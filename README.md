# NVIDIA Nsight Systems CPU Profiling POC

This repository contains a comprehensive proof-of-concept (POC) demonstrating how to use NVIDIA Nsight Systems (nsys) for CPU profiling of Python and C++ applications. The examples explore various CPU-intensive workloads, memory access patterns, parallelism, and custom instrumentation.

## Overview

NVIDIA Nsight Systems is a system-wide performance analysis tool designed to visualize application algorithms, identify optimization opportunities, and scale efficiently across CPUs and GPUs. This POC focuses specifically on CPU profiling capabilities.

## Repository Structure

```
profiling-poc/
├── python/                      # Python examples
│   ├── 1_basic_cpu_profiling.py     # Basic CPU-intensive operations
│   ├── 2_matrix_operations.py       # Matrix operations and algorithms
│   ├── 3_multiprocessing_example.py # Multiprocessing patterns
│   ├── 4_nvtx_annotations.py        # Custom NVTX markers
│   └── 5_io_bound_example.py        # I/O bound operations
├── cpp/                         # C++ examples
│   ├── 1_basic_cpu_profiling.cpp    # Basic CPU-intensive operations
│   ├── 2_matrix_operations.cpp      # Matrix operations with optimizations
│   ├── 3_multithreading_example.cpp # Multithreading patterns
│   ├── 4_nvtx_annotations.cpp       # Custom NVTX markers
│   └── 5_memory_intensive.cpp       # Memory access patterns
├── scripts/                     # Profiling and analysis scripts
│   ├── profile_all.sh              # Profile all examples
│   ├── analyze_results.sh          # Analyze profiling results
│   └── compare_results.py          # Compare Python vs C++ performance
├── results/                     # Profiling results (generated)
├── Makefile                     # Build system for C++ examples
└── README.md                    # This file
```

## Prerequisites

### Required Software

1. **NVIDIA Nsight Systems**
   - Download from: https://developer.nvidia.com/nsight-systems
   - Ensure `nsys` command is in your PATH

2. **Python 3.7+**
   - NumPy: `pip install numpy`
   - (Optional) nvtx: `pip install nvtx`
   - (Optional) aiofiles: `pip install aiofiles`
   - (Optional) matplotlib: `pip install matplotlib`

3. **C++ Build Tools**
   - CMake 3.10+
   - GCC 7+ or Clang 8+ with C++17 support
   - pthread support
   - (Optional) CUDA Toolkit for NVTX support

### System Requirements

- Linux (x86_64 or ARM64)
- Root access may be required for certain profiling features
- At least 4GB RAM recommended
- Multi-core CPU for parallel examples

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository>
cd profiling-poc
```

### 2. Setup Python Environment

```bash
# Create and activate virtual environment
./setup_venv.sh

# Or manually:
python3 -m venv venv
source venv/bin/activate  # On Linux/Mac
# venv\Scripts\activate   # On Windows

# Install dependencies
pip install -r requirements.txt
```

### 3. Build C++ Examples

The project uses CMake for building C++ examples:

```bash
make all          # Uses CMake internally
```

For more control over the build:
```bash
# Debug build
CMAKE_BUILD_TYPE=Debug make all

# Release with debug info
CMAKE_BUILD_TYPE=RelWithDebInfo make all

# Build with NVTX support (requires CUDA Toolkit)
make nvtx

# Build with different optimization levels for comparison
make build-opt-comparison
```

### 4. Run Basic Profiling

Profile all examples:
```bash
./scripts/profile_all.sh
```

Or use the enhanced Makefile (see [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) for all options):
```bash
# Profile everything
make profile

# Profile with advanced options
make advanced-workflow
```

Profile a specific example:
```bash
# Python example
nsys profile --sample=cpu --trace=osrt -o results/py_basic python python/1_basic_cpu_profiling.py

