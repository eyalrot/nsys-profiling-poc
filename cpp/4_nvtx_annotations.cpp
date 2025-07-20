/*
 * NVTX Annotations Example for C++
 * Demonstrates how to use NVTX markers for detailed profiling with nsys.
 * Compile with: -lnvToolsExt (link against NVTX library)
 */

#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#include <chrono>
#include <thread>
#include <cmath>
#include <string>
#include <functional>

// NVTX header - will be conditionally included
#ifdef USE_NVTX
#include <nvToolsExt.h>
#else
// Dummy NVTX implementation when not available
namespace {
    void nvtxRangePushA(const char* message) {}
    void nvtxRangePushEx(const void* eventAttrib) {}
    void nvtxRangePop() {}
    void nvtxMarkA(const char* message) {}
    
    struct nvtxEventAttributes_t {
        uint16_t version;
        uint16_t size;
        uint32_t category;
        int32_t colorType;
        uint32_t color;
        int32_t payloadType;
        int32_t messageType;
        const char* message;
    };
    
    #define NVTX_VERSION 1
    #define NVTX_EVENT_ATTRIB_STRUCT_SIZE sizeof(nvtxEventAttributes_t)
    #define NVTX_COLOR_ARGB 1
}
#endif

using namespace std;
using namespace std::chrono;

// Helper class for NVTX ranges with RAII
class NVTXRange {
private:
    bool active;
    
public:
    NVTXRange(const string& name, uint32_t color = 0xFF00FF00) : active(true) {
#ifdef USE_NVTX
        nvtxEventAttributes_t eventAttrib = {0};
        eventAttrib.version = NVTX_VERSION;
        eventAttrib.size = NVTX_EVENT_ATTRIB_STRUCT_SIZE;
        eventAttrib.colorType = NVTX_COLOR_ARGB;
        eventAttrib.color = color;
        eventAttrib.messageType = NVTX_MESSAGE_TYPE_ASCII;
        eventAttrib.message.ascii = name.c_str();
        nvtxRangePushEx(&eventAttrib);
#else
        nvtxRangePushA(name.c_str());
#endif
    }
    
    ~NVTXRange() {
        if (active) {
            nvtxRangePop();
        }
    }
    
    // Disable copy
    NVTXRange(const NVTXRange&) = delete;
    NVTXRange& operator=(const NVTXRange&) = delete;
    
    // Enable move
    NVTXRange(NVTXRange&& other) : active(other.active) {
        other.active = false;
    }
};

// Timer utility with NVTX integration
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

// Color definitions for NVTX
namespace Colors {
    const uint32_t RED = 0xFFFF0000;
    const uint32_t GREEN = 0xFF00FF00;
    const uint32_t BLUE = 0xFF0000FF;
    const uint32_t YELLOW = 0xFFFFFF00;
    const uint32_t PURPLE = 0xFFFF00FF;
    const uint32_t CYAN = 0xFF00FFFF;
    const uint32_t ORANGE = 0xFFFFA500;
    const uint32_t WHITE = 0xFFFFFFFF;
}

// Data preprocessing with NVTX annotations
vector<double> preprocess_data(size_t size) {
    NVTXRange range("DataPreprocessing", Colors::RED);
    
    // Data loading phase
    vector<double> data;
    {
        NVTXRange load_range("LoadData", Colors::YELLOW);
        data.resize(size);
        for (size_t i = 0; i < size; ++i) {
            data[i] = static_cast<double>(rand()) / RAND_MAX;
        }
        this_thread::sleep_for(milliseconds(100)); // Simulate I/O
    }
    
    // Normalization phase
    {
        NVTXRange norm_range("Normalize", Colors::GREEN);
        double mean = accumulate(data.begin(), data.end(), 0.0) / size;
        double sq_sum = 0;
        for (const auto& val : data) {
            sq_sum += (val - mean) * (val - mean);
        }
        double std_dev = sqrt(sq_sum / size);
        
        for (auto& val : data) {
            val = (val - mean) / (std_dev + 1e-8);
        }
    }
    
    // Feature extraction phase
    {
        NVTXRange feature_range("ExtractFeatures", Colors::BLUE);
        vector<double> features;
        features.reserve(size * 3);
        
        for (const auto& val : data) {
            features.push_back(val);
            features.push_back(val * val);
            features.push_back(abs(val));
        }
        
        return features;
    }
}

