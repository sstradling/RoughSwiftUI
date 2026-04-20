//
//  RibbonShaders.metal
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Vertex and fragment shaders for the gradient-ribbon proof of concept.
//  The mesh is a triangle strip; each vertex carries:
//    - position in canvas points
//    - parametric (s, t) where s in [0,1] is along-stroke and
//      t in [-1, +1] is across-stroke (0 = centerline)
//

#include <metal_stdlib>
using namespace metal;

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
    // Stored as two 2D rows + a 2D translation, then expanded.
    //   x_clip = projectionScale.x * x_pt + projectionOffset.x
    //   y_clip = projectionScale.y * y_pt + projectionOffset.y
    // (The y scale is negative so canvas-y-down maps to clip-y-up.)
    float2 projectionScale;
    float2 projectionOffset;

    // Color stops: shader interpolates linearly from start at s = 0
    // to end at s = 1, then multiplies the result by `opacityScale`.
    float4 colorStart;
    float4 colorEnd;
    float  opacityScale;
    float  edgeSoftness; // 0 = hard edges, 1 = full taper to 0 at |t| = 1
};

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

fragment float4 ribbon_fragment(
    RibbonVertexOut in [[stage_in]],
    constant RibbonUniforms &u [[buffer(1)]]
) {
    float s = clamp(in.parametric.x, 0.0, 1.0);
    float t = in.parametric.y;

    // Linear color blend along stroke length.
    float4 color = mix(u.colorStart, u.colorEnd, s);

    // Soft edge across the stroke width. When edgeSoftness == 0 the
    // alpha multiplier is 1 across the full ribbon; when 1, alpha falls
    // off linearly to 0 at the boundary, giving an ink-like soft edge.
    float edgeFactor = 1.0;
    if (u.edgeSoftness > 0.0) {
        float falloff = 1.0 - smoothstep(1.0 - u.edgeSoftness, 1.0, fabs(t));
        edgeFactor = falloff;
    }

    color.a *= u.opacityScale * edgeFactor;
    // Pre-multiplied alpha output for blendable composition.
    color.rgb *= color.a;
    return color;
}
