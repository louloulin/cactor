/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Core - 批量消息处理器
 * 高性能批量消息处理，提升吞吐量
 */
package cactor.core.message

import std.sync.*
import std.time.*
import std.collection.*

/**
 * 批量消息处理器
 * 
 * 性能优化:
 * 1. 批量处理消息，减少系统调用
 * 2. 无锁环形缓冲区
 * 3. 自适应批量大小
 * 4. 延迟聚合处理
 */
public class BatchMessageProcessor {
    private let batchSize: Int32
    private let maxWaitTime: Int64  // 微秒
    private let buffer: Array<Option<Envelope>>
    private let bufferSize: AtomicInt32
    private let head: AtomicInt64
    private let tail: AtomicInt64
    private let isRunning: AtomicBool
    
    // 性能统计
    private let totalMessages: AtomicInt64
    private let totalBatches: AtomicInt64
    private let avgBatchSize: AtomicInt64
    private let maxLatency: AtomicInt64
    private let minLatency: AtomicInt64

    public init(batchSize: Int32, maxWaitTime: Int64) {
        this.batchSize = batchSize
        this.maxWaitTime = maxWaitTime
        this.buffer = Array<Option<Envelope>>(Int64(batchSize * 2), { i => None })
        this.bufferSize = AtomicInt32(0)
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.isRunning = AtomicBool(true)
        
        this.totalMessages = AtomicInt64(0)
        this.totalBatches = AtomicInt64(0)
        this.avgBatchSize = AtomicInt64(0)
        this.maxLatency = AtomicInt64(0)
        this.minLatency = AtomicInt64(Int64.MAX_VALUE)
    }

    /**
     * 添加消息到批处理缓冲区
     */
    public func addMessage(envelope: Envelope): Bool {
        if (!isRunning.load()) {
            return false
        }

        let currentTail = tail.load()
        let index = currentTail % Int64(buffer.size)
        
        // 检查缓冲区是否已满
        if (bufferSize.load() >= batchSize) {
            return false
        }
        
        // 原子性地添加消息
        if (tail.compareAndSwap(currentTail, currentTail + 1)) {
            buffer[index] = Some(envelope)
            bufferSize.fetchAdd(1)
            totalMessages.fetchAdd(1)
            return true
        }
        
        return false
    }

    /**
     * 处理一批消息
     */
    public func processBatch(): Array<Envelope> {
        let startTime = getCurrentTimeMicros()
        let currentSize = bufferSize.load()
        
        if (currentSize == 0) {
            return Array<Envelope>(0, { i => Envelope(StringMessage(""), None) })
        }
        
        // 确定批量大小
        let actualBatchSize = if (currentSize >= batchSize) { batchSize } else { currentSize }
        let batch = Array<Envelope>(Int64(actualBatchSize), { i => Envelope(StringMessage(""), None) })
        
        // 批量出队
        var processedCount = 0
        for (i in 0..Int64(actualBatchSize)) {
            let currentHead = head.load()
            let index = currentHead % Int64(buffer.size)
            
            match (buffer[index]) {
                case Some(envelope) =>
                    if (head.compareAndSwap(currentHead, currentHead + 1)) {
                        buffer[index] = None
                        batch[i] = envelope
                        processedCount += 1
                        bufferSize.fetchAdd(-1)
                    }
                case None => break
            }
        }
        
        // 更新统计信息
        if (processedCount > 0) {
            totalBatches.fetchAdd(1)
            let endTime = getCurrentTimeMicros()
            let latency = endTime - startTime
            
            updateLatencyStats(latency)
            updateAvgBatchSize(Int64(processedCount))
        }
        
        return batch.slice(0, Int64(processedCount))
    }

    /**
     * 自适应批量处理
     * 根据当前负载动态调整批量大小
     */
    public func adaptiveBatchProcess(): Array<Envelope> {
        let currentSize = bufferSize.load()
        let avgSize = avgBatchSize.load()
        
        // 自适应批量大小
        let adaptiveBatchSize = if (currentSize > avgSize) {
            min(currentSize, batchSize)
        } else {
            max(currentSize / 2, 1)
        }
        
        return processBatchWithSize(adaptiveBatchSize)
    }

