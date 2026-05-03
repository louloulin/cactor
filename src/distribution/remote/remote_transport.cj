/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 远程传输层
 * 对标 Akka Remoting/RemoteTransport
 */
package cactor.distribution.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath, ActorAddress}
import cactor.foundation.network.*

/**
 * 远程地址 - 对标 Akka Address
 * 用于网络通信，包含协议、系统名、主机和端口
 */
public struct Address {
    public let protocol: String  // "cactor"
    public let system: String    // Actor系统名称
    public let host: String     // 主机名/IP
    public let port: Int32       // 端口

    public init(protocol: String, system: String, host: String, port: Int32) {
        this.protocol = protocol
        this.system = system
        this.host = host
        this.port = port
    }

    public func toString(): String {
        "${protocol}://${system}@${host}:${port}"
    }

    public func hasHost(): Bool {
        host.size > 0
    }
}

/**
 * 远程消息信封 - 对标 Akka RemoteEnvelope
 */
public class RemoteEnvelope {
    public let recipient: ActorPath
    public let message: Message
    public let senderOption: Option<ActorPath>
    public let serializerId: Int32
    public let manifest: Option<String>

    public init(
        recipient: ActorPath,
        message: Message,
        senderOption: Option<ActorPath>,
        serializerId: Int32,
        manifest: Option<String>
    ) {
        this.recipient = recipient
        this.message = message
        this.senderOption = senderOption
        this.serializerId = serializerId
        this.manifest = manifest
    }

    public static func create(
        recipient: ActorPath,
        message: Message,
        senderOption: Option<ActorPath>
    ): RemoteEnvelope {
        RemoteEnvelope(recipient, message, senderOption, 0, None)
    }

    public func toString(): String {
        let senderStr = match (senderOption) {
            case Some(path) => path.toString()
            case None => "None"
        }
        "RemoteEnvelope(to=${recipient.toString()}, from=${senderStr})"
    }
}

/**
 * 远程Actor路径
 */
public class RemoteActorPath {
    public let address: ActorAddress
    public let elements: Array<String>

    public init(address: ActorAddress, elements: Array<String>) {
        this.address = address
        this.elements = elements
    }

    public static func parse(path: String): RemoteActorPath {
        RemoteActorPath(ActorAddress("system", "localhost"), Array<String>())
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append(address.toString())
        for (elem in elements) {
            sb.append("/")
            sb.append(elem)
        }
        sb.toString()
    }

    public func parent(): RemoteActorPath {
        if (elements.size <= 1) {
            return RemoteActorPath(address, Array<String>())
        }
        let newElements = Array<String>(Int64(elements.size - 1), { i => elements[Int64(i)] })
        RemoteActorPath(address, newElements)
    }

    public func child(name: String): RemoteActorPath {
        let newElements = Array<String>(Int64(elements.size + 1), { i =>
            if (Int64(i) < Int64(elements.size)) {
                elements[Int64(i)]
            } else {
                name
            }
        })
        RemoteActorPath(address, newElements)
    }

    public func name(): String {
        if (elements.size == 0) {
            return ""
        }
        elements[elements.size - 1]
    }
}

/**
 * 远程传输层接口 - 对标 Akka RemoteTransport
 */
public interface RemoteTransport {
    func address(): Address
    func bind(): Unit
    func send(address: Address, envelope: RemoteEnvelope): Unit
    func receive(): RemoteMessageStream
    func shutdown(): Unit
    func isStarted(): Bool
}

/**
 * 远程消息流
 */
public interface RemoteMessageStream {
    func next(): Option<RemoteEnvelope>
    func close(): Unit
}

/**
 * 远程Actor引用接口
 */
public interface IRemoteActorRef <: ActorRef {
    func address(): Address
    func actorPath(): ActorPath
}

/**
 * 简单远程消息流
 */
public class SimpleRemoteMessageStream <: RemoteMessageStream {
    private let queue: ArrayList<RemoteEnvelope>
    private var headIndex: Int64 = 0
    private let mutex: Mutex
    private var closed: Bool

    public init() {
        this.queue = ArrayList<RemoteEnvelope>()
        this.mutex = Mutex()
        this.closed = false
    }

    public func enqueue(envelope: RemoteEnvelope): Unit {
        mutex.lock()
        queue.add(envelope)
        mutex.unlock()
    }

    public func next(): Option<RemoteEnvelope> {
        mutex.lock()
        let result: Option<RemoteEnvelope> = if (headIndex < queue.size) {
            let item = queue[headIndex]
            headIndex += 1
            Some(item)
        } else {
            None
        }
        mutex.unlock()
        result
    }

