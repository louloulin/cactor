/*
 * Copyright (c) 2024. All rights reserved.
 * PinnedDispatcher - 固定线程调度器
 * 基于plan10.md设计，为特定Actor提供固定线程执行
 */
package cactor.runtime.dispatcher

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, Envelope}
import cactor.foundation.queue.{LockFreeQueue}

/**
 * 固定线程任务
 */
public struct PinnedTask {
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
 * 固定线程执行器
 */
class PinnedThreadExecutor {
    private let threadId: Int32
    private let taskQueue: LockFreeQueue<PinnedTask>
    private let isRunning: AtomicBool
    private let processedTasks: AtomicInt64
    private let totalLatency: AtomicInt64
    private let cpuAffinity: Option<Int32>
    
    public init(threadId: Int32, queueSize: Int32, cpuAffinity: Option<Int32>) {
        this.threadId = threadId
        this.taskQueue = LockFreeQueue<PinnedTask>(queueSize)
        this.isRunning = AtomicBool(false)
        this.processedTasks = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
        this.cpuAffinity = cpuAffinity
    }
    
    /**
     * 启动线程执行器
     */
    public func start(): Unit {
        isRunning.store(true)
        
        // 设置CPU亲和性（简化实现）
        match (cpuAffinity) {
            case Some(cpu) =>
                println("线程${threadId}绑定到CPU${cpu}")
            case None => ()
        }
        
        workLoop()
    }
    
    /**
     * 停止线程执行器
     */
    public func stop(): Unit {
        isRunning.store(false)
    }
    
    /**
     * 提交任务
     */
    public func submitTask(task: PinnedTask): Bool {
        taskQueue.offer(task)
    }
    
    /**
     * 获取队列大小
     */
    public func getQueueSize(): Int32 {
        taskQueue.size()
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): PinnedThreadStats {
        PinnedThreadStats(
            threadId,
            processedTasks.load(),
            totalLatency.load(),
            taskQueue.size(),
            isRunning.load(),
            cpuAffinity
        )
    }
    
    /**
     * 工作循环
     */
    private func workLoop(): Unit {
        while (isRunning.load()) {
            let task = taskQueue.poll()
            match (task) {
                case Some(t) =>
                    executeTask(t)
                case None =>
                    // 没有任务，短暂休眠
                    // Thread.yield()
                    ()
            }
        }
    }
    
    /**
     * 执行任务
     */
    private func executeTask(task: PinnedTask): Unit {
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        try {
            // 执行Actor消息处理
            task.actorRef.tell(task.envelope.getMessage())
            
            let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
            let latency = endTime - startTime
            
            processedTasks.fetchAdd(1)
            totalLatency.fetchAdd(latency)
            
        } catch (e: Exception) {
            println("固定线程执行任务时发生错误: ${e}")
        }
    }
}

/**
 * 固定线程统计信息
 */
public struct PinnedThreadStats {
    public let threadId: Int32
    public let processedTasks: Int64
    public let totalLatency: Int64
    public let queueSize: Int32
    public let isRunning: Bool
    public let cpuAffinity: Option<Int32>
    
    public init(
        threadId: Int32,
        processedTasks: Int64,
        totalLatency: Int64,
        queueSize: Int32,
        isRunning: Bool,
        cpuAffinity: Option<Int32>
    ) {
        this.threadId = threadId
        this.processedTasks = processedTasks
        this.totalLatency = totalLatency
        this.queueSize = queueSize
        this.isRunning = isRunning
        this.cpuAffinity = cpuAffinity
    }
    
    /**
     * 获取平均延迟
     */
    public func getAverageLatency(): Float64 {
        if (processedTasks > 0) {
            Float64(totalLatency) / Float64(processedTasks) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
    }
}

/**
 * 固定线程调度器实现
 */
public class PinnedDispatcher <: Dispatcher {
    private let dispatcherName: String
    private let config: DispatcherConfig
    private let threadExecutors: Array<PinnedThreadExecutor>
    private let actorToThreadMap: HashMap<String, Int32>
    private let isRunning: AtomicBool
    private let totalSubmittedTasks: AtomicInt64
    private let totalErrors: AtomicInt64
    private let nextThreadIndex: AtomicInt32
    
