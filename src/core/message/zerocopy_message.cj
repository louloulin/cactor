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
    private let mutex: ReentrantMutex

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
        this.mutex = ReentrantMutex()

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
 * 零拷贝消息工厂
 */
public class ZeroCopyMessageFactory {
    private let mutex: ReentrantMutex

    public init() {
        this.mutex = ReentrantMutex()
    }

    public func createEmptyMessage(messageType: UInt16, payloadSize: UInt64, 
                                  sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        mutex.lock()
        try {
            ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, None)
        } finally {
            mutex.unlock()
        }
    }

    public func createMessageWithPayload(messageType: UInt16, payloadSize: UInt64,
                                        sourceActor: UInt64, targetActor: UInt64,
                                        payload: Array<UInt8>): ZeroCopyMessageImpl {
        mutex.lock()
        try {
            ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, Some(payload))
        } finally {
            mutex.unlock()
        }
    }

    public func createMessage(messageType: UInt16, payloadSize: UInt64,
                             sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        createEmptyMessage(messageType, payloadSize, sourceActor, targetActor)
    }
}

/**
 * 消息池
 */
public class MessagePool {
    private let capacity: Int64
    private let pool: Array<Option<ZeroCopyMessageImpl>>
    private let head: AtomicInt64
    private let tail: AtomicInt64
    private let size: AtomicInt64
    private let mutex: ReentrantMutex

    public init(capacity: Int64) {
        this.capacity = capacity
        this.pool = Array<Option<ZeroCopyMessageImpl>>(capacity, { i => None })
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.size = AtomicInt64(0)
        this.mutex = ReentrantMutex()
    }

    public func acquire(messageType: UInt16, payloadSize: UInt64, 
                       sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        mutex.lock()
        try {
            if (size.load() > 0) {
                let headPos = head.load()
                match (pool[headPos]) {
                    case Some(message) =>
                        pool[headPos] = None
                        head.store((headPos + 1) % capacity)
                        size.fetchAdd(-1)
                        return message
                    case None => ()
                }
            }
            
            // 池为空，创建新消息
            ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor, None)
        } finally {
            mutex.unlock()
        }
    }

    public func release(message: ZeroCopyMessageImpl): Unit {
        mutex.lock()
        try {
            if (size.load() < capacity) {
                let tailPos = tail.load()
                pool[tailPos] = Some(message)
                tail.store((tailPos + 1) % capacity)
                size.fetchAdd(1)
            }
        } finally {
            mutex.unlock()
        }
    }

    public func getPoolSize(): Int64 {
        size.load()
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
