/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 基于Foundation队列的高级邮箱系统
 * 基于plan3.md Phase 2设计，利用现有的高性能队列实现
 */
package cactor.runtime.mailbox.advanced

import std.time.*
import std.collection.*
import cactor.core.message.{Message, Envelope}
import cactor.runtime.mailbox.Mailbox
import cactor.foundation.queue.{Queue, LockFreeQueue, SPSCQueue, MPSCQueue}
import cactor.core.config.{MailboxConfig, MailboxType}

/**
 * 基于Foundation LockFreeQueue的无界邮箱
 * 利用现有的高性能无锁队列实现
 */
public class FoundationUnboundedMailbox <: Mailbox {
    private let queue: LockFreeQueue<Envelope>
    private let config: MailboxConfig
    private let name: String
    
    public init(config: MailboxConfig) {
        // 使用默认容量创建LockFreeQueue
        this.queue = LockFreeQueue<Envelope>(1024)  // 默认1024容量
        this.config = config
        this.name = config.name
    }
    
    public func enqueue(envelope: Envelope): Bool {
        // LockFreeQueue的无界特性：当满时会自动扩容或返回false
        queue.enqueue(envelope)
    }
    
    public func dequeue(): Option<Envelope> {
        queue.dequeue()
    }
    
    public func size(): Int64 {
        queue.size()
    }
    
    public func isEmpty(): Bool {
        queue.isEmpty()
    }
    
    public func hasMessages(): Bool {
        !queue.isEmpty()
    }
    
    public func getName(): String {
        name
    }
    
    public func getConfig(): MailboxConfig {
        config
    }
    
    /**
     * 批量出队操作，利用LockFreeQueue的批量能力
     */
    public func dequeueBatch(maxBatchSize: Int32): Array<Envelope> {
        let batch = ArrayList<Envelope>()
        let batchSize = if (maxBatchSize <= 0) { Int32(100) } else { maxBatchSize }

        for (i in 0..Int64(batchSize)) {
            match (queue.dequeue()) {
                case Some(envelope) => batch.append(envelope)
                case None => break
            }
        }

        Array<Envelope>(Int64(batch.size), { i => batch[i] })
    }
    
    /**
     * 快速入队，使用LockFreeQueue的fastEnqueue
     */
    public func fastEnqueue(envelope: Envelope): Bool {
        queue.fastEnqueue(envelope)
    }
    
    /**
     * 获取队列统计信息
     */
    public func getStats(): String {
        let stats = queue.getStats()
        "FoundationUnboundedMailbox[${name}] - Size: ${stats.currentSize}, " +
        "Enqueued: ${stats.enqueueCount}, Dequeued: ${stats.dequeueCount}, " +
        "Failed: ${stats.failedEnqueues}, Success Rate: ${stats.getSuccessRate()}"
    }

    public func clear(): Unit {
        while (!queue.isEmpty()) {
            queue.dequeue()
        }
    }
}

/**
 * 基于Foundation LockFreeQueue的有界邮箱
 * 严格控制容量，支持背压
 */
public class FoundationBoundedMailbox <: Mailbox {
    private let queue: LockFreeQueue<Envelope>
    private let capacity: Int64
    private let pushTimeout: Duration
    private let config: MailboxConfig
    private let name: String
    
    public init(config: MailboxConfig) {
        this.capacity = config.capacity
        this.queue = LockFreeQueue<Envelope>(capacity)
        this.pushTimeout = config.pushTimeout
        this.config = config
        this.name = config.name
    }
    
    public func enqueue(envelope: Envelope): Bool {
        // 检查容量限制
        if (queue.size() >= capacity) {
            return false  // 有界邮箱已满
        }
        
        queue.enqueue(envelope)
    }
    
