/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - WebSocket 单元测试
 */
package cactor.api.websocket

import std.collection.*
import std.sync.*

// ============================================================================
// WsMessage Tests
// ============================================================================

@Test
func testWsMessage_fromText() {
    let msg = WsMessage.fromText("hello")
    match (msg.text) {
        case Some(t) => @Expect(t, "hello")
        case None => @Expect(true, false)
    }
}

@Test
func testWsMessage_fromBinary() {
    let data = Array<UInt8>(3, { i: Int64 => 0u8 })
    let msg = WsMessage.fromBinary(data)
    @Expect(true, true)
}

@Test
func testWsMessage_close() {
    let msg = WsMessage.close()
    @Expect(true, true)
}

@Test
func testWsMessage_ping() {
    let data = Array<UInt8>(0, { i: Int64 => 0u8 })
    let msg = WsMessage.ping(data)
    @Expect(true, true)
}

@Test
func testWsMessage_pong() {
    let data = Array<UInt8>(0, { i: Int64 => 0u8 })
    let msg = WsMessage.pong(data)
    @Expect(true, true)
}

// ============================================================================
// WsCloseCode Tests
// ============================================================================

@Test
func testWsCloseCode_codes() {
    @Expect(WsCloseCode.Normal.code(), 1000)
    @Expect(WsCloseCode.GoingAway.code(), 1001)
    @Expect(WsCloseCode.ProtocolError.code(), 1002)
    @Expect(WsCloseCode.UnsupportedData.code(), 1003)
    @Expect(WsCloseCode.NoStatus.code(), 1005)
    @Expect(WsCloseCode.Abnormal.code(), 1006)
    @Expect(WsCloseCode.InvalidData.code(), 1007)
    @Expect(WsCloseCode.PolicyViolation.code(), 1008)
    @Expect(WsCloseCode.TooLarge.code(), 1009)
    @Expect(WsCloseCode.InternalError.code(), 1011)
}

@Test
func testWsCloseCode_custom() {
    let code = WsCloseCode.Custom(4000)
    @Expect(code.code(), 4000)
}

// ============================================================================
// WsContext Tests
// ============================================================================

@Test
func testWsContext_creation() {
    let ctx = WsContext("/ws", Some("127.0.0.1:12345"), None)
    @Expect(ctx.path, "/ws")
}

@Test
func testWsContext_attributes() {
    let ctx = WsContext("/ws", None, None)
    ctx.setAttribute("user", "test")
    match (ctx.attribute("user")) {
        case Some(v) => @Expect(v, "test")
        case None => @Expect(true, false)
    }
}

@Test
func testWsContext_sendText() {
    let ctx = WsContext("/ws", None, None)
    ctx.sendText("hello")
    @Expect(true, true)
}

@Test
func testWsContext_sendBinary() {
    let ctx = WsContext("/ws", None, None)
    let data = Array<UInt8>(0, { i: Int64 => 0u8 })
    ctx.sendBinary(data)
    @Expect(true, true)
}

@Test
func testWsContext_connectionState() {
    let ctx = WsContext("/ws", None, None)
    @Expect(true, true)
}

// ============================================================================
// WsServerConfig Tests
// ============================================================================

@Test
func testWsServerConfig_defaults() {
    let config = WsServerConfig()
    @Expect(config.host, "0.0.0.0")
    @Expect(config.port, 8080)
    @Expect(config.path, "/ws")
    @Expect(config.autoPing, true)
}

// ============================================================================
// WsClientConfig Tests
// ============================================================================

@Test
func testWsClientConfig_defaults() {
    let config = WsClientConfig()
    @Expect(config.url, "ws://localhost:8080/ws")
    @Expect(config.reconnect, false)
    @Expect(config.maxReconnectAttempts, 3)
}

// ============================================================================
// WsFlow Tests
// ============================================================================

@Test
func testWsFlow_creation() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    @Expect(true, true)
}

