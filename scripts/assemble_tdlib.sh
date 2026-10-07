#!/bin/bash
# scripts/assemble_tdlib.sh
# Deterministic assembly script for TDLib (pinned commit 42e6a5259551178d1dab54a22ad96d14bd906e20)
# and OpenSSL 3.0.15 (pinned commit 1979ad30e4ad341ea22b31a84f3eb86f78878b27).
# Designed for the selected cloud build runner (macOS-26 / Xcode 26).
# Builds in an owned temporary directory with cleanup trap, targets iOS 26 arm64 device architecture,
# combines the complete JSON static link closure, and seals the native cache per docs/BUILD-CACHE.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN_COMMIT="42e6a5259551178d1dab54a22ad96d14bd906e20"
TD_REPO_URL="https://github.com/tdlib/td.git"

OPENSSL_PIN_COMMIT="1979ad30e4ad341ea22b31a84f3eb86f78878b27"
OPENSSL_REPO_URL="https://github.com/openssl/openssl.git"

BUILD_ROOT="${CLOUDIFIED_BUILD_ROOT:-$REPO_ROOT/build}"
OUTPUT_DIR="$BUILD_ROOT/tdlib"

echo "=== TDLib Deterministic Assembly ==="
echo "TDLib pinned commit: $PIN_COMMIT"
echo "OpenSSL pinned commit: $OPENSSL_PIN_COMMIT"
echo "Output directory: $OUTPUT_DIR"

# Require Darwin and full Xcode / toolchain
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: Assembling TDLib for iOS requires macOS with Xcode and cmake." >&2
    exit 2
fi

if ! command -v cmake >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
    echo "Error: cmake and ninja are required to assemble TDLib." >&2
    exit 2
fi

# Locate iPhoneOS SDK
IPHONEOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
if [[ -z "$IPHONEOS_SDK" ]]; then
    echo "Error: iPhoneOS SDK not found. Full Xcode installation with iOS SDK is required." >&2
    exit 4
fi

# Create owned temporary workspace with automatic cleanup trap
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cloudified_tdlib_build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT INT TERM

mkdir -p "$BUILD_DIR/src-td" "$BUILD_DIR/src-openssl" "$BUILD_DIR/host-td" "$BUILD_DIR/ios-td" "$BUILD_DIR/ios-openssl" "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"

echo "1. Fetching pinned TDLib and OpenSSL sources..."
(
    cd "$BUILD_DIR/src-td"
    git init
    git remote add origin "$TD_REPO_URL"
    git fetch --depth 1 origin "$PIN_COMMIT"
    git checkout "$PIN_COMMIT"
    HEAD_COMMIT="$(git rev-parse HEAD)"
    if [[ "$HEAD_COMMIT" != "$PIN_COMMIT" ]]; then
        echo "Error: TDLib commit $HEAD_COMMIT does not match pin $PIN_COMMIT!" >&2
        exit 3
    fi
)

(
    cd "$BUILD_DIR/src-openssl"
    git init
    git remote add origin "$OPENSSL_REPO_URL"
    git fetch --depth 1 origin "$OPENSSL_PIN_COMMIT"
    git checkout "$OPENSSL_PIN_COMMIT"
    HEAD_COMMIT="$(git rev-parse HEAD)"
    if [[ "$HEAD_COMMIT" != "$OPENSSL_PIN_COMMIT" ]]; then
        echo "Error: OpenSSL commit $HEAD_COMMIT does not match pin $OPENSSL_PIN_COMMIT!" >&2
        exit 3
    fi
)

echo "2. Building iOS OpenSSL arm64..."
(
    cd "$BUILD_DIR/src-openssl"
    # Configure OpenSSL for iOS arm64 without shared libraries
    export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
    export CROSS_SDK="$(basename "$IPHONEOS_SDK")"
    ./Configure ios64-cross no-shared no-dso no-tests no-engine \
        --prefix="$BUILD_DIR/ios-openssl" \
        -D__ARM_MAX_ARCH__=8 \
        -mios-version-min=26.0
    make -j "$(sysctl -n hw.ncpu || echo 4)" build_libs
    make install_dev
)

echo "3. Host code generation phase (macOS host)..."
(
    cd "$BUILD_DIR/host-td"
    cmake -GNinja "$BUILD_DIR/src-td" \
        -DCMAKE_BUILD_TYPE=Release \
        -DTD_GENERATE_SOURCE_FILES=ON
    cmake --build . --target prepare_cross_compiling -j "$(sysctl -n hw.ncpu || echo 4)"
)

echo "4. Cross-compiling TDLib for iOS arm64 (deployment 26.0)..."
(
    cd "$BUILD_DIR/ios-td"
    cmake -GNinja "$BUILD_DIR/src-td" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT="$IPHONEOS_SDK" \
        -DCMAKE_OSX_ARCHITECTURES="arm64" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="26.0" \
        -DOPENSSL_ROOT_DIR="$BUILD_DIR/ios-openssl" \
        -DOPENSSL_USE_STATIC_LIBS=TRUE \
        -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
        -DTD_ENABLE_JNI=OFF \
        -DTD_ENABLE_DOTNET=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    cmake --build . --target tdjson_static -j "$(sysctl -n hw.ncpu || echo 4)"
)

echo "5. Combining complete static link closure into unified libtdjson.a..."
# Find all member static libraries produced by tdjson target closure and openssl
TD_ARCHIVES=(
    "$BUILD_DIR/ios-td/td/telegram/libtdjson_static.a"
    "$BUILD_DIR/ios-td/td/libtdclient.a"
    "$BUILD_DIR/ios-td/td/libtdcore.a"
    "$BUILD_DIR/ios-td/tddb/td/db/libtddb.a"
    "$BUILD_DIR/ios-td/tdactor/td/actor/libtdactor.a"
    "$BUILD_DIR/ios-td/tdnet/td/net/libtdnet.a"
    "$BUILD_DIR/ios-td/tdutils/td/utils/libtdutils.a"
    "$BUILD_DIR/ios-openssl/lib/libcrypto.a"
    "$BUILD_DIR/ios-openssl/lib/libssl.a"
)

# Collect existing static libraries
VALID_ARCHIVES=()
for arch in "${TD_ARCHIVES[@]}"; do
    if [[ -f "$arch" ]]; then
        VALID_ARCHIVES+=("$arch")
    fi
done

# Also pick up any additional td archives in the build tree
while IFS= read -r -d '' extra_arch; do
    if [[ ! " ${VALID_ARCHIVES[*]} " =~ " ${extra_arch} " ]]; then
        VALID_ARCHIVES+=("$extra_arch")
    fi
done < <(find "$BUILD_DIR/ios-td" -name "libtd*.a" -print0)

# Merge into unified static archive using libtool
libtool -static -o "$OUTPUT_DIR/lib/libtdjson.a" "${VALID_ARCHIVES[@]}"

# Copy headers
cp "$BUILD_DIR/src-td/td/telegram/td_json_client.h" "$OUTPUT_DIR/include/"
cp "$BUILD_DIR/ios-td/td/telegram/tdjson_export.h" "$OUTPUT_DIR/include/"

# Verify arm64 architecture
xcrun lipo -info "$OUTPUT_DIR/lib/libtdjson.a"

# Seal cache provenance per BUILD-CACHE.md
echo "6. Sealing native TDLib cache..."
python3 "$REPO_ROOT/scripts/build_cache.py" seal-tdlib --build-root "$BUILD_ROOT"

echo "=== TDLib assembly complete ==="
echo "Artifact: $OUTPUT_DIR/lib/libtdjson.a"
