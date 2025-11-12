#!/usr/bin/env python3
"""
YOLO to CoreML Conversion Script
Converts YOLO PyTorch models to CoreML format for macOS integration
"""

import sys
import os
from pathlib import Path

def check_dependencies():
    """Check if required packages are installed"""
    required = ['ultralytics', 'coremltools', 'torch']
    missing = []

    for package in required:
        try:
            __import__(package)
        except ImportError:
            missing.append(package)

    if missing:
        print(f"Error: Missing required packages: {', '.join(missing)}")
        print("\nInstall with:")
        print(f"  pip3 install {' '.join(missing)}")
        return False
    return True

def convert_yolo_to_coreml(model_path, output_dir=None, img_size=640, include_nms=True):
    """
    Convert YOLO model to CoreML format

    Args:
        model_path: Path to .pt model file
        output_dir: Output directory (default: same as model_path)
        img_size: Input image size (default: 640)
        include_nms: Include NMS in model (default: True)
    """
    from ultralytics import YOLO

    model_path = Path(model_path)
    if not model_path.exists():
        print(f"Error: Model file not found: {model_path}")
        return False

    if output_dir is None:
        output_dir = model_path.parent
    else:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading YOLO model from: {model_path}")
    try:
        model = YOLO(str(model_path))
    except Exception as e:
        print(f"Error loading model: {e}")
        return False

    print(f"Converting to CoreML (img_size={img_size}, nms={include_nms})...")
    try:
        # Export to CoreML
        # The export function will create the .mlpackage file
        export_path = model.export(
            format='coreml',
            imgsz=img_size,
            nms=include_nms,
            half=False,  # Don't use FP16 for better compatibility
        )
        print(f"✓ Successfully exported to: {export_path}")

        # Get the model name
        model_name = model_path.stem
        mlpackage_path = model_path.parent / f"{model_name}.mlpackage"

        if mlpackage_path.exists():
            print(f"✓ CoreML model package created: {mlpackage_path}")

            # Copy to Flutter app Resources directory
            flutter_resources = Path("/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources")
            if flutter_resources.exists():
                import shutil
                dest = flutter_resources / mlpackage_path.name
                print(f"\nCopying to Flutter app...")
                shutil.copytree(mlpackage_path, dest, dirs_exist_ok=True)
                print(f"✓ Copied to: {dest}")
            else:
                print(f"\nNote: Flutter Resources directory not found at: {flutter_resources}")
                print(f"You'll need to manually copy {mlpackage_path.name} to your app's Resources directory")

        return True

    except Exception as e:
        print(f"Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 convert_yolo_to_coreml.py <model.pt> [output_dir] [img_size]")
        print("\nExample:")
        print("  python3 convert_yolo_to_coreml.py yolo12m.pt")
        print("  python3 convert_yolo_to_coreml.py yolo12m.pt /path/to/output 320")
        sys.exit(1)

    if not check_dependencies():
        sys.exit(1)

    model_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None
    img_size = int(sys.argv[3]) if len(sys.argv) > 3 else 640

    print("="*60)
    print("YOLO to CoreML Conversion")
    print("="*60)

    success = convert_yolo_to_coreml(model_path, output_dir, img_size)

    if success:
        print("\n" + "="*60)
        print("Conversion completed successfully!")
        print("="*60)
        print("\nNext steps:")
        print("1. Rebuild your Flutter app")
        print("2. Run the app and select 'YOLO' or 'Auto' backend")
        print("3. Check console logs for '[YOLO] CoreML detector initialized'")
    else:
        print("\nConversion failed!")
        sys.exit(1)

if __name__ == '__main__':
    main()
