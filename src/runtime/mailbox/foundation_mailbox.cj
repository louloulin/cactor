/*
 * Copyright (c) 2024. All rights reserved.
 * Runtime Layer - Foundation基础的邮箱实现
 * 基于Foundation层Queue构建的高性能Actor邮箱
 */
package cactor.runtime.mailbox

import std.sync.*
import cactor.foundation.queue.{Queue, LockFreeQueue, SimpleQueue, QueueStats}
import cactor.core.message.{Message, Envelope}

/**
 * 基于Foundation Queue的Actor邮箱
 * 使用Foundation层的高性能队列作为底层存储
 */
public class FoundationMailbox <: Mailbox {
    private let queue: Queue<Envelope>
    private let mailboxCapacity: Int64
    private let mailboxType: String
    private let stats: MailboxStats
    private let mutex: Mutex
    private let closed: AtomicBool

    public init(capacity: Int64, useHighPerformance: Bool) {
        this.mailboxCapacity = capacity
        this.mailboxType = if (useHighPerformance) { "LockFree" } else { "Simple" }
        this.stats = MailboxStats()
        this.mutex = Mutex()
        this.closed = AtomicBool(false)
        
        // 根据性能需求选择队列实现
        this.queue = if (useHighPerformance) {
            // 确保容量是2的幂，用于LockFreeQueue
            let actualCapacity = FoundationMailbox.nextPowerOfTwo(capacity)
            LockFreeQueue<Envelope>(actualCapacity)
        } else {
            SimpleQueue<Envelope>(capacity)
        }
    }

    /**
     * 便利构造函数 - 默认使用高性能队列
     */
    public init(capacity: Int64) {
        this.mailboxCapacity = capacity
        this.mailboxType = "LockFree"
        this.stats = MailboxStats()
        this.mutex = Mutex()
        this.closed = AtomicBool(false)

        let actualCapacity = FoundationMailbox.nextPowerOfTwo(capacity)
        this.queue = LockFreeQueue<Envelope>(actualCapacity)
    }

    public func enqueue(envelope: Envelope): Bool {
        if (closed.load()) {
            return false
        }

        let success = queue.enqueue(envelope)
        
        mutex.lock()
        if (success) {
            stats.incrementEnqueued()
        } else {
            stats.incrementDropped()
        }
        mutex.unlock()
        
        success
    }

    public func dequeue(): Option<Envelope> {
        let result = queue.dequeue()
        
        mutex.lock()
        match (result) {
            case Some(_) => stats.incrementDequeued()
            case None => stats.incrementEmptyReads()
        }
        mutex.unlock()
        
        result
    }

    public func isEmpty(): Bool {
        queue.isEmpty()
    }

    public func size(): Int64 {
        queue.size()
    }

    public func capacity(): Int64 {
        queue.capacity()
    }

    public func clear(): Unit {
        queue.clear()

        mutex.lock()
        stats.incrementClears()
        mutex.unlock()
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
        clear()
    }

    public func getMailboxType(): String {
        mailboxType
    }

    public func getStats(): MailboxStats {
        mutex.lock()
        let currentStats = stats.copy()
        mutex.unlock()
        currentStats
    }

    /**
     * 获取Foundation队列的详细统计信息
     */
    public func getFoundationQueueStats(): Option<QueueStats> {
        match (queue) {
            case lockFreeQueue: LockFreeQueue<Envelope> => Some(lockFreeQueue.getStats())
            case _ => None
        }
    }

    /**
     * 获取邮箱性能指标
     */
    public func getPerformanceMetrics(): MailboxPerformanceMetrics {
        let mailboxStats = getStats()
        let queueStats = getFoundationQueueStats()
        
        MailboxPerformanceMetrics(
            mailboxStats,
            queueStats,
            mailboxType,
            capacity(),
            size()
        )
    }

    /**
     * 计算下一个2的幂
     */
    private static func nextPowerOfTwo(n: Int64): Int64 {
        if (n <= 1) { return 1 }
        if (n <= 2) { return 2 }
        if (n <= 4) { return 4 }
        if (n <= 8) { return 8 }
        if (n <= 16) { return 16 }
        if (n <= 32) { return 32 }
        if (n <= 64) { return 64 }
        if (n <= 128) { return 128 }
        if (n <= 256) { return 256 }
        if (n <= 512) { return 512 }
        if (n <= 1024) { return 1024 }
        if (n <= 2048) { return 2048 }
        if (n <= 4096) { return 4096 }
        if (n <= 8192) { return 8192 }
        if (n <= 16384) { return 16384 }
        return 32768  // 最大支持32K
    }
}

