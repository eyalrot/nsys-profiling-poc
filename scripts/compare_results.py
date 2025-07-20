#!/usr/bin/env python3
"""
Compare and visualize profiling results from nsys
Generates comparative analysis and visualizations
"""

import os
import sys
import json
import re
from pathlib import Path
from typing import Dict, List, Tuple
import subprocess

try:
    import matplotlib.pyplot as plt
    import numpy as np
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    print("Warning: matplotlib not available. Install with: pip install matplotlib")
    MATPLOTLIB_AVAILABLE = False


def parse_stats_file(filepath: Path) -> Dict[str, any]:
    """Parse nsys stats output file"""
    stats = {
        'duration': None,
        'cpu_samples': 0,
        'context_switches': 0,
        'top_functions': [],
        'os_runtime_events': 0,
        'nvtx_events': 0
    }
    
    if not filepath.exists():
        return stats
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Extract duration
    duration_match = re.search(r'Duration:\s*([\d.]+)\s*seconds', content)
    if duration_match:
        stats['duration'] = float(duration_match.group(1))
    
    # Extract CPU samples
    samples_match = re.search(r'Total samples:\s*(\d+)', content)
    if samples_match:
        stats['cpu_samples'] = int(samples_match.group(1))
    
    # Extract context switches
    ctx_match = re.search(r'Context switches:\s*(\d+)', content)
    if ctx_match:
        stats['context_switches'] = int(ctx_match.group(1))
    
    # Extract top functions
    if 'Top Functions' in content:
        func_section = content.split('Top Functions')[1].split('\n\n')[0]
        for line in func_section.split('\n')[2:]:  # Skip header lines
            if line.strip() and '%' in line:
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        percentage = float(parts[0].strip('%'))
                        function = ' '.join(parts[1:])
                        stats['top_functions'].append((function, percentage))
                    except ValueError:
                        pass
    
    return stats


def compare_implementations(results_dir: Path) -> Dict[str, Dict]:
    """Compare Python and C++ implementations"""
    comparisons = {}
    
    # Define example pairs to compare
    example_pairs = [
        ('py_1_basic_cpu', 'cpp_1_basic_cpu', 'Basic CPU Profiling'),
        ('py_2_matrix_ops', 'cpp_2_matrix_ops', 'Matrix Operations'),
        ('py_3_multiprocessing', 'cpp_3_multithreading', 'Parallel Processing'),
        ('py_4_nvtx', 'cpp_4_nvtx', 'NVTX Annotations'),
        ('py_5_io_bound', 'cpp_5_memory', 'Memory/IO Intensive')
    ]
    
    for py_name, cpp_name, display_name in example_pairs:
        py_stats = parse_stats_file(results_dir / f"{py_name}_stats.txt")
        cpp_stats = parse_stats_file(results_dir / f"{cpp_name}_stats.txt")
        
        if py_stats['duration'] and cpp_stats['duration']:
            comparisons[display_name] = {
                'python': py_stats,
                'cpp': cpp_stats,
                'speedup': py_stats['duration'] / cpp_stats['duration']
            }
    
    return comparisons


def generate_performance_report(comparisons: Dict[str, Dict]) -> str:
    """Generate a detailed performance comparison report"""
    report = []
    report.append("# Performance Comparison Report")
    report.append("\n## Executive Summary\n")
    
    # Calculate average speedup
    speedups = [comp['speedup'] for comp in comparisons.values()]
    if speedups:
        avg_speedup = np.mean(speedups)
        report.append(f"- **Average C++ Speedup**: {avg_speedup:.2f}x faster than Python")
        report.append(f"- **Max Speedup**: {max(speedups):.2f}x")
        report.append(f"- **Min Speedup**: {min(speedups):.2f}x")
    
    report.append("\n## Detailed Comparison\n")
    
    for example, data in comparisons.items():
        report.append(f"### {example}")
        report.append(f"- **Python Duration**: {data['python']['duration']:.3f}s")
        report.append(f"- **C++ Duration**: {data['cpp']['duration']:.3f}s")
        report.append(f"- **Speedup**: {data['speedup']:.2f}x")
        
        # CPU sampling comparison
        if data['python']['cpu_samples'] > 0:
            report.append(f"- **Python CPU Samples**: {data['python']['cpu_samples']:,}")
        if data['cpp']['cpu_samples'] > 0:
            report.append(f"- **C++ CPU Samples**: {data['cpp']['cpu_samples']:,}")
        
        # Top functions
        report.append("\n**Top Functions (Python):**")
        for func, pct in data['python']['top_functions'][:5]:
            report.append(f"  - {func}: {pct:.1f}%")
        
        report.append("\n**Top Functions (C++):**")
        for func, pct in data['cpp']['top_functions'][:5]:
            report.append(f"  - {func}: {pct:.1f}%")
        
        report.append("")
    
    return '\n'.join(report)


