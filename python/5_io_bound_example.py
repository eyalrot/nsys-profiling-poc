#!/usr/bin/env python3
"""
I/O Bound Operations Profiling Example
Demonstrates various I/O patterns and their impact on CPU profiling with nsys.
"""

import time
import os
import tempfile
import shutil
import json
import csv
import sqlite3
import threading
import queue
import asyncio
import aiofiles
from pathlib import Path
from typing import List, Dict, Any
import numpy as np


class IOProfiler:
    """Helper class to measure I/O operations"""
    
    def __init__(self):
        self.temp_dir = tempfile.mkdtemp(prefix="nsys_io_test_")
        self.results = {}
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        shutil.rmtree(self.temp_dir)
    
    def measure(self, name: str, func, *args, **kwargs):
        """Measure execution time of a function"""
        start = time.time()
        result = func(*args, **kwargs)
        elapsed = time.time() - start
        self.results[name] = elapsed
        print(f"   {name}: {elapsed:.3f}s")
        return result


def file_io_patterns(profiler: IOProfiler):
    """Test different file I/O patterns"""
    print("\n1. File I/O Patterns:")
    
    # Test data
    data = "x" * 1024  # 1KB of data
    large_data = "x" * (1024 * 1024)  # 1MB of data
    
    # Sequential writes
    def sequential_writes():
        file_path = Path(profiler.temp_dir) / "sequential.txt"
        with open(file_path, 'w') as f:
            for i in range(10000):
                f.write(f"Line {i}: {data}\n")
    
    profiler.measure("Sequential writes (10k lines)", sequential_writes)
    
    # Buffered writes
    def buffered_writes():
        file_path = Path(profiler.temp_dir) / "buffered.txt"
        buffer = []
        for i in range(10000):
            buffer.append(f"Line {i}: {data}\n")
            if len(buffer) >= 100:
                with open(file_path, 'a') as f:
                    f.writelines(buffer)
                buffer = []
    
    profiler.measure("Buffered writes (100 line chunks)", buffered_writes)
    
    # Binary file operations
    def binary_io():
        file_path = Path(profiler.temp_dir) / "binary.dat"
        # Write
        data_array = np.random.rand(1000, 1000).astype(np.float32)
        with open(file_path, 'wb') as f:
            data_array.tofile(f)
        # Read
        with open(file_path, 'rb') as f:
            loaded = np.fromfile(f, dtype=np.float32).reshape(1000, 1000)
        return loaded.shape
    
    profiler.measure("Binary I/O (1000x1000 float32)", binary_io)
    
    # Many small files
    def many_small_files():
        base_path = Path(profiler.temp_dir) / "many_files"
        base_path.mkdir(exist_ok=True)
        for i in range(1000):
            file_path = base_path / f"file_{i}.txt"
            with open(file_path, 'w') as f:
                f.write(f"Content of file {i}\n")
    
    profiler.measure("Create 1000 small files", many_small_files)
    
    # Memory-mapped file
    def memory_mapped_io():
        import mmap
        file_path = Path(profiler.temp_dir) / "mmap.dat"
        
        # Create file
        size = 100 * 1024 * 1024  # 100MB
        with open(file_path, 'wb') as f:
            f.write(b'\x00' * size)
        
        # Memory map and modify
        with open(file_path, 'r+b') as f:
            with mmap.mmap(f.fileno(), 0) as mmapped:
                # Write pattern
                for i in range(0, size, 4096):
                    mmapped[i:i+4] = b'TEST'
                # Read pattern
                data = mmapped[::4096]
    
    profiler.measure("Memory-mapped I/O (100MB)", memory_mapped_io)


def structured_data_io(profiler: IOProfiler):
    """Test structured data formats I/O"""
    print("\n2. Structured Data I/O:")
    
    # Generate test data
    records = []
    for i in range(10000):
        records.append({
            'id': i,
            'name': f'Record_{i}',
            'value': np.random.rand(),
            'data': [np.random.rand() for _ in range(10)],
            'metadata': {
                'created': time.time(),
                'tags': [f'tag_{j}' for j in range(5)]
            }
        })
    
    # JSON I/O
    def json_io():
        file_path = Path(profiler.temp_dir) / "data.json"
        # Write
        with open(file_path, 'w') as f:
            json.dump(records, f)
        # Read
        with open(file_path, 'r') as f:
            loaded = json.load(f)
        return len(loaded)
    
    profiler.measure("JSON I/O (10k records)", json_io)
    
    # CSV I/O
    def csv_io():
        file_path = Path(profiler.temp_dir) / "data.csv"
        # Write
        with open(file_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['id', 'name', 'value'])
            writer.writeheader()
            for record in records:
                writer.writerow({
                    'id': record['id'],
                    'name': record['name'],
                    'value': record['value']
                })
        # Read
        with open(file_path, 'r') as f:
            reader = csv.DictReader(f)
            loaded = list(reader)
        return len(loaded)
    
    profiler.measure("CSV I/O (10k records)", csv_io)
    
    # SQLite I/O
    def sqlite_io():
        db_path = Path(profiler.temp_dir) / "data.db"
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Create table
        cursor.execute('''
            CREATE TABLE records (
                id INTEGER PRIMARY KEY,
                name TEXT,
                value REAL,
                data BLOB
            )
        ''')
        
        # Insert data
        for record in records:
            cursor.execute(
                "INSERT INTO records (id, name, value, data) VALUES (?, ?, ?, ?)",
                (record['id'], record['name'], record['value'], 
                 json.dumps(record['data']))
            )
        conn.commit()
        
        # Query data
        cursor.execute("SELECT COUNT(*) FROM records WHERE value > 0.5")
        count = cursor.fetchone()[0]
        
        conn.close()
        return count
    
    profiler.measure("SQLite I/O (10k records)", sqlite_io)


