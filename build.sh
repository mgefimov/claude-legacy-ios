#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="ClaudeLegacy.xcodeproj"
SCHEME="ClaudeLegacy"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/ClaudeLegacy.xcarchive"
OUTPUT_DIR="${BUILD_DIR}/output"
IPA_NAME="ClaudeLegacy.ipa"

echo "=== ClaudeLegacy IPA Builder ==="

# Init submodules if needed
if [ ! -f "${PROJECT_DIR}/Polyfills/layout/Library/Application Support/Polyfills/polyfills.js" ]; then
    echo ">> Initializing submodules..."
    cd "${PROJECT_DIR}"
    git submodule update --init --recursive
fi

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Build archive (no codesigning)
echo ">> Archiving..."
xcodebuild archive \
    -project "${PROJECT_DIR}/${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "generic/platform=iOS" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_ENTITLEMENTS="" \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    | tail -5

# Package IPA from archive
echo ">> Packaging IPA..."
APP_PATH="${ARCHIVE_PATH}/Products/Applications/ClaudeLegacy.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: .app not found at ${APP_PATH}"
    echo "Searching archive for .app..."
    find "${ARCHIVE_PATH}" -name "*.app" -type d
    exit 1
fi

# Remove code signature directories
find "${APP_PATH}" -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true

# Build Payload structure
PAYLOAD_DIR="${OUTPUT_DIR}/Payload"
mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"

# Create IPA
cd "${OUTPUT_DIR}"
zip -qr "${IPA_NAME}" Payload
rm -rf Payload

echo ""
echo "=== Done ==="
echo "IPA: ${OUTPUT_DIR}/${IPA_NAME}"
echo "Size: $(du -h "${OUTPUT_DIR}/${IPA_NAME}" | cut -f1)"
