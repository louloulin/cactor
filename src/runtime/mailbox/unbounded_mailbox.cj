/*
 * Copyright (c) 2024. All rights reserved.
 * UnboundedMailbox - 无界邮箱实现
 * 基于plan10.md设计，提供无容量限制的高性能邮箱
 */
package cactor.runtime.mailbox

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.message.{Message, Envelope}
import cactor.foundation.queue.{LockFreeQueue}

/**
 * 无界邮箱实现
 */
public class UnboundedMailbox <: Mailbox {
    private let config: MailboxConfig
    private let messageQueue: LockFreeQueue<Envelope>
    private let currentSize: AtomicInt32
    private let totalEnqueued: AtomicInt64
    private let totalDequeued: AtomicInt64
    private let totalEnqueueTime: AtomicInt64
    private let totalDequeueTime: AtomicInt64
    private let isClosed: AtomicBool
    private let maxObservedSize: AtomicInt32
    
    public init(config: MailboxConfig) {
        this.config = config
        // 无界邮箱使用一个大的初始容量，但可以动态扩展
        this.messageQueue = LockFreeQueue<Envelope>(config.capacity)
        this.currentSize = AtomicInt32(0)
        this.totalEnqueued = AtomicInt64(0)
        this.totalDequeued = AtomicInt64(0)
        this.totalEnqueueTime = AtomicInt64(0)
        this.totalDequeueTime = AtomicInt64(0)
        this.isClosed = AtomicBool(false)
        this.maxObservedSize = AtomicInt32(0)
    }
    
    public prop mailboxType: MailboxType {
        get() { MailboxType.Unbounded }
    }
    
    public prop capacity: Int32 {
        get() { Int32.max }  // 无界
    }
    
    public prop messageCount: Int32 {
        get() { currentSize.load() }
    }
    
    public prop isEmpty: Bool {
        get() { currentSize.load() == 0 }
    }
    
    public prop isFull: Bool {
        get() { false }  // 无界邮箱永远不满
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
        
        // 无界邮箱总是尝试入队
        let success = messageQueue.offer(envelope)
        
        if (success) {
            let newSize = currentSize.fetchAdd(1) + 1
            totalEnqueued.fetchAdd(1)
            
            // 更新最大观察到的大小
            updateMaxObservedSize(newSize)
            
            if (config.enableMetrics) {
                let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
                totalEnqueueTime.fetchAdd(endTime - startTime)
            }
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
            MailboxType.Unbounded,
            Int32.max,  // 无界容量
            currentSize.load(),
            enqueued,
            dequeued,
            0,  // 无界邮箱不会丢弃消息
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
     * 获取最大观察到的大小
     */
    public func getMaxObservedSize(): Int32 {
        maxObservedSize.load()
    }
    
    /**
     * 获取内存使用估算
     */
    public func getEstimatedMemoryUsage(): Int64 {
        // 简化估算：每个消息大约占用64字节
        Int64(currentSize.load()) * 64
    }
    
    /**
     * 检查是否需要内存警告
     */
    public func needsMemoryWarning(threshold: Int32): Bool {
        currentSize.load() > threshold
    }
    
    /**
     * 获取详细的性能指标
     */
    public func getPerformanceMetrics(): UnboundedMailboxMetrics {
        let totalTime = totalEnqueueTime.load() + totalDequeueTime.load()
        let totalOps = totalEnqueued.load() + totalDequeued.load()
        
        let throughput = if (totalTime > 0) {
            Float64(totalOps) / (Float64(totalTime) / 1_000_000_000.0)  // ops/s
        } else {
            0.0
        }
        
        UnboundedMailboxMetrics(
            currentSize.load(),
            maxObservedSize.load(),
            getEstimatedMemoryUsage(),
            throughput,
            needsMemoryWarning(10000)  // 10K消息阈值
        )
    }
    
    /**
     * 更新最大观察到的大小
     */
    private func updateMaxObservedSize(newSize: Int32): Unit {
        var currentMax = maxObservedSize.load()
        while (newSize > currentMax) {
            if (maxObservedSize.compareAndSwap(currentMax, newSize)) {
                break
            }
            currentMax = maxObservedSize.load()
        }
    }
    
    /**
     * 压缩邮箱（如果支持）
     */
    public func compact(): Unit {
        // 无界邮箱的压缩操作
        // 在实际实现中，这里可能会重新组织内部数据结构
        // 简化实现，仅记录操作
        println("无界邮箱压缩操作完成")
    }
    
    /**
     * 获取吞吐量统计
     */
    public func getThroughputStats(windowSizeNanos: Int64): UnboundedThroughputStats {
        // 简化实现，返回基于总体统计的估算
        let totalTime = totalEnqueueTime.load() + totalDequeueTime.load()
        let totalOps = totalEnqueued.load() + totalDequeued.load()
        
        let avgThroughput = if (totalTime > 0) {
            Float64(totalOps) / (Float64(totalTime) / 1_000_000_000.0)
        } else {
            0.0
        }
        
        UnboundedThroughputStats(
            avgThroughput,
            avgThroughput * 1.2,  // 估算峰值
            avgThroughput * 0.8,  // 估算最低值
            windowSizeNanos
        )
    }
}

/**
 * 无界邮箱性能指标
 */
public struct UnboundedMailboxMetrics {
    public let currentSize: Int32
    public let maxObservedSize: Int32
    public let estimatedMemoryUsage: Int64
    public let throughput: Float64
    public let needsMemoryWarning: Bool
    
    public init(
        currentSize: Int32,
        maxObservedSize: Int32,
        estimatedMemoryUsage: Int64,
        throughput: Float64,
        needsMemoryWarning: Bool
    ) {
        this.currentSize = currentSize
        this.maxObservedSize = maxObservedSize
        this.estimatedMemoryUsage = estimatedMemoryUsage
        this.throughput = throughput
        this.needsMemoryWarning = needsMemoryWarning
    }
    
    /**
     * 打印性能指标报告
     */
    public func printReport(): Unit {
        println("=== 无界邮箱性能指标 ===")
        println("当前大小: ${currentSize}")
        println("最大观察大小: ${maxObservedSize}")
        println("估算内存使用: ${estimatedMemoryUsage} bytes")
        println("吞吐量: ${throughput} ops/s")
        println("内存警告: ${if (needsMemoryWarning) { "是" } else { "否" }}")
        println("======================")
    }
}

/**
 * 无界邮箱吞吐量统计
 */
public struct UnboundedThroughputStats {
    public let averageThroughput: Float64
    public let peakThroughput: Float64
    public let minThroughput: Float64
    public let windowSizeNanos: Int64
    
    public init(
        averageThroughput: Float64,
        peakThroughput: Float64,
        minThroughput: Float64,
        windowSizeNanos: Int64
    ) {
        this.averageThroughput = averageThroughput
        this.peakThroughput = peakThroughput
        this.minThroughput = minThroughput
        this.windowSizeNanos = windowSizeNanos
    }
}
