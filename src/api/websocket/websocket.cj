/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - WebSocket 实现
 * 对标 Akka Streams WebSocket，支持全双工通信
 */
package cactor.api.websocket

import std.collection.*
import std.sync.*
import std.time.*

// ============================================================================
// WebSocket 模型
// ============================================================================

/**
 * WebSocket 消息类型
 */
public enum WsMessageType {
    | Text
    | Binary
    | Close
    | Ping
    | Pong
}

/**
 * WebSocket 消息
 */
public class WsMessage {
    public let messageType: WsMessageType
    public let data: Array<UInt8>
    public let text: Option<String>

    public init(messageType: WsMessageType, data: Array<UInt8>, text: Option<String>) {
        this.messageType = messageType
        this.data = data
        this.text = text
    }

    public static func fromText(text: String): WsMessage {
        // 简化实现，存储空数组
        let data = Array<UInt8>(0, { i: Int64 => 0u8 })
        WsMessage(WsMessageType.Text, data, Some(text))
    }

    public static func fromBinary(data: Array<UInt8>): WsMessage {
        WsMessage(WsMessageType.Binary, data, None)
    }

    public static func close(): WsMessage {
        WsMessage(WsMessageType.Close, Array<UInt8>(0, { i: Int64 => 0u8 }), None)
    }

    public static func ping(data: Array<UInt8>): WsMessage {
        WsMessage(WsMessageType.Ping, data, None)
    }

    public static func pong(data: Array<UInt8>): WsMessage {
        WsMessage(WsMessageType.Pong, data, None)
    }
}

/**
 * WebSocket 关闭码
 */
public enum WsCloseCode {
    | Normal
    | GoingAway
    | ProtocolError
    | UnsupportedData
    | NoStatus
    | Abnormal
    | InvalidData
    | PolicyViolation
    | TooLarge
    | MissingExtension
    | InternalError
    | ServiceRestart
    | TryAgainLater
    | BadGateway
    | Custom(Int64)

    public func code(): Int64 {
        match (this) {
            case Normal => 1000
            case GoingAway => 1001
            case ProtocolError => 1002
            case UnsupportedData => 1003
            case NoStatus => 1005
            case Abnormal => 1006
            case InvalidData => 1007
            case PolicyViolation => 1008
            case TooLarge => 1009
            case MissingExtension => 1010
            case InternalError => 1011
            case ServiceRestart => 1012
            case TryAgainLater => 1013
            case BadGateway => 1014
            case Custom(code) => code
        }
    }
}

/**
 * WebSocket 连接状态
 */
public enum WsConnectionState {
    | Connecting
    | Open
    | Closing
    | Closed
}

/**
 * WebSocket 配置
 */
public class WsServerConfig {
    public var host: String
    public var port: Int32
    public var path: String
    public var subprotocols: ArrayList<String>
    public var maxFrameSize: Int64
    public var pingInterval: Duration
    public var autoPing: Bool

    public init() {
        this.host = "0.0.0.0"
        this.port = 8080
        this.path = "/ws"
        this.subprotocols = ArrayList<String>()
        this.maxFrameSize = 65536
        this.pingInterval = Duration.second * 30
        this.autoPing = true
    }
}

/**
 * WebSocket 客户端配置
 */
public class WsClientConfig {
    public var url: String
    public var subprotocol: Option<String>
    public var headers: HashMap<String, String>
    public var reconnect: Bool
    public var reconnectInterval: Duration
    public var maxReconnectAttempts: Int64

    public init() {
        this.url = "ws://localhost:8080/ws"
        this.subprotocol = None
        this.headers = HashMap<String, String>()
        this.reconnect = false
        this.reconnectInterval = Duration.second * 5
        this.maxReconnectAttempts = 3
    }
}

// ============================================================================
// WebSocket Handler
// ============================================================================

/**
 * WebSocket 处理器接口
 */
public interface WsHandler {
    func onConnect(ctx: WsContext): Unit
    func onMessage(ctx: WsContext, message: WsMessage): Unit
    func onPing(ctx: WsContext, data: Array<UInt8>): Unit
    func onPong(ctx: WsContext, data: Array<UInt8>): Unit
    func onClose(ctx: WsContext, code: WsCloseCode, reason: String): Unit
    func onError(ctx: WsContext, error: String): Unit
}

