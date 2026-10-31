#!/usr/bin/env bash
# Render the DocExample gallery into docs/images and docs/Examples.md.
#
# Usage:
#   scripts/render-docs.sh
#
# DocsGalleryTests stay skipped in a normal test run. This script enables them
# by setting TEST_RUNNER_RENDER_DOCS=1 on the booted simulator (launchctl).
# Passing that name as an xcodebuild argument only sets a build setting and
# does not reach the test process. The tests also accept RENDER_DOCS=1.
# Stills are quantized with pngquant and then oxipng. GIFs are assembled with
# gifski from PNG frames of pinned animation steps.
#
# Budgets, checked after compression. The script exits non-zero past any of them:
#   each still PNG  <= 120 KB
#   each GIF        <= 800 KB
#   docs/images     <= 10 MB
# No Git LFS.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RAW="$ROOT/build/docs-render"
LOG="$ROOT/build/docs-render.log"
RESULT="$ROOT/build/docs-gallery.xcresult"
DERIVED="$ROOT/build/DerivedData"
DOCS_IMAGES="$ROOT/docs/images"
EXAMPLES="$ROOT/docs/Examples.md"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6"

MAX_STILL=$((120 * 1024))
MAX_GIF=$((800 * 1024))
MAX_TOTAL=$((10 * 1024 * 1024))
# The simulator test runner has hung past xcodebuild's own prepare timeout.
# Kill the process group if the gallery run is still going after 20 minutes.
XCODEBUILD_TIMEOUT=1200

# Run a command in its own process group. Stdout and stderr go to `logfile`.
# Exit 124 if it is still running after `seconds`, after killing the group.
run_with_timeout() {
  local seconds="$1"
  local logfile="$2"
  shift 2
  perl - "$seconds" "$logfile" "$@" <<'PERL'
use strict;
use warnings;
my $seconds = shift @ARGV;
my $logfile = shift @ARGV;
my $pid = fork();
die "fork: $!" unless defined $pid;
if ($pid == 0) {
    setpgrp(0, 0);
    open my $log, ">", $logfile or die "open $logfile: $!";
    open STDOUT, ">&", $log or die $!;
    open STDERR, ">&", $log or die $!;
    exec @ARGV or die "exec: $!";
}
my $timed_out = 0;
local $SIG{ALRM} = sub { $timed_out = 1; kill "TERM", -$pid; };
alarm $seconds;
waitpid($pid, 0);
my $status = $?;
alarm 0;
if ($timed_out) {
    sleep 2;
    kill "KILL", -$pid;
    waitpid($pid, 0);
    exit 124;
}
if ($status & 127) {
    exit 128 + ($status & 127);
}
exit($status >> 8);
PERL
}

# gifski's thread pool does not change pixels, but a fixed pool keeps the
# encoder on one code path if a future version ever mixed them.
export RAYON_NUM_THREADS=1

ensure_tool() {
  local bin="$1"
  local formula="$2"
  if command -v "$bin" >/dev/null 2>&1; then
    return 0
  fi
  echo "Missing '$bin'."
  echo "Install with: brew install $formula"
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not on PATH. Install $formula, then re-run scripts/render-docs.sh."
    exit 1
  fi
  echo "Installing $formula with Homebrew..."
  brew install "$formula"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "error: '$bin' is still not on PATH after brew install $formula"
    exit 1
  fi
}

ensure_tool gifski gifski
ensure_tool pngquant pngquant
ensure_tool oxipng oxipng

mkdir -p "$ROOT/build"
rm -rf "$RAW" "$RESULT"
mkdir -p "$RAW"

# iPhone 16 Pro on the iOS 18.6 runtime. Name match avoids the Pro Max.
UDID="$(
  xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "iOS-18-6" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("name") == "iPhone 16 Pro":
            print(device["udid"])
            sys.exit(0)
sys.stderr.write("No available iPhone 16 Pro simulator on iOS 18.6\n")
sys.exit(1)
'
)"

clear_render_env() {
  xcrun simctl spawn "$UDID" launchctl unsetenv TEST_RUNNER_RENDER_DOCS >/dev/null 2>&1 || true
  xcrun simctl spawn "$UDID" launchctl unsetenv RENDER_DOCS >/dev/null 2>&1 || true
  xcrun simctl spawn "$UDID" launchctl unsetenv TEST_RUNNER_DOCS_OUTPUT >/dev/null 2>&1 || true
  xcrun simctl spawn "$UDID" launchctl unsetenv DOCS_OUTPUT >/dev/null 2>&1 || true
}
trap clear_render_env EXIT

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl spawn "$UDID" launchctl setenv TEST_RUNNER_RENDER_DOCS 1
xcrun simctl spawn "$UDID" launchctl setenv RENDER_DOCS 1
xcrun simctl spawn "$UDID" launchctl setenv TEST_RUNNER_DOCS_OUTPUT "$RAW"
xcrun simctl spawn "$UDID" launchctl setenv DOCS_OUTPUT "$RAW"