    /**
     * 带超时的入队操作
     */
    public func enqueueWithTimeout(envelope: Envelope, timeout: Duration): Bool {
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        let timeoutNanos = timeout.toNanoseconds()
        
        while (queue.size() >= capacity) {
            let elapsed = DateTime.now().toUnixTimeStamp().toNanoseconds() - startTime
            if (elapsed >= timeoutNanos) {
                return false  // 超时
            }
            
            // 简单的自旋等待，实际应该使用更高效的等待机制
            // 这里可以集成仓颉的协程等待机制
        }
        
        return enqueue(envelope)
    }
    
    public func dequeue(): Option<Envelope> {
        queue.dequeue()
    }
    
    public func size(): Int64 {
        queue.size()
    }
    
    public func isEmpty(): Bool {
        queue.isEmpty()
    }
    
    public func hasMessages(): Bool {
        !queue.isEmpty()
    }
    
    public func getName(): String {
        name
    }
    
    public func getConfig(): MailboxConfig {
        config
    }
    
    /**
     * 获取剩余容量
     */
    public func remainingCapacity(): Int64 {
        capacity - queue.size()
    }
    
    /**
     * 检查是否已满
     */
    public func isFull(): Bool {
        queue.size() >= capacity
    }
    
    /**
     * 获取容量利用率
     */
    public func getUtilization(): Float64 {
        Float64(queue.size()) / Float64(capacity)
    }

    public func clear(): Unit {
        while (!queue.isEmpty()) {
            queue.dequeue()
        }
    }
}

/**
 * 基于SPSC队列的单生产者单消费者邮箱
 * 专门优化的高性能邮箱，适用于单Actor场景
 */
public class SPSCMailbox <: Mailbox {
    private let queue: SPSCQueue<Envelope>
    private let config: MailboxConfig
    private let name: String
    
    public init(config: MailboxConfig) {
        let capacity = if (config.capacity <= 0) { Int32(1024) } else { Int32(config.capacity) }
        this.queue = SPSCQueue<Envelope>(capacity)
        this.config = config
        this.name = config.name
    }
    
    public func enqueue(envelope: Envelope): Bool {
        queue.offer(envelope)
    }
    
    public func dequeue(): Option<Envelope> {
        queue.poll()
    }
    
    public func size(): Int64 {
        queue.size()
    }
    
    public func isEmpty(): Bool {
        queue.isEmpty()
    }
    
    public func hasMessages(): Bool {
        !queue.isEmpty()
    }
    
    public func getName(): String {
        name
    }
    
    public func getConfig(): MailboxConfig {
        config
    }
    
    /**
     * 批量入队，利用SPSC的批量优化
     */
    public func enqueueBatch(envelopes: Array<Envelope>): Int32 {
        queue.offerBatch(envelopes)
    }
    
    /**
     * 批量出队，利用SPSC的批量优化
     */
    public func dequeueBatch(maxBatchSize: Int32): Array<Envelope> {
        queue.pollBatch(maxBatchSize)
    }
    
    /**
     * 获取性能统计
     */
    public func getPerformanceStats(): String {
        let stats = queue.getPerformanceStats()
        "SPSCMailbox[${name}] - Size: ${stats.currentSize}/${stats.capacity}, " +
        "Enqueued: ${stats.totalEnqueues}, Dequeued: ${stats.totalDequeues}, " +
        "Utilization: ${stats.getUtilization()}"
    }

    public func clear(): Unit {
        while (!queue.isEmpty()) {
            queue.poll()
        }
    }
}

/**
 * 基于MPSC队列的多生产者单消费者邮箱
 * 适用于多个发送者向同一个Actor发送消息的场景
 */
public class MPSCMailbox <: Mailbox {
    private let queue: MPSCQueue<Envelope>
    private let config: MailboxConfig
    private let name: String
    
    public init(config: MailboxConfig) {
        let capacity = if (config.capacity <= 0) { Int32(1024) } else { Int32(config.capacity) }
        this.queue = MPSCQueue<Envelope>(capacity)
        this.config = config
        this.name = config.name
    }
    
    public func enqueue(envelope: Envelope): Bool {
        queue.offer(envelope)
    }
    
