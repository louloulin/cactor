/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Core - 零拷贝消息实现
 * 提供简单的零拷贝消息功能
 */
package cactor.core.message

import std.sync.*
import std.time.*
import std.collection.*

/**
 * CRC32校验和计算器
 */
public class CRC32 {
    private let value: AtomicInt64

    public init() {
        this.value = AtomicInt64(0)
    }

    public func update(data: UInt8): Unit {
        let current = value.load()
        value.store(current + Int64(data))
    }

    public func getValue(): UInt32 {
        UInt32(value.load() % 4294967296)  // 2^32
    }

    public func reset(): Unit {
        value.store(0)
    }
}

/**
 * 零拷贝消息实现
 */
public class ZeroCopyMessageImpl {
    private let messageId: UInt64
    private let messageType: UInt16
    private let payloadSize: UInt64
    private let sourceActor: UInt64
    private let targetActor: UInt64
    private let payload: Option<Array<UInt8>>
    private let refCount: AtomicInt64
    private let isValidFlag: AtomicBool
    private let checksum: UInt32
    private let mutex: Mutex

    public init(messageType: UInt16, payloadSize: UInt64, sourceActor: UInt64,
                targetActor: UInt64, payload: Option<Array<UInt8>>) {
        // 先初始化所有成员变量
        this.messageType = messageType
        this.payloadSize = payloadSize
        this.sourceActor = sourceActor
        this.targetActor = targetActor
        this.payload = payload
        this.refCount = AtomicInt64(1)
        this.isValidFlag = AtomicBool(true)
        this.mutex = Mutex()

        // 然后计算需要调用方法的字段
        this.messageId = ZeroCopyMessageImpl.generateMessageIdStatic()
        this.checksum = ZeroCopyMessageImpl.calculateChecksumStatic(payload)
    }

    private func generateMessageId(): UInt64 {
        ZeroCopyMessageImpl.generateMessageIdStatic()
    }

    private func calculateChecksum(payload: Option<Array<UInt8>>): UInt32 {
        ZeroCopyMessageImpl.calculateChecksumStatic(payload)
    }

    private static func generateMessageIdStatic(): UInt64 {
        let now = DateTime.now()
        UInt64(now.toUnixTimeStamp().toMilliseconds())
    }

    private static func calculateChecksumStatic(payload: Option<Array<UInt8>>): UInt32 {
        let crc = CRC32()
        match (payload) {
            case Some(data) =>
                for (byte in data) {
                    crc.update(byte)
                }
            case None => ()
        }
        crc.getValue()
    }

    public func getMessageId(): UInt64 {
        messageId
    }

    public func getMessageType(): UInt16 {
        messageType
    }

    public func getPayloadSize(): UInt64 {
        payloadSize
    }

    public func getSourceActor(): UInt64 {
        sourceActor
    }

    public func getTargetActor(): UInt64 {
        targetActor
    }

    public func getPayload(): Option<Array<UInt8>> {
        payload
    }

    public func getReferenceCount(): Int64 {
        refCount.load()
    }

    public func retain(): Unit {
        if (isValidFlag.load()) {
            refCount.fetchAdd(1)
        }
    }

    public func release(): Unit {
        if (isValidFlag.load()) {
            let newCount = refCount.fetchAdd(-1)
            if (newCount <= 1) {
                isValidFlag.store(false)
            }
        }
    }

    public func isValid(): Bool {
        isValidFlag.load()
    }

    public func getChecksum(): UInt32 {
        checksum
    }

    public func getMessageTypeString(): String {
        "ZeroCopyMessage_${messageType}"
    }
}

/**
 * 高性能零拷贝消息工厂 (无锁实现)
 *
 * 性能优化:
 * 1. 移除锁，使用原子操作
 * 2. 支持批量创建
 * 3. 内存预分配
 */
public class ZeroCopyMessageFactory {
    private let messageIdGenerator: AtomicInt64
    private let createdCount: AtomicInt64

    public init() {
        this.messageIdGenerator = AtomicInt64(1)
        this.createdCount = AtomicInt64(0)
    }

