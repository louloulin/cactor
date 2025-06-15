/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 2: 增强消息传递系统
 * 基于共享内存和零拷贝技术的高性能消息传递实现
 */
package cactor.core.zerocopy

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.message.*
import cactor.mailbox.lockfree.*

// 零拷贝消息适配器
public class ZeroCopyMessageAdapter {
    private let messageMap: HashMap<Int64, EnhancedZeroCopyMessage>
    private let mutex: ReentrantMutex
    private let nextId: AtomicInt64

    public init() {
        this.messageMap = HashMap<Int64, EnhancedZeroCopyMessage>()
        this.mutex = ReentrantMutex()
        this.nextId = AtomicInt64(1)
    }

    public func storeMessage(message: EnhancedZeroCopyMessage): Int64 {
        let id = nextId.fetchAdd(1)
        mutex.lock()
        messageMap.put(id, message)
        mutex.unlock()
        return id
    }

    public func retrieveMessage(id: Int64): Option<EnhancedZeroCopyMessage> {
        mutex.lock()
        let message = messageMap.get(id)
        if (message.isSome()) {
            messageMap.remove(id)
        }
        mutex.unlock()
        return message
    }
}

// 零拷贝消息包装器
public class ZeroCopyWrapperMessage <: Message {
    private let wrappedMessageId: Int64

    public init(messageId: Int64) {
        this.wrappedMessageId = messageId
    }

    public func messageType(): String {
        return "ZeroCopyWrapper"
    }

    public func getWrappedMessageId(): Int64 {
        return wrappedMessageId
    }
}

// 增强的消息传递接口
public interface EnhancedMessagePassing {
    func sendMessage(message: EnhancedZeroCopyMessage, targetActor: UInt64): Bool
    func receiveMessage(): Option<EnhancedZeroCopyMessage>
    func getMessageCount(): Int64
    func getThroughput(): Float64
    func getLatencyStats(): LatencyStats
    func getMemoryUsage(): MemoryUsageStats
    func getZeroCopyRatio(): Float64
}

// 延迟统计
public struct LatencyStats {
    public let avgLatency: Float64
    public let p50Latency: Float64
    public let p95Latency: Float64
    public let p99Latency: Float64
    public let maxLatency: Float64
    
    public init(avgLatency: Float64, p50Latency: Float64, p95Latency: Float64, p99Latency: Float64, maxLatency: Float64) {
        this.avgLatency = avgLatency
        this.p50Latency = p50Latency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
        this.maxLatency = maxLatency
    }
}

// 内存使用统计
public struct MemoryUsageStats {
    public let totalAllocated: UInt64
    public let totalUsed: UInt64
    public let poolEfficiency: Float64
    public let zeroCopyRatio: Float64
    
    public init(totalAllocated: UInt64, totalUsed: UInt64, poolEfficiency: Float64, zeroCopyRatio: Float64) {
        this.totalAllocated = totalAllocated
        this.totalUsed = totalUsed
        this.poolEfficiency = poolEfficiency
        this.zeroCopyRatio = zeroCopyRatio
    }
}

// 增强的零拷贝消息
public interface EnhancedZeroCopyMessage <: ZeroCopyMessage {
    func getSharedBuffer(): SharedMemoryBuffer
    func getSendTimestamp(): Int64
    func setSendTimestamp(timestamp: Int64): Unit
    func getHopCount(): Int32
    func incrementHopCount(): Unit
}

// 增强的零拷贝消息实现
public class EnhancedZeroCopyMessageImpl <: EnhancedZeroCopyMessage {
    private let baseMessage: ZeroCopyMessageImpl
    private let sharedBuffer: SharedMemoryBuffer
    private var sendTimestamp: Int64
    private let hopCount: AtomicInt32

    public init(messageType: UInt16, sourceActor: UInt64, targetActor: UInt64, sharedBuffer: SharedMemoryBuffer) {
        this.baseMessage = ZeroCopyMessageImpl(messageType, sharedBuffer.getSize(), sourceActor, targetActor, None)
        this.sharedBuffer = sharedBuffer
        this.sendTimestamp = getCurrentTimeNanos()
        this.hopCount = AtomicInt32(0)
    }

