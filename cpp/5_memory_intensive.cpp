/*
 * Memory Intensive Operations Profiling Example
 * Demonstrates various memory access patterns and their impact on CPU performance.
 */

#include <iostream>
#include <vector>
#include <array>
#include <chrono>
#include <algorithm>
#include <numeric>
#include <random>
#include <memory>
#include <cstring>
#include <thread>
#include <atomic>

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

    ~Timer() {
        auto end_time = high_resolution_clock::now();
        auto duration = duration_cast<milliseconds>(end_time - start_time);
        cout << "   " << name << ": " << duration.count() / 1000.0 << "s" << endl;
    }
};

// 1. Sequential vs Random Memory Access
void memory_access_patterns() {
    cout << "\n1. Memory Access Patterns:" << endl;
    
    const size_t size = 100'000'000; // 100M elements
    vector<int> data(size);
    
    // Initialize with random values
    random_device rd;
    mt19937 gen(rd());
    uniform_int_distribution<> dis(0, 1000);
    for (auto& val : data) {
        val = dis(gen);
    }
    
    // Sequential access
    {
        Timer timer("Sequential access");
        long long sum = 0;
        for (size_t i = 0; i < size; ++i) {
            sum += data[i];
        }
        cout << "     Sum: " << sum << endl;
    }
    
    // Random access with indices
    vector<size_t> random_indices(size);
    iota(random_indices.begin(), random_indices.end(), 0);
    shuffle(random_indices.begin(), random_indices.end(), gen);
    
    {
        Timer timer("Random access");
        long long sum = 0;
        for (size_t i = 0; i < size; ++i) {
            sum += data[random_indices[i]];
        }
        cout << "     Sum: " << sum << endl;
    }
    
    // Strided access (cache-unfriendly)
    {
        Timer timer("Strided access (stride=64)");
        long long sum = 0;
        const size_t stride = 64;
        for (size_t j = 0; j < stride; ++j) {
            for (size_t i = j; i < size; i += stride) {
                sum += data[i];
            }
        }
        cout << "     Sum: " << sum << endl;
    }
}

// 2. Cache Line Effects
void cache_line_effects() {
    cout << "\n2. Cache Line Effects:" << endl;
    
    const size_t num_elements = 10'000'000;
    const size_t cache_line_size = 64; // Typical cache line size
    
    // Structure that fits in one cache line
    struct alignas(64) CacheLinePadded {
        long long value;
        char padding[56]; // Total size = 64 bytes
    };
    
    // Structure without padding (potential false sharing)
    struct NoPadding {
        long long value;
    };
    
    // Test with padding
    {
        vector<CacheLinePadded> padded_data(num_elements);
        
        Timer timer("With cache line padding");
        for (size_t i = 0; i < num_elements; ++i) {
            padded_data[i].value = i;
        }
        
        long long sum = 0;
        for (const auto& item : padded_data) {
            sum += item.value;
        }
        cout << "     Sum: " << sum << endl;
    }
    
    // Test without padding
    {
        vector<NoPadding> unpadded_data(num_elements);
        
        Timer timer("Without padding");
        for (size_t i = 0; i < num_elements; ++i) {
            unpadded_data[i].value = i;
        }
        
        long long sum = 0;
        for (const auto& item : unpadded_data) {
            sum += item.value;
        }
        cout << "     Sum: " << sum << endl;
    }
}

// 3. Memory Allocation Patterns
void memory_allocation_patterns() {
    cout << "\n3. Memory Allocation Patterns:" << endl;
    
    const size_t num_allocations = 100'000;
    const size_t allocation_size = 1024; // 1KB each
    
    // Many small allocations
    {
        Timer timer("Many small allocations (new/delete)");
        vector<char*> pointers;
        pointers.reserve(num_allocations);
        
        for (size_t i = 0; i < num_allocations; ++i) {
            pointers.push_back(new char[allocation_size]);
            memset(pointers.back(), i % 256, allocation_size);
        }
        
        for (auto ptr : pointers) {
            delete[] ptr;
        }
    }
    
    // Pool allocator simulation
    {
        Timer timer("Pool allocator (pre-allocated)");
        
        // Pre-allocate large buffer
        vector<char> pool(num_allocations * allocation_size);
        vector<char*> pointers;
        pointers.reserve(num_allocations);
        
        for (size_t i = 0; i < num_allocations; ++i) {
            pointers.push_back(&pool[i * allocation_size]);
            memset(pointers.back(), i % 256, allocation_size);
        }
        
        // No explicit deallocation needed
    }
    
    // Smart pointer allocations
    {
        Timer timer("Smart pointer allocations");
        vector<unique_ptr<char[]>> pointers;
        pointers.reserve(num_allocations);
        
        for (size_t i = 0; i < num_allocations; ++i) {
            pointers.push_back(make_unique<char[]>(allocation_size));
            memset(pointers.back().get(), i % 256, allocation_size);
        }
        
        // Automatic cleanup
    }
}

