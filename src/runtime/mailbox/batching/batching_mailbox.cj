/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 批量处理邮箱
 * 支持自适应批处理的高性能邮箱实现
 */
package cactor.runtime.mailbox.batching

import std.sync.*
import std.time.*
import std.collection.*
import std.math.*
import cactor.runtime.mailbox.Mailbox
import cactor.core.message.Envelope

/**
 * 批量处理邮箱
 * 支持按大小和时间触发的批量处理
 */
public class BatchingMailbox <: Mailbox {
    private let batchSize: Int64
    private let batchTimeout: Duration
    private let pendingBatch: ArrayList<Envelope>
    private let lastBatchTime: AtomicInt64
    private let closed: AtomicBool
    private let batchMutex: ReentrantMutex
    private let totalEnqueued: AtomicInt64
    private let totalBatches: AtomicInt64

    public init(batchSize: Int64, batchTimeout: Duration) {
        this.batchSize = batchSize
        this.batchTimeout = batchTimeout
        this.pendingBatch = ArrayList<Envelope>()
        this.closed = AtomicBool(false)
        this.batchMutex = ReentrantMutex()
        this.totalEnqueued = AtomicInt64(0)
        this.totalBatches = AtomicInt64(0)
        this.lastBatchTime = AtomicInt64(DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000)
    }

    public func enqueue(envelope: Envelope): Bool {
        if (closed.load()) {
            return false
        }

        batchMutex.lock()
        try {
            pendingBatch.append(envelope)
            totalEnqueued.fetchAdd(1)
            return true
        } finally {
            batchMutex.unlock()
        }
    }

    public func dequeue(): Option<Envelope> {
        // 批量邮箱不支持单个消息出队
        // 应该使用 processBatch() 方法
        None
    }

    /**
     * 处理批次消息
     * @return 当前批次的所有消息
     */
    public func processBatch(): Array<Envelope> {
        let now = getCurrentTimeNanos()
        let shouldFlush = shouldFlushBatch(now)
        
        if (!shouldFlush) {
            return Array<Envelope>()
        }

        batchMutex.lock()
        try {
            if (pendingBatch.isEmpty()) {
                return Array<Envelope>()
            }

            let batch = pendingBatch.toArray()
            pendingBatch.clear()
            lastBatchTime.store(now)
            totalBatches.fetchAdd(1)
            
            return batch
        } finally {
            batchMutex.unlock()
        }
    }

    private func shouldFlushBatch(now: Int64): Bool {
        batchMutex.lock()
        try {
            let currentSize = pendingBatch.size
            let timeSinceLastBatch = now - lastBatchTime.load()
            
            return currentSize >= batchSize || 
                   (currentSize > 0 && timeSinceLastBatch > batchTimeout.toMilliseconds() * 1_000_000)
        } finally {
            batchMutex.unlock()
        }
    }

    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000  // 简化实现
    }

    public func isEmpty(): Bool {
        batchMutex.lock()
        try {
            pendingBatch.isEmpty()
        } finally {
            batchMutex.unlock()
        }
    }

    public func size(): Int64 {
        batchMutex.lock()
        try {
            Int64(pendingBatch.size)
        } finally {
            batchMutex.unlock()
        }
    }

    public func clear(): Unit {
        batchMutex.lock()
        try {
            pendingBatch.clear()
        } finally {
            batchMutex.unlock()
        }
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
    }

    public func getBatchSize(): Int64 {
        batchSize
    }

    public func getBatchTimeout(): Duration {
        batchTimeout
    }

    public func getTotalEnqueued(): Int64 {
        totalEnqueued.load()
    }

    public func getTotalBatches(): Int64 {
        totalBatches.load()
    }

    public func getAverageBatchSize(): Float64 {
        let batches = totalBatches.load()
        if (batches == 0) {
            return 0.0
        }
        Float64(totalEnqueued.load()) / Float64(batches)
    }
}

/**
 * 自适应批量处理邮箱
 * 根据处理性能自动调整批次大小
 */
public class AdaptiveBatchingMailbox <: Mailbox {
    private let innerMailbox: BatchingMailbox
    private let minBatchSize: Int64
    private let maxBatchSize: Int64
    private let currentBatchSize: AtomicInt64
    private let avgProcessingTime: AtomicInt64
    private let targetLatency: Duration
    private let adjustmentCounter: AtomicInt64

    public init(minBatchSize: Int64, maxBatchSize: Int64, 
                batchTimeout: Duration, targetLatency: Duration) {
        this.minBatchSize = minBatchSize
        this.maxBatchSize = maxBatchSize
        this.currentBatchSize = AtomicInt64(minBatchSize)
        this.targetLatency = targetLatency
        this.avgProcessingTime = AtomicInt64(0)
        this.adjustmentCounter = AtomicInt64(0)
        
        // 使用当前批次大小创建内部邮箱
        this.innerMailbox = BatchingMailbox(minBatchSize, batchTimeout)
    }

