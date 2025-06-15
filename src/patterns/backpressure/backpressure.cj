/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 背压模式实现
 * 提供流量控制和过载保护机制
 */
package cactor.patterns.backpressure

import std.sync.*
import std.time.*
import std.collection.*
import cactor.foundation.queue.{Queue, LockFreeQueue}
import cactor.core.message.{Message, Envelope}
import cactor.core.actor.ActorRef

/**
 * 背压策略
 */
public enum BackpressureStrategy {
    | Drop          // 丢弃新消息
    | Block         // 阻塞发送者
    | Buffer        // 缓冲消息
    | Reject        // 拒绝消息
    | Throttle      // 限流
}

/**
 * 背压配置
 */
public struct BackpressureConfig {
    public let strategy: BackpressureStrategy
    public let maxBufferSize: Int64
    public let maxThroughput: Int64        // 每秒最大消息数
    public let windowSize: Duration        // 时间窗口大小
    public let dropThreshold: Float64      // 丢弃阈值 (0.0-1.0)
    public let blockTimeout: Duration      // 阻塞超时时间

    public init(strategy: BackpressureStrategy, maxBufferSize: Int64, 
                maxThroughput: Int64, windowSize: Duration,
                dropThreshold: Float64, blockTimeout: Duration) {
        this.strategy = strategy
        this.maxBufferSize = maxBufferSize
        this.maxThroughput = maxThroughput
        this.windowSize = windowSize
        this.dropThreshold = dropThreshold
        this.blockTimeout = blockTimeout
    }
}

/**
 * 背压统计信息
 */
public struct BackpressureStats {
    public let totalMessages: Int64
    public let droppedMessages: Int64
    public let blockedMessages: Int64
    public let bufferedMessages: Int64
    public let rejectedMessages: Int64
    public let throttledMessages: Int64
    public let currentThroughput: Float64
    public let bufferUtilization: Float64

    public init(totalMessages: Int64, droppedMessages: Int64, blockedMessages: Int64,
                bufferedMessages: Int64, rejectedMessages: Int64, throttledMessages: Int64,
                currentThroughput: Float64, bufferUtilization: Float64) {
        this.totalMessages = totalMessages
        this.droppedMessages = droppedMessages
        this.blockedMessages = blockedMessages
        this.bufferedMessages = bufferedMessages
        this.rejectedMessages = rejectedMessages
        this.throttledMessages = throttledMessages
        this.currentThroughput = currentThroughput
        this.bufferUtilization = bufferUtilization
    }

    public func getDropRate(): Float64 {
        if (totalMessages == 0) { return 0.0 }
        Float64(droppedMessages) / Float64(totalMessages)
    }

    public func getSuccessRate(): Float64 {
        if (totalMessages == 0) { return 1.0 }
        let successful = totalMessages - droppedMessages - rejectedMessages
        Float64(successful) / Float64(totalMessages)
    }
}

/**
 * 背压异常
 */
public class BackpressureException <: Exception {
    private let strategy: BackpressureStrategy
    private let reason: String

    public init(strategy: BackpressureStrategy, reason: String) {
        super("Backpressure ${strategy}: ${reason}")
        this.strategy = strategy
        this.reason = reason
    }

    public func getStrategy(): BackpressureStrategy {
        strategy
    }

    public func getReason(): String {
        reason
    }
}

/**
 * 流量控制器接口
 */
public interface FlowController {
    /**
     * 尝试发送消息
     */
    func trySend(message: Message): Bool

    /**
     * 获取当前统计信息
     */
    func getStats(): BackpressureStats

    /**
     * 重置统计信息
     */
    func reset(): Unit

    /**
     * 检查是否过载
     */
    func isOverloaded(): Bool
}

/**
 * 基础背压控制器
 */
public class BasicBackpressureController <: FlowController {
    private let config: BackpressureConfig
    private let buffer: Queue<Message>
    private let totalMessages: AtomicInt64
    private let droppedMessages: AtomicInt64
    private let blockedMessages: AtomicInt64
    private let rejectedMessages: AtomicInt64
    private let throttledMessages: AtomicInt64
    private let messageTimestamps: Queue<Int64>
    private let mutex: ReentrantMutex
    private let isRunning: AtomicBool

    public init(config: BackpressureConfig) {
        this.config = config
        this.buffer = LockFreeQueue<Message>(config.maxBufferSize)
        this.totalMessages = AtomicInt64(0)
        this.droppedMessages = AtomicInt64(0)
        this.blockedMessages = AtomicInt64(0)
        this.rejectedMessages = AtomicInt64(0)
        this.throttledMessages = AtomicInt64(0)
        this.messageTimestamps = LockFreeQueue<Int64>(1000)
        this.mutex = ReentrantMutex()
        this.isRunning = AtomicBool(true)
    }

    public func trySend(message: Message): Bool {
        if (!isRunning.load()) {
            return false
        }

        totalMessages.fetchAdd(1)
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        // 更新时间戳队列
        updateTimestamps(now)
        
        // 检查是否超过吞吐量限制
        if (isOverThroughputLimit()) {
            return handleOverThroughput(message)
        }
        
        // 检查缓冲区状态
        let bufferUtilization = getCurrentBufferUtilization()
        
        match (config.strategy) {
            case BackpressureStrategy.Drop => 
                return handleDrop(message, bufferUtilization)
            case BackpressureStrategy.Block => 
                return handleBlock(message, bufferUtilization)
            case BackpressureStrategy.Buffer => 
                return handleBuffer(message)
            case BackpressureStrategy.Reject => 
                return handleReject(message, bufferUtilization)
            case BackpressureStrategy.Throttle => 
                return handleThrottle(message, bufferUtilization)
        }
    }

