#!/bin/bash
set -e

APP_NAME="ExtraDock"
INSTALL_DIR="/Applications"

echo "Building $APP_NAME..."

# Build release configuration
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    build \
    2>&1 | grep -E '(BUILD|error:)'

# Find the built app in DerivedData
BUILD_DIR=$(xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')

APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built app not found at $APP_PATH"
    exit 1
fi

echo "Build successful."
echo ""

# Install to /Applications
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing existing $APP_NAME from $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

echo "Installing to $INSTALL_DIR..."
cp -R "$APP_PATH" "$INSTALL_DIR/"

echo "Done! $APP_NAME installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Launch it with:"
echo "  open /Applications/$APP_NAME.app"