// 4. Memory Bandwidth Test
void memory_bandwidth_test() {
    cout << "\n4. Memory Bandwidth Test:" << endl;
    
    const size_t size = 1024 * 1024 * 100; // 100MB
    
    // Allocate aligned memory for better performance
    alignas(64) vector<char> src(size);
    alignas(64) vector<char> dst(size);
    
    // Initialize source
    for (size_t i = 0; i < size; ++i) {
        src[i] = static_cast<char>(i % 256);
    }
    
    // Test different copy methods
    
    // memcpy
    {
        Timer timer("memcpy");
        memcpy(dst.data(), src.data(), size);
    }
    
    // std::copy
    {
        Timer timer("std::copy");
        copy(src.begin(), src.end(), dst.begin());
    }
    
    // Manual copy (byte by byte)
    {
        Timer timer("Manual copy (byte)");
        for (size_t i = 0; i < size; ++i) {
            dst[i] = src[i];
        }
    }
    
    // Manual copy (8 bytes at a time)
    {
        Timer timer("Manual copy (8-byte chunks)");
        const size_t chunk_size = sizeof(uint64_t);
        const size_t num_chunks = size / chunk_size;
        
        uint64_t* src64 = reinterpret_cast<uint64_t*>(src.data());
        uint64_t* dst64 = reinterpret_cast<uint64_t*>(dst.data());
        
        for (size_t i = 0; i < num_chunks; ++i) {
            dst64[i] = src64[i];
        }
        
        // Handle remaining bytes
        for (size_t i = num_chunks * chunk_size; i < size; ++i) {
            dst[i] = src[i];
        }
    }
}

// 5. Data Structure Layout Effects
void data_structure_layout() {
    cout << "\n5. Data Structure Layout Effects:" << endl;
    
    const size_t num_elements = 10'000'000;
    
    // Array of Structures (AoS)
    struct Particle_AoS {
        float x, y, z;
        float vx, vy, vz;
        float mass;
        float charge;
    };
    
    // Structure of Arrays (SoA)
    struct Particle_SoA {
        vector<float> x, y, z;
        vector<float> vx, vy, vz;
        vector<float> mass;
        vector<float> charge;
        
        Particle_SoA(size_t n) : 
            x(n), y(n), z(n), 
            vx(n), vy(n), vz(n), 
            mass(n), charge(n) {}
    };
    
    // Test AoS
    {
        vector<Particle_AoS> particles_aos(num_elements);
        
        // Initialize
        for (size_t i = 0; i < num_elements; ++i) {
            particles_aos[i] = {
                float(i), float(i+1), float(i+2),
                float(i*0.1), float(i*0.2), float(i*0.3),
                1.0f, float(i % 2 ? 1.0 : -1.0)
            };
        }
        
        Timer timer("Array of Structures (position update)");
        for (auto& p : particles_aos) {
            p.x += p.vx * 0.01f;
            p.y += p.vy * 0.01f;
            p.z += p.vz * 0.01f;
        }
    }
    
    // Test SoA
    {
        Particle_SoA particles_soa(num_elements);
        
        // Initialize
        for (size_t i = 0; i < num_elements; ++i) {
            particles_soa.x[i] = float(i);
            particles_soa.y[i] = float(i+1);
            particles_soa.z[i] = float(i+2);
            particles_soa.vx[i] = float(i*0.1);
            particles_soa.vy[i] = float(i*0.2);
            particles_soa.vz[i] = float(i*0.3);
            particles_soa.mass[i] = 1.0f;
            particles_soa.charge[i] = float(i % 2 ? 1.0 : -1.0);
        }
        
        Timer timer("Structure of Arrays (position update)");
        for (size_t i = 0; i < num_elements; ++i) {
            particles_soa.x[i] += particles_soa.vx[i] * 0.01f;
            particles_soa.y[i] += particles_soa.vy[i] * 0.01f;
            particles_soa.z[i] += particles_soa.vz[i] * 0.01f;
        }
    }
}