echo "Rendering docs gallery on ${DESTINATION} (timeout ${XCODEBUILD_TIMEOUT}s)"
echo "Log: $LOG"
set +e
run_with_timeout "$XCODEBUILD_TIMEOUT" "$LOG" \
  xcodebuild test \
  -scheme RoughSwiftUI \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" \
  -only-testing:RoughSwiftUITests/DocsGalleryTests \
  -parallel-testing-enabled NO \
  -enableCodeCoverage NO
status=$?
set -e
if [[ "$status" -eq 124 ]]; then
  echo "error: xcodebuild exceeded ${XCODEBUILD_TIMEOUT}s and was killed. Log: $LOG"
  exit 124
fi
if [[ "$status" -ne 0 ]]; then
  echo "error: xcodebuild exited $status. Log: $LOG"
  exit "$status"
fi

SOURCE="$RAW"
if [[ ! -f "$SOURCE/manifest.json" ]]; then
  echo "manifest.json was not in $RAW. Searching the simulator container..."
  found="$(find "$HOME/Library/Developer/CoreSimulator/Devices" \
    -type f -name manifest.json -path '*roughswiftui-docs-gallery/manifest.json' -mmin -30 \
    2>/dev/null | head -n 1 || true)"
  if [[ -z "$found" ]]; then
    echo "error: DocsGalleryTests did not write a manifest."
    echo "The test is skipped unless TEST_RUNNER_RENDER_DOCS=1 reaches the runner."
    echo "Log: $LOG"
    exit 1
  fi
  SOURCE="$(dirname "$found")"
  echo "Using simulator output at $SOURCE"
fi

mkdir -p "$DOCS_IMAGES"

compress_still() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  local min_quality=65
  local attempt
  for attempt in 1 2 3; do
    local tmp="${dest}.pngquant.png"
    rm -f "$tmp"
    local quant_status=0
    pngquant --force --skip-if-larger --speed 1 \
      --quality="${min_quality}-95" \
      --output "$tmp" "$src" || quant_status=$?
    if [[ "$quant_status" -eq 0 ]]; then
      mv "$tmp" "$dest"
    elif [[ "$quant_status" -eq 98 || "$quant_status" -eq 99 ]]; then
      rm -f "$tmp"
      cp "$src" "$dest"
    else
      rm -f "$tmp"
      echo "error: pngquant failed on $src (exit $quant_status)"
      exit 1
    fi
    oxipng -o 4 --strip all --quiet "$dest"
    local size
    size="$(stat -f%z "$dest")"
    if [[ "$size" -le "$MAX_STILL" ]]; then
      return 0
    fi
    min_quality=$((min_quality - 20))
    if [[ "$min_quality" -lt 20 ]]; then
      echo "error: still $dest is ${size} bytes after pngquant/oxipng (limit ${MAX_STILL})."
      exit 1
    fi
    echo "still $(basename "$dest") is ${size} bytes; retrying pngquant min quality ${min_quality}"
  done
}

assemble_gif() {
  local frames="$1"
  local dest="$2"
  local fps="$3"
  mkdir -p "$(dirname "$dest")"
  local frame_list=()
  while IFS= read -r frame; do
    frame_list+=("$frame")
  done < <(find "$frames" -name 'frame-*.png' | sort)
  if [[ "${#frame_list[@]}" -eq 0 ]]; then
    echo "error: no frames in $frames"
    exit 1
  fi
  local width height
  width="$(sips -g pixelWidth "${frame_list[0]}" | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelHeight "${frame_list[0]}" | awk '/pixelHeight/ { print $2 }')"
  local quality=90
  while [[ "$quality" -ge 40 ]]; do
    gifski \
      --quiet \
      --fps "$fps" \
      --width "$width" \
      --height "$height" \
      --quality "$quality" \
      --repeat 0 \
      --no-sort \
      -o "$dest" \
      "${frame_list[@]}"
    local size
    size="$(stat -f%z "$dest")"
    if [[ "$size" -le "$MAX_GIF" ]]; then
      echo "gif $(basename "$dest") ${size} bytes at quality ${quality}"
      return 0
    fi
    echo "gif $(basename "$dest") is ${size} bytes at quality ${quality}; lowering quality"
    quality=$((quality - 10))
  done
  local size
  size="$(stat -f%z "$dest")"
  echo "error: GIF $dest is ${size} bytes (limit ${MAX_GIF})."
  exit 1
}

