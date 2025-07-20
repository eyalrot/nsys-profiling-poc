#!/usr/bin/env python3
"""
NVTX Annotations Example
Demonstrates how to use NVTX markers for detailed profiling with nsys.
Note: Requires 'pip install nvtx' or 'pip install pynvtx'
"""

import time
import numpy as np
from typing import List, Dict, Any
import functools

try:
    import nvtx
    NVTX_AVAILABLE = True
except ImportError:
    print("Warning: nvtx module not found. Install with: pip install nvtx")
    print("Falling back to dummy implementation...")
    NVTX_AVAILABLE = False
    
    # Dummy NVTX implementation for demonstration
    class DummyNVTX:
        @staticmethod
        def annotate(message=None, color=None, domain=None):
            def decorator(func):
                return func
            if callable(message):
                return message
            return decorator
        
        @staticmethod
        def push_range(message, color=None, domain=None):
            pass
        
        @staticmethod
        def pop_range():
            pass
    
    nvtx = DummyNVTX()


# Custom decorator for timing with NVTX
def profile_function(name: str = None, color: str = "blue"):
    """Decorator that adds NVTX annotations and timing"""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            func_name = name or func.__name__
            nvtx.push_range(func_name, color=color)
            start = time.time()
            
            try:
                result = func(*args, **kwargs)
                return result
            finally:
                elapsed = time.time() - start
                nvtx.pop_range()
                print(f"   {func_name}: {elapsed:.3f}s")
        
        return wrapper
    return decorator


@nvtx.annotate("DataPreprocessing", color="red")
def preprocess_data(size: int) -> np.ndarray:
    """Simulate data preprocessing with NVTX annotation"""
    # Data loading phase
    nvtx.push_range("LoadData", color="yellow")
    data = np.random.randn(size, 100)
    time.sleep(0.1)  # Simulate I/O
    nvtx.pop_range()
    
    # Normalization phase
    nvtx.push_range("Normalize", color="green")
    mean = np.mean(data, axis=0)
    std = np.std(data, axis=0)
    normalized = (data - mean) / (std + 1e-8)
    nvtx.pop_range()
    
    # Feature extraction phase
    nvtx.push_range("ExtractFeatures", color="blue")
    features = np.concatenate([
        normalized,
        np.square(normalized),
        np.abs(normalized)
    ], axis=1)
    nvtx.pop_range()
    
    return features


@profile_function("ModelTraining", color="purple")
def train_model(data: np.ndarray, epochs: int = 10):
    """Simulate model training with nested NVTX ranges"""
    n_samples, n_features = data.shape
    weights = np.random.randn(n_features)
    learning_rate = 0.01
    
    for epoch in range(epochs):
        nvtx.push_range(f"Epoch_{epoch}", color="orange")
        
        # Forward pass
        nvtx.push_range("Forward", color="cyan")
        predictions = np.dot(data, weights)
        loss = np.mean(np.square(predictions))
        nvtx.pop_range()
        
        # Backward pass
        nvtx.push_range("Backward", color="magenta")
        gradients = 2 * np.dot(data.T, predictions) / n_samples
        weights -= learning_rate * gradients
        nvtx.pop_range()
        
        nvtx.pop_range()  # End epoch
    
    return weights


class DataPipeline:
    """Example class using NVTX annotations for method profiling"""
    
    def __init__(self, batch_size: int = 32):
        self.batch_size = batch_size
        self.data_cache = {}
    
    @nvtx.annotate("Pipeline.load", color="red")
    def load_batch(self, batch_id: int) -> np.ndarray:
        """Load a batch of data"""
        if batch_id in self.data_cache:
            return self.data_cache[batch_id]
        
        # Simulate data loading
        time.sleep(0.05)
        data = np.random.randn(self.batch_size, 50)
        self.data_cache[batch_id] = data
        return data
    
    @nvtx.annotate("Pipeline.transform", color="green")
    def transform_batch(self, data: np.ndarray) -> np.ndarray:
        """Apply transformations to batch"""
        # Multiple transformation steps
        with nvtx.annotate("FFT", color="yellow"):
            fft_data = np.fft.fft(data, axis=1)
        
        with nvtx.annotate("Filter", color="blue"):
            filtered = np.real(fft_data) * 0.5
        
        with nvtx.annotate("Inverse_FFT", color="cyan"):
            result = np.fft.ifft(filtered, axis=1).real
        
        return result
    
    @nvtx.annotate("Pipeline.process", color="purple")
    def process_batches(self, num_batches: int) -> List[np.ndarray]:
        """Process multiple batches through the pipeline"""
        results = []
        
        for i in range(num_batches):
            nvtx.push_range(f"Batch_{i}", color="orange")
            data = self.load_batch(i)
            transformed = self.transform_batch(data)
            results.append(transformed)
            nvtx.pop_range()
        
        return results