    // 实现 ZeroCopyMessage 接口
    public func getMessageId(): UInt64 { baseMessage.getMessageId() }
    public func getPayloadSize(): UInt64 { baseMessage.getPayloadSize() }
    public func getTimestamp(): Int64 { baseMessage.getTimestamp() }
    public func getSourceActor(): UInt64 { baseMessage.getSourceActor() }
    public func getTargetActor(): UInt64 { baseMessage.getTargetActor() }
    public func getPayloadPtr(): Option<Array<UInt8>> { Some(sharedBuffer.getData()) }
    public func release(): Unit { 
        baseMessage.release()
        sharedBuffer.release()
    }
    public func retain(): Unit { 
        baseMessage.retain()
        sharedBuffer.retain()
    }
    public func getReferenceCount(): Int32 { baseMessage.getReferenceCount() }
    public func isValid(): Bool { baseMessage.isValid() && sharedBuffer.isValid() }
    public func getChecksum(): UInt64 { baseMessage.getChecksum() }
    public func messageType(): String { baseMessage.messageType() }
    public func toString(): String { baseMessage.toString() }

    // 实现 EnhancedZeroCopyMessage 接口
    public func getSharedBuffer(): SharedMemoryBuffer { sharedBuffer }
    public func getSendTimestamp(): Int64 { sendTimestamp }
    public func setSendTimestamp(timestamp: Int64): Unit { this.sendTimestamp = timestamp }
    public func getHopCount(): Int32 { hopCount.load() }
    public func incrementHopCount(): Unit { hopCount.fetchAdd(1) }
}

// 高性能消息传递实现
public class HighPerformanceMessagePassing <: EnhancedMessagePassing {
    private let messageQueue: LockFreeRingBufferMailbox
    private let messageAdapter: ZeroCopyMessageAdapter
    private let memoryPool: HighPerformanceMemoryPool
    private let messageCount: AtomicInt64
    private let zeroCopyCount: AtomicInt64
    private let totalLatency: AtomicInt64
    private let latencyMeasurements: ArrayList<Int64>
    private let latencyMutex: ReentrantMutex
    private let startTime: Int64

    public init(queueCapacity: Int64, memoryPool: HighPerformanceMemoryPool) {
        this.messageQueue = LockFreeRingBufferMailbox(queueCapacity)
        this.messageAdapter = ZeroCopyMessageAdapter()
        this.memoryPool = memoryPool
        this.messageCount = AtomicInt64(0)
        this.zeroCopyCount = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
        this.latencyMeasurements = ArrayList<Int64>()
        this.latencyMutex = ReentrantMutex()
        this.startTime = getCurrentTimeNanos()
    }
    
    public func sendMessage(message: EnhancedZeroCopyMessage, targetActor: UInt64): Bool {
        let sendTime = getCurrentTimeNanos()
        message.setSendTimestamp(sendTime)

        // 将零拷贝消息存储到适配器中
        let messageId = messageAdapter.storeMessage(message)

        // 创建包装消息的Envelope
        let wrapperMessage = ZeroCopyWrapperMessage(messageId)
        let envelope = Envelope(wrapperMessage, None)

        let success = messageQueue.enqueue(envelope)
        if (success) {
            messageCount.fetchAdd(1)
            // 如果使用共享内存缓冲区，计为零拷贝
            if (message.getSharedBuffer().isValid()) {
                zeroCopyCount.fetchAdd(1)
            }
        }

        return success
    }
    
    public func receiveMessage(): Option<EnhancedZeroCopyMessage> {
        let receiveTime = getCurrentTimeNanos()

        match (messageQueue.dequeue()) {
            case Some(envelope) =>
                // 从Envelope中提取包装消息
                match (envelope.getMessage()) {
                    case wrapper: ZeroCopyWrapperMessage =>
                        let messageId = wrapper.getWrappedMessageId()
                        match (messageAdapter.retrieveMessage(messageId)) {
                            case Some(zeroCopyMessage) =>
                                // 计算延迟
                                let latency = receiveTime - zeroCopyMessage.getSendTimestamp()
                                recordLatency(latency)
                                zeroCopyMessage.incrementHopCount()
                                return Some(zeroCopyMessage)
                            case None =>
                                return None
                        }
                    case _ =>
                        return None
                }
            case None =>
                return None
        }
    }
    
