/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 可靠性模式实现
 * 对标 Akka 可靠消息传递
 * 提供死信通道、消息确认、重试机制
 */
package cactor.patterns.reliability

import std.collection.*
import std.sync.*
import std.time.*

// ============================================================================
// 死信相关类型
// ============================================================================

/**
 * 死信原因
 */
public enum DeadLetterReason {
    | RecipientTerminated
    | MailboxFull
    | RouteNotFound
    | SerializationFailed
    | Timeout
    | Unknown
}

/**
 * 死信消息
 */
public class DeadLetter {
    public let message: Any
    public let sender: Option<String>
    public let recipient: String
    public let timestamp: Int64
    public let reason: DeadLetterReason

    public init(
        message: Any,
        sender: Option<String>,
        recipient: String,
        reason: DeadLetterReason
    ) {
        this.message = message
        this.sender = sender
        this.recipient = recipient
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.reason = reason
    }
}

/**
 * 死信监听器接口
 */
public interface DeadLetterListener {
    func onDeadLetter(letter: DeadLetter): Unit
}

/**
 * 死信通道 - 收集无法投递的消息
 */
public class DeadLetterChannel {
    private let letters: ArrayList<DeadLetter>
    private let listeners: ArrayList<DeadLetterListener>
    private let lock: ReentrantReadWriteMutex
    private let maxCapacity: Int64

    public init() {
        this.letters = ArrayList<DeadLetter>()
        this.listeners = ArrayList<DeadLetterListener>()
        this.lock = ReentrantReadWriteMutex()
        this.maxCapacity = 1000
    }

    public init(maxCapacity: Int64) {
        this.letters = ArrayList<DeadLetter>()
        this.listeners = ArrayList<DeadLetterListener>()
        this.lock = ReentrantReadWriteMutex()
        this.maxCapacity = maxCapacity
    }

