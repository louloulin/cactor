/*
 * Copyright (c) 2024. All rights reserved.
 * Core Layer - 网络消息传输
 * 基于Foundation层网络传输的消息网络传输实现
 */
package cactor.core.message

import std.collection.*
import cactor.foundation.network.{NetworkTransport, TcpTransport, UdpTransport, NetworkAddress}
import cactor.foundation.serialization.SerializationManager

/**
 * 网络消息包装器
 * 包装要通过网络发送的消息，添加Actor相关信息
 */
public struct NetworkMessage {
    public let targetActor: String
    public let message: Message
    public let sender: Option<String>
    public let messageId: String
    public let timestamp: Int64

    public init(targetActor: String, message: Message, sender: Option<String>) {
        this.targetActor = targetActor
        this.message = message
        this.sender = sender
        this.messageId = NetworkMessage.generateMessageId()
        this.timestamp = NetworkMessage.getCurrentTimeNanos()
    }

    private static func generateMessageId(): String {
        "msg_${getCurrentTimeNanos()}"
    }

    private static func getCurrentTimeNanos(): Int64 {
        1000000000
    }
}

/**
 * 网络消息序列化器
 * 将NetworkMessage序列化为字节流，用于网络传输
 */
public class NetworkMessageSerializer {
    private let serializationManager: SerializationManager
    private let messageSerializer: MessageSerializer

    public init() {
        this.serializationManager = SerializationManager()
        this.messageSerializer = MessageSerializer()
    }

    public func serialize(networkMessage: NetworkMessage): Array<UInt8> {
        let result = ArrayList<UInt8>()

        // 序列化目标Actor
        let targetBytes = serializationManager.serializeString(networkMessage.targetActor)
        writeInt32(result, Int32(targetBytes.size))
        for (b in targetBytes) {
            result.add(b)
        }

        // 序列化发送者
        let senderStr = match (networkMessage.sender) {
            case Some(s) => s
            case None => ""
        }
        let senderBytes = serializationManager.serializeString(senderStr)
        writeInt32(result, Int32(senderBytes.size))
        for (b in senderBytes) {
            result.add(b)
        }

        // 序列化消息ID
        let messageIdBytes = serializationManager.serializeString(networkMessage.messageId)
        writeInt32(result, Int32(messageIdBytes.size))
        for (b in messageIdBytes) {
            result.add(b)
        }

        // 序列化时间戳
        let timestampBytes = serializationManager.serializeInt(networkMessage.timestamp)
        for (b in timestampBytes) {
            result.add(b)
        }

        // 序列化消息内容
        let messageBytes = messageSerializer.serialize(networkMessage.message)
        writeInt32(result, Int32(messageBytes.size))
        for (b in messageBytes) {
            result.add(b)
        }

        result.toArray()
    }

    public func deserialize(data: Array<UInt8>): NetworkMessage {
        if (data.size < 4) {
            throw NetworkMessageException("数据不完整")
        }

        var offset = 0

        // 读取目标Actor
        let targetLength = readInt32(data, offset)
        offset += 4
        let targetBytes = data.slice(Int64(offset), Int64(offset) + Int64(targetLength))
        let targetActor = serializationManager.deserializeString(targetBytes)
        offset += Int64(targetLength)

        // 读取发送者
        let senderLength = readInt32(data, offset)
        offset += 4
        let senderBytes = data.slice(Int64(offset), Int64(offset) + Int64(senderLength))
        let senderStr = serializationManager.deserializeString(senderBytes)
        let sender: Option<String> = if (senderStr.isEmpty()) { None } else { Some(senderStr) }
        offset += Int64(senderLength)

        // 读取消息ID
        let messageIdLength = readInt32(data, offset)
        offset += 4
        let messageIdBytes = data.slice(Int64(offset), Int64(offset) + Int64(messageIdLength))
        let messageId = serializationManager.deserializeString(messageIdBytes)
        offset += Int64(messageIdLength)

        // 读取时间戳
        let timestampBytes = data.slice(Int64(offset), Int64(offset) + 8)
        let timestamp = serializationManager.deserializeInt(timestampBytes)
        offset += 8

        // 读取消息内容
        let messageLength = readInt32(data, offset)
        offset += 4
        let messageBytes = data.slice(Int64(offset), Int64(offset) + Int64(messageLength))
        let message = messageSerializer.deserialize(messageBytes)

        NetworkMessage(targetActor, message, sender)
    }

    private func writeInt32(buffer: ArrayList<UInt8>, value: Int32): Unit {
        buffer.add(UInt8((value >> 24) & 0xFF))
        buffer.add(UInt8((value >> 16) & 0xFF))
        buffer.add(UInt8((value >> 8) & 0xFF))
        buffer.add(UInt8(value & 0xFF))
    }

    private func readInt32(data: Array<UInt8>, offset: Int64): Int32 {
        (Int32(data[offset]) << 24) |
        (Int32(data[offset + 1]) << 16) |
        (Int32(data[offset + 2]) << 8) |
        Int32(data[offset + 3])
    }
}

/**
 * 网络消息传输器
 */
public class NetworkMessageTransport {
    private let transport: NetworkTransport

    public init(transport: NetworkTransport) {
        this.transport = transport
    }

    public func send(networkMessage: NetworkMessage, address: NetworkAddress): Unit {
        let data = serializeMessage(networkMessage)
        transport.send(address, data)
    }

    private func serializeMessage(msg: NetworkMessage): Array<UInt8> {
        let serializer = NetworkMessageSerializer()
        serializer.serialize(msg)
    }

    private func deserializeMessage(data: Array<UInt8>): NetworkMessage {
        let serializer = NetworkMessageSerializer()
        serializer.deserialize(data)
    }
}

/**
 * 网络消息异常
 */
public class NetworkMessageException <: Exception {
    public init(message: String) {
        super(message)
    }
}