/**
 * 邮箱统计信息
 */
public class MailboxStats {
    private var enqueued: Int64
    private var dequeued: Int64
    private var dropped: Int64
    private var emptyReads: Int64
    private var clears: Int64
    private let createdAt: Int64

    public init() {
        this.enqueued = 0
        this.dequeued = 0
        this.dropped = 0
        this.emptyReads = 0
        this.clears = 0
        this.createdAt = MailboxStats.getCurrentTimeNanos()
    }

    public func incrementEnqueued(): Unit { enqueued += 1 }
    public func incrementDequeued(): Unit { dequeued += 1 }
    public func incrementDropped(): Unit { dropped += 1 }
    public func incrementEmptyReads(): Unit { emptyReads += 1 }
    public func incrementClears(): Unit { clears += 1 }

    public func getEnqueued(): Int64 { enqueued }
    public func getDequeued(): Int64 { dequeued }
    public func getDropped(): Int64 { dropped }
    public func getEmptyReads(): Int64 { emptyReads }
    public func getClears(): Int64 { clears }
    public func getCreatedAt(): Int64 { createdAt }

    public func getThroughput(): Float64 {
        let totalOps = enqueued + dequeued
        let ageInSeconds = getAgeInSeconds()
        if (ageInSeconds > 0.0) {
            Float64(totalOps) / ageInSeconds
        } else {
            0.0
        }
    }

    public func getSuccessRate(): Float64 {
        let totalAttempts = enqueued + dropped
        if (totalAttempts > 0) {
            Float64(enqueued) / Float64(totalAttempts) * 100.0
        } else {
            100.0
        }
    }

    public func getAgeInSeconds(): Float64 {
        Float64(getCurrentTimeNanos() - createdAt) / 1000000000.0
    }

    public func copy(): MailboxStats {
        let newStats = MailboxStats()
        newStats.enqueued = this.enqueued
        newStats.dequeued = this.dequeued
        newStats.dropped = this.dropped
        newStats.emptyReads = this.emptyReads
        newStats.clears = this.clears
        newStats
    }

    private static func getCurrentTimeNanos(): Int64 {
        // 简化实现
        1000000000
    }
}

/**
 * 邮箱性能指标
 */
public struct MailboxPerformanceMetrics {
    public let mailboxStats: MailboxStats
    public let queueStats: Option<QueueStats>
    public let mailboxType: String
    public let capacity: Int64
    public let currentSize: Int64

    public init(mailboxStats: MailboxStats, queueStats: Option<QueueStats>, 
                mailboxType: String, capacity: Int64, currentSize: Int64) {
        this.mailboxStats = mailboxStats
        this.queueStats = queueStats
        this.mailboxType = mailboxType
        this.capacity = capacity
        this.currentSize = currentSize
    }

    public func getOverallThroughput(): Float64 {
        mailboxStats.getThroughput()
    }

    public func getUtilization(): Float64 {
        if (capacity > 0) {
            Float64(currentSize) / Float64(capacity) * 100.0
        } else {
            0.0
        }
    }

    public func getFoundationQueueSuccessRate(): Float64 {
        match (queueStats) {
            case Some(stats) => stats.getSuccessRate()
            case None => mailboxStats.getSuccessRate()
        }
    }

    public func isHighPerformance(): Bool {
        mailboxType == "LockFree"
    }
}

/**
 * Foundation邮箱工厂
 * 创建不同配置的Foundation邮箱
 */
public class FoundationMailboxFactory {
    /**
     * 创建高性能邮箱（使用LockFreeQueue）
     */
    public static func createHighPerformanceMailbox(capacity: Int64): FoundationMailbox {
        FoundationMailbox(capacity, true)
    }

    /**
     * 创建标准邮箱（使用SimpleQueue）
     */
    public static func createStandardMailbox(capacity: Int64): FoundationMailbox {
        FoundationMailbox(capacity, false)
    }

    /**
     * 根据性能需求自动选择邮箱类型
     */
    public static func createOptimalMailbox(capacity: Int64, expectedThroughput: Int64): FoundationMailbox {
        // 如果期望吞吐量高，使用高性能邮箱
        let useHighPerformance = expectedThroughput > 10000  // 每秒10K消息以上
        FoundationMailbox(capacity, useHighPerformance)
    }

    /**
     * 创建批量邮箱（用于高吞吐量场景）
     */
    public static func createBulkMailbox(capacity: Int64): FoundationMailbox {
        // 确保容量足够大，适合批量处理
        let bulkCapacity = if (capacity < 1024) { 1024 } else { capacity }
        FoundationMailbox(bulkCapacity, true)
    }
}