    private func updateTimestamps(now: Int64): Unit {
        messageTimestamps.enqueue(now)
        
        // 清理过期的时间戳
        let windowStart = now - config.windowSize.toMilliseconds()
        while (!messageTimestamps.isEmpty()) {
            match (messageTimestamps.dequeue()) {
                case Some(timestamp) =>
                    if (timestamp >= windowStart) {
                        // 重新入队
                        messageTimestamps.enqueue(timestamp)
                        break
                    }
                case None => break
            }
        }
    }

    private func isOverThroughputLimit(): Bool {
        let currentThroughput = getCurrentThroughput()
        currentThroughput > Float64(config.maxThroughput)
    }

    private func getCurrentThroughput(): Float64 {
        let count = messageTimestamps.size()
        let windowSeconds = Float64(config.windowSize.toMilliseconds()) / 1000.0
        Float64(count) / windowSeconds
    }

    private func getCurrentBufferUtilization(): Float64 {
        if (config.maxBufferSize == 0) { return 0.0 }
        Float64(buffer.size()) / Float64(config.maxBufferSize)
    }

    private func handleOverThroughput(message: Message): Bool {
        throttledMessages.fetchAdd(1)
        
        // 简单的延迟策略
        let delay = Duration.millisecond * 10
        sleep(delay)
        
        // 重试发送
        return buffer.enqueue(message)
    }

    private func handleDrop(message: Message, utilization: Float64): Bool {
        if (utilization > config.dropThreshold) {
            droppedMessages.fetchAdd(1)
            return false
        }
        return buffer.enqueue(message)
    }

    private func handleBlock(message: Message, utilization: Float64): Bool {
        if (utilization > config.dropThreshold) {
            blockedMessages.fetchAdd(1)
            
            // 等待缓冲区有空间
            let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            while (getCurrentBufferUtilization() > config.dropThreshold) {
                let elapsed = DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime
                if (elapsed > config.blockTimeout.toMilliseconds()) {
                    return false  // 超时
                }
                sleep(Duration.millisecond * 10)
            }
        }
        return buffer.enqueue(message)
    }

    private func handleBuffer(message: Message): Bool {
        return buffer.enqueue(message)
    }

    private func handleReject(message: Message, utilization: Float64): Bool {
        if (utilization > config.dropThreshold) {
            rejectedMessages.fetchAdd(1)
            throw BackpressureException(BackpressureStrategy.Reject, 
                                      "Buffer utilization ${utilization} exceeds threshold ${config.dropThreshold}")
        }
        return buffer.enqueue(message)
    }

    private func handleThrottle(message: Message, utilization: Float64): Bool {
        if (utilization > config.dropThreshold) {
            throttledMessages.fetchAdd(1)
            
            // 动态延迟
            let delayMs = Int64(utilization * 100.0)  // 最大100ms延迟
            sleep(Duration.millisecond * delayMs)
        }
        return buffer.enqueue(message)
    }

    public func getStats(): BackpressureStats {
        mutex.lock()
        try {
            BackpressureStats(
                totalMessages.load(),
                droppedMessages.load(),
                blockedMessages.load(),
                buffer.size(),
                rejectedMessages.load(),
                throttledMessages.load(),
                getCurrentThroughput(),
                getCurrentBufferUtilization()
            )
        } finally {
            mutex.unlock()
        }
    }

    public func reset(): Unit {
        mutex.lock()
        try {
            totalMessages.store(0)
            droppedMessages.store(0)
            blockedMessages.store(0)
            rejectedMessages.store(0)
            throttledMessages.store(0)
            buffer.clear()
            messageTimestamps.clear()
        } finally {
            mutex.unlock()
        }
    }

    public func isOverloaded(): Bool {
        let utilization = getCurrentBufferUtilization()
        let throughputOverload = isOverThroughputLimit()
        utilization > config.dropThreshold || throughputOverload
    }

    public func stop(): Unit {
        isRunning.store(false)
    }

    public func getBufferedMessages(): Queue<Message> {
        buffer
    }
}

/**
 * 背压控制器工厂
 */
public struct BackpressureControllerFactory {
    /**
     * 创建丢弃策略的控制器
     */
    public static func createDropController(maxBufferSize: Int64, maxThroughput: Int64): BasicBackpressureController {
        let config = BackpressureConfig(
            BackpressureStrategy.Drop,
            maxBufferSize,
            maxThroughput,
            Duration.second,
            0.8,  // 80%阈值
            Duration.second * 5
        )
        BasicBackpressureController(config)
    }

    /**
     * 创建阻塞策略的控制器
     */
    public static func createBlockController(maxBufferSize: Int64, maxThroughput: Int64): BasicBackpressureController {
        let config = BackpressureConfig(
            BackpressureStrategy.Block,
            maxBufferSize,
            maxThroughput,
            Duration.second,
            0.9,  // 90%阈值
            Duration.second * 10
        )
        BasicBackpressureController(config)
    }

    /**
     * 创建限流策略的控制器
     */
    public static func createThrottleController(maxBufferSize: Int64, maxThroughput: Int64): BasicBackpressureController {
        let config = BackpressureConfig(
            BackpressureStrategy.Throttle,
            maxBufferSize,
            maxThroughput,
            Duration.second,
            0.7,  // 70%阈值
            Duration.second * 3
        )
        BasicBackpressureController(config)
    }
}
