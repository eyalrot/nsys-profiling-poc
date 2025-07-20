# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an NVIDIA Nsight Systems CPU profiling proof-of-concept repository that demonstrates performance analysis techniques for both Python and C++ code. The project uses nsys (NVIDIA's system-wide performance analysis tool) to profile CPU-intensive operations, memory patterns, parallelism, and I/O operations.

## Key Commands

### Environment Setup
```bash
# Setup Python virtual environment
./setup_venv.sh
# Or manually:
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**IMPORTANT**: Always activate the virtual environment before running any Python scripts:
```bash
source venv/bin/activate
```

### Build Commands
```bash
# Build all C++ examples (uses CMake internally)
make all

# Build with NVTX support (requires CUDA Toolkit)
make nvtx

# Build with different optimization levels
CMAKE_BUILD_TYPE=Debug make all
CMAKE_BUILD_TYPE=RelWithDebInfo make all
```

### Profiling Commands
```bash
# Profile all examples
make profile

# Profile specific categories
make profile-cpp
make profile-python
make profile-cpu-detailed
make profile-memory

# Custom profiling
make profile-custom TARGET=build/bin/1_basic_cpu_profiling OPTS='--duration=10'

# Interactive profiling workflow
make advanced-workflow
```

### Analysis Commands
```bash
# Run all analysis types
make analyze

# Generate visual HTML report
make analyze-visual

# View results in GUI
make view PROFILE=cpp_1_basic_cpu_profiling

# Quick terminal view
make quick-view PROFILE=py_matrix_operations
```

### Testing and Verification
```bash
# Run all examples without profiling
make run

# Test environment setup (activate venv first!)
source venv/bin/activate
python test_environment.py

# Check nsys installation
make check-nsys
```

### Development Commands
```bash
# Lint Python code (activate venv first if dev dependencies installed)
source venv/bin/activate
black python/
flake8 python/

# Clean build artifacts
make clean
make clean-results
```

## Architecture and Design Patterns

### Hybrid Build System
- **CMake**: Handles C++ compilation with automatic dependency detection, NVTX support detection, and optimization flags
- **Makefile**: Provides workflow automation, profiling targets, and analysis pipelines. The Makefile wraps CMake for C++ builds.

### Profiling Examples Structure
Each numbered example (1-5) in both Python and C++ demonstrates specific profiling scenarios:
1. **Basic CPU profiling**: Algorithm comparison, computational complexity
2. **Matrix operations**: Cache optimization, SIMD usage, algorithmic improvements
3. **Multiprocessing/Multithreading**: Parallelism patterns, synchronization overhead
4. **NVTX annotations**: Custom profiling markers for fine-grained analysis
5. **Memory/I/O intensive**: Memory access patterns, I/O optimization

### Key Technical Considerations

1. **Virtual Environment**: Always activate the virtual environment (`source venv/bin/activate`) before running any Python scripts or commands. This ensures all dependencies are available.

2. **Python Multiprocessing**: Functions used with multiprocessing.Pool must be defined at module level (not lambdas or nested functions) to be picklable.

3. **NVTX API**: Use `nvtx.annotate()` as a context manager, not `nvtx.push_range()` which doesn't return a context manager.

4. **Integer String Limits**: Python 3.10+ requires `sys.set_int_max_str_digits()` for very large integers (e.g., Fibonacci calculations).

5. **Build Output**: CMake outputs binaries to `build/bin/`, not `build/cpp/bin/`.

6. **Async I/O**: Avoid creating nested event loops in async functions - use `await` directly instead of `loop.run_until_complete()`.

### Profiling Best Practices

1. **nsys Options**:
   - Basic: `--sample=cpu --trace=osrt`
   - Python: `--trace=osrt,nvtx --sample=cpu` (note: 'python' trace removed in newer nsys versions)
   - Detailed: `--sample=cpu --cpuctxsw=true --trace=osrt,nvtx,cuda`
   
2. **CPU Sampling Permission Issues**:
   - CPU sampling requires root or lowered kernel paranoid level
   - Quick fix: Run `./scripts/setup_cpu_profiling.sh`
   - Manual temporary fix: `echo 1 | sudo tee /proc/sys/kernel/perf_event_paranoid`
   - Permanent fix: 
     ```bash
     echo 'kernel.perf_event_paranoid = 1' | sudo tee /etc/sysctl.d/99-perf.conf
     sudo sysctl -p /etc/sysctl.d/99-perf.conf
     ```
   - Without CPU sampling, nsys still collects useful OS runtime and NVTX data

3. **Performance Analysis Flow**:
   - Start with `make profile` for baseline
   - Use `make analyze-visual` for overview
   - Drill down with `make profile-cpu-detailed` or `make profile-memory`
   - Compare implementations with `make analyze-compare`

3. **Common Bottlenecks to Check**:
   - Hot functions in CPU sampling
   - Context switch overhead in parallel code
   - Memory access patterns and cache misses
   - I/O wait times and syscall patterns

## Important Files

- **MAKEFILE_GUIDE.md**: Comprehensive guide to all Makefile targets and workflows
- **requirements.txt**: Python dependencies including numpy, nvtx, aiofiles
- **pyproject.toml**: Modern Python package configuration with dev dependencies
- **scripts/**: Profiling and analysis automation scripts
- **results/**: Generated profiling data (excluded from git)

## Git Configuration

- User: Eyal Rot
- Email: eyalr.rot1@gmail.com
- Repository: https://github.com/eyalrot/nsys-profiling-poc