/*
 * Multithreading Profiling Example
 * Demonstrates various multithreading patterns for CPU profiling with nsys.
 */

#include <iostream>
#include <vector>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <future>
#include <queue>
#include <chrono>
#include <numeric>
#include <algorithm>
#include <random>
#include <functional>

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

// CPU-intensive task
long long cpu_bound_task(int n) {
    long long total = 0;
    for (int i = 0; i < n; ++i) {
        total += i * i;
    }
    return total;
}

// Thread pool implementation
class ThreadPool {
private:
    vector<thread> workers;
    queue<function<void()>> tasks;
    mutex queue_mutex;
    condition_variable condition;
    atomic<bool> stop;

public:
    ThreadPool(size_t num_threads) : stop(false) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers.emplace_back([this] {
                while (true) {
                    function<void()> task;
                    
                    {
                        unique_lock<mutex> lock(queue_mutex);
                        condition.wait(lock, [this] { 
                            return stop.load() || !tasks.empty(); 
                        });
                        
                        if (stop.load() && tasks.empty()) {
                            return;
                        }
                        
                        task = move(tasks.front());
                        tasks.pop();
                    }
                    
                    task();
                }
            });
        }
    }
    
    template<class F>
    void enqueue(F&& f) {
        {
            unique_lock<mutex> lock(queue_mutex);
            tasks.emplace(forward<F>(f));
        }
        condition.notify_one();
    }
    
    ~ThreadPool() {
        stop.store(true);
        condition.notify_all();
        
        for (thread& worker : workers) {
            worker.join();
        }
    }
};