python3 - "$SOURCE/manifest.json" "$SOURCE" "$DOCS_IMAGES" "$EXAMPLES" <<'PY'
import json
import pathlib
import re
import sys

manifest_path, source_root, images_root, examples_path = map(pathlib.Path, sys.argv[1:5])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
examples = manifest["examples"]

def anchor(text: str) -> str:
    slug = text.strip().lower()
    slug = re.sub(r"[^a-z0-9\s-]", "", slug)
    slug = re.sub(r"\s+", "-", slug)
    return slug

sections = []
grouped = {}
for example in examples:
    section = example["section"]
    if section not in grouped:
        sections.append(section)
        grouped[section] = []
    grouped[section].append(example)

# The shell compresses after this process prints a plan. Paths only.
plan = []
for example in examples:
    plan.append({
        "kind": example["kind"],
        "output": example["output"],
        "framesDirectory": example.get("framesDirectory"),
        "fps": example.get("fps") or 8,
    })
plan_path = source_root / "publish-plan.json"
plan_path.write_text(json.dumps(plan), encoding="utf-8")

lines = [
    "# Examples",
    "",
    "Rendered by `scripts/render-docs.sh` from the `DocExample` catalog. Each example sets a fixed seed so the picture matches the snippet. Tiles are light paper cards.",
    "",
    "## Contents",
    "",
]
for section in sections:
    lines.append(f"- [{section}](#{anchor(section)})")
lines.append("")
for section in sections:
    lines.append(f"## {section}")
    lines.append("")
    for example in grouped[section]:
        lines.append(f"### {example['title']}")
        lines.append("")
        lines.append(example["description"])
        lines.append("")
        lines.append(f"![{example['title']}](images/{example['output']})")
        lines.append("")
        lines.append("```swift")
        lines.append(example["snippet"].strip("\n"))
        lines.append("```")
        lines.append("")

examples_path.parent.mkdir(parents=True, exist_ok=True)
text = "\n".join(lines)
if not text.endswith("\n"):
    text += "\n"
examples_path.write_text(text, encoding="utf-8")
print(f"Wrote {examples_path}")
PY

python3 - "$SOURCE/publish-plan.json" "$SOURCE" "$DOCS_IMAGES" <<'PY' > "$ROOT/build/docs-publish.tsv"
import json
import pathlib
import sys

plan_path, source_root, images_root = map(pathlib.Path, sys.argv[1:4])
plan = json.loads(plan_path.read_text(encoding="utf-8"))
for item in plan:
    output = images_root / item["output"]
    if item["kind"] == "still":
        src = source_root / item["output"]
        print(f"still\t{src}\t{output}\t")
    elif item["kind"] == "gif":
        frames = source_root / item["framesDirectory"]
        print(f"gif\t{frames}\t{output}\t{item['fps']}")
    else:
        raise SystemExit(f"unknown kind {item['kind']}")
PY

while IFS=$'\t' read -r kind src dest extra; do
  [[ -z "${kind:-}" ]] && continue
  if [[ "$kind" == "still" ]]; then
    compress_still "$src" "$dest"
  elif [[ "$kind" == "gif" ]]; then
    assemble_gif "$src" "$dest" "$extra"
  else
    echo "error: unknown publish kind $kind"
    exit 1
  fi
done < "$ROOT/build/docs-publish.tsv"

echo "File sizes:"
total=0
over=0
while IFS= read -r -d '' file; do
  size="$(stat -f%z "$file")"
  total=$((total + size))
  rel="${file#"$ROOT"/}"
  printf '  %s  %s bytes\n' "$rel" "$size"
  case "$file" in
    *.png)
      if [[ "$size" -gt "$MAX_STILL" ]]; then
        echo "error: still $rel is ${size} bytes (limit ${MAX_STILL})."
        over=1
      fi
      ;;
    *.gif)
      if [[ "$size" -gt "$MAX_GIF" ]]; then
        echo "error: GIF $rel is ${size} bytes (limit ${MAX_GIF})."
        over=1
      fi
      ;;
  esac
done < <(find "$DOCS_IMAGES" -type f \( -name '*.png' -o -name '*.gif' \) -print0)

echo "docs/images total: ${total} bytes (limit ${MAX_TOTAL})"
if [[ "$total" -gt "$MAX_TOTAL" ]]; then
  echo "error: docs/images total ${total} bytes exceeds ${MAX_TOTAL}."
  over=1
fi
if [[ "$over" -ne 0 ]]; then
  exit 1
fi

echo "Docs gallery written to docs/images and docs/Examples.md"