# C++ example
nsys profile --sample=cpu --trace=osrt -o results/cpp_basic build/bin/1_basic_cpu_profiling
```

### 5. Analyze Results

Generate analysis reports:
```bash
./scripts/analyze_results.sh
```

Compare Python vs C++ performance:
```bash
python scripts/compare_results.py
```

### 6. View Results

GUI visualization:
```bash
nsys-ui results/<profile_name>.nsys-rep
```

Command-line statistics:
```bash
nsys stats results/<profile_name>.nsys-rep
```

## Examples Overview

### Python Examples

1. **Basic CPU Profiling** (`1_basic_cpu_profiling.py`)
   - Fibonacci calculations (recursive vs iterative)
   - Prime number generation (Sieve of Eratosthenes)
   - Matrix multiplication
   - Mathematical computations
   - String operations

2. **Matrix Operations** (`2_matrix_operations.py`)
   - Naive vs optimized multiplication
   - NumPy operations comparison
   - Strassen's algorithm
   - Block matrix multiplication
   - 2D convolution

3. **Multiprocessing** (`3_multiprocessing_example.py`)
   - Process pool patterns
   - Shared memory usage
   - Producer-consumer pattern
   - Concurrent.futures comparison
   - Work stealing simulation

4. **NVTX Annotations** (`4_nvtx_annotations.py`)
   - Function-level annotations
   - Nested ranges
   - Custom domains and colors
   - Context manager usage
   - Performance comparison with markers

5. **I/O Bound Operations** (`5_io_bound_example.py`)
   - File I/O patterns
   - Structured data formats (JSON, CSV, SQLite)
   - Concurrent I/O
   - Async I/O patterns
   - Network I/O simulation

### C++ Examples

1. **Basic CPU Profiling** (`1_basic_cpu_profiling.cpp`)
   - Algorithm comparisons
   - Sorting algorithms
   - Dynamic programming
   - Hash table operations
   - STL usage patterns

2. **Matrix Operations** (`2_matrix_operations.cpp`)
   - Cache-optimized multiplication
   - SIMD optimization (AVX)
   - Strassen's algorithm
   - Convolution operations
   - Memory layout effects

3. **Multithreading** (`3_multithreading_example.cpp`)
   - Thread pool implementation
   - Mutex contention analysis
   - Lock-free programming
   - False sharing demonstration
   - Work stealing pattern

4. **NVTX Annotations** (`4_nvtx_annotations.cpp`)
   - RAII-based range management
   - Color-coded profiling
   - Nested annotations
   - Domain separation
   - Integration with timers

5. **Memory Intensive** (`5_memory_intensive.cpp`)
   - Sequential vs random access
   - Cache line effects
   - Memory allocation patterns
   - Bandwidth measurements
   - NUMA effects simulation

## Key nsys Commands

### Basic CPU Profiling
```bash
nsys profile --sample=cpu --trace=osrt -o output.nsys-rep ./program
```

### With Context Switches
```bash
nsys profile --sample=cpu --cpuctxsw=true --trace=osrt -o output.nsys-rep ./program
```

### NVTX Tracing
```bash
nsys profile --trace=nvtx,osrt --sample=cpu -o output.nsys-rep ./program
```

### Python Profiling
```bash
nsys profile --trace=osrt,nvtx --sample=cpu --delay=60 python script.py
```

### Generate Statistics
```bash
nsys stats output.nsys-rep
```

### Detailed Analysis
```bash
nsys analyze --report cpusampling output.nsys-rep
```

## Performance Insights

### What to Look For

1. **CPU Sampling**
   - Hot functions consuming most CPU time
   - Call stack analysis
   - Instruction-level bottlenecks

2. **Context Switches**
   - Thread/process scheduling overhead
   - Lock contention
   - I/O wait patterns

3. **Memory Patterns**
   - Cache misses
   - Memory bandwidth utilization
   - False sharing effects

4. **Parallelism**
   - CPU utilization across cores
   - Load balancing
   - Synchronization overhead

### Common Optimization Opportunities

1. **Algorithm Selection**
   - Choose appropriate algorithms for data size
   - Consider cache-friendly implementations
   - Use vectorization where possible

2. **Memory Access**
   - Optimize data structure layout
   - Improve cache locality
   - Reduce memory allocations

3. **Parallelism**
   - Minimize synchronization
   - Balance work distribution
   - Avoid false sharing

4. **I/O Operations**
   - Batch operations
   - Use async I/O
   - Optimize buffer sizes

## Build System

The project uses a hybrid build system:
- **CMake**: For portable C++ compilation with automatic dependency detection
- **Makefile**: For workflow automation, profiling, and analysis

For detailed information about all Makefile targets and advanced workflows, see [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md).

### CMake Build Options

```bash
# Configure with custom options
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_NVTX=ON
make

# Or use the wrapper Makefile
make cmake-configure-nvtx
```

### Build Directories
- `build/`: CMake build directory
- `build/bin/`: Compiled C++ executables
- `results/`: Profiling results
- `results/reports/`: Analysis reports

## Troubleshooting

### Build Issues
```bash
# Clean and rebuild
make clean
make all

# Reconfigure CMake
make clean-cmake
make cmake-configure
```

### Permission Issues

CPU sampling requires appropriate permissions. If you see warnings about CPU sampling not being supported:

```bash
# Check your system's paranoid level
cat /proc/sys/kernel/perf_event_paranoid

# Option 1: Use sudo (recommended for testing)
sudo $(which nsys) profile --sample=cpu ./program

# Option 2: Temporarily lower paranoid level (requires root)
echo 1 | sudo tee /proc/sys/kernel/perf_event_paranoid

# Option 3: Use the helper script
./scripts/nsys_with_sudo.sh profile --sample=cpu ./program
```

Note: Without CPU sampling, nsys will still collect OS runtime traces, NVTX markers, and other metrics.

### Missing NVTX
```bash
# Install CUDA Toolkit or use dummy implementation
make all  # Builds without NVTX
make nvtx # Requires CUDA Toolkit
```

### Large Profile Files
```bash
# Limit profiling duration
nsys profile --duration=10 ./program

# Or use delay
nsys profile --delay=60 --duration=30 ./program
```

## Advanced Usage

### Custom NVTX Domains
```python
import nvtx

# Create custom domain
domain = nvtx.Domain("MyApp")

# Use domain-specific ranges
with nvtx.Range("Processing", domain=domain):
    process_data()
```

### Profiling Specific Functions
```cpp
// C++ with manual instrumentation
void hot_function() {
    nvtxRangePushA("hot_function");
    // ... work ...
    nvtxRangePop();
}
```

### Remote Profiling
```bash
# On target machine
nsys profile --capture-range=cudaProfilerApi ./program

# Transfer .nsys-rep file to host for analysis
```

## Contributing

Feel free to add more examples or improve existing ones. Key areas for expansion:

1. GPU profiling examples
2. MPI applications
3. Real-world application patterns
4. Additional optimization techniques

## References

- [NVIDIA Nsight Systems Documentation](https://docs.nvidia.com/nsight-systems/)
- [NVTX Documentation](https://docs.nvidia.com/nvtx/)
- [CPU Profiling Best Practices](https://developer.nvidia.com/blog/nvidia-nsight-systems/)

## License

This POC is provided as-is for educational purposes. Feel free to use and modify for your profiling needs.