/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Remote Transport 测试
 */
package cactor.distribution.remote

import std.time.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import cactor.core.actor.{ActorPath, ActorAddress}
import cactor.core.message.Message

/**
 * 测试消息
 */
class SimpleMessage <: Message {
    private let content: String
    public init(content: String) {
        this.content = content
    }
    public func messageType(): String {
        "SimpleMessage"
    }
    public func getContent(): String {
        content
    }
}

@Test
func testAddress(): Unit {
    let addr = Address("cactor", "system", "localhost", 2552)
    @Assert(addr.toString() == "cactor://system@localhost:2552")
    @Assert(addr.hasHost())
}

@Test
func testAddressNoHost(): Unit {
    let addr = Address("cactor", "system", "", 0)
    @Assert(!addr.hasHost())
}

@Test
func testRemoteEnvelope(): Unit {
    let path = ActorPath("user", Array<String>())
    let msg = SimpleMessage("hello")
    let envelope = RemoteEnvelope.create(path, msg, Some(path))
    @Assert(envelope.senderOption.isSome())
}

@Test
func testRemoteEnvelopeNoSender(): Unit {
    let path = ActorPath("user", Array<String>())
    let msg = SimpleMessage("hello")
    let envelope = RemoteEnvelope.create(path, msg, None)
    @Assert(envelope.senderOption.isNone())
}

@Test
func testTcpSocketConnect(): Unit {
    let socket = TcpSocket()
    let addr = NetworkAddress("localhost", 2552)
    let connected = socket.connect(addr, Duration.second * 5)
    @Assert(connected)
    socket.close()
}

@Test
func testTcpSocketBind(): Unit {
    let socket = TcpSocket()
    let addr = NetworkAddress("localhost", 2555)
    let bound = socket.bind(addr)
    @Assert(bound)
    socket.close()
}

@Test
func testTcpSocketWrite(): Unit {
    let socket = TcpSocket()
    let addr = NetworkAddress("localhost", 2552)
    socket.connect(addr, Duration.second * 5)
    let data = Array<UInt8>(5, { i => UInt8(i) })
    let written = socket.write(data)
    @Assert(written >= 0)
    socket.close()
}

@Test
func testTcpServerStart(): Unit {
    let config = TcpTransportConfig("localhost", 2556)
    let server = TcpServer(config)
    let started = server.start()
    @Assert(started)
    server.stop()
}

@Test
func testTcpClientConnect(): Unit {
    let config = TcpTransportConfig("localhost", 2557)
    let client = TcpClient(config)
    let connected = client.connect()
    @Assert(connected)
    client.disconnect()
}

@Test
func testTcpClientSend(): Unit {
    let config = TcpTransportConfig("localhost", 2558)
    let client = TcpClient(config)
    client.connect()
    let data = Array<UInt8>(5, { i => UInt8(i) })
    let sent = client.send(data)
    @Assert(sent)
    client.disconnect()
}

@Test
func testTcpConnectionState(): Unit {
    let state = TcpConnectionState.CONNECTED
    @Assert(state.isConnected())
    @Assert(!TcpConnectionState.CLOSED.isConnected())
}

@Test
func testConnectionPool(): Unit {
    let pool = ConnectionPool()
    @Assert(pool.size() == 0)
}

@Test
func testConnectionPoolAcquire(): Unit {
    let pool = ConnectionPool()
    let addr = Address("cactor", "system", "localhost", 2552)
    let conn = pool.acquire(addr)
    @Assert(conn.isNone())
}

@Test
func testSimpleRemoteTransport(): Unit {
    let addr = Address("cactor", "system", "localhost", 2559)
    let transport = SimpleRemoteTransport(addr)
    @Assert(!transport.isStarted())
    transport.bind()
    @Assert(transport.isStarted())
    transport.shutdown()
}

@Test
func testRemoteActorPath(): Unit {
    let addr = ActorAddress("system", "localhost")
    let path = RemoteActorPath(addr, Array<String>())
    @Assert(path.name() == "")
    let childPath = path.child("actor1")
    @Assert(childPath.name() == "actor1")
}

@Test
func testRemoteActorPathParent(): Unit {
    let addr = ActorAddress("system", "localhost")
    let path = RemoteActorPath(addr, Array<String>())
    let childPath = path.child("actor1").child("actor2")
    @Assert(childPath.name() == "actor2")
    let parentPath = childPath.parent()
    @Assert(parentPath.name() == "actor1")
}

@Test
func testTcpTransportConfig(): Unit {
    let config = TcpTransportConfig("localhost", 2552)
    @Assert(config.host == "localhost")
    @Assert(config.port == 2552)
    @Assert(config.backlog == 128)
    @Assert(config.keepAlive)
}

@Test
func testTcpConnectionInfo(): Unit {
    let info = TcpConnectionInfo(
        "conn-1",
        NetworkAddress("localhost", 2552),
        NetworkAddress("localhost", 2553),
        TcpConnectionState.CONNECTED,
        DateTime.now().toUnixTimeStamp().toMilliseconds()
    )
    @Assert(info.connectionId == "conn-1")
    @Assert(info.state.isConnected())
}

@Test
func testTcpConnection(): Unit {
    let socket = TcpSocket()
    let conn = TcpConnection(
        "conn-1",
        NetworkAddress("localhost", 2552),
        NetworkAddress("localhost", 2553),
        socket
    )
    let info = conn.getConnectionInfo()
    @Assert(info.connectionId == "conn-1")
}

@Test
func testTcpConnectionSend(): Unit {
    let socket = TcpSocket()
    socket.connect(NetworkAddress("localhost", 2552), Duration.second * 5)
    let conn = TcpConnection(
        "conn-1",
        NetworkAddress("localhost", 2552),
        NetworkAddress("localhost", 2553),
        socket
    )
    conn.connected()
    let data = Array<UInt8>(5, { i => UInt8(i) })
    let sent = conn.send(data)
    @Assert(sent)
}

@Test
func testTcpConnectionReceive(): Unit {
    let socket = TcpSocket()
    socket.connect(NetworkAddress("localhost", 2552), Duration.second * 5)
    let conn = TcpConnection(
        "conn-1",
        NetworkAddress("localhost", 2552),
        NetworkAddress("localhost", 2553),
        socket
    )
    conn.connected()
    let data = conn.receive(4096)
    // 预期无数据可读
    @Assert(data.isNone())
}

@Test
func testRealTcpRemoteTransport(): Unit {
    let addr = Address("cactor", "system", "localhost", 2560)
    let transport = RealTcpRemoteTransport(addr)
    @Assert(!transport.isStarted())
    transport.bind()
    @Assert(transport.isStarted())
    @Assert(transport.getConnectionCount() == 0)
    transport.shutdown()
}
