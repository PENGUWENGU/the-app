#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "       Locus iOS IPA Builder             "
echo "========================================="

# 1. Check for Xcode / xcodebuild
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Error: xcodebuild is required to compile iOS binaries (requires macOS with Xcode)."
    echo "Tip: You can use the automated GitHub Actions workflow (.github/workflows/build.yml) to build the IPA for free in the cloud without a Mac!"
    exit 1
fi

# 2. Check or build libidevice_ffi.a
if [ ! -f "Vendor/idevice/libidevice_ffi.a" ]; then
    echo "libidevice_ffi.a not found in Vendor/idevice/. Attempting to compile via cargo..."
    if command -v cargo >/dev/null 2>&1; then
        rustup target add aarch64-apple-ios || true
        mkdir -p /tmp/idevice_src
        git clone --depth 1 https://github.com/jkcoxson/idevice.git /tmp/idevice_src
        (cd /tmp/idevice_src/ffi 2>/dev/null || cd /tmp/idevice_src && cargo build --release --target aarch64-apple-ios)
        mkdir -p Vendor/idevice
        find /tmp/idevice_src/target/aarch64-apple-ios/release -name "*.a" | head -n 1 | xargs -I {} cp {} Vendor/idevice/libidevice_ffi.a
    else
        echo "Warning: cargo not found. If linker fails on -lidevice_ffi, please provide Vendor/idevice/libidevice_ffi.a."
    fi
fi

# 3. Clean and build
echo "Building Locus Release binary..."
rm -rf build Payload *.ipa
mkdir -p build

xcodebuild \
  -project Locus.xcodeproj \
  -scheme Locus \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/build" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  AD_HOC_CODE_SIGNING_ALLOWED=NO \
  build

# 4. Package IPA
APP=$(find build -name "Locus.app" -type d | head -n 1)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "Error: Locus.app was not produced."
    exit 1
fi

echo "Packaging Payload from $APP..."
mkdir -p Payload
cp -R "$APP" Payload/Locus.app

zip -qry LocusPlus-unsigned.ipa Payload
cp LocusPlus-unsigned.ipa Locus-unsigned.ipa

echo "Done! Generated:"
ls -lh LocusPlus-unsigned.ipa