    public init(name: String, config: DispatcherConfig) {
        this.dispatcherName = name
        this.config = config
        this.threadExecutors = Array<PinnedThreadExecutor>()
        this.actorToThreadMap = HashMap<String, Int32>()
        this.isRunning = AtomicBool(false)
        this.totalSubmittedTasks = AtomicInt64(0)
        this.totalErrors = AtomicInt64(0)
        this.nextThreadIndex = AtomicInt32(0)
        
        initializeThreadExecutors()
    }
    
    public prop name: String {
        get() { dispatcherName }
    }
    
    public prop dispatcherType: DispatcherType {
        get() { DispatcherType.Pinned }
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
            throw Exception("PinnedDispatcher未运行")
        }
        
        let task = PinnedTask(envelope, actorRef, priority)
        let actorPath = actorRef.path.toString()
        
        // 为Actor分配固定线程
        let threadIndex = getOrAssignThread(actorPath)
        let executor = threadExecutors[threadIndex]
        
        if (executor.submitTask(task)) {
            totalSubmittedTasks.fetchAdd(1)
        } else {
            totalErrors.fetchAdd(1)
            throw Exception("固定线程队列已满")
        }
    }
    
    /**
     * 启动调度器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            for (executor in threadExecutors) {
                executor.start()
            }
            println("PinnedDispatcher '${name}' 已启动，${config.threadCount}个固定线程")
        }
    }
    
    /**
     * 停止调度器
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            for (executor in threadExecutors) {
                executor.stop()
            }
            actorToThreadMap.clear()
            println("PinnedDispatcher '${name}' 已停止")
        }
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): DispatcherStats {
        let threadStats = Array<PinnedThreadStats>()
        var totalProcessed = Int64(0)
        var totalLatency = Int64(0)
        
        for (executor in threadExecutors) {
            let stats = executor.getStats()
            threadStats.append(stats)
            totalProcessed += stats.processedTasks
            totalLatency += stats.totalLatency
        }
        
        let averageLatency = if (totalProcessed > 0) {
            Float64(totalLatency) / Float64(totalProcessed) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
        
        let throughput = calculateThroughput(totalProcessed)
        
        DispatcherStats(
            dispatcherName,
            DispatcherType.Pinned,
            config.threadCount,
            config.queueSize,
            totalProcessed,
            averageLatency,
            throughput,
            totalErrors.load()
        )
    }
    
    /**
     * 获取详细的线程统计
     */
    public func getThreadStats(): Array<PinnedThreadStats> {
        let stats = Array<PinnedThreadStats>()
        for (executor in threadExecutors) {
            stats.append(executor.getStats())
        }
        stats
    }
    
    /**
     * 获取Actor到线程的映射
     */
    public func getActorThreadMapping(): HashMap<String, Int32> {
        actorToThreadMap
    }
    
    /**
     * 初始化线程执行器
     */
    private func initializeThreadExecutors(): Unit {
        for (i in 0..config.threadCount) {
            let cpuAffinity = match (config.cpuAffinity) {
                case Some(affinities) =>
                    if (i < affinities.size()) {
                        Some(affinities[i])
                    } else {
                        None
                    }
                case None => None
            }
            
            let executor = PinnedThreadExecutor(
                i,
                config.queueSize / config.threadCount,
                cpuAffinity
            )
            threadExecutors.append(executor)
        }
    }
    
    /**
     * 为Actor获取或分配线程
     */
    private func getOrAssignThread(actorPath: String): Int32 {
        match (actorToThreadMap.get(actorPath)) {
            case Some(threadIndex) =>
                threadIndex
            case None =>
                // 为新Actor分配线程
                let threadIndex = nextThreadIndex.fetchAdd(1) % config.threadCount
                actorToThreadMap.put(actorPath, threadIndex)
                threadIndex
        }
    }
    
    /**
     * 计算吞吐量
     */
    private func calculateThroughput(totalProcessed: Int64): Float64 {
        // 简化实现，基于总处理数估算
        Float64(totalProcessed) * 1000.0
    }
}
