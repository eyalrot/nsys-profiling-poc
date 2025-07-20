/*
 * Basic CPU Profiling Example
 * This example demonstrates various CPU-intensive operations for profiling with nsys.
 */

#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#include <chrono>
#include <cmath>
#include <string>
#include <unordered_map>
#include <random>
#include <functional>

using namespace std;
using namespace std::chrono;

// Timer utility class
class Timer {
private:
    high_resolution_clock::time_point start_time;
    string name;

public:
    Timer(const string& timer_name) : name(timer_name) {
        start_time = high_resolution_clock::now();
    }

    ~Timer() {
        auto end_time = high_resolution_clock::now();
        auto duration = duration_cast<milliseconds>(end_time - start_time);
        cout << "   " << name << ": " << duration.count() / 1000.0 << "s" << endl;
    }
};

// Recursive Fibonacci - intentionally inefficient
long long fibonacci_recursive(int n) {
    if (n <= 1) return n;
    return fibonacci_recursive(n - 1) + fibonacci_recursive(n - 2);
}

// Iterative Fibonacci - more efficient
long long fibonacci_iterative(int n) {
    if (n <= 1) return n;
    
    long long a = 0, b = 1;
    for (int i = 2; i <= n; ++i) {
        long long temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// Sieve of Eratosthenes for prime generation
vector<int> sieve_of_eratosthenes(int limit) {
    vector<bool> is_prime(limit + 1, true);
    is_prime[0] = is_prime[1] = false;
    
    for (int i = 2; i * i <= limit; ++i) {
        if (is_prime[i]) {
            for (int j = i * i; j <= limit; j += i) {
                is_prime[j] = false;
            }
        }
    }
    
    vector<int> primes;
    for (int i = 2; i <= limit; ++i) {
        if (is_prime[i]) {
            primes.push_back(i);
        }
    }
    return primes;
}

// Naive matrix multiplication
vector<vector<double>> matrix_multiply_naive(
    const vector<vector<double>>& a,
    const vector<vector<double>>& b) {
    
    int n = a.size();
    int m = b[0].size();
    int k = b.size();
    
    vector<vector<double>> c(n, vector<double>(m, 0.0));
    
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < m; ++j) {
            for (int p = 0; p < k; ++p) {
                c[i][j] += a[i][p] * b[p][j];
            }
        }
    }
    
    return c;
}

// CPU intensive mathematical computations
double compute_intensive_loop(int iterations) {
    double result = 0.0;
    for (int i = 1; i <= iterations; ++i) {
        result += sqrt(static_cast<double>(i)) * 
                  log(i + 1.0) / 
                  exp(i / 1000.0);
    }
    return result;
}

// String operations
int string_operations(int size) {
    vector<string> strings;
    strings.reserve(size);
    
    // Generate strings
    for (int i = 0; i < size; ++i) {
        string s = "String number " + to_string(i);
        // Repeat string 10 times
        string repeated;
        for (int j = 0; j < 10; ++j) {
            repeated += s;
        }
        
        // Transform operations
        transform(repeated.begin(), repeated.end(), repeated.begin(), ::toupper);
        transform(repeated.begin(), repeated.end(), repeated.begin(), ::tolower);
        
        // Replace spaces with underscores
        replace(repeated.begin(), repeated.end(), ' ', '_');
        
        strings.push_back(repeated);
    }
    
    // Concatenation
    string result;
    int limit = min(100, size);
    for (int i = 0; i < limit; ++i) {
        result += strings[i];
    }
    
    return result.length();
}

// Sorting algorithms comparison
void sorting_comparison(int size) {
    cout << "\n7. Sorting Algorithm Comparison:" << endl;
    
    // Generate random data
    random_device rd;
    mt19937 gen(rd());
    uniform_int_distribution<> dis(1, 1000000);
    
    vector<int> original(size);
    for (int i = 0; i < size; ++i) {
        original[i] = dis(gen);
    }
    
    // Bubble sort (small dataset)
    if (size <= 10000) {
        vector<int> data = original;
        Timer timer("   Bubble sort");
        
        for (int i = 0; i < size - 1; ++i) {
            for (int j = 0; j < size - i - 1; ++j) {
                if (data[j] > data[j + 1]) {
                    swap(data[j], data[j + 1]);
                }
            }
        }
    }
    
    // Quick sort
    {
        vector<int> data = original;
        Timer timer("   Quick sort");
        
        function<void(int, int)> quicksort = [&](int low, int high) {
            if (low < high) {
                // Partition
                int pivot = data[high];
                int i = low - 1;
                
                for (int j = low; j < high; ++j) {
                    if (data[j] < pivot) {
                        i++;
                        swap(data[i], data[j]);
                    }
                }
                swap(data[i + 1], data[high]);
                
                int pi = i + 1;
                quicksort(low, pi - 1);
                quicksort(pi + 1, high);
            }
        };
        
        quicksort(0, size - 1);
    }
    
    // STL sort
    {
        vector<int> data = original;
        Timer timer("   STL sort");
        sort(data.begin(), data.end());
    }
    
    // Heap sort
    {
        vector<int> data = original;
        Timer timer("   Heap sort");
        make_heap(data.begin(), data.end());
        sort_heap(data.begin(), data.end());
    }
}

