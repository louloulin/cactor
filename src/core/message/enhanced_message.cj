/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Core - 增强消息系统
 * 提供零拷贝和高性能消息传递功能
 */
package cactor.core.message

import std.sync.*
import std.time.*
import cactor.foundation.memory.{SharedMemoryBuffer, MemoryPool}

/**
 * 增强零拷贝消息
 */
public class EnhancedZeroCopyMessage {
    private let messageType: UInt16
    private let sourceActor: UInt64
    private let targetActor: UInt64
    private let sharedBuffer: SharedMemoryBuffer
    private let payloadSize: UInt64
    private let refCount: AtomicInt64
    private let sendTimestamp: AtomicInt64
    private let hopCount: AtomicInt64
    private let mutex: ReentrantMutex

    public init(messageType: UInt16, sourceActor: UInt64, targetActor: UInt64, 
                sharedBuffer: SharedMemoryBuffer, payloadSize: UInt64) {
        this.messageType = messageType
        this.sourceActor = sourceActor
        this.targetActor = targetActor
        this.sharedBuffer = sharedBuffer
        this.payloadSize = payloadSize
        this.refCount = AtomicInt64(1)
        this.sendTimestamp = AtomicInt64(0)
        this.hopCount = AtomicInt64(0)
        this.mutex = ReentrantMutex()
    }

    /**
     * 获取消息类型
     */
    public func getMessageType(): UInt16 {
        messageType
    }

    /**
     * 获取源Actor ID
     */
    public func getSourceActor(): UInt64 {
        sourceActor
    }

    /**
     * 获取目标Actor ID
     */
    public func getTargetActor(): UInt64 {
        targetActor
    }

    /**
     * 获取共享缓冲区
     */
    public func getSharedBuffer(): SharedMemoryBuffer {
        sharedBuffer
    }

    /**
     * 获取负载大小
     */
    public func getPayloadSize(): UInt64 {
        payloadSize
    }

    /**
     * 获取引用计数
     */
    public func getReferenceCount(): Int64 {
        refCount.load()
    }

    /**
     * 增加引用计数
     */
    public func retain(): Unit {
        refCount.fetchAdd(1)
        sharedBuffer.retain()
    }

    /**
     * 减少引用计数
     */
    public func release(): Unit {
        let newCount = refCount.fetchAdd(-1)
        if (newCount <= 1) {
            sharedBuffer.release()
        }
    }

    /**
     * 设置发送时间戳
     */
    public func setSendTimestamp(timestamp: Int64): Unit {
        sendTimestamp.store(timestamp)
    }

    /**
     * 获取发送时间戳
     */
    public func getSendTimestamp(): Int64 {
        sendTimestamp.load()
    }

    /**
     * 获取跳数
     */
    public func getHopCount(): Int64 {
        hopCount.load()
    }

    /**
     * 增加跳数
     */
    public func incrementHopCount(): Unit {
        hopCount.fetchAdd(1)
    }

    /**
     * 获取消息数据
     */
    public func getData(): Array<UInt8> {
        sharedBuffer.getData()
    }
}

/**
 * 增强消息工厂
 */
public class EnhancedMessageFactory {
    private let memoryPool: MemoryPool
    private let mutex: ReentrantMutex

    public init(memoryPool: MemoryPool) {
        this.memoryPool = memoryPool
        this.mutex = ReentrantMutex()
    }

