/*
 * Matrix Operations Profiling Example
 * Compares different matrix operation implementations to demonstrate profiling differences.
 */

#include <iostream>
#include <vector>
#include <chrono>
#include <cmath>
#include <algorithm>
#include <immintrin.h>  // For SIMD instructions
#include <cstring>
#include <iomanip>

using namespace std;
using namespace std::chrono;

class Timer {
private:
    high_resolution_clock::time_point start_time;
    string name;

public:
    Timer(const string& timer_name) : name(timer_name) {
        start_time = high_resolution_clock::now();
    }

    double elapsed() {
        auto end_time = high_resolution_clock::now();
        auto duration = duration_cast<microseconds>(end_time - start_time);
        return duration.count() / 1000000.0;
    }

    ~Timer() {
        cout << "   " << name << ": " << fixed << setprecision(3) 
             << elapsed() << "s" << endl;
    }
};

// Matrix class for easier manipulation
template<typename T>
class Matrix {
private:
    vector<T> data;
    size_t rows, cols;

public:
    Matrix(size_t r, size_t c) : rows(r), cols(c), data(r * c) {}
    
    Matrix(size_t r, size_t c, T init_val) : rows(r), cols(c), data(r * c, init_val) {}
    
    T& operator()(size_t i, size_t j) {
        return data[i * cols + j];
    }
    
    const T& operator()(size_t i, size_t j) const {
        return data[i * cols + j];
    }
    
    T* row(size_t i) {
        return &data[i * cols];
    }
    
    const T* row(size_t i) const {
        return &data[i * cols];
    }
    
    size_t num_rows() const { return rows; }
    size_t num_cols() const { return cols; }
    
    void randomize() {
        for (auto& val : data) {
            val = static_cast<T>(rand()) / RAND_MAX;
        }
    }
};

// Naive matrix multiplication - O(n^3)
template<typename T>
Matrix<T> multiply_naive(const Matrix<T>& a, const Matrix<T>& b) {
    size_t m = a.num_rows();
    size_t n = b.num_cols();
    size_t k = a.num_cols();
    
    Matrix<T> c(m, n, 0);
    
    for (size_t i = 0; i < m; ++i) {
        for (size_t j = 0; j < n; ++j) {
            for (size_t p = 0; p < k; ++p) {
                c(i, j) += a(i, p) * b(p, j);
            }
        }
    }
    
    return c;
}

// Cache-optimized multiplication (loop tiling)
template<typename T>
Matrix<T> multiply_tiled(const Matrix<T>& a, const Matrix<T>& b, size_t tile_size = 64) {
    size_t m = a.num_rows();
    size_t n = b.num_cols();
    size_t k = a.num_cols();
    
    Matrix<T> c(m, n, 0);
    
    for (size_t i0 = 0; i0 < m; i0 += tile_size) {
        for (size_t j0 = 0; j0 < n; j0 += tile_size) {
            for (size_t k0 = 0; k0 < k; k0 += tile_size) {
                // Compute tile
                size_t i_max = min(i0 + tile_size, m);
                size_t j_max = min(j0 + tile_size, n);
                size_t k_max = min(k0 + tile_size, k);
                
                for (size_t i = i0; i < i_max; ++i) {
                    for (size_t j = j0; j < j_max; ++j) {
                        T sum = c(i, j);
                        for (size_t p = k0; p < k_max; ++p) {
                            sum += a(i, p) * b(p, j);
                        }
                        c(i, j) = sum;
                    }
                }
            }
        }
    }
    
    return c;
}

// Transposed B multiplication for better cache usage
template<typename T>
Matrix<T> multiply_transposed(const Matrix<T>& a, const Matrix<T>& b) {
    size_t m = a.num_rows();
    size_t n = b.num_cols();
    size_t k = a.num_cols();
    
    // Transpose B for better cache locality
    Matrix<T> b_transposed(n, k);
    for (size_t i = 0; i < k; ++i) {
        for (size_t j = 0; j < n; ++j) {
            b_transposed(j, i) = b(i, j);
        }
    }
    
    Matrix<T> c(m, n, 0);
    
    for (size_t i = 0; i < m; ++i) {
        for (size_t j = 0; j < n; ++j) {
            T sum = 0;
            for (size_t p = 0; p < k; ++p) {
                sum += a(i, p) * b_transposed(j, p);
            }
            c(i, j) = sum;
        }
    }
    
    return c;
}

