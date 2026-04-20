//
//  RibbonShaders.metal
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Vertex and fragment shaders for stroke ribbons.
//
//  Each stroke is a triangle strip with per-vertex (s, t) parameters:
//    - s in [0, 1] runs along the stroke
//    - t in [-1, +1] runs across the stroke (0 = centerline)
//
//  The fragment shader does, in order:
//    1. Linearly interpolate colorStart -> colorEnd over s
//    2. Apply optional cross-stroke edge softness (alpha falloff at |t| -> 1)
//    3. Apply procedural texture (smooth / pencil / chalk / ink / watercolor)
//    4. Multiply by global opacityScale
//    5. Pre-multiply alpha for source-over blending
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Texture mode constants
//
// Must match the raw values of `RibbonTextureMode` in `RibbonAppearance.swift`.
constant int kBrushTextureSmooth     = 0;
constant int kBrushTexturePencil     = 1;
constant int kBrushTextureChalk      = 2;
constant int kBrushTextureInk        = 3;
constant int kBrushTextureWatercolor = 4;

// MARK: - I/O

struct RibbonVertexIn {
    float2 position  [[attribute(0)]];
    float2 parametric [[attribute(1)]];
};

struct RibbonVertexOut {
    float4 clipPosition [[position]];
    float2 parametric;
};

struct RibbonUniforms {
    // Orthographic projection: maps canvas points to clip space.
    //   x_clip = projectionScale.x * x_pt + projectionOffset.x
    //   y_clip = projectionScale.y * y_pt + projectionOffset.y
    // (The y scale is negative so canvas-y-down maps to clip-y-up.)
    float2 projectionScale;
    float2 projectionOffset;

    // Linear color gradient over s in [0, 1]. Endpoint alphas already
    // include any opacity-along-path taper baked in by the renderer.
    float4 colorStart;
    float4 colorEnd;

    // Global multiplier applied last to the alpha channel.
    float  opacityScale;

    // Cross-stroke edge softness. 0 = hard edges; 1 = full taper.
    float  edgeSoftness;

    // Texture selector and parameters (see `RibbonTextureMode` /
    // `RibbonAppearance` in Swift for layout).
    int    textureMode;
    int    _pad;        // align next field to 16 bytes
    float4 textureParams;
};

// MARK: - Procedural noise
//
// Simple 2D value noise sufficient for stroke-grain effects. Uses a
// hash function that maps a 2D integer lattice point to a deterministic
// pseudo-random float in [0, 1], then bilinearly interpolates with a
// smoothstep falloff to remove blockiness. Cheap, GPU-friendly, no
// texture sampling required.

inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 78.233);
    return fract(p.x * p.y);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);   // smoothstep

    float a = hash21(i + float2(0.0, 0.0));
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x),
               mix(c, d, u.x),
               u.y);
}

// MARK: - Vertex

vertex RibbonVertexOut ribbon_vertex(
    RibbonVertexIn in [[stage_in]],
    constant RibbonUniforms &u [[buffer(1)]]
) {
    RibbonVertexOut out;
    float2 clip;
    clip.x = u.projectionScale.x * in.position.x + u.projectionOffset.x;
    clip.y = u.projectionScale.y * in.position.y + u.projectionOffset.y;
    out.clipPosition = float4(clip, 0.0, 1.0);
    out.parametric = in.parametric;
    return out;
}

// MARK: - Fragment

fragment float4 ribbon_fragment(
    RibbonVertexOut in [[stage_in]],
    constant RibbonUniforms &u [[buffer(1)]]
) {
    float s = clamp(in.parametric.x, 0.0, 1.0);
    float t = in.parametric.y;
    float absT = fabs(t);

    // 1. Linear color blend along stroke length.
    float4 color = mix(u.colorStart, u.colorEnd, s);

    // 2. Soft edge across the stroke width.
    float edgeFactor = 1.0;
    if (u.edgeSoftness > 0.0) {
        edgeFactor = 1.0 - smoothstep(1.0 - u.edgeSoftness, 1.0, absT);
    }

    // 3. Procedural texture modulation. The noise lattice is sampled in
    //    (s, t)-space scaled by texture-specific frequencies. We use s
    //    multiplied by a magic factor (50) to give a sensible cycle
    //    count along a typical stroke; the exact factor doesn't matter
    //    visually and is just a frequency baseline.
    float textureFactor = 1.0;
    if (u.textureMode == kBrushTexturePencil) {
        // Pencil: per-pixel noise threshold cuts gaps out of alpha.
        // grain = textureParams.x  (cycles per stroke width)
        // density = textureParams.y  (probability of a pixel surviving)
        float grain = u.textureParams.x;
        float density = u.textureParams.y;
        float n = valueNoise(float2(s * 50.0, t) * grain);
        // Smooth threshold so the cutoff isn't a hard binary mask.
        textureFactor = smoothstep(1.0 - density, 1.0 - density + 0.15, n);
    } else if (u.textureMode == kBrushTextureChalk) {
        // Chalk: like pencil, but edges drop out faster (chalk on board
        // is patchy near boundaries) and the noise lattice is coarser.
        float grain = u.textureParams.x;
        float density = u.textureParams.y;
        float n = valueNoise(float2(s * 50.0, t * 1.5) * grain);
        float core = smoothstep(1.0 - density, 1.0 - density + 0.2, n);
        // Extra edge drop-out: multiply by an across-stroke envelope
        // that fades toward |t| = 1.
        float edgeFade = 1.0 - smoothstep(0.5, 1.0, absT);
        textureFactor = core * mix(0.5, 1.0, edgeFade);
    } else if (u.textureMode == kBrushTextureInk) {
        // Ink bleed: smooth alpha falloff toward edges, no gaps.
        // bleed = textureParams.x  (width of falloff in [0, 1])
        float bleed = u.textureParams.x;
        // Inside `1 - bleed` the alpha is full; from there it ramps down
        // to 0 at the edge.
        textureFactor = 1.0 - smoothstep(1.0 - bleed, 1.0, absT);
    } else if (u.textureMode == kBrushTextureWatercolor) {
        // Watercolor: edge-darkened wash. Darken color toward the
        // boundary while keeping the interior at the base color, then
        // modulate alpha with a low-frequency noise mask so the wash
        // looks uneven.
        float edgeDarkness = u.textureParams.x;
        float bleed = u.textureParams.y;
        float edgeFalloff = smoothstep(1.0 - bleed, 1.0, absT);
        // Multiply RGB by (1 - edgeDarkness*edgeFalloff) — darker near
        // the edge. Alpha is unaffected by darkening; only by noise.
        color.rgb *= (1.0 - edgeDarkness * edgeFalloff);
        float wash = valueNoise(float2(s * 30.0, t * 2.0));
        // Map wash from [0,1] into [0.7, 1] so we don't punch big holes.
        textureFactor = mix(0.7, 1.0, wash);
    }
    // (kBrushTextureSmooth: leave textureFactor = 1.0)

    color.a *= u.opacityScale * edgeFactor * textureFactor;

    // 5. Pre-multiplied alpha for source-over blending.
    color.rgb *= color.a;
    return color;
}
