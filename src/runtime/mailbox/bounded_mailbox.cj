/*
 * Copyright (c) 2024. All rights reserved.
 * BoundedMailbox - 有界邮箱实现
 * 基于plan10.md设计，提供容量限制的高性能邮箱
 */
package cactor.runtime.mailbox

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.message.{Message, Envelope}
import cactor.foundation.queue.{LockFreeQueue}

/**
 * 有界邮箱实现
 */
public class BoundedMailbox <: Mailbox {
    private let config: MailboxConfig
    private let messageQueue: LockFreeQueue<Envelope>
    private let currentSize: AtomicInt32
    private let totalEnqueued: AtomicInt64
    private let totalDequeued: AtomicInt64
    private let totalDropped: AtomicInt64
    private let totalEnqueueTime: AtomicInt64
    private let totalDequeueTime: AtomicInt64
    private let isClosed: AtomicBool
    
    public init(config: MailboxConfig) {
        this.config = config
        this.messageQueue = LockFreeQueue<Envelope>(config.capacity)
        this.currentSize = AtomicInt32(0)
        this.totalEnqueued = AtomicInt64(0)
        this.totalDequeued = AtomicInt64(0)
        this.totalDropped = AtomicInt64(0)
        this.totalEnqueueTime = AtomicInt64(0)
        this.totalDequeueTime = AtomicInt64(0)
        this.isClosed = AtomicBool(false)
    }
    
    public prop mailboxType: MailboxType {
        get() { MailboxType.Bounded }
    }
    
    public prop capacity: Int32 {
        get() { config.capacity }
    }
    
    public prop messageCount: Int32 {
        get() { currentSize.load() }
    }
    
    public prop isEmpty: Bool {
        get() { currentSize.load() == 0 }
    }
    
    public prop isFull: Bool {
        get() { currentSize.load() >= config.capacity }
    }
    
    /**
     * 入队消息
     */
    public func enqueue(envelope: Envelope): Bool {
        if (isClosed.load()) {
            return false
        }
        
        let startTime = if (config.enableMetrics) {
            DateTime.now().toUnixTimeStamp().toNanoseconds()
        } else {
            0
        }
        
        // 检查容量限制
        if (currentSize.load() >= config.capacity) {
            totalDropped.fetchAdd(1)
            return false
        }
        
        // 尝试入队
        let success = messageQueue.offer(envelope)
        
        if (success) {
            currentSize.fetchAdd(1)
            totalEnqueued.fetchAdd(1)
            
            if (config.enableMetrics) {
                let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
                totalEnqueueTime.fetchAdd(endTime - startTime)
            }
        } else {
            totalDropped.fetchAdd(1)
        }
        
        return success
    }
    
    /**
     * 出队消息
     */
    public func dequeue(): Option<Envelope> {
        if (isClosed.load() && isEmpty) {
            return None
        }
        
        let startTime = if (config.enableMetrics) {
            DateTime.now().toUnixTimeStamp().toNanoseconds()
        } else {
            0
        }
        
        let envelope = messageQueue.poll()
        
        match (envelope) {
            case Some(env) =>
                currentSize.fetchAdd(-1)
                totalDequeued.fetchAdd(1)
                
                if (config.enableMetrics) {
                    let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
                    totalDequeueTime.fetchAdd(endTime - startTime)
                }
                
                Some(env)
            case None =>
                None
        }
    }
    
    /**
     * 批量出队消息
     */
    public func dequeueBatch(maxBatchSize: Int32): Array<Envelope> {
        let batch = Array<Envelope>()
        let actualBatchSize = if (config.enableBatching) {
            Int32.min(maxBatchSize, config.batchSize)
        } else {
            1
        }
        
        for (i in 0..actualBatchSize) {
            let envelope = dequeue()
            match (envelope) {
                case Some(env) =>
                    batch.append(env)
                case None =>
                    break
            }
        }
        
        return batch
    }
    
