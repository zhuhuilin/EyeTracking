# ONNX Runtime Integration for Windows ARM64

## Overview

Due to OpenCV DNN module not compiling on Windows ARM64 (uses unsupported `__fp16` type), we use a hybrid approach:
- **OpenCV (core)**: Basic image processing + Haar Cascade face detection
- **ONNX Runtime**: YOLO model inference (native ARM64 support)

## Setup

### Directory Structure

```
core/
├── dependencies/
│   └── onnxruntime/
│       └── windows-arm64/         # ONNX Runtime 1.20.1
│           ├── include/
│           ├── lib/
│           │   └── onnxruntime.dll
│           └── ...
├── models/
│   ├── haarcascade_frontalface_default.xml  # Haar Cascade (works)
│   ├── face_detection_yunet_2023mar.onnx    # YuNet (needs ONNX Runtime)
│   └── yolov5n-face.onnx                    # YOLO (needs ONNX Runtime)
```

### CMakeLists.txt Changes Needed

```cmake
# Find ONNX Runtime
if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
    set(ONNXRUNTIME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/onnxruntime/windows-arm64")
    set(ONNXRUNTIME_INCLUDE_DIRS "${ONNXRUNTIME_DIR}/include")
    set(ONNXRUNTIME_LIBRARIES "${ONNXRUNTIME_DIR}/lib/onnxruntime.lib")
    target_include_directories(eyeball_tracking_core PRIVATE ${ONNXRUNTIME_INCLUDE_DIRS})
    target_link_libraries(eyeball_tracking_core ${ONNXRUNTIME_LIBRARIES})
    target_compile_definitions(eyeball_tracking_core PRIVATE EYETRACKING_HAS_ONNXRUNTIME=1)
else()
    target_compile_definitions(eyeball_tracking_core PRIVATE EYETRACKING_HAS_ONNXRUNTIME=0)
endif()
```

### Code Changes Needed

#### tracking_engine.h

```cpp
#ifndef EYETRACKING_HAS_ONNXRUNTIME
#define EYETRACKING_HAS_ONNXRUNTIME 0
#endif

#if EYETRACKING_HAS_ONNXRUNTIME
#include <onnxruntime_cxx_api.h>
#endif

class TrackingEngine {
    // ...
private:
#if EYETRACKING_HAS_ONNXRUNTIME
    std::unique_ptr<Ort::Env> ort_env_;
    std::unique_ptr<Ort::Session> yolo_session_;
    bool yolo_session_loaded_;
#endif
};
```

#### tracking_engine.cpp

Replace `detectFaceWithYolo()` implementation:

```cpp
cv::Rect TrackingEngine::detectFaceWithYolo(const cv::Mat& frame) {
#if EYETRACKING_HAS_ONNXRUNTIME
    if (!yolo_session_loaded_) {
        if (!ensureYoloSession()) {
            return cv::Rect();  // Fall back to Haar Cascade
        }
    }

    // Preprocess frame for YOLO
    cv::Mat blob;
    cv::dnn::blobFromImage(frame, blob, 1/255.0, cv::Size(640, 640), cv::Scalar(), true, false);

    // Run ONNX Runtime inference
    auto memory_info = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    std::vector<int64_t> input_shape = {1, 3, 640, 640};
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(
        memory_info,
        (float*)blob.data,
        blob.total(),
        input_shape.data(),
        input_shape.size()
    );

    const char* input_names[] = {"images"};
    const char* output_names[] = {"output0"};

    auto output_tensors = yolo_session_->Run(
        Ort::RunOptions{nullptr},
        input_names, &input_tensor, 1,
        output_names, 1
    );

    // Post-process YOLO output
    // ... (parse detections, apply NMS, return best face bbox)

#else
    // ONNX Runtime not available - fall back to Haar Cascade
    return detectFaceWithCascade(frame);
#endif
}

bool TrackingEngine::ensureYoloSession() {
#if EYETRACKING_HAS_ONNXRUNTIME
    if (yolo_session_loaded_) return true;

    try {
        ort_env_ = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "EyeTracking");

        Ort::SessionOptions session_options;
        session_options.SetIntraOpNumThreads(1);
        session_options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_EXTENDED);

        std::string model_path = resolveYoloModelPath();
        yolo_session_ = std::make_unique<Ort::Session>(*ort_env_, model_path.c_str(), session_options);

        yolo_session_loaded_ = true;
        return true;
    } catch (const Ort::Exception& e) {
        std::cerr << "ONNX Runtime error: " << e.what() << std::endl;
        return false;
    }
#else
    return false;
#endif
}
```

## Deployment

When building for Windows ARM64, copy `onnxruntime.dll` to the output directory:

```cmake
if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
    install(FILES ${ONNXRUNTIME_DIR}/lib/onnxruntime.dll
            DESTINATION bin)
endif()
```

## Benefits

1. **Native ARM64 Support**: ONNX Runtime is optimized for ARM64 Windows
2. **DirectML Acceleration**: Can use GPU/NPU acceleration
3. **No Compilation Issues**: Pre-built binaries, no source compilation needed
4. **Fallback Support**: Gracefully falls back to Haar Cascades if ONNX Runtime unavailable

## Next Steps

1. Update `CMakeLists.txt` with ONNX Runtime linking
2. Modify `tracking_engine.h` to conditionally include ONNX Runtime
3. Implement `ensureYoloSession()` and update `detectFaceWithYolo()`
4. Test with a simple YOLO model first
5. Expand to support multiple model variants (n, s, m, l, x)
