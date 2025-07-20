cmake_minimum_required(VERSION 3.10)
project(nsys_profiling_poc VERSION 1.0.0 LANGUAGES CXX)

# Add the cpp subdirectory
add_subdirectory(cpp)

# Custom target for profiling (delegates to Makefile)
add_custom_target(profile
    COMMAND ${CMAKE_COMMAND} -E echo "Running profiling via Makefile..."
    COMMAND make -f ${CMAKE_SOURCE_DIR}/Makefile profile
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Profiling all examples"
)

# Custom target for analysis
add_custom_target(analyze
    COMMAND ${CMAKE_COMMAND} -E echo "Running analysis via Makefile..."
    COMMAND make -f ${CMAKE_SOURCE_DIR}/Makefile analyze
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Analyzing profiling results"
)