    public func dequeue(): Option<Envelope> {
        queue.poll()
    }
    
    public func size(): Int64 {
        queue.size()
    }
    
    public func isEmpty(): Bool {
        queue.isEmpty()
    }
    
    public func hasMessages(): Bool {
        !queue.isEmpty()
    }
    
    public func getName(): String {
        name
    }
    
    public func getConfig(): MailboxConfig {
        config
    }
    
    /**
     * 高性能入队，利用MPSC的优化
     */
    public func fastEnqueue(envelope: Envelope): Bool {
        queue.offer(envelope)
    }

    /**
     * 批量出队
     */
    public func dequeueBatch(maxBatchSize: Int32): Array<Envelope> {
        queue.pollBatch(maxBatchSize)
    }

    /**
     * 获取竞争统计信息
     */
    public func getContentionStats(): String {
        let stats = queue.getPerformanceStats()
        "MPSCMailbox[${name}] - Capacity: ${stats.currentCapacity}, " +
        "Enqueued: ${stats.totalEnqueues}, Dequeued: ${stats.totalDequeues}, " +
        "Expansions: ${stats.expansionCount}"
    }

    public func clear(): Unit {
        while (!queue.isEmpty()) {
            queue.poll()
        }
    }
}

/**
 * 基于Foundation队列的优先级邮箱
 * 使用LockFreeQueue配合优先级排序实现
 */
public class FoundationPriorityMailbox <: Mailbox {
    private let normalQueue: LockFreeQueue<Envelope>
    private let priorityQueue: LockFreeQueue<PriorityEnvelope>
    private let comparator: (Message, Message) -> Int32
    private let config: MailboxConfig
    private let name: String

    public init(config: MailboxConfig, comparator: (Message, Message) -> Int32) {
        let capacity = if (config.capacity <= 0) { Int32(1024) } else { Int32(config.capacity) }
        this.normalQueue = LockFreeQueue<Envelope>(Int64(capacity / 2))
        this.priorityQueue = LockFreeQueue<PriorityEnvelope>(Int64(capacity / 2))
        this.comparator = comparator
        this.config = config
        this.name = config.name
    }

    public func enqueue(envelope: Envelope): Bool {
        let priority = envelope.getMessage().priority()

        if (priority > 0) {
            // 高优先级消息进入优先级队列
            let priorityEnvelope = PriorityEnvelope(envelope, priority)
            priorityQueue.enqueue(priorityEnvelope)
        } else {
            // 普通消息进入普通队列
            normalQueue.enqueue(envelope)
        }
    }

    public func dequeue(): Option<Envelope> {
        // 优先从优先级队列取消息
        match (priorityQueue.dequeue()) {
            case Some(priorityEnvelope) => Some(priorityEnvelope.envelope)
            case None => normalQueue.dequeue()
        }
    }

    public func size(): Int64 {
        normalQueue.size() + priorityQueue.size()
    }

    public func isEmpty(): Bool {
        normalQueue.isEmpty() && priorityQueue.isEmpty()
    }

    public func hasMessages(): Bool {
        !isEmpty()
    }

    public func getName(): String {
        name
    }

    public func getConfig(): MailboxConfig {
        config
    }

    /**
     * 批量出队，优先级优先
     */
    public func dequeueBatch(maxBatchSize: Int32): Array<Envelope> {
        let batch = ArrayList<Envelope>()
        let batchSize = if (maxBatchSize <= 0) { Int32(100) } else { maxBatchSize }

        // 先处理优先级消息
        var processed = Int32(0)
        while (processed < batchSize) {
            match (priorityQueue.dequeue()) {
                case Some(priorityEnvelope) =>
                    batch.append(priorityEnvelope.envelope)
                    processed += 1
                case None => break
            }
        }

        // 再处理普通消息
        while (processed < batchSize) {
            match (normalQueue.dequeue()) {
                case Some(envelope) =>
                    batch.append(envelope)
                    processed += 1
                case None => break
            }
        }

        Array<Envelope>(Int64(batch.size), { i => batch[i] })
    }

