# CMake Toolchain File for Android
# This file configures CMake to build for Android using Android NDK

# Android NDK path (should be set as environment variable or passed via -DANDROID_NDK=path)
if(NOT DEFINED ANDROID_NDK AND DEFINED ENV{ANDROID_NDK})
    set(ANDROID_NDK $ENV{ANDROID_NDK})
endif()

if(NOT DEFINED ANDROID_NDK)
    message(FATAL_ERROR "ANDROID_NDK not set. Please set ANDROID_NDK environment variable or pass -DANDROID_NDK=path")
endif()

# Use Android NDK's toolchain file
set(CMAKE_TOOLCHAIN_FILE "${ANDROID_NDK}/build/cmake/android.toolchain.cmake")

# Android platform (API level)
if(NOT DEFINED ANDROID_PLATFORM)
    set(ANDROID_PLATFORM "android-21" CACHE STRING "Android API level")
endif()

# Android ABI (will be set by build script for each ABI)
# Supported: arm64-v8a, armeabi-v7a, x86, x86_64
if(NOT DEFINED ANDROID_ABI)
    set(ANDROID_ABI "arm64-v8a" CACHE STRING "Android ABI")
endif()

# STL implementation
if(NOT DEFINED ANDROID_STL)
    set(ANDROID_STL "c++_shared" CACHE STRING "Android STL")
endif()

# Compiler settings
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build shared libraries for Android
set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries for Android")

# Optimization
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# OpenCV for Android
# Expected location: core/dependencies/android/OpenCV-android-sdk
set(OPENCV_ANDROID_SDK "${CMAKE_CURRENT_LIST_DIR}/../dependencies/android/OpenCV-android-sdk")
if(EXISTS "${OPENCV_ANDROID_SDK}/sdk/native/jni")
    set(OpenCV_DIR "${OPENCV_ANDROID_SDK}/sdk/native/jni")
    message(STATUS "Found OpenCV Android SDK: ${OpenCV_DIR}")
else()
    message(WARNING "OpenCV Android SDK not found at ${OPENCV_ANDROID_SDK}")
    message(WARNING "Please download OpenCV Android SDK and place it in core/dependencies/android/")
endif()

message(STATUS "Configured toolchain for Android")
message(STATUS "  NDK: ${ANDROID_NDK}")
message(STATUS "  Platform: ${ANDROID_PLATFORM}")
message(STATUS "  ABI: ${ANDROID_ABI}")
message(STATUS "  STL: ${ANDROID_STL}")
