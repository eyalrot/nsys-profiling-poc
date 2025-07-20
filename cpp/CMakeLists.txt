cmake_minimum_required(VERSION 3.10)
project(nsys_profiling_examples VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo" "MinSizeRel")
endif()

# Compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -pthread")
set(CMAKE_CXX_FLAGS_DEBUG "-g -O0")
set(CMAKE_CXX_FLAGS_RELEASE "-O2 -march=native")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-O2 -g -march=native")

# Output directory
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Find required packages
find_package(Threads REQUIRED)

# Check for AVX2 support (for matrix operations)
include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-mavx2" COMPILER_SUPPORTS_AVX2)

# NVTX support (optional)
option(USE_NVTX "Enable NVTX support (requires CUDA toolkit)" OFF)
if(USE_NVTX)
    find_path(NVTX_INCLUDE_DIR nvToolsExt.h
        HINTS
        $ENV{CUDA_HOME}/include
        /usr/local/cuda/include
        /opt/cuda/include
    )
    
    find_library(NVTX_LIBRARY nvToolsExt
        HINTS
        $ENV{CUDA_HOME}/lib64
        $ENV{CUDA_HOME}/lib
        /usr/local/cuda/lib64
        /usr/local/cuda/lib
        /opt/cuda/lib64
        /opt/cuda/lib
    )
    
    if(NVTX_INCLUDE_DIR AND NVTX_LIBRARY)
        message(STATUS "NVTX found: ${NVTX_LIBRARY}")
        set(NVTX_FOUND TRUE)
    else()
        message(WARNING "NVTX not found. Building without NVTX support.")
        set(NVTX_FOUND FALSE)
    endif()
endif()

# Define executables
set(EXAMPLES
    1_basic_cpu_profiling
    2_matrix_operations
    3_multithreading_example
    4_nvtx_annotations
    5_memory_intensive
)

# Build each example
foreach(example ${EXAMPLES})
    add_executable(${example} ${example}.cpp)
    target_link_libraries(${example} PRIVATE Threads::Threads)
    
    # Special handling for specific examples
    if(${example} STREQUAL "2_matrix_operations")
        if(COMPILER_SUPPORTS_AVX2)
            target_compile_options(${example} PRIVATE -mavx2)
        endif()
    endif()
    
    if(${example} STREQUAL "4_nvtx_annotations")
        if(NVTX_FOUND AND USE_NVTX)
            target_compile_definitions(${example} PRIVATE USE_NVTX)
            target_include_directories(${example} PRIVATE ${NVTX_INCLUDE_DIR})
            target_link_libraries(${example} PRIVATE ${NVTX_LIBRARY})
            
            # Also create NVTX-enabled version with different name
            add_executable(${example}_nvtx ${example}.cpp)
            target_compile_definitions(${example}_nvtx PRIVATE USE_NVTX)
            target_include_directories(${example}_nvtx PRIVATE ${NVTX_INCLUDE_DIR})
            target_link_libraries(${example}_nvtx PRIVATE Threads::Threads ${NVTX_LIBRARY})
        endif()
    endif()
endforeach()

# Custom target to build with different optimization levels
add_custom_target(build-opt-comparison
    COMMAND ${CMAKE_COMMAND} -E echo "Building with different optimization levels..."
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/opt_comparison
)

foreach(opt_level O0 O1 O2 O3 Os)
    add_custom_command(TARGET build-opt-comparison
        COMMAND ${CMAKE_COMMAND} -E echo "Building with -${opt_level}..."
        COMMAND ${CMAKE_CXX_COMPILER} -${opt_level} -g -std=c++17 -pthread 
                ${CMAKE_CURRENT_SOURCE_DIR}/1_basic_cpu_profiling.cpp
                -o ${CMAKE_BINARY_DIR}/opt_comparison/1_basic_cpu_profiling_${opt_level}
    )
endforeach()

# Print configuration summary
message(STATUS "")
message(STATUS "Configuration Summary:")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "  C++ Flags: ${CMAKE_CXX_FLAGS}")
message(STATUS "  AVX2 Support: ${COMPILER_SUPPORTS_AVX2}")
message(STATUS "  NVTX Support: ${NVTX_FOUND}")
message(STATUS "  Output Directory: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
message(STATUS "")

# Installation rules (optional)
install(TARGETS ${EXAMPLES}
    RUNTIME DESTINATION bin
)

# Add a target to clean build artifacts
add_custom_target(clean-all
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/opt_comparison
    COMMAND ${CMAKE_COMMAND} -E echo "Cleaned all build artifacts"
)