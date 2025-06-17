/*
 * Copyright (c) 2024. All rights reserved.
 * ForkJoinDispatcher - Fork-Join池调度器
 * 基于plan10.md设计，实现高性能Fork-Join调度
 */
package cactor.runtime.dispatcher

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, Envelope}
import cactor.foundation.queue.{LockFreeQueue}

/**
 * Fork-Join任务
 */
public struct ForkJoinTask {
    public let envelope: Envelope
    public let actorRef: ActorRef
    public let priority: Priority
    public let timestamp: Int64
    public let taskId: String
    
    public init(envelope: Envelope, actorRef: ActorRef, priority: Priority) {
        this.envelope = envelope
        this.actorRef = actorRef
        this.priority = priority
        this.timestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
        this.taskId = "task-${timestamp}-${actorRef.path.toString()}"
    }
    
    /**
     * 生成任务ID
     */
    private func generateTaskId(): String {
        "task-${timestamp}-${actorRef.path.toString()}"
    }
}

/**
 * Fork-Join工作线程
 */
class ForkJoinWorkerThread {
    private let threadId: Int32
    private let taskQueue: LockFreeQueue<ForkJoinTask>
    private let sharedQueue: LockFreeQueue<ForkJoinTask>
    private let isRunning: AtomicBool
    private let processedTasks: AtomicInt64
    private let executionTime: AtomicInt64
    private let batchSize: Int32
    
    public init(
        threadId: Int32,
        queueSize: Int32,
        sharedQueue: LockFreeQueue<ForkJoinTask>,
        batchSize: Int32
    ) {
        this.threadId = threadId
        this.taskQueue = LockFreeQueue<ForkJoinTask>(Int64(queueSize))
        this.sharedQueue = sharedQueue
        this.isRunning = AtomicBool(false)
        this.processedTasks = AtomicInt64(0)
        this.executionTime = AtomicInt64(0)
        this.batchSize = batchSize
    }
    
    /**
     * 启动工作线程
     */
    public func start(): Unit {
        isRunning.store(true)
        workLoop()
    }
    
    /**
     * 停止工作线程
     */
    public func stop(): Unit {
        isRunning.store(false)
    }
    
    /**
     * 提交任务
     */
    public func submitTask(task: ForkJoinTask): Bool {
        taskQueue.enqueue(task)
    }
    
    /**
     * 获取线程统计信息
     */
    public func getStats(): ForkJoinWorkerStats {
        ForkJoinWorkerStats(
            threadId,
            processedTasks.load(),
            executionTime.load(),
            Int32(taskQueue.size()),
            isRunning.load()
        )
    }
    
    /**
     * 工作循环
     */
    private func workLoop(): Unit {
        while (isRunning.load()) {
            // 批量处理任务以提高性能
            processBatch()
        }
    }
    
    /**
     * 批量处理任务
     */
    private func processBatch(): Unit {
        var processedInBatch = 0
        
        while (Int64(processedInBatch) < Int64(batchSize) && isRunning.load()) {
            // 1. 优先处理本地队列
            let localTask = taskQueue.dequeue()
            match (localTask) {
                case Some(task) =>
                    executeTask(task)
                    processedInBatch += 1
                case None =>
                    // 2. 从共享队列获取任务
                    let sharedTask = sharedQueue.dequeue()
                    match (sharedTask) {
                        case Some(task) =>
                            executeTask(task)
                            processedInBatch += 1
                        case None =>
                            // 没有任务，退出批处理
                            break
                    }
            }
        }
        
        // 如果没有处理任何任务，短暂休眠
        if (processedInBatch == 0) {
            // Thread.yield() 或短暂休眠
        }
    }
    
    /**
     * 执行任务
     */
    private func executeTask(task: ForkJoinTask): Unit {
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        try {
            // 执行Actor消息处理
            task.actorRef.tell(task.envelope.getMessage())
            
            let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
            let duration = endTime - startTime
            
            processedTasks.fetchAdd(1)
            executionTime.fetchAdd(duration)
            
        } catch (e: Exception) {
            println("ForkJoin执行任务时发生错误: ${e}")
        }
    }
}

/**
 * Fork-Join工作线程统计信息
 */
public struct ForkJoinWorkerStats {
    public let threadId: Int32
    public let processedTasks: Int64
    public let executionTime: Int64
    public let queueSize: Int32
    public let isRunning: Bool
    
    public init(
        threadId: Int32,
        processedTasks: Int64,
        executionTime: Int64,
        queueSize: Int32,
        isRunning: Bool
    ) {
        this.threadId = threadId
        this.processedTasks = processedTasks
        this.executionTime = executionTime
        this.queueSize = queueSize
        this.isRunning = isRunning
    }
    
