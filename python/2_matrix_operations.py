#!/usr/bin/env python3
"""
Matrix Operations Profiling Example
Compares different matrix operation implementations to demonstrate profiling differences.
"""

import time
import numpy as np
import random
from typing import List, Tuple


def naive_matrix_multiply(a: List[List[float]], b: List[List[float]]) -> List[List[float]]:
    """Naive O(n^3) matrix multiplication using pure Python"""
    rows_a, cols_a = len(a), len(a[0])
    rows_b, cols_b = len(b), len(b[0])
    
    if cols_a != rows_b:
        raise ValueError("Incompatible matrix dimensions")
    
    result = [[0.0 for _ in range(cols_b)] for _ in range(rows_a)]
    
    for i in range(rows_a):
        for j in range(cols_b):
            for k in range(cols_a):
                result[i][j] += a[i][k] * b[k][j]
    
    return result


def optimized_matrix_multiply(a: List[List[float]], b: List[List[float]]) -> List[List[float]]:
    """Slightly optimized matrix multiplication with better cache usage"""
    rows_a, cols_a = len(a), len(a[0])
    rows_b, cols_b = len(b), len(b[0])
    
    if cols_a != rows_b:
        raise ValueError("Incompatible matrix dimensions")
    
    # Transpose b for better cache locality
    b_transposed = [[b[j][i] for j in range(rows_b)] for i in range(cols_b)]
    result = [[0.0 for _ in range(cols_b)] for _ in range(rows_a)]
    
    for i in range(rows_a):
        for j in range(cols_b):
            result[i][j] = sum(a[i][k] * b_transposed[j][k] for k in range(cols_a))
    
    return result


def numpy_matrix_operations(size: int) -> Tuple[float, float, float, float]:
    """Various NumPy matrix operations for comparison"""
    # Generate random matrices
    a = np.random.rand(size, size)
    b = np.random.rand(size, size)
    
    # Matrix multiplication
    start = time.time()
    c = np.dot(a, b)
    mult_time = time.time() - start
    
    # Element-wise operations
    start = time.time()
    d = a * b + np.sin(a) - np.cos(b)
    elem_time = time.time() - start
    
    # Matrix decomposition (SVD)
    start = time.time()
    u, s, vh = np.linalg.svd(a[:100, :100])  # Smaller size for SVD
    svd_time = time.time() - start
    
    # Eigenvalue computation
    start = time.time()
    eigenvalues, eigenvectors = np.linalg.eig(a[:100, :100])
    eig_time = time.time() - start
    
    return mult_time, elem_time, svd_time, eig_time


def matrix_convolution(matrix: List[List[float]], kernel: List[List[float]]) -> List[List[float]]:
    """2D convolution operation - common in image processing"""
    m_rows, m_cols = len(matrix), len(matrix[0])
    k_rows, k_cols = len(kernel), len(kernel[0])
    
    # Output dimensions
    out_rows = m_rows - k_rows + 1
    out_cols = m_cols - k_cols + 1
    
    result = [[0.0 for _ in range(out_cols)] for _ in range(out_rows)]
    
    for i in range(out_rows):
        for j in range(out_cols):
            for ki in range(k_rows):
                for kj in range(k_cols):
                    result[i][j] += matrix[i + ki][j + kj] * kernel[ki][kj]
    
    return result


def block_matrix_multiply(a: np.ndarray, b: np.ndarray, block_size: int = 64) -> np.ndarray:
    """Block matrix multiplication for better cache performance"""
    n = a.shape[0]
    c = np.zeros((n, n))
    
    for i in range(0, n, block_size):
        for j in range(0, n, block_size):
            for k in range(0, n, block_size):
                # Multiply blocks
                i_end = min(i + block_size, n)
                j_end = min(j + block_size, n)
                k_end = min(k + block_size, n)
                
                c[i:i_end, j:j_end] += np.dot(a[i:i_end, k:k_end], 
                                               b[k:k_end, j:j_end])
    
    return c


