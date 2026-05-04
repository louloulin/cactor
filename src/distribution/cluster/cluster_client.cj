/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Client 外部客户端通信机制
 * 对标 Akka Cluster Client
 * 允许外部系统与集群中的 Actor 通信
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 集群接触点信息
 */
public class ClusterContactPoint {
    public let host: String
    public let port: Int32
    public var lastSeen: Int64
    public var failureCount: Int64

    public init(host: String, port: Int32) {
        this.host = host
        this.port = port
        this.lastSeen = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.failureCount = 0
    }

    /**
     * 更新最后可见时间
     */
    public func touch(): Unit {
        lastSeen = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /**
     * 记录失败
     */
    public func recordFailure(): Unit {
        failureCount += 1
    }

    /**
     * 重置失败计数
     */
    public func resetFailures(): Unit {
        failureCount = 0
    }

    /**
     * 检查是否可用
     */
    public func isAvailable(): Bool {
        failureCount < 3
    }

    /**
     * 获取地址字符串
     */
    public func address(): String {
        "${host}:${port}"
    }
}

/**
 * 客户端消息类型
 */
public enum ClientMessageType {
    Connect
    Disconnect
    Send
    Subscribe
    Unsubscribe
    Ack
    Nack
}

/**
 * 客户端信封
 */
public class ClientEnvelope {
    public let messageType: ClientMessageType
    public let destinationPath: String
    public let payload: String
    public let clientId: String
    public let timestamp: Int64
    public var retryCount: Int64

    public init(messageType: ClientMessageType, destinationPath: String, payload: String, clientId: String) {
        this.messageType = messageType
        this.destinationPath = destinationPath
        this.payload = payload
        this.clientId = clientId
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.retryCount = 0
    }
}

/**
 * 客户端连接状态
 */
public enum ClientConnectionState {
    Disconnected
    Connecting
    Connected
    Reconnecting
    Failed
}

/**
 * 集群客户端事件
 */
public enum ClusterClientEvent {
    Connected(nodeId: String)
    Disconnected(nodeId: String)
    MessageSent(destination: String, messageId: Int64)
    MessageReceived(from: String, payload: String)
    ConnectionFailed(reason: String)
}

/**
 * 集群客户端事件处理器
 */
public interface ClusterClientEventHandler {
    /**
     * 连接到节点
     */
    func onConnected(nodeId: String): Unit

    /**
     * 从节点断开
     */
    func onDisconnected(nodeId: String): Unit

    /**
     * 消息已发送
     */
    func onMessageSent(destination: String, messageId: Int64): Unit

    /**
     * 收到消息
     */
    func onMessageReceived(from: String, payload: String): Unit

    /**
     * 连接失败
     */
    func onConnectionFailed(reason: String): Unit
}

/**
 * 集群客户端配置
 */
public class ClusterClientConfig {
    public let reconnectInterval: Duration
    public let heartbeatInterval: Duration
    public let maxRetries: Int64
    public let bufferSize: Int64
    public let enableAutoReconnect: Bool

    public init(reconnectInterval: Duration, heartbeatInterval: Duration, maxRetries: Int64, bufferSize: Int64, enableAutoReconnect: Bool) {
        this.reconnectInterval = reconnectInterval
        this.heartbeatInterval = heartbeatInterval
        this.maxRetries = maxRetries
        this.bufferSize = bufferSize
        this.enableAutoReconnect = enableAutoReconnect
    }
}

/**
 * ClusterClient - 集群客户端
 * 对标 Akka Cluster Client
 * 允许外部系统与集群中的 Actor 通信
 */
public class ClusterClient {
    private let clientId: String
    private let config: ClusterClientConfig
    private let contactPoints: ArrayList<ClusterContactPoint>
    private var currentNode: Option<String>
    private var connectionState: ClientConnectionState
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<ClusterClientEventHandler>
    private let pendingMessages: HashMap<Int64, ClientEnvelope>
    private var messageIdCounter: Int64
    private var totalSent: Int64
    private var totalReceived: Int64
    private var totalFailed: Int64