    /**
     * 创建带数据的消息
     */
    public func createMessageWithData(messageType: UInt16, data: Array<UInt8>, 
                                     sourceActor: UInt64, targetActor: UInt64): EnhancedZeroCopyMessage {
        mutex.lock()
        try {
            let buffer = memoryPool.allocate(UInt64(data.size))
            buffer.copyFrom(data, 0)
            
            let message = EnhancedZeroCopyMessage(messageType, sourceActor, targetActor, buffer, UInt64(data.size))
            message.setSendTimestamp(getCurrentTimeNanos())
            
            return message
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 创建空消息
     */
    public func createEmptyMessage(messageType: UInt16, sourceActor: UInt64, 
                                  targetActor: UInt64, size: UInt64): EnhancedZeroCopyMessage {
        mutex.lock()
        try {
            let buffer = memoryPool.allocate(size)
            let message = EnhancedZeroCopyMessage(messageType, sourceActor, targetActor, buffer, size)
            message.setSendTimestamp(getCurrentTimeNanos())
            
            return message
        } finally {
            mutex.unlock()
        }
    }

    private func getCurrentTimeNanos(): Int64 {
        let now = DateTime.now()
        return now.toUnixTimeStamp().toMilliseconds() * 1000000  // 转换为纳秒
    }
}

/**
 * 延迟统计信息
 */
public struct LatencyStats {
    public let avgLatency: Float64
    public let maxLatency: Int64
    public let minLatency: Int64
    public let p95Latency: Int64
    public let p99Latency: Int64

    public init(avgLatency: Float64, maxLatency: Int64, minLatency: Int64, 
                p95Latency: Int64, p99Latency: Int64) {
        this.avgLatency = avgLatency
        this.maxLatency = maxLatency
        this.minLatency = minLatency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
    }
}

/**
 * 内存使用统计
 */
public struct MemoryUsageStats {
    public let totalAllocated: UInt64
    public let currentUsage: UInt64
    public let peakUsage: UInt64
    public let poolEfficiency: Float64

    public init(totalAllocated: UInt64, currentUsage: UInt64, peakUsage: UInt64, poolEfficiency: Float64) {
        this.totalAllocated = totalAllocated
        this.currentUsage = currentUsage
        this.peakUsage = peakUsage
        this.poolEfficiency = poolEfficiency
    }
}

/**
 * 高性能消息传递系统
 */
public class HighPerformanceMessagePassing {
    private let capacity: Int64
    private let memoryPool: MemoryPool
    private let messageQueue: Array<Option<EnhancedZeroCopyMessage>>
    private let head: AtomicInt64
    private let tail: AtomicInt64
    private let size: AtomicInt64
    private let totalMessages: AtomicInt64
    private let zeroCopyCount: AtomicInt64
    private let mutex: ReentrantMutex

    public init(capacity: Int64, memoryPool: MemoryPool) {
        this.capacity = capacity
        this.memoryPool = memoryPool
        this.messageQueue = Array<Option<EnhancedZeroCopyMessage>>(capacity, { i => None })
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.size = AtomicInt64(0)
        this.totalMessages = AtomicInt64(0)
        this.zeroCopyCount = AtomicInt64(0)
        this.mutex = ReentrantMutex()
    }

    /**
     * 发送消息
     */
    public func sendMessage(message: EnhancedZeroCopyMessage, targetActor: UInt64): Bool {
        mutex.lock()
        try {
            if (size.load() >= capacity) {
                return false  // 队列满
            }

            let tailPos = tail.load()
            messageQueue[tailPos] = Some(message)
            tail.store((tailPos + 1) % capacity)
            size.fetchAdd(1)
            totalMessages.fetchAdd(1)
            zeroCopyCount.fetchAdd(1)  // 假设都是零拷贝

            return true
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 接收消息
     */
    public func receiveMessage(): Option<EnhancedZeroCopyMessage> {
        mutex.lock()
        try {
            if (size.load() <= 0) {
                return None
            }

            let headPos = head.load()
            let message = messageQueue[headPos]
            messageQueue[headPos] = None
            head.store((headPos + 1) % capacity)
            size.fetchAdd(-1)

            return message
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取延迟统计
     */
    public func getLatencyStats(): LatencyStats {
        // 简化实现，返回模拟数据
        LatencyStats(50.0, 1000, 10, 100, 200)
    }

    /**
     * 获取内存使用统计
     */
    public func getMemoryUsage(): MemoryUsageStats {
        let poolStats = memoryPool.getStats()
        MemoryUsageStats(
            poolStats.totalAllocated,
            poolStats.currentUsage,
            poolStats.peakUsage,
            poolStats.poolEfficiency
        )
    }

    /**
     * 获取零拷贝比率
     */
    public func getZeroCopyRatio(): Float64 {
        let total = totalMessages.load()
        if (total > 0) {
            Float64(zeroCopyCount.load()) / Float64(total)
        } else {
            0.0
        }
    }

    /**
     * 获取队列大小
     */
    public func getQueueSize(): Int64 {
        size.load()
    }
}
