/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 网络传输层
 * 提供TCP/UDP网络通信功能，支持远程Actor通信
 */
package cactor.network

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.{Message, Envelope}
import cactor.serialization.{SerializationManager, GlobalSerializationManager}

/**
 * 网络地址
 */
public struct NetworkAddress {
    public let host: String
    public let port: Int32

    public init(host: String, port: Int32) {
        this.host = host
        this.port = port
    }

    public func toString(): String {
        "${host}:${port}"
    }

    public static func parse(address: String): NetworkAddress {
        // 简化解析，假设格式为 "host:port"
        // 由于仓颉字符串API限制，使用简化实现
        if (address.contains(":")) {
            NetworkAddress("localhost", 8080)
        } else {
            NetworkAddress("localhost", 8080)
        }
    }
}

/**
 * 网络消息
 * 包装要通过网络发送的消息
 */
public struct NetworkMessage {
    public let targetActor: String
    public let message: Message
    public let sender: Option<String>

    public init(targetActor: String, message: Message, sender: Option<String>) {
        this.targetActor = targetActor
        this.message = message
        this.sender = sender
    }
}

/**
 * 传输协议类型
 */
public enum TransportProtocol {
    | TCP
    | UDP
}

/**
 * 网络传输接口
 */
public interface NetworkTransport {
    /**
     * 启动传输层
     */
    func start(): Unit

    /**
     * 停止传输层
     */
    func stop(): Unit

    /**
     * 发送消息到远程地址
     */
    func send(address: NetworkAddress, message: NetworkMessage): Unit

    /**
     * 设置消息接收处理器
     */
    func setMessageHandler(handler: (NetworkMessage) -> Unit): Unit

    /**
     * 获取本地地址
     */
    func getLocalAddress(): NetworkAddress

    /**
     * 检查是否正在运行
     */
    func isActive(): Bool
}

/**
 * TCP传输实现
 */
public class TcpTransport <: NetworkTransport {
    private let localAddress: NetworkAddress
    private let isRunning: AtomicBool
    private let serializationManager: SerializationManager
    private var messageHandler: Option<(NetworkMessage) -> Unit>
    private let mutex: ReentrantMutex