    public init(clientId: String, config: ClusterClientConfig) {
        this.clientId = clientId
        this.config = config
        this.contactPoints = ArrayList<ClusterContactPoint>()
        this.currentNode = None
        this.connectionState = ClientConnectionState.Disconnected
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
        this.pendingMessages = HashMap<Int64, ClientEnvelope>()
        this.messageIdCounter = 0
        this.totalSent = 0
        this.totalReceived = 0
        this.totalFailed = 0
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: ClusterClientEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 添加接触点
     */
    public func addContactPoint(host: String, port: Int32): Unit {
        lock.writeMutex.lock()
        let contact = ClusterContactPoint(host, port)
        contactPoints.add(contact)
        lock.writeMutex.unlock()
    }

    /**
     * 添加多个接触点
     */
    public func addContactPoints(points: ArrayList<(String, Int32)>): Unit {
        for ((host, port) in points) {
            addContactPoint(host, port)
        }
    }

    /**
     * 连接到集群
     */
    public func connect(): Bool {
        lock.writeMutex.lock()
        connectionState = ClientConnectionState.Connecting
        var connected = false

        // 尝试连接所有接触点
        for (contact in contactPoints) {
            if (contact.isAvailable()) {
                // 模拟连接成功
                currentNode = Some(contact.address())
                contact.resetFailures()
                contact.touch()
                connected = true
                break
            }
        }

        if (connected) {
            connectionState = ClientConnectionState.Connected
        } else {
            connectionState = ClientConnectionState.Failed
            totalFailed += 1
        }
        lock.writeMutex.unlock()

        if (connected) {
            match (currentNode) {
                case Some(nodeId) =>
                    match (eventHandler) {
                        case Some(handler) => handler.onConnected(nodeId)
                        case None => ()
                    }
                case None => ()
            }
        } else {
            match (eventHandler) {
                case Some(handler) => handler.onConnectionFailed("No available contact points")
                case None => ()
            }
        }

        connected
    }

    /**
     * 断开连接
     */
    public func disconnect(): Unit {
        lock.writeMutex.lock()
        match (currentNode) {
            case Some(nodeId) =>
                connectionState = ClientConnectionState.Disconnected
                currentNode = None
            case None => ()
        }
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onDisconnected("")
            case None => ()
        }
    }

    /**
     * 发送消息到集群中的 Actor
     */
    public func send(destinationPath: String, payload: String): Int64 {
        lock.writeMutex.lock()
        messageIdCounter += 1
        let messageId = messageIdCounter
        let envelope = ClientEnvelope(ClientMessageType.Send, destinationPath, payload, clientId)
        pendingMessages.add(messageId, envelope)
        totalSent += 1
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onMessageSent(destinationPath, messageId)
            case None => ()
        }

        messageId
    }

    /**
     * 批量发送消息
     */
    public func sendBatch(destinations: ArrayList<String>, payloads: ArrayList<String>): ArrayList<Int64> {
        let ids = ArrayList<Int64>()
        for (i in 0..destinations.size) {
            ids.add(send(destinations[i], payloads[i]))
        }
        ids
    }

    /**
     * 确认消息已收到
     */
    public func acknowledge(messageId: Int64): Bool {
        lock.writeMutex.lock()
        let existed = pendingMessages.get(messageId).isSome()
        if (existed) {
            pendingMessages.remove(messageId)
        }
        lock.writeMutex.unlock()
        existed
    }

    /**
     * 重试未确认的消息
     */
    public func retryPending(): Int64 {
        lock.writeMutex.lock()
        var count: Int64 = 0
        for ((msgId, envelope) in pendingMessages) {
            envelope.retryCount += 1
            if (envelope.retryCount <= config.maxRetries) {
                count += 1
            }
        }
        lock.writeMutex.unlock()
        count
    }

    /**
     * 获取连接状态
     */
    public func getConnectionState(): ClientConnectionState {
        lock.readMutex.lock()
        let state = connectionState
        lock.readMutex.unlock()
        state
    }

    /**
     * 检查是否已连接
     */
    public func isConnected(): Bool {
        lock.readMutex.lock()
        let connected = connectionState == ClientConnectionState.Connected
        lock.readMutex.unlock()
        connected
    }