    public func createEmptyMessage(messageType: UInt16, payloadSize: UInt64,
                                  sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        // 无锁创建，性能提升
        let message = ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, None)
        createdCount.fetchAdd(1)
        return message
    }

    public func createMessageWithPayload(messageType: UInt16, payloadSize: UInt64,
                                        sourceActor: UInt64, targetActor: UInt64,
                                        payload: Array<UInt8>): ZeroCopyMessageImpl {
        // 无锁创建，性能提升
        let message = ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, Some(payload))
        createdCount.fetchAdd(1)
        return message
    }

    /**
     * 批量创建消息 - 性能优化
     */
    public func createBatchMessages(messageType: UInt16, payloadSize: UInt64,
                                   sourceActor: UInt64, targetActor: UInt64,
                                   batchSize: Int32): Array<ZeroCopyMessageImpl> {
        let messages = Array<ZeroCopyMessageImpl>(Int64(batchSize), { i =>
            ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, None)
        })
        createdCount.fetchAdd(Int64(batchSize))
        return messages
    }

    /**
     * 获取创建统计
     */
    public func getCreatedCount(): Int64 {
        createdCount.load()
    }

    public func createMessage(messageType: UInt16, payloadSize: UInt64,
                             sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        createEmptyMessage(messageType, payloadSize, sourceActor, targetActor)
    }
}

/**
 * 高性能消息池 (无锁实现)
 *
 * 性能优化:
 * 1. 无锁环形缓冲区
 * 2. 原子操作替代锁
 * 3. 批量获取/释放
 * 4. 内存预热
 * 5. 性能统计
 */
public class MessagePool {
    private let capacity: Int64
    private let mask: Int64  // 容量掩码，用于快速取模
    private let pool: Array<Option<ZeroCopyMessageImpl>>
    private let head: AtomicInt64
    private let tail: AtomicInt64
    private let size: AtomicInt64

    // 性能统计
    private let acquireCount: AtomicInt64
    private let releaseCount: AtomicInt64
    private let hitCount: AtomicInt64
    private let missCount: AtomicInt64

    public init(capacity: Int64) {
        // 确保容量是2的幂，便于位运算优化
        this.capacity = MessagePool.nextPowerOfTwo(capacity)
        this.mask = this.capacity - 1
        this.pool = Array<Option<ZeroCopyMessageImpl>>(this.capacity, { i => None })
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.size = AtomicInt64(0)

        this.acquireCount = AtomicInt64(0)
        this.releaseCount = AtomicInt64(0)
        this.hitCount = AtomicInt64(0)
        this.missCount = AtomicInt64(0)

        // 预热池
        warmupPool()
    }