def complex_workflow():
    """Demonstrate a complex workflow with multiple NVTX domains"""
    print("\n5. Complex Workflow with Multiple Domains:")
    
    # Domain for data operations
    data_domain = "DataOps" if NVTX_AVAILABLE else None
    # Domain for compute operations  
    compute_domain = "ComputeOps" if NVTX_AVAILABLE else None
    
    # Phase 1: Data preparation
    nvtx.push_range("DataPreparation", color="red", domain=data_domain)
    
    datasets = []
    for i in range(3):
        nvtx.push_range(f"LoadDataset_{i}", color="yellow", domain=data_domain)
        data = np.random.randn(1000, 50)
        time.sleep(0.1)
        datasets.append(data)
        nvtx.pop_range()
    
    nvtx.pop_range()  # End data preparation
    
    # Phase 2: Parallel processing simulation
    nvtx.push_range("ParallelProcessing", color="green", domain=compute_domain)
    
    results = []
    for i, data in enumerate(datasets):
        nvtx.push_range(f"ProcessDataset_{i}", color="blue", domain=compute_domain)
        
        # Simulate complex computation
        result = np.fft.fft2(data)
        result = np.abs(result)
        result = np.log1p(result)
        
        results.append(result)
        nvtx.pop_range()
    
    nvtx.pop_range()  # End parallel processing
    
    # Phase 3: Aggregation
    nvtx.push_range("Aggregation", color="purple", domain=compute_domain)
    final_result = np.mean(results, axis=0)
    nvtx.pop_range()
    
    print("   Complex workflow completed")
    return final_result


def benchmark_with_annotations():
    """Benchmark different algorithms with NVTX annotations"""
    print("\n6. Algorithm Comparison with Annotations:")
    
    size = 10000
    data = np.random.randn(size)
    
    # Bubble sort (intentionally inefficient)
    @nvtx.annotate("BubbleSort", color="red")
    def bubble_sort(arr):
        arr = arr.copy()
        n = len(arr)
        for i in range(n):
            if i % 1000 == 0:  # Add range markers for progress
                nvtx.push_range(f"BubbleSort_Progress_{i//1000}", color="yellow")
            
            for j in range(0, n-i-1):
                if arr[j] > arr[j+1]:
                    arr[j], arr[j+1] = arr[j+1], arr[j]
            
            if i % 1000 == 0:
                nvtx.pop_range()
        return arr
    
    # Quick sort
    @nvtx.annotate("QuickSort", color="green")
    def quick_sort(arr):
        arr = arr.copy()
        
        def _quick_sort(arr, low, high):
            if low < high:
                pi = partition(arr, low, high)
                _quick_sort(arr, low, pi-1)
                _quick_sort(arr, pi+1, high)
        
        def partition(arr, low, high):
            pivot = arr[high]
            i = low - 1
            for j in range(low, high):
                if arr[j] < pivot:
                    i += 1
                    arr[i], arr[j] = arr[j], arr[i]
            arr[i+1], arr[high] = arr[high], arr[i+1]
            return i + 1
        
        _quick_sort(arr, 0, len(arr)-1)
        return arr
    
    # NumPy sort
    @nvtx.annotate("NumpySort", color="blue")
    def numpy_sort(arr):
        return np.sort(arr)
    
    # Run comparisons
    small_data = data[:1000]  # Use smaller size for bubble sort
    
    start = time.time()
    bubble_result = bubble_sort(small_data)
    bubble_time = time.time() - start
    
    start = time.time()
    quick_result = quick_sort(data)
    quick_time = time.time() - start
    
    start = time.time()
    numpy_result = numpy_sort(data)
    numpy_time = time.time() - start
    
    print(f"   Bubble sort (n=1000): {bubble_time:.3f}s")
    print(f"   Quick sort (n=10000): {quick_time:.3f}s")
    print(f"   NumPy sort (n=10000): {numpy_time:.3f}s")


def main():
    print("NVTX Annotations Profiling Examples")
    print(f"NVTX Available: {NVTX_AVAILABLE}")
    print("=" * 60)
    
    # Example 1: Basic function annotation
    print("\n1. Basic Function Annotations:")
    data = preprocess_data(10000)
    print(f"   Preprocessed data shape: {data.shape}")
    
    # Example 2: Nested annotations in training
    print("\n2. Model Training with Nested Annotations:")
    weights = train_model(data[:1000], epochs=5)
    print(f"   Final weights norm: {np.linalg.norm(weights):.3f}")
    
    # Example 3: Class-based annotations
    print("\n3. Data Pipeline with Method Annotations:")
    pipeline = DataPipeline(batch_size=64)
    results = pipeline.process_batches(5)
    print(f"   Processed {len(results)} batches")
    
    # Example 4: Context manager style
    print("\n4. Context Manager Style Annotations:")
    with nvtx.annotate("ContextExample", color="purple"):
        # Nested contexts
        with nvtx.annotate("Phase1", color="red"):
            phase1_data = np.random.randn(1000, 100)
            time.sleep(0.1)
        
        with nvtx.annotate("Phase2", color="green"):
            phase2_result = np.dot(phase1_data, phase1_data.T)
            time.sleep(0.1)
        
        with nvtx.annotate("Phase3", color="blue"):
            final_result = np.linalg.eigvals(phase2_result[:50, :50])
    
    print("   Context manager example completed")
    
    # Example 5: Complex workflow
    complex_workflow()
    
    # Example 6: Algorithm comparison
    benchmark_with_annotations()
    
    print("\n" + "=" * 60)
    print("NVTX annotation examples complete!")
    print("\nProfiler hints:")
    print("- Use 'nsys profile --trace=nvtx' to capture NVTX markers")
    print("- NVTX ranges will appear as colored blocks in the timeline")
    print("- Use different colors and domains to organize your profiling data")
    
    if not NVTX_AVAILABLE:
        print("\nNote: Install nvtx for actual profiling: pip install nvtx")


if __name__ == "__main__":
    main()