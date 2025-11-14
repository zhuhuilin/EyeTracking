# CMake Toolchain File for macOS
# This file configures CMake to build universal binaries for macOS (Apple Silicon + Intel)

set(CMAKE_SYSTEM_NAME Darwin)

# Build universal binary supporting both ARM64 (Apple Silicon) and x86_64 (Intel)
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64")

# Set minimum macOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS deployment version")

# Compiler flags
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization flags
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Link against Accelerate framework for optimized linear algebra
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Accelerate")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -framework Accelerate")

# OpenCV detection
# Prefer Homebrew installation
if(EXISTS "/opt/homebrew/opt/opencv")
    # Apple Silicon Homebrew path
    set(OpenCV_DIR "/opt/homebrew/opt/opencv/lib/cmake/opencv4")
elseif(EXISTS "/usr/local/opt/opencv")
    # Intel Mac Homebrew path
    set(OpenCV_DIR "/usr/local/opt/opencv/lib/cmake/opencv4")
endif()

message(STATUS "Configured toolchain for macOS Universal Binary")
message(STATUS "  Architectures: ${CMAKE_OSX_ARCHITECTURES}")
message(STATUS "  Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
if(OpenCV_DIR)
    message(STATUS "  OpenCV Hint: ${OpenCV_DIR}")
endif()
