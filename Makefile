# Makefile for NVIDIA Nsight Systems CPU Profiling POC
# Enhanced with advanced profiling, viewing, and analysis options
# Now uses CMake for C++ builds

# Build configuration
CMAKE = cmake
CMAKE_BUILD_TYPE ?= Release
BUILD_DIR = build

# Python interpreter
PYTHON = python3
VENV_PYTHON = venv/bin/python

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
NSYS_DETAILED = --sample=cpu --cpuctxsw=process-tree --trace=osrt,nvtx,cuda
NSYS_MEMORY = --sample=cpu --trace=osrt --backtrace=fp
NSYS_PYTHON = --trace=osrt,nvtx --sample=cpu
NSYS_ADVANCED = --sample=cpu --cpuctxsw=process-tree --trace=osrt,nvtx

# Default target
all: check-venv cpp-all

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

run-python: check-venv
	@echo "\nRunning all Python examples..."
	@echo "=============================="
	@for script in $(PYTHON_SOURCES); do \
		echo "\nRunning $$script:"; \
		$(VENV_PYTHON) $$script || true; \
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

profile-python: check-venv dirs
	@echo "\nProfiling Python examples with nsys..."
	@echo "======================================"
	@for script in $(PYTHON_SOURCES); do \
		name=$$(basename $$script .py); \
		echo "\nProfiling $$name..."; \
		nsys profile $(NSYS_PYTHON) -o $(RESULTS_DIR)/py_$$name $(VENV_PYTHON) $$script || true; \
	done

# ==================== Advanced Profiling ====================

# Profile with detailed CPU metrics
profile-cpu-detailed: cpp-all dirs
	@echo "Detailed CPU profiling..."
	@echo "========================"
	nsys profile $(NSYS_DETAILED) --sampling-period=200000 \
		-o $(RESULTS_DIR)/cpu_detailed_basic $(BIN_DIR)/1_basic_cpu_profiling
	nsys profile $(NSYS_DETAILED) --sampling-period=150000 \
		-o $(RESULTS_DIR)/cpu_detailed_threading $(BIN_DIR)/3_multithreading_example

# Profile memory access patterns
profile-memory: cpp-all dirs
	@echo "Memory profiling..."
	@echo "=================="
	nsys profile $(NSYS_MEMORY) --sampling-period=200000 \
		-o $(RESULTS_DIR)/memory_patterns $(BIN_DIR)/5_memory_intensive
	nsys profile $(NSYS_MEMORY) --sampling-period=200000 \
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
analyze-compare: check-venv dirs
	@echo "\nComparing Python vs C++ performance..."
	@echo "======================================"
	$(VENV_PYTHON) scripts/compare_results.py

# Generate visual HTML report with charts
analyze-visual: check-venv dirs
	@echo "\nGenerating visual HTML report..."
	@echo "================================"
	$(VENV_PYTHON) scripts/generate_simple_html_report.py
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

# Check virtual environment
check-venv:
	@if [ ! -d "venv" ]; then \
		echo "Virtual environment not found. Creating it..."; \
		python3 -m venv venv; \
		venv/bin/pip install -r requirements.txt; \
	elif [ ! -f "venv/bin/python" ]; then \
		echo "Virtual environment appears corrupted. Recreating..."; \
		rm -rf venv; \
		python3 -m venv venv; \
		venv/bin/pip install -r requirements.txt; \
	fi

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
	@echo "  make check-venv       - Check/create Python virtual environment"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "SOFTWARE-BASED PROFILING TARGETS:"
	@echo "  make check-cpu-counters    - Check if hardware counters are available"
	@echo "  make build-software-demo   - Build software profiling demonstration"
	@echo "  make profile-software-demo - Run various software-based profiling techniques"
	@echo "  make analyze-software-profiles - Analyze software profiling results"
	@echo ""
	@echo "STACK TRACE TARGETS:"
	@echo "  make build-stack-trace    - Build stack trace examples with different flags"
	@echo "  make profile-stack-traces - Profile examples with different backtrace methods"
	@echo "  make test-stack-traces    - Run comprehensive stack trace test script"
	@echo "  make analyze-stack-traces - Analyze stack trace profiling results"
	@echo "  make view-stack-trace-docs - View stack trace documentation"
	@echo ""
	@echo "ADVANCED WORKFLOWS:"
	@echo "  make advanced-workflow - Launch interactive advanced profiling menu"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make profile-custom TARGET=cpp/bin/1_basic_cpu_profiling OPTS='--duration=10'"
	@echo "  make view PROFILE=cpp_1_basic_cpu_profiling"
	@echo "  make quick-view PROFILE=py_matrix_operations"
	@echo "  make test-stack-traces    - Test your stack trace setup"

