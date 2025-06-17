/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10企业级Actor系统示例
 * 展示plan10.md中实现的企业级功能
 */
package cactor.examples.plan10_enterprise_example

import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}
import cactor.core.context.{ActorContext}
import cactor.integration.enterprise.{EnterpriseActorSystem, EnterpriseActorSystemConfig, SystemMode, PerformanceMode}
import cactor.runtime.events.{SimpleEventListener, SimpleActorLifecycleEvent, ConsoleEventListener, StatsEventListener}

/**
 * 企业级工作Actor
 * 模拟真实的业务处理场景
 */
class EnterpriseWorkerActor <: Actor {
    private var processedTasks: Int32
    private var totalProcessingTime: Int64
    private let workerId: String
    
    public init(workerId: String) {
        this.workerId = workerId
        this.processedTasks = 0
        this.totalProcessingTime = 0
    }
    
    public prop name: String {
        get() { "enterprise-worker-${workerId}" }
    }
    
    public prop description: String {
        get() { "Enterprise Worker Actor for business processing" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        match (message) {
            case task: BusinessTask =>
                processBusinessTask(task)
                MessageResult.Handled
            case msg: StringMessage =>
                processStringMessage(msg.getContent())
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        totalProcessingTime += (endTime - startTime)
        processedTasks += 1
        
        MessageResult.Handled
    }
    
    private func processBusinessTask(task: BusinessTask): Unit {
        // 模拟业务处理
        Thread.sleep(Duration.microsecond * Int64(task.complexity * 10))
        println("Worker ${workerId} processed task: ${task.taskId} (complexity: ${task.complexity})")
    }
    
    private func processStringMessage(content: String): Unit {
        // 模拟字符串消息处理
        Thread.sleep(Duration.microsecond * 5)
        println("Worker ${workerId} processed message: ${content}")
    }
    
    public func getStats(): WorkerStats {
        WorkerStats(workerId, processedTasks, totalProcessingTime)
    }
}

/**
 * 企业级管理Actor
 * 负责协调和管理工作Actor
 */
class EnterpriseManagerActor <: Actor {
    private let workers: Array<ActorRef>
    private var taskCounter: Int32
    private var distributedTasks: Int32
    
    public init() {
        this.workers = Array<ActorRef>()
        this.taskCounter = 0
        this.distributedTasks = 0
    }
    
    public prop name: String {
        get() { "enterprise-manager" }
    }
    
    public prop description: String {
        get() { "Enterprise Manager Actor for coordinating workers" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case cmd: RegisterWorker =>
                registerWorker(cmd.worker)
                MessageResult.Handled
            case task: BusinessTask =>
                distributeTask(task)
                MessageResult.Handled
            case cmd: GetManagerStats =>
                // 这里可以发送统计信息给发送者
                println("Manager stats: ${distributedTasks} tasks distributed to ${workers.size()} workers")
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
    }
    
    private func registerWorker(worker: ActorRef): Unit {
        workers.append(worker)
        println("Manager registered worker: ${worker.path.toString()}")
    }
    
    private func distributeTask(task: BusinessTask): Unit {
        if (workers.size() > 0) {
            let workerIndex = distributedTasks % Int32(workers.size())
            let selectedWorker = workers[workerIndex]
            selectedWorker.tell(task)
            distributedTasks += 1
            println("Manager distributed task ${task.taskId} to worker ${workerIndex}")
        } else {
            println("Manager: No workers available for task ${task.taskId}")
        }
    }
}

/**
 * 业务任务消息
 */
public struct BusinessTask <: Message {
    public let taskId: String
    public let complexity: Int32
    public let priority: Int32
    
    public init(taskId: String, complexity: Int32, priority: Int32) {
        this.taskId = taskId
        this.complexity = complexity
        this.priority = priority
    }
}

/**
 * 注册工作Actor命令
 */
public struct RegisterWorker <: Message {
    public let worker: ActorRef
    
    public init(worker: ActorRef) {
        this.worker = worker
    }
}

/**
 * 获取管理器统计命令
 */
public struct GetManagerStats <: Message {
    public init() {}
}

/**
 * 工作Actor统计信息
 */
public struct WorkerStats {
    public let workerId: String
    public let processedTasks: Int32
    public let totalProcessingTime: Int64
    
    public init(workerId: String, processedTasks: Int32, totalProcessingTime: Int64) {
        this.workerId = workerId
        this.processedTasks = processedTasks
        this.totalProcessingTime = totalProcessingTime
    }
    
    public func printStats(): Unit {
        let avgTime = if (processedTasks > 0) {
            Float64(totalProcessingTime) / Float64(processedTasks)
        } else {
            0.0
        }
        println("Worker ${workerId}: ${processedTasks} tasks, avg time: ${avgTime}ms")
    }
}

/**
 * 企业级事件监听器
 */
class EnterpriseEventListener <: SimpleEventListener {
    private var eventCount: Int32
    
    public init() {
        this.eventCount = 0
    }
    
    public func onEvent(event: SimpleActorLifecycleEvent): Unit {
        eventCount += 1
        let timeStr = DateTime.fromUnixTimeStamp(UnixTimeStamp.fromMilliseconds(event.timestamp / 1000000)).toString()
        println("🔔 [ENTERPRISE] ${timeStr} ${event.eventType}: ${event.actorRef.path.toString()}")
    }
    
    public func getEventCount(): Int32 {
        eventCount
    }
}

/**
 * 主函数 - 企业级Actor系统演示
 */
main(): Int64 {
    println("🏢 Plan10企业级Actor系统演示")
    println("========================================")
    
    // 创建企业级Actor系统
    let config = EnterpriseActorSystemConfig.createProduction()
    let system = EnterpriseActorSystem("enterprise-demo", config)
    
    // 启动系统
    system.start()
    
    // 获取运行时组件
    let runtime = system.getRuntime()
    let eventBus = runtime.getEventBus()
    let metrics = runtime.getSystemMetrics()
    
    // 添加事件监听器
    let enterpriseListener = EnterpriseEventListener()
    let consoleListener = ConsoleEventListener("[DEMO]")
    let statsListener = StatsEventListener()
    
    eventBus.subscribe(enterpriseListener)
    eventBus.subscribe(consoleListener)
    eventBus.subscribe(statsListener)
    
    println("📊 事件监听器已注册")
    
    // 创建管理Actor
    let managerFactory = SimpleActorFactory<Actor>({ => EnterpriseManagerActor() })
    let managerProps = Props<Actor>(managerFactory)
    let manager = system.actorOf(managerProps, "enterprise-manager")
    
    println("👔 企业管理Actor已创建")
    
    // 创建工作Actor
    let workerCount = 5
    let workers = Array<ActorRef>()
    
    for (i in 0..workerCount) {
        let workerId = "worker-${i}"
        let workerFactory = SimpleActorFactory<Actor>({ => EnterpriseWorkerActor(workerId) })
        let workerProps = Props<Actor>(workerFactory)
        let worker = system.actorOf(workerProps, workerId)
        workers.append(worker)
        
        // 注册工作Actor到管理Actor
        manager.tell(RegisterWorker(worker))
    }
    
    println("👷 ${workerCount}个工作Actor已创建并注册")
    
    // 生成业务任务
    let taskCount = 20
    println("📋 开始分发${taskCount}个业务任务...")
    
    for (i in 0..taskCount) {
        let taskId = "task-${i}"
        let complexity = (i % 5) + 1  // 复杂度1-5
        let priority = (i % 3) + 1    // 优先级1-3
        let task = BusinessTask(taskId, complexity, priority)
        
        manager.tell(task)
        
        // 添加一些延迟模拟真实场景
        Thread.sleep(Duration.millisecond * 10)
    }
    
    println("⏳ 等待任务处理完成...")
    Thread.sleep(Duration.second * 2)
    
    // 获取管理器统计
    manager.tell(GetManagerStats())
    
    // 显示系统统计信息
    println("\n📈 系统性能统计:")
    let systemStats = system.getSystemStats()
    systemStats.printEnterpriseReport()
    
    // 显示运行时统计
    println("\n🔧 运行时统计:")
    let runtimeStats = runtime.getRuntimeStats()
    runtimeStats.printReport()
    
    // 显示事件统计
    println("\n🔔 事件统计:")
    println("企业监听器接收事件: ${enterpriseListener.getEventCount()}")
    println("总事件数: ${eventBus.getEventCount()}")
    statsListener.printStats()
    
    // 显示性能指标
    println("\n⚡ 性能指标:")
    let perfMetrics = metrics.getPerformanceMetrics()
    println("消息吞吐量: ${perfMetrics.messagesThroughput} msg/s")
    println("平均延迟: ${perfMetrics.averageLatency} μs")
    println("错误率: ${perfMetrics.errorRate}%")
    
    // 显示自定义指标
    println("\n📊 自定义指标:")
    metrics.incrementCustomCounter("demo_tasks", Int64(taskCount))
    metrics.setCustomGauge("demo_workers", Float64(workerCount))
    
    let customMetrics = metrics.getCustomMetrics()
    let customGauges = metrics.getCustomGauges()
    
    for ((name, counter) in customMetrics) {
        println("${name}: ${counter.load()}")
    }
    
    for ((name, value) in customGauges) {
        println("${name}: ${value}")
    }
    
    println("\n🎯 演示完成，准备关闭系统...")
    Thread.sleep(Duration.second * 1)
    
    // 关闭系统
    system.shutdown()
    
    println("✅ Plan10企业级Actor系统演示成功完成!")
    println("========================================")
    
    return 0
}
