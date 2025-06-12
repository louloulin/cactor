/*
 * 仓颉Actor系统 - 简单测试
 * 测试基础的并发和同步功能
 */
package tests

import std.sync.*
import std.collection.*
import std.time.*

// 简单的工作者类
public class SimpleWorker {
    private let workerName: String
    private var taskCount: AtomicInt64
    private let isRunning: AtomicBool
    
    public init(name: String) {
        this.workerName = name
        this.taskCount = AtomicInt64(0)
        this.isRunning = AtomicBool(false)
    }
    
    public func getName(): String {
        workerName
    }
    
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("${workerName} started")
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("${workerName} stopped after ${taskCount.load()} tasks")
        }
    }
    
    public func isActive(): Bool {
        isRunning.load()
    }
    
    public func doWork(workId: Int64): Unit {
        if (isRunning.load()) {
            taskCount.fetchAdd(1)
            println("${workerName} processing work ${workId} (total: ${taskCount.load()})")
            // 模拟工作
            sleep(Duration.millisecond * 50)
        }
    }
    
    public func getTaskCount(): Int64 {
        taskCount.load()
    }
}

// 简单的管理器类
public class WorkerManager {
    private let workers: ArrayList<SimpleWorker>
    private let workersMutex: ReentrantMutex
    private let isRunning: AtomicBool
    
    public init() {
        this.workers = ArrayList<SimpleWorker>()
        this.workersMutex = ReentrantMutex()
        this.isRunning = AtomicBool(false)
    }
    
    public func addWorker(worker: SimpleWorker): Unit {
        workersMutex.lock()
        try {
            workers.append(worker)
            println("Added worker: ${worker.getName()}")
        } finally {
            workersMutex.unlock()
        }
    }
    
    public func startAll(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            workersMutex.lock()
            try {
                for (worker in workers) {
                    worker.start()
                }
                println("Started ${workers.size} workers")
            } finally {
                workersMutex.unlock()
            }
        }
    }
    
    public func stopAll(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            workersMutex.lock()
            try {
                for (worker in workers) {
                    worker.stop()
                }
                println("Stopped all workers")
            } finally {
                workersMutex.unlock()
            }
        }
    }
    
    public func assignWork(workId: Int64): Unit {
        if (isRunning.load()) {
            workersMutex.lock()
            try {
                if (!workers.isEmpty()) {
                    let workerIndex = workId % workers.size
                    let worker = workers[workerIndex]
                    worker.doWork(workId)
                }
            } finally {
                workersMutex.unlock()
            }
        }
    }
    
    public func getWorkerCount(): Int64 {
        workersMutex.lock()
        try {
            return workers.size
        } finally {
            workersMutex.unlock()
        }
    }
    
    public func getTotalTasks(): Int64 {
        workersMutex.lock()
        try {
            var total: Int64 = 0
            for (worker in workers) {
                total += worker.getTaskCount()
            }
            return total
        } finally {
            workersMutex.unlock()
        }
    }
}

// 测试函数
func testBasicWorker(): Bool {
    println("=== 测试基础Worker功能 ===")
    
    let worker = SimpleWorker("TestWorker")
    
    // 测试启动
    worker.start()
    if (!worker.isActive()) {
        println("✗ Worker启动失败")
        return false
    }
    
    // 测试工作
    worker.doWork(1)
    worker.doWork(2)
    worker.doWork(3)
    
    if (worker.getTaskCount() != 3) {
        println("✗ 任务计数错误: ${worker.getTaskCount()}")
        return false
    }
    
    // 测试停止
    worker.stop()
    if (worker.isActive()) {
        println("✗ Worker停止失败")
        return false
    }
    
    println("✓ 基础Worker功能测试通过")
    return true
}

func testWorkerManager(): Bool {
    println("\n=== 测试WorkerManager ===")
    
    let manager = WorkerManager()
    
    // 添加多个worker
    for (i in 0..3) {
        let worker = SimpleWorker("Worker-${i}")
        manager.addWorker(worker)
    }
    
    if (manager.getWorkerCount() != 3) {
        println("✗ Worker数量错误: ${manager.getWorkerCount()}")
        return false
    }
    
    // 启动所有worker
    manager.startAll()
    
    // 分配工作
    for (i in 0..9) {
        manager.assignWork(i)
    }

    // 等待工作完成
    sleep(Duration.millisecond * 500)

    let totalTasks = manager.getTotalTasks()
    if (totalTasks != 9) {
        println("✗ 总任务数错误: ${totalTasks}")
        return false
    }
    
    // 停止所有worker
    manager.stopAll()
    
    println("✓ WorkerManager测试通过")
    return true
}

func testConcurrentWorkers(): Bool {
    println("\n=== 测试并发Worker ===")
    
    let manager = WorkerManager()
    
    // 添加worker
    for (i in 0..5) {
        let worker = SimpleWorker("ConcurrentWorker-${i}")
        manager.addWorker(worker)
    }
    
    manager.startAll()
    
    // 并发分配工作
    for (i in 0..20) {
        spawn {
            manager.assignWork(i)
        }
    }
    
    // 等待所有工作完成
    sleep(Duration.second * 2)
    
    let totalTasks = manager.getTotalTasks()
    if (totalTasks != 20) {
        println("✗ 并发任务数错误: ${totalTasks}")
        return false
    }
    
    manager.stopAll()
    
    println("✓ 并发Worker测试通过")
    return true
}

func testAtomicOperations(): Bool {
    println("\n=== 测试原子操作 ===")
    
    let counter = AtomicInt64(0)
    let numThreads = 10
    let incrementsPerThread = 100
    
    // 并发增加计数器
    for (i in 0..numThreads) {
        spawn {
            for (j in 0..incrementsPerThread) {
                counter.fetchAdd(1)
            }
        }
    }
    
    // 等待所有线程完成
    sleep(Duration.second)
    
    let expectedValue = numThreads * incrementsPerThread
    let actualValue = counter.load()
    
    if (actualValue == expectedValue) {
        println("✓ 原子操作测试通过: ${actualValue}")
        return true
    } else {
        println("✗ 原子操作测试失败: 期望 ${expectedValue}, 实际 ${actualValue}")
        return false
    }
}

// 主测试函数
main(): Int64 {
    println("开始仓颉并发系统测试...")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testBasicWorker()
    allTestsPassed = allTestsPassed && testWorkerManager()
    allTestsPassed = allTestsPassed && testConcurrentWorkers()
    allTestsPassed = allTestsPassed && testAtomicOperations()
    
    if (allTestsPassed) {
        println("\n🎉 所有测试通过！")
        return 0
    } else {
        println("\n❌ 部分测试失败")
        return 1
    }
}