// 1. Basic threading example
void basic_threading_example() {
    cout << "\n1. Basic Threading Example:" << endl;
    
    const int num_threads = thread::hardware_concurrency();
    const int work_per_thread = 10000000;
    
    // Sequential execution
    {
        Timer timer("Sequential execution");
        long long total = 0;
        for (int i = 0; i < num_threads; ++i) {
            total += cpu_bound_task(work_per_thread);
        }
        cout << "     Total: " << total << endl;
    }
    
    // Parallel execution
    {
        Timer timer("Parallel execution (" + to_string(num_threads) + " threads)");
        vector<thread> threads;
        vector<long long> results(num_threads);
        
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([i, &results, work_per_thread]() {
                results[i] = cpu_bound_task(work_per_thread);
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
        
        long long total = accumulate(results.begin(), results.end(), 0LL);
        cout << "     Total: " << total << endl;
    }
}

// 2. Mutex contention example
void mutex_contention_example() {
    cout << "\n2. Mutex Contention Example:" << endl;
    
    const int num_threads = 8;
    const int iterations = 1000000;
    
    // High contention (single mutex)
    {
        Timer timer("High contention (single mutex)");
        mutex mtx;
        long long shared_counter = 0;
        vector<thread> threads;
        
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&mtx, &shared_counter, iterations]() {
                for (int j = 0; j < iterations; ++j) {
                    lock_guard<mutex> lock(mtx);
                    shared_counter++;
                }
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
        
        cout << "     Counter: " << shared_counter << endl;
    }
    
    // Low contention (multiple mutexes)
    {
        Timer timer("Low contention (striped locks)");
        const int num_stripes = 64;
        vector<mutex> mutexes(num_stripes);
        vector<long long> counters(num_stripes, 0);
        vector<thread> threads;
        
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&mutexes, &counters, iterations, num_stripes, i]() {
                for (int j = 0; j < iterations; ++j) {
                    int stripe = (i + j) % num_stripes;
                    lock_guard<mutex> lock(mutexes[stripe]);
                    counters[stripe]++;
                }
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
        
        long long total = accumulate(counters.begin(), counters.end(), 0LL);
        cout << "     Total: " << total << endl;
    }
    
    // Lock-free (atomic)
    {
        Timer timer("Lock-free (atomic)");
        atomic<long long> atomic_counter(0);
        vector<thread> threads;
        
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&atomic_counter, iterations]() {
                for (int j = 0; j < iterations; ++j) {
                    atomic_counter.fetch_add(1, memory_order_relaxed);
                }
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
        
        cout << "     Counter: " << atomic_counter.load() << endl;
    }
}

// 3. Producer-consumer pattern
void producer_consumer_example() {
    cout << "\n3. Producer-Consumer Pattern:" << endl;
    
    const int num_producers = 2;
    const int num_consumers = 4;
    const int items_per_producer = 10000;
    
    Timer timer("Producer-consumer execution");
    
    queue<int> work_queue;
    mutex queue_mutex;
    condition_variable cv_producer, cv_consumer;
    atomic<int> items_produced(0);
    atomic<int> items_consumed(0);
    atomic<bool> done_producing(false);
    const size_t max_queue_size = 100;
    
    // Producer function
    auto producer = [&](int id) {
        for (int i = 0; i < items_per_producer; ++i) {
            unique_lock<mutex> lock(queue_mutex);
            cv_producer.wait(lock, [&] { 
                return work_queue.size() < max_queue_size; 
            });
            
            work_queue.push(id * items_per_producer + i);
            items_produced++;
            
            lock.unlock();
            cv_consumer.notify_one();
        }
    };
    
    // Consumer function
    auto consumer = [&](int id) {
        while (true) {
            unique_lock<mutex> lock(queue_mutex);
            cv_consumer.wait(lock, [&] { 
                return !work_queue.empty() || done_producing.load(); 
            });
            
            if (work_queue.empty() && done_producing.load()) {
                break;
            }
            
            int item = work_queue.front();
            work_queue.pop();
            items_consumed++;
            
            lock.unlock();
            cv_producer.notify_one();
            
            // Simulate work
            cpu_bound_task(1000);
        }
    };
    
    // Start threads
    vector<thread> producers, consumers;
    
    for (int i = 0; i < num_producers; ++i) {
        producers.emplace_back(producer, i);
    }
    
    for (int i = 0; i < num_consumers; ++i) {
        consumers.emplace_back(consumer, i);
    }
    
    // Wait for producers
    for (auto& t : producers) {
        t.join();
    }
    
    done_producing.store(true);
    cv_consumer.notify_all();
    
    // Wait for consumers
    for (auto& t : consumers) {
        t.join();
    }
    
    cout << "     Items produced: " << items_produced.load() << endl;
    cout << "     Items consumed: " << items_consumed.load() << endl;
}

// 4. Thread pool example
void thread_pool_example() {
    cout << "\n4. Thread Pool Example:" << endl;
    
    const int pool_size = thread::hardware_concurrency();
    const int num_tasks = 1000;
    
    {
        Timer timer("Thread pool execution");
        ThreadPool pool(pool_size);
        vector<future<long long>> futures;
        
        for (int i = 0; i < num_tasks; ++i) {
            auto promise = make_shared<std::promise<long long>>();
            futures.push_back(promise->get_future());
            
            pool.enqueue([promise, i]() {
                long long result = cpu_bound_task(10000);
                promise->set_value(result);
            });
        }
        
        long long total = 0;
        for (auto& f : futures) {
            total += f.get();
        }
        
        cout << "     Total result: " << total << endl;
    }
}

// 5. False sharing demonstration
void false_sharing_example() {
    cout << "\n5. False Sharing Example:" << endl;
    
    const int num_threads = 4;
    const int iterations = 100000000;
    
    // With false sharing
    {
        Timer timer("With false sharing");
        struct Counter {
            long long value;
        };
        
        vector<Counter> counters(num_threads);
        vector<thread> threads;
        
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&counters, i, iterations]() {
                for (int j = 0; j < iterations; ++j) {
                    counters[i].value++;
                }
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
    }
    
    // Without false sharing (padded)
    {
        Timer timer("Without false sharing (padded)");
        struct PaddedCounter {
            alignas(64) long long value;  // Cache line size padding
        };
        
        vector<PaddedCounter> counters(num_threads);
        vector<thread> threads;
        
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&counters, i, iterations]() {
                for (int j = 0; j < iterations; ++j) {
                    counters[i].value++;
                }
            });
        }
        
        for (auto& t : threads) {
            t.join();
        }
    }
}