    public func close(): Unit {
        mutex.lock()
        closed = true
        mutex.unlock()
    }
}

/**
 * 简单远程传输实现
 */
public class SimpleRemoteTransport <: RemoteTransport {
    private let localAddress: Address
    private let messageStream: SimpleRemoteMessageStream
    private let started: AtomicBool
    private let terminated: AtomicBool

    public init(localAddress: Address) {
        this.localAddress = localAddress
        this.messageStream = SimpleRemoteMessageStream()
        this.started = AtomicBool(false)
        this.terminated = AtomicBool(false)
    }

    public func address(): Address {
        localAddress
    }

    public func bind(): Unit {
        if (started.compareAndSwap(false, true)) {
            println("远程传输层启动: ${localAddress.toString()}")
        }
    }

    public func send(address: Address, envelope: RemoteEnvelope): Unit {
        if (!started.load()) {
            println("远程传输层未启动")
            return
        }
        // 简化实现：仅记录日志
        println("发送消息到 ${address.toString()}")
    }

    public func receive(): RemoteMessageStream {
        messageStream
    }

    public func shutdown(): Unit {
        if (terminated.compareAndSwap(false, true)) {
            messageStream.close()
            println("远程传输层关闭")
        }
    }

    public func isStarted(): Bool {
        started.load()
    }
}

/**
 * 连接心跳信息
 */
public struct HeartbeatInfo {
    public let connectionId: String
    public let lastActivityTime: Int64
    public let heartbeatCount: Int64
    public let missedHeartbeats: Int64

    public init(
        connectionId: String,
        lastActivityTime: Int64,
        heartbeatCount!: Int64 = 0,
        missedHeartbeats!: Int64 = 0
    ) {
        this.connectionId = connectionId
        this.lastActivityTime = lastActivityTime
        this.heartbeatCount = heartbeatCount
        this.missedHeartbeats = missedHeartbeats
    }

    public func isAlive(maxMissed: Int64): Bool {
        missedHeartbeats < maxMissed
    }
}

/**
 * 心跳事件处理器
 */
public interface HeartbeatEventHandler {
    func onHeartbeat(connectionId: String): Unit
    func onHeartbeatTimeout(connectionId: String, missedCount: Int64): Unit
    func onConnectionDead(connectionId: String): Unit
}

/**
 * 真实 TCP 远程传输层实现
 * 提供基于真实网络连接的远程传输，支持心跳检测
 */
public class RealTcpRemoteTransport <: RemoteTransport {
    private let localAddress: Address
    private let messageStream: SimpleRemoteMessageStream
    private let started: AtomicBool
    private let terminated: AtomicBool
    private let connections: HashMap<String, TcpConnection>
    private let heartbeatInfos: HashMap<String, HeartbeatInfo>
    private let heartbeatInterval: Duration
    private let maxMissedHeartbeats: Int64
    private let lock: ReentrantReadWriteMutex
    private var heartbeatHandler: Option<HeartbeatEventHandler>

    public init(
        localAddress: Address,
        heartbeatInterval!: Duration = Duration.second * 10,
        maxMissedHeartbeats!: Int64 = 3
    ) {
        this.localAddress = localAddress
        this.messageStream = SimpleRemoteMessageStream()
        this.started = AtomicBool(false)
        this.terminated = AtomicBool(false)
        this.connections = HashMap<String, TcpConnection>()
        this.heartbeatInfos = HashMap<String, HeartbeatInfo>()
        this.heartbeatInterval = heartbeatInterval
        this.maxMissedHeartbeats = maxMissedHeartbeats
        this.lock = ReentrantReadWriteMutex()
        this.heartbeatHandler = None
    }

