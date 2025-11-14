# CMake Toolchain File for iOS
# This file configures CMake to build for iOS (both device and simulator)

set(CMAKE_SYSTEM_NAME iOS)

# Set iOS SDK (will be overridden by build scripts for simulator vs device)
# Values: iphoneos (device), iphonesimulator (simulator)
if(NOT DEFINED CMAKE_OSX_SYSROOT)
    set(CMAKE_OSX_SYSROOT "iphoneos")
endif()

# Architecture
# Device: arm64
# Simulator: x86_64 (Intel Macs) or arm64 (Apple Silicon Macs)
if(NOT DEFINED CMAKE_OSX_ARCHITECTURES)
    if(CMAKE_OSX_SYSROOT MATCHES "simulator")
        set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64")
    else()
        set(CMAKE_OSX_ARCHITECTURES "arm64")
    endif()
endif()

# Minimum iOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum iOS deployment version")

# Compiler settings
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build static libraries for iOS
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries for iOS")

# Disable code signing for library builds
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO")
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")

# Optimization
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# OpenCV for iOS
# Expected location: core/dependencies/ios/OpenCV.framework
set(OPENCV_IOS_DIR "${CMAKE_CURRENT_LIST_DIR}/../dependencies/ios")
if(EXISTS "${OPENCV_IOS_DIR}/OpenCV.framework")
    set(OpenCV_DIR "${OPENCV_IOS_DIR}/OpenCV.framework")
    message(STATUS "Found OpenCV framework for iOS: ${OpenCV_DIR}")
else()
    message(WARNING "OpenCV framework not found at ${OPENCV_IOS_DIR}/OpenCV.framework")
    message(WARNING "Please download OpenCV for iOS and place it in core/dependencies/ios/")
endif()

message(STATUS "Configured toolchain for iOS")
message(STATUS "  SDK: ${CMAKE_OSX_SYSROOT}")
message(STATUS "  Architectures: ${CMAKE_OSX_ARCHITECTURES}")
message(STATUS "  Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
