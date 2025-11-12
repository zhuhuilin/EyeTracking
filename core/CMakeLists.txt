cmake_minimum_required(VERSION 3.16)
project(eyeball_tracking_core)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(OpenCV REQUIRED)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# Source files
set(SOURCES
    src/tracking_engine.cpp
)

# Create shared library
add_library(eyeball_tracking_core SHARED ${SOURCES})

# Provide the default paths to bundled face detection models
set(EYETRACKING_FACE_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/models/face_detection_yunet_2023mar.onnx")
set(EYETRACKING_YOLO_FACE_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/models/yolov5n-face.onnx")
set(EYETRACKING_HAAR_CASCADE "${CMAKE_CURRENT_SOURCE_DIR}/models/haarcascade_frontalface_default.xml")
target_compile_definitions(eyeball_tracking_core PRIVATE
    EYETRACKING_DEFAULT_FACE_MODEL_PATH=\"${EYETRACKING_FACE_MODEL}\"
    EYETRACKING_DEFAULT_YOLO_FACE_MODEL_PATH=\"${EYETRACKING_YOLO_FACE_MODEL}\"
    EYETRACKING_DEFAULT_HAAR_CASCADE_PATH=\"${EYETRACKING_HAAR_CASCADE}\"
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