    public func enqueue(envelope: Envelope): Bool {
        innerMailbox.enqueue(envelope)
    }

    public func dequeue(): Option<Envelope> {
        innerMailbox.dequeue()
    }

    public func processBatch(): Array<Envelope> {
        let startTime = getCurrentTimeNanos()
        let batch = innerMailbox.processBatch()
        
        if (!batch.isEmpty()) {
            let endTime = getCurrentTimeNanos()
            let processingTime = endTime - startTime
            
            updateAverageProcessingTime(processingTime)
            adjustBatchSize(processingTime)
        }
        
        return batch
    }

    private func updateAverageProcessingTime(processingTime: Int64): Unit {
        let currentAvg = avgProcessingTime.load()
        let newAvg = if (currentAvg == 0) {
            processingTime
        } else {
            (currentAvg * 9 + processingTime) / 10  // 指数移动平均
        }
        avgProcessingTime.store(newAvg)
    }

    private func adjustBatchSize(processingTime: Int64): Unit {
        let adjustmentCount = adjustmentCounter.fetchAdd(1)
        
        // 每10次处理后调整一次批次大小
        if (adjustmentCount % 10 != 0) {
            return
        }

        let currentAvg = avgProcessingTime.load()
        let targetNanos = targetLatency.toMilliseconds() * 1_000_000
        let currentSize = currentBatchSize.load()

        if (currentAvg > targetNanos) {
            // 处理时间过长，减小批次
            let newSize = max(minBatchSize, currentSize * 8 / 10)
            if (newSize != currentSize) {
                currentBatchSize.store(newSize)
                println("减小批次大小: ${currentSize} -> ${newSize}")
            }
        } else if (currentAvg < targetNanos / 2) {
            // 处理时间很短，增大批次
            let newSize = min(maxBatchSize, currentSize * 12 / 10)
            if (newSize != currentSize) {
                currentBatchSize.store(newSize)
                println("增大批次大小: ${currentSize} -> ${newSize}")
            }
        }
    }

    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000
    }

    public func isEmpty(): Bool {
        innerMailbox.isEmpty()
    }

    public func size(): Int64 {
        innerMailbox.size()
    }

    public func clear(): Unit {
        innerMailbox.clear()
    }

    public func isClosed(): Bool {
        innerMailbox.isClosed()
    }

    public func close(): Unit {
        innerMailbox.close()
    }

    public func getCurrentBatchSize(): Int64 {
        currentBatchSize.load()
    }

    public func getAverageProcessingTime(): Int64 {
        avgProcessingTime.load()
    }

    public func getTargetLatency(): Duration {
        targetLatency
    }
}

/**
 * 批量处理器
 * 用于处理批量消息的工具类
 */
public class BatchProcessor {
    private let processingFunction: (Array<Envelope>) -> Unit
    private let errorHandler: (Exception) -> Unit

    public init(processingFunction: (Array<Envelope>) -> Unit,
                errorHandler: (Exception) -> Unit) {
        this.processingFunction = processingFunction
        this.errorHandler = errorHandler
    }

    public func processBatch(batch: Array<Envelope>): Unit {
        if (batch.isEmpty()) {
            return
        }

        try {
            processingFunction(batch)
        } catch (e: Exception) {
            errorHandler(e)
        }
    }

    public func processWithMetrics(batch: Array<Envelope>): BatchProcessingMetrics {
        let startTime = getCurrentTimeNanos()
        var errorCount: Int64 = 0
        
        try {
            processingFunction(batch)
        } catch (e: Exception) {
            errorCount = 1
            errorHandler(e)
        }
        
        let endTime = getCurrentTimeNanos()
        let processingTime = endTime - startTime
        
        BatchProcessingMetrics(
            Int64(batch.size),
            processingTime,
            errorCount,
            calculateThroughput(Int64(batch.size), processingTime)
        )
    }

    private func calculateThroughput(batchSize: Int64, processingTimeNanos: Int64): Float64 {
        if (processingTimeNanos == 0) {
            return 0.0
        }
        let processingTimeSeconds = Float64(processingTimeNanos) / 1_000_000_000.0
        Float64(batchSize) / processingTimeSeconds
    }

    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000
    }
}

/**
 * 批处理性能指标
 */
public struct BatchProcessingMetrics {
    public let batchSize: Int64
    public let processingTime: Int64  // 纳秒
    public let errorCount: Int64
    public let throughput: Float64    // 消息/秒

    public init(batchSize: Int64, processingTime: Int64, errorCount: Int64, throughput: Float64) {
        this.batchSize = batchSize
        this.processingTime = processingTime
        this.errorCount = errorCount
        this.throughput = throughput
    }

    public func getProcessingTimeMs(): Float64 {
        Float64(processingTime) / 1_000_000.0
    }

    public func hasErrors(): Bool {
        errorCount > 0
    }
}