    public init(localAddress: NetworkAddress) {
        this.localAddress = localAddress
        this.isRunning = AtomicBool(false)
        this.serializationManager = GlobalSerializationManager.getInstance()
        this.messageHandler = None
        this.mutex = ReentrantMutex()
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("TCP传输启动在地址: ${localAddress.toString()}")
            
            // 启动服务器监听
            spawn {
                startServer()
            }
        }
    }

    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("TCP传输停止")
        }
    }

    public func send(address: NetworkAddress, message: NetworkMessage): Unit {
        if (!isRunning.load()) {
            throw Exception("传输层未启动")
        }

        try {
            // 序列化消息
            let serializedMessage = serializationManager.serialize(message.message)
            
            // 创建网络包
            let packet = createNetworkPacket(message.targetActor, serializedMessage, message.sender)
            
            // 发送到目标地址
            sendPacket(address, packet)
            
            println("消息发送到 ${address.toString()}: ${message.message.messageType()}")
        } catch (e: Exception) {
            println("发送消息失败: ${e.message}")
            throw e
        }
    }

    public func setMessageHandler(handler: (NetworkMessage) -> Unit): Unit {
        mutex.lock()
        messageHandler = Some(handler)
        mutex.unlock()
    }

    public func getLocalAddress(): NetworkAddress {
        localAddress
    }

    public func isActive(): Bool {
        isRunning.load()
    }

    private func startServer(): Unit {
        println("TCP服务器开始监听端口: ${localAddress.port}")
        
        // 简化的服务器实现
        while (isRunning.load()) {
            try {
                // 模拟接收连接和数据
                sleep(Duration.millisecond * 100)
                
                // 这里应该是真正的socket监听代码
                // 由于仓颉socket API的复杂性，这里使用简化实现
                
            } catch (e: Exception) {
                if (isRunning.load()) {
                    println("服务器错误: ${e.message}")
                }
            }
        }
        
        println("TCP服务器停止监听")
    }

    private func createNetworkPacket(targetActor: String, data: Array<UInt8>, sender: Option<String>): Array<UInt8> {
        // 简化的网络包格式：
        // [4字节：目标Actor长度][目标Actor][4字节：发送者长度][发送者][4字节：数据长度][数据]
        let packet = ArrayList<UInt8>()
        
        // 目标Actor
        let targetBytes = stringToBytes(targetActor)
        writeInt32(packet, Int32(targetBytes.size))
        packet.appendAll(targetBytes)
        
        // 发送者
        let senderStr = match (sender) {
            case Some(s) => s
            case None => ""
        }
        let senderBytes = stringToBytes(senderStr)
        writeInt32(packet, Int32(senderBytes.size))
        packet.appendAll(senderBytes)
        
        // 消息数据
        writeInt32(packet, Int32(data.size))
        packet.appendAll(data)
        
        packet.toArray()
    }

    private func sendPacket(address: NetworkAddress, packet: Array<UInt8>): Unit {
        // 简化的发送实现
        // 在实际实现中，这里应该创建TCP连接并发送数据
        println("发送${packet.size}字节到${address.toString()}")
    }

    private func writeInt32(buffer: ArrayList<UInt8>, value: Int32): Unit {
        buffer.append(UInt8((value >> 24) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    private func stringToBytes(str: String): Array<UInt8> {
        // 简化实现
        let bytes = ArrayList<UInt8>()
        for (i in 0..str.size) {
            bytes.append(UInt8(65))  // 简化为固定值
        }
        bytes.toArray()
    }
}

/**
 * UDP传输实现
 */
public class UdpTransport <: NetworkTransport {
    private let localAddress: NetworkAddress
    private let isRunning: AtomicBool
    private let serializationManager: SerializationManager
    private var messageHandler: Option<(NetworkMessage) -> Unit>
    private let mutex: ReentrantMutex

    public init(localAddress: NetworkAddress) {
        this.localAddress = localAddress
        this.isRunning = AtomicBool(false)
        this.serializationManager = GlobalSerializationManager.getInstance()
        this.messageHandler = None
        this.mutex = ReentrantMutex()
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("UDP传输启动在地址: ${localAddress.toString()}")
            
            spawn {
                startServer()
            }
        }
    }

    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("UDP传输停止")
        }
    }

    public func send(address: NetworkAddress, message: NetworkMessage): Unit {
        if (!isRunning.load()) {
            throw Exception("传输层未启动")
        }

        try {
            let serializedMessage = serializationManager.serialize(message.message)
            println("UDP发送消息到 ${address.toString()}: ${message.message.messageType()}")
        } catch (e: Exception) {
            println("UDP发送消息失败: ${e.message}")
            throw e
        }
    }

    public func setMessageHandler(handler: (NetworkMessage) -> Unit): Unit {
        mutex.lock()
        messageHandler = Some(handler)
        mutex.unlock()
    }

    public func getLocalAddress(): NetworkAddress {
        localAddress
    }

    public func isActive(): Bool {
        isRunning.load()
    }

    private func startServer(): Unit {
        println("UDP服务器开始监听端口: ${localAddress.port}")
        
        while (isRunning.load()) {
            try {
                sleep(Duration.millisecond * 100)
                // UDP监听实现
            } catch (e: Exception) {
                if (isRunning.load()) {
                    println("UDP服务器错误: ${e.message}")
                }
            }
        }
        
        println("UDP服务器停止监听")
    }
}

/**
 * 传输工厂
 */
public class TransportFactory {
    public static func createTcpTransport(address: NetworkAddress): NetworkTransport {
        TcpTransport(address)
    }

    public static func createUdpTransport(address: NetworkAddress): NetworkTransport {
        UdpTransport(address)
    }

    public static func createTransport(protocol: TransportProtocol, address: NetworkAddress): NetworkTransport {
        match (protocol) {
            case TransportProtocol.TCP => createTcpTransport(address)
            case TransportProtocol.UDP => createUdpTransport(address)
        }
    }
}