# Advanced profiling workflow
advanced-workflow:
	@echo "Launching advanced profiling workflow..."
	@echo "======================================="
	@./scripts/advanced_profiling.sh

# ==================== Software-Based Profiling Targets ====================

# Check CPU counter availability
check-cpu-counters:
	@echo "Checking CPU performance counter availability..."
	@echo "==========================================="
	@./scripts/check_cpu_counters.sh || true

# Build software profiling examples
build-software-demo: cmake-configure
	@echo "Building software profiling demo..."
	@echo "==================================="
	@if [ -f "examples/software_profiling_demo.cpp" ]; then \
		g++ -O2 -g -pthread -o $(BIN_DIR)/software_profiling_demo examples/software_profiling_demo.cpp; \
		echo "Built: $(BIN_DIR)/software_profiling_demo"; \
	else \
		echo "Software profiling demo source not found"; \
	fi

# Profile with software-based techniques
profile-software-demo: build-software-demo dirs check-venv
	@echo "Profiling with software-based techniques..."
	@echo "=========================================="
	@echo "\n1. CPU Sampling Profile..."
	nsys profile --sample=cpu --backtrace=fp \
		-o $(RESULTS_DIR)/software_cpu_sampling $(BIN_DIR)/software_profiling_demo || true
	@echo "\n2. Context Switch Profile..."
	nsys profile --cpuctxsw=process-tree \
		-o $(RESULTS_DIR)/software_context_switch $(BIN_DIR)/software_profiling_demo || true
	@echo "\n3. OS Runtime Profile..."
	nsys profile --trace=osrt \
		-o $(RESULTS_DIR)/software_os_runtime $(BIN_DIR)/software_profiling_demo || true
	@echo "\n4. Combined Profile..."
	nsys profile --sample=cpu --cpuctxsw=process-tree --trace=osrt --backtrace=fp \
		-o $(RESULTS_DIR)/software_combined $(BIN_DIR)/software_profiling_demo || true
	@echo "\n5. Python Software Demo..."
	@if [ -f "examples/software_profiling_demo.py" ]; then \
		nsys profile --sample=cpu --trace=osrt,nvtx --backtrace=fp \
			-o $(RESULTS_DIR)/software_python $(VENV_PYTHON) examples/software_profiling_demo.py || true; \
	else \
		echo "Python software profiling demo not found"; \
	fi

# Analyze software-based profiling results
analyze-software-profiles: dirs
	@echo "Analyzing software-based profiling results..."
	@echo "==========================================="
	@for profile in software_cpu_sampling software_context_switch software_os_runtime software_combined software_python; do \
		if [ -f "$(RESULTS_DIR)/$$profile.nsys-rep" ]; then \
			echo "\nAnalyzing $$profile..."; \
			nsys stats $(RESULTS_DIR)/$$profile.nsys-rep > $(REPORTS_DIR)/$${profile}_analysis.txt 2>/dev/null || true; \
			echo "Analysis saved to $(REPORTS_DIR)/$${profile}_analysis.txt"; \
		fi; \
	done

# ==================== Stack Trace Targets ====================

# Build stack trace examples
build-stack-trace: cmake-configure
	@echo "Building stack trace examples..."
	@echo "================================"
	cd $(BUILD_DIR) && $(CMAKE) --build . --target stack_trace_example_fp
	cd $(BUILD_DIR) && $(CMAKE) --build . --target stack_trace_example_dwarf
	cd $(BUILD_DIR) && $(CMAKE) --build . --target stack_trace_example_no_fp
	@echo "Stack trace examples built:"
	@echo "  - $(BIN_DIR)/stack_trace_example_fp (with frame pointers)"
	@echo "  - $(BIN_DIR)/stack_trace_example_dwarf (with DWARF debug info)"
	@echo "  - $(BIN_DIR)/stack_trace_example_no_fp (without frame pointers)"

