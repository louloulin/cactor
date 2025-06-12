/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 优化的消息传递路径
 * 高性能、低延迟的零拷贝消息传递系统
 */
package cactor.core.zerocopy

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import cactor.core.memory.*

// 消息传递策略
public enum MessagePassingStrategy {
    | DirectCopy      // 直接拷贝（小消息）
    | ZeroCopy        // 零拷贝（大消息）
    | SharedMemory    // 共享内存（跨进程）
    | Batched         // 批量传递
}

// 消息传递配置
public struct MessagePassingConfig {
    public let zeroCopyThreshold: UInt64      // 零拷贝阈值
    public let batchSize: Int64               // 批量大小
    public let maxLatency: Int64              // 最大延迟（微秒）
    public let enableCompression: Bool        // 启用压缩
    public let enableChecksum: Bool           // 启用校验和
    
    public init(zeroCopyThreshold: UInt64, batchSize: Int64, maxLatency: Int64, 
                enableCompression: Bool, enableChecksum: Bool) {
        this.zeroCopyThreshold = zeroCopyThreshold
        this.batchSize = batchSize
        this.maxLatency = maxLatency
        this.enableCompression = enableCompression
        this.enableChecksum = enableChecksum
    }
}

// 优化的消息传递器
public class OptimizedMessagePasser {
    private let config: MessagePassingConfig
    private let memoryPool: NumaAwareMemoryPool
    private let serializer: HighPerfMessageSerializer
    private let bufferPool: SerializationBufferPool
    private let metrics: MessagePassingMetrics
    private let batchProcessor: BatchMessageProcessor
    
    public init(config: MessagePassingConfig, memoryPool: NumaAwareMemoryPool) {
        this.config = config
        this.memoryPool = memoryPool
        this.bufferPool = SerializationBufferPool(1000, 8192)
        this.serializer = HighPerfMessageSerializer(bufferPool, config.enableCompression)
        this.metrics = MessagePassingMetrics()
        this.batchProcessor = BatchMessageProcessor(config.batchSize, config.maxLatency)
    }
    
    // 发送消息（主要接口）
    public func sendMessage(message: ZeroCopyMessageImpl, target: Actor): MessagePassingResult {
        let startTime = getCurrentTimeMicros()
        
        // 选择传递策略
        let strategy = selectStrategy(message)
        
        // 根据策略发送消息
        let result = match (strategy) {
            case MessagePassingStrategy.DirectCopy =>
                sendDirectCopy(message, target)
            case MessagePassingStrategy.ZeroCopy =>
                sendZeroCopy(message, target)
            case MessagePassingStrategy.SharedMemory =>
                sendSharedMemory(message, target)
            case MessagePassingStrategy.Batched =>
                sendBatched(message, target)
        }
        
        let endTime = getCurrentTimeMicros()
        metrics.recordLatency(endTime - startTime)
        metrics.recordMessage(strategy, message.getPayloadSize())
        
        return result
    }
    
    // 批量发送消息
    public func sendBatch(messages: Array<ZeroCopyMessageImpl>, targets: Array<Actor>): Array<MessagePassingResult> {
        if (messages.size != targets.size) {
            return Array<MessagePassingResult>(messages.size, { i => 
                MessagePassingResult.Error("消息和目标数量不匹配")
            })
        }
        
        let results = Array<MessagePassingResult>(messages.size, { i => 
            MessagePassingResult.Success(0)
        })
        
        for (i in 0..messages.size) {
            results[i] = sendMessage(messages[i], targets[i])
        }
        
        return results
    }
    
    // 选择传递策略
    private func selectStrategy(message: ZeroCopyMessageImpl): MessagePassingStrategy {
        let payloadSize = message.getPayloadSize()
        
        if (payloadSize >= config.zeroCopyThreshold) {
            return MessagePassingStrategy.ZeroCopy
        } else if (batchProcessor.shouldBatch()) {
            return MessagePassingStrategy.Batched
        } else {
            return MessagePassingStrategy.DirectCopy
        }
    }
    
