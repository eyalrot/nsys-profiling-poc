#!/bin/bash
# Analyze profiling results and generate reports

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Analyzing Nsight Systems Profiling Results${NC}"
echo "=========================================="
echo ""

# Check if results directory exists
if [ ! -d "results" ]; then
    echo -e "${RED}Error: results directory not found!${NC}"
    echo "Please run profile_all.sh first to generate profiling data."
    exit 1
fi

# Function to analyze a single profile
analyze_profile() {
    local file=$1
    local base=$(basename "$file" .nsys-rep)
    
    echo -e "\n${YELLOW}Analyzing: $base${NC}"
    echo "------------------------"
    
    # Generate basic stats
    echo -e "${BLUE}Generating statistics...${NC}"
    nsys stats "$file" > "results/${base}_stats.txt" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Stats saved to: results/${base}_stats.txt${NC}"
        
        # Extract key metrics
        echo -e "\n${BLUE}Key Metrics:${NC}"
        
        # CPU sampling summary
        if grep -q "Sampling" "results/${base}_stats.txt"; then
            echo -e "\nCPU Sampling Summary:"
            grep -A 10 "Top Functions" "results/${base}_stats.txt" 2>/dev/null || true
        fi
        
        # OS Runtime summary
        if grep -q "OS Runtime" "results/${base}_stats.txt"; then
            echo -e "\nOS Runtime Summary:"
            grep -A 10 "OS Runtime Summary" "results/${base}_stats.txt" 2>/dev/null || true
        fi
        
        # NVTX summary if present
        if grep -q "NVTX" "results/${base}_stats.txt"; then
            echo -e "\nNVTX Events Found"
        fi
    else
        echo -e "${RED}✗ Failed to generate stats${NC}"
    fi
    
    # Generate specific reports based on the profile type
    case "$base" in
        *multiprocessing*|*multithreading*)
            echo -e "\n${BLUE}Generating thread/process report...${NC}"
            nsys analyze --report osrtsum "$file" > "results/${base}_threads.txt" 2>/dev/null || true
            ;;
        *nvtx*)
            echo -e "\n${BLUE}Generating NVTX report...${NC}"
            nsys analyze --report nvtxsum "$file" > "results/${base}_nvtx.txt" 2>/dev/null || true
            ;;
        *memory*)
            echo -e "\n${BLUE}Generating memory access patterns...${NC}"
            nsys analyze --report cpusampling "$file" > "results/${base}_cpu_sampling.txt" 2>/dev/null || true
            ;;
    esac
}

# Function to generate comparative analysis
generate_comparison() {
    echo -e "\n${GREEN}=== Comparative Analysis ===${NC}"
    echo -e "\n${BLUE}Python vs C++ Performance Comparison${NC}"
    echo "-----------------------------------"
    
    # Create comparison file
    comparison_file="results/performance_comparison.txt"
    echo "Performance Comparison Report" > "$comparison_file"
    echo "Generated: $(date)" >> "$comparison_file"
    echo "" >> "$comparison_file"
    
    # Compare similar examples
    for example in "basic_cpu" "matrix_ops" "nvtx"; do
        py_stats="results/py_${example}_stats.txt"
        cpp_stats="results/cpp_${example}_stats.txt"
        
        if [ -f "$py_stats" ] && [ -f "$cpp_stats" ]; then
            echo -e "\n${example} Comparison:" | tee -a "$comparison_file"
            echo "Python:" | tee -a "$comparison_file"
            grep -E "Duration|Total CPU" "$py_stats" 2>/dev/null | head -5 | tee -a "$comparison_file" || true
            echo "" | tee -a "$comparison_file"
            echo "C++:" | tee -a "$comparison_file"
            grep -E "Duration|Total CPU" "$cpp_stats" 2>/dev/null | head -5 | tee -a "$comparison_file" || true
            echo "------------------------" | tee -a "$comparison_file"
        fi
    done
    
    echo -e "\n${GREEN}✓ Comparison saved to: $comparison_file${NC}"
}

# Function to generate summary report
generate_summary() {
    echo -e "\n${GREEN}=== Summary Report ===${NC}"
    
    summary_file="results/profiling_summary.md"
    
    cat > "$summary_file" << EOF
# NVIDIA Nsight Systems CPU Profiling Summary

Generated: $(date)

## Profiling Results Overview

### Python Examples

EOF
    
    for file in results/py_*.nsys-rep; do
        if [ -f "$file" ]; then
            base=$(basename "$file" .nsys-rep)
            echo "#### $base" >> "$summary_file"
            echo "" >> "$summary_file"
            if [ -f "results/${base}_stats.txt" ]; then
                echo "- Stats available: results/${base}_stats.txt" >> "$summary_file"
            fi
            echo "" >> "$summary_file"
        fi
    done
    
    echo "### C++ Examples" >> "$summary_file"
    echo "" >> "$summary_file"
    
    for file in results/cpp_*.nsys-rep; do
        if [ -f "$file" ]; then
            base=$(basename "$file" .nsys-rep)
            echo "#### $base" >> "$summary_file"
            echo "" >> "$summary_file"
            if [ -f "results/${base}_stats.txt" ]; then
                echo "- Stats available: results/${base}_stats.txt" >> "$summary_file"
            fi
            echo "" >> "$summary_file"
        fi
    done
    
    echo -e "\n${GREEN}✓ Summary saved to: $summary_file${NC}"
}

# Main analysis loop
echo -e "${BLUE}Processing profiling results...${NC}"

# Analyze each .nsys-rep file
for file in results/*.nsys-rep; do
    if [ -f "$file" ]; then
        analyze_profile "$file"
    fi
done

# Generate comparison report
generate_comparison

# Generate summary report
generate_summary

echo -e "\n${GREEN}=== Analysis Complete ===${NC}"
echo ""
echo "Generated reports:"
echo "  - Individual stats: results/*_stats.txt"
echo "  - Comparison report: results/performance_comparison.txt"
echo "  - Summary report: results/profiling_summary.md"
echo ""
echo "To view profiling results in GUI:"
echo "  nsys-ui results/<profile_name>.nsys-rep"