#!/bin/bash
# Profile all Python and C++ examples with various nsys configurations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p results

# Use virtual environment Python if available
if [ -f "venv/bin/python" ]; then
    PYTHON_CMD="venv/bin/python"
else
    PYTHON_CMD="python3"
fi

echo -e "${GREEN}NVIDIA Nsight Systems CPU Profiling - Full Suite${NC}"
echo "=================================================="
echo ""

# Function to check if nsys is available
check_nsys() {
    if ! command -v nsys &> /dev/null; then
        echo -e "${RED}Error: nsys command not found!${NC}"
        echo "Please ensure NVIDIA Nsight Systems is installed and in your PATH."
        exit 1
    fi
}

# Function to profile a command
profile_command() {
    local name=$1
    local command=$2
    local options=$3
    
    echo -e "\n${YELLOW}Profiling: $name${NC}"
    echo "Command: $command"
    echo "Options: $options"
    
    nsys profile $options -o "results/$name" $command
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
}

# Check prerequisites
check_nsys

# Python Examples
echo -e "\n${GREEN}=== Python Examples ===${NC}"

# Basic CPU profiling
profile_command "py_1_basic_cpu" \
    "$PYTHON_CMD python/1_basic_cpu_profiling.py" \
    "--sample=cpu --trace=osrt"

# Matrix operations with CPU sampling
profile_command "py_2_matrix_ops" \
    "$PYTHON_CMD python/2_matrix_operations.py" \
    "--sample=cpu --trace=osrt,nvtx"

# Multiprocessing with context switches
profile_command "py_3_multiprocessing" \
    "$PYTHON_CMD python/3_multiprocessing_example.py" \
    "--sample=cpu --cpuctxsw=true --trace=osrt"

# NVTX annotations (if available)
profile_command "py_4_nvtx" \
    "$PYTHON_CMD python/4_nvtx_annotations.py" \
    "--trace=nvtx,osrt --sample=cpu"

# I/O bound operations
profile_command "py_5_io_bound" \
    "$PYTHON_CMD python/5_io_bound_example.py" \
    "--trace=osrt --sample=cpu"

# C++ Examples (build first if needed)
echo -e "\n${GREEN}=== Building C++ Examples ===${NC}"
make all

echo -e "\n${GREEN}=== C++ Examples ===${NC}"

# Basic CPU profiling
profile_command "cpp_1_basic_cpu" \
    "cpp/bin/1_basic_cpu_profiling" \
    "--sample=cpu --trace=osrt"

# Matrix operations with detailed sampling
profile_command "cpp_2_matrix_ops" \
    "cpp/bin/2_matrix_operations" \
    "--sample=cpu --trace=osrt"

# Multithreading with context switches
profile_command "cpp_3_multithreading" \
    "cpp/bin/3_multithreading_example" \
    "--sample=cpu --cpuctxsw=true --trace=osrt"

# NVTX annotations
profile_command "cpp_4_nvtx" \
    "cpp/bin/4_nvtx_annotations" \
    "--trace=nvtx,osrt --sample=cpu"

# Memory intensive operations
profile_command "cpp_5_memory" \
    "cpp/bin/5_memory_intensive" \
    "--sample=cpu --trace=osrt"

echo -e "\n${GREEN}=== Profiling Complete ===${NC}"
echo "Results saved in the 'results' directory"
echo ""
echo "To view results:"
echo "  - GUI: nsys-ui results/<profile_name>.nsys-rep"
echo "  - CLI: nsys stats results/<profile_name>.nsys-rep"
echo ""
echo "To generate reports, run: ./scripts/analyze_results.sh"