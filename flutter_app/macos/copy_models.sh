#!/bin/bash
# Copy model files to the app bundle Resources directory

set -e

echo "Copying face detection models to app bundle..."

# The app bundle is at: $BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app
RESOURCES_DIR="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources"

# Create Resources directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"

# Source directory
SOURCE_DIR="$PROJECT_DIR/Runner/Resources"

# Copy model files
if [ -f "$SOURCE_DIR/face_detection_yunet_2023mar.onnx" ]; then
    cp "$SOURCE_DIR/face_detection_yunet_2023mar.onnx" "$RESOURCES_DIR/"
    echo "✓ Copied YuNet model"
fi

if [ -f "$SOURCE_DIR/haarcascade_frontalface_default.xml" ]; then
    cp "$SOURCE_DIR/haarcascade_frontalface_default.xml" "$RESOURCES_DIR/"
    echo "✓ Copied Haar Cascade face model"
fi

if [ -f "$SOURCE_DIR/haarcascade_eye.xml" ]; then
    cp "$SOURCE_DIR/haarcascade_eye.xml" "$RESOURCES_DIR/"
    echo "✓ Copied Haar Cascade eye model"
fi

echo "Model files copied successfully"