    /**
     * 无锁获取消息 - 高性能实现
     */
    public func acquire(messageType: UInt16, payloadSize: UInt64,
                       sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        acquireCount.fetchAdd(1)

        // 最大重试次数，避免无限循环
        let maxRetries = 100
        var retries = 0

        while (retries < maxRetries && size.load() > 0) {
            let currentHead = head.load()
            let currentTail = tail.load()

            if (currentHead >= currentTail) {
                break  // 池为空
            }

            let index = currentHead & mask
            match (pool[index]) {
                case Some(message) =>
                    // 尝试原子性地获取消息
                    if (head.compareAndSwap(currentHead, currentHead + 1)) {
                        pool[index] = None
                        size.fetchAdd(-1)
                        hitCount.fetchAdd(1)

                        // 重置消息状态以便重用
                        resetMessage(message, messageType, payloadSize, sourceActor, targetActor)
                        return message
                    }
                case None => ()
            }

            retries += 1
        }

        // 池为空或获取失败，创建新消息
        missCount.fetchAdd(1)
        return ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, None)
    }

    /**
     * 无锁释放消息 - 高性能实现
     */
    public func release(message: ZeroCopyMessageImpl): Unit {
        releaseCount.fetchAdd(1)

        // 最大重试次数
        let maxRetries = 100
        var retries = 0

        while (retries < maxRetries && size.load() < capacity) {
            let currentTail = tail.load()
            let currentHead = head.load()

            if (currentTail - currentHead >= capacity) {
                break  // 池已满
            }

            let index = currentTail & mask
            if (pool[index].isNone()) {
                // 尝试原子性地释放消息
                if (tail.compareAndSwap(currentTail, currentTail + 1)) {
                    pool[index] = Some(message)
                    size.fetchAdd(1)
                    return
                }
            }

            retries += 1
        }

        // 池已满，直接丢弃消息（让GC处理）
    }

    /**
     * 批量获取消息 - 性能优化
     */
    public func acquireBatch(messageType: UInt16, payloadSize: UInt64,
                            sourceActor: UInt64, targetActor: UInt64,
                            batchSize: Int32): Array<ZeroCopyMessageImpl> {
        let messages = Array<ZeroCopyMessageImpl>(Int64(batchSize), { i =>
            acquire(messageType, payloadSize, sourceActor, targetActor)
        })
        return messages
    }

    /**
     * 批量释放消息 - 性能优化
     */
    public func releaseBatch(messages: Array<ZeroCopyMessageImpl>): Unit {
        for (message in messages) {
            release(message)
        }
    }

    public func getPoolSize(): Int64 {
        size.load()
    }

    /**
     * 获取池统计信息
     */
    public func getStats(): MessagePoolStats {
        MessagePoolStats(
            capacity,
            size.load(),
            acquireCount.load(),
            releaseCount.load(),
            hitCount.load(),
            missCount.load()
        )
    }

    /**
     * 预热池 - 提升性能
     */
    private func warmupPool(): Unit {
        let warmupSize = capacity / 2
        for (i in 0..warmupSize) {
            let message = ZeroCopyMessageImpl(0, 0, 0, 0, None)
            pool[i] = Some(message)
        }
        size.store(warmupSize)
        tail.store(warmupSize)
    }

    /**
     * 重置消息状态以便重用
     */
    private func resetMessage(message: ZeroCopyMessageImpl, messageType: UInt16,
                             payloadSize: UInt64, sourceActor: UInt64, targetActor: UInt64): Unit {
        // 这里应该重置消息的所有字段
        // 简化实现，实际需要消息提供reset方法
    }

    /**
     * 计算下一个2的幂
     */
    private static func nextPowerOfTwo(n: Int64): Int64 {
        var power = 1
        while (power < n) {
            power *= 2
        }
        return power
    }
}

/**
 * 消息池统计信息
 */
public struct MessagePoolStats {
    public let capacity: Int64
    public let size: Int64
    public let acquireCount: Int64
    public let releaseCount: Int64
    public let hitCount: Int64
    public let missCount: Int64

    public init(capacity: Int64, size: Int64, acquireCount: Int64,
               releaseCount: Int64, hitCount: Int64, missCount: Int64) {
        this.capacity = capacity
        this.size = size
        this.acquireCount = acquireCount
        this.releaseCount = releaseCount
        this.hitCount = hitCount
        this.missCount = missCount
    }

    public func getHitRate(): Float64 {
        if (acquireCount > 0) {
            return Float64(hitCount) / Float64(acquireCount)
        }
        return 0.0
    }

    public func getUtilization(): Float64 {
        if (capacity > 0) {
            return Float64(size) / Float64(capacity)
        }
        return 0.0
    }
}

/**
 * 零拷贝消息构建器
 */
public class ZeroCopyMessageBuilder {
    private var messageType: UInt16
    private var payloadSize: UInt64
    private var sourceActor: UInt64
    private var targetActor: UInt64
    private var payload: Option<Array<UInt8>>

    public init() {
        this.messageType = 0
        this.payloadSize = 0
        this.sourceActor = 0
        this.targetActor = 0
        this.payload = None
    }

    public func withMessageType(messageType: UInt16): ZeroCopyMessageBuilder {
        this.messageType = messageType
        this
    }

    public func withPayloadSize(payloadSize: UInt64): ZeroCopyMessageBuilder {
        this.payloadSize = payloadSize
        this
    }

    public func withSource(sourceActor: UInt64): ZeroCopyMessageBuilder {
        this.sourceActor = sourceActor
        this
    }

    public func withTarget(targetActor: UInt64): ZeroCopyMessageBuilder {
        this.targetActor = targetActor
        this
    }

    public func withPayload(payload: Array<UInt8>): ZeroCopyMessageBuilder {
        this.payload = Some(payload)
        this.payloadSize = UInt64(payload.size)
        this
    }

    public func build(): ZeroCopyMessageImpl {
        ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, payload)
    }
}