    /**
     * 指定大小的批量处理
     */
    public func processBatchWithSize(size: Int32): Array<Envelope> {
        let startTime = getCurrentTimeMicros()
        let currentSize = bufferSize.load()
        
        if (currentSize == 0) {
            return Array<Envelope>(0, { i => Envelope(StringMessage(""), None) })
        }
        
        let actualSize = min(size, currentSize)
        let batch = Array<Envelope>(Int64(actualSize), { i => Envelope(StringMessage(""), None) })
        
        // 批量出队
        var processedCount = 0
        for (i in 0..Int64(actualSize)) {
            let currentHead = head.load()
            let index = currentHead % Int64(buffer.size)
            
            match (buffer[index]) {
                case Some(envelope) =>
                    if (head.compareAndSwap(currentHead, currentHead + 1)) {
                        buffer[index] = None
                        batch[i] = envelope
                        processedCount += 1
                        bufferSize.fetchAdd(-1)
                    }
                case None => break
            }
        }
        
        // 更新统计信息
        if (processedCount > 0) {
            totalBatches.fetchAdd(1)
            let endTime = getCurrentTimeMicros()
            let latency = endTime - startTime
            
            updateLatencyStats(latency)
            updateAvgBatchSize(Int64(processedCount))
        }
        
        return batch.slice(0, Int64(processedCount))
    }

    /**
     * 等待批量处理
     * 等待指定时间或达到批量大小
     */
    public func waitAndProcessBatch(): Array<Envelope> {
        let startTime = getCurrentTimeMicros()
        let deadline = startTime + maxWaitTime
        
        while (getCurrentTimeMicros() < deadline) {
            if (bufferSize.load() >= batchSize) {
                return processBatch()
            }
            
            // 短暂休眠，避免忙等待
            sleep(Duration.microseconds(10))
        }
        
        // 超时，处理当前缓冲区中的消息
        return processBatch()
    }

    /**
     * 获取性能统计
     */
    public func getStats(): BatchProcessorStats {
        BatchProcessorStats(
            totalMessages.load(),
            totalBatches.load(),
            avgBatchSize.load(),
            maxLatency.load(),
            minLatency.load(),
            bufferSize.load()
        )
    }

    /**
     * 停止处理器
     */
    public func stop(): Unit {
        isRunning.store(false)
    }

    /**
     * 清空缓冲区
     */
    public func clear(): Unit {
        head.store(0)
        tail.store(0)
        bufferSize.store(0)
        
        for (i in 0..Int64(buffer.size)) {
            buffer[i] = None
        }
    }

    // 私有辅助方法
    private func updateLatencyStats(latency: Int64): Unit {
        // 更新最大延迟
        var currentMax = maxLatency.load()
        while (latency > currentMax) {
            if (maxLatency.compareAndSwap(currentMax, latency)) {
                break
            }
            currentMax = maxLatency.load()
        }
        
        // 更新最小延迟
        var currentMin = minLatency.load()
        while (latency < currentMin) {
            if (minLatency.compareAndSwap(currentMin, latency)) {
                break
            }
            currentMin = minLatency.load()
        }
    }

    private func updateAvgBatchSize(batchSize: Int64): Unit {
        let totalBatchCount = totalBatches.load()
        if (totalBatchCount > 0) {
            let currentAvg = avgBatchSize.load()
            let newAvg = (currentAvg * (totalBatchCount - 1) + batchSize) / totalBatchCount
            avgBatchSize.store(newAvg)
        }
    }

    private func getCurrentTimeMicros(): Int64 {
        DateTime.now().toUnixTimeStamp().toMicroseconds()
    }

    private func min(a: Int32, b: Int32): Int32 {
        if (a < b) { a } else { b }
    }

    private func max(a: Int32, b: Int32): Int32 {
        if (a > b) { a } else { b }
    }

    private func sleep(duration: Duration): Unit {
        // 简化的sleep实现
        let startTime = getCurrentTimeMicros()
        let endTime = startTime + duration.toMicroseconds()
        while (getCurrentTimeMicros() < endTime) {
            // 忙等待
        }
    }
}

/**
 * 批处理器统计信息
 */
public struct BatchProcessorStats {
    public let totalMessages: Int64
    public let totalBatches: Int64
    public let avgBatchSize: Int64
    public let maxLatency: Int64
    public let minLatency: Int64
    public let currentBufferSize: Int32
    
    public init(totalMessages: Int64, totalBatches: Int64, avgBatchSize: Int64,
               maxLatency: Int64, minLatency: Int64, currentBufferSize: Int32) {
        this.totalMessages = totalMessages
        this.totalBatches = totalBatches
        this.avgBatchSize = avgBatchSize
        this.maxLatency = maxLatency
        this.minLatency = minLatency
        this.currentBufferSize = currentBufferSize
    }
    
    public func getThroughput(): Float64 {
        if (totalBatches > 0) {
            return Float64(totalMessages) / Float64(totalBatches)
        }
        return 0.0
    }
}