    public func getMessageCount(): Int64 {
        messageCount.load()
    }
    
    public func getThroughput(): Float64 {
        let currentTime = getCurrentTimeNanos()
        let elapsedTime = currentTime - startTime
        let messageCount = getMessageCount()
        
        if (elapsedTime > 0) {
            return Float64(messageCount) / (Float64(elapsedTime) / 1_000_000_000.0)  // 消息/秒
        } else {
            return 0.0
        }
    }
    
    public func getZeroCopyRatio(): Float64 {
        let total = messageCount.load()
        let zeroCopy = zeroCopyCount.load()
        
        if (total > 0) {
            return Float64(zeroCopy) / Float64(total)
        } else {
            return 0.0
        }
    }
    
    public func getLatencyStats(): LatencyStats {
        latencyMutex.lock()

        if (latencyMeasurements.isEmpty()) {
            latencyMutex.unlock()
            return LatencyStats(0.0, 0.0, 0.0, 0.0, 0.0)
        }

        // 简化统计计算
        let count = latencyMeasurements.size
        var sum: Int64 = 0
        var maxLatency: Int64 = 0
        var minLatency: Int64 = 9223372036854775807

        for (i in 0..count) {
            let latency = latencyMeasurements[i]
            sum += latency
            if (latency > maxLatency) {
                maxLatency = latency
            }
            if (latency < minLatency) {
                minLatency = latency
            }
        }

        latencyMutex.unlock()

        let avgLatency = Float64(sum) / Float64(count)
        let p50Latency = avgLatency  // 简化实现
        let p95Latency = Float64(maxLatency) * 0.95
        let p99Latency = Float64(maxLatency) * 0.99
        let maxLatencyFloat = Float64(maxLatency)

        return LatencyStats(avgLatency, p50Latency, p95Latency, p99Latency, maxLatencyFloat)
    }
    
    public func getMemoryUsage(): MemoryUsageStats {
        let stats = memoryPool.getStats()
        let zeroCopyRatio = getZeroCopyRatio()
        let poolEfficiency = 1.0 - stats.fragmentation
        
        return MemoryUsageStats(
            stats.totalAllocated,
            stats.totalUsed,
            poolEfficiency,
            zeroCopyRatio
        )
    }
    
    private func recordLatency(latency: Int64): Unit {
        totalLatency.fetchAdd(latency)

        latencyMutex.lock()
        latencyMeasurements.append(latency)

        // 限制测量数据的大小
        if (latencyMeasurements.size > 10000) {
            latencyMeasurements.clear()  // 简化实现：清空列表
        }

        latencyMutex.unlock()
    }
}

// 消息工厂
public class EnhancedMessageFactory {
    private let memoryPool: HighPerformanceMemoryPool
    private let messageIdCounter: AtomicInt64
    
    public init(memoryPool: HighPerformanceMemoryPool) {
        this.memoryPool = memoryPool
        this.messageIdCounter = AtomicInt64(0)
    }
    
    public func createMessage(messageType: UInt16, payloadSize: UInt64, sourceActor: UInt64, targetActor: UInt64): EnhancedZeroCopyMessageImpl {
        let sharedBuffer = memoryPool.allocate(payloadSize)
        return EnhancedZeroCopyMessageImpl(messageType, sourceActor, targetActor, sharedBuffer)
    }
    
    public func createMessageWithData(messageType: UInt16, data: Array<UInt8>, sourceActor: UInt64, targetActor: UInt64): EnhancedZeroCopyMessageImpl {
        let sharedBuffer = memoryPool.allocate(UInt64(data.size))
        
        // 将数据复制到共享缓冲区
        let bufferData = sharedBuffer.getData()
        for (i in 0..data.size) {
            bufferData[i] = data[i]
        }
        
        return EnhancedZeroCopyMessageImpl(messageType, sourceActor, targetActor, sharedBuffer)
    }
}
