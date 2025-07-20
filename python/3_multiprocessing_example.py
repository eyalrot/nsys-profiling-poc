#!/usr/bin/env python3
"""
Multiprocessing Profiling Example
Demonstrates various multiprocessing patterns for CPU profiling with nsys.
"""

import time
import multiprocessing as mp
from multiprocessing import Pool, Process, Queue, Manager, Lock
import concurrent.futures
import numpy as np
from typing import List, Tuple, Any
import os


def cpu_bound_task(n: int) -> int:
    """CPU-intensive task: calculate sum of squares"""
    total = 0
    for i in range(n):
        total += i * i
    return total


def cpu_bound_task_scaled(x: int) -> int:
    """Wrapper for cpu_bound_task with scaling"""
    return cpu_bound_task(x * 1000)


def worker_with_shared_memory(arr: mp.Array, start: int, end: int, lock: Lock) -> None:
    """Worker that modifies shared memory array"""
    local_sum = 0
    for i in range(start, end):
        local_sum += i * i
    
    # Update shared memory with lock
    with lock:
        arr[0] += local_sum


def producer(queue: Queue, num_items: int) -> None:
    """Producer process that generates work items"""
    for i in range(num_items):
        # Simulate some computation
        item = cpu_bound_task(1000)
        queue.put((i, item))
    queue.put(None)  # Sentinel value


def consumer(queue: Queue, result_queue: Queue) -> None:
    """Consumer process that processes work items"""
    total = 0
    count = 0
    
    while True:
        item = queue.get()
        if item is None:
            break
        
        idx, value = item
        # Simulate processing
        processed = value * 2 + cpu_bound_task(500)
        total += processed
        count += 1
    
    result_queue.put((os.getpid(), count, total))


def process_batch(batch_id: int, size: int) -> Tuple[int, float]:
    """Process a batch of data for concurrent futures example"""
    start = time.time()
    result = 0
    for i in range(size):
        result += cpu_bound_task(100)
    return batch_id, time.time() - start


def multiply_row_range(a_rows, b, start_row, end_row):
    """Multiply a range of rows for parallel matrix multiplication"""
    return np.dot(a_rows[start_row:end_row], b)


def worker_task(x):
    """Worker task for pool comparison - simulate CPU-intensive work"""
    result = 0
    for i in range(x, x + 10000):
        result += i * i
    return result


def parallel_map_example():
    """Example using multiprocessing.Pool.map"""
    print("\n1. Parallel Map Example:")
    
    # Data to process
    data = list(range(100))
    
    # Sequential processing
    start = time.time()
    sequential_results = [cpu_bound_task(x * 1000) for x in data]
    seq_time = time.time() - start
    print(f"   Sequential processing: {seq_time:.3f}s")
    
    # Parallel processing with Pool
    start = time.time()
    with Pool(processes=mp.cpu_count()) as pool:
        parallel_results = pool.map(cpu_bound_task_scaled, data)
    par_time = time.time() - start
    print(f"   Parallel processing ({mp.cpu_count()} cores): {par_time:.3f}s")
    print(f"   Speedup: {seq_time/par_time:.2f}x")


def shared_memory_example():
    """Example using shared memory between processes"""
    print("\n2. Shared Memory Example:")
    
    # Create shared memory array
    shared_array = mp.Array('d', [0.0])  # Double array with one element
    lock = mp.Lock()
    
    # Calculate sum of squares from 0 to 10,000,000
    n = 10_000_000
    num_processes = mp.cpu_count()
    chunk_size = n // num_processes
    
    start = time.time()
    processes = []
    
    for i in range(num_processes):
        start_idx = i * chunk_size
        end_idx = start_idx + chunk_size if i < num_processes - 1 else n
        
        p = Process(target=worker_with_shared_memory, 
                   args=(shared_array, start_idx, end_idx, lock))
        p.start()
        processes.append(p)
    
    # Wait for all processes
    for p in processes:
        p.join()
    
    par_time = time.time() - start
    print(f"   Parallel sum calculation: {par_time:.3f}s")
    print(f"   Result: {shared_array[0]:.0f}")
    
    # Compare with sequential
    start = time.time()
    sequential_sum = sum(i * i for i in range(n))
    seq_time = time.time() - start
    print(f"   Sequential calculation: {seq_time:.3f}s")
    print(f"   Speedup: {seq_time/par_time:.2f}x")


