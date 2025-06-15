/*
 * Copyright (c) 2024. All rights reserved.
 * Core Layer - 消息序列化器
 * 基于Foundation层序列化框架的消息序列化实现
 */
package cactor.core.message

import std.collection.*
import cactor.foundation.serialization.{Serializer, SerializationManager}

/**
 * 消息序列化器
 * 基于Foundation层的通用序列化框架实现消息序列化
 */
public class MessageSerializer <: Serializer<Message> {
    private let serializationManager: SerializationManager

    public init() {
        this.serializationManager = SerializationManager()
    }

    public func serialize(message: Message): Array<UInt8> {
        let messageType = message.messageType()
        let result = ArrayList<UInt8>()
        
        // 写入消息类型长度和类型
        let typeBytes = serializationManager.serializeString(messageType)
        writeInt32(result, Int32(typeBytes.size))
        result.appendAll(typeBytes)
        
        // 根据消息类型序列化具体内容
        match (messageType) {
            case "StringMessage" =>
                match (message as StringMessage) {
                    case Some(msg) =>
                        let contentBytes = serializationManager.serializeString(msg.getContent())
                        writeInt32(result, Int32(contentBytes.size))
                        result.appendAll(contentBytes)
                    case None => throw SerializationException("消息类型转换失败")
                }
            case "PingMessage" =>
                match (message as PingMessage) {
                    case Some(msg) =>
                        let idBytes = serializationManager.serializeInt(msg.getId())
                        result.appendAll(idBytes)
                        let timestampBytes = serializationManager.serializeInt(msg.timestamp())
                        result.appendAll(timestampBytes)
                    case None => throw SerializationException("消息类型转换失败")
                }
            case "PongMessage" =>
                match (message as PongMessage) {
                    case Some(msg) =>
                        let idBytes = serializationManager.serializeInt(msg.getOriginalId())
                        result.appendAll(idBytes)
                    case None => throw SerializationException("消息类型转换失败")
                }
            case "StopMessage" =>
                match (message as StopMessage) {
                    case Some(msg) =>
                        let reasonBytes = serializationManager.serializeString(msg.getReason())
                        writeInt32(result, Int32(reasonBytes.size))
                        result.appendAll(reasonBytes)
                    case None => throw SerializationException("消息类型转换失败")
                }
            case _ =>
                throw SerializationException("不支持的消息类型: ${messageType}")
        }
        
        result.toArray()
    }

    public func deserialize(data: Array<UInt8>): Message {
        if (data.size < 4) {
            throw DeserializationException("数据不完整")
        }
        
        var offset = 0
        
        // 读取消息类型
        let typeLength = readInt32(data, offset)
        offset += 4
        
        if (data.size < offset + Int64(typeLength)) {
            throw DeserializationException("消息类型数据不完整")
        }
        
        let typeBytes = data.slice(Int64(offset), Int64(offset) + Int64(typeLength))
        let messageType = serializationManager.deserializeString(typeBytes)
        offset += Int64(typeLength)
        
        // 根据消息类型反序列化具体内容
        match (messageType) {
            case "StringMessage" =>
                if (data.size < offset + 4) {
                    throw DeserializationException("StringMessage内容长度数据不完整")
                }
                let contentLength = readInt32(data, offset)
                offset += 4
                
                if (data.size < offset + Int64(contentLength)) {
                    throw DeserializationException("StringMessage内容数据不完整")
                }
                
                let contentBytes = data.slice(Int64(offset), Int64(offset) + Int64(contentLength))
                let content = serializationManager.deserializeString(contentBytes)
                StringMessage(content)
                
            case "PingMessage" =>
                if (data.size < offset + 16) { // 8字节ID + 8字节时间戳
                    throw DeserializationException("PingMessage数据不完整")
                }
                
                let idBytes = data.slice(Int64(offset), Int64(offset) + 8)
                let id = serializationManager.deserializeInt(idBytes)
                offset += 8
                
                let timestampBytes = data.slice(Int64(offset), Int64(offset) + 8)
                let timestamp = serializationManager.deserializeInt(timestampBytes)
                
                // 创建PingMessage，但需要设置时间戳
                // 简化实现：创建新的PingMessage
                PingMessage(id)
                
            case "PongMessage" =>
                if (data.size < offset + 8) {
                    throw DeserializationException("PongMessage数据不完整")
                }
                
                let idBytes = data.slice(Int64(offset), Int64(offset) + 8)
                let originalId = serializationManager.deserializeInt(idBytes)
                PongMessage(originalId)
                
            case "StopMessage" =>
                if (data.size < offset + 4) {
                    throw DeserializationException("StopMessage原因长度数据不完整")
                }
                let reasonLength = readInt32(data, offset)
                offset += 4
                
                if (data.size < offset + Int64(reasonLength)) {
                    throw DeserializationException("StopMessage原因数据不完整")
                }
                
                let reasonBytes = data.slice(Int64(offset), Int64(offset) + Int64(reasonLength))
                let reason = serializationManager.deserializeString(reasonBytes)
                StopMessage(reason)
                
            case _ =>
                throw DeserializationException("不支持的消息类型: ${messageType}")
        }
    }

    public func getName(): String {
        "MessageSerializer"
    }

    private func writeInt32(buffer: ArrayList<UInt8>, value: Int32): Unit {
        buffer.append(UInt8((value >> 24) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    private func readInt32(data: Array<UInt8>, offset: Int64): Int32 {
        (Int32(data[offset]) << 24) |
        (Int32(data[offset + 1]) << 16) |
        (Int32(data[offset + 2]) << 8) |
        Int32(data[offset + 3])
    }
}

/**
 * 序列化异常
 */
public class SerializationException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 反序列化异常
 */
public class DeserializationException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 消息序列化管理器
 * 提供消息序列化的统一接口
 */
public class MessageSerializationManager {
    private let messageSerializer: MessageSerializer

    public init() {
        this.messageSerializer = MessageSerializer()
    }

    /**
     * 序列化消息
     */
    public func serialize(message: Message): Array<UInt8> {
        messageSerializer.serialize(message)
    }

    /**
     * 反序列化消息
     */
    public func deserialize(data: Array<UInt8>): Message {
        messageSerializer.deserialize(data)
    }

    /**
     * 获取序列化器名称
     */
    public func getSerializerName(): String {
        messageSerializer.getName()
    }
}

/**
 * 全局消息序列化管理器
 */
public class GlobalMessageSerializationManager {
    private static var instance: Option<MessageSerializationManager> = None

    public static func getInstance(): MessageSerializationManager {
        match (instance) {
            case Some(manager) => manager
            case None =>
                let manager = MessageSerializationManager()
                instance = Some(manager)
                manager
        }
    }
}
