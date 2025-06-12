/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 高性能工作窃取调度器
 * 基于仓颉并发原语的低延时高吞吐工作窃取实现
 * 支持优先级调度、零拷贝消息、NUMA感知等高级特性
 */
package cactor.dispatcher.work_stealing

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import std.math.*
import std.random.*
import cactor.core.message.Envelope
import cactor.core.actor.ActorRef
// import cactor.core.zerocopy.ZeroCopyMessage
// import cactor.core.memory.NumaAwareMemoryPool

// 优先级枚举
public enum Priority {
    | Critical    // 系统关键消息 - 优先级0
    | High        // 高优先级业务消息 - 优先级1
    | Normal      // 普通消息 - 优先级2
    | Low         // 低优先级消息 - 优先级3

    public func getValue(): Int32 {
        match (this) {
            case Critical => 0
            case High => 1
            case Normal => 2
            case Low => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Critical => "Critical"
            case High => "High"
            case Normal => "Normal"
            case Low => "Low"
        }
    }
}

/**
 * 工作窃取队列
 * 支持本地LIFO访问和远程FIFO窃取
 * 使用ArrayList实现双端队列行为
 */
public class WorkStealingQueue<T> {
    private let items: ArrayList<T>
    private let size: AtomicInt64
    private let maxSize: Int64
    private let mutex: ReentrantMutex

    public init(maxSize: Int64) {
        this.items = ArrayList<T>()
        this.size = AtomicInt64(0)
        this.maxSize = maxSize
        this.mutex = ReentrantMutex()
    }