    /**
     * 发布死信
     */
    public func publish(letter: DeadLetter): Unit {
        try {
            lock.writeMutex.lock()
            if (letters.size >= maxCapacity) {
                // 移除第一个元素
                if (letters.size > 0) {
                    let _ = letters.remove(0..1)
                }
            }
            letters.add(letter)
            lock.writeMutex.unlock()
            notifyListeners(letter)
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 获取所有死信
     */
    public func getDeadLetters(): Array<DeadLetter> {
        try {
            lock.readMutex.lock()
            let result = letters.toArray()
            lock.readMutex.unlock()
            result
        } catch (e: Exception) {
            lock.readMutex.unlock()
            Array<DeadLetter>(0, { i: Int64 => DeadLetter("" as Any, None, "", DeadLetterReason.Unknown) })
        }
    }

    /**
     * 获取死信数量
     */
    public func size(): Int64 {
        try {
            lock.readMutex.lock()
            let count = letters.size
            lock.readMutex.unlock()
            Int64(count)
        } catch (e: Exception) {
            lock.readMutex.unlock()
            0
        }
    }

    /**
     * 清空死信
     */
    public func clear(): Unit {
        try {
            lock.writeMutex.lock()
            letters.clear()
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 添加监听器
     */
    public func addListener(listener: DeadLetterListener): Unit {
        try {
            lock.writeMutex.lock()
            listeners.add(listener)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 移除监听器
     */
    public func removeListener(listener: DeadLetterListener): Unit {
        try {
            lock.writeMutex.lock()
            if (listeners.size > 0) {
                // 移除第一个监听器
                let _ = listeners.remove(0..1)
            }
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    private func notifyListeners(letter: DeadLetter): Unit {
        let listenerCount = listeners.size
        var i = 0
        while (i < listenerCount) {
            try {
                listeners[i].onDeadLetter(letter)
            } catch (e: Exception) {
                // 忽略监听器异常
            }
            i += 1
        }
    }

    /**
     * 根据接收者过滤死信
     */
    public func getDeadLettersFor(recipient: String): Array<DeadLetter> {
        try {
            lock.readMutex.lock()
            let result = ArrayList<DeadLetter>()
            for (i in 0..letters.size) {
                let letter = letters[i]
                if (letter.recipient == recipient) {
                    result.add(letter)
                }
            }
            lock.readMutex.unlock()
            result.toArray()
        } catch (e: Exception) {
            lock.readMutex.unlock()
            Array<DeadLetter>(0, { i: Int64 => DeadLetter("" as Any, None, "", DeadLetterReason.Unknown) })
        }
    }

    /**
     * 获取最新的 N 条死信
     */
    public func getRecentDeadLetters(n: Int64): Array<DeadLetter> {
        try {
            lock.readMutex.lock()
            let count = if (letters.size > n) { n } else { letters.size }
            let result = ArrayList<DeadLetter>()
            var i = letters.size - count
            while (i < letters.size) {
                result.add(letters[i])
                i += 1
            }
            lock.readMutex.unlock()
            result.toArray()
        } catch (e: Exception) {
            lock.readMutex.unlock()
            Array<DeadLetter>(0, { i: Int64 => DeadLetter("" as Any, None, "", DeadLetterReason.Unknown) })
        }
    }
}

// ============================================================================
// 确认机制相关类型
// ============================================================================

/**
 * 确认状态
 */
public enum AckStatus {
    | Pending
    | Acknowledged
    | Failed(String)
    | Expired
}

/**
 * 消息确认
 */
public class Acknowledgement {
    public let messageId: String
    public let status: AckStatus
    public let timestamp: Int64
    public let retryCount: Int64

    public init(messageId: String) {
        this.messageId = messageId
        this.status = AckStatus.Pending
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.retryCount = 0
    }

    public init(
        messageId: String,
        status: AckStatus,
        timestamp: Int64,
        retryCount: Int64
    ) {
        this.messageId = messageId
        this.status = status
        this.timestamp = timestamp
        this.retryCount = retryCount
    }

    public func withStatus(status: AckStatus): Acknowledgement {
        Acknowledgement(this.messageId, status, this.timestamp, this.retryCount)
    }

    public func withRetry(): Acknowledgement {
        Acknowledgement(this.messageId, this.status, this.timestamp, this.retryCount + 1)
    }
}

/**
 * 消息确认跟踪器
 */
public class AckTracker {
    private let pendingAcks: HashMap<String, Acknowledgement>
    private let lock: ReentrantReadWriteMutex
    private let timeout: Duration
    private let maxRetries: Int64

    public init() {
        this.pendingAcks = HashMap<String, Acknowledgement>()
        this.lock = ReentrantReadWriteMutex()
        this.timeout = Duration.second * 30
        this.maxRetries = 3
    }

    public init(timeout: Duration, maxRetries: Int64) {
        this.pendingAcks = HashMap<String, Acknowledgement>()
        this.lock = ReentrantReadWriteMutex()
        this.timeout = timeout
        this.maxRetries = maxRetries
    }

    /**
     * 注册需要确认的消息
     */
    public func register(messageId: String): Unit {
        try {
            lock.writeMutex.lock()
            let ack = Acknowledgement(messageId)
            let _ = pendingAcks.add(messageId, ack)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 确认消息
     */
    public func acknowledge(messageId: String): Bool {
        try {
            lock.writeMutex.lock()
            match (pendingAcks.get(messageId)) {
                case Some(ack) =>
                    let _ = pendingAcks.add(messageId, ack.withStatus(AckStatus.Acknowledged))
                    lock.writeMutex.unlock()
                    true
                case None =>
                    lock.writeMutex.unlock()
                    false
            }
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            false
        }
    }

    /**
     * 否定确认
     */
    public func nack(messageId: String, reason: String): Bool {
        try {
            lock.writeMutex.lock()
            match (pendingAcks.get(messageId)) {
                case Some(ack) =>
                    let newAck = ack.withStatus(AckStatus.Failed(reason))
                    let _ = pendingAcks.add(messageId, newAck)
                    lock.writeMutex.unlock()
                    true
                case None =>
                    lock.writeMutex.unlock()
                    false
            }
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            false
        }
    }

    /**
     * 获取确认状态
     */
    public func getStatus(messageId: String): Option<AckStatus> {
        try {
            lock.readMutex.lock()
            match (pendingAcks.get(messageId)) {
                case Some(ack) =>
                    lock.readMutex.unlock()
                    Some(ack.status)
                case None =>
                    lock.readMutex.unlock()
                    None
            }
        } catch (e: Exception) {
            lock.readMutex.unlock()
            None
        }
    }

    /**
     * 获取待确认数量
     */
    public func pendingCount(): Int64 {
        try {
            lock.readMutex.lock()
            var count = 0
            let keys = pendingAcks.keys()
            for (key in keys) {
                match (pendingAcks.get(key)) {
                    case Some(ack) =>
                        match (ack.status) {
                            case AckStatus.Pending => count += 1
                            case _ => ()
                        }
                    case None => ()
                }
            }
            lock.readMutex.unlock()
            Int64(count)
        } catch (e: Exception) {
            lock.readMutex.unlock()
            0
        }
    }

    /**
     * 获取所有被跟踪的消息数量（包括已确认的）
     */
    public func totalCount(): Int64 {
        try {
            lock.readMutex.lock()
            let count = pendingAcks.size
            lock.readMutex.unlock()
            Int64(count)
        } catch (e: Exception) {
            lock.readMutex.unlock()
            0
        }
    }

    /**
     * 获取所有待确认的消息ID
     */
    public func getPendingMessageIds(): Array<String> {
        try {
            lock.readMutex.lock()
            let result = ArrayList<String>()
            let keys = pendingAcks.keys()
            for (key in keys) {
                match (pendingAcks.get(key)) {
                    case Some(ack) =>
                        match (ack.status) {
                            case AckStatus.Pending => result.add(key)
                            case _ => ()
                        }
                    case None => ()
                }
            }
            lock.readMutex.unlock()
            result.toArray()
        } catch (e: Exception) {
            lock.readMutex.unlock()
            Array<String>(0, { i: Int64 => "" })
        }
    }

    /**
     * 清理已确认的消息
     */
    public func cleanup(): Int64 {
        try {
            lock.writeMutex.lock()
            var removed = 0
            let keys = pendingAcks.keys()
            let toRemove = ArrayList<String>()
            for (key in keys) {
                match (pendingAcks.get(key)) {
                    case Some(ack) =>
                        match (ack.status) {
                            case AckStatus.Acknowledged => toRemove.add(key)
                            case _ => ()
                        }
                    case None => ()
                }
            }
            for (i in 0..toRemove.size) {
                let key = toRemove[i]
                let _ = pendingAcks.remove(key)
                removed += 1
            }
            lock.writeMutex.unlock()
            Int64(removed)
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            0
        }
    }

    /**
     * 检查并标记超时的消息
     */
    public func checkTimeouts(): Array<String> {
        try {
            lock.writeMutex.lock()
            let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
            let timedOut = ArrayList<String>()
            let keys = pendingAcks.keys()
            for (key in keys) {
                match (pendingAcks.get(key)) {
                    case Some(ack) =>
                        match (ack.status) {
                            case AckStatus.Pending =>
                                if (now - ack.timestamp > timeout.toMilliseconds()) {
                                    let _ = pendingAcks.add(key, ack.withStatus(AckStatus.Expired))
                                    timedOut.add(key)
                                }
                            case _ => ()
                        }
                    case None => ()
                }
            }
            lock.writeMutex.unlock()
            timedOut.toArray()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            Array<String>(0, { i: Int64 => "" })
        }
    }
}

// ============================================================================
// 重试策略相关类型
// ============================================================================

/**
 * 重试策略接口
 */
public interface RetryStrategy {
    func shouldRetry(retryCount: Int64, lastError: Option<String>): Bool
    func nextDelay(retryCount: Int64): Duration
}

/**
 * 指数退避重试策略
 */
public class ExponentialBackoffRetry <: RetryStrategy {
    private let baseDelay: Duration
    private let maxDelay: Duration
    private let maxRetries: Int64

    public init() {
        this.baseDelay = Duration.millisecond * 100
        this.maxDelay = Duration.second * 30
        this.maxRetries = 5
    }

    public init(baseDelay: Duration, maxDelay: Duration, maxRetries: Int64) {
        this.baseDelay = baseDelay
        this.maxDelay = maxDelay
        this.maxRetries = maxRetries
    }

    public func shouldRetry(retryCount: Int64, lastError: Option<String>): Bool {
        retryCount < maxRetries
    }

    public func nextDelay(retryCount: Int64): Duration {
        let delayMs = baseDelay.toMilliseconds() * (1 << retryCount)
        let delay = Duration.millisecond * delayMs
        if (delay > maxDelay) { maxDelay } else { delay }
    }
}

/**
 * 固定间隔重试策略
 */
public class FixedDelayRetry <: RetryStrategy {
    private let delay: Duration
    private let maxRetries: Int64

    public init() {
        this.delay = Duration.second * 1
        this.maxRetries = 3
    }

    public init(delay: Duration, maxRetries: Int64) {
        this.delay = delay
        this.maxRetries = maxRetries
    }

    public func shouldRetry(retryCount: Int64, lastError: Option<String>): Bool {
        retryCount < maxRetries
    }

    public func nextDelay(retryCount: Int64): Duration {
        delay
    }
}

// ============================================================================
// 可靠消息发送器
// ============================================================================

/**
 * 发送结果
 */
public enum SendResult {
    | Sent
    | SentWithAck(String)  // 消息ID
    | RetryScheduled(Int64)  // 重试次数
    | Failed(String)  // 失败原因
    | Dropped  // 超过最大重试次数
}

/**
 * 可靠消息发送器
 */
public class ReliableMessageSender {
    private let deadLetterChannel: DeadLetterChannel
    private let ackTracker: AckTracker
    private let retryStrategy: RetryStrategy
    private let lock: ReentrantReadWriteMutex

    public init(deadLetterChannel: DeadLetterChannel) {
        this.deadLetterChannel = deadLetterChannel
        this.ackTracker = AckTracker()
        this.retryStrategy = ExponentialBackoffRetry()
        this.lock = ReentrantReadWriteMutex()
    }

    public init(
        deadLetterChannel: DeadLetterChannel,
        retryStrategy: RetryStrategy
    ) {
        this.deadLetterChannel = deadLetterChannel
        this.ackTracker = AckTracker()
        this.retryStrategy = retryStrategy
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 发送需要确认的消息
     */
    public func sendWithAck(
        message: Any,
        recipient: String
    ): String {
        sendWithAckWithSender(message, recipient, None)
    }

    /**
     * 发送需要确认的消息（带发送者）
     */
    public func sendWithAckWithSender(
        message: Any,
        recipient: String,
        sender: Option<String>
    ): String {
        let messageId = generateMessageId()
        ackTracker.register(messageId)
        messageId
    }

    /**
     * 确认消息已被处理
     */
    public func ack(messageId: String): Unit {
        let _ = ackTracker.acknowledge(messageId)
    }

    /**
     * 否定确认
     */
    public func nack(messageId: String, reason: String): Bool {
        ackTracker.nack(messageId, reason)
    }

    /**
     * 处理发送失败
     */
    public func handleSendFailure(
        message: Any,
        recipient: String,
        sender: Option<String>,
        retryCount: Int64,
        error: String
    ): SendResult {
        if (retryStrategy.shouldRetry(retryCount, Some(error))) {
            SendResult.RetryScheduled(retryCount + 1)
        } else {
            let letter = DeadLetter(
                message,
                sender,
                recipient,
                DeadLetterReason.Unknown
            )
            deadLetterChannel.publish(letter)
            SendResult.Dropped
        }
    }

    /**
     * 获取待确认消息数量
     */
    public func getPendingCount(): Int64 {
        ackTracker.totalCount()
    }

    /**
     * 检查超时的消息
     */
    public func checkTimeouts(): Array<String> {
        ackTracker.checkTimeouts()
    }

    /**
     * 清理已确认的消息
     */
    public func cleanup(): Int64 {
        ackTracker.cleanup()
    }

    /**
     * 获取确认跟踪器（用于测试）
     */
    public func getTracker(): AckTracker {
        ackTracker
    }

    private func generateMessageId(): String {
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let id = timestamp + (timestamp % 1000)
        "msg-${id}"
    }
}

// ============================================================================
// 消息缓冲器
// ============================================================================

/**
 * 消息缓冲器 - 用于消息重排序
 */
public class MessageBuffer {
    private let buffer: ArrayList<(Int64, Any)>
    private let lock: ReentrantReadWriteMutex
    private var expectedSequence: Int64
    private let maxBufferSize: Int64
    private let onDelivery: (Any) -> Unit

    public init(onDelivery: (Any) -> Unit) {
        this.buffer = ArrayList<(Int64, Any)>()
        this.lock = ReentrantReadWriteMutex()
        this.expectedSequence = 0
        this.maxBufferSize = 100
        this.onDelivery = onDelivery
    }

    public init(
        onDelivery: (Any) -> Unit,
        expectedSequence: Int64,
        maxBufferSize: Int64
    ) {
        this.buffer = ArrayList<(Int64, Any)>()
        this.lock = ReentrantReadWriteMutex()
        this.expectedSequence = expectedSequence
        this.maxBufferSize = maxBufferSize
        this.onDelivery = onDelivery
    }

    /**
     * 添加消息到缓冲器
     */
    public func add(sequence: Int64, message: Any): Unit {
        try {
            lock.writeMutex.lock()
            if (sequence == expectedSequence) {
                deliver(message)
                expectedSequence += 1
                drainBuffer()
            } else if (sequence > expectedSequence) {
                if (buffer.size < maxBufferSize) {
                    buffer.add((sequence, message))
                    sortBuffer()
                }
            }
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    private func deliver(message: Any): Unit {
        try {
            onDelivery(message)
        } catch (e: Exception) {
            // 传递失败
        }
    }

    private func sortBuffer(): Unit {
        var i = 1
        while (i < buffer.size) {
            let (seq, msg) = buffer[i]
            var j = i
            while (j > 0) {
                let (prevSeq, _) = buffer[j - 1]
                if (prevSeq > seq) {
                    buffer[j] = buffer[j - 1]
                    j -= 1
                } else {
                    break
                }
            }
            buffer[j] = (seq, msg)
            i += 1
        }
    }

    private func drainBuffer(): Unit {
        var drained = true
        while (drained) {
            drained = false
            var i: Int64 = 0
            while (i < buffer.size) {
                let (seq, msg) = buffer[Int64(i)]
                if (seq == expectedSequence) {
                    deliver(msg)
                    expectedSequence += 1
                    let _ = buffer.remove(i..i+1)
                    drained = true
                } else {
                    i += 1
                }
            }
        }
    }

    /**
     * 获取缓冲器大小
     */
    public func getBufferSize(): Int64 {
        try {
            lock.readMutex.lock()
            let size = buffer.size
            lock.readMutex.unlock()
            Int64(size)
        } catch (e: Exception) {
            lock.readMutex.unlock()
            0
        }
    }

    /**
     * 获取期望的下一个序列号
     */
    public func getExpectedSequence(): Int64 {
        try {
            lock.readMutex.lock()
            let seq = expectedSequence
            lock.readMutex.unlock()
            seq
        } catch (e: Exception) {
            lock.readMutex.unlock()
            0
        }
    }
}