// Hash table operations
void hash_table_operations() {
    cout << "\n8. Hash Table Operations:" << endl;
    
    unordered_map<int, string> hash_map;
    const int num_elements = 1000000;
    
    // Insertion
    {
        Timer timer("   Insertion (1M elements)");
        for (int i = 0; i < num_elements; ++i) {
            hash_map[i] = "Value_" + to_string(i);
        }
    }
    
    // Lookup
    {
        Timer timer("   Lookup (1M queries)");
        int found = 0;
        for (int i = 0; i < num_elements; ++i) {
            if (hash_map.find(i) != hash_map.end()) {
                found++;
            }
        }
        cout << "     Found: " << found << " elements" << endl;
    }
    
    // Deletion
    {
        Timer timer("   Deletion (500k elements)");
        for (int i = 0; i < num_elements / 2; ++i) {
            hash_map.erase(i);
        }
    }
}

int main() {
    cout << "Starting CPU-intensive operations for profiling..." << endl;
    cout << "============================================================" << endl;
    
    // Test 1: Fibonacci comparison
    cout << "\n1. Fibonacci Calculation:" << endl;
    {
        Timer timer("Recursive (n=40)");
        long long fib_rec = fibonacci_recursive(40);
        cout << "     Result: " << fib_rec << endl;
    }
    
    {
        Timer timer("Iterative (n=90)");
        long long fib_iter = fibonacci_iterative(90);
        cout << "     Result: " << fib_iter << endl;
    }
    
    // Test 2: Prime number generation
    cout << "\n2. Prime Number Generation:" << endl;
    {
        Timer timer("Sieve of Eratosthenes (up to 10M)");
        vector<int> primes = sieve_of_eratosthenes(10000000);
        cout << "     Found " << primes.size() << " primes" << endl;
    }
    
    // Test 3: Matrix multiplication
    cout << "\n3. Matrix Multiplication:" << endl;
    {
        int size = 500;
        vector<vector<double>> a(size, vector<double>(size));
        vector<vector<double>> b(size, vector<double>(size));
        
        // Initialize matrices
        for (int i = 0; i < size; ++i) {
            for (int j = 0; j < size; ++j) {
                a[i][j] = i * j;
                b[i][j] = i + j;
            }
        }
        
        Timer timer("500x500 matrix multiplication");
        auto result = matrix_multiply_naive(a, b);
        cout << "     Result[0][0]: " << result[0][0] << endl;
    }
    
    // Test 4: Mathematical computations
    cout << "\n4. Mathematical Computations:" << endl;
    {
        Timer timer("Complex calculations (100k iterations)");
        double result = compute_intensive_loop(100000);
        cout << "     Result: " << result << endl;
    }
    
    // Test 5: String operations
    cout << "\n5. String Operations:" << endl;
    {
        Timer timer("String manipulation (10k strings)");
        int result_length = string_operations(10000);
        cout << "     Result length: " << result_length << endl;
    }
    
    // Test 6: Dynamic programming example
    cout << "\n6. Dynamic Programming (Longest Common Subsequence):" << endl;
    {
        string s1 = string(1000, 'A');
        string s2 = string(1000, 'B');
        // Insert some common characters
        for (int i = 0; i < 100; ++i) {
            s1[i * 10] = 'X';
            s2[i * 10] = 'X';
        }
        
        Timer timer("LCS of 1000-char strings");
        
        int m = s1.length();
        int n = s2.length();
        vector<vector<int>> dp(m + 1, vector<int>(n + 1, 0));
        
        for (int i = 1; i <= m; ++i) {
            for (int j = 1; j <= n; ++j) {
                if (s1[i-1] == s2[j-1]) {
                    dp[i][j] = dp[i-1][j-1] + 1;
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1]);
                }
            }
        }
        
        cout << "     LCS length: " << dp[m][n] << endl;
    }
    
    // Test 7: Sorting comparison
    sorting_comparison(100000);
    
    // Test 8: Hash table operations
    hash_table_operations();
    
    cout << "\n============================================================" << endl;
    cout << "CPU profiling examples complete!" << endl;
    
    return 0;
}