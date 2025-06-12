/*
 * 仓颉Actor系统 - 简单演示
 * 展示基本的Actor创建、消息传递和生命周期管理
 */
package examples

import std.sync.*
import std.collection.*
import std.time.*

// 简单的计数器Actor
public class CounterActor <: Actor {
    private let actorName: String
    private var count: Int64 = 0
    private let mutex: ReentrantMutex = ReentrantMutex()
    
    public init(name: String) {
        this.actorName = name
    }
    
    public prop name: String {
        get() { actorName }
    }
    
    public prop description: String {
        get() { "Counter Actor: ${actorName}" }
    }
    
    public func started(): Unit {
        println("${actorName} started with initial count: ${count}")
    }
    
    public func stopping(): Bool {
        println("${actorName} is stopping with final count: ${count}")
        true
    }
    
    public func stopped(): Unit {
        println("${actorName} stopped")
    }
    
    public func increment(): Int64 {
        mutex.lock()
        try {
            count += 1
            println("${actorName} incremented to: ${count}")
            return count
        } finally {
            mutex.unlock()
        }
    }
    
    public func getCount(): Int64 {
        mutex.lock()
        try {
            return count
        } finally {
            mutex.unlock()
        }
    }
}

// 工作者Actor
public class WorkerActor <: Actor {
    private let actorName: String
    private var taskCount: Int64 = 0
    
    public init(name: String) {
        this.actorName = name
    }
    
    public prop name: String {
        get() { actorName }
    }
    
    public prop description: String {
        get() { "Worker Actor: ${actorName}" }
    }
    
    public func started(): Unit {
        println("${actorName} worker started")
    }
    
    public func stopping(): Bool {
        println("${actorName} worker stopping after ${taskCount} tasks")
        true
    }
    
    public func stopped(): Unit {
        println("${actorName} worker stopped")
    }
    
    public func doWork(workId: Int64): Unit {
        taskCount += 1
        println("${actorName} processing work ${workId} (task #${taskCount})")
        // 模拟工作
        sleep(Duration.millisecond * 100)
    }
    
    public func getTaskCount(): Int64 {
        taskCount
    }
}

// 自定义工作消息
public struct WorkMessage <: Message {
    public let workId: Int64
    public let description: String
    
    public init(id: Int64, desc: String) {
        this.workId = id
        this.description = desc
    }
    
    public func messageType(): String {
        "WorkMessage"
    }
    
    public func priority(): Int32 {
        0
    }
}

// 主演示函数
main(): Int64 {
    println("=== 仓颉Actor系统演示 ===")
    
    // 创建Actor运行时
    let runtime = ActorRuntime(100)
    
    try {
        // 创建计数器Actor
        let counter = CounterActor("Counter-1")
        let counterRef = runtime.spawnActor(counter, "counter-1")
        
        // 创建工作者Actor
        let worker = WorkerActor("Worker-1")
        let workerRef = runtime.spawnActor(worker, "worker-1")
        
        println("Created ${runtime.getActorCount()} actors")
        
        // 等待Actor启动
        sleep(Duration.millisecond * 200)
        
        // 测试计数器
        println("\n--- 测试计数器 ---")
        for (i in 1..5) {
            counter.increment()
            sleep(Duration.millisecond * 50)
        }
        
        println("Final counter value: ${counter.getCount()}")
        
        // 测试工作者
        println("\n--- 测试工作者 ---")
        for (i in 1..3) {
            worker.doWork(i)
        }
        
        println("Worker completed ${worker.getTaskCount()} tasks")
        
        // 测试消息传递
        println("\n--- 测试消息传递 ---")
        let pingMsg = PingMessage(123)
        let stopMsg = StopMessage()
        
        counterRef.send(pingMsg)
        workerRef.send(pingMsg)
        
        sleep(Duration.millisecond * 500)
        
        // 检查Actor状态
        println("\n--- Actor状态 ---")
        println("Counter state: ${counterRef.getState()}")
        println("Worker state: ${workerRef.getState()}")
        
        // 停止Actor
        println("\n--- 停止Actor ---")
        counterRef.stop()
        workerRef.stop()
        
        // 等待停止
        sleep(Duration.millisecond * 500)
        
        println("Remaining actors: ${runtime.getActorCount()}")
        
    } catch (e: Exception) {
        println("Error: ${e}")
        return 1
    } finally {
        // 关闭运行时
        runtime.shutdown()
        println("Runtime shutdown complete")
    }
    
    println("=== 演示结束 ===")
    return 0
}

// 并发测试函数
func testConcurrency(): Unit {
    println("\n=== 并发测试 ===")
    
    let runtime = ActorRuntime(50)
    let actors = ArrayList<ActorRef>()
    
    try {
        // 创建多个Actor
        for (i in 1..10) {
            let counter = CounterActor("Counter-${i}")
            let actorRef = runtime.spawnActor(counter, "counter-${i}")
            actors.append(actorRef)
        }
        
        println("Created ${runtime.getActorCount()} concurrent actors")
        
        // 等待启动
        sleep(Duration.millisecond * 300)
        
        // 并发操作
        for (actorRef in actors) {
            spawn {
                for (j in 1..5) {
                    let pingMsg = PingMessage(j)
                    actorRef.send(pingMsg)
                    sleep(Duration.millisecond * 10)
                }
            }
        }
        
        // 等待操作完成
        sleep(Duration.second * 2)
        
        // 停止所有Actor
        for (actorRef in actors) {
            actorRef.stop()
        }
        
        // 等待停止
        sleep(Duration.millisecond * 500)
        
        println("Final actor count: ${runtime.getActorCount()}")
        
    } finally {
        runtime.shutdown()
    }
    
    println("=== 并发测试结束 ===")
}

// 性能测试函数
func performanceTest(): Unit {
    println("\n=== 性能测试 ===")
    
    let runtime = ActorRuntime(1000)
    let numActors = 100
    let actors = ArrayList<ActorRef>()
    
    let startTime = MonoTime.now()
    
    try {
        // 创建大量Actor
        for (i in 1..numActors) {
            let worker = WorkerActor("PerfWorker-${i}")
            let actorRef = runtime.spawnActor(worker, "perf-worker-${i}")
            actors.append(actorRef)
        }
        
        let createTime = MonoTime.now()
        println("Created ${numActors} actors in ${(createTime - startTime).toNanosecond() / 1000000} ms")
        
        // 等待启动
        sleep(Duration.millisecond * 500)
        
        // 发送消息
        for (actorRef in actors) {
            for (j in 1..10) {
                let pingMsg = PingMessage(j)
                actorRef.send(pingMsg)
            }
        }
        
        // 等待处理
        sleep(Duration.second * 3)
        
        // 停止所有Actor
        for (actorRef in actors) {
            actorRef.stop()
        }
        
        // 等待停止
        while (runtime.getActorCount() > 0) {
            sleep(Duration.millisecond * 10)
        }
        
        let endTime = MonoTime.now()
        println("Total test duration: ${(endTime - startTime).toNanosecond() / 1000000} ms")
        
    } finally {
        runtime.shutdown()
    }
    
    println("=== 性能测试结束 ===")
}