    // 直接拷贝发送
    private func sendDirectCopy(message: ZeroCopyMessageImpl, target: Actor): MessagePassingResult {
        let serialized = serializer.serialize(message)
        
        // 创建新的消息副本
        let copiedMessage = createMessageCopy(message, serialized.data)
        
        // 发送到目标Actor
        let context = createMessageContext(message)
        let result = target.receive(copiedMessage, context)
        
        return MessagePassingResult.Success(serialized.size)
    }
    
    // 零拷贝发送
    private func sendZeroCopy(message: ZeroCopyMessageImpl, target: Actor): MessagePassingResult {
        // 增加引用计数
        message.retain()
        
        // 直接传递消息引用
        let context = createMessageContext(message)
        let result = target.receive(message, context)
        
        return MessagePassingResult.Success(message.getPayloadSize())
    }
    
    // 共享内存发送
    private func sendSharedMemory(message: ZeroCopyMessageImpl, target: Actor): MessagePassingResult {
        // 简化实现：使用内存池分配共享内存
        let sharedBlock = memoryPool.allocate(message.getPayloadSize())
        
        match (sharedBlock) {
            case Some(block) =>
                // 将消息数据复制到共享内存
                let serialized = serializer.serialize(message)
                copyToSharedMemory(block, serialized.data)
                
                // 创建共享内存消息
                let sharedMessage = createSharedMessage(message, block)
                let context = createMessageContext(message)
                let result = target.receive(sharedMessage, context)
                
                return MessagePassingResult.Success(serialized.size)
            case None =>
                return MessagePassingResult.Error("无法分配共享内存")
        }
    }
    
    // 批量发送
    private func sendBatched(message: ZeroCopyMessageImpl, target: Actor): MessagePassingResult {
        batchProcessor.addMessage(message, target)
        return MessagePassingResult.Success(message.getPayloadSize())
    }
    
    // 辅助方法
    private func createMessageCopy(original: ZeroCopyMessageImpl, data: Array<UInt8>): ZeroCopyMessageImpl {
        return ZeroCopyMessageImpl(
            1, 
            original.getPayloadSize(), 
            original.getSourceActor(), 
            original.getTargetActor(), 
            Some(data)
        )
    }
    
    private func createSharedMessage(original: ZeroCopyMessageImpl, block: MemoryBlock): ZeroCopyMessageImpl {
        // 简化实现：创建指向共享内存的消息
        return ZeroCopyMessageImpl(
            2, 
            original.getPayloadSize(), 
            original.getSourceActor(), 
            original.getTargetActor(), 
            None
        )
    }
    
    private func createMessageContext(message: ZeroCopyMessageImpl): ActorContext {
        return SimpleActorContext(message.getSourceActor().toString())
    }
    
    private func copyToSharedMemory(block: MemoryBlock, data: Array<UInt8>): Unit {
        // 简化实现：假设已复制
        println("复制数据到共享内存，大小: ${data.size}")
    }
    
    public func getMetrics(): MessagePassingMetrics {
        return metrics
    }
    
    public func flushBatches(): Unit {
        batchProcessor.flush()
    }
}

// 消息传递结果
public enum MessagePassingResult {
    | Success(UInt64)  // 成功，返回传递的字节数
    | Error(String)    // 失败，返回错误信息
}

// 批量消息处理器
public class BatchMessageProcessor {
    private let batchSize: Int64
    private let maxLatency: Int64
    private let pendingMessages: ArrayList<PendingMessage>
    private let mutex: ReentrantMutex
    private var lastFlushTime: Int64
    
    public init(batchSize: Int64, maxLatency: Int64) {
        this.batchSize = batchSize
        this.maxLatency = maxLatency
        this.pendingMessages = ArrayList<PendingMessage>()
        this.mutex = ReentrantMutex()
        this.lastFlushTime = getCurrentTimeMicros()
    }
    