// 6. Memory Fragmentation Test
void memory_fragmentation_test() {
    cout << "\n6. Memory Fragmentation Test:" << endl;
    
    const size_t num_iterations = 10000;
    random_device rd;
    mt19937 gen(rd());
    uniform_int_distribution<> size_dis(100, 10000);
    
    // Fragmentation-inducing pattern
    {
        Timer timer("Fragmentation-inducing allocation pattern");
        vector<unique_ptr<char[]>> allocations;
        
        for (size_t i = 0; i < num_iterations; ++i) {
            // Allocate random size
            size_t size = size_dis(gen);
            allocations.push_back(make_unique<char[]>(size));
            
            // Randomly deallocate some
            if (allocations.size() > 100 && i % 3 == 0) {
                uniform_int_distribution<> idx_dis(0, allocations.size() - 1);
                int idx = idx_dis(gen);
                allocations.erase(allocations.begin() + idx);
            }
        }
    }
    
    // Better allocation pattern
    {
        Timer timer("Size-pooled allocation pattern");
        
        // Pools for different size classes
        vector<vector<unique_ptr<char[]>>> pools(10);
        
        for (size_t i = 0; i < num_iterations; ++i) {
            size_t size = size_dis(gen);
            size_t pool_idx = min(size / 1000, size_t(9));
            
            pools[pool_idx].push_back(make_unique<char[]>(size));
            
            // Remove from same pool
            if (pools[pool_idx].size() > 10 && i % 3 == 0) {
                pools[pool_idx].pop_back();
            }
        }
    }
}

// 7. NUMA Effects Simulation
void numa_effects_simulation() {
    cout << "\n7. NUMA Effects Simulation:" << endl;
    
    const size_t size = 50'000'000; // 50M elements
    const int num_threads = thread::hardware_concurrency();
    
    vector<int> shared_data(size);
    
    // Initialize data
    for (size_t i = 0; i < size; ++i) {
        shared_data[i] = i % 1000;
    }
    
    // All threads access same memory region
    {
        Timer timer("All threads same region");
        vector<thread> threads;
        atomic<long long> total_sum(0);
        
        for (int t = 0; t < num_threads; ++t) {
            threads.emplace_back([&shared_data, &total_sum, size]() {
                long long local_sum = 0;
                for (size_t i = 0; i < size; ++i) {
                    local_sum += shared_data[i];
                }
                total_sum += local_sum;
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
        
        cout << "     Sum: " << total_sum.load() << endl;
    }
    
    // Each thread accesses different region
    {
        Timer timer("Each thread different region");
        vector<thread> threads;
        atomic<long long> total_sum(0);
        
        size_t chunk_size = size / num_threads;
        
        for (int t = 0; t < num_threads; ++t) {
            threads.emplace_back([&shared_data, &total_sum, t, chunk_size, num_threads, size]() {
                size_t start = t * chunk_size;
                size_t end = (t == num_threads - 1) ? size : start + chunk_size;
                
                long long local_sum = 0;
                for (size_t i = start; i < end; ++i) {
                    local_sum += shared_data[i];
                }
                total_sum += local_sum;
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
        
        cout << "     Sum: " << total_sum.load() << endl;
    }
}

int main() {
    cout << "Memory Intensive Operations Profiling Examples" << endl;
    cout << "============================================================" << endl;
    
    // Run all memory tests
    memory_access_patterns();
    cache_line_effects();
    memory_allocation_patterns();
    memory_bandwidth_test();
    data_structure_layout();
    memory_fragmentation_test();
    numa_effects_simulation();
    
    cout << "\n============================================================" << endl;
    cout << "Memory profiling examples complete!" << endl;
    cout << "\nProfiler hints:" << endl;
    cout << "- Use 'nsys profile --sample=cpu --cpuctxsw=true' to see context switches" << endl;
    cout << "- Look for cache miss patterns in the CPU sampling data" << endl;
    cout << "- Memory bandwidth limitations will show as CPU stalls" << endl;
    cout << "- Compare different data layouts for cache efficiency" << endl;
    
    return 0;
}