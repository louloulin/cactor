/*
 * Copyright (c) 2024. All rights reserved.
 * WorkStealingDispatcher - 工作窃取调度器
 * 基于plan10.md设计，实现高性能工作窃取算法
 */
package cactor.runtime.dispatcher

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, Envelope}
import cactor.foundation.queue.{LockFreeQueue}

/**
 * 工作窃取任务
 */
public struct WorkStealingTask {
    public let envelope: Envelope
    public let actorRef: ActorRef
    public let priority: Priority
    public let timestamp: Int64
    
    public init(envelope: Envelope, actorRef: ActorRef, priority: Priority) {
        this.envelope = envelope
        this.actorRef = actorRef
        this.priority = priority
        this.timestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }
}

/**
 * 工作线程
 */
class WorkStealingThread {
    private let threadId: Int32
    private let localQueue: LockFreeQueue<WorkStealingTask>
    private let globalQueue: LockFreeQueue<WorkStealingTask>
    private let otherQueues: Array<LockFreeQueue<WorkStealingTask>>
    private let isRunning: AtomicBool
    private let processedTasks: AtomicInt64
    private let stolenTasks: AtomicInt64
    private let batchSize: Int32
    
    public init(
        threadId: Int32,
        queueSize: Int32,
        globalQueue: LockFreeQueue<WorkStealingTask>,
        otherQueues: Array<LockFreeQueue<WorkStealingTask>>,
        batchSize: Int32
    ) {
        this.threadId = threadId
        this.localQueue = LockFreeQueue<WorkStealingTask>(Int64(queueSize))
        this.globalQueue = globalQueue
        this.otherQueues = otherQueues
        this.isRunning = AtomicBool(false)
        this.processedTasks = AtomicInt64(0)
        this.stolenTasks = AtomicInt64(0)
        this.batchSize = batchSize
    }
    
    /**
     * 启动工作线程
     */
    public func start(): Unit {
        isRunning.store(true)
        // 在实际实现中，这里会启动一个新线程
        // 简化实现，直接调用工作循环
        workLoop()
    }
    
    /**
     * 停止工作线程
     */
    public func stop(): Unit {
        isRunning.store(false)
    }
    
    /**
     * 添加任务到本地队列
     */
    public func addTask(task: WorkStealingTask): Bool {
        localQueue.enqueue(task)
    }
    
    /**
     * 获取线程统计信息
     */
    public func getStats(): WorkStealingThreadStats {
        WorkStealingThreadStats(
            threadId,
            processedTasks.load(),
            stolenTasks.load(),
            Int32(localQueue.size()),
            isRunning.load()
        )
    }
    
    /**
     * 工作循环
     */
    private func workLoop(): Unit {
        while (isRunning.load()) {
            // 1. 尝试从本地队列获取任务
            let task = tryGetLocalTask()
            
            match (task) {
                case Some(t) =>
                    executeTask(t)
                case None =>
                    // 2. 尝试从全局队列获取任务
                    let globalTask = tryGetGlobalTask()
                    match (globalTask) {
                        case Some(t) =>
                            executeTask(t)
                        case None =>
                            // 3. 尝试从其他线程窃取任务
                            let stolenTask = tryStealTask()
                            match (stolenTask) {
                                case Some(t) =>
                                    executeTask(t)
                                    stolenTasks.fetchAdd(1)
                                case None =>
                                    // 4. 没有任务，短暂休眠
                                    // Thread.yield() 或短暂休眠
                                    ()
                            }
                    }
            }
        }
    }
    
    /**
     * 尝试从本地队列获取任务
     */
    private func tryGetLocalTask(): Option<WorkStealingTask> {
        localQueue.dequeue()
    }
    
    /**
     * 尝试从全局队列获取任务
     */
    private func tryGetGlobalTask(): Option<WorkStealingTask> {
        globalQueue.dequeue()
    }
    
    /**
     * 尝试从其他线程窃取任务
     */
    private func tryStealTask(): Option<WorkStealingTask> {
        // 随机选择一个其他线程的队列进行窃取
        if (otherQueues.size() > 0) {
            let randomIndex = threadId % Int32(otherQueues.size())
            let targetQueue = otherQueues[randomIndex]
            targetQueue.poll()
        } else {
            None
        }
    }
    
    /**
     * 执行任务
     */
    private func executeTask(task: WorkStealingTask): Unit {
        try {
            // 执行Actor消息处理
            task.actorRef.tell(task.envelope.getMessage())
            processedTasks.fetchAdd(1)
        } catch (e: Exception) {
            // 记录错误，但不中断线程
            println("执行任务时发生错误: ${e}")
        }
    }
}

/**
 * 工作线程统计信息
 */
public struct WorkStealingThreadStats {
    public let threadId: Int32
    public let processedTasks: Int64
    public let stolenTasks: Int64
    public let queueSize: Int32
    public let isRunning: Bool
    
