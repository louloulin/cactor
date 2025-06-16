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
        let batchSize = if (maxBatchSize <= 0) { 100 } else { maxBatchSize }
        
        for (i in 0..batchSize) {
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
        let capacity = if (config.capacity <= 0) { 1024 } else { config.capacity }
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
        let stats = queue.getStats()
        "SPSCMailbox[${name}] - Size: ${stats.currentSize}/${stats.capacity}, " +
        "Enqueued: ${stats.enqueueCount}, Dequeued: ${stats.dequeueCount}, " +
        "Utilization: ${stats.getUtilization()}"
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
        let capacity = if (config.capacity <= 0) { 1024 } else { config.capacity }
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
        queue.fastOffer(envelope)
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
        let stats = queue.getContentionStats()
        "MPSCMailbox[${name}] - Producers: ${stats.activeProducers}, " +
        "Retries: ${stats.totalRetries}, Success Rate: ${stats.getSuccessRate()}"
    }
}
