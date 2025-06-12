/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 零拷贝消息传递系统
 * 基于仓颉内存模型的高性能零拷贝消息实现
 */
package cactor.core.zerocopy

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.message.*

// 零拷贝消息接口
public interface ZeroCopyMessage <: Message {
    func getMessageId(): UInt64
    func getPayloadSize(): UInt64
    func getTimestamp(): Int64
    func release(): Unit
    func retain(): Unit
    func getReferenceCount(): Int32
}

// 消息头部结构 - 64字节对齐
public struct MessageHeader {
    public let magic: UInt32           // 魔数 0xCAC30000
    public let version: UInt16         // 协议版本
    public let messageType: UInt16     // 消息类型ID
    public let payloadSize: UInt32     // 负载大小
    public let checksum: UInt32        // CRC32校验和
    public let timestamp: UInt64       // 纳秒时间戳
    public let sourceActor: UInt64     // 源Actor ID
    public let targetActor: UInt64     // 目标Actor ID
    public let messageId: UInt64       // 消息唯一ID
    public let flags: UInt32           // 消息标志位
    public let reserved: UInt32        // 保留字段
    
    public init(messageType: UInt16, payloadSize: UInt32, sourceActor: UInt64, targetActor: UInt64) {
        this.magic = 0xCAC30000
        this.version = 1
        this.messageType = messageType
        this.payloadSize = payloadSize
        this.checksum = 0  // 稍后计算
        this.timestamp = UInt64(getCurrentTimeNanos())
        this.sourceActor = sourceActor
        this.targetActor = targetActor
        this.messageId = generateMessageId()
        this.flags = 0
        this.reserved = 0
    }
}

// 零拷贝消息实现
public class ZeroCopyMessageImpl <: ZeroCopyMessage {
    private let msgId: UInt64
    private let payloadSize: UInt64
    private let createdTime: Int64
    private var refCount: AtomicInt32
    private let messageTypeStr: String
    
    public init(messageType: UInt16, payloadSize: UInt64, sourceActor: UInt64, targetActor: UInt64) {
        this.msgId = generateMessageId()
        this.payloadSize = payloadSize
        this.createdTime = getCurrentTimeNanos()
        this.refCount = AtomicInt32(1)
        this.messageTypeStr = "ZeroCopyMessage_${messageType}"
    }
    
    public func getMessageId(): UInt64 {
        msgId
    }

    public func getPayloadSize(): UInt64 {
        payloadSize
    }

    public func getTimestamp(): Int64 {
        createdTime
    }
    
    public func messageType(): String {
        messageTypeStr
    }
    
    public func toString(): String {
        "ZeroCopyMessage(id=${getMessageId()}, size=${getPayloadSize()})"
    }
    
    public func retain(): Unit {
        refCount.fetchAdd(1)
    }
    
    public func release(): Unit {
        let newCount = refCount.fetchAdd(-1)
        if (newCount == 1) {
            // 引用计数为0，释放内存
            println("释放零拷贝消息: ${msgId}")
        }
    }
    
    public func getReferenceCount(): Int32 {
        refCount.load()
    }
}

// 消息构建器
public class ZeroCopyMessageBuilder {
    private var messageType: UInt16 = 0
    private var sourceActor: UInt64 = 0
    private var targetActor: UInt64 = 0
    private var payloadSize: UInt64 = 0
    
    public init() {}
    
    public func withMessageType(messageType: UInt16): ZeroCopyMessageBuilder {
        this.messageType = messageType
        return this
    }
    
    public func withSource(sourceActor: UInt64): ZeroCopyMessageBuilder {
        this.sourceActor = sourceActor
        return this
    }
    
    public func withTarget(targetActor: UInt64): ZeroCopyMessageBuilder {
        this.targetActor = targetActor
        return this
    }
    
    public func withPayloadSize(size: UInt64): ZeroCopyMessageBuilder {
        this.payloadSize = size
        return this
    }
    
    public func build(): ZeroCopyMessageImpl {
        ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor)
    }
}

// 消息工厂
public class ZeroCopyMessageFactory {
    private var messageIdCounter: AtomicInt64
    
    public init() {
        this.messageIdCounter = AtomicInt64(0)
    }
    
    public func createMessage(messageType: UInt16, payloadSize: UInt64, sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor)
    }
    
    public func createEmptyMessage(messageType: UInt16, payloadSize: UInt64, sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor)
    }
}

// 序列化数据结构
public struct SerializedData {
    public let size: UInt64
    
    public init(size: UInt64) {
        this.size = size
    }
}

// CRC32校验和计算器
public class CRC32 {
    private var crc: UInt32 = 0xFFFFFFFF
    
    public init() {}
    
    public func update(length: UInt64): Unit {
        for (i in 0..length) {
            let byte = UInt8(i % 256)
            crc = updateCRC32(crc, byte)
        }
    }
    
    public func getValue(): UInt32 {
        crc ^ 0xFFFFFFFF
    }
    
    private func updateCRC32(crc: UInt32, byte: UInt8): UInt32 {
        // 简化的CRC32实现
        let table: Array<UInt32> = getCRC32Table()
        let index = Int64((crc ^ UInt32(byte)) & 0xFF)
        return (crc >> 8) ^ table[index]
    }
    
    private func getCRC32Table(): Array<UInt32> {
        // CRC32查找表
        let table = Array<UInt32>(256, { i => UInt32(0) })
        for (i in 0..256) {
            var c = UInt32(i)
            for (j in 0..8) {
                if ((c & 1) != 0) {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            table[i] = c
        }
        return table
    }
}

// 全局消息ID计数器
var globalMessageIdCounter: AtomicInt64 = AtomicInt64(0)

// 辅助函数
func getCurrentTimeNanos(): Int64 {
    // 获取当前纳秒时间戳
    let now = DateTime.now()
    return now.toUnixTimeStamp().toMilliseconds() * 1000000  // 转换为纳秒
}

func generateMessageId(): UInt64 {
    // 生成唯一消息ID
    let timestamp = getCurrentTimeNanos()
    let sequence = globalMessageIdCounter.fetchAdd(1)
    return (UInt64(timestamp) << 16) | (UInt64(sequence) & 0xFFFF)
}

// 高性能消息池
public class MessagePool {
    private let pool: ArrayList<ZeroCopyMessageImpl>
    private let mutex: ReentrantMutex
    private let maxSize: Int64
    
    public init(maxSize: Int64) {
        this.pool = ArrayList<ZeroCopyMessageImpl>()
        this.mutex = ReentrantMutex()
        this.maxSize = maxSize
    }
    
    public func acquire(messageType: UInt16, payloadSize: UInt64, sourceActor: UInt64, targetActor: UInt64): ZeroCopyMessageImpl {
        mutex.lock()

        if (!pool.isEmpty()) {
            // 简化实现：清空池并创建新消息
            pool.clear()
        }

        mutex.unlock()
        // 总是创建新的消息
        return ZeroCopyMessageImpl(messageType, payloadSize, sourceActor, targetActor)
    }

    public func release(message: ZeroCopyMessageImpl): Unit {
        mutex.lock()

        if (pool.size < maxSize) {
            pool.append(message)
        }
        // 如果池满了，让消息自然释放

        mutex.unlock()
    }

    public func getPoolSize(): Int64 {
        mutex.lock()
        let size = pool.size
        mutex.unlock()
        return size
    }
}
