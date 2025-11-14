cmake_minimum_required(VERSION 3.16)
project(eyeball_tracking_core)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(OpenCV REQUIRED)

# Check if OpenCV has DNN module (optional for Windows ARM64)
if(OpenCV_FOUND)
    # Try to include DNN header to check if it's available
    include(CheckIncludeFileCXX)
    set(CMAKE_REQUIRED_INCLUDES ${OpenCV_INCLUDE_DIRS})
    check_include_file_cxx("opencv2/dnn.hpp" HAVE_OPENCV_DNN)

    if(HAVE_OPENCV_DNN)
        message(STATUS "OpenCV DNN module found")
    else()
        message(WARNING "OpenCV DNN module not found - YOLO detection will use ONNX Runtime if available")
    endif()
endif()

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# Source files
set(SOURCES
    src/tracking_engine.cpp
)

# Create shared library
add_library(eyeball_tracking_core SHARED ${SOURCES})

# ONNX Runtime support for Windows ARM64 (alternative to OpenCV DNN)
set(EYETRACKING_HAS_ONNXRUNTIME 0)
if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
    set(ONNXRUNTIME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/onnxruntime/windows-arm64")
    if(EXISTS "${ONNXRUNTIME_DIR}/include")
        message(STATUS "ONNX Runtime found for Windows ARM64")
        set(ONNXRUNTIME_INCLUDE_DIRS "${ONNXRUNTIME_DIR}/include")
        set(ONNXRUNTIME_LIBRARIES "${ONNXRUNTIME_DIR}/lib/onnxruntime.lib")
        target_include_directories(eyeball_tracking_core PRIVATE ${ONNXRUNTIME_INCLUDE_DIRS})
        target_link_libraries(eyeball_tracking_core ${ONNXRUNTIME_LIBRARIES})
        set(EYETRACKING_HAS_ONNXRUNTIME 1)
    else()
        message(WARNING "ONNX Runtime not found - YOLO detection will not be available")
    endif()
endif()

# Provide the default paths to bundled face detection models
set(EYETRACKING_FACE_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/models/face_detection_yunet_2023mar.onnx")
set(EYETRACKING_YOLO_FACE_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/models/yolov5n-face.onnx")
set(EYETRACKING_HAAR_CASCADE "${CMAKE_CURRENT_SOURCE_DIR}/models/haarcascade_frontalface_default.xml")

# Set compile definitions based on available features
target_compile_definitions(eyeball_tracking_core PRIVATE
    EYETRACKING_DEFAULT_FACE_MODEL_PATH=\"${EYETRACKING_FACE_MODEL}\"
    EYETRACKING_DEFAULT_YOLO_FACE_MODEL_PATH=\"${EYETRACKING_YOLO_FACE_MODEL}\"
    EYETRACKING_DEFAULT_HAAR_CASCADE_PATH=\"${EYETRACKING_HAAR_CASCADE}\"
    EYETRACKING_HAS_DNN=$<BOOL:${HAVE_OPENCV_DNN}>
    EYETRACKING_HAS_ONNXRUNTIME=${EYETRACKING_HAS_ONNXRUNTIME}
)

# Link libraries
target_link_libraries(eyeball_tracking_core ${OpenCV_LIBS})

# Platform-specific settings
if(APPLE)
    target_link_libraries(eyeball_tracking_core "-framework Accelerate")
endif()

# Installation
install(TARGETS eyeball_tracking_core
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    FRAMEWORK DESTINATION Frameworks
)

# Install ONNX Runtime DLL for Windows ARM64
if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64" AND EYETRACKING_HAS_ONNXRUNTIME)
    install(FILES "${ONNXRUNTIME_DIR}/lib/onnxruntime.dll"
            DESTINATION bin)
endif()

# Install supporting model assets
install(FILES models/face_detection_yunet_2023mar.onnx
        DESTINATION share/eyeball_tracking/models)
install(FILES models/haarcascade_frontalface_default.xml
        DESTINATION share/eyeball_tracking/models)
if(EXISTS ${EYETRACKING_YOLO_FACE_MODEL})
    install(FILES ${EYETRACKING_YOLO_FACE_MODEL}
            DESTINATION share/eyeball_tracking/models)
endif()

# Include headers
install(DIRECTORY include/ DESTINATION include)