def create_visualizations(comparisons: Dict[str, Dict], output_dir: Path):
    """Create visualization charts"""
    if not MATPLOTLIB_AVAILABLE:
        print("Skipping visualizations (matplotlib not available)")
        return
    
    # Speedup comparison chart
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    examples = list(comparisons.keys())
    speedups = [comparisons[ex]['speedup'] for ex in examples]
    
    # Speedup bar chart
    bars = ax1.bar(examples, speedups, color=['#2ecc71' if s > 1 else '#e74c3c' for s in speedups])
    ax1.axhline(y=1, color='black', linestyle='--', alpha=0.5)
    ax1.set_ylabel('Speedup (C++ vs Python)')
    ax1.set_title('Performance Speedup Comparison')
    ax1.set_ylim(0, max(speedups) * 1.2)
    
    # Add value labels on bars
    for bar, speedup in zip(bars, speedups):
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                f'{speedup:.2f}x', ha='center', va='bottom')
    
    # Execution time comparison
    py_times = [comparisons[ex]['python']['duration'] for ex in examples]
    cpp_times = [comparisons[ex]['cpp']['duration'] for ex in examples]
    
    x = np.arange(len(examples))
    width = 0.35
    
    bars1 = ax2.bar(x - width/2, py_times, width, label='Python', color='#3498db')
    bars2 = ax2.bar(x + width/2, cpp_times, width, label='C++', color='#e67e22')
    
    ax2.set_ylabel('Execution Time (seconds)')
    ax2.set_title('Execution Time Comparison')
    ax2.set_xticks(x)
    ax2.set_xticklabels(examples, rotation=45, ha='right')
    ax2.legend()
    
    plt.tight_layout()
    plt.savefig(output_dir / 'performance_comparison.png', dpi=150, bbox_inches='tight')
    plt.close()
    
    # CPU sampling efficiency chart
    fig, ax = plt.subplots(figsize=(10, 6))
    
    examples_with_samples = []
    py_samples_per_sec = []
    cpp_samples_per_sec = []
    
    for ex, data in comparisons.items():
        if data['python']['cpu_samples'] > 0 and data['cpp']['cpu_samples'] > 0:
            examples_with_samples.append(ex)
            py_samples_per_sec.append(data['python']['cpu_samples'] / data['python']['duration'])
            cpp_samples_per_sec.append(data['cpp']['cpu_samples'] / data['cpp']['duration'])
    
    if examples_with_samples:
        x = np.arange(len(examples_with_samples))
        width = 0.35
        
        bars1 = ax.bar(x - width/2, py_samples_per_sec, width, label='Python', color='#9b59b6')
        bars2 = ax.bar(x + width/2, cpp_samples_per_sec, width, label='C++', color='#1abc9c')
        
        ax.set_ylabel('CPU Samples per Second')
        ax.set_title('CPU Sampling Rate Comparison')
        ax.set_xticks(x)
        ax.set_xticklabels(examples_with_samples, rotation=45, ha='right')
        ax.legend()
        
        plt.tight_layout()
        plt.savefig(output_dir / 'cpu_sampling_comparison.png', dpi=150, bbox_inches='tight')
        plt.close()


def main():
    """Main function"""
    results_dir = Path('results')
    
    if not results_dir.exists():
        print("Error: results directory not found!")
        print("Please run profile_all.sh first to generate profiling data.")
        sys.exit(1)
    
    print("Analyzing profiling results...")
    
    # Compare implementations
    comparisons = compare_implementations(results_dir)
    
    if not comparisons:
        print("No valid comparison data found!")
        sys.exit(1)
    
    # Generate report
    report = generate_performance_report(comparisons)
    report_path = results_dir / 'detailed_comparison_report.md'
    with open(report_path, 'w') as f:
        f.write(report)
    print(f"✓ Detailed report saved to: {report_path}")
    
    # Create visualizations
    create_visualizations(comparisons, results_dir)
    if MATPLOTLIB_AVAILABLE:
        print(f"✓ Visualizations saved to: {results_dir}/")
    
    # Print summary
    print("\nPerformance Summary:")
    print("-" * 50)
    for example, data in comparisons.items():
        print(f"{example:30} Speedup: {data['speedup']:6.2f}x")
    
    print("\nAnalysis complete!")


if __name__ == "__main__":
    main()