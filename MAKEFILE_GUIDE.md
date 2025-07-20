# Enhanced Makefile Guide for NVIDIA Nsight Systems Profiling

This guide provides detailed information about the enhanced Makefile targets for profiling, viewing, and analyzing CPU performance with NVIDIA Nsight Systems.

## Quick Start Workflows

### 1. Basic Profiling Workflow
```bash
# Build all examples
make all

# Profile everything
make profile

# Analyze results
make analyze

# View visual report
firefox results/reports/profiling_report.html
```

### 2. Python vs C++ Comparison
```bash
# Profile both Python and C++ implementations
make profile-cpp profile-python

# Generate comparison analysis
make analyze-compare analyze-visual

# View specific results
make view PROFILE=cpp_1_basic_cpu_profiling
```

### 3. Advanced Interactive Workflow
```bash
# Launch interactive menu with guided workflows
make advanced-workflow
```

## Detailed Target Reference

### Build Targets

| Target | Description | Example |
|--------|-------------|---------|
| `all` / `cpp-all` | Build all C++ examples | `make all` |
| `nvtx` | Build with NVTX support (requires CUDA) | `make nvtx` |
| Individual targets | Build specific example | `make cpp/bin/1_basic_cpu_profiling` |

### Run Targets (No Profiling)

| Target | Description | Example |
|--------|-------------|---------|
| `run` | Run all examples | `make run` |
| `run-cpp` | Run C++ examples only | `make run-cpp` |
| `run-python` | Run Python examples only | `make run-python` |

### Basic Profiling Targets

| Target | Description | Nsys Options Used |
|--------|-------------|-------------------|
| `profile` | Profile all examples | `--sample=cpu --trace=osrt,nvtx` |
| `profile-cpp` | Profile C++ examples | `--sample=cpu --trace=osrt,nvtx` |
| `profile-python` | Profile Python examples | `--trace=osrt,nvtx,python --sample=cpu` |

### Advanced Profiling Targets

| Target | Description | Special Focus |
|--------|-------------|---------------|
| `profile-cpu-detailed` | Detailed CPU profiling | Context switches, thread states |
| `profile-memory` | Memory pattern analysis | Memory access, cache behavior |
| `profile-advanced` | All available metrics | GPU metrics, CUDA, cuDNN, cuBLAS |
| `profile-custom` | Custom profiling | User-defined options |

#### Custom Profiling Example
```bash
# Profile with custom duration and specific traces
make profile-custom TARGET=cpp/bin/2_matrix_operations \
     OPTS='--duration=20 --sample=cpu --cpuctxsw=true'
```

### Analysis Targets

| Target | Description | Output |
|--------|-------------|--------|
| `analyze` | Run all analysis types | All reports below |
| `analyze-stats` | Basic statistics | `*_stats.txt` files |
| `analyze-sqlite` | Export to SQLite | `*.sqlite` databases |
| `analyze-cpu-sampling` | CPU sampling details | `*_cpusampling.txt` |
| `analyze-osrt` | OS runtime analysis | `*_osrt.txt` |
| `analyze-nvtx` | NVTX marker summary | `*_nvtx.txt` |
| `analyze-compare` | Python vs C++ comparison | Comparison reports |
| `analyze-visual` | Visual HTML report | `profiling_report.html` with charts |

### Viewing Targets

| Target | Description | Example |
|--------|-------------|---------|
| `list-results` | List available profiles | `make list-results` |
| `view` | Open specific profile in GUI | `make view PROFILE=cpp_matrix_ops` |
| `view-all` | Open all profiles | `make view-all` |
| `quick-view` | Quick stats in terminal | `make quick-view PROFILE=py_1_basic` |

### Utility Targets

| Target | Description | Example |
|--------|-------------|---------|
| `clean` | Remove all artifacts | `make clean` |
| `clean-results` | Remove profiling results only | `make clean-results` |
| `archive` | Create timestamped archive | `make archive` |
| `check-nsys` | Verify nsys installation | `make check-nsys` |

## Advanced Workflows Menu

The `make advanced-workflow` target launches an interactive menu with:

1. **Interactive Profiling Session** - Guided profiling with custom options
2. **Comparative Performance Analysis** - Side-by-side Python vs C++ analysis
3. **Memory Bottleneck Detection** - Identify memory performance issues
4. **Thread Contention Analysis** - Find threading bottlenecks
5. **Hot Function Analysis** - Identify performance hotspots
6. **I/O Performance Analysis** - Analyze I/O patterns
7. **Custom Metric Collection** - Collect specific performance metrics
8. **Generate Comprehensive Report** - Create detailed analysis report
9. **Profile with Different Optimization Levels** - Compare -O0 to -O3

## Common Use Cases

### Finding Performance Bottlenecks
```bash
# Profile with detailed CPU sampling
make profile-cpu-detailed

# Analyze hot functions
make analyze-cpu-sampling

# View results
make quick-view PROFILE=cpu_detailed_basic
```

### Memory Performance Analysis
```bash
# Profile memory-intensive operations
make profile-memory

# Generate memory analysis
make analyze-stats

# Check for memory bottlenecks
grep -i "memory\|cache\|malloc" results/reports/*memory*.txt
```

### Comparing Implementations
```bash
# Profile same algorithm in Python and C++
make profile

# Generate comparison
make analyze-compare analyze-visual

# Open visual report
xdg-open results/reports/profiling_report.html
```

### Thread/Process Analysis
```bash
# Profile with context switches
make profile-cpu-detailed

# Analyze OS runtime behavior
make analyze-osrt

# Look for contention
grep -i "mutex\|lock\|wait" results/reports/*osrt*.txt
```

## Tips and Best Practices

1. **Start Simple**: Use `make profile` for initial profiling, then drill down with advanced targets

2. **Use Visual Reports**: `make analyze-visual` creates easy-to-understand HTML reports with charts

3. **Interactive Workflow**: For complex analysis, use `make advanced-workflow` for guided profiling

4. **Custom Profiling**: Use `profile-custom` for specific scenarios:
   ```bash
   # Long-running analysis
   make profile-custom TARGET=./my_app OPTS='--duration=300'
   
   # Specific sampling rate
   make profile-custom TARGET=./my_app OPTS='--sampling-period=10000'
   ```

5. **Batch Analysis**: Profile multiple configurations:
   ```bash
   for opt in O0 O2 O3; do
     make clean
     make CXXFLAGS="-$opt -g"
     make profile-cpp
     mv results results_$opt
   done
   ```

6. **Archive Important Results**: Before major changes:
   ```bash
   make archive  # Creates timestamped backup
   ```

## Environment Variables

The Makefile respects these environment variables:

- `CXX`: C++ compiler (default: g++)
- `CXXFLAGS`: Compiler flags
- `PYTHON`: Python interpreter (default: python3)
- `RESULTS_DIR`: Results directory (default: results)
- `REPORTS_DIR`: Reports directory (default: results/reports)

Example:
```bash
CXX=clang++ CXXFLAGS="-O3 -march=native" make all
```

## Troubleshooting

### No profiling results found
```bash
make check-nsys  # Verify nsys is installed
make dirs        # Create required directories
```

### Permission denied errors
```bash
# Some profiling features require elevated permissions
sudo make profile-advanced
```

### Out of disk space
```bash
make clean-results  # Remove old profiling data
make archive        # Or archive before cleaning
```

### Can't open GUI
```bash
# Use quick-view for terminal output
make quick-view PROFILE=<name>

# Or generate HTML report
make analyze-visual
```