    /**
     * 清空邮箱
     */
    public func clear(): Unit {
        while (!isEmpty) {
            let _ = dequeue()
        }
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): MailboxStats {
        let enqueued = totalEnqueued.load()
        let dequeued = totalDequeued.load()
        let enqueuedTime = totalEnqueueTime.load()
        let dequeuedTime = totalDequeueTime.load()
        
        let avgEnqueueTime = if (enqueued > 0) {
            Float64(enqueuedTime) / Float64(enqueued) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
        
        let avgDequeueTime = if (dequeued > 0) {
            Float64(dequeuedTime) / Float64(dequeued) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
        
        MailboxStats(
            MailboxType.Bounded,
            config.capacity,
            currentSize.load(),
            enqueued,
            dequeued,
            totalDropped.load(),
            avgEnqueueTime,
            avgDequeueTime
        )
    }
    
    /**
     * 关闭邮箱
     */
    public func close(): Unit {
        isClosed.store(true)
    }
    
    /**
     * 等待邮箱为空
     */
    public func waitUntilEmpty(timeoutNanos: Int64): Bool {
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        while (!isEmpty) {
            let currentTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
            if (currentTime - startTime > timeoutNanos) {
                return false
            }
            
            // 短暂休眠
            // Thread.yield()
        }
        
        return true
    }
    
    /**
     * 获取容量利用率
     */
    public func getUtilizationRate(): Float64 {
        if (config.capacity > 0) {
            Float64(currentSize.load()) / Float64(config.capacity)
        } else {
            0.0
        }
    }
    
    /**
     * 获取丢弃率
     */
    public func getDropRate(): Float64 {
        let enqueued = totalEnqueued.load()
        let dropped = totalDropped.load()
        
        if (enqueued + dropped > 0) {
            Float64(dropped) / Float64(enqueued + dropped)
        } else {
            0.0
        }
    }
    
    /**
     * 检查是否接近满容量
     */
    public func isNearlyFull(threshold: Float64): Bool {
        getUtilizationRate() >= threshold
    }
    
    /**
     * 获取详细的性能指标
     */
    public func getPerformanceMetrics(): BoundedMailboxMetrics {
        BoundedMailboxMetrics(
            getUtilizationRate(),
            getDropRate(),
            Float64(totalEnqueued.load()) / (Float64(totalEnqueueTime.load()) / 1_000_000_000.0),  // 入队吞吐量
            Float64(totalDequeued.load()) / (Float64(totalDequeueTime.load()) / 1_000_000_000.0),  // 出队吞吐量
            isNearlyFull(0.8)  // 80%阈值
        )
    }
}

/**
 * 有界邮箱性能指标
 */
public struct BoundedMailboxMetrics {
    public let utilizationRate: Float64
    public let dropRate: Float64
    public let enqueueThroughput: Float64
    public let dequeueThroughput: Float64
    public let isNearlyFull: Bool
    
    public init(
        utilizationRate: Float64,
        dropRate: Float64,
        enqueueThroughput: Float64,
        dequeueThroughput: Float64,
        isNearlyFull: Bool
    ) {
        this.utilizationRate = utilizationRate
        this.dropRate = dropRate
        this.enqueueThroughput = enqueueThroughput
        this.dequeueThroughput = dequeueThroughput
        this.isNearlyFull = isNearlyFull
    }
    
    /**
     * 打印性能指标报告
     */
    public func printReport(): Unit {
        println("=== 有界邮箱性能指标 ===")
        println("利用率: ${utilizationRate * 100.0}%")
        println("丢弃率: ${dropRate * 100.0}%")
        println("入队吞吐量: ${enqueueThroughput} ops/s")
        println("出队吞吐量: ${dequeueThroughput} ops/s")
        println("接近满容量: ${if (isNearlyFull) { "是" } else { "否" }}")
        println("======================")
    }
}
