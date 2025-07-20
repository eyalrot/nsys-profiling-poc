#!/bin/bash
# Advanced profiling workflows for NVIDIA Nsight Systems

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RESULTS_DIR="results"
REPORTS_DIR="$RESULTS_DIR/reports"

# Create directories
mkdir -p "$RESULTS_DIR" "$REPORTS_DIR"

# Function to display menu
show_menu() {
    echo -e "\n${GREEN}NVIDIA Nsight Systems - Advanced Profiling Workflows${NC}"
    echo "===================================================="
    echo ""
    echo -e "${CYAN}1.${NC} Interactive Profiling Session"
    echo -e "${CYAN}2.${NC} Comparative Performance Analysis"
    echo -e "${CYAN}3.${NC} Memory Bottleneck Detection"
    echo -e "${CYAN}4.${NC} Thread Contention Analysis"
    echo -e "${CYAN}5.${NC} Hot Function Analysis"
    echo -e "${CYAN}6.${NC} I/O Performance Analysis"
    echo -e "${CYAN}7.${NC} Custom Metric Collection"
    echo -e "${CYAN}8.${NC} Generate Comprehensive Report"
    echo -e "${CYAN}9.${NC} Profile with Different Optimization Levels"
    echo -e "${CYAN}0.${NC} Exit"
    echo ""
}