// SIMD-optimized multiplication (for float matrices)
Matrix<float> multiply_simd(const Matrix<float>& a, const Matrix<float>& b) {
    size_t m = a.num_rows();
    size_t n = b.num_cols();
    size_t k = a.num_cols();
    
    Matrix<float> c(m, n, 0);
    
    // Ensure alignment
    const size_t simd_width = 8; // AVX can process 8 floats at once
    
    for (size_t i = 0; i < m; ++i) {
        for (size_t j = 0; j < n; ++j) {
            __m256 sum = _mm256_setzero_ps();
            
            size_t p = 0;
            // SIMD loop
            for (; p + simd_width <= k; p += simd_width) {
                __m256 a_vec = _mm256_loadu_ps(&a(i, p));
                __m256 b_vec = _mm256_set_ps(
                    b(p+7, j), b(p+6, j), b(p+5, j), b(p+4, j),
                    b(p+3, j), b(p+2, j), b(p+1, j), b(p+0, j)
                );
                sum = _mm256_fmadd_ps(a_vec, b_vec, sum);
            }
            
            // Sum the SIMD register elements
            float result[8];
            _mm256_storeu_ps(result, sum);
            float final_sum = 0;
            for (int i = 0; i < 8; ++i) {
                final_sum += result[i];
            }
            
            // Handle remaining elements
            for (; p < k; ++p) {
                final_sum += a(i, p) * b(p, j);
            }
            
            c(i, j) = final_sum;
        }
    }
    
    return c;
}

// Strassen's algorithm (recursive, for power-of-2 sizes)
template<typename T>
Matrix<T> multiply_strassen(const Matrix<T>& a, const Matrix<T>& b, size_t min_size = 64) {
    size_t n = a.num_rows();
    
    // Base case: use regular multiplication for small matrices
    if (n <= min_size) {
        return multiply_naive(a, b);
    }
    
    // Ensure power of 2 (simplified version)
    if (n % 2 != 0) {
        return multiply_naive(a, b);
    }
    
    size_t half = n / 2;
    
    // Divide matrices into quadrants
    Matrix<T> a11(half, half), a12(half, half), a21(half, half), a22(half, half);
    Matrix<T> b11(half, half), b12(half, half), b21(half, half), b22(half, half);
    
    for (size_t i = 0; i < half; ++i) {
        for (size_t j = 0; j < half; ++j) {
            a11(i, j) = a(i, j);
            a12(i, j) = a(i, j + half);
            a21(i, j) = a(i + half, j);
            a22(i, j) = a(i + half, j + half);
            
            b11(i, j) = b(i, j);
            b12(i, j) = b(i, j + half);
            b21(i, j) = b(i + half, j);
            b22(i, j) = b(i + half, j + half);
        }
    }
    
    // Compute the 7 products (simplified without explicit temp matrices)
    auto add = [](const Matrix<T>& x, const Matrix<T>& y) {
        size_t n = x.num_rows();
        Matrix<T> result(n, n);
        for (size_t i = 0; i < n; ++i) {
            for (size_t j = 0; j < n; ++j) {
                result(i, j) = x(i, j) + y(i, j);
            }
        }
        return result;
    };
    
    auto subtract = [](const Matrix<T>& x, const Matrix<T>& y) {
        size_t n = x.num_rows();
        Matrix<T> result(n, n);
        for (size_t i = 0; i < n; ++i) {
            for (size_t j = 0; j < n; ++j) {
                result(i, j) = x(i, j) - y(i, j);
            }
        }
        return result;
    };
    
    auto m1 = multiply_strassen(add(a11, a22), add(b11, b22), min_size);
    auto m2 = multiply_strassen(add(a21, a22), b11, min_size);
    auto m3 = multiply_strassen(a11, subtract(b12, b22), min_size);
    auto m4 = multiply_strassen(a22, subtract(b21, b11), min_size);
    auto m5 = multiply_strassen(add(a11, a12), b22, min_size);
    auto m6 = multiply_strassen(subtract(a21, a11), add(b11, b12), min_size);
    auto m7 = multiply_strassen(subtract(a12, a22), add(b21, b22), min_size);
    
    // Compute result quadrants
    auto c11 = add(subtract(add(m1, m4), m5), m7);
    auto c12 = add(m3, m5);
    auto c21 = add(m2, m4);
    auto c22 = add(subtract(add(m1, m3), m2), m6);
    
    // Combine results
    Matrix<T> c(n, n);
    for (size_t i = 0; i < half; ++i) {
        for (size_t j = 0; j < half; ++j) {
            c(i, j) = c11(i, j);
            c(i, j + half) = c12(i, j);
            c(i + half, j) = c21(i, j);
            c(i + half, j + half) = c22(i, j);
        }
    }
    
    return c;
}

