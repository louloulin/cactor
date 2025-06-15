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
        // 简化的消息ID生成
        "msg_${getCurrentTimeNanos()}"
    }

    private static func getCurrentTimeNanos(): Int64 {
        // 简化实现
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

    /**
     * 序列化网络消息
     */
    public func serialize(networkMessage: NetworkMessage): Array<UInt8> {
        let result = ArrayList<UInt8>()
        
        // 序列化目标Actor
        let targetBytes = serializationManager.serializeString(networkMessage.targetActor)
        writeInt32(result, Int32(targetBytes.size))
        result.appendAll(targetBytes)
        
        // 序列化发送者
        let senderStr = match (networkMessage.sender) {
            case Some(s) => s
            case None => ""
        }
        let senderBytes = serializationManager.serializeString(senderStr)
        writeInt32(result, Int32(senderBytes.size))
        result.appendAll(senderBytes)
        
        // 序列化消息ID
        let messageIdBytes = serializationManager.serializeString(networkMessage.messageId)
        writeInt32(result, Int32(messageIdBytes.size))
        result.appendAll(messageIdBytes)
        
        // 序列化时间戳
        let timestampBytes = serializationManager.serializeInt(networkMessage.timestamp)
        result.appendAll(timestampBytes)
        
        // 序列化消息内容
        let messageBytes = messageSerializer.serialize(networkMessage.message)
        writeInt32(result, Int32(messageBytes.size))
        result.appendAll(messageBytes)
        
        result.toArray()
    }

    /**
     * 反序列化网络消息
     */
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
        
        // 创建NetworkMessage（简化实现）
        let networkMessage = NetworkMessage(targetActor, message, sender)
        networkMessage
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
 * 网络消息传输器
 * 基于Foundation层网络传输实现消息的网络传输
 */
public class NetworkMessageTransport {
    private let transport: NetworkTransport
    private let serializer: NetworkMessageSerializer
    private var messageHandler: Option<(NetworkMessage) -> Unit>

    public init(transport: NetworkTransport) {
        this.transport = transport
        this.serializer = NetworkMessageSerializer()
        this.messageHandler = None
        
        // 设置字节流处理器
        transport.setDataHandler({ data => this.handleReceivedData(data) })
    }

    /**
     * 发送网络消息
     */
    public func send(address: NetworkAddress, networkMessage: NetworkMessage): Unit {
        let data = serializer.serialize(networkMessage)
        transport.send(address, data)
    }

    /**
     * 设置消息处理器
     */
    public func setMessageHandler(handler: (NetworkMessage) -> Unit): Unit {
        this.messageHandler = Some(handler)
    }

    /**
     * 启动传输器
     */
    public func start(): Unit {
        transport.start()
    }

    /**
     * 停止传输器
     */
    public func stop(): Unit {
        transport.stop()
    }

    /**
     * 检查是否活跃
     */
    public func isActive(): Bool {
        transport.isActive()
    }

    /**
     * 获取本地地址
     */
    public func getLocalAddress(): NetworkAddress {
        transport.getLocalAddress()
    }

    /**
     * 处理接收到的字节数据
     */
    private func handleReceivedData(data: Array<UInt8>): Unit {
        try {
            let networkMessage = serializer.deserialize(data)
            match (messageHandler) {
                case Some(handler) => handler(networkMessage)
                case None => println("警告：没有设置消息处理器")
            }
        } catch (e: Exception) {
            println("网络消息反序列化失败: ${e.message}")
        }
    }
}

/**
 * 网络消息传输工厂
 * 创建不同类型的网络消息传输器
 */
public class NetworkMessageTransportFactory {
    /**
     * 创建TCP网络消息传输器
     */
    public static func createTcpTransport(localAddress: NetworkAddress): NetworkMessageTransport {
        let tcpTransport = TcpTransport(localAddress)
        NetworkMessageTransport(tcpTransport)
    }

    /**
     * 创建UDP网络消息传输器
     */
    public static func createUdpTransport(localAddress: NetworkAddress): NetworkMessageTransport {
        let udpTransport = UdpTransport(localAddress)
        NetworkMessageTransport(udpTransport)
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

/**
 * 远程消息发送器
 * 提供简化的远程消息发送接口
 */
public class RemoteMessageSender {
    private let transport: NetworkMessageTransport

    public init(transport: NetworkMessageTransport) {
        this.transport = transport
    }

    /**
     * 发送消息到远程Actor
     */
    public func sendToRemoteActor(remoteAddress: NetworkAddress, targetActor: String, 
                                  message: Message, sender: Option<String>): Unit {
        let networkMessage = NetworkMessage(targetActor, message, sender)
        transport.send(remoteAddress, networkMessage)
    }

    /**
     * 启动发送器
     */
    public func start(): Unit {
        transport.start()
    }

    /**
     * 停止发送器
     */
    public func stop(): Unit {
        transport.stop()
    }
}