/**
 * WebSocket 上下文
 */
public class WsContext {
    public let path: String
    public let remoteAddress: Option<String>
    public let subprotocol: Option<String>
    public var connectionState: WsConnectionState
    public let attributes: HashMap<String, String>

    private var sendQueue: ArrayList<WsMessage>

    public init(path: String, remoteAddress: Option<String>, subprotocol: Option<String>) {
        this.path = path
        this.remoteAddress = remoteAddress
        this.subprotocol = subprotocol
        this.connectionState = WsConnectionState.Connecting
        this.attributes = HashMap<String, String>()
        this.sendQueue = ArrayList<WsMessage>()
    }

    /**
     * 发送文本消息
     */
    public func sendText(text: String): Unit {
        sendMessage(WsMessage.fromText(text))
    }

    /**
     * 发送二进制消息
     */
    public func sendBinary(data: Array<UInt8>): Unit {
        sendMessage(WsMessage.fromBinary(data))
    }

    /**
     * 发送消息
     */
    public func sendMessage(message: WsMessage): Unit {
        sendQueue.add(message)
    }

    /**
     * 关闭连接
     */
    public func close(code: WsCloseCode, reason: String): Unit {
        connectionState = WsConnectionState.Closing
    }

    /**
     * 获取属性
     */
    public func attribute(key: String): Option<String> {
        attributes.get(key)
    }

    /**
     * 设置属性
     */
    public func setAttribute(key: String, value: String): Unit {
        let _ = attributes.add(key, value)
    }
}

// ============================================================================
// WebSocket Flow
// ============================================================================

/**
 * WebSocket 流处理器
 */
public class WsFlow {
    private let handler: WsHandler
    private let config: WsServerConfig

    public init(handler: WsHandler, config: WsServerConfig) {
        this.handler = handler
        this.config = config
    }

    public init(handler: WsHandler) {
        this.handler = handler
        this.config = WsServerConfig()
    }

    /**
     * 处理连接
     */
    public func handleConnection(ctx: WsContext): Unit {
        ctx.connectionState = WsConnectionState.Open
        handler.onConnect(ctx)
    }

    /**
     * 处理消息
     */
    public func handleMessage(ctx: WsContext, message: WsMessage): Unit {
        match (message.messageType) {
            case WsMessageType.Text =>
                handler.onMessage(ctx, message)
            case WsMessageType.Binary =>
                handler.onMessage(ctx, message)
            case WsMessageType.Close =>
                handler.onClose(ctx, WsCloseCode.Normal, "")
            case WsMessageType.Ping =>
                handler.onPing(ctx, message.data)
            case WsMessageType.Pong =>
                handler.onPong(ctx, message.data)
        }
    }
}

// ============================================================================
// WebSocket Server
// ============================================================================

/**
 * WebSocket 服务器
 */
public class WsServer {
    private let config: WsServerConfig
    private let flow: WsFlow
    private let isRunning: AtomicBool
    private let routes: HashMap<String, WsFlow>

    public init(config: WsServerConfig, flow: WsFlow) {
        this.config = config
        this.flow = flow
        this.isRunning = AtomicBool(false)
        this.routes = HashMap<String, WsFlow>()
    }

    public init(flow: WsFlow) {
        this.config = WsServerConfig()
        this.flow = flow
        this.isRunning = AtomicBool(false)
        this.routes = HashMap<String, WsFlow>()
    }

    /**
     * 添加 WebSocket 路由
     */
    public func withRoute(path: String, flow: WsFlow): WsServer {
        let _ = routes.add(path, flow)
        this
    }

    /**
     * 启动服务器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("WebSocket 服务器启动在 ${config.host}:${config.port}")
        }
    }

    /**
     * 停止服务器
     */
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("WebSocket 服务器停止")
        }
    }

    /**
     * 是否正在运行
     */
    public func isActive(): Bool {
        isRunning.load()
    }

    /**
     * 获取流处理器
     */
    public func getFlow(path: String): Option<WsFlow> {
        routes.get(path)
    }
}

// ============================================================================
// WebSocket Client
// ============================================================================