# Profile stack trace examples with different backtrace methods
profile-stack-traces: build-stack-trace dirs
	@echo "Profiling stack trace examples..."
	@echo "================================="
	@echo "\nProfiling with frame pointer backtrace..."
	nsys profile --sample=cpu --trace=osrt --backtrace=fp \
		-o $(RESULTS_DIR)/stack_trace_fp $(BIN_DIR)/stack_trace_example_fp --quick || true
	@echo "\nProfiling with DWARF backtrace..."
	nsys profile --sample=cpu --trace=osrt --backtrace=dwarf \
		-o $(RESULTS_DIR)/stack_trace_dwarf $(BIN_DIR)/stack_trace_example_dwarf --quick || true
	@echo "\nProfiling with LBR backtrace (may fail on some platforms)..."
	nsys profile --sample=cpu --trace=osrt --backtrace=lbr \
		-o $(RESULTS_DIR)/stack_trace_lbr $(BIN_DIR)/stack_trace_example_fp --quick || true
	@echo "\nProfiling Python stack trace example..."
	@if [ -f "examples/stack_trace_example.py" ]; then \
		nsys profile --sample=cpu --trace=osrt,nvtx --backtrace=fp \
			-o $(RESULTS_DIR)/stack_trace_python $(VENV_PYTHON) examples/stack_trace_example.py --quick || true; \
	else \
		echo "Python stack trace example not found"; \
	fi

# Test stack trace collection
test-stack-traces:
	@echo "Testing stack trace collection..."
	@echo "================================="
	@if [ -f "scripts/test_stack_traces.sh" ]; then \
		./scripts/test_stack_traces.sh; \
	else \
		echo "Stack trace test script not found"; \
	fi

# Analyze stack trace results
analyze-stack-traces: dirs
	@echo "Analyzing stack trace results..."
	@echo "================================"
	@for profile in stack_trace_fp stack_trace_dwarf stack_trace_lbr stack_trace_python; do \
		if [ -f "$(RESULTS_DIR)/$$profile.nsys-rep" ]; then \
			echo "\nAnalyzing $$profile..."; \
			nsys stats --report cpusampling $(RESULTS_DIR)/$$profile.nsys-rep > $(REPORTS_DIR)/$${profile}_analysis.txt 2>/dev/null || \
			nsys stats $(RESULTS_DIR)/$$profile.nsys-rep > $(REPORTS_DIR)/$${profile}_analysis.txt 2>/dev/null || true; \
			echo "Analysis saved to $(REPORTS_DIR)/$${profile}_analysis.txt"; \
		fi; \
	done

# View stack trace documentation
view-stack-trace-docs:
	@echo "Stack Trace Documentation:"
	@echo "========================="
	@echo "1. Stack Traces Guide: docs/STACK_TRACES_GUIDE.md"
	@echo "2. Examples README: examples/README_stack_traces.md"
	@echo "3. Test Script: scripts/test_stack_traces.sh"
	@echo ""
	@echo "To view in your editor:"
	@echo "  - docs/STACK_TRACES_GUIDE.md"
	@echo "  - examples/README_stack_traces.md"

# Phony targets
.PHONY: all cpp-all dirs clean clean-results clean-cmake run run-cpp run-python \
        cmake-configure cmake-configure-nvtx build-opt-comparison \
        profile profile-cpp profile-python profile-cpu-detailed \
        profile-memory profile-advanced profile-custom \
        analyze analyze-stats analyze-sqlite analyze-cpu-sampling \
        analyze-osrt analyze-nvtx analyze-compare analyze-visual \
        list-results view view-all quick-view \
        archive check-nsys check-venv help nvtx advanced-workflow \
        build-stack-trace profile-stack-traces test-stack-traces \
        analyze-stack-traces view-stack-trace-docs \
        check-cpu-counters build-software-demo profile-software-demo \
        analyze-software-profiles