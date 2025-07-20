#!/usr/bin/env python3
"""
Basic CPU Profiling Example
This example demonstrates various CPU-intensive operations for profiling with nsys.
"""

import time
import math
import sys

# Increase the limit for integer string conversion
sys.set_int_max_str_digits(100000)


def fibonacci_recursive(n):
    """Recursive fibonacci - inefficient on purpose for CPU profiling"""
    if n <= 1:
        return n
    return fibonacci_recursive(n-1) + fibonacci_recursive(n-2)


def fibonacci_iterative(n):
    """Iterative fibonacci - more efficient implementation"""
    if n <= 1:
        return n
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b


def prime_sieve(limit):
    """Sieve of Eratosthenes - CPU intensive algorithm"""
    sieve = [True] * (limit + 1)
    sieve[0] = sieve[1] = False
    
    for i in range(2, int(math.sqrt(limit)) + 1):
        if sieve[i]:
            for j in range(i*i, limit + 1, i):
                sieve[j] = False
    
    return [i for i in range(2, limit + 1) if sieve[i]]


def matrix_multiply_naive(size):
    """Naive matrix multiplication - O(n^3) complexity"""
    # Initialize matrices
    a = [[i * j for j in range(size)] for i in range(size)]
    b = [[i + j for j in range(size)] for i in range(size)]
    c = [[0 for _ in range(size)] for _ in range(size)]
    
    # Naive multiplication
    for i in range(size):
        for j in range(size):
            for k in range(size):
                c[i][j] += a[i][k] * b[k][j]
    
    return c


def compute_intensive_loop(iterations):
    """CPU intensive mathematical computations"""
    result = 0.0
    for i in range(1, iterations + 1):
        result += math.sqrt(i) * math.log(i + 1) / math.exp(i / 1000)
    return result


def string_operations(size):
    """String manipulation operations"""
    strings = []
    for i in range(size):
        s = f"String number {i}" * 10
        strings.append(s.upper().lower().replace(" ", "_"))
    
    # Concatenation
    result = ""
    for s in strings[:100]:  # Limit to avoid excessive memory use
        result += s
    
    return len(result)


def main():
    print("Starting CPU-intensive operations for profiling...")
    print("=" * 60)
    
    # Test 1: Fibonacci comparison
    print("\n1. Fibonacci Calculation:")
    start = time.time()
    fib_rec = fibonacci_recursive(35)
    rec_time = time.time() - start
    print(f"   Recursive (n=35): {fib_rec} in {rec_time:.3f}s")
    
    start = time.time()
    fib_iter = fibonacci_iterative(100000)
    iter_time = time.time() - start
    print(f"   Iterative (n=100000): {len(str(fib_iter))} digits in {iter_time:.3f}s")
    
    # Test 2: Prime number generation
    print("\n2. Prime Number Generation:")
    start = time.time()
    primes = prime_sieve(1000000)
    prime_time = time.time() - start
    print(f"   Found {len(primes)} primes up to 1,000,000 in {prime_time:.3f}s")
    
    # Test 3: Matrix multiplication
    print("\n3. Matrix Multiplication:")
    start = time.time()
    result = matrix_multiply_naive(200)
    matrix_time = time.time() - start
    print(f"   200x200 matrix multiplication in {matrix_time:.3f}s")
    
    # Test 4: Mathematical computations
    print("\n4. Mathematical Computations:")
    start = time.time()
    math_result = compute_intensive_loop(100000)
    math_time = time.time() - start
    print(f"   Complex calculations result: {math_result:.6f} in {math_time:.3f}s")
    
    # Test 5: String operations
    print("\n5. String Operations:")
    start = time.time()
    str_result = string_operations(10000)
    str_time = time.time() - start
    print(f"   String operations result length: {str_result} in {str_time:.3f}s")
    
    print("\n" + "=" * 60)
    print(f"Total execution time: {rec_time + iter_time + prime_time + matrix_time + math_time + str_time:.3f}s")


if __name__ == "__main__":
    main()