def concurrent_io_patterns(profiler: IOProfiler):
    """Test concurrent I/O patterns"""
    print("\n3. Concurrent I/O Patterns:")
    
    # Thread-based concurrent I/O
    def threaded_io():
        results_queue = queue.Queue()
        
        def worker(worker_id, num_files):
            for i in range(num_files):
                file_path = Path(profiler.temp_dir) / f"thread_{worker_id}_file_{i}.txt"
                with open(file_path, 'w') as f:
                    f.write(f"Worker {worker_id} file {i}\n" * 100)
                results_queue.put((worker_id, i))
        
        threads = []
        num_threads = 4
        files_per_thread = 250
        
        for i in range(num_threads):
            t = threading.Thread(target=worker, args=(i, files_per_thread))
            t.start()
            threads.append(t)
        
        for t in threads:
            t.join()
        
        total = results_queue.qsize()
        return total
    
    profiler.measure("Threaded I/O (4 threads, 1000 files)", threaded_io)
    
    # Producer-consumer pattern
    def producer_consumer_io():
        work_queue = queue.Queue(maxsize=100)
        done_event = threading.Event()
        
        def producer():
            for i in range(1000):
                data = f"Data packet {i}: " + "x" * 1024
                work_queue.put((i, data))
            work_queue.put(None)  # Sentinel
        
        def consumer(consumer_id):
            while True:
                item = work_queue.get()
                if item is None:
                    work_queue.put(None)  # For other consumers
                    break
                
                idx, data = item
                file_path = Path(profiler.temp_dir) / f"consumer_{consumer_id}_data_{idx}.txt"
                with open(file_path, 'w') as f:
                    f.write(data)
        
        # Start threads
        producer_thread = threading.Thread(target=producer)
        consumer_threads = [
            threading.Thread(target=consumer, args=(i,))
            for i in range(3)
        ]
        
        producer_thread.start()
        for t in consumer_threads:
            t.start()
        
        producer_thread.join()
        for t in consumer_threads:
            t.join()
    
    profiler.measure("Producer-consumer I/O", producer_consumer_io)


async def async_io_patterns(profiler: IOProfiler):
    """Test async I/O patterns"""
    print("\n4. Async I/O Patterns:")
    
    # Async file operations
    async def async_file_io():
        tasks = []
        
        async def write_file_async(file_id):
            file_path = Path(profiler.temp_dir) / f"async_file_{file_id}.txt"
            async with aiofiles.open(file_path, 'w') as f:
                for i in range(100):
                    await f.write(f"Async line {i} in file {file_id}\n")
        
        # Create many concurrent file operations
        for i in range(100):
            tasks.append(write_file_async(i))
        
        await asyncio.gather(*tasks)
        return len(tasks)
    
    # Run async function
    start = time.time()
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        result = loop.run_until_complete(async_file_io())
        elapsed = time.time() - start
        profiler.results["Async I/O (100 concurrent files)"] = elapsed
        print(f"   Async I/O (100 concurrent files): {elapsed:.3f}s")
    finally:
        loop.close()
    
    # Async with rate limiting
    async def rate_limited_io():
        semaphore = asyncio.Semaphore(10)  # Limit to 10 concurrent operations
        
        async def write_with_limit(file_id):
            async with semaphore:
                file_path = Path(profiler.temp_dir) / f"rate_limited_{file_id}.txt"
                async with aiofiles.open(file_path, 'w') as f:
                    await f.write(f"Rate limited file {file_id}\n" * 1000)
        
        tasks = [write_with_limit(i) for i in range(200)]
        await asyncio.gather(*tasks)
        return len(tasks)
    
    # Run rate-limited async
    start = time.time()
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        result = loop.run_until_complete(rate_limited_io())
        elapsed = time.time() - start
        profiler.results["Rate-limited async I/O"] = elapsed
        print(f"   Rate-limited async I/O: {elapsed:.3f}s")
    finally:
        loop.close()


