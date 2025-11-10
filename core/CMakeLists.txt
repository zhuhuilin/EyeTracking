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

# Include headers
install(DIRECTORY include/ DESTINATION include)
