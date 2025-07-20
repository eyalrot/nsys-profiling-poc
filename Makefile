# Makefile for NVIDIA Nsight Systems CPU Profiling POC
# Enhanced with advanced profiling, viewing, and analysis options
# Now uses CMake for C++ builds

# Build configuration
CMAKE = cmake
CMAKE_BUILD_TYPE ?= Release
BUILD_DIR = build

# Python interpreter
PYTHON = python3

# Output directories
BIN_DIR = $(BUILD_DIR)/bin
RESULTS_DIR = results
REPORTS_DIR = $(RESULTS_DIR)/reports
PYTHON_DIR = python

# Source files
CPP_SOURCES = $(wildcard cpp/*.cpp)
CPP_TARGETS = $(patsubst cpp/%.cpp,$(BIN_DIR)/%,$(CPP_SOURCES))
PYTHON_SOURCES = $(wildcard $(PYTHON_DIR)/*.py)

# NSYS profiling options
NSYS_BASIC = --sample=cpu --trace=osrt,nvtx
NSYS_DETAILED = --sample=cpu --cpuctxsw=true --trace=osrt,nvtx,cuda
NSYS_MEMORY = --sample=cpu --trace=osrt --backtrace=fp
NSYS_PYTHON = --trace=osrt,nvtx,python --sample=cpu
NSYS_ADVANCED = --sample=cpu --cpuctxsw=true --trace=osrt,nvtx,cuda,cudnn,cublas --gpu-metrics-device=all

# Default target
all: cpp-all

# Create directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)

$(REPORTS_DIR):
	mkdir -p $(REPORTS_DIR)

dirs: $(BUILD_DIR) $(RESULTS_DIR) $(REPORTS_DIR)

# ==================== C++ Build Targets (using CMake) ====================

# Configure CMake
cmake-configure: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(CMAKE) -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) ..

# Configure with NVTX support
cmake-configure-nvtx: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(CMAKE) -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) -DUSE_NVTX=ON ..

# Build all C++ examples
cpp-all: cmake-configure
	cd $(BUILD_DIR) && $(CMAKE) --build . --target all
	@echo "C++ examples built with CMake"

# Build with NVTX support (requires CUDA toolkit)
nvtx: cmake-configure-nvtx
	cd $(BUILD_DIR) && $(CMAKE) --build . --target all
	@echo "C++ examples built with NVTX support"

# Build specific optimization comparison
build-opt-comparison: cmake-configure
	cd $(BUILD_DIR) && $(CMAKE) --build . --target build-opt-comparison

# ==================== Run Targets ====================

# Run all examples (without profiling)
run: run-cpp run-python

run-cpp: cpp-all
	@echo "Running all C++ examples..."
	@echo "=========================="
	@for target in $(CPP_TARGETS); do \
		echo "\nRunning $$target:"; \
		$$target || true; \
	done

run-python:
	@echo "\nRunning all Python examples..."
	@echo "=============================="
	@for script in $(PYTHON_SOURCES); do \
		echo "\nRunning $$script:"; \
		$(PYTHON) $$script || true; \
	done

# ==================== Basic Profiling ====================

profile: profile-cpp profile-python

profile-cpp: cpp-all dirs
	@echo "Profiling C++ examples with nsys..."
	@echo "==================================="
	@for target in $(CPP_TARGETS); do \
		name=$$(basename $$target); \
		echo "\nProfiling $$name..."; \
		nsys profile $(NSYS_BASIC) -o $(RESULTS_DIR)/cpp_$$name $$target || true; \
	done

profile-python: dirs
	@echo "\nProfiling Python examples with nsys..."
	@echo "======================================"
	@for script in $(PYTHON_SOURCES); do \
		name=$$(basename $$script .py); \
		echo "\nProfiling $$name..."; \
		nsys profile $(NSYS_PYTHON) -o $(RESULTS_DIR)/py_$$name $(PYTHON) $$script || true; \
	done

# ==================== Advanced Profiling ====================

# Profile with detailed CPU metrics
profile-cpu-detailed: cpp-all dirs
	@echo "Detailed CPU profiling..."
	@echo "========================"
	nsys profile $(NSYS_DETAILED) --sampling-period=100000 \
		-o $(RESULTS_DIR)/cpu_detailed_basic $(BIN_DIR)/1_basic_cpu_profiling
	nsys profile $(NSYS_DETAILED) --sampling-period=50000 \
		-o $(RESULTS_DIR)/cpu_detailed_threading $(BIN_DIR)/3_multithreading_example

# Profile memory access patterns
profile-memory: cpp-all dirs
	@echo "Memory profiling..."
	@echo "=================="
	nsys profile $(NSYS_MEMORY) --sampling-period=100000 \
		-o $(RESULTS_DIR)/memory_patterns $(BIN_DIR)/5_memory_intensive
	nsys profile $(NSYS_MEMORY) --sampling-period=100000 \
		-o $(RESULTS_DIR)/memory_matrix $(BIN_DIR)/2_matrix_operations

# Profile with advanced metrics
profile-advanced: cpp-all dirs
	@echo "Advanced profiling with all metrics..."
	@echo "====================================="
	@for target in $(CPP_TARGETS); do \
		name=$$(basename $$target); \
		echo "\nAdvanced profiling $$name..."; \
		nsys profile $(NSYS_ADVANCED) --duration=30 \
			-o $(RESULTS_DIR)/advanced_$$name $$target || true; \
	done

# Profile specific example with custom options
profile-custom:
	@if [ -z "$(TARGET)" ]; then \
		echo "Usage: make profile-custom TARGET=<binary> OPTS='<nsys-options>'"; \
		echo "Example: make profile-custom TARGET=cpp/bin/1_basic_cpu_profiling OPTS='--sample=cpu --duration=10'"; \
	else \
		echo "Custom profiling $(TARGET) with options: $(OPTS)"; \
		nsys profile $(OPTS) -o $(RESULTS_DIR)/custom_$$(basename $(TARGET)) $(TARGET); \
	fi

# ==================== Analysis Targets ====================

# Generate all reports
analyze: analyze-stats analyze-sqlite analyze-compare analyze-visual

# Generate statistics reports
analyze-stats: dirs
	@echo "Generating statistics reports..."
	@echo "==============================="
	@for file in $(RESULTS_DIR)/*.nsys-rep; do \
		if [ -f "$$file" ]; then \
			base=$$(basename $$file .nsys-rep); \
			echo "\nAnalyzing $$base..."; \
			nsys stats $$file > $(REPORTS_DIR)/$${base}_stats.txt || true; \
			echo "Stats saved to $(REPORTS_DIR)/$${base}_stats.txt"; \
		fi; \
	done

# Export to SQLite for custom queries
analyze-sqlite: dirs
	@echo "\nExporting to SQLite databases..."
	@echo "================================"
	@for file in $(RESULTS_DIR)/*.nsys-rep; do \
		if [ -f "$$file" ]; then \
			base=$$(basename $$file .nsys-rep); \
			echo "\nExporting $$base..."; \
			nsys export --type=sqlite --output=$(REPORTS_DIR)/$${base}.sqlite $$file || true; \
			echo "SQLite database saved to $(REPORTS_DIR)/$${base}.sqlite"; \
		fi; \
	done

# Generate specific analysis reports
analyze-cpu-sampling: dirs
	@echo "\nGenerating CPU sampling reports..."
	@echo "=================================="
	@for file in $(RESULTS_DIR)/*.nsys-rep; do \
		if [ -f "$$file" ]; then \
			base=$$(basename $$file .nsys-rep); \
			echo "\nCPU sampling analysis for $$base..."; \
			nsys analyze --report cpusampling $$file > $(REPORTS_DIR)/$${base}_cpusampling.txt 2>/dev/null || true; \
		fi; \
	done

analyze-osrt: dirs
	@echo "\nGenerating OS runtime reports..."
	@echo "================================"
	@for file in $(RESULTS_DIR)/*.nsys-rep; do \
		if [ -f "$$file" ]; then \
			base=$$(basename $$file .nsys-rep); \
			echo "\nOS runtime analysis for $$base..."; \
			nsys analyze --report osrtsum $$file > $(REPORTS_DIR)/$${base}_osrt.txt 2>/dev/null || true; \
		fi; \
	done

analyze-nvtx: dirs
	@echo "\nGenerating NVTX reports..."
	@echo "=========================="
	@for file in $(RESULTS_DIR)/*.nsys-rep; do \
		if [ -f "$$file" ]; then \
			base=$$(basename $$file .nsys-rep); \
			echo "\nNVTX analysis for $$base..."; \
			nsys analyze --report nvtxsum $$file > $(REPORTS_DIR)/$${base}_nvtx.txt 2>/dev/null || true; \
		fi; \
	done

# Compare Python vs C++ performance
analyze-compare: dirs
	@echo "\nComparing Python vs C++ performance..."
	@echo "======================================"
	$(PYTHON) scripts/compare_results.py

# Generate visual HTML report with charts
analyze-visual: dirs
	@echo "\nGenerating visual HTML report..."
	@echo "================================"
	$(PYTHON) scripts/generate_visual_report.py
	@echo "Report generated in $(REPORTS_DIR)/profiling_report.html"

# ==================== Viewing Targets ====================

# List all profiling results
list-results:
	@echo "Available profiling results:"
	@echo "==========================="
	@ls -lh $(RESULTS_DIR)/*.nsys-rep 2>/dev/null || echo "No profiling results found."

# View specific profile in GUI
view:
	@if [ -z "$(PROFILE)" ]; then \
		echo "Usage: make view PROFILE=<profile-name>"; \
		echo "Example: make view PROFILE=cpp_1_basic_cpu_profiling"; \
		echo ""; \
		make list-results; \
	else \
		echo "Opening $(PROFILE) in nsys-ui..."; \
		nsys-ui $(RESULTS_DIR)/$(PROFILE).nsys-rep & \
	fi

# View all profiles in GUI (opens multiple windows)
view-all:
	@echo "Opening all profiles in nsys-ui..."
	@for file in $(RESULTS_DIR)/*.nsys-rep; do \
		if [ -f "$$file" ]; then \
			nsys-ui $$file & \
		fi; \
	done

# Quick view of stats for a specific profile
quick-view:
	@if [ -z "$(PROFILE)" ]; then \
		echo "Usage: make quick-view PROFILE=<profile-name>"; \
		echo "Example: make quick-view PROFILE=cpp_1_basic_cpu_profiling"; \
	else \
		echo "Quick stats for $(PROFILE):"; \
		echo "=========================="; \
		nsys stats $(RESULTS_DIR)/$(PROFILE).nsys-rep 2>/dev/null | head -50 || echo "Profile not found."; \
	fi

# ==================== Utility Targets ====================

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(RESULTS_DIR)/*.nsys-rep
	rm -f $(RESULTS_DIR)/*.qdrep
	rm -f $(RESULTS_DIR)/*.sqlite
	rm -rf $(REPORTS_DIR)

# Clean only profiling results
clean-results:
	rm -f $(RESULTS_DIR)/*.nsys-rep
	rm -f $(RESULTS_DIR)/*.qdrep
	rm -f $(RESULTS_DIR)/*.sqlite
	rm -rf $(REPORTS_DIR)

# Clean CMake cache (for reconfiguration)
clean-cmake:
	rm -rf $(BUILD_DIR)/CMakeCache.txt $(BUILD_DIR)/CMakeFiles

# Archive profiling results
archive:
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	archive_name="profiling_results_$$timestamp.tar.gz"; \
	echo "Archiving results to $$archive_name..."; \
	tar -czf $$archive_name $(RESULTS_DIR)/ || true; \
	echo "Archive created: $$archive_name"

# Check nsys installation
check-nsys:
	@echo "Checking NVIDIA Nsight Systems installation..."
	@echo "============================================="
	@which nsys > /dev/null 2>&1 && nsys --version || echo "nsys not found in PATH!"
	@echo ""
	@which nsys-ui > /dev/null 2>&1 && echo "nsys-ui found" || echo "nsys-ui not found in PATH!"

# ==================== Help Target ====================

help:
	@echo "NVIDIA Nsight Systems CPU Profiling POC - Enhanced Makefile"
	@echo "=========================================================="
	@echo ""
	@echo "BUILD TARGETS (using CMake):"
	@echo "  make all              - Build all C++ examples"
	@echo "  make cpp-all          - Build all C++ examples"
	@echo "  make nvtx             - Build with NVTX support (requires CUDA)"
	@echo "  make cmake-configure  - Configure CMake build"
	@echo "  make cmake-configure-nvtx - Configure with NVTX support"
	@echo "  make build-opt-comparison - Build with different optimization levels"
	@echo ""
	@echo "RUN TARGETS:"
	@echo "  make run              - Run all examples (C++ and Python)"
	@echo "  make run-cpp          - Run all C++ examples"
	@echo "  make run-python       - Run all Python examples"
	@echo ""
	@echo "BASIC PROFILING:"
	@echo "  make profile          - Profile all examples (C++ and Python)"
	@echo "  make profile-cpp      - Profile all C++ examples"
	@echo "  make profile-python   - Profile all Python examples"
	@echo ""
	@echo "ADVANCED PROFILING:"
	@echo "  make profile-cpu-detailed - Detailed CPU profiling with context switches"
	@echo "  make profile-memory       - Memory access pattern profiling"
	@echo "  make profile-advanced     - Advanced profiling with all metrics"
	@echo "  make profile-custom       - Custom profiling (TARGET=<binary> OPTS='<options>')"
	@echo ""
	@echo "ANALYSIS TARGETS:"
	@echo "  make analyze          - Generate all analysis reports"
	@echo "  make analyze-stats    - Generate statistics reports"
	@echo "  make analyze-sqlite   - Export to SQLite databases"
	@echo "  make analyze-cpu-sampling - CPU sampling analysis"
	@echo "  make analyze-osrt     - OS runtime analysis"
	@echo "  make analyze-nvtx     - NVTX marker analysis"
	@echo "  make analyze-compare  - Compare Python vs C++ performance"
	@echo "  make analyze-visual   - Generate visual HTML report with charts"
	@echo ""
	@echo "VIEWING TARGETS:"
	@echo "  make list-results     - List all profiling results"
	@echo "  make view             - View specific profile (PROFILE=<name>)"
	@echo "  make view-all         - Open all profiles in GUI"
	@echo "  make quick-view       - Quick stats view (PROFILE=<name>)"
	@echo ""
	@echo "UTILITY TARGETS:"
	@echo "  make clean            - Clean all build artifacts and results"
	@echo "  make clean-results    - Clean only profiling results"
	@echo "  make clean-cmake      - Clean CMake cache for reconfiguration"
	@echo "  make archive          - Archive profiling results with timestamp"
	@echo "  make check-nsys       - Check nsys installation"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "ADVANCED WORKFLOWS:"
	@echo "  make advanced-workflow - Launch interactive advanced profiling menu"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make profile-custom TARGET=cpp/bin/1_basic_cpu_profiling OPTS='--duration=10'"
	@echo "  make view PROFILE=cpp_1_basic_cpu_profiling"
	@echo "  make quick-view PROFILE=py_matrix_operations"

# Advanced profiling workflow
advanced-workflow:
	@echo "Launching advanced profiling workflow..."
	@echo "======================================="
	@./scripts/advanced_profiling.sh

# Phony targets
.PHONY: all cpp-all dirs clean clean-results clean-cmake run run-cpp run-python \
        cmake-configure cmake-configure-nvtx build-opt-comparison \
        profile profile-cpp profile-python profile-cpu-detailed \
        profile-memory profile-advanced profile-custom \
        analyze analyze-stats analyze-sqlite analyze-cpu-sampling \
        analyze-osrt analyze-nvtx analyze-compare analyze-visual \
        list-results view view-all quick-view \
        archive check-nsys help nvtx advanced-workflow