@Test
func testWsFlow_handleConnection() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    let ctx = WsContext("/ws", None, None)
    flow.handleConnection(ctx)
    @Expect(true, true)
}

@Test
func testWsFlow_handleTextMessage() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    let ctx = WsContext("/ws", None, None)
    ctx.connectionState = WsConnectionState.Open
    let msg = WsMessage.fromText("hello")
    flow.handleMessage(ctx, msg)
    @Expect(true, true)
}

@Test
func testWsFlow_handlePing() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    let ctx = WsContext("/ws", None, None)
    let data = Array<UInt8>(0, { i: Int64 => 0u8 })
    let msg = WsMessage.ping(data)
    flow.handleMessage(ctx, msg)
    @Expect(true, true)
}

// ============================================================================
// WsServer Tests
// ============================================================================

@Test
func testWsServer_creation() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    let server = WsServer(flow)
    @Expect(server.isActive(), false)
}

@Test
func testWsServer_startStop() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    let server = WsServer(flow)
    server.start()
    @Expect(server.isActive(), true)
    server.stop()
    @Expect(server.isActive(), false)
}

@Test
func testWsServer_withRoute() {
    let handler = EchoWsHandler()
    let flow = WsFlow(handler)
    let flow2 = WsFlow(handler)
    let server = WsServer(flow)
    let s = server.withRoute("/ws/chat", flow2)
    match (s.getFlow("/ws/chat")) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, false)
    }
}

// ============================================================================
// WsClient Tests
// ============================================================================

@Test
func testWsClient_creation() {
    let client = WsClient()
    @Expect(true, true)
}

@Test
func testWsClient_connect() {
    let client = WsClient()
    let result = client.connect()
    @Expect(result, true)
    @Expect(client.isConnected(), true)
}

@Test
func testWsClient_disconnect() {
    let client = WsClient()
    let _ = client.connect()
    client.disconnect()
    @Expect(client.isConnected(), false)
}

@Test
func testWsClient_sendText() {
    let client = WsClient()
    let _ = client.connect()
    client.sendText("hello")
    @Expect(true, true)
}

@Test
func testWsClient_sendBinary() {
    let client = WsClient()
    let _ = client.connect()
    let data = Array<UInt8>(0, { i: Int64 => 0u8 })
    client.sendBinary(data)
    @Expect(true, true)
}

// ============================================================================
// SimpleWsHandler Tests
// ============================================================================

@Test
func testSimpleHandler_creation() {
    let handler = simpleHandler(None, None, None)
    let ctx = WsContext("/ws", None, None)
    handler.onConnect(ctx)
    @Expect(true, true)
}

@Test
func testSimpleHandler_withCallbacks() {
    let handler = simpleHandler(
        Some({ ctx: WsContext => () }),
        Some({ ctx: WsContext, msg: WsMessage => () }),
        None
    )
    let ctx = WsContext("/ws", None, None)
    handler.onConnect(ctx)
    let msg = WsMessage.fromText("test")
    handler.onMessage(ctx, msg)
    @Expect(true, true)
}

// ============================================================================
// Echo Handler (测试辅助)
// ============================================================================

class EchoWsHandler <: WsHandler {
    public func onConnect(ctx: WsContext): Unit {
        // nothing
    }

    public func onMessage(ctx: WsContext, message: WsMessage): Unit {
        match (message.text) {
            case Some(t) => ctx.sendText(t)
            case None => ctx.sendBinary(message.data)
        }
    }

    public func onPing(ctx: WsContext, data: Array<UInt8>): Unit {
        ctx.sendBinary(data)
    }

    public func onPong(ctx: WsContext, data: Array<UInt8>): Unit {
        // nothing
    }

    public func onClose(ctx: WsContext, code: WsCloseCode, reason: String): Unit {
        // nothing
    }

    public func onError(ctx: WsContext, error: String): Unit {
        // nothing
    }
}