    public func addMessage(message: ZeroCopyMessageImpl, target: Actor): Unit {
        mutex.lock()
        
        pendingMessages.append(PendingMessage(message, target))
        
        if (shouldFlushNow()) {
            flushInternal()
        }
        
        mutex.unlock()
    }
    
    public func shouldBatch(): Bool {
        mutex.lock()
        let shouldBatch = pendingMessages.size < batchSize
        mutex.unlock()
        return shouldBatch
    }
    
    public func flush(): Unit {
        mutex.lock()
        flushInternal()
        mutex.unlock()
    }
    
    private func shouldFlushNow(): Bool {
        let currentTime = getCurrentTimeMicros()
        return pendingMessages.size >= batchSize || 
               (currentTime - lastFlushTime) >= maxLatency
    }
    
    private func flushInternal(): Unit {
        if (pendingMessages.isEmpty()) {
            return
        }
        
        // 批量处理消息
        for (pending in pendingMessages) {
            let context = SimpleActorContext(pending.message.getSourceActor().toString())
            pending.target.receive(pending.message, context)
        }
        
        pendingMessages.clear()
        lastFlushTime = getCurrentTimeMicros()
    }
}

// 待处理消息
public struct PendingMessage {
    public let message: ZeroCopyMessageImpl
    public let target: Actor
    
    public init(message: ZeroCopyMessageImpl, target: Actor) {
        this.message = message
        this.target = target
    }
}

// 消息传递指标
public class MessagePassingMetrics {
    private var totalMessages: AtomicInt64
    private var totalBytes: AtomicInt64
    private var totalLatency: AtomicInt64
    private var directCopyCount: AtomicInt64
    private var zeroCopyCount: AtomicInt64
    private var sharedMemoryCount: AtomicInt64
    private var batchedCount: AtomicInt64
    
    public init() {
        this.totalMessages = AtomicInt64(0)
        this.totalBytes = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
        this.directCopyCount = AtomicInt64(0)
        this.zeroCopyCount = AtomicInt64(0)
        this.sharedMemoryCount = AtomicInt64(0)
        this.batchedCount = AtomicInt64(0)
    }
    
    public func recordMessage(strategy: MessagePassingStrategy, bytes: UInt64): Unit {
        totalMessages.fetchAdd(1)
        totalBytes.fetchAdd(Int64(bytes))
        
        match (strategy) {
            case MessagePassingStrategy.DirectCopy =>
                directCopyCount.fetchAdd(1)
            case MessagePassingStrategy.ZeroCopy =>
                zeroCopyCount.fetchAdd(1)
            case MessagePassingStrategy.SharedMemory =>
                sharedMemoryCount.fetchAdd(1)
            case MessagePassingStrategy.Batched =>
                batchedCount.fetchAdd(1)
        }
    }
    
    public func recordLatency(latencyMicros: Int64): Unit {
        totalLatency.fetchAdd(latencyMicros)
    }
    
    public func getTotalMessages(): Int64 {
        totalMessages.load()
    }
    
    public func getAverageLatency(): Float64 {
        let messages = totalMessages.load()
        if (messages == 0) {
            return 0.0
        }
        return Float64(totalLatency.load()) / Float64(messages)
    }
    
    public func getThroughput(): Float64 {
        // 简化实现：返回消息/秒
        return Float64(totalMessages.load())
    }
}

// 简单的ActorContext实现
public class SimpleActorContext <: ActorContext {
    private let senderName: String
    
    public init(senderName: String) {
        this.senderName = senderName
    }
    
    public func sender(): Option<String> {
        Some(senderName)
    }
}

// 辅助函数
func getCurrentTimeMicros(): Int64 {
    // 简化实现：返回毫秒时间戳 * 1000
    DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000
}