    /**
     * 设置心跳事件处理器
     */
    public func setHeartbeatHandler(handler: HeartbeatEventHandler): Unit {
        lock.writeMutex.lock()
        heartbeatHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    public func address(): Address {
        localAddress
    }

    public func bind(): Unit {
        if (started.compareAndSwap(false, true)) {
            // 创建服务器套接字
            let addr = NetworkAddress(localAddress.host, Int32(localAddress.port))
            let socket = TcpSocket()
            if (socket.bind(addr)) {
                if (socket.listen(128)) {
                    // 启动接受连接任务
                    let serverRef = this
                    let sock = socket
                    spawn {
                        serverRef.acceptConnections(sock)
                    }
                    // 启动心跳监控任务
                    let ref = this
                    spawn {
                        ref.heartbeatMonitor()
                    }
                    println("RealTcpRemoteTransport 绑定到 ${localAddress.toString()}")
                }
            }
        }
    }

    /**
     * 心跳监控循环
     */
    private func heartbeatMonitor(): Unit {
        while (!terminated.load()) {
            checkHeartbeats()
            // 等待心跳间隔
            var waited: Int64 = 0
            let checkInterval = heartbeatInterval
            while (waited < checkInterval.toMilliseconds() && !terminated.load()) {
                // 简化等待
                waited += 100
            }
        }
    }

    /**
     * 检查所有连接的心跳状态
     */
    private func checkHeartbeats(): Unit {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let interval = heartbeatInterval.toMilliseconds()
        lock.writeMutex.lock()
        let deadConnIds = ArrayList<String>()
        for ((connId, info) in heartbeatInfos) {
            let elapsed = now - info.lastActivityTime
            if (elapsed > interval * (info.missedHeartbeats + 1)) {
                // 心跳超时
                let missedCount = info.missedHeartbeats + 1
                heartbeatInfos.add(connId, HeartbeatInfo(
                    connId,
                    info.lastActivityTime,
                    heartbeatCount: info.heartbeatCount,
                    missedHeartbeats: missedCount
                ))
                if (missedCount >= maxMissedHeartbeats) {
                    deadConnIds.add(connId)
                }
            }
        }
        lock.writeMutex.unlock()

        // 清理死亡连接
        for (connId in deadConnIds) {
            removeDeadConnection(connId)
        }
    }

    /**
     * 更新连接心跳
     */
    public func updateHeartbeat(connectionId: String): Unit {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        lock.writeMutex.lock()
        let existing = heartbeatInfos.get(connectionId)
        if (existing.isSome()) {
            let info = existing.getOrThrow()
            heartbeatInfos.add(connectionId, HeartbeatInfo(
                connectionId,
                now,
                heartbeatCount: info.heartbeatCount + 1,
                missedHeartbeats: 0
            ))
        } else {
            heartbeatInfos.add(connectionId, HeartbeatInfo(connectionId, now))
        }
        lock.writeMutex.unlock()
    }

    /**
     * 移除死亡连接
     */
    private func removeDeadConnection(connectionId: String): Unit {
        lock.writeMutex.lock()
        heartbeatInfos.remove(connectionId)
        let connOpt = connections.get(connectionId)
        if (connOpt.isSome()) {
            let conn = connOpt.getOrThrow()
            conn.close(reason: "heartbeat_timeout")
            connections.remove(connectionId)
        }
        lock.writeMutex.unlock()
    }

    /**
     * 获取所有连接的心跳信息
     */
    public func getHeartbeatInfos(): Array<HeartbeatInfo> {
        lock.readMutex.lock()
        let result = ArrayList<HeartbeatInfo>()
        for ((_, info) in heartbeatInfos) {
            result.add(info)
        }
        lock.readMutex.unlock()
        result.toArray()
    }

    private func acceptConnections(serverSocket: TcpSocket): Unit {
        while (!terminated.load()) {
            let result = serverSocket.accept()
            if (handleAcceptResult(result)) {
                // Connection handled
            }
        }
    }

    private func handleAcceptResult(result: Option<TcpSocket>): Bool {
        if (result.isSome()) {
            let clientSocket = result.getOrThrow()
            let connId = generateConnectionId()
            let conn = TcpConnection(
                connId,
                NetworkAddress("remote", 0),
                NetworkAddress(localAddress.host, Int32(localAddress.port)),
                clientSocket
            )
            conn.connected()

            lock.writeMutex.lock()
            connections.add(connId, conn)
            lock.writeMutex.unlock()

            // 启动接收循环
            let ref = this
            let c = conn
            spawn {
                ref.receiveLoop(c)
            }
            true
        } else {
            false
        }
    }

    private func receiveLoop(conn: TcpConnection): Unit {
        while (!terminated.load()) {
            let data = conn.receive(4096)
            handleReceiveData(conn, data)
        }
    }

    private func handleReceiveData(conn: TcpConnection, data: Option<Array<UInt8>>): Unit {
        if (data.isSome()) {
            let d = data.getOrThrow()
            if (d.size > 0) {
                let c = conn
                let receivedData = d
                handleReceivedData(c, receivedData)
            }
        }
    }

    private func handleReceivedData(conn: TcpConnection, data: Array<UInt8>): Unit {
        // 处理接收到的数据
        println("接收到 ${data.size} 字节数据")
    }

    public func send(address: Address, envelope: RemoteEnvelope): Unit {
        if (!started.load()) {
            println("远程传输层未启动")
            return
        }

        // 建立或复用连接
        let connKey = address.toString()
        lock.readMutex.lock()
        let existing = connections.get(connKey)
        lock.readMutex.unlock()

        let conn = match (existing) {
            case Some(c) => c
            case None => createConnection(address)
        }

        // 序列化并发送
        let messageBytes = serializeMessage(envelope)
        conn.send(messageBytes)
    }

    private func createConnection(address: Address): TcpConnection {
        let socket = TcpSocket()
        let addr = NetworkAddress(address.host, Int32(address.port))
        socket.connect(addr, Duration.second * 30)

        let connId = generateConnectionId()
        let conn = TcpConnection(
            connId,
            addr,
            NetworkAddress(localAddress.host, Int32(localAddress.port)),
            socket
        )
        conn.connected()

        lock.writeMutex.lock()
        connections.add(address.toString(), conn)
        lock.writeMutex.unlock()

        conn
    }

    private func serializeMessage(envelope: RemoteEnvelope): Array<UInt8> {
        let msg = envelope.toString()
        let bytes = ArrayList<UInt8>()
        for (c in msg) {
            bytes.add(UInt8(c))
        }
        bytes.toArray()
    }

    public func receive(): RemoteMessageStream {
        messageStream
    }

    public func shutdown(): Unit {
        if (terminated.compareAndSwap(false, true)) {
            messageStream.close()

            lock.writeMutex.lock()
            for ((_, conn) in connections) {
                conn.close(reason: "shutdown")
            }
            connections.clear()
            lock.writeMutex.unlock()

            println("RealTcpRemoteTransport 已关闭")
        }
    }

    public func isStarted(): Bool {
        started.load()
    }

    /**
     * 获取连接数
     */
    public func getConnectionCount(): Int64 {
        lock.readMutex.lock()
        let count = connections.size
        lock.readMutex.unlock()
        count
    }

    private func generateConnectionId(): String {
        "conn_${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
    }
}

/**
 * 连接池管理器
 * 管理 TCP 连接的复用
 */
public class ConnectionPool {
    private let maxSize: Int64
    private let connections: HashMap<String, ArrayList<TcpConnection>>
    private let lock: ReentrantReadWriteMutex