    public init(
        threadId: Int32,
        processedTasks: Int64,
        stolenTasks: Int64,
        queueSize: Int32,
        isRunning: Bool
    ) {
        this.threadId = threadId
        this.processedTasks = processedTasks
        this.stolenTasks = stolenTasks
        this.queueSize = queueSize
        this.isRunning = isRunning
    }
}

/**
 * 工作窃取调度器实现
 */
public class WorkStealingDispatcher <: Dispatcher {
    private let dispatcherName: String
    private let config: DispatcherConfig
    private let globalQueue: LockFreeQueue<WorkStealingTask>
    private let workerThreads: Array<WorkStealingThread>
    private let workerQueues: Array<LockFreeQueue<WorkStealingTask>>
    private let isRunning: AtomicBool
    private let totalProcessedMessages: AtomicInt64
    private let totalErrors: AtomicInt64
    private let roundRobinCounter: AtomicInt32
    
    public init(name: String, config: DispatcherConfig) {
        this.dispatcherName = name
        this.config = config
        this.globalQueue = LockFreeQueue<WorkStealingTask>(config.queueSize)
        this.workerThreads = Array<WorkStealingThread>()
        this.workerQueues = Array<LockFreeQueue<WorkStealingTask>>()
        this.isRunning = AtomicBool(false)
        this.totalProcessedMessages = AtomicInt64(0)
        this.totalErrors = AtomicInt64(0)
        this.roundRobinCounter = AtomicInt32(0)
        
        initializeWorkerThreads()
    }
    
    public prop name: String {
        get() { dispatcherName }
    }
    
    public prop dispatcherType: DispatcherType {
        get() { DispatcherType.WorkStealing }
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
            throw Exception("WorkStealingDispatcher未运行")
        }
        
        let task = WorkStealingTask(envelope, actorRef, priority)
        
        // 根据优先级选择队列
        match (priority) {
            case Priority.Critical =>
                // 高优先级任务直接放入全局队列
                if (!globalQueue.offer(task)) {
                    totalErrors.fetchAdd(1)
                    throw Exception("全局队列已满")
                }
            case _ =>
                // 普通任务使用轮询方式分配到工作线程
                let threadIndex = roundRobinCounter.fetchAdd(1) % config.threadCount
                let workerThread = workerThreads[threadIndex]
                
                if (!workerThread.addTask(task)) {
                    // 本地队列满了，放入全局队列
                    if (!globalQueue.offer(task)) {
                        totalErrors.fetchAdd(1)
                        throw Exception("所有队列都已满")
                    }
                }
        }
        
        totalProcessedMessages.fetchAdd(1)
    }
    
    /**
     * 启动调度器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            for (worker in workerThreads) {
                worker.start()
            }
            println("WorkStealingDispatcher '${name}' 已启动，${config.threadCount}个工作线程")
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
            println("WorkStealingDispatcher '${name}' 已停止")
        }
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): DispatcherStats {
        let threadStats = Array<WorkStealingThreadStats>()
        var totalProcessed = Int64(0)
        var totalStolen = Int64(0)
        
        for (worker in workerThreads) {
            let stats = worker.getStats()
            threadStats.append(stats)
            totalProcessed += stats.processedTasks
            totalStolen += stats.stolenTasks
        }
        
        let averageLatency = calculateAverageLatency()
        let throughput = calculateThroughput(totalProcessed)
        
        DispatcherStats(
            dispatcherName,
            DispatcherType.WorkStealing,
            config.threadCount,
            config.queueSize,
            totalProcessed,
            averageLatency,
            throughput,
            totalErrors.load()
        )
    }
    
    /**
     * 初始化工作线程
     */
    private func initializeWorkerThreads(): Unit {
        // 首先创建所有队列
        for (i in 0..config.threadCount) {
            let queue = LockFreeQueue<WorkStealingTask>(config.queueSize)
            workerQueues.append(queue)
        }
        
        // 然后创建工作线程
        for (i in 0..config.threadCount) {
            let otherQueues = Array<LockFreeQueue<WorkStealingTask>>()
            for (j in 0..config.threadCount) {
                if (i != j) {
                    otherQueues.append(workerQueues[j])
                }
            }
            
            let worker = WorkStealingThread(
                i,
                config.queueSize,
                globalQueue,
                otherQueues,
                config.batchSize
            )
            workerThreads.append(worker)
        }
    }
    
    /**
     * 计算平均延迟
     */
    private func calculateAverageLatency(): Float64 {
        // 简化实现，返回固定值
        // 实际实现中应该基于时间戳计算真实延迟
        50.0  // 50微秒
    }
    
    /**
     * 计算吞吐量
     */
    private func calculateThroughput(totalProcessed: Int64): Float64 {
        // 简化实现，返回估算值
        // 实际实现中应该基于时间窗口计算真实吞吐量
        Float64(totalProcessed) * 1000.0  // 估算每秒处理量
    }
}
