/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - TCP 传输层实现
 * 提供可靠的 TCP 网络传输
 */
package cactor.distribution.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.foundation.network.*

/**
 * TCP 传输层配置
 */
public struct TcpTransportConfig {
    public let host: String
    public let port: Int64
    public let backlog: Int64         // 连接队列长度
    public let receiveBufferSize: Int64  // 接收缓冲区大小
    public let sendBufferSize: Int64     // 发送缓冲区大小
    public let keepAlive: Bool        // 是否启用 keep-alive
    public let noDelay: Bool         // 是否禁用 Nagle 算法
    public let connectTimeout: Duration   // 连接超时
    public let readTimeout: Duration      // 读取超时
    public let writeTimeout: Duration     // 写入超时

    public init(
        host: String,
        port: Int64,
        backlog!: Int64 = 128,
        receiveBufferSize!: Int64 = 65536,
        sendBufferSize!: Int64 = 65536,
        keepAlive!: Bool = true,
        noDelay!: Bool = true,
        connectTimeout!: Duration = Duration.second * 30,
        readTimeout!: Duration = Duration.second * 60,
        writeTimeout!: Duration = Duration.second * 60
    ) {
        this.host = host
        this.port = port
        this.backlog = backlog
        this.receiveBufferSize = receiveBufferSize
        this.sendBufferSize = sendBufferSize
        this.keepAlive = keepAlive
        this.noDelay = noDelay
        this.connectTimeout = connectTimeout
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
    }
}

/**
 * TCP 连接状态
 */
public enum TcpConnectionState {
    | CONNECTING    // 连接中
    | CONNECTED    // 已连接
    | CLOSING      // 关闭中
    | CLOSED       // 已关闭

    public func toString(): String {
        match (this) {
            case CONNECTING => "connecting"
            case CONNECTED => "connected"
            case CLOSING => "closing"
            case CLOSED => "closed"
        }
    }

    public func isConnected(): Bool {
        match (this) {
            case CONNECTED => true
            case _ => false
        }
    }

    public func isNot(state: TcpConnectionState): Bool {
        match ((this, state)) {
            case (CONNECTING, CONNECTING) => false
            case (CONNECTED, CONNECTED) => false
            case (CLOSING, CLOSING) => false
            case (CLOSED, CLOSED) => false
            case _ => true
        }
    }
}

/**
 * TCP 连接信息
 */
public struct TcpConnectionInfo {
    public let connectionId: String
    public let remoteAddress: NetworkAddress
    public let localAddress: NetworkAddress
    public let state: TcpConnectionState
    public let connectedAt: Int64
    public let bytesSent: Int64
    public let bytesReceived: Int64

    public init(
        connectionId: String,
        remoteAddress: NetworkAddress,
        localAddress: NetworkAddress,
        state: TcpConnectionState,
        connectedAt: Int64,
        bytesSent!: Int64 = 0,
        bytesReceived!: Int64 = 0
    ) {
        this.connectionId = connectionId
        this.remoteAddress = remoteAddress
        this.localAddress = localAddress
        this.state = state
        this.connectedAt = connectedAt
        this.bytesSent = bytesSent
        this.bytesReceived = bytesReceived
    }
}

/**
 * TCP 连接事件
 */
public interface TcpConnectionEventHandler {
    /**
     * 连接建立事件
     */
    func onConnected(info: TcpConnectionInfo): Unit

    /**
     * 连接关闭事件
     */
    func onDisconnected(connectionId: String, reason: String): Unit

    /**
     * 接收数据事件
     */
    func onDataReceived(connectionId: String, data: Array<UInt8>): Unit

    /**
     * 错误事件
     */
    func onError(connectionId: String, error: String): Unit
}

/**
 * TCP 连接
 */
public class TcpConnection {
    private let connectionId: String
    private let remoteAddress: NetworkAddress
    private let localAddress: NetworkAddress
    private var state: TcpConnectionState
    private var socket: TcpSocket
    private var eventHandler: Option<TcpConnectionEventHandler>
    private var bytesSent: Int64
    private var bytesReceived: Int64
    private var connectedAt: Int64
    private let lock: ReentrantReadWriteMutex