def strassen_multiply(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Strassen's matrix multiplication algorithm (simplified version)"""
    n = a.shape[0]
    
    # Base case
    if n <= 64:  # Use regular multiplication for small matrices
        return np.dot(a, b)
    
    # Ensure even dimensions
    if n % 2 != 0:
        a = np.pad(a, ((0, 1), (0, 1)), mode='constant')
        b = np.pad(b, ((0, 1), (0, 1)), mode='constant')
        n += 1
    
    mid = n // 2
    
    # Divide matrices into quadrants
    a11, a12 = a[:mid, :mid], a[:mid, mid:]
    a21, a22 = a[mid:, :mid], a[mid:, mid:]
    b11, b12 = b[:mid, :mid], b[:mid, mid:]
    b21, b22 = b[mid:, :mid], b[mid:, mid:]
    
    # Strassen's 7 multiplications
    m1 = strassen_multiply(a11 + a22, b11 + b22)
    m2 = strassen_multiply(a21 + a22, b11)
    m3 = strassen_multiply(a11, b12 - b22)
    m4 = strassen_multiply(a22, b21 - b11)
    m5 = strassen_multiply(a11 + a12, b22)
    m6 = strassen_multiply(a21 - a11, b11 + b12)
    m7 = strassen_multiply(a12 - a22, b21 + b22)
    
    # Compute result quadrants
    c11 = m1 + m4 - m5 + m7
    c12 = m3 + m5
    c21 = m2 + m4
    c22 = m1 - m2 + m3 + m6
    
    # Combine quadrants
    c = np.vstack([np.hstack([c11, c12]), np.hstack([c21, c22])])
    
    return c[:a.shape[0], :b.shape[1]]


def main():
    print("Matrix Operations Profiling Examples")
    print("=" * 60)
    
    # Test 1: Compare Python implementations
    print("\n1. Pure Python Matrix Multiplication (100x100):")
    size = 100
    a = [[random.random() for _ in range(size)] for _ in range(size)]
    b = [[random.random() for _ in range(size)] for _ in range(size)]
    
    start = time.time()
    result1 = naive_matrix_multiply(a, b)
    naive_time = time.time() - start
    print(f"   Naive implementation: {naive_time:.3f}s")
    
    start = time.time()
    result2 = optimized_matrix_multiply(a, b)
    opt_time = time.time() - start
    print(f"   Optimized implementation: {opt_time:.3f}s")
    print(f"   Speedup: {naive_time/opt_time:.2f}x")
    
    # Test 2: NumPy operations
    print("\n2. NumPy Matrix Operations (500x500):")
    mult_time, elem_time, svd_time, eig_time = numpy_matrix_operations(500)
    print(f"   Matrix multiplication: {mult_time:.3f}s")
    print(f"   Element-wise operations: {elem_time:.3f}s")
    print(f"   SVD (100x100): {svd_time:.3f}s")
    print(f"   Eigenvalue decomposition (100x100): {eig_time:.3f}s")
    
    # Test 3: Convolution
    print("\n3. 2D Convolution (200x200 with 5x5 kernel):")
    matrix = [[random.random() for _ in range(200)] for _ in range(200)]
    kernel = [[random.random() for _ in range(5)] for _ in range(5)]
    
    start = time.time()
    conv_result = matrix_convolution(matrix, kernel)
    conv_time = time.time() - start
    print(f"   Convolution time: {conv_time:.3f}s")
    
    # Test 4: Advanced multiplication algorithms
    print("\n4. Advanced Multiplication Algorithms (256x256):")
    a_np = np.random.rand(256, 256)
    b_np = np.random.rand(256, 256)
    
    start = time.time()
    np_result = np.dot(a_np, b_np)
    np_time = time.time() - start
    print(f"   NumPy standard multiplication: {np_time:.3f}s")
    
    start = time.time()
    block_result = block_matrix_multiply(a_np, b_np)
    block_time = time.time() - start
    print(f"   Block multiplication: {block_time:.3f}s")
    
    start = time.time()
    strassen_result = strassen_multiply(a_np, b_np)
    strassen_time = time.time() - start
    print(f"   Strassen's algorithm: {strassen_time:.3f}s")
    
    # Test 5: Large matrix operations
    print("\n5. Large Matrix Operations:")
    print("   Creating 2000x2000 matrices...")
    large_a = np.random.rand(2000, 2000)
    large_b = np.random.rand(2000, 2000)
    
    start = time.time()
    large_result = np.dot(large_a, large_b)
    large_time = time.time() - start
    print(f"   2000x2000 multiplication: {large_time:.3f}s")
    
    # Memory bandwidth test
    start = time.time()
    transpose = large_a.T
    copy = large_a.copy()
    mem_time = time.time() - start
    print(f"   Transpose + copy operations: {mem_time:.3f}s")
    
    print("\n" + "=" * 60)
    print("Matrix operations profiling complete!")


if __name__ == "__main__":
    main()