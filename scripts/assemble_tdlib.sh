#!/bin/bash
# scripts/assemble_tdlib.sh
# Deterministic assembly script for TDLib (pinned commit 42e6a5259551178d1dab54a22ad96d14bd906e20)
# Designed for the selected cloud build runner (macOS-26 / Xcode 26).
# Builds in a no-space temporary directory, targets iOS arm64 device architecture,
# and outputs libtdjson.a into ignored build/tdlib/ with SHA-256 checksum.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN_COMMIT="42e6a5259551178d1dab54a22ad96d14bd906e20"
TD_REPO_URL="https://github.com/tdlib/td.git"

BUILD_DIR="/tmp/cloudified_tdlib_build"
OUTPUT_DIR="${CLOUDIFIED_BUILD_ROOT:-$REPO_ROOT/build}/tdlib"

echo "=== TDLib Deterministic Assembly ==="
echo "Pinned commit: $PIN_COMMIT"
echo "Build directory: $BUILD_DIR"
echo "Output directory: $OUTPUT_DIR"

# Require full Xcode tools on Darwin
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: Assembling TDLib for iOS requires macOS with Xcode command line tools and cmake." >&2
    exit 2
fi

if ! command -v cmake >/dev/null 2>&1; then
    echo "Error: cmake is required to assemble TDLib. Please install cmake." >&2
    exit 2
fi

# Clean and prepare temporary directory without spaces
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/src" "$BUILD_DIR/build" "$OUTPUT_DIR"

echo "1. Fetching pinned TDLib sources..."
cd "$BUILD_DIR/src"
git init
git remote add origin "$TD_REPO_URL"
git fetch --depth 1 origin "$PIN_COMMIT"
git checkout "$PIN_COMMIT"

# Verify exact checkout matches pin
HEAD_COMMIT="$(git rev-parse HEAD)"
if [[ "$HEAD_COMMIT" != "$PIN_COMMIT" ]]; then
    echo "Error: Checked out commit $HEAD_COMMIT does not match pin $PIN_COMMIT!" >&2
    exit 3
fi
echo "Verified source HEAD equals pin: $HEAD_COMMIT"

echo "2. Configuring CMake for iOS arm64..."
cd "$BUILD_DIR/build"

# Locate iPhoneOS SDK
IPHONEOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
if [[ -z "$IPHONEOS_SDK" ]]; then
    echo "Error: iPhoneOS SDK not found. Full Xcode installation with iOS SDK is required." >&2
    exit 4
fi

cmake -GNinja "$BUILD_DIR/src" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$IPHONEOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
    -DTD_ENABLE_JNI=OFF \
    -DTD_ENABLE_DOTNET=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON

echo "3. Building tdjson target..."
cmake --build . --target tdjson_static --config Release -j "$(sysctl -n hw.ncpu || echo 4)"

echo "4. Copying artifacts and recording checksum..."
mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"

if [[ -f "$BUILD_DIR/build/td/telegram/libtdjson_static.a" ]]; then
    cp "$BUILD_DIR/build/td/telegram/libtdjson_static.a" "$OUTPUT_DIR/lib/libtdjson.a"
elif [[ -f "$BUILD_DIR/build/libtdjson.a" ]]; then
    cp "$BUILD_DIR/build/libtdjson.a" "$OUTPUT_DIR/lib/libtdjson.a"
else
    echo "Error: Expected static library not found after build!" >&2
    exit 5
fi

# Copy generated headers
cp "$BUILD_DIR/src/td/telegram/td_json_client.h" "$OUTPUT_DIR/include/"
cp "$BUILD_DIR/build/td/telegram/tdjson_export.h" "$OUTPUT_DIR/include/"

# Record output checksum
(
    cd "$OUTPUT_DIR/lib"
    shasum -a 256 libtdjson.a | tee "$OUTPUT_DIR/libtdjson.a.sha256"
)

echo "=== TDLib assembly complete ==="
echo "Artifact: $OUTPUT_DIR/lib/libtdjson.a"
python3 "$REPO_ROOT/scripts/build_cache.py" seal-tdlib --build-root "${CLOUDIFIED_BUILD_ROOT:-$REPO_ROOT/build}"