def producer_consumer_example():
    """Example using producer-consumer pattern"""
    print("\n3. Producer-Consumer Pattern:")
    
    work_queue = mp.Queue(maxsize=100)
    result_queue = mp.Queue()
    
    num_items = 1000
    num_consumers = 4
    
    start = time.time()
    
    # Start producer
    producer_proc = Process(target=producer, args=(work_queue, num_items))
    producer_proc.start()
    
    # Start consumers
    consumers = []
    for _ in range(num_consumers):
        c = Process(target=consumer, args=(work_queue, result_queue))
        c.start()
        consumers.append(c)
    
    # Send sentinel values for remaining consumers
    for _ in range(num_consumers - 1):
        work_queue.put(None)
    
    # Wait for producer
    producer_proc.join()
    
    # Wait for consumers
    for c in consumers:
        c.join()
    
    # Collect results
    total_items = 0
    total_value = 0
    for _ in range(num_consumers):
        pid, count, value = result_queue.get()
        print(f"   Consumer PID {pid}: processed {count} items")
        total_items += count
        total_value += value
    
    elapsed = time.time() - start
    print(f"   Total items processed: {total_items}")
    print(f"   Total time: {elapsed:.3f}s")


def concurrent_futures_example():
    """Example using concurrent.futures for high-level parallelism"""
    print("\n4. Concurrent Futures Example:")
    
    num_batches = 50
    batch_size = 1000
    
    # Using ThreadPoolExecutor (GIL limited for CPU tasks)
    start = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        thread_futures = [executor.submit(process_batch, i, batch_size) 
                         for i in range(num_batches)]
        thread_results = [f.result() for f in thread_futures]
    thread_time = time.time() - start
    print(f"   ThreadPoolExecutor time: {thread_time:.3f}s")
    
    # Using ProcessPoolExecutor
    start = time.time()
    with concurrent.futures.ProcessPoolExecutor(max_workers=mp.cpu_count()) as executor:
        process_futures = [executor.submit(process_batch, i, batch_size) 
                          for i in range(num_batches)]
        process_results = [f.result() for f in process_futures]
    process_time = time.time() - start
    print(f"   ProcessPoolExecutor time: {process_time:.3f}s")
    print(f"   Process vs Thread speedup: {thread_time/process_time:.2f}x")


def numpy_parallel_example():
    """Example showing NumPy's internal parallelism"""
    print("\n5. NumPy Parallel Operations:")
    
    size = 5000
    a = np.random.rand(size, size)
    b = np.random.rand(size, size)
    
    # Matrix multiplication (uses BLAS with multiple threads)
    start = time.time()
    c = np.dot(a, b)
    numpy_time = time.time() - start
    print(f"   NumPy matrix multiplication ({size}x{size}): {numpy_time:.3f}s")
    
    # Manual parallel multiplication using multiprocessing
    start = time.time()
    num_processes = mp.cpu_count()
    chunk_size = size // num_processes
    
    with Pool(processes=num_processes) as pool:
        tasks = []
        for i in range(num_processes):
            start_row = i * chunk_size
            end_row = start_row + chunk_size if i < num_processes - 1 else size
            tasks.append(pool.apply_async(multiply_row_range, 
                                        (a, b, start_row, end_row)))
        
        results = [task.get() for task in tasks]
        c_manual = np.vstack(results)
    
    manual_time = time.time() - start
    print(f"   Manual parallel multiplication: {manual_time:.3f}s")
    print(f"   NumPy internal parallelism advantage: {manual_time/numpy_time:.2f}x")


def pool_comparison():
    """Compare different pool implementations"""
    print("\n6. Pool Implementation Comparison:")
    
    work_items = list(range(1000))
    
    # Standard Pool with different methods
    with Pool(processes=mp.cpu_count()) as pool:
        # map
        start = time.time()
        map_results = pool.map(worker_task, work_items)
        map_time = time.time() - start
        print(f"   pool.map: {map_time:.3f}s")
        
        # imap
        start = time.time()
        imap_results = list(pool.imap(worker_task, work_items, chunksize=10))
        imap_time = time.time() - start
        print(f"   pool.imap: {imap_time:.3f}s")
        
        # map_async
        start = time.time()
        async_result = pool.map_async(worker_task, work_items)
        async_results = async_result.get()
        async_time = time.time() - start
        print(f"   pool.map_async: {async_time:.3f}s")


def main():
    print("Multiprocessing Profiling Examples")
    print(f"System has {mp.cpu_count()} CPU cores")
    print("=" * 60)
    
    # Run examples
    parallel_map_example()
    shared_memory_example()
    producer_consumer_example()
    concurrent_futures_example()
    numpy_parallel_example()
    pool_comparison()
    
    print("\n" + "=" * 60)
    print("Multiprocessing examples complete!")
    print("\nProfiler hints:")
    print("- Use 'nsys profile --trace=osrt --sample=cpu' to see process/thread creation")
    print("- Look for CPU utilization patterns across cores")
    print("- Compare synchronization overhead in different approaches")


if __name__ == "__main__":
    # Ensure proper multiprocessing on different platforms
    mp.set_start_method('spawn', force=True)
    main()