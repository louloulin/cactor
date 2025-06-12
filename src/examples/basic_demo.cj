/*
 * 仓颉Actor系统 - 基础演示
 * 展示基本的Actor概念和并发编程
 */
package default

import std.sync.*
import std.collection.*

// 简单的工作者Actor
public class WorkerActor {
    private let workerName: String
    private var taskCount: Int64 = 0
    private let isRunning: AtomicBool = AtomicBool(false)
    
    public init(name: String) {
        this.workerName = name
    }
    
    public func getName(): String {
        workerName
    }
    
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("Worker ${workerName} started")
            
            // 在新线程中运行
            spawn {
                this.run()
            }
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("Worker ${workerName} stopping...")
        }
    }
    
    public func isActive(): Bool {
        isRunning.load()
    }
    
    public func getTaskCount(): Int64 {
        taskCount
    }
    
    public func doWork(workId: Int64): Unit {
        if (isRunning.load()) {
            taskCount += 1
            println("Worker ${workerName} processing task ${workId} (total: ${taskCount})")
            
            // 模拟工作
            sleep(Duration.millisecond * 100)
        }
    }
    
    private func run(): Unit {
        while (isRunning.load()) {
            // 模拟工作循环
            sleep(Duration.millisecond * 50)
        }
        println("Worker ${workerName} stopped, completed ${taskCount} tasks")
    }
}

// 计数器Actor
public class CounterActor {
    private var count: Int64 = 0
    private let lock: Mutex = Mutex()
    private let isActive: AtomicBool = AtomicBool(false)
    
    public func start(): Unit {
        isActive.store(true)
        println("Counter Actor started")
    }
    
    public func stop(): Unit {
        isActive.store(false)
        println("Counter Actor stopped, final count: ${getCount()}")
    }
    
    public func increment(): Int64 {
        lock.lock()
        try {
            if (isActive.load()) {
                count += 1
                return count
            } else {
                return count
            }
        } finally {
            lock.unlock()
        }
    }
    
    public func decrement(): Int64 {
        lock.lock()
        try {
            if (isActive.load()) {
                count -= 1
                return count
            } else {
                return count
            }
        } finally {
            lock.unlock()
        }
    }
    
    public func getCount(): Int64 {
        lock.lock()
        try {
            return count
        } finally {
            lock.unlock()
        }
    }
    
    public func reset(): Unit {
        lock.lock()
        try {
            if (isActive.load()) {
                count = 0
            }
        } finally {
            lock.unlock()
        }
    }
}

// Actor管理器
public class SimpleActorManager {
    private let workers: ArrayList<WorkerActor> = ArrayList<WorkerActor>()
    private let counter: CounterActor = CounterActor()
    private let isRunning: AtomicBool = AtomicBool(false)
    
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("Actor Manager starting...")
            counter.start()
            
            // 创建多个工作者
            for (i in 0..3) {
                let worker = WorkerActor("Worker-${i}")
                workers.append(worker)
                worker.start()
            }
            
            println("Actor Manager started with ${workers.size()} workers")
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("Actor Manager stopping...")
            
            // 停止所有工作者
            for (worker in workers) {
                worker.stop()
            }
            
            counter.stop()
            
            // 等待工作者停止
            sleep(Duration.millisecond * 200)
            println("Actor Manager stopped")
        }
    }
    
    public func assignWork(workId: Int64): Unit {
        if (isRunning.load() && !workers.isEmpty()) {
            // 简单的轮询分配
            let workerIndex = (workId % workers.size()).toInt64()
            let worker = workers[workerIndex]
            worker.doWork(workId)
            counter.increment()
        }
    }
    
    public func getStatus(): String {
        let activeWorkers = workers.filter { w => w.isActive() }.size()
        let totalTasks = counter.getCount()
        return "Active Workers: ${activeWorkers}, Total Tasks: ${totalTasks}"
    }
}

// 主演示函数
main(): Unit {
    println("=== 仓颉Actor系统基础演示 ===")
    
    let manager = SimpleActorManager()
    
    try {
        // 启动Actor管理器
        manager.start()
        
        // 等待启动完成
        sleep(Duration.millisecond * 100)
        
        println("Initial status: ${manager.getStatus()}")
        
        // 分配一些工作
        println("\n--- 分配工作任务 ---")
        for (i in 1..10) {
            manager.assignWork(i)
            sleep(Duration.millisecond * 50)
        }
        
        // 等待工作完成
        sleep(Duration.second)
        
        println("Final status: ${manager.getStatus()}")
        
    } catch (e: Exception) {
        println("Error: ${e}")
    } finally {
        // 停止管理器
        manager.stop()
    }
    
    println("=== 演示结束 ===")
}

// 并发测试函数
func concurrencyTest(): Unit {
    println("\n=== 并发测试 ===")
    
    let counter = CounterActor()
    counter.start()
    
    let numThreads = 5
    let tasksPerThread = 100
    
    println("启动 ${numThreads} 个线程，每个执行 ${tasksPerThread} 个任务")
    
    // 启动多个线程并发操作
    for (i in 0..numThreads) {
        spawn {
            for (j in 0..tasksPerThread) {
                counter.increment()
                sleep(Duration.millisecond)
            }
            println("Thread ${i} completed")
        }
    }
    
    // 等待所有线程完成
    sleep(Duration.second * 2)
    
    let finalCount = counter.getCount()
    let expectedCount = numThreads * tasksPerThread
    
    println("Expected count: ${expectedCount}")
    println("Actual count: ${finalCount}")
    println("Test ${if (finalCount == expectedCount) "PASSED" else "FAILED"}")
    
    counter.stop()
}

// 性能测试函数
func performanceTest(): Unit {
    println("\n=== 性能测试 ===")
    
    let numWorkers = 10
    let workers = ArrayList<WorkerActor>()
    
    // 创建工作者
    for (i in 0..numWorkers) {
        let worker = WorkerActor("PerfWorker-${i}")
        workers.append(worker)
        worker.start()
    }
    
    // 等待启动
    sleep(Duration.millisecond * 100)
    
    let startTime = MonoTime.now()
    let numTasks = 1000
    
    println("分配 ${numTasks} 个任务给 ${numWorkers} 个工作者")
    
    // 分配任务
    for (i in 0..numTasks) {
        let workerIndex = i % numWorkers
        let worker = workers[workerIndex]
        
        spawn {
            worker.doWork(i)
        }
    }
    
    // 等待完成
    sleep(Duration.second * 3)
    
    let endTime = MonoTime.now()
    let duration = endTime - startTime
    
    // 统计结果
    let totalTasks = workers.map { w => w.getTaskCount() }.reduce(0) { acc, count => acc + count }
    
    println("完成任务数: ${totalTasks}")
    println("执行时间: ${duration.toNanosecond() / 1000000} ms")
    println("平均每秒处理: ${(totalTasks * 1000) / (duration.toNanosecond() / 1000000)} 任务")
    
    // 停止所有工作者
    for (worker in workers) {
        worker.stop()
    }
    
    sleep(Duration.millisecond * 200)
}