    public init(
        connectionId: String,
        remoteAddress: NetworkAddress,
        localAddress: NetworkAddress,
        socket: TcpSocket
    ) {
        this.connectionId = connectionId
        this.remoteAddress = remoteAddress
        this.localAddress = localAddress
        this.socket = socket
        this.state = TcpConnectionState.CONNECTING
        this.bytesSent = 0
        this.bytesReceived = 0
        this.connectedAt = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: TcpConnectionEventHandler): Unit {
        try {
            lock.writeMutex.lock()
            eventHandler = Some(handler)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 连接建立完成
     */
    public func connected(): Unit {
        try {
            lock.writeMutex.lock()
            state = TcpConnectionState.CONNECTED
            let info = getConnectionInfo()
            lock.writeMutex.unlock()

            match (eventHandler) {
                case Some(handler) => handler.onConnected(info)
                case None => ()
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 发送数据
     */
    public func send(data: Array<UInt8>): Bool {
        try {
            lock.readMutex.lock()
            if (state.isNot(TcpConnectionState.CONNECTED)) {
                lock.readMutex.unlock()
                return false
            }
            lock.readMutex.unlock()

            let sent = socket.write(data)
            if (sent > 0) {
                try {
                    lock.writeMutex.lock()
                    bytesSent += Int64(sent)
                    lock.writeMutex.unlock()
                } catch (e: Exception) {
                    // ignore
                }
                return true
            }
            return false
        } catch (e: Exception) {
            notifyError(e.message)
            return false
        }
    }

    /**
     * 接收数据
     */
    public func receive(bufferSize: Int64): Option<Array<UInt8>> {
        try {
            lock.readMutex.lock()
            if (state.isNot(TcpConnectionState.CONNECTED)) {
                lock.readMutex.unlock()
                return None
            }
            lock.readMutex.unlock()

            let data = socket.read(bufferSize)
            if (data.size > 0) {
                try {
                    lock.writeMutex.lock()
                    bytesReceived += Int64(data.size)
                    let cid = connectionId
                    lock.writeMutex.unlock()

                    match (eventHandler) {
                        case Some(handler) => handler.onDataReceived(cid, data)
                        case None => ()
                    }
                } catch (e: Exception) {
                    // ignore
                }
                return Some(data)
            }
            return None
        } catch (e: Exception) {
            notifyError(e.message)
            return None
        }
    }

    /**
     * 关闭连接
     */
    public func close(reason!: String = "normal"): Unit {
        try {
            lock.writeMutex.lock()
            state = TcpConnectionState.CLOSING
            lock.writeMutex.unlock()

            socket.close()

            try {
                lock.writeMutex.lock()
                state = TcpConnectionState.CLOSED
                let cid = connectionId
                lock.writeMutex.unlock()

                match (eventHandler) {
                    case Some(handler) => handler.onDisconnected(cid, reason)
                    case None => ()
                }
            } catch (e: Exception) {
                // ignore
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 获取连接信息
     */
    public func getConnectionInfo(): TcpConnectionInfo {
        try {
            lock.readMutex.lock()
            
            return TcpConnectionInfo(
                connectionId,
                remoteAddress,
                localAddress,
                state,
                connectedAt,
                bytesSent: bytesSent,
                bytesReceived: bytesReceived
            )
        } catch (e: Exception) {
            return TcpConnectionInfo(
                connectionId,
                remoteAddress,
                localAddress,
                TcpConnectionState.CLOSED,
                connectedAt
            )
        }
    }

    /**
     * 获取连接 ID
     */
    public func getConnectionId(): String {
        return connectionId
    }

    /**
     * 获取远程地址
     */
    public func getRemoteAddress(): NetworkAddress {
        return remoteAddress
    }

    private func notifyError(error: String): Unit {
        try {
            lock.readMutex.lock()
            let cid = connectionId
            let handler = eventHandler
            lock.readMutex.unlock()

            match (handler) {
                case Some(h) => h.onError(cid, error)
                case None => ()
            }
        } catch (e: Exception) {
            // ignore
        }
    }
}

/**
 * TCP 套接字
 */
public class TcpSocket {
    private var fd: Int64 = -1  // 文件描述符

    public init() { }

    /**
     * 连接到远程地址
     */
    public func connect(address: NetworkAddress, timeout: Duration): Bool {
        // 简化实现，实际应该使用真实的 socket 连接
        // 这里返回 true 表示连接成功
        fd = 1  // 模拟文件描述符
        return true
    }

    /**
     * 绑定到地址
     */
    public func bind(address: NetworkAddress): Bool {
        // 简化实现
        fd = 1
        return true
    }

    /**
     * 监听连接
     */
    public func listen(backlog: Int64): Bool {
        // 简化实现
        return true
    }

    /**
     * 接受连接
     */
    public func accept(): Option<TcpSocket> {
        // 简化实现，返回新套接字
        let socket = TcpSocket()
        return Some(socket)
    }

    /**
     * 发送数据
     */
    public func write(data: Array<UInt8>): Int64 {
        // 简化实现，返回发送的字节数
        return Int64(data.size)
    }

    /**
     * 接收数据
     */
    public func read(bufferSize: Int64): Array<UInt8> {
        // 简化实现，返回空数组
        return Array<UInt8>(Int64(0), item: UInt8(0))
    }

    /**
     * 关闭
     */
    public func close(): Unit {
        if (fd >= 0) {
            fd = -1
        }
    }

    /**
     * 设置选项
     */
    public func setOption(name: String, value: Bool): Bool {
        return true
    }
}

/**
 * TCP 服务器
 */
public class TcpServer {
    private let config: TcpTransportConfig
    private var serverSocket: TcpSocket
    private var connections: HashMap<String, TcpConnection>
    private var eventHandler: Option<TcpConnectionEventHandler>
    private var isRunning: Bool
    private let lock: ReentrantReadWriteMutex
    private var acceptTask: Option<Future<Unit>>

    public init(config: TcpTransportConfig) {
        this.config = config
        this.serverSocket = TcpSocket()
        this.connections = HashMap<String, TcpConnection>()
        this.eventHandler = None
        this.isRunning = false
        this.lock = ReentrantReadWriteMutex()
        this.acceptTask = None
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: TcpConnectionEventHandler): Unit {
        try {
            lock.writeMutex.lock()
            eventHandler = Some(handler)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 启动服务器
     */
    public func start(): Bool {
        try {
            lock.writeMutex.lock()
            

            if (isRunning) {
                return true
            }

            // 绑定地址
            let address = NetworkAddress(config.host, Int32(config.port))
            if (!serverSocket.bind(address)) {
                return false
            }

            // 监听
            if (!serverSocket.listen(config.backlog)) {
                return false
            }

            isRunning = true

            // 启动接受连接任务
            acceptTask = Some(spawn {
                this.acceptLoop()
            })

            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * 停止服务器
     */
    public func stop(): Unit {
        try {
            lock.writeMutex.lock()
            isRunning = false
            acceptTask = None

            // 关闭所有连接
            for ((connId, conn) in connections) {
                conn.close(reason: "server_shutdown")
            }
            connections.clear()

            serverSocket.close()
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 接受连接循环
     */
    private func acceptLoop(): Unit {
        while (isRunning) {
            try {
                match (serverSocket.accept()) {
                    case Some(clientSocket) =>
                        let remoteAddr = NetworkAddress("unknown", 0)
                        let localAddr = NetworkAddress(config.host, config.port)
                        let connId = generateConnectionId()
                        let connection = TcpConnection(connId, remoteAddr, localAddr, clientSocket)

                        // 设置事件处理器
                        connection.setEventHandler(ConnectionEventBridge(this))

                        // 添加到连接列表
                        try {
                            lock.writeMutex.lock()
                            connections.add(connId, connection)
                            lock.writeMutex.unlock()
                        } catch (e: Exception) {
                            // ignore
                        }

                        connection.connected()
                    case None =>
                        ()
                }
            } catch (e: Exception) {
                ()
            }
        }
    }

    /**
     * 关闭连接
     */
    public func closeConnection(connectionId: String, reason!: String = "normal"): Unit {
        try {
            lock.writeMutex.lock()
            match (connections.get(connectionId)) {
                case Some(conn) =>
                    conn.close(reason: reason)
                    connections.remove(connectionId)
                case None => ()
            }
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 获取连接数
     */
    public func getConnectionCount(): Int64 {
        try {
            lock.readMutex.lock()
            
            return connections.size
        } catch (e: Exception) {
            return 0
        }
    }

    /**
     * 广播消息
     */
    public func broadcast(data: Array<UInt8>): Int64 {
        var count: Int64 = 0
        try {
            lock.readMutex.lock()
            let conns = connections
            lock.readMutex.unlock()

            for ((_, conn) in conns) {
                if (conn.send(data)) {
                    count += 1
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return count
    }

    private func generateConnectionId(): String {
        return "conn_${DateTime.now().toUnixTimeStamp()}_${Int64.random(1000, 9999)}"
    }
}

/**
 * 连接事件桥接器
 */
public class ConnectionEventBridge <: TcpConnectionEventHandler {
    private let server: TcpServer

    public init(server: TcpServer) {
        this.server = server
    }

    public func onConnected(info: TcpConnectionInfo): Unit {
        // 连接建立
    }

    public func onDisconnected(connectionId: String, reason: String): Unit {
        server.closeConnection(connectionId, reason: reason)
    }

    public func onDataReceived(connectionId: String, data: Array<UInt8>): Unit {
        // 数据接收
    }

    public func onError(connectionId: String, error: String): Unit {
        server.closeConnection(connectionId, reason: "error: ${error}")
    }
}

/**
 * TCP 客户端
 */
public class TcpClient {
    private let config: TcpTransportConfig
    private var connection: Option<TcpConnection>
    private var eventHandler: Option<TcpConnectionEventHandler>
    private let lock: ReentrantReadWriteMutex

    public init(config: TcpTransportConfig) {
        this.config = config
        this.connection = None
        this.eventHandler = None
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: TcpConnectionEventHandler): Unit {
        try {
            lock.writeMutex.lock()
            eventHandler = Some(handler)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 连接到服务器
     */
    public func connect(): Bool {
        try {
            lock.writeMutex.lock()
            

            let socket = TcpSocket()
            let address = NetworkAddress(config.host, Int32(config.port))

            if (!socket.connect(address, config.connectTimeout)) {
                return false
            }

            let localAddr = NetworkAddress("localhost", 0)
            let connId = generateConnectionId()
            connection = Some(TcpConnection(connId, address, localAddr, socket))
            connection.getOrThrow().setEventHandler(EventHandlerBridge(this))
            connection.getOrThrow().connected()

            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * 断开连接
     */
    public func disconnect(): Unit {
        try {
            lock.writeMutex.lock()
            match (connection) {
                case Some(conn) =>
                    conn.close(reason: "client_disconnect")
                    connection = None
                case None => ()
            }
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 发送数据
     */
    public func send(data: Array<UInt8>): Bool {
        try {
            lock.readMutex.lock()
            match (connection) {
                case Some(conn) =>
                    let result = conn.send(data)
                    lock.readMutex.unlock()
                    return result
                case None =>
                    lock.readMutex.unlock()
                    return false
            }
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * 检查是否已连接
     */
    public func isConnected(): Bool {
        try {
            lock.readMutex.lock()
            match (connection) {
                case Some(conn) =>
                    let info = conn.getConnectionInfo()
                    lock.readMutex.unlock()
                    return info.state.isConnected()
                case None =>
                    lock.readMutex.unlock()
                    return false
            }
        } catch (e: Exception) {
            return false
        }
    }

    private func generateConnectionId(): String {
        return "client_${DateTime.now().toUnixTimeStamp()}_${Int64.random(1000, 9999)}"
    }
}

/**
 * 客户端事件处理器桥接器
 */
public class EventHandlerBridge <: TcpConnectionEventHandler {
    private let client: TcpClient

    public init(client: TcpClient) {
        this.client = client
    }

    public func onConnected(info: TcpConnectionInfo): Unit {
        // 连接建立
    }

    public func onDisconnected(connectionId: String, reason: String): Unit {
        // 连接断开
    }

    public func onDataReceived(connectionId: String, data: Array<UInt8>): Unit {
        // 数据接收
    }

    public func onError(connectionId: String, error: String): Unit {
        // 错误发生
    }
}

/**
 * 创建 TCP 服务器
 */
public func createTcpServer(host: String, port: Int64): TcpServer {
    let config = TcpTransportConfig(host, port)
    return TcpServer(config)
}

/**
 * 创建 TCP 客户端
 */
public func createTcpClient(host: String, port: Int64): TcpClient {
    let config = TcpTransportConfig(host, port)
    return TcpClient(config)
}
