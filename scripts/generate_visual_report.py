#!/usr/bin/env python3
"""
Generate visual reports from NVIDIA Nsight Systems profiling data
Creates charts, graphs, and HTML reports for easy analysis
"""

import os
import sys
import json
import sqlite3
import argparse
from pathlib import Path
from datetime import datetime
import subprocess
from typing import Dict, List, Tuple, Optional

try:
    import matplotlib.pyplot as plt
    import seaborn as sns
    import pandas as pd
    import numpy as np
    VISUALIZATION_AVAILABLE = True
except ImportError:
    print("Warning: Visualization libraries not available.")
    print("Install with: pip install matplotlib seaborn pandas numpy")
    VISUALIZATION_AVAILABLE = False


class NSysReportGenerator:
    """Generate visual reports from nsys profiling data"""
    
    def __init__(self, results_dir: str = "results", reports_dir: str = "results/reports"):
        self.results_dir = Path(results_dir)
        self.reports_dir = Path(reports_dir)
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        
        # Set style for plots
        if VISUALIZATION_AVAILABLE:
            plt.style.use('seaborn-v0_8-darkgrid')
            sns.set_palette("husl")
    
    def find_profiles(self) -> List[Path]:
        """Find all .nsys-rep files in results directory"""
        return sorted(self.results_dir.glob("*.nsys-rep"))
    
    def extract_stats(self, profile_path: Path) -> Dict[str, any]:
        """Extract statistics from nsys profile using nsys stats command"""
        stats = {
            'name': profile_path.stem,
            'duration': None,
            'cpu_utilization': None,
            'top_functions': [],
            'context_switches': 0,
            'samples': 0
        }
        
        try:
            # Run nsys stats
            result = subprocess.run(
                ['nsys', 'stats', str(profile_path)],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse output
            lines = result.stdout.split('\n')
            for i, line in enumerate(lines):
                # Extract duration
                if 'Duration:' in line:
                    try:
                        duration_str = line.split('Duration:')[1].strip()
                        # Extract numeric value (assuming seconds)
                        stats['duration'] = float(duration_str.split()[0])
                    except:
                        pass
                
                # Extract top functions
                if 'Top Functions' in line or 'CPU Functions' in line:
                    # Parse the table that follows
                    j = i + 2  # Skip header lines
                    while j < len(lines) and lines[j].strip():
                        parts = lines[j].split()
                        if len(parts) >= 2 and '%' in parts[0]:
                            try:
                                percentage = float(parts[0].strip('%'))
                                function = ' '.join(parts[1:])
                                stats['top_functions'].append((function, percentage))
                            except:
                                pass
                        j += 1
                
                # Extract CPU samples
                if 'Total samples:' in line:
                    try:
                        stats['samples'] = int(line.split(':')[1].strip())
                    except:
                        pass
        
        except subprocess.CalledProcessError as e:
            print(f"Error extracting stats from {profile_path}: {e}")
        
        return stats
    
    def create_duration_comparison_chart(self, profiles_data: List[Dict]) -> Optional[Path]:
        """Create execution duration comparison chart"""
        if not VISUALIZATION_AVAILABLE:
            return None
        
        # Filter profiles with valid duration
        valid_profiles = [p for p in profiles_data if p['duration'] is not None]
        if not valid_profiles:
            return None
        
        # Separate Python and C++ profiles
        py_profiles = [p for p in valid_profiles if p['name'].startswith('py_')]
        cpp_profiles = [p for p in valid_profiles if p['name'].startswith('cpp_')]
        
        fig, ax = plt.subplots(figsize=(12, 6))
        
        # Prepare data
        all_profiles = py_profiles + cpp_profiles
        names = [p['name'] for p in all_profiles]
        durations = [p['duration'] for p in all_profiles]
        colors = ['#3498db'] * len(py_profiles) + ['#e74c3c'] * len(cpp_profiles)
        
        # Create bar chart
        bars = ax.bar(names, durations, color=colors)
        
        # Customize chart
        ax.set_xlabel('Profile Name', fontsize=12)
        ax.set_ylabel('Duration (seconds)', fontsize=12)
        ax.set_title('Execution Duration Comparison', fontsize=14, fontweight='bold')
        ax.tick_params(axis='x', rotation=45)
        
        # Add value labels on bars
        for bar, duration in zip(bars, durations):
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{duration:.2f}s', ha='center', va='bottom')
        
        # Add legend
        from matplotlib.patches import Patch
        legend_elements = [
            Patch(facecolor='#3498db', label='Python'),
            Patch(facecolor='#e74c3c', label='C++')
        ]
        ax.legend(handles=legend_elements, loc='upper right')
        
        plt.tight_layout()
        output_path = self.reports_dir / 'duration_comparison.png'
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        return output_path
    
    def create_hot_functions_chart(self, profile_data: Dict, top_n: int = 10) -> Optional[Path]:
        """Create hot functions chart for a single profile"""
        if not VISUALIZATION_AVAILABLE or not profile_data['top_functions']:
            return None
        
        # Get top N functions
        functions = profile_data['top_functions'][:top_n]
        if not functions:
            return None
        
        names = [f[0][:50] + '...' if len(f[0]) > 50 else f[0] for f in functions]
        percentages = [f[1] for f in functions]
        
        fig, ax = plt.subplots(figsize=(10, 6))
        
        # Create horizontal bar chart
        y_pos = np.arange(len(names))
        bars = ax.barh(y_pos, percentages, color='#2ecc71')
        
        # Customize chart
        ax.set_yticks(y_pos)
        ax.set_yticklabels(names)
        ax.set_xlabel('CPU Time (%)', fontsize=12)
        ax.set_title(f'Top {top_n} Hot Functions - {profile_data["name"]}', 
                    fontsize=14, fontweight='bold')
        
        # Add percentage labels
        for i, (bar, pct) in enumerate(zip(bars, percentages)):
            ax.text(bar.get_width() + 0.3, bar.get_y() + bar.get_height()/2,
                   f'{pct:.1f}%', ha='left', va='center')
        
        plt.tight_layout()
        output_path = self.reports_dir / f'hot_functions_{profile_data["name"]}.png'
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        return output_path
    
    def create_performance_matrix(self, profiles_data: List[Dict]) -> Optional[Path]:
        """Create a performance comparison matrix"""
        if not VISUALIZATION_AVAILABLE:
            return None
        
        # Group profiles by type
        profile_types = {}
        for p in profiles_data:
            base_name = p['name'].replace('py_', '').replace('cpp_', '')
            base_name = base_name.split('_')[0] if '_' in base_name else base_name
            
            if base_name not in profile_types:
                profile_types[base_name] = {}
            
            if p['name'].startswith('py_'):
                profile_types[base_name]['python'] = p
            elif p['name'].startswith('cpp_'):
                profile_types[base_name]['cpp'] = p
        
        # Create comparison data
        comparisons = []
        for test_name, langs in profile_types.items():
            if 'python' in langs and 'cpp' in langs:
                py_duration = langs['python']['duration']
                cpp_duration = langs['cpp']['duration']
                
                if py_duration and cpp_duration:
                    speedup = py_duration / cpp_duration
                    comparisons.append({
                        'Test': test_name,
                        'Python (s)': py_duration,
                        'C++ (s)': cpp_duration,
                        'Speedup': speedup
                    })
        
        if not comparisons:
            return None
        
        # Create DataFrame
        df = pd.DataFrame(comparisons)
        
        # Create figure with subplots
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
        
        # Speedup bar chart
        bars = ax1.bar(df['Test'], df['Speedup'], color='#9b59b6')
        ax1.axhline(y=1, color='black', linestyle='--', alpha=0.5)
        ax1.set_ylabel('Speedup Factor (C++ vs Python)', fontsize=12)
        ax1.set_title('Performance Speedup Comparison', fontsize=14, fontweight='bold')
        ax1.tick_params(axis='x', rotation=45)
        
        # Add speedup labels
        for bar, speedup in zip(bars, df['Speedup']):
            ax1.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 0.1,
                    f'{speedup:.1f}x', ha='center', va='bottom')
        
        # Time comparison
        x = np.arange(len(df['Test']))
        width = 0.35
        
        bars1 = ax2.bar(x - width/2, df['Python (s)'], width, label='Python', color='#3498db')
        bars2 = ax2.bar(x + width/2, df['C++ (s)'], width, label='C++', color='#e74c3c')
        
        ax2.set_ylabel('Execution Time (seconds)', fontsize=12)
        ax2.set_title('Execution Time Comparison', fontsize=14, fontweight='bold')
        ax2.set_xticks(x)
        ax2.set_xticklabels(df['Test'], rotation=45)
        ax2.legend()
        
        plt.tight_layout()
        output_path = self.reports_dir / 'performance_matrix.png'
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        return output_path
    
    def generate_html_report(self, profiles_data: List[Dict], charts: List[Path]) -> Path:
        """Generate comprehensive HTML report"""
        html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>NVIDIA Nsight Systems Profiling Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            text-align: center;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        .summary {
            background-color: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .profile-section {
            margin: 20px 0;
            padding: 15px;
            border: 1px solid #bdc3c7;
            border-radius: 5px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .chart {
            text-align: center;
            margin: 20px 0;
        }
        .chart img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .timestamp {
            text-align: right;
            color: #7f8c8d;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>NVIDIA Nsight Systems Profiling Report</h1>
        <p class="timestamp">Generated: {timestamp}</p>
        
        <div class="summary">
            <h2>Summary</h2>
            <p>Total profiles analyzed: {total_profiles}</p>
            <p>Python profiles: {python_profiles}</p>
            <p>C++ profiles: {cpp_profiles}</p>
        </div>
        
        {charts_section}
        
        <h2>Profile Details</h2>
        {profiles_section}
        
        <div class="summary">
            <h2>Recommendations</h2>
            <ul>
                <li>Review hot functions to identify optimization opportunities</li>
                <li>Compare Python vs C++ implementations for performance insights</li>
                <li>Use nsys-ui for detailed interactive analysis</li>
                <li>Consider NVTX annotations for better profiling granularity</li>
            </ul>
        </div>
    </div>
</body>
</html>
        """
        
        # Count profiles
        python_count = sum(1 for p in profiles_data if p['name'].startswith('py_'))
        cpp_count = sum(1 for p in profiles_data if p['name'].startswith('cpp_'))
        
        # Generate charts section
        charts_html = ""
        if charts:
            charts_html = "<h2>Performance Charts</h2>\n"
            for chart in charts:
                if chart and chart.exists():
                    rel_path = os.path.relpath(chart, self.reports_dir)
                    charts_html += f'<div class="chart"><img src="{rel_path}" alt="{chart.stem}"></div>\n'
        
        # Generate profiles section
        profiles_html = ""
        for profile in profiles_data:
            profiles_html += f"""
        <div class="profile-section">
            <h3>{profile['name']}</h3>
            <table>
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Duration</td><td>{profile['duration']:.3f}s</td></tr>
                <tr><td>CPU Samples</td><td>{profile['samples']:,}</td></tr>
                <tr><td>Context Switches</td><td>{profile['context_switches']:,}</td></tr>
            </table>
            """
            
            if profile['top_functions']:
                profiles_html += """
            <h4>Top 5 Functions</h4>
            <table>
                <tr><th>Function</th><th>CPU Time %</th></tr>
                """
                for func, pct in profile['top_functions'][:5]:
                    profiles_html += f"<tr><td>{func}</td><td>{pct:.1f}%</td></tr>\n"
                profiles_html += "</table>\n"
            
            profiles_html += "</div>\n"
        
        # Fill template
        html_final = html_content.format(
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            total_profiles=len(profiles_data),
            python_profiles=python_count,
            cpp_profiles=cpp_count,
            charts_section=charts_html,
            profiles_section=profiles_html
        )
        
        # Save HTML
        output_path = self.reports_dir / 'profiling_report.html'
        with open(output_path, 'w') as f:
            f.write(html_final)
        
        return output_path
    
    def generate_report(self, profile_filter: Optional[str] = None):
        """Generate complete visual report"""
        print("Generating visual profiling report...")
        
        # Find profiles
        profiles = self.find_profiles()
        if profile_filter:
            profiles = [p for p in profiles if profile_filter in str(p)]
        
        if not profiles:
            print("No profiling results found!")
            return
        
        print(f"Found {len(profiles)} profiles to analyze")
        
        # Extract stats from all profiles
        profiles_data = []
        for profile in profiles:
            print(f"Analyzing {profile.name}...")
            stats = self.extract_stats(profile)
            if stats['duration'] is not None:
                profiles_data.append(stats)
        
        if not profiles_data:
            print("No valid profile data extracted!")
            return
        
        # Generate charts
        charts = []
        
        if VISUALIZATION_AVAILABLE:
            print("Generating visualizations...")
            
            # Duration comparison
            chart = self.create_duration_comparison_chart(profiles_data)
            if chart:
                charts.append(chart)
                print(f"✓ Created duration comparison chart")
            
            # Performance matrix
            chart = self.create_performance_matrix(profiles_data)
            if chart:
                charts.append(chart)
                print(f"✓ Created performance matrix")
            
            # Hot functions for each profile
            for profile in profiles_data[:5]:  # Limit to first 5
                chart = self.create_hot_functions_chart(profile)
                if chart:
                    charts.append(chart)
                    print(f"✓ Created hot functions chart for {profile['name']}")
        
        # Generate HTML report
        print("Generating HTML report...")
        html_path = self.generate_html_report(profiles_data, charts)
        
        print(f"\n✓ Report generated successfully!")
        print(f"  HTML Report: {html_path}")
        print(f"  Charts: {self.reports_dir}/*.png")
        
        # Open in browser
        try:
            import webbrowser
            webbrowser.open(f"file://{html_path.absolute()}")
            print("  Report opened in browser")
        except:
            print(f"  Open in browser: file://{html_path.absolute()}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate visual reports from NVIDIA Nsight Systems profiling data"
    )
    parser.add_argument(
        '--results-dir',
        default='results',
        help='Directory containing .nsys-rep files (default: results)'
    )
    parser.add_argument(
        '--reports-dir',
        default='results/reports',
        help='Directory for output reports (default: results/reports)'
    )
    parser.add_argument(
        '--filter',
        help='Filter profiles by name (e.g., "cpp_" or "matrix")'
    )
    
    args = parser.parse_args()
    
    # Create report generator
    generator = NSysReportGenerator(args.results_dir, args.reports_dir)
    
    # Generate report
    generator.generate_report(args.filter)


if __name__ == "__main__":
    main()