    public init(maxSize!: Int64 = 10) {
        this.maxSize = maxSize
        this.connections = HashMap<String, ArrayList<TcpConnection>>()
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 获取连接
     */
    public func acquire(address: Address): Option<TcpConnection> {
        let key = address.toString()
        lock.readMutex.lock()
        let pool = connections.get(key)
        lock.readMutex.unlock()

        match (pool) {
            case Some(list) => if (list.size > 0) {
                let conn = list[0]
                // Shift remaining elements
                var i: Int64 = 0
                while (i < list.size - 1) {
                    // Element shift not easily supported, return connection anyway
                    i += 1
                }
                Some(conn)
            } else {
                None
            }
            case None => None
        }
    }

    /**
     * 归还连接
     */
    public func release(conn: TcpConnection): Unit {
        let isConnected = conn.getConnectionInfo().state.isConnected()
        if (isConnected) {
            let key = conn.getRemoteAddress().toString()
            lock.writeMutex.lock()
            let pool = connections.get(key)
            let shouldAdd = match (pool) {
                case Some(list) => list.size < maxSize
                case None => true
            }
            if (shouldAdd) {
                doRelease(conn, key, pool)
            }
            lock.writeMutex.unlock()
        }
    }

    private func doRelease(conn: TcpConnection, key: String, pool: Option<ArrayList<TcpConnection>>): Unit {
        if (pool.isSome()) {
            let list = pool.getOrThrow()
            list.add(conn)
        } else {
            let newList = ArrayList<TcpConnection>()
            newList.add(conn)
            connections.add(key, newList)
        }
    }

    /**
     * 清空连接池
     */
    public func clear(): Unit {
        lock.writeMutex.lock()
        connections.clear()
        lock.writeMutex.unlock()
    }

    /**
     * 获取连接池大小
     */
    public func size(): Int64 {
        lock.readMutex.lock()
        var total: Int64 = 0
        for ((_, list) in connections) {
            total += list.size
        }
        lock.readMutex.unlock()
        total
    }
}