    public func clear(): Unit {
        while (!normalQueue.isEmpty()) {
            normalQueue.dequeue()
        }
        while (!priorityQueue.isEmpty()) {
            priorityQueue.dequeue()
        }
    }
}

/**
 * 优先级信封包装类
 */
public class PriorityEnvelope {
    public let envelope: Envelope
    public let priority: Int32

    public init(envelope: Envelope, priority: Int32) {
        this.envelope = envelope
        this.priority = priority
    }
}

/**
 * 基于Foundation队列的暂存邮箱
 * 支持消息暂存和恢复功能
 */
public class FoundationStashingMailbox <: Mailbox {
    private let normalQueue: LockFreeQueue<Envelope>
    private let stashQueue: LockFreeQueue<Envelope>
    private let capacity: Int64
    private let stashCapacity: Int64
    private let config: MailboxConfig
    private let name: String

    public init(config: MailboxConfig) {
        this.capacity = if (config.capacity <= 0) { Int64(1024) } else { config.capacity }
        this.stashCapacity = config.stashCapacity
        this.normalQueue = LockFreeQueue<Envelope>(capacity)
        this.stashQueue = LockFreeQueue<Envelope>(stashCapacity)
        this.config = config
        this.name = config.name
    }

    public func enqueue(envelope: Envelope): Bool {
        if (normalQueue.size() >= capacity) {
            return false
        }
        normalQueue.enqueue(envelope)
    }

    public func dequeue(): Option<Envelope> {
        normalQueue.dequeue()
    }

    public func size(): Int64 {
        normalQueue.size()
    }

    public func isEmpty(): Bool {
        normalQueue.isEmpty()
    }

    public func hasMessages(): Bool {
        !normalQueue.isEmpty()
    }

    public func getName(): String {
        name
    }

    public func getConfig(): MailboxConfig {
        config
    }

    /**
     * 暂存消息
     */
    public func stash(envelope: Envelope): Bool {
        if (stashQueue.size() >= stashCapacity) {
            return false  // 暂存队列已满
        }
        stashQueue.enqueue(envelope)
    }

    /**
     * 恢复所有暂存的消息到正常队列
     */
    public func unstashAll(): Int32 {
        var count = Int32(0)
        while (!stashQueue.isEmpty() && normalQueue.size() < capacity) {
            match (stashQueue.dequeue()) {
                case Some(envelope) =>
                    if (normalQueue.enqueue(envelope)) {
                        count += 1
                    } else {
                        // 如果正常队列满了，把消息放回暂存队列
                        stashQueue.enqueue(envelope)
                        break
                    }
                case None => break
            }
        }
        count
    }

    /**
     * 恢复指定数量的暂存消息
     */
    public func unstash(count: Int32): Int32 {
        var unstashed = Int32(0)
        for (i in 0..count) {
            if (stashQueue.isEmpty() || normalQueue.size() >= capacity) {
                break
            }

            match (stashQueue.dequeue()) {
                case Some(envelope) =>
                    if (normalQueue.enqueue(envelope)) {
                        unstashed += 1
                    } else {
                        stashQueue.enqueue(envelope)
                        break
                    }
                case None => break
            }
        }
        unstashed
    }

    /**
     * 获取暂存队列大小
     */
    public func stashSize(): Int64 {
        stashQueue.size()
    }

    /**
     * 检查暂存队列是否为空
     */
    public func isStashEmpty(): Bool {
        stashQueue.isEmpty()
    }

    /**
     * 清空暂存队列
     */
    public func clearStash(): Unit {
        while (!stashQueue.isEmpty()) {
            stashQueue.dequeue()
        }
    }

    public func clear(): Unit {
        while (!normalQueue.isEmpty()) {
            normalQueue.dequeue()
        }
        clearStash()
    }
}