def io_optimization_comparison(profiler: IOProfiler):
    """Compare optimized vs unoptimized I/O"""
    print("\n5. I/O Optimization Comparison:")
    
    test_size = 10 * 1024 * 1024  # 10MB
    
    # Unoptimized: byte-by-byte
    def unoptimized_copy():
        src_path = Path(profiler.temp_dir) / "source.dat"
        dst_path = Path(profiler.temp_dir) / "dest_unopt.dat"
        
        # Create source
        with open(src_path, 'wb') as f:
            f.write(b'x' * test_size)
        
        # Copy byte by byte (intentionally slow)
        with open(src_path, 'rb') as src:
            with open(dst_path, 'wb') as dst:
                while True:
                    byte = src.read(1)
                    if not byte:
                        break
                    dst.write(byte)
    
    # Don't run full unoptimized version as it's too slow
    # profiler.measure("Unoptimized copy (byte-by-byte)", unoptimized_copy)
    print("   Unoptimized copy: skipped (too slow)")
    
    # Optimized: buffered copy
    def optimized_copy():
        src_path = Path(profiler.temp_dir) / "source.dat"
        dst_path = Path(profiler.temp_dir) / "dest_opt.dat"
        
        buffer_size = 1024 * 1024  # 1MB buffer
        with open(src_path, 'rb') as src:
            with open(dst_path, 'wb') as dst:
                while True:
                    chunk = src.read(buffer_size)
                    if not chunk:
                        break
                    dst.write(chunk)
    
    profiler.measure("Optimized copy (1MB buffer)", optimized_copy)
    
    # Using shutil (system optimized)
    def system_copy():
        src_path = Path(profiler.temp_dir) / "source.dat"
        dst_path = Path(profiler.temp_dir) / "dest_system.dat"
        shutil.copy2(src_path, dst_path)
    
    profiler.measure("System copy (shutil)", system_copy)


def simulate_network_io(profiler: IOProfiler):
    """Simulate network-like I/O patterns"""
    print("\n6. Network I/O Simulation:")
    
    # Simulate request-response pattern
    def request_response_pattern():
        latencies = []
        
        for i in range(1000):
            # Simulate network latency
            time.sleep(0.001)  # 1ms latency
            
            # Simulate data transfer
            request_size = np.random.randint(100, 1000)
            response_size = np.random.randint(1000, 10000)
            
            start = time.time()
            # Simulate processing
            request_data = b'x' * request_size
            response_data = b'y' * response_size
            latencies.append(time.time() - start)
        
        return np.mean(latencies)
    
    profiler.measure("Request-response pattern (1000 requests)", request_response_pattern)
    
    # Streaming pattern
    def streaming_pattern():
        chunk_size = 4096
        total_size = 10 * 1024 * 1024  # 10MB
        chunks_sent = 0
        
        file_path = Path(profiler.temp_dir) / "stream.dat"
        
        # Simulate streaming write
        with open(file_path, 'wb') as f:
            while chunks_sent * chunk_size < total_size:
                chunk = b'x' * chunk_size
                f.write(chunk)
                chunks_sent += 1
                # Simulate network delay
                time.sleep(0.0001)
        
        return chunks_sent
    
    profiler.measure("Streaming pattern (10MB)", streaming_pattern)


def main():
    print("I/O Bound Operations Profiling Examples")
    print("=" * 60)
    
    with IOProfiler() as profiler:
        # Run all I/O pattern tests
        file_io_patterns(profiler)
        structured_data_io(profiler)
        concurrent_io_patterns(profiler)
        
        # Run async I/O tests
        try:
            import aiofiles
            asyncio.run(async_io_patterns(profiler))
        except ImportError:
            print("\n4. Async I/O Patterns:")
            print("   Skipped: Install aiofiles with 'pip install aiofiles'")
        
        io_optimization_comparison(profiler)
        simulate_network_io(profiler)
        
        # Summary
        print("\n" + "=" * 60)
        print("I/O Performance Summary:")
        for name, time_taken in sorted(profiler.results.items(), 
                                     key=lambda x: x[1], reverse=True):
            print(f"   {name}: {time_taken:.3f}s")
    
    print("\n" + "=" * 60)
    print("I/O profiling examples complete!")
    print("\nProfiler hints:")
    print("- Use 'nsys profile --trace=osrt' to see OS runtime calls")
    print("- Look for syscall patterns and I/O wait times")
    print("- Compare CPU utilization during I/O operations")
    print("- Check for inefficient I/O patterns (many small operations)")


if __name__ == "__main__":
    main()