    /**
     * 获取平均执行时间
     */
    public func getAverageExecutionTime(): Float64 {
        if (processedTasks > 0) {
            Float64(executionTime) / Float64(processedTasks)
        } else {
            0.0
        }
    }
}

/**
 * Fork-Join调度器实现
 */
public class ForkJoinDispatcher <: Dispatcher {
    private let dispatcherName: String
    private let config: DispatcherConfig
    private let sharedQueue: LockFreeQueue<ForkJoinTask>
    private let workerThreads: Array<ForkJoinWorkerThread>
    private let isRunning: AtomicBool
    private let totalSubmittedTasks: AtomicInt64
    private let totalErrors: AtomicInt64
    private let roundRobinCounter: AtomicInt32
    
    public init(name: String, config: DispatcherConfig) {
        this.dispatcherName = name
        this.config = config
        this.sharedQueue = LockFreeQueue<ForkJoinTask>(Int64(config.queueSize))
        this.workerThreads = Array<ForkJoinWorkerThread>()
        this.isRunning = AtomicBool(false)
        this.totalSubmittedTasks = AtomicInt64(0)
        this.totalErrors = AtomicInt64(0)
        this.roundRobinCounter = AtomicInt32(0)
        
        initializeWorkerThreads()
    }
    
    public prop name: String {
        get() { dispatcherName }
    }
    
    public prop dispatcherType: DispatcherType {
        get() { DispatcherType.ForkJoin }
    }
    
    public prop isRunning: Bool {
        get() { this.isRunning.load() }
    }
    
    /**
     * 分发消息
     */
    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        dispatchWithPriority(envelope, actorRef, Priority.Normal)
    }
    
    /**
     * 带优先级的分发
     */
    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        if (!isRunning.load()) {
            throw Exception("ForkJoinDispatcher未运行")
        }
        
        let task = ForkJoinTask(envelope, actorRef, priority)
        
        // 根据优先级和负载均衡策略分发任务
        let success = match (priority) {
            case Priority.Critical =>
                // 高优先级任务直接放入共享队列
                sharedQueue.enqueue(task)
            case _ =>
                // 普通任务使用轮询方式分配到工作线程
                let threadIndex = roundRobinCounter.fetchAdd(1) % config.threadCount
                let workerThread = workerThreads[threadIndex]
                
                if (!workerThread.submitTask(task)) {
                    // 工作线程队列满了，放入共享队列
                    sharedQueue.enqueue(task)
                } else {
                    true
                }
        }
        
        if (success) {
            totalSubmittedTasks.fetchAdd(1)
        } else {
            totalErrors.fetchAdd(1)
            throw Exception("无法提交任务，所有队列都已满")
        }
    }
    
    /**
     * 启动调度器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            for (worker in workerThreads) {
                worker.start()
            }
            println("ForkJoinDispatcher '${name}' 已启动，${config.threadCount}个工作线程")
        }
    }
    
    /**
     * 停止调度器
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            for (worker in workerThreads) {
                worker.stop()
            }
            println("ForkJoinDispatcher '${name}' 已停止")
        }
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): DispatcherStats {
        let workerStats = Array<ForkJoinWorkerStats>()
        var totalProcessed = Int64(0)
        var totalExecutionTime = Int64(0)
        
        for (worker in workerThreads) {
            let stats = worker.getStats()
            workerStats.append(stats)
            totalProcessed += stats.processedTasks
            totalExecutionTime += stats.executionTime
        }
        
        let averageLatency = if (totalProcessed > 0) {
            Float64(totalExecutionTime) / Float64(totalProcessed) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
        
        let throughput = calculateThroughput(totalProcessed)
        
        DispatcherStats(
            dispatcherName,
            DispatcherType.ForkJoin,
            config.threadCount,
            config.queueSize,
            totalProcessed,
            averageLatency,
            throughput,
            totalErrors.load()
        )
    }
    
    /**
     * 获取详细的工作线程统计
     */
    public func getWorkerStats(): Array<ForkJoinWorkerStats> {
        let stats = Array<ForkJoinWorkerStats>()
        for (worker in workerThreads) {
            stats.append(worker.getStats())
        }
        stats
    }
    
    /**
     * 初始化工作线程
     */
    private func initializeWorkerThreads(): Unit {
        for (i in 0..config.threadCount) {
            let worker = ForkJoinWorkerThread(
                i,
                config.queueSize / config.threadCount,  // 每个线程的队列大小
                sharedQueue,
                config.batchSize
            )
            workerThreads.append(worker)
        }
    }
    
    /**
     * 计算吞吐量
     */
    private func calculateThroughput(totalProcessed: Int64): Float64 {
        // 简化实现，基于总处理数估算
        // 实际实现中应该基于时间窗口计算真实吞吐量
        Float64(totalProcessed) * 1000.0
    }
}