# Function to select target
select_target() {
    echo -e "\n${YELLOW}Select target type:${NC}"
    echo "1. C++ executable"
    echo "2. Python script"
    echo -n "Choice: "
    read target_type

    case $target_type in
        1)
            echo -e "\n${YELLOW}Available C++ executables:${NC}"
            ls -1 cpp/bin/ 2>/dev/null | cat -n
            echo -n "Select number: "
            read num
            TARGET=$(ls -1 cpp/bin/ | sed -n "${num}p")
            TARGET="cpp/bin/$TARGET"
            TARGET_NAME=$(basename "$TARGET")
            ;;
        2)
            echo -e "\n${YELLOW}Available Python scripts:${NC}"
            ls -1 python/*.py 2>/dev/null | cat -n
            echo -n "Select number: "
            read num
            TARGET=$(ls -1 python/*.py | sed -n "${num}p")
            TARGET_NAME=$(basename "$TARGET" .py)
            TARGET="python $TARGET"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return 1
            ;;
    esac

    echo -e "${GREEN}Selected: $TARGET${NC}"
    return 0
}

# 1. Interactive Profiling Session
interactive_profiling() {
    echo -e "\n${PURPLE}=== Interactive Profiling Session ===${NC}"
    
    if ! select_target; then return; fi

    echo -e "\n${YELLOW}Profiling options:${NC}"
    echo "1. Quick profile (5 seconds)"
    echo "2. Standard profile (30 seconds)"
    echo "3. Extended profile (60 seconds)"
    echo "4. Custom duration"
    echo -n "Choice: "
    read duration_choice

    case $duration_choice in
        1) DURATION=5 ;;
        2) DURATION=30 ;;
        3) DURATION=60 ;;
        4) 
            echo -n "Enter duration (seconds): "
            read DURATION
            ;;
        *) DURATION=30 ;;
    esac

    echo -e "\n${YELLOW}Select profiling focus:${NC}"
    echo "1. CPU sampling only"
    echo "2. CPU + Context switches"
    echo "3. CPU + Memory access"
    echo "4. Everything (CPU, Memory, OS, NVTX)"
    echo -n "Choice: "
    read focus_choice

    case $focus_choice in
        1) 
            OPTS="--sample=cpu --trace=osrt"
            SUFFIX="cpu"
            ;;
        2) 
            OPTS="--sample=cpu --cpuctxsw=true --trace=osrt"
            SUFFIX="cpu_ctx"
            ;;
        3) 
            OPTS="--sample=cpu --trace=osrt --backtrace=fp"
            SUFFIX="cpu_mem"
            ;;
        4) 
            OPTS="--sample=cpu --cpuctxsw=true --trace=osrt,nvtx,cuda --backtrace=fp"
            SUFFIX="full"
            ;;
        *) 
            OPTS="--sample=cpu --trace=osrt"
            SUFFIX="default"
            ;;
    esac

    OUTPUT="${RESULTS_DIR}/interactive_${TARGET_NAME}_${SUFFIX}_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${GREEN}Starting profiling...${NC}"
    echo "Command: nsys profile $OPTS --duration=$DURATION -o $OUTPUT $TARGET"
    
    nsys profile $OPTS --duration=$DURATION -o "$OUTPUT" $TARGET
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Profiling complete!${NC}"
        echo "Results saved to: ${OUTPUT}.nsys-rep"
        
        echo -n "Generate report? (y/n): "
        read generate_report
        if [ "$generate_report" = "y" ]; then
            nsys stats "${OUTPUT}.nsys-rep" > "${OUTPUT}_stats.txt"
            echo "Report saved to: ${OUTPUT}_stats.txt"
        fi
        
        echo -n "Open in GUI? (y/n): "
        read open_gui
        if [ "$open_gui" = "y" ]; then
            nsys-ui "${OUTPUT}.nsys-rep" &
        fi
    else
        echo -e "${RED}Profiling failed!${NC}"
    fi
}

# 2. Comparative Performance Analysis
comparative_analysis() {
    echo -e "\n${PURPLE}=== Comparative Performance Analysis ===${NC}"
    
    echo -e "${YELLOW}This will profile the same algorithm in both Python and C++${NC}"
    echo "Select algorithm:"
    echo "1. Basic CPU operations"
    echo "2. Matrix operations"
    echo "3. Parallel processing"
    echo -n "Choice: "
    read algo_choice

    case $algo_choice in
        1)
            PY_TARGET="python/1_basic_cpu_profiling.py"
            CPP_TARGET="cpp/bin/1_basic_cpu_profiling"
            ALGO_NAME="basic_cpu"
            ;;
        2)
            PY_TARGET="python/2_matrix_operations.py"
            CPP_TARGET="cpp/bin/2_matrix_operations"
            ALGO_NAME="matrix_ops"
            ;;
        3)
            PY_TARGET="python/3_multiprocessing_example.py"
            CPP_TARGET="cpp/bin/3_multithreading_example"
            ALGO_NAME="parallel"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return
            ;;
    esac

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    echo -e "\n${GREEN}Profiling Python implementation...${NC}"
    nsys profile --sample=cpu --trace=osrt,nvtx,python \
        -o "${RESULTS_DIR}/compare_py_${ALGO_NAME}_${TIMESTAMP}" \
        python "$PY_TARGET"
    
    echo -e "\n${GREEN}Profiling C++ implementation...${NC}"
    nsys profile --sample=cpu --cpuctxsw=true --trace=osrt,nvtx \
        -o "${RESULTS_DIR}/compare_cpp_${ALGO_NAME}_${TIMESTAMP}" \
        "$CPP_TARGET"
    
    echo -e "\n${GREEN}Generating comparison report...${NC}"
    
    # Generate stats for both
    nsys stats "${RESULTS_DIR}/compare_py_${ALGO_NAME}_${TIMESTAMP}.nsys-rep" \
        > "${REPORTS_DIR}/compare_py_${ALGO_NAME}_${TIMESTAMP}_stats.txt"
    
    nsys stats "${RESULTS_DIR}/compare_cpp_${ALGO_NAME}_${TIMESTAMP}.nsys-rep" \
        > "${REPORTS_DIR}/compare_cpp_${ALGO_NAME}_${TIMESTAMP}_stats.txt"
    
    # Run comparison script
    python scripts/compare_results.py
    
    echo -e "\n${GREEN}Comparison complete!${NC}"
}

# 3. Memory Bottleneck Detection
memory_bottleneck_detection() {
    echo -e "\n${PURPLE}=== Memory Bottleneck Detection ===${NC}"
    
    if ! select_target; then return; fi

    echo -e "\n${GREEN}Profiling for memory bottlenecks...${NC}"
    
    OUTPUT="${RESULTS_DIR}/memory_bottleneck_${TARGET_NAME}_$(date +%Y%m%d_%H%M%S)"
    
    # Profile with memory-focused options
    nsys profile \
        --sample=cpu \
        --sampling-period=100000 \
        --trace=osrt \
        --backtrace=fp \
        --capture-range=nvtx \
        -o "$OUTPUT" \
        $TARGET
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Analyzing memory access patterns...${NC}"
        
        # Generate CPU sampling report with focus on memory operations
        nsys analyze --report cpusampling "$OUTPUT.nsys-rep" \
            > "${REPORTS_DIR}/memory_analysis_${TARGET_NAME}.txt" 2>&1
        
        echo -e "\n${YELLOW}Memory Bottleneck Indicators:${NC}"
        echo "1. High percentage of time in memory allocation/deallocation functions"
        echo "2. Cache miss indicators in CPU sampling"
        echo "3. Memory bandwidth saturation"
        
        # Look for common memory bottleneck indicators
        echo -e "\n${YELLOW}Checking for memory-related functions...${NC}"
        grep -E "(malloc|free|memcpy|memmove|operator new|operator delete)" \
            "${REPORTS_DIR}/memory_analysis_${TARGET_NAME}.txt" | head -20
    fi
}

# 4. Thread Contention Analysis
thread_contention_analysis() {
    echo -e "\n${PURPLE}=== Thread Contention Analysis ===${NC}"
    
    echo -e "${YELLOW}Select multi-threaded target:${NC}"
    echo "1. C++ multithreading example"
    echo "2. Python multiprocessing example"
    echo "3. Custom target"
    echo -n "Choice: "
    read choice

    case $choice in
        1)
            TARGET="cpp/bin/3_multithreading_example"
            TARGET_NAME="cpp_multithreading"
            ;;
        2)
            TARGET="python python/3_multiprocessing_example.py"
            TARGET_NAME="py_multiprocessing"
            ;;
        3)
            if ! select_target; then return; fi
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return
            ;;
    esac

    OUTPUT="${RESULTS_DIR}/thread_contention_${TARGET_NAME}_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${GREEN}Profiling for thread contention...${NC}"
    
    nsys profile \
        --sample=cpu \
        --cpuctxsw=true \
        --trace=osrt,nvtx \
        --sampling-period=10000 \
        -o "$OUTPUT" \
        $TARGET
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Analyzing thread behavior...${NC}"
        
        # Generate OS runtime summary
        nsys analyze --report osrtsum "$OUTPUT.nsys-rep" \
            > "${REPORTS_DIR}/thread_analysis_${TARGET_NAME}.txt" 2>&1
        
        echo -e "\n${YELLOW}Thread Contention Indicators:${NC}"
        echo "- High context switch rate"
        echo "- Time spent in synchronization primitives (mutex, locks)"
        echo "- Uneven CPU utilization across threads"
        
        # Generate stats
        nsys stats "$OUTPUT.nsys-rep" > "${REPORTS_DIR}/thread_stats_${TARGET_NAME}.txt"
        
        echo -e "\n${YELLOW}Context switch summary:${NC}"
        grep -i "context switch" "${REPORTS_DIR}/thread_stats_${TARGET_NAME}.txt" | head -10
    fi
}

# 5. Hot Function Analysis
hot_function_analysis() {
    echo -e "\n${PURPLE}=== Hot Function Analysis ===${NC}"
    
    if ! select_target; then return; fi

    OUTPUT="${RESULTS_DIR}/hot_functions_${TARGET_NAME}_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${GREEN}Profiling to identify hot functions...${NC}"
    
    nsys profile \
        --sample=cpu \
        --sampling-period=10000 \
        --trace=osrt,nvtx \
        --duration=30 \
        -o "$OUTPUT" \
        $TARGET
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Analyzing hot functions...${NC}"
        
        # Generate detailed CPU sampling report
        nsys stats "$OUTPUT.nsys-rep" > "${REPORTS_DIR}/hot_functions_${TARGET_NAME}.txt"
        
        echo -e "\n${YELLOW}Top 10 Hot Functions:${NC}"
        # Extract and display hot functions
        grep -A 15 "Top Functions" "${REPORTS_DIR}/hot_functions_${TARGET_NAME}.txt" 2>/dev/null || \
        grep -A 15 "CPU Functions" "${REPORTS_DIR}/hot_functions_${TARGET_NAME}.txt" 2>/dev/null
        
        # Generate flame graph data (if supported)
        echo -e "\n${YELLOW}Generating call tree analysis...${NC}"
        nsys analyze --report cpusampling --format csv "$OUTPUT.nsys-rep" \
            > "${REPORTS_DIR}/hot_functions_${TARGET_NAME}.csv" 2>&1
    fi
}

# 6. I/O Performance Analysis
io_performance_analysis() {
    echo -e "\n${PURPLE}=== I/O Performance Analysis ===${NC}"
    
    echo -e "${YELLOW}Select I/O intensive target:${NC}"
    echo "1. Python I/O bound example"
    echo "2. Custom target"
    echo -n "Choice: "
    read choice

    case $choice in
        1)
            TARGET="python python/5_io_bound_example.py"
            TARGET_NAME="py_io_bound"
            ;;
        2)
            if ! select_target; then return; fi
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return
            ;;
    esac

    OUTPUT="${RESULTS_DIR}/io_performance_${TARGET_NAME}_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${GREEN}Profiling I/O performance...${NC}"
    
    nsys profile \
        --sample=cpu \
        --trace=osrt \
        --sampling-period=100000 \
        -o "$OUTPUT" \
        $TARGET
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Analyzing I/O patterns...${NC}"
        
        # Generate OS runtime report
        nsys analyze --report osrtsum "$OUTPUT.nsys-rep" \
            > "${REPORTS_DIR}/io_analysis_${TARGET_NAME}.txt" 2>&1
        
        echo -e "\n${YELLOW}I/O Performance Indicators:${NC}"
        echo "- Time spent in I/O system calls (read, write, open, close)"
        echo "- I/O wait time vs CPU time"
        echo "- File system operation frequency"
        
        # Look for I/O related functions
        echo -e "\n${YELLOW}I/O related functions:${NC}"
        nsys stats "$OUTPUT.nsys-rep" | grep -E "(read|write|open|close|fread|fwrite|aio_)" | head -20
    fi
}

# 7. Custom Metric Collection
custom_metric_collection() {
    echo -e "\n${PURPLE}=== Custom Metric Collection ===${NC}"
    
    if ! select_target; then return; fi

    echo -e "\n${YELLOW}Available metrics:${NC}"
    echo "1. CPU cycles and instructions"
    echo "2. Cache misses"
    echo "3. Branch predictions"
    echo "4. Memory bandwidth"
    echo "5. Custom perf events"
    echo -n "Select metrics (comma-separated, e.g., 1,2,4): "
    read metric_choices

    OPTS="--sample=cpu"
    SUFFIX="custom"

    # Parse metric choices
    IFS=',' read -ra METRICS <<< "$metric_choices"
    for metric in "${METRICS[@]}"; do
        case $metric in
            1) 
                OPTS="$OPTS --cpuctxsw=true"
                SUFFIX="${SUFFIX}_cpu"
                ;;
            2) 
                OPTS="$OPTS --backtrace=fp"
                SUFFIX="${SUFFIX}_cache"
                ;;
            3) 
                OPTS="$OPTS --trace=osrt"
                SUFFIX="${SUFFIX}_branch"
                ;;
            4) 
                OPTS="$OPTS --sampling-period=10000"
                SUFFIX="${SUFFIX}_mem"
                ;;
            5) 
                echo -n "Enter custom perf event: "
                read perf_event
                # Note: Custom perf events require specific system support
                ;;
        esac
    done

    OUTPUT="${RESULTS_DIR}/custom_metrics_${TARGET_NAME}_${SUFFIX}_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${GREEN}Collecting custom metrics...${NC}"
    echo "Command: nsys profile $OPTS -o $OUTPUT $TARGET"
    
    nsys profile $OPTS -o "$OUTPUT" $TARGET
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Generating custom metric report...${NC}"
        nsys stats "$OUTPUT.nsys-rep" > "${REPORTS_DIR}/custom_metrics_${TARGET_NAME}.txt"
        
        echo -e "\n${GREEN}Custom metrics collected successfully!${NC}"
        echo "Results: ${OUTPUT}.nsys-rep"
        echo "Report: ${REPORTS_DIR}/custom_metrics_${TARGET_NAME}.txt"
    fi
}

# 8. Generate Comprehensive Report
generate_comprehensive_report() {
    echo -e "\n${PURPLE}=== Generate Comprehensive Report ===${NC}"
    
    echo -e "${YELLOW}Select profiling result to analyze:${NC}"
    ls -1t results/*.nsys-rep 2>/dev/null | head -20 | cat -n
    echo -n "Select number: "
    read num
    
    PROFILE=$(ls -1t results/*.nsys-rep 2>/dev/null | sed -n "${num}p")
    
    if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
        echo -e "${RED}Invalid selection${NC}"
        return
    fi
    
    BASE=$(basename "$PROFILE" .nsys-rep)
    REPORT_DIR="${REPORTS_DIR}/${BASE}_comprehensive"
    mkdir -p "$REPORT_DIR"
    
    echo -e "\n${GREEN}Generating comprehensive report for: $BASE${NC}"
    
    # 1. Basic statistics
    echo -e "\n${BLUE}1. Generating basic statistics...${NC}"
    nsys stats "$PROFILE" > "$REPORT_DIR/01_basic_stats.txt"
    
    # 2. CPU sampling analysis
    echo -e "${BLUE}2. Analyzing CPU sampling...${NC}"
    nsys analyze --report cpusampling "$PROFILE" > "$REPORT_DIR/02_cpu_sampling.txt" 2>&1
    
    # 3. OS runtime analysis
    echo -e "${BLUE}3. Analyzing OS runtime...${NC}"
    nsys analyze --report osrtsum "$PROFILE" > "$REPORT_DIR/03_os_runtime.txt" 2>&1
    
    # 4. NVTX analysis (if available)
    echo -e "${BLUE}4. Analyzing NVTX markers...${NC}"
    nsys analyze --report nvtxsum "$PROFILE" > "$REPORT_DIR/04_nvtx.txt" 2>&1
    
    # 5. Export to SQLite
    echo -e "${BLUE}5. Exporting to SQLite...${NC}"
    nsys export --type=sqlite --output="$REPORT_DIR/05_database.sqlite" "$PROFILE" 2>&1
    
    # 6. Generate summary
    echo -e "${BLUE}6. Creating summary report...${NC}"
    cat > "$REPORT_DIR/00_summary.md" << EOF
# Comprehensive Profiling Report
## Profile: $BASE
## Generated: $(date)

### Overview
$(grep -m 1 "Duration:" "$REPORT_DIR/01_basic_stats.txt" 2>/dev/null || echo "Duration: N/A")
$(grep -m 1 "Total CPU" "$REPORT_DIR/01_basic_stats.txt" 2>/dev/null || echo "CPU Info: N/A")

### Hot Functions
$(grep -A 10 "Top Functions" "$REPORT_DIR/01_basic_stats.txt" 2>/dev/null | head -15)

### Files Generated
1. 01_basic_stats.txt - Basic profiling statistics
2. 02_cpu_sampling.txt - Detailed CPU sampling analysis
3. 03_os_runtime.txt - OS runtime analysis
4. 04_nvtx.txt - NVTX marker analysis
5. 05_database.sqlite - SQLite database for custom queries

### Recommendations
- Review hot functions in 01_basic_stats.txt
- Check CPU sampling patterns in 02_cpu_sampling.txt
- Analyze thread behavior in 03_os_runtime.txt
- Use SQLite database for custom analysis queries
EOF

    echo -e "\n${GREEN}Comprehensive report generated!${NC}"
    echo "Location: $REPORT_DIR"
    echo ""
    echo "Files created:"
    ls -la "$REPORT_DIR/"
}

# 9. Profile with Different Optimization Levels
optimization_comparison() {
    echo -e "\n${PURPLE}=== Profile with Different Optimization Levels ===${NC}"
    
    echo -e "${YELLOW}This requires recompiling C++ code with different optimization flags${NC}"
    echo "Select C++ example to test:"
    ls -1 cpp/*.cpp | grep -v nvtx | cat -n
    echo -n "Select number: "
    read num
    
    SOURCE=$(ls -1 cpp/*.cpp | grep -v nvtx | sed -n "${num}p")
    if [ -z "$SOURCE" ]; then
        echo -e "${RED}Invalid selection${NC}"
        return
    fi
    
    BASE=$(basename "$SOURCE" .cpp)
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Optimization levels to test
    OPT_LEVELS=("-O0" "-O1" "-O2" "-O3" "-Os")
    
    for opt in "${OPT_LEVELS[@]}"; do
        echo -e "\n${GREEN}Compiling with $opt...${NC}"
        
        OUTPUT_BIN="cpp/bin/${BASE}_${opt#-}"
        g++ $opt -g -std=c++17 -pthread "$SOURCE" -o "$OUTPUT_BIN"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Profiling with $opt...${NC}"
            
            nsys profile \
                --sample=cpu \
                --trace=osrt \
                --duration=10 \
                -o "${RESULTS_DIR}/opt_comparison_${BASE}_${opt#-}_${TIMESTAMP}" \
                "$OUTPUT_BIN"
            
            # Clean up binary
            rm -f "$OUTPUT_BIN"
        else
            echo -e "${RED}Compilation failed for $opt${NC}"
        fi
    done
    
    echo -e "\n${GREEN}Optimization comparison complete!${NC}"
    echo "Results saved with prefix: opt_comparison_${BASE}_*_${TIMESTAMP}"
    
    # Generate comparison summary
    echo -e "\n${YELLOW}Generating comparison summary...${NC}"
    SUMMARY_FILE="${REPORTS_DIR}/optimization_comparison_${BASE}_${TIMESTAMP}.txt"
    echo "Optimization Level Comparison for $BASE" > "$SUMMARY_FILE"
    echo "=====================================" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
    
    for opt in "${OPT_LEVELS[@]}"; do
        PROFILE="${RESULTS_DIR}/opt_comparison_${BASE}_${opt#-}_${TIMESTAMP}.nsys-rep"
        if [ -f "$PROFILE" ]; then
            echo "Optimization: $opt" >> "$SUMMARY_FILE"
            nsys stats "$PROFILE" | grep -E "(Duration:|Total CPU)" >> "$SUMMARY_FILE"
            echo "---" >> "$SUMMARY_FILE"
        fi
    done
    
    echo "Summary saved to: $SUMMARY_FILE"
}

# Main loop
while true; do
    show_menu
    echo -n "Enter choice: "
    read choice
    
    case $choice in
        1) interactive_profiling ;;
        2) comparative_analysis ;;
        3) memory_bottleneck_detection ;;
        4) thread_contention_analysis ;;
        5) hot_function_analysis ;;
        6) io_performance_analysis ;;
        7) custom_metric_collection ;;
        8) generate_comprehensive_report ;;
        9) optimization_comparison ;;
        0) 
            echo -e "\n${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
done