/**
 * WebSocket 客户端
 */
public class WsClient {
    private let config: WsClientConfig
    private var connectionState: WsConnectionState
    private let handler: Option<WsHandler>
    private var ctx: Option<WsContext>

    public init(config: WsClientConfig, handler: WsHandler) {
        this.config = config
        this.connectionState = WsConnectionState.Closed
        this.handler = Some(handler)
        this.ctx = None
    }

    public init(config: WsClientConfig) {
        this.config = config
        this.connectionState = WsConnectionState.Closed
        this.handler = None
        this.ctx = None
    }

    public init() {
        this.config = WsClientConfig()
        this.connectionState = WsConnectionState.Closed
        this.handler = None
        this.ctx = None
    }

    /**
     * 连接到服务器
     */
    public func connect(): Bool {
        connectionState = WsConnectionState.Connecting
        // 模拟连接成功
        let mockCtx = WsContext("/ws", Some("127.0.0.1:12345"), config.subprotocol)
        mockCtx.connectionState = WsConnectionState.Open
        ctx = Some(mockCtx)
        connectionState = WsConnectionState.Open

        match (handler) {
            case Some(h) => h.onConnect(mockCtx)
            case None => ()
        }
        true
    }

    /**
     * 断开连接
     */
    public func disconnect(): Unit {
        match (ctx) {
            case Some(c) =>
                c.close(WsCloseCode.Normal, "")
                match (handler) {
                    case Some(h) => h.onClose(c, WsCloseCode.Normal, "")
                    case None => ()
                }
            case None => ()
        }
        connectionState = WsConnectionState.Closed
        ctx = None
    }

    /**
     * 发送文本消息
     */
    public func sendText(text: String): Unit {
        match (ctx) {
            case Some(c) => c.sendText(text)
            case None => ()
        }
    }

    /**
     * 发送二进制消息
     */
    public func sendBinary(data: Array<UInt8>): Unit {
        match (ctx) {
            case Some(c) => c.sendBinary(data)
            case None => ()
        }
    }

    /**
     * 获取连接状态
     */
    public func state(): WsConnectionState {
        connectionState
    }

    /**
     * 是否已连接
     */
    public func isConnected(): Bool {
        match (connectionState) {
            case WsConnectionState.Open => true
            case _ => false
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/**
 * 创建简单 WebSocket 处理器
 */
public func simpleHandler(
    connectCb: Option<(WsContext) -> Unit>,
    messageCb: Option<(WsContext, WsMessage) -> Unit>,
    closeCb: Option<(WsContext, WsCloseCode, String) -> Unit>
): WsHandler {
    SimpleWsHandler(connectCb, messageCb, closeCb)
}

class SimpleWsHandler <: WsHandler {
    private let connectCallback: Option<(WsContext) -> Unit>
    private let messageCallback: Option<(WsContext, WsMessage) -> Unit>
    private let closeCallback: Option<(WsContext, WsCloseCode, String) -> Unit>

    init(
        connectCb: Option<(WsContext) -> Unit>,
        messageCb: Option<(WsContext, WsMessage) -> Unit>,
        closeCb: Option<(WsContext, WsCloseCode, String) -> Unit>
    ) {
        this.connectCallback = connectCb
        this.messageCallback = messageCb
        this.closeCallback = closeCb
    }

    public func onConnect(ctx: WsContext): Unit {
        match (connectCallback) {
            case Some(f) => f(ctx)
            case None => ()
        }
    }

    public func onMessage(ctx: WsContext, message: WsMessage): Unit {
        match (messageCallback) {
            case Some(f) => f(ctx, message)
            case None => ()
        }
    }

    public func onPing(ctx: WsContext, data: Array<UInt8>): Unit {
        ctx.sendBinary(data)
    }

    public func onPong(ctx: WsContext, data: Array<UInt8>): Unit {
        // Pong received, no action needed
    }

    public func onClose(ctx: WsContext, code: WsCloseCode, reason: String): Unit {
        match (closeCallback) {
            case Some(f) => f(ctx, code, reason)
            case None => ()
        }
    }

    public func onError(ctx: WsContext, error: String): Unit {
        println("WebSocket error: ${error}")
    }
}
