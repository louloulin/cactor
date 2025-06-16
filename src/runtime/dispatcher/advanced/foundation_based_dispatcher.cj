/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 基于现有组件的高级调度器系统
 * 基于plan3.md Phase 3设计，利用现有的高性能Dispatcher实现
 */
package cactor.runtime.dispatcher.advanced

import std.time.*
import std.collection.*
import cactor.core.message.{Message, Envelope}
import cactor.core.actor.{Actor, ActorRef}
import cactor.runtime.dispatcher.work_stealing.WorkStealingDispatcher
import cactor.runtime.dispatcher.optimized.OptimizedWorkStealingDispatcher
import cactor.runtime.dispatcher.batch_processing.BatchProcessor
import cactor.core.config.{DispatcherConfig, DispatcherType}

/**
 * 高级消息调度器接口
 * 基于现有Dispatcher组件的统一接口
 */
public interface AdvancedMessageDispatcher {
    /**
     * 分发消息到Actor
     */
    func dispatch(envelope: Envelope, actorRef: ActorRef): Unit
    
    /**
     * 带优先级的消息分发
     */
    func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit
    
    /**
     * 批量分发消息
     */
    func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit
    
    /**
     * 启动调度器
     */
    func start(): Unit
    
    /**
     * 停止调度器
     */
    func stop(): Unit
    
    /**
     * 获取调度器配置
     */
    func getConfig(): DispatcherConfig
    
    /**
     * 获取性能统计
     */
    func getPerformanceStats(): String
    
    /**
     * 检查调度器是否运行中
     */
    func isRunning(): Bool
}

/**
 * 优先级枚举
 */
public enum Priority {
    | Critical    // 关键优先级
    | High        // 高优先级
    | Normal      // 普通优先级
    | Low         // 低优先级
}

/**
 * 基于WorkStealingDispatcher的高级调度器
 * 利用现有的工作窃取调度器实现
 */
public class AdvancedWorkStealingDispatcher <: AdvancedMessageDispatcher {
    private let workStealingDispatcher: WorkStealingDispatcher
    private let config: DispatcherConfig
    private let name: String
    private let isActive: AtomicBool
    
    public init(config: DispatcherConfig) {
        this.config = config
        this.name = config.name
        this.isActive = AtomicBool(false)
        
        // 基于配置创建WorkStealingDispatcher
        let workerCount = if (config.executorConfig.corePoolSize <= 0) { 4 } else { config.executorConfig.corePoolSize }
        this.workStealingDispatcher = WorkStealingDispatcher(workerCount)
    }
    
    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        if (!isActive.load()) {
            throw Exception("Dispatcher ${name} is not running")
        }
        
        workStealingDispatcher.dispatch(envelope, actorRef)
    }
    
    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        if (!isActive.load()) {
            throw Exception("Dispatcher ${name} is not running")
        }
        
        // 将Priority转换为WorkStealingDispatcher的Priority
        let wsPriority = match (priority) {
            case Priority.Critical => cactor.runtime.dispatcher.work_stealing.Priority.Critical
            case Priority.High => cactor.runtime.dispatcher.work_stealing.Priority.High
            case Priority.Normal => cactor.runtime.dispatcher.work_stealing.Priority.Normal
            case Priority.Low => cactor.runtime.dispatcher.work_stealing.Priority.Low
        }
        
        workStealingDispatcher.dispatchWithPriority(envelope, actorRef, wsPriority)
    }
    
    public func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit {
        if (!isActive.load()) {
            throw Exception("Dispatcher ${name} is not running")
        }
        
        // 批量分发，利用WorkStealingDispatcher的高性能
        let minSize = min(Int64(envelopes.size), Int64(actorRefs.size))
        for (i in 0..minSize) {
            workStealingDispatcher.dispatch(envelopes[i], actorRefs[i])
        }
    }
    
    public func start(): Unit {
        if (isActive.compareAndSwap(false, true)) {
            workStealingDispatcher.start()
        }
    }
    
    public func stop(): Unit {
        if (isActive.compareAndSwap(true, false)) {
            workStealingDispatcher.stop()
        }
    }
    
    public func getConfig(): DispatcherConfig {
        config
    }
    
    public func getPerformanceStats(): String {
        let stats = workStealingDispatcher.getStats()
        "AdvancedWorkStealingDispatcher[${name}] - ${stats}"
    }
    
    public func isRunning(): Bool {
        isActive.load()
    }
}

/**
 * 基于OptimizedWorkStealingDispatcher的超高性能调度器
 * 利用现有的优化工作窃取调度器实现
 */
public class UltraHighPerformanceDispatcher <: AdvancedMessageDispatcher {
    private let optimizedDispatcher: OptimizedWorkStealingDispatcher
    private let config: DispatcherConfig
    private let name: String
    private let isActive: AtomicBool
    
    public init(config: DispatcherConfig) {
        this.config = config
        this.name = config.name
        this.isActive = AtomicBool(false)
        
        // 基于配置创建OptimizedWorkStealingDispatcher
        let workerCount = if (config.executorConfig.corePoolSize <= 0) { 8 } else { config.executorConfig.corePoolSize }
        this.optimizedDispatcher = OptimizedWorkStealingDispatcher(workerCount)
    }
    
    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        if (!isActive.load()) {
            throw Exception("UltraHighPerformanceDispatcher ${name} is not running")
        }
        
        // 使用优化的简单分发
        optimizedDispatcher.dispatchSimple(envelope)
    }
    
    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        if (!isActive.load()) {
            throw Exception("UltraHighPerformanceDispatcher ${name} is not running")
        }
        
        // 将Priority转换为OptimizedWorkStealingDispatcher的Priority
        let optPriority = match (priority) {
            case Priority.Critical => cactor.runtime.dispatcher.optimized.Priority.Critical
            case Priority.High => cactor.runtime.dispatcher.optimized.Priority.High
            case Priority.Normal => cactor.runtime.dispatcher.optimized.Priority.Normal
            case Priority.Low => cactor.runtime.dispatcher.optimized.Priority.Low
        }
        
        optimizedDispatcher.dispatchWithPriority(envelope, actorRef, optPriority)
    }
    
    public func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit {
        if (!isActive.load()) {
            throw Exception("UltraHighPerformanceDispatcher ${name} is not running")
        }
        
        // 超高性能批量分发
        let minSize = min(Int64(envelopes.size), Int64(actorRefs.size))
        for (i in 0..minSize) {
            optimizedDispatcher.dispatchSimple(envelopes[i])
        }
    }
    
    public func start(): Unit {
        if (isActive.compareAndSwap(false, true)) {
            optimizedDispatcher.start()
        }
    }
    
    public func stop(): Unit {
        if (isActive.compareAndSwap(true, false)) {
            optimizedDispatcher.stop()
        }
    }
    
    public func getConfig(): DispatcherConfig {
        config
    }
    
    public func getPerformanceStats(): String {
        let stats = optimizedDispatcher.getPerformanceReport()
        "UltraHighPerformanceDispatcher[${name}] - ${stats}"
    }
    
    public func isRunning(): Bool {
        isActive.load()
    }
}

/**
 * 线程池调度器
 * 基于传统线程池模式的调度器实现
 */
public class ThreadPoolDispatcher <: AdvancedMessageDispatcher {
    private let config: DispatcherConfig
    private let name: String
    private let isActive: AtomicBool
    private let workerThreads: Array<DispatcherWorkerThread>
    private let taskQueue: LockFreeQueue<DispatcherTask>
    private let roundRobinCounter: AtomicInt64
    
    public init(config: DispatcherConfig) {
        this.config = config
        this.name = config.name
        this.isActive = AtomicBool(false)
        this.roundRobinCounter = AtomicInt64(0)
        
        let poolSize = if (config.executorConfig.corePoolSize <= 0) { 4 } else { config.executorConfig.corePoolSize }
        this.taskQueue = LockFreeQueue<DispatcherTask>(1024)
        
        // 创建工作线程
        this.workerThreads = Array<DispatcherWorkerThread>(Int64(poolSize), { i =>
            DispatcherWorkerThread(Int32(i), taskQueue, isActive)
        })
    }
    
    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        if (!isActive.load()) {
            throw Exception("ThreadPoolDispatcher ${name} is not running")
        }
        
        let task = DispatcherTask(envelope, actorRef, Priority.Normal)
        taskQueue.enqueue(task)
    }
    
    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        if (!isActive.load()) {
            throw Exception("ThreadPoolDispatcher ${name} is not running")
        }
        
        let task = DispatcherTask(envelope, actorRef, priority)
        taskQueue.enqueue(task)
    }
    
    public func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit {
        if (!isActive.load()) {
            throw Exception("ThreadPoolDispatcher ${name} is not running")
        }
        
        let minSize = min(Int64(envelopes.size), Int64(actorRefs.size))
        for (i in 0..minSize) {
            let task = DispatcherTask(envelopes[i], actorRefs[i], Priority.Normal)
            taskQueue.enqueue(task)
        }
    }
    
    public func start(): Unit {
        if (isActive.compareAndSwap(false, true)) {
            for (worker in workerThreads) {
                worker.start()
            }
        }
    }
    
    public func stop(): Unit {
        if (isActive.compareAndSwap(true, false)) {
            for (worker in workerThreads) {
                worker.stop()
            }
        }
    }
    
    public func getConfig(): DispatcherConfig {
        config
    }
    
    public func getPerformanceStats(): String {
        let queueSize = taskQueue.size()
        let stats = taskQueue.getStats()
        "ThreadPoolDispatcher[${name}] - Workers: ${workerThreads.size}, " +
        "Queue Size: ${queueSize}, Success Rate: ${stats.getSuccessRate()}"
    }
    
    public func isRunning(): Bool {
        isActive.load()
    }
}

/**
 * 调度器任务
 */
public class DispatcherTask {
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
 * 调度器工作线程
 */
public class DispatcherWorkerThread {
    private let workerId: Int32
    private let taskQueue: LockFreeQueue<DispatcherTask>
    private let isRunning: AtomicBool
    private let tasksProcessed: AtomicInt64
    
    public init(workerId: Int32, taskQueue: LockFreeQueue<DispatcherTask>, isRunning: AtomicBool) {
        this.workerId = workerId
        this.taskQueue = taskQueue
        this.isRunning = isRunning
        this.tasksProcessed = AtomicInt64(0)
    }
    
    public func start(): Unit {
        spawn {
            workerLoop()
        }
    }
    
    public func stop(): Unit {
        // 工作线程会在isRunning变为false时自动停止
    }
    
    private func workerLoop(): Unit {
        while (isRunning.load()) {
            match (taskQueue.dequeue()) {
                case Some(task) =>
                    executeTask(task)
                    tasksProcessed.fetchAdd(1)
                case None =>
                    // 没有任务，短暂休眠
                    sleep(Duration.microsecond * 100)
            }
        }
    }
    
    private func executeTask(task: DispatcherTask): Unit {
        // 简化的任务执行
        // 实际应该调用actorRef.tell(task.envelope)
        ()
    }
    
    public func getTasksProcessed(): Int64 {
        tasksProcessed.load()
    }
}

/**
 * 专用线程调度器
 * 为关键Actor提供专用线程，保证低延迟
 */
public class PinnedDispatcher <: AdvancedMessageDispatcher {
    private let config: DispatcherConfig
    private let name: String
    private let isActive: AtomicBool
    private let dedicatedThread: PinnedWorkerThread
    private let taskQueue: LockFreeQueue<DispatcherTask>

    public init(config: DispatcherConfig) {
        this.config = config
        this.name = config.name
        this.isActive = AtomicBool(false)
        this.taskQueue = LockFreeQueue<DispatcherTask>(512)  // 较小队列，专用线程
        this.dedicatedThread = PinnedWorkerThread(taskQueue, isActive)
    }

    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        if (!isActive.load()) {
            throw Exception("PinnedDispatcher ${name} is not running")
        }

        let task = DispatcherTask(envelope, actorRef, Priority.Critical)
        if (!taskQueue.enqueue(task)) {
            // 专用线程队列满，这是严重问题
            throw Exception("PinnedDispatcher ${name} queue is full")
        }
    }

    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        // 专用线程调度器所有任务都是高优先级
        dispatch(envelope, actorRef)
    }

    public func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit {
        if (!isActive.load()) {
            throw Exception("PinnedDispatcher ${name} is not running")
        }

        let minSize = min(Int64(envelopes.size), Int64(actorRefs.size))
        for (i in 0..minSize) {
            let task = DispatcherTask(envelopes[i], actorRefs[i], Priority.Critical)
            if (!taskQueue.enqueue(task)) {
                throw Exception("PinnedDispatcher ${name} queue is full at batch item ${i}")
            }
        }
    }

    public func start(): Unit {
        if (isActive.compareAndSwap(false, true)) {
            dedicatedThread.start()
        }
    }

    public func stop(): Unit {
        if (isActive.compareAndSwap(true, false)) {
            dedicatedThread.stop()
        }
    }

    public func getConfig(): DispatcherConfig {
        config
    }

    public func getPerformanceStats(): String {
        let queueSize = taskQueue.size()
        let tasksProcessed = dedicatedThread.getTasksProcessed()
        "PinnedDispatcher[${name}] - Queue Size: ${queueSize}, " +
        "Tasks Processed: ${tasksProcessed}, Dedicated Thread: Active"
    }

    public func isRunning(): Bool {
        isActive.load()
    }
}

/**
 * 专用工作线程
 */
public class PinnedWorkerThread {
    private let taskQueue: LockFreeQueue<DispatcherTask>
    private let isRunning: AtomicBool
    private let tasksProcessed: AtomicInt64

    public init(taskQueue: LockFreeQueue<DispatcherTask>, isRunning: AtomicBool) {
        this.taskQueue = taskQueue
        this.isRunning = isRunning
        this.tasksProcessed = AtomicInt64(0)
    }

    public func start(): Unit {
        spawn {
            dedicatedWorkerLoop()
        }
    }

    public func stop(): Unit {
        // 线程会在isRunning变为false时自动停止
    }

    private func dedicatedWorkerLoop(): Unit {
        while (isRunning.load()) {
            match (taskQueue.dequeue()) {
                case Some(task) =>
                    executeTaskImmediately(task)
                    tasksProcessed.fetchAdd(1)
                case None =>
                    // 专用线程使用更短的休眠时间
                    sleep(Duration.nanosecond * 100)
            }
        }
    }

    private func executeTaskImmediately(task: DispatcherTask): Unit {
        // 立即执行任务，最小化延迟
        // 实际应该调用actorRef.tell(task.envelope)
        ()
    }

    public func getTasksProcessed(): Int64 {
        tasksProcessed.load()
    }
}

/**
 * 调用线程调度器
 * 在调用者线程中直接执行，零延迟但无并发
 */
public class CallingThreadDispatcher <: AdvancedMessageDispatcher {
    private let config: DispatcherConfig
    private let name: String
    private let isActive: AtomicBool
    private let tasksExecuted: AtomicInt64

    public init(config: DispatcherConfig) {
        this.config = config
        this.name = config.name
        this.isActive = AtomicBool(false)
        this.tasksExecuted = AtomicInt64(0)
    }

    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        if (!isActive.load()) {
            throw Exception("CallingThreadDispatcher ${name} is not running")
        }

        // 在调用线程中直接执行
        executeInCallingThread(envelope, actorRef)
        tasksExecuted.fetchAdd(1)
    }

    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        // 调用线程调度器忽略优先级
        dispatch(envelope, actorRef)
    }

    public func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit {
        if (!isActive.load()) {
            throw Exception("CallingThreadDispatcher ${name} is not running")
        }

        let minSize = min(Int64(envelopes.size), Int64(actorRefs.size))
        for (i in 0..minSize) {
            executeInCallingThread(envelopes[i], actorRefs[i])
            tasksExecuted.fetchAdd(1)
        }
    }

    public func start(): Unit {
        isActive.store(true)
    }

    public func stop(): Unit {
        isActive.store(false)
    }

    public func getConfig(): DispatcherConfig {
        config
    }

    public func getPerformanceStats(): String {
        "CallingThreadDispatcher[${name}] - Tasks Executed: ${tasksExecuted.load()}, " +
        "Mode: Direct Execution"
    }

    public func isRunning(): Bool {
        isActive.load()
    }

    private func executeInCallingThread(envelope: Envelope, actorRef: ActorRef): Unit {
        // 在调用线程中直接执行
        // 实际应该调用actorRef.tell(envelope)
        ()
    }
}
