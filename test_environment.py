#!/usr/bin/env python3
"""
Test script to verify the environment setup
"""

import sys
import importlib
from pathlib import Path


def test_python_version():
    """Check Python version"""
    print("Python Version:")
    print(f"  {sys.version}")
    
    if sys.version_info >= (3, 7):
        print("  ✓ Python 3.7+ detected")
        return True
    else:
        print("  ✗ Python 3.7+ required")
        return False


def test_virtual_env():
    """Check if running in virtual environment"""
    print("\nVirtual Environment:")
    
    in_venv = hasattr(sys, 'real_prefix') or (
        hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix
    )
    
    if in_venv:
        print("  ✓ Running in virtual environment")
        print(f"  Path: {sys.prefix}")
        return True
    else:
        print("  ⚠ Not running in virtual environment")
        print("  Run: source venv/bin/activate")
        return False


def test_imports():
    """Test required imports"""
    print("\nRequired Packages:")
    
    packages = {
        'numpy': 'Core numerical computing',
        'scipy': 'Scientific computing',
        'matplotlib': 'Plotting and visualization',
        'pandas': 'Data analysis',
        'nvtx': 'NVIDIA profiling annotations',
        'aiofiles': 'Async file operations',
        'tqdm': 'Progress bars',
        'psutil': 'System utilities'
    }
    
    all_good = True
    for package, description in packages.items():
        try:
            module = importlib.import_module(package)
            version = getattr(module, '__version__', 'unknown')
            print(f"  ✓ {package:12} {version:10} - {description}")
        except ImportError:
            print(f"  ✗ {package:12} {'missing':10} - {description}")
            all_good = False
    
    return all_good


def test_directories():
    """Check required directories"""
    print("\nProject Structure:")
    
    dirs = ['python', 'cpp', 'scripts', 'results']
    all_good = True
    
    for dir_name in dirs:
        dir_path = Path(dir_name)
        if dir_path.exists():
            file_count = len(list(dir_path.glob('*')))
            print(f"  ✓ {dir_name:10} ({file_count} files)")
        else:
            print(f"  ✗ {dir_name:10} (missing)")
            all_good = False
    
    return all_good


def test_nsys():
    """Check nsys availability"""
    print("\nNVIDIA Nsight Systems:")
    
    import subprocess
    try:
        result = subprocess.run(['nsys', '--version'], 
                              capture_output=True, text=True, check=True)
        version_line = result.stdout.strip().split('\n')[0]
        print(f"  ✓ nsys found: {version_line}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("  ✗ nsys not found in PATH")
        print("  Install from: https://developer.nvidia.com/nsight-systems")
        return False


def test_cpp_build():
    """Check if C++ examples are built"""
    print("\nC++ Build Status:")
    
    bin_dir = Path('cpp/bin')
    if bin_dir.exists():
        binaries = list(bin_dir.glob('*'))
        if binaries:
            print(f"  ✓ {len(binaries)} C++ examples built")
            for binary in binaries[:3]:
                print(f"    - {binary.name}")
            if len(binaries) > 3:
                print(f"    ... and {len(binaries) - 3} more")
            return True
        else:
            print("  ⚠ No C++ examples built yet")
            print("  Run: make all")
            return False
    else:
        print("  ⚠ C++ bin directory not found")
        print("  Run: make all")
        return False


def main():
    """Run all tests"""
    print("="*60)
    print("Environment Test for NVIDIA Nsight Systems Profiling POC")
    print("="*60)
    
    tests = [
        test_python_version(),
        test_virtual_env(),
        test_imports(),
        test_directories(),
        test_nsys(),
        test_cpp_build()
    ]
    
    print("\n" + "="*60)
    passed = sum(tests)
    total = len(tests)
    
    if passed == total:
        print(f"✓ All tests passed! ({passed}/{total})")
        print("\nYou're ready to run the profiling examples!")
        print("\nNext steps:")
        print("  1. Run an example: python python/1_basic_cpu_profiling.py")
        print("  2. Profile an example: ./scripts/profile_all.sh")
        print("  3. Use interactive runner: python run_example.py")
    else:
        print(f"⚠ Some tests failed ({passed}/{total} passed)")
        print("\nPlease fix the issues above before running examples.")
    
    return passed == total


if __name__ == "__main__":
    sys.exit(0 if main() else 1)