// Matrix convolution (2D)
template<typename T>
Matrix<T> convolve_2d(const Matrix<T>& input, const Matrix<T>& kernel) {
    size_t in_rows = input.num_rows();
    size_t in_cols = input.num_cols();
    size_t k_rows = kernel.num_rows();
    size_t k_cols = kernel.num_cols();
    
    size_t out_rows = in_rows - k_rows + 1;
    size_t out_cols = in_cols - k_cols + 1;
    
    Matrix<T> output(out_rows, out_cols, 0);
    
    for (size_t i = 0; i < out_rows; ++i) {
        for (size_t j = 0; j < out_cols; ++j) {
            T sum = 0;
            for (size_t ki = 0; ki < k_rows; ++ki) {
                for (size_t kj = 0; kj < k_cols; ++kj) {
                    sum += input(i + ki, j + kj) * kernel(ki, kj);
                }
            }
            output(i, j) = sum;
        }
    }
    
    return output;
}

// Matrix operations benchmarks
void benchmark_operations() {
    cout << "\n5. Additional Matrix Operations:" << endl;
    
    const size_t size = 500;
    Matrix<double> a(size, size);
    Matrix<double> b(size, size);
    a.randomize();
    b.randomize();
    
    // Transpose
    {
        Timer timer("   Matrix transpose");
        Matrix<double> transposed(size, size);
        for (size_t i = 0; i < size; ++i) {
            for (size_t j = 0; j < size; ++j) {
                transposed(j, i) = a(i, j);
            }
        }
    }
    
    // Element-wise operations
    {
        Timer timer("   Element-wise operations");
        Matrix<double> result(size, size);
        for (size_t i = 0; i < size; ++i) {
            for (size_t j = 0; j < size; ++j) {
                result(i, j) = sin(a(i, j)) * cos(b(i, j)) + 
                              sqrt(abs(a(i, j) - b(i, j)));
            }
        }
    }
    
    // Matrix trace
    {
        Timer timer("   Matrix trace calculation");
        double trace = 0;
        for (size_t i = 0; i < size; ++i) {
            trace += a(i, i);
        }
        cout << "     Trace: " << trace << endl;
    }
    
    // Frobenius norm
    {
        Timer timer("   Frobenius norm");
        double norm = 0;
        for (size_t i = 0; i < size; ++i) {
            for (size_t j = 0; j < size; ++j) {
                norm += a(i, j) * a(i, j);
            }
        }
        norm = sqrt(norm);
        cout << "     Norm: " << norm << endl;
    }
}

int main() {
    cout << "Matrix Operations Profiling Examples" << endl;
    cout << "============================================================" << endl;
    
    // Test different matrix sizes
    vector<size_t> sizes = {100, 256, 512};
    
    for (size_t size : sizes) {
        cout << "\nMatrix size: " << size << "x" << size << endl;
        cout << "------------------------------------------------------------" << endl;
        
        Matrix<double> a(size, size);
        Matrix<double> b(size, size);
        a.randomize();
        b.randomize();
        
        // 1. Naive multiplication
        {
            Timer timer("1. Naive multiplication");
            auto c = multiply_naive(a, b);
        }
        
        // 2. Cache-optimized (tiled)
        {
            Timer timer("2. Tiled multiplication (64x64 tiles)");
            auto c = multiply_tiled(a, b, 64);
        }
        
        // 3. Transposed multiplication
        {
            Timer timer("3. Transposed B multiplication");
            auto c = multiply_transposed(a, b);
        }
        
        // 4. Strassen's algorithm (for power-of-2 sizes)
        if (size == 256 || size == 512) {
            Timer timer("4. Strassen's algorithm");
            auto c = multiply_strassen(a, b);
        }
    }
    
    // SIMD demonstration with float matrices
    cout << "\n\nSIMD Optimization (float, 512x512):" << endl;
    cout << "------------------------------------------------------------" << endl;
    
    Matrix<float> af(512, 512);
    Matrix<float> bf(512, 512);
    af.randomize();
    bf.randomize();
    
    {
        Timer timer("Regular float multiplication");
        auto cf = multiply_naive(af, bf);
    }
    
    {
        Timer timer("SIMD-optimized multiplication");
        auto cf = multiply_simd(af, bf);
    }
    
    // Convolution example
    cout << "\n\nConvolution Operations:" << endl;
    cout << "------------------------------------------------------------" << endl;
    
    Matrix<double> image(500, 500);
    image.randomize();
    
    // Different kernel sizes
    vector<size_t> kernel_sizes = {3, 5, 7};
    for (size_t ks : kernel_sizes) {
        Matrix<double> kernel(ks, ks);
        kernel.randomize();
        
        Timer timer("Convolution with " + to_string(ks) + "x" + 
                   to_string(ks) + " kernel");
        auto result = convolve_2d(image, kernel);
    }
    
    // Additional operations benchmark
    benchmark_operations();
    
    cout << "\n============================================================" << endl;
    cout << "Matrix operations profiling complete!" << endl;
    cout << "\nProfiler hints:" << endl;
    cout << "- Look for cache miss patterns in naive multiplication" << endl;
    cout << "- Compare CPU utilization between different algorithms" << endl;
    cout << "- Check SIMD instruction usage in optimized versions" << endl;
    
    return 0;
}