// Model training simulation with nested NVTX ranges
vector<double> train_model(const vector<double>& data, int epochs = 10) {
    NVTXRange range("ModelTraining", Colors::PURPLE);
    Timer timer("Model training");
    
    size_t n_features = data.size();
    vector<double> weights(n_features);
    for (auto& w : weights) {
        w = static_cast<double>(rand()) / RAND_MAX;
    }
    
    double learning_rate = 0.01;
    
    for (int epoch = 0; epoch < epochs; ++epoch) {
        NVTXRange epoch_range("Epoch_" + to_string(epoch), Colors::ORANGE);
        
        // Forward pass
        double loss = 0;
        {
            NVTXRange forward_range("Forward", Colors::CYAN);
            for (size_t i = 0; i < n_features; ++i) {
                loss += data[i] * weights[i];
            }
            loss = loss * loss; // Squared loss
        }
        
        // Backward pass
        {
            NVTXRange backward_range("Backward", Colors::PURPLE);
            for (size_t i = 0; i < n_features; ++i) {
                double gradient = 2 * loss * data[i];
                weights[i] -= learning_rate * gradient;
            }
        }
        
        // Mark epoch completion
        nvtxMarkA(("Epoch " + to_string(epoch) + " completed").c_str());
    }
    
    return weights;
}

// Complex workflow with multiple NVTX domains
void complex_workflow() {
    cout << "\n5. Complex Workflow with NVTX Domains:" << endl;
    
    // Phase 1: Data preparation
    {
        NVTXRange range("DataPreparation", Colors::RED);
        
        vector<vector<double>> datasets;
        for (int i = 0; i < 3; ++i) {
            NVTXRange dataset_range("LoadDataset_" + to_string(i), Colors::YELLOW);
            
            vector<double> data(10000);
            for (auto& val : data) {
                val = static_cast<double>(rand()) / RAND_MAX;
            }
            datasets.push_back(data);
            
            this_thread::sleep_for(milliseconds(50));
        }
    }
    
    // Phase 2: Parallel processing simulation
    {
        NVTXRange range("ParallelProcessing", Colors::GREEN);
        
        vector<thread> workers;
        for (int i = 0; i < 4; ++i) {
            workers.emplace_back([i]() {
                NVTXRange worker_range("Worker_" + to_string(i), Colors::BLUE);
                
                // Simulate complex computation
                vector<double> result(1000);
                for (int j = 0; j < 1000; ++j) {
                    result[j] = sin(j) * cos(j) + sqrt(abs(j));
                }
                
                this_thread::sleep_for(milliseconds(100));
            });
        }
        
        for (auto& t : workers) {
            t.join();
        }
    }
    
    // Phase 3: Aggregation
    {
        NVTXRange range("Aggregation", Colors::PURPLE);
        
        double final_result = 0;
        for (int i = 0; i < 10000; ++i) {
            final_result += sqrt(i) * log(i + 1);
        }
        
        cout << "   Complex workflow completed" << endl;
    }
}

// Algorithm comparison with NVTX annotations
void benchmark_algorithms() {
    cout << "\n6. Algorithm Comparison with NVTX Annotations:" << endl;
    
    const size_t size = 100000;
    vector<int> data(size);
    for (size_t i = 0; i < size; ++i) {
        data[i] = rand() % 1000000;
    }
    
    // Bubble sort (small dataset)
    if (size <= 1000) {
        vector<int> bubble_data = data;
        NVTXRange range("BubbleSort", Colors::RED);
        Timer timer("Bubble sort");
        
        for (size_t i = 0; i < size - 1; ++i) {
            if (i % 100 == 0) {
                NVTXRange progress_range("BubbleSort_Progress_" + to_string(i/100), 
                                       Colors::YELLOW);
            }
            
            for (size_t j = 0; j < size - i - 1; ++j) {
                if (bubble_data[j] > bubble_data[j + 1]) {
                    swap(bubble_data[j], bubble_data[j + 1]);
                }
            }
        }
    }
    
    // Quick sort
    {
        vector<int> quick_data = data;
        NVTXRange range("QuickSort", Colors::GREEN);
        Timer timer("Quick sort");
        
        std::function<void(int, int)> quicksort = [&](int low, int high) {
            if (low < high) {
                // Partition
                int pivot = quick_data[high];
                int i = low - 1;
                
                for (int j = low; j < high; ++j) {
                    if (quick_data[j] < pivot) {
                        i++;
                        swap(quick_data[i], quick_data[j]);
                    }
                }
                swap(quick_data[i + 1], quick_data[high]);
                
                int pi = i + 1;
                quicksort(low, pi - 1);
                quicksort(pi + 1, high);
            }
        };
        
        quicksort(0, size - 1);
    }
    
    // STL sort
    {
        vector<int> stl_data = data;
        NVTXRange range("STLSort", Colors::BLUE);
        Timer timer("STL sort");
        sort(stl_data.begin(), stl_data.end());
    }
}

// Matrix operations with detailed NVTX profiling
void matrix_operations_with_nvtx() {
    cout << "\n7. Matrix Operations with Detailed NVTX Profiling:" << endl;
    
    const size_t size = 500;
    
    // Initialize matrices
    vector<vector<double>> a(size, vector<double>(size));
    vector<vector<double>> b(size, vector<double>(size));
    
    {
        NVTXRange range("MatrixInitialization", Colors::YELLOW);
        for (size_t i = 0; i < size; ++i) {
            for (size_t j = 0; j < size; ++j) {
                a[i][j] = static_cast<double>(rand()) / RAND_MAX;
                b[i][j] = static_cast<double>(rand()) / RAND_MAX;
            }
        }
    }
    
    // Matrix multiplication with detailed profiling
    {
        NVTXRange range("MatrixMultiplication", Colors::PURPLE);
        Timer timer("Matrix multiplication");
        
        vector<vector<double>> c(size, vector<double>(size, 0));
        
        // Tile-based multiplication for better cache usage
        const size_t tile_size = 64;
        for (size_t i0 = 0; i0 < size; i0 += tile_size) {
            NVTXRange tile_i_range("Tile_I_" + to_string(i0/tile_size), Colors::RED);
            
            for (size_t j0 = 0; j0 < size; j0 += tile_size) {
                NVTXRange tile_j_range("Tile_J_" + to_string(j0/tile_size), Colors::GREEN);
                
                for (size_t k0 = 0; k0 < size; k0 += tile_size) {
                    NVTXRange tile_k_range("Tile_K_" + to_string(k0/tile_size), Colors::BLUE);
                    
                    // Compute tile
                    size_t i_max = min(i0 + tile_size, size);
                    size_t j_max = min(j0 + tile_size, size);
                    size_t k_max = min(k0 + tile_size, size);
                    
                    for (size_t i = i0; i < i_max; ++i) {
                        for (size_t j = j0; j < j_max; ++j) {
                            for (size_t k = k0; k < k_max; ++k) {
                                c[i][j] += a[i][k] * b[k][j];
                            }
                        }
                    }
                }
            }
        }
    }
}

int main() {
    cout << "NVTX Annotations Profiling Examples (C++)" << endl;
#ifdef USE_NVTX
    cout << "NVTX: Enabled" << endl;
#else
    cout << "NVTX: Using dummy implementation (compile with -DUSE_NVTX -lnvToolsExt for real NVTX)" << endl;
#endif
    cout << "============================================================" << endl;
    
    // Example 1: Basic function annotation
    cout << "\n1. Basic Function Annotations:" << endl;
    auto preprocessed_data = preprocess_data(10000);
    cout << "   Preprocessed data size: " << preprocessed_data.size() << endl;
    
    // Example 2: Nested annotations in training
    cout << "\n2. Model Training with Nested Annotations:" << endl;
    auto weights = train_model(preprocessed_data, 5);
    cout << "   Model weights size: " << weights.size() << endl;
    
    // Example 3: Scoped NVTX ranges
    cout << "\n3. Scoped NVTX Ranges Example:" << endl;
    {
        NVTXRange outer_range("OuterScope", Colors::PURPLE);
        
        {
            NVTXRange phase1_range("Phase1", Colors::RED);
            this_thread::sleep_for(milliseconds(100));
        }
        
        {
            NVTXRange phase2_range("Phase2", Colors::GREEN);
            this_thread::sleep_for(milliseconds(100));
        }
        
        {
            NVTXRange phase3_range("Phase3", Colors::BLUE);
            this_thread::sleep_for(milliseconds(100));
        }
    }
    cout << "   Scoped ranges completed" << endl;
    
    // Example 4: NVTX marks
    cout << "\n4. NVTX Marks Example:" << endl;
    for (int i = 0; i < 5; ++i) {
        nvtxMarkA(("Processing iteration " + to_string(i)).c_str());
        this_thread::sleep_for(milliseconds(50));
    }
    cout << "   Marks example completed" << endl;
    
    // Example 5: Complex workflow
    complex_workflow();
    
    // Example 6: Algorithm comparison
    benchmark_algorithms();
    
    // Example 7: Matrix operations
    matrix_operations_with_nvtx();
    
    cout << "\n============================================================" << endl;
    cout << "NVTX annotation examples complete!" << endl;
    cout << "\nProfiler hints:" << endl;
    cout << "- Compile with: g++ -O2 -DUSE_NVTX file.cpp -lnvToolsExt" << endl;
    cout << "- Use 'nsys profile --trace=nvtx' to capture NVTX markers" << endl;
    cout << "- NVTX ranges will appear as colored blocks in the timeline" << endl;
    cout << "- Use different colors to organize your profiling data" << endl;
    
    return 0;
}