    /**
     * 获取当前节点
     */
    public func getCurrentNode(): Option<String> {
        lock.readMutex.lock()
        let node = currentNode
        lock.readMutex.unlock()
        node
    }

    /**
     * 获取接触点数量
     */
    public func contactPointCount(): Int64 {
        lock.readMutex.lock()
        let count = contactPoints.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取可用接触点
     */
    public func getAvailableContactPoints(): ArrayList<ClusterContactPoint> {
        lock.readMutex.lock()
        let result = ArrayList<ClusterContactPoint>()
        for (contact in contactPoints) {
            if (contact.isAvailable()) {
                result.add(contact)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取待确认消息数量
     */
    public func pendingCount(): Int64 {
        lock.readMutex.lock()
        let count = pendingMessages.size
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
     * 获取总接收数
     */
    public func totalReceived(): Int64 {
        lock.readMutex.lock()
        let count = totalReceived
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
     * 获取客户端 ID
     */
    public func getClientId(): String {
        clientId
    }

    /**
     * 获取配置
     */
    public func getConfig(): ClusterClientConfig {
        config
    }

    /**
     * 清除所有待确认消息
     */
    public func clearPending(): Int64 {
        lock.writeMutex.lock()
        let count = pendingMessages.size
        pendingMessages.clear()
        lock.writeMutex.unlock()
        count
    }

    /**
     * 重新连接
     */
    public func reconnect(): Bool {
        lock.writeMutex.lock()
        connectionState = ClientConnectionState.Reconnecting
        lock.writeMutex.unlock()
        disconnect()
        connect()
    }

    /**
     * 记录消息接收
     */
    public func recordReceive(payload: String, from: String): Unit {
        lock.writeMutex.lock()
        totalReceived += 1
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onMessageReceived(from, payload)
            case None => ()
        }
    }

    /**
     * 获取消息追踪信息
     */
    public func getPendingMessages(): ArrayList<(Int64, String, String, Int64)> {
        lock.readMutex.lock()
        let result = ArrayList<(Int64, String, String, Int64)>()
        for ((msgId, envelope) in pendingMessages) {
            result.add((msgId, envelope.destinationPath, envelope.payload, envelope.retryCount))
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 移除不可用的接触点
     */
    public func removeUnavailableContactPoints(): Int64 {
        lock.writeMutex.lock()
        var removed: Int64 = 0
        let toRemove = ArrayList<Int64>()
        for (i in 0..contactPoints.size) {
            if (!contactPoints[i].isAvailable()) {
                toRemove.add(i)
                removed += 1
            }
        }
        for (i in toRemove.size - 1..-1..-1) {
            contactPoints.remove(toRemove[i])
        }
        lock.writeMutex.unlock()
        removed
    }
}

/**
 * 创建集群客户端
 */
public func createClusterClient(clientId: String): ClusterClient {
    let config = ClusterClientConfig(
        Duration.second * 5,    // reconnectInterval
        Duration.second * 30,    // heartbeatInterval
        5,                       // maxRetries
        1000,                    // bufferSize
        true                     // enableAutoReconnect
    )
    ClusterClient(clientId, config)
}

/**
 * 创建带配置的集群客户端
 */
public func createClusterClientWithConfig(clientId: String, config: ClusterClientConfig): ClusterClient {
    ClusterClient(clientId, config)
}

/**
 * 创建默认客户端配置
 */
public func createDefaultClusterClientConfig(): ClusterClientConfig {
    ClusterClientConfig(
        Duration.second * 5,
        Duration.second * 30,
        5,
        1000,
        true
    )
}

/**
 * ClusterClientSettings - 客户端设置
 */
public class ClusterClientSettings {
    public let bufferSize: Int64
    public let flushInterval: Duration
    public let enableBatching: Bool

    public init(bufferSize: Int64, flushInterval: Duration, enableBatching: Bool) {
        this.bufferSize = bufferSize
        this.flushInterval = flushInterval
        this.enableBatching = enableBatching
    }
}

/**
 * 创建默认客户端设置
 */
public func createDefaultClusterClientSettings(): ClusterClientSettings {
    ClusterClientSettings(
        1000,
        Duration.millisecond * 100,
        true
    )
}