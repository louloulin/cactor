/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 简化的远程通信系统
 */
package cactor.distribution.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
import cactor.foundation.network.{NetworkTransport, NetworkAddress, TransportFactory, TransportProtocol}
import cactor.core.message.{NetworkMessage, NetworkMessageSerializer}
import cactor.foundation.serialization.{SerializationManager, GlobalSerializationManager}

/**
 * 简化的远程消息发送器
 */
public class SimpleRemoteSender {
    private let transport: NetworkTransport
    private let serializationManager: SerializationManager
    private let networkMessageSerializer: NetworkMessageSerializer
    private let isStarted: AtomicBool

    public init(localAddress: NetworkAddress, protocol: TransportProtocol) {
        this.transport = TransportFactory.createTransport(protocol, localAddress)
        this.serializationManager = GlobalSerializationManager.getInstance()
        this.networkMessageSerializer = NetworkMessageSerializer()
        this.isStarted = AtomicBool(false)
    }

    /**
     * 启动发送器
     */
    public func start(): Unit {
        if (isStarted.compareAndSwap(false, true)) {
            transport.start()
            println("远程发送器启动在地址: ${transport.getLocalAddress().toString()}")
        }
    }

    /**
     * 停止发送器
     */
    public func stop(): Unit {
        if (isStarted.compareAndSwap(true, false)) {
            transport.stop()
            println("远程发送器停止")
        }
    }

    /**
     * 发送消息到远程地址
     */
    public func sendMessage(targetAddress: NetworkAddress, targetActor: String, message: Message): Unit {
        if (!isStarted.load()) {
            throw Exception("发送器未启动")
        }

        try {
            let networkMessage = NetworkMessage(targetActor, message, None)
            // 序列化NetworkMessage为字节数组
            let serializedData = networkMessageSerializer.serialize(networkMessage)
            transport.send(targetAddress, serializedData)
            println("消息发送成功到 ${targetAddress.toString()}")
        } catch (e: Exception) {
            println("消息发送失败: ${e.message}")
            throw e
        }
    }

    /**
     * 检查是否已启动
     */
    public func isActive(): Bool {
        isStarted.load()
    }

    /**
     * 获取本地地址
     */
    public func getLocalAddress(): NetworkAddress {
        transport.getLocalAddress()
    }
}

/**
 * 简化的远程消息接收器
 */
public class SimpleRemoteReceiver {
    private let transport: NetworkTransport
    private let serializationManager: SerializationManager
    private let networkMessageSerializer: NetworkMessageSerializer
    private let isStarted: AtomicBool
    private let messageHandlers: HashMap<String, (Message) -> Unit>
    private let mutex: ReentrantMutex

    public init(localAddress: NetworkAddress, protocol: TransportProtocol) {
        this.transport = TransportFactory.createTransport(protocol, localAddress)
        this.serializationManager = GlobalSerializationManager.getInstance()
        this.networkMessageSerializer = NetworkMessageSerializer()
        this.isStarted = AtomicBool(false)
        this.messageHandlers = HashMap<String, (Message) -> Unit>()
        this.mutex = ReentrantMutex()

        // 设置数据处理器
        transport.setDataHandler(handleReceivedData)
    }

    /**
     * 启动接收器
     */
    public func start(): Unit {
        if (isStarted.compareAndSwap(false, true)) {
            transport.start()
            println("远程接收器启动在地址: ${transport.getLocalAddress().toString()}")
        }
    }

    /**
     * 停止接收器
     */
    public func stop(): Unit {
        if (isStarted.compareAndSwap(true, false)) {
            transport.stop()
            println("远程接收器停止")
        }
    }

    /**
     * 注册消息处理器
     */
    public func registerHandler(actorName: String, handler: (Message) -> Unit): Unit {
        mutex.lock()
        messageHandlers[actorName] = handler
        mutex.unlock()
        println("注册消息处理器: ${actorName}")
    }

    /**
     * 处理接收到的字节数据
     */
    private func handleReceivedData(data: Array<UInt8>): Unit {
        try {
            let networkMessage = networkMessageSerializer.deserialize(data)
            handleNetworkMessage(networkMessage)
        } catch (e: Exception) {
            println("反序列化网络消息失败: ${e.message}")
        }
    }

    /**
     * 处理网络消息
     */
    private func handleNetworkMessage(networkMessage: NetworkMessage): Unit {
        try {
            let targetActor = networkMessage.targetActor
            mutex.lock()
            let handler = messageHandlers.get(targetActor)
            mutex.unlock()

            match (handler) {
                case Some(h) =>
                    h(networkMessage.message)
                    println("消息处理成功: ${targetActor}")
                case None =>
                    println("未找到处理器: ${targetActor}")
            }
        } catch (e: Exception) {
            println("处理网络消息失败: ${e.message}")
        }
    }

    /**
     * 检查是否已启动
     */
    public func isActive(): Bool {
        isStarted.load()
    }

    /**
     * 获取本地地址
     */
    public func getLocalAddress(): NetworkAddress {
        transport.getLocalAddress()
    }
}

/**
 * 简化的远程通信管理器
 */
public class SimpleRemoteManager {
    private let sender: SimpleRemoteSender
    private let receiver: SimpleRemoteReceiver
    private let localAddress: NetworkAddress

    public init(localAddress: NetworkAddress, protocol: TransportProtocol) {
        this.localAddress = localAddress
        this.sender = SimpleRemoteSender(localAddress, protocol)
        this.receiver = SimpleRemoteReceiver(localAddress, protocol)
    }

    /**
     * 启动远程通信
     */
    public func start(): Unit {
        sender.start()
        receiver.start()
        println("远程通信管理器启动")
    }

    /**
     * 停止远程通信
     */
    public func stop(): Unit {
        sender.stop()
        receiver.stop()
        println("远程通信管理器停止")
    }

    /**
     * 发送消息
     */
    public func sendMessage(targetAddress: NetworkAddress, targetActor: String, message: Message): Unit {
        sender.sendMessage(targetAddress, targetActor, message)
    }

    /**
     * 注册消息处理器
     */
    public func registerHandler(actorName: String, handler: (Message) -> Unit): Unit {
        receiver.registerHandler(actorName, handler)
    }

    /**
     * 检查是否已启动
     */
    public func isActive(): Bool {
        sender.isActive() && receiver.isActive()
    }

    /**
     * 获取本地地址
     */
    public func getLocalAddress(): NetworkAddress {
        localAddress
    }
}

/**
 * 远程通信工厂
 */
public class RemoteFactory {
    /**
     * 创建简化的远程发送器
     */
    public static func createSender(address: NetworkAddress, protocol: TransportProtocol): SimpleRemoteSender {
        SimpleRemoteSender(address, protocol)
    }

    /**
     * 创建简化的远程接收器
     */
    public static func createReceiver(address: NetworkAddress, protocol: TransportProtocol): SimpleRemoteReceiver {
        SimpleRemoteReceiver(address, protocol)
    }

    /**
     * 创建简化的远程通信管理器
     */
    public static func createManager(address: NetworkAddress, protocol: TransportProtocol): SimpleRemoteManager {
        SimpleRemoteManager(address, protocol)
    }

    /**
     * 创建默认的TCP远程通信管理器
     */
    public static func createDefaultManager(port: Int32): SimpleRemoteManager {
        let address = NetworkAddress("localhost", port)
        SimpleRemoteManager(address, TransportProtocol.TCP)
    }
}