// 6. Work stealing example (simplified)
void work_stealing_example() {
    cout << "\n6. Work Stealing Pattern:" << endl;
    
    const int num_threads = 4;
    const int total_work = 1000000;
    
    Timer timer("Work stealing execution");
    
    // Per-thread work queues
    vector<queue<int>> work_queues(num_threads);
    vector<mutex> queue_mutexes(num_threads);
    atomic<int> completed_work(0);
    
    // Initially distribute work
    for (int i = 0; i < total_work; ++i) {
        work_queues[i % num_threads].push(i);
    }
    
    // Worker function with work stealing
    auto worker = [&](int id) {
        random_device rd;
        mt19937 gen(rd());
        uniform_int_distribution<> dis(0, num_threads - 1);
        
        while (completed_work.load() < total_work) {
            int work_item = -1;
            
            // Try to get work from own queue
            {
                lock_guard<mutex> lock(queue_mutexes[id]);
                if (!work_queues[id].empty()) {
                    work_item = work_queues[id].front();
                    work_queues[id].pop();
                }
            }
            
            // If no work, try to steal from others
            if (work_item == -1) {
                int victim = dis(gen);
                if (victim != id) {
                    lock_guard<mutex> lock(queue_mutexes[victim]);
                    if (!work_queues[victim].empty()) {
                        work_item = work_queues[victim].front();
                        work_queues[victim].pop();
                    }
                }
            }
            
            // Process work if found
            if (work_item != -1) {
                cpu_bound_task(100);
                completed_work.fetch_add(1);
            } else {
                // Brief sleep if no work found
                this_thread::sleep_for(microseconds(10));
            }
        }
    };
    
    // Start workers
    vector<thread> workers;
    for (int i = 0; i < num_threads; ++i) {
        workers.emplace_back(worker, i);
    }
    
    // Wait for completion
    for (auto& t : workers) {
        t.join();
    }
    
    cout << "     Completed work items: " << completed_work.load() << endl;
}

// 7. Async/future example
void async_future_example() {
    cout << "\n7. Async/Future Example:" << endl;
    
    const int num_tasks = 100;
    
    // Using async with deferred policy
    {
        Timer timer("Async with deferred policy");
        vector<future<long long>> futures;
        
        for (int i = 0; i < num_tasks; ++i) {
            futures.push_back(async(launch::deferred, [i]() {
                return cpu_bound_task(10000);
            }));
        }
        
        long long total = 0;
        for (auto& f : futures) {
            total += f.get();
        }
        cout << "     Total: " << total << endl;
    }
    
    // Using async with async policy
    {
        Timer timer("Async with async policy");
        vector<future<long long>> futures;
        
        for (int i = 0; i < num_tasks; ++i) {
            futures.push_back(async(launch::async, [i]() {
                return cpu_bound_task(10000);
            }));
        }
        
        long long total = 0;
        for (auto& f : futures) {
            total += f.get();
        }
        cout << "     Total: " << total << endl;
    }
}

int main() {
    cout << "Multithreading Profiling Examples" << endl;
    cout << "Hardware concurrency: " << thread::hardware_concurrency() << " threads" << endl;
    cout << "============================================================" << endl;
    
    // Run examples
    basic_threading_example();
    mutex_contention_example();
    producer_consumer_example();
    thread_pool_example();
    false_sharing_example();
    work_stealing_example();
    async_future_example();
    
    cout << "\n============================================================" << endl;
    cout << "Multithreading examples complete!" << endl;
    cout << "\nProfiler hints:" << endl;
    cout << "- Use 'nsys profile --trace=osrt --sample=cpu' to see thread creation/destruction" << endl;
    cout << "- Look for lock contention and synchronization overhead" << endl;
    cout << "- Compare CPU utilization across different threading patterns" << endl;
    cout << "- Check for false sharing effects in performance" << endl;
    
    return 0;
}