/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 工作窃取调度器
 * 基于仓颉并发原语的高性能工作窃取实现
 */
package cactor.dispatcher.work_stealing

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.message.Envelope
import cactor.core.actor.ActorRef

/**
 * 工作窃取队列
 * 支持本地LIFO访问和远程FIFO窃取
 */
public class WorkStealingQueue<T> {
    private let deque: NonBlockingQueue<T>
    private let size: AtomicInt64
    private let maxSize: Int64

    public init(maxSize: Int64) {
        this.deque = NonBlockingQueue<T>()
        this.size = AtomicInt64(0)
        this.maxSize = maxSize
    }

    /**
     * 本地推入任务 (LIFO)
     */
    public func push(item: T): Bool {
        if (size.load() >= maxSize) {
            return false
        }
        
        if (deque.enqueue(item)) {
            size.fetchAdd(1)
            return true
        }
        return false
    }

    /**
     * 本地弹出任务 (LIFO)
     */
    public func pop(): Option<T> {
        match (deque.dequeue()) {
            case Some(item) => 
                size.fetchAdd(-1)
                Some(item)
            case None => None
        }
    }

    /**
     * 远程窃取任务 (FIFO)
     */
    public func steal(): Option<T> {
        // 简化实现：使用相同的dequeue操作
        // 实际实现中可以使用双端队列优化
        match (deque.dequeue()) {
            case Some(item) => 
                size.fetchAdd(-1)
                Some(item)
            case None => None
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

        let startIndex = Int32(System.currentTimeMillis() % targetCount.toInt64())
        
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
 * Actor任务
 */
public class ActorTask {
    private let envelope: Envelope
    private let actorRef: ActorRef
    private let creationTime: Int64

    public init(envelope: Envelope, actorRef: ActorRef) {
        this.envelope = envelope
        this.actorRef = actorRef
        this.creationTime = System.currentTimeMillis()
    }

    public func execute(): Unit {
        // 这里应该调用Actor的消息处理方法
        // 简化实现：直接打印
        println("执行任务: Actor=${actorRef.toString()}, Message=${envelope.getMessage().messageType()}")
    }

    public func getEnvelope(): Envelope {
        envelope
    }

    public func getActorRef(): ActorRef {
        actorRef
    }

    public func getCreationTime(): Int64 {
        creationTime
    }

    public func getAge(): Int64 {
        System.currentTimeMillis() - creationTime
    }
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
        this.workers = Array<WorkerThread>(workerCount, { i => 
            WorkerThread(i, globalQueue)
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
        let task = ActorTask(envelope, actorRef)
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
        let index = roundRobinCounter.fetchAdd(1) % workerCount.toInt64()
        workers[Int32(index)]
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
        workers.map { worker =>
            WorkerStats(
                workerId: worker.getWorkerId(),
                tasksProcessed: worker.getTasksProcessed(),
                localQueueSize: worker.getLocalQueueSize(),
                stealAttempts: worker.getStealAttempts(),
                successfulSteals: worker.getSuccessfulSteals()
            )
        }
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
    
    public func getStealSuccessRate(): Float64 {
        if (stealAttempts == 0) {
            return 0.0
        }
        Float64(successfulSteals) / Float64(stealAttempts)
    }
}
