#!/usr/bin/env python3
"""
Interactive runner for profiling examples
Provides a menu-driven interface to run individual examples
"""

import os
import sys
import subprocess
from pathlib import Path


def check_venv():
    """Check if running in virtual environment"""
    if not hasattr(sys, 'real_prefix') and not (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print("Warning: Not running in a virtual environment!")
        print("It's recommended to activate the virtual environment first:")
        print("  source venv/bin/activate")
        print("")
        response = input("Continue anyway? (y/N): ")
        if response.lower() != 'y':
            sys.exit(1)


def check_nsys():
    """Check if nsys is available"""
    try:
        subprocess.run(['nsys', '--version'], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: nsys not found in PATH!")
        print("Please install NVIDIA Nsight Systems first.")
        return False


def list_examples():
    """List all available examples"""
    python_examples = list(Path('python').glob('*.py'))
    cpp_examples = list(Path('cpp/bin').glob('*')) if Path('cpp/bin').exists() else []
    
    return {
        'python': sorted(python_examples),
        'cpp': sorted(cpp_examples)
    }


def run_python_example(script_path, profile=False):
    """Run a Python example"""
    if profile:
        output_name = f"results/py_{script_path.stem}"
        cmd = [
            'nsys', 'profile',
            '--sample=cpu',
            '--trace=osrt,nvtx',
            '-o', output_name,
            'python', str(script_path)
        ]
    else:
        cmd = ['python', str(script_path)]
    
    print(f"\nRunning: {' '.join(cmd)}")
    subprocess.run(cmd)


def run_cpp_example(binary_path, profile=False):
    """Run a C++ example"""
    if profile:
        output_name = f"results/cpp_{binary_path.stem}"
        cmd = [
            'nsys', 'profile',
            '--sample=cpu',
            '--trace=osrt,nvtx',
            '--cpuctxsw=true',
            '-o', output_name,
            str(binary_path)
        ]
    else:
        cmd = [str(binary_path)]
    
    print(f"\nRunning: {' '.join(cmd)}")
    subprocess.run(cmd)


def build_cpp_examples():
    """Build C++ examples"""
    print("\nBuilding C++ examples...")
    result = subprocess.run(['make', 'all'], capture_output=True, text=True)
    if result.returncode == 0:
        print("Build successful!")
    else:
        print("Build failed!")
        print(result.stderr)


def main_menu():
    """Display main menu and handle user input"""
    check_venv()
    
    if not check_nsys():
        print("\nNote: You can still run examples without profiling.")
    
    # Ensure results directory exists
    Path('results').mkdir(exist_ok=True)
    
    while True:
        print("\n" + "="*60)
        print("NVIDIA Nsight Systems CPU Profiling POC - Interactive Runner")
        print("="*60)
        
        examples = list_examples()
        
        print("\nPython Examples:")
        for i, example in enumerate(examples['python'], 1):
            print(f"  {i}. {example.stem}")
        
        print("\nC++ Examples:")
        if examples['cpp']:
            for i, example in enumerate(examples['cpp'], len(examples['python'])+1):
                print(f"  {i}. {example.stem}")
        else:
            print("  (Not built yet - use 'b' to build)")
        
        print("\nOptions:")
        print("  p: Run with profiling")
        print("  b: Build C++ examples")
        print("  a: Run all examples")
        print("  q: Quit")
        
        choice = input("\nEnter choice (number or letter): ").strip().lower()
        
        if choice == 'q':
            break
        elif choice == 'b':
            build_cpp_examples()
        elif choice == 'a':
            print("\nRunning all examples...")
            for example in examples['python']:
                run_python_example(example, profile=False)
            for example in examples['cpp']:
                run_cpp_example(example, profile=False)
        elif choice == 'p':
            profile_choice = input("Enter example number to profile: ").strip()
            try:
                idx = int(profile_choice) - 1
                all_examples = examples['python'] + examples['cpp']
                if 0 <= idx < len(all_examples):
                    if idx < len(examples['python']):
                        run_python_example(all_examples[idx], profile=True)
                    else:
                        run_cpp_example(all_examples[idx], profile=True)
                else:
                    print("Invalid example number!")
            except ValueError:
                print("Invalid input!")
        else:
            try:
                idx = int(choice) - 1
                all_examples = examples['python'] + examples['cpp']
                if 0 <= idx < len(all_examples):
                    if idx < len(examples['python']):
                        run_python_example(all_examples[idx], profile=False)
                    else:
                        run_cpp_example(all_examples[idx], profile=False)
                else:
                    print("Invalid example number!")
            except ValueError:
                print("Invalid input!")


if __name__ == "__main__":
    main_menu()