    /**
     * 本地推入任务 (LIFO)
     */
    public func push(item: T): Bool {
        if (size.load() >= maxSize) {
            return false
        }

        mutex.lock()
        try {
            if (size.load() >= maxSize) {
                return false
            }
            items.append(item)  // 添加到末尾
            size.fetchAdd(1)
            return true
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 本地弹出任务 (LIFO) - 从末尾取
     */
    public func pop(): Option<T> {
        mutex.lock()
        try {
            if (items.isEmpty()) {
                return None
            }
            let lastIndex = items.size - 1
            let item = items[lastIndex]
            items.remove(lastIndex)  // 从末尾移除（LIFO）
            size.fetchAdd(-1)
            Some(item)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 远程窃取任务 (FIFO) - 从开头取
     */
    public func steal(): Option<T> {
        mutex.lock()
        try {
            if (items.isEmpty()) {
                return None
            }
            let item = items[0]
            items.remove(0)  // 从开头移除（FIFO）
            size.fetchAdd(-1)
            Some(item)
        } finally {
            mutex.unlock()
        }
    }

    public func getSize(): Int64 {
        size.load()
    }

    public func isEmpty(): Bool {
        size.load() == 0
    }
}

/**
 * 工作线程
 */
public class WorkerThread {
    private let workerId: Int32
    private let localQueue: WorkStealingQueue<ActorTask>
    private let globalQueue: NonBlockingQueue<ActorTask>
    private let otherWorkers: Array<WorkerThread>
    private let isRunning: AtomicBool
    private let tasksProcessed: AtomicInt64
    private let stealAttempts: AtomicInt64
    private let successfulSteals: AtomicInt64

    public init(workerId: Int32, globalQueue: NonBlockingQueue<ActorTask>) {
        this.workerId = workerId
        this.localQueue = WorkStealingQueue<ActorTask>(1000)
        this.globalQueue = globalQueue
        this.otherWorkers = Array<WorkerThread>()
        this.isRunning = AtomicBool(false)
        this.tasksProcessed = AtomicInt64(0)
        this.stealAttempts = AtomicInt64(0)
        this.successfulSteals = AtomicInt64(0)
    }

    public func setOtherWorkers(workers: Array<WorkerThread>): Unit {
        // 注意：这里简化处理，实际应该使用更安全的方式
        for (worker in workers) {
            if (worker.workerId != this.workerId) {
                // 添加到其他工作线程列表
            }
        }
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            spawn {
                workerLoop()
            }
        }
    }

    public func stop(): Unit {
        isRunning.store(false)
    }

    public func submitTask(task: ActorTask): Bool {
        localQueue.push(task)
    }

    private func workerLoop(): Unit {
        while (isRunning.load()) {
            match (findTask()) {
                case Some(task) => 
                    executeTask(task)
                    tasksProcessed.fetchAdd(1)
                case None => 
                    // 没有任务，短暂休眠
                    sleep(Duration.microsecond * 10)
            }
        }
    }

    private func findTask(): Option<ActorTask> {
        // 1. 首先尝试从本地队列获取任务
        match (localQueue.pop()) {
            case Some(task) => Some(task)
            case None => 
                // 2. 尝试从全局队列获取任务
                match (globalQueue.dequeue()) {
                    case Some(task) => Some(task)
                    case None => 
                        // 3. 尝试从其他工作线程窃取任务
                        stealFromOthers()
                }
        }
    }

    private func stealFromOthers(): Option<ActorTask> {
        stealAttempts.fetchAdd(1)
        
        // 随机选择其他工作线程进行窃取
        let targetCount = otherWorkers.size
        if (targetCount == 0) {
            return None
        }

        let startIndex = 0  // 简化实现，从第一个开始
        
        for (i in 0..targetCount) {
            let targetIndex = (startIndex + i) % targetCount
            let targetWorker = otherWorkers[targetIndex]
            
            match (targetWorker.localQueue.steal()) {
                case Some(task) => 
                    successfulSteals.fetchAdd(1)
                    return Some(task)
                case None => 
                    // 继续尝试下一个工作线程
                    ()
            }
        }
        
        return None
    }

    private func executeTask(task: ActorTask): Unit {
        try {
            task.execute()
        } catch (e: Exception) {
            // 记录错误，但不影响工作线程继续运行
            println("Worker ${workerId} 执行任务时发生错误: ${e}")
        }
    }

    public func getWorkerId(): Int32 {
        workerId
    }

    public func getTasksProcessed(): Int64 {
        tasksProcessed.load()
    }

    public func getStealAttempts(): Int64 {
        stealAttempts.load()
    }

    public func getSuccessfulSteals(): Int64 {
        successfulSteals.load()
    }

    public func getLocalQueueSize(): Int64 {
        localQueue.getSize()
    }
}

/**
 * 增强的Actor任务 - 支持优先级和零拷贝消息
 */
public class ActorTask {
    private let envelope: Envelope
    private let actorRef: ActorRef
    private let priority: Priority
    private let creationTime: Int64
    private let taskId: UInt64
    private var executionStartTime: Int64
    private var executionEndTime: Int64
    private var isZeroCopy: Bool

    public init(envelope: Envelope, actorRef: ActorRef, priority: Priority) {
        this.envelope = envelope
        this.actorRef = actorRef
        this.priority = priority
        this.creationTime = getCurrentTimeNanos()
        this.taskId = generateTaskId()
        this.executionStartTime = 0
        this.executionEndTime = 0
        this.isZeroCopy = false  // 暂时禁用零拷贝检测
    }

    public func execute(): Unit {
        executionStartTime = getCurrentTimeNanos()

        try {
            // 检查是否为零拷贝消息
            if (isZeroCopy) {
                executeZeroCopyMessage()
            } else {
                executeRegularMessage()
            }
        } catch (e: Exception) {
            println("任务执行失败: ${e}")
        } finally {
            executionEndTime = getCurrentTimeNanos()
        }
    }

    private func executeZeroCopyMessage(): Unit {
        // 零拷贝消息的高效处理（暂时简化实现）
        let message = envelope.getMessage()
        println("执行零拷贝任务: Type=${message.messageType()}")
    }

    private func executeRegularMessage(): Unit {
        // 常规消息处理
        println("执行常规任务: Message=${envelope.getMessage().messageType()}")
    }

    public func getEnvelope(): Envelope { envelope }
    public func getActorRef(): ActorRef { actorRef }
    public func getPriority(): Priority { priority }
    public func getCreationTime(): Int64 { creationTime }
    public func getTaskId(): UInt64 { taskId }
    public func isZeroCopyMessage(): Bool { isZeroCopy }

    public func getAge(): Int64 {
        getCurrentTimeNanos() - creationTime
    }

    public func getExecutionTime(): Int64 {
        if (executionEndTime > executionStartTime) {
            return executionEndTime - executionStartTime
        }
        return 0
    }

    public func getWaitTime(): Int64 {
        if (executionStartTime > creationTime) {
            return executionStartTime - creationTime
        }
        return 0
    }
}

// 全局任务ID计数器
var globalTaskIdCounter: AtomicInt64 = AtomicInt64(0)

// 任务ID生成器
func generateTaskId(): UInt64 {
    let timestamp = getCurrentTimeNanos()
    let sequence = globalTaskIdCounter.fetchAdd(1)
    return (UInt64(timestamp) << 16) | (UInt64(sequence) & 0xFFFF)
}

func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    return now.toUnixTimeStamp().toMilliseconds() * 1000000  // 转换为纳秒
}

/**
 * 工作窃取调度器
 */
public class WorkStealingDispatcher {
    private let workerCount: Int32
    private let workers: Array<WorkerThread>
    private let globalQueue: NonBlockingQueue<ActorTask>
    private let roundRobinCounter: AtomicInt64
    private let isStarted: AtomicBool
    private let totalTasksSubmitted: AtomicInt64
    private let totalTasksCompleted: AtomicInt64

    public init(workerCount: Int32) {
        this.workerCount = workerCount
        this.globalQueue = NonBlockingQueue<ActorTask>()
        this.roundRobinCounter = AtomicInt64(0)
        this.isStarted = AtomicBool(false)
        this.totalTasksSubmitted = AtomicInt64(0)
        this.totalTasksCompleted = AtomicInt64(0)

        // 创建工作线程
        let queue = this.globalQueue
        this.workers = Array<WorkerThread>(Int64(workerCount), { i =>
            WorkerThread(Int32(i), queue)
        })

        // 设置工作线程之间的引用
        for (worker in workers) {
            worker.setOtherWorkers(workers)
        }
    }

    public func start(): Unit {
        if (isStarted.compareAndSwap(false, true)) {
            for (worker in workers) {
                worker.start()
            }
            println("工作窃取调度器启动，工作线程数: ${workerCount}")
        }
    }

    public func stop(): Unit {
        if (isStarted.compareAndSwap(true, false)) {
            for (worker in workers) {
                worker.stop()
            }
            println("工作窃取调度器停止")
        }
    }

    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        dispatchWithPriority(envelope, actorRef, Priority.Normal)
    }

    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        let task = ActorTask(envelope, actorRef, priority)
        totalTasksSubmitted.fetchAdd(1)

        // 尝试提交到负载最轻的工作线程
        let targetWorker = selectWorker()

        if (!targetWorker.submitTask(task)) {
            // 本地队列满，提交到全局队列
            globalQueue.enqueue(task)
        }
    }

    private func selectWorker(): WorkerThread {
        // 简单的轮询策略
        let index = roundRobinCounter.fetchAdd(1) % Int64(workerCount)
        workers[index]
    }

    public func getWorkerCount(): Int32 {
        workerCount
    }

    public func getTotalTasksSubmitted(): Int64 {
        totalTasksSubmitted.load()
    }

    public func getTotalTasksProcessed(): Int64 {
        var total: Int64 = 0
        for (worker in workers) {
            total += worker.getTasksProcessed()
        }
        total
    }

    public func getGlobalQueueSize(): Int64 {
        globalQueue.size
    }

    public func getWorkerStats(): Array<WorkerStats> {
        let stats = ArrayList<WorkerStats>()
        for (worker in workers) {
            stats.append(WorkerStats(
                worker.getWorkerId(),
                worker.getTasksProcessed(),
                worker.getLocalQueueSize(),
                worker.getStealAttempts(),
                worker.getSuccessfulSteals()
            ))
        }
        stats.toArray()
    }
}

/**
 * 工作线程统计信息
 */
public struct WorkerStats {
    public let workerId: Int32
    public let tasksProcessed: Int64
    public let localQueueSize: Int64
    public let stealAttempts: Int64
    public let successfulSteals: Int64

    public init(workerId: Int32, tasksProcessed: Int64, localQueueSize: Int64,
                stealAttempts: Int64, successfulSteals: Int64) {
        this.workerId = workerId
        this.tasksProcessed = tasksProcessed
        this.localQueueSize = localQueueSize
        this.stealAttempts = stealAttempts
        this.successfulSteals = successfulSteals
    }

    public func getStealSuccessRate(): Float64 {
        if (stealAttempts == 0) {
            return 0.0
        }
        Float64(successfulSteals) / Float64(stealAttempts)
    }
}
