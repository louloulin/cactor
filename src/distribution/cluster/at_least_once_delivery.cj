/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - AtLeastOnceDelivery 至少一次投递机制
 * 对标 Akka AtLeastOnceDelivery
 * 实现带确认的消息投递，确保消息至少被投递一次
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 投递状态
 */
public enum DeliveryState {
    Pending
    Sent
    Confirmed
    ConfirmedStale
}

/**
 * 投递信封
 * 包含消息的投递信息和重试状态
 */
public class DeliveryEnvelope {
    public let messageId: Int64
    public let destination: String
    public let payload: String
    public var state: DeliveryState
    public var sendCount: Int64
    public var lastSendTime: Int64
    public var timestamp: Int64

    public init(messageId: Int64, destination: String, payload: String) {
        this.messageId = messageId
        this.destination = destination
        this.payload = payload
        this.state = DeliveryState.Pending
        this.sendCount = 0
        this.lastSendTime = 0
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /**
     * 标记为已发送
     */
    public func markSent(): Unit {
        this.state = DeliveryState.Sent
        this.sendCount += 1
        this.lastSendTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /**
     * 标记为已确认
     */
    public func markConfirmed(): Unit {
        this.state = DeliveryState.Confirmed
    }

    /**
     * 检查是否需要重试
     */
    public func needsRetry(retryInterval: Duration): Bool {
        if (state == DeliveryState.Confirmed) {
            return false
        }
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        (now - lastSendTime) > retryInterval.toMilliseconds()
    }
}

/**
 * 投递跟踪信息
 */
public class DeliveryTracking {
    public let messageId: Int64
    public let destination: String
    public let payload: String
    public let sentAt: Int64
    public let confirmedAt: Option<Int64>
    public let sendCount: Int64

    public init(envelope: DeliveryEnvelope) {
        this.messageId = envelope.messageId
        this.destination = envelope.destination
        this.payload = envelope.payload
        this.sentAt = envelope.timestamp
        this.confirmedAt = None
        this.sendCount = envelope.sendCount
    }

    /**
     * 获取投递持续时间
     */
    public func deliveryDuration(): Int64 {
        let endTime = match (confirmedAt) {
            case Some(ct) => ct
            case None => DateTime.now().toUnixTimeStamp().toMilliseconds()
        }
        endTime - sentAt
    }
}

/**
 * 投递确认请求
 */
public class ConfirmRequest {
    public let messageId: Int64
    public let timestamp: Int64

    public init(messageId: Int64) {
        this.messageId = messageId
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 投递结果
 */
public class DeliveryResult {
    public let messageId: Int64
    public let destination: String
    public let success: Bool
    public let confirmed: Bool
    public let reason: Option<String>

    public init(messageId: Int64, destination: String, success: Bool, confirmed: Bool, reason: Option<String>) {
        this.messageId = messageId
        this.destination = destination
        this.success = success
        this.confirmed = confirmed
        this.reason = reason
    }
}

/**
 * AtLeastOnceDelivery 事件处理器
 */
public interface DeliveryEventHandler {
    /**
     * 消息已发送
     */
    func onMessageSent(messageId: Int64, destination: String, payload: String): Unit

    /**
     * 消息已确认
     */
    func onMessageConfirmed(messageId: Int64): Unit

    /**
     * 消息确认超时
     */
    func onMessageTimeout(messageId: Int64, destination: String): Unit

    /**
     * 消息达到最大重试次数
     */
    func onMessageMaxRetries(messageId: Int64, destination: String, reason: String): Unit

    /**
     * 消息被标记为过时
     */
    func onMessageStale(messageId: Int64): Unit
}

/**
 * AtLeastOnceDelivery 配置
 */
public class DeliveryConfig {
    public let redeliverInterval: Duration
    public let maxRetries: Int64
    public let trackInterval: Duration
    public let staleThreshold: Duration
    public let pendingBufferSize: Int64

    public init(redeliverInterval: Duration, maxRetries: Int64, trackInterval: Duration, staleThreshold: Duration, pendingBufferSize: Int64) {
        this.redeliverInterval = redeliverInterval
        this.maxRetries = maxRetries
        this.trackInterval = trackInterval
        this.staleThreshold = staleThreshold
        this.pendingBufferSize = pendingBufferSize
    }
}

/**
 * AtLeastOnceDelivery 实现
 * 对标 Akka AtLeastOnceDelivery trait
 */
public class AtLeastOnceDelivery {
    private let destination: String
    private let config: DeliveryConfig
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<DeliveryEventHandler>
    private var messageIdCounter: Int64
    private let pendingDeliveries: HashMap<Int64, DeliveryEnvelope>
    private let confirmedDeliveries: HashMap<Int64, DeliveryTracking>
    private var totalSent: Int64
    private var totalConfirmed: Int64
    private var totalFailed: Int64

    public init(destination: String, config: DeliveryConfig) {
        this.destination = destination
        this.config = config
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
        this.messageIdCounter = 0
        this.pendingDeliveries = HashMap<Int64, DeliveryEnvelope>()
        this.confirmedDeliveries = HashMap<Int64, DeliveryTracking>()
        this.totalSent = 0
        this.totalConfirmed = 0
        this.totalFailed = 0
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: DeliveryEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 发送消息（带至少一次投递保证）
     * 返回消息 ID
     */
    public func deliver(payload: String): Int64 {
        lock.writeMutex.lock()
        messageIdCounter += 1
        let messageId = messageIdCounter
        let envelope = DeliveryEnvelope(messageId, destination, payload)
        pendingDeliveries.add(messageId, envelope)
        totalSent += 1
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onMessageSent(messageId, destination, payload)
            case None => ()
        }

        messageId
    }

    /**
     * 批量发送消息
     * 返回消息 ID 列表
     */
    public func deliverBatch(payloads: ArrayList<String>): ArrayList<Int64> {
        let ids = ArrayList<Int64>()
        for (payload in payloads) {
            ids.add(deliver(payload))
        }
        ids
    }

    /**
     * 标记消息为已发送
     * 当底层传输层发送消息后调用
     */
    public func markSent(messageId: Int64): Unit {
        lock.writeMutex.lock()
        match (pendingDeliveries.get(messageId)) {
            case Some(envelope) =>
                envelope.markSent()
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 确认消息已收到
     * 当接收方确认收到消息时调用
     */
    public func confirm(messageId: Int64): Bool {
        lock.writeMutex.lock()
        let confirmed = pendingDeliveries.get(messageId).isSome()
        match (pendingDeliveries.get(messageId)) {
            case Some(envelope) =>
                envelope.markConfirmed()
                let tracking = DeliveryTracking(envelope)
                confirmedDeliveries.add(messageId, tracking)
                pendingDeliveries.remove(messageId)
                totalConfirmed += 1
            case None => ()
        }
        lock.writeMutex.unlock()

        if (confirmed) {
            match (eventHandler) {
                case Some(handler) => handler.onMessageConfirmed(messageId)
                case None => ()
            }
        }

        confirmed
    }

    /**
     * 处理确认请求
     */
    public func handleConfirmRequest(request: ConfirmRequest): Unit {
        confirm(request.messageId)
    }

    /**
     * 获取待确认的消息列表
     */
    public func getPendingDeliveries(): ArrayList<DeliveryTracking> {
        lock.readMutex.lock()
        let result = ArrayList<DeliveryTracking>()
        for ((_, envelope) in pendingDeliveries) {
            result.add(DeliveryTracking(envelope))
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取确认的消息列表
     */
    public func getConfirmedDeliveries(): ArrayList<DeliveryTracking> {
        lock.readMutex.lock()
        let result = ArrayList<DeliveryTracking>()
        for ((_, tracking) in confirmedDeliveries) {
            result.add(tracking)
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取需要重试的消息
     */
    public func getMessagesToRetry(): ArrayList<DeliveryEnvelope> {
        lock.writeMutex.lock()
        let result = ArrayList<DeliveryEnvelope>()
        for ((_, envelope) in pendingDeliveries) {
            if (envelope.needsRetry(config.redeliverInterval)) {
                if (envelope.sendCount < config.maxRetries) {
                    result.add(envelope)
                }
            }
        }
        lock.writeMutex.unlock()
        result
    }

    /**
     * 重试失败的消息
     */
    public func retryFailed(): Int64 {
        lock.writeMutex.lock()
        var count: Int64 = 0
        for ((_, envelope) in pendingDeliveries) {
            if (envelope.state != DeliveryState.Confirmed && envelope.sendCount >= config.maxRetries) {
                match (eventHandler) {
                    case Some(handler) =>
                        handler.onMessageMaxRetries(envelope.messageId, envelope.destination, "Max retries exceeded")
                    case None => ()
                }
                count += 1
            }
        }
        lock.writeMutex.unlock()
        count
    }

    /**
     * 检查消息是否已确认
     */
    public func isConfirmed(messageId: Int64): Bool {
        lock.readMutex.lock()
        let result = confirmedDeliveries.get(messageId).isSome()
        lock.readMutex.unlock()
        result
    }

    /**
     * 检查消息是否待确认
     */
    public func isPending(messageId: Int64): Bool {
        lock.readMutex.lock()
        let result = pendingDeliveries.get(messageId).isSome()
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取待确认消息数量
     */
    public func pendingCount(): Int64 {
        lock.readMutex.lock()
        let count = pendingDeliveries.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取已确认消息数量
     */
    public func confirmedCount(): Int64 {
        lock.readMutex.lock()
        let count = confirmedDeliveries.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取总发送数
     */
    public func totalSent(): Int64 {
        lock.readMutex.lock()
        let count = totalSent
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取总确认数
     */
    public func totalConfirmed(): Int64 {
        lock.readMutex.lock()
        let count = totalConfirmed
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取总失败数
     */
    public func totalFailed(): Int64 {
        lock.readMutex.lock()
        let count = totalFailed
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取确认率
     */
    public func confirmationRate(): Float64 {
        if (totalSent == 0) {
            return 1.0
        }
        Float64(totalConfirmed) / Float64(totalSent)
    }

    /**
     * 清理过时的已确认消息
     */
    public func cleanupStaleMessages(): Int64 {
        lock.writeMutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let threshold = config.staleThreshold.toMilliseconds()
        var count: Int64 = 0
        let toRemove = ArrayList<Int64>()
        for ((msgId, tracking) in confirmedDeliveries) {
            match (tracking.confirmedAt) {
                case Some(ct) =>
                    if ((now - ct) > threshold) {
                        toRemove.add(msgId)
                        count += 1
                    }
                case None => ()
            }
        }
        for (msgId in toRemove) {
            confirmedDeliveries.remove(msgId)
        }
        lock.writeMutex.unlock()
        count
    }

    /**
     * 获取消息跟踪信息
     */
    public func getTracking(messageId: Int64): Option<DeliveryTracking> {
        lock.readMutex.lock()
        let result = confirmedDeliveries.get(messageId)
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取投递状态
     */
    public func getDeliveryState(messageId: Int64): Option<DeliveryState> {
        lock.readMutex.lock()
        let result = match (pendingDeliveries.get(messageId)) {
            case Some(e) => Some(e.state)
            case None =>
                match (confirmedDeliveries.get(messageId)) {
                    case Some(_) => Some(DeliveryState.Confirmed)
                    case None => None
                }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 取消待确认消息
     */
    public func cancelDelivery(messageId: Int64): Bool {
        lock.writeMutex.lock()
        let existed = pendingDeliveries.get(messageId).isSome()
        if (existed) {
            pendingDeliveries.remove(messageId)
            totalFailed += 1
        }
        lock.writeMutex.unlock()
        existed
    }

    /**
     * 获取消息投递的目标
     */
    public func getDestination(): String {
        destination
    }
}

/**
 * 创建 AtLeastOnceDelivery 实例
 */
public func createAtLeastOnceDelivery(destination: String): AtLeastOnceDelivery {
    let config = DeliveryConfig(
        Duration.second * 5,    // redeliverInterval
        5,                      // maxRetries
        Duration.minute * 1,   // trackInterval
        Duration.minute * 30,   // staleThreshold
        1000                    // pendingBufferSize
    )
    AtLeastOnceDelivery(destination, config)
}

/**
 * 创建自定义配置的 AtLeastOnceDelivery
 */
public func createAtLeastOnceDeliveryWithConfig(destination: String, config: DeliveryConfig): AtLeastOnceDelivery {
    AtLeastOnceDelivery(destination, config)
}

/**
 * 创建默认投递配置
 */
public func createDefaultDeliveryConfig(): DeliveryConfig {
    DeliveryConfig(
        Duration.second * 5,
        5,
        Duration.minute * 1,
        Duration.minute * 30,
        1000
    )
}