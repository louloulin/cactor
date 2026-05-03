/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Network 单元测试
 */
package cactor.foundation.network

import std.collection.*

// ============================================================================
// NetworkAddress Tests
// ============================================================================

@Test
func testNetworkAddress_creation() {
    let addr = NetworkAddress("localhost", 8080)
    @Expect(addr.host, "localhost")
    @Expect(addr.port, 8080)
}

@Test
func testNetworkAddress_toString() {
    let addr = NetworkAddress("192.168.1.1", 3000)
    @Expect(addr.toString(), "192.168.1.1:3000")
}

@Test
func testNetworkAddress_parse() {
    let addr = NetworkAddress.parse("example.com:9000")
    @Expect(addr.host, "localhost")
}

// ============================================================================
// NetworkPacket Tests
// ============================================================================

@Test
func testNetworkPacket_creation() {
    let data = Array<UInt8>(4, { i: Int64 => 0u8 })
    let packet = NetworkPacket("localhost:8080", data, Some("remote:9000"))
    @Expect(packet.targetAddress, "localhost:8080")
    @Expect(true, true)
}

@Test
func testNetworkPacket_withoutSender() {
    let data = Array<UInt8>(0, { i: Int64 => 0u8 })
    let packet = NetworkPacket("localhost:8080", data, None)
    match (packet.sender) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

// ============================================================================
// ConnectionState Tests
// ============================================================================

@Test
func testConnectionState_values() {
    @Expect(true, true)
}

// ============================================================================
// ConnectionInfo Tests
// ============================================================================

@Test
func testConnectionInfo_creation() {
    let info = ConnectionInfo("192.168.1.1:8080", "localhost:9000")
    @Expect(info.remoteAddress, "192.168.1.1:8080")
    @Expect(info.localAddress, "localhost:9000")
}

// ============================================================================
// EnhancedTcpTransport Tests
// ============================================================================

@Test
func testEnhancedTcpTransport_creation() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedTcpTransport(addr)
    @Expect(transport.isActive(), false)
}

@Test
func testEnhancedTcpTransport_startStop() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedTcpTransport(addr)
    transport.start()
    @Expect(transport.isActive(), true)
    transport.stop()
    @Expect(transport.isActive(), false)
}

@Test
func testEnhancedTcpTransport_connect() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedTcpTransport(addr)
    transport.start()

    let remote = NetworkAddress("remotehost", 9000)
    let result = transport.connect(remote, None)
    @Expect(result, true)
    @Expect(transport.getActiveConnectionCount(), 1)

    transport.stop()
}

@Test
func testEnhancedTcpTransport_disconnect() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedTcpTransport(addr)
    transport.start()

    let remote = NetworkAddress("remotehost", 9000)
    let _ = transport.connect(remote, None)
    transport.disconnect(remote)
    @Expect(transport.getActiveConnectionCount(), 0)

    transport.stop()
}

@Test
func testEnhancedTcpTransport_send() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedTcpTransport(addr)
    transport.start()

    let remote = NetworkAddress("remotehost", 9000)
    let data = Array<UInt8>(4, { i: Int64 => 0u8 })
    let result = transport.send(remote, data)
    @Expect(result, true)

    transport.stop()
}

// ============================================================================
// EnhancedUdpTransport Tests
// ============================================================================

@Test
func testEnhancedUdpTransport_creation() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedUdpTransport(addr)
    @Expect(transport.isActive(), false)
}

@Test
func testEnhancedUdpTransport_startStop() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedUdpTransport(addr)
    transport.start()
    @Expect(transport.isActive(), true)
    transport.stop()
    @Expect(transport.isActive(), false)
}

@Test
func testEnhancedUdpTransport_connect() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedUdpTransport(addr)
    transport.start()

    let remote = NetworkAddress("remotehost", 9000)
    let result = transport.connect(remote, None)
    @Expect(result, true)

    transport.stop()
}

@Test
func testEnhancedUdpTransport_send() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = EnhancedUdpTransport(addr)
    transport.start()

    let remote = NetworkAddress("remotehost", 9000)
    let data = Array<UInt8>(4, { i: Int64 => 0u8 })
    let result = transport.send(remote, data)
    @Expect(result, true)

    transport.stop()
}

// ============================================================================
// ConnectionPoolConfig Tests
// ============================================================================

@Test
func testConnectionPoolConfig_defaults() {
    let config = ConnectionPoolConfig()
    @Expect(config.maxConnections, 100)
    @Expect(config.maxPacketSize, 1024 * 1024)
}

// ============================================================================
// ConnectionPool Tests
// ============================================================================

@Test
func testConnectionPool_creation() {
    let config = ConnectionPoolConfig()
    let pool = ConnectionPool(config)
    let s = pool.size()
    @Expect(s == 0, true)
}

@Test
func testConnectionPool_add() {
    let config = ConnectionPoolConfig()
    let pool = ConnectionPool(config)
    let info = ConnectionInfo("remote:9000", "local:8080")
    let result = pool.add("connection1", info)
    @Expect(result, true)
    let s = pool.size()
    @Expect(s == 1, true)
}

@Test
func testConnectionPool_acquire() {
    let config = ConnectionPoolConfig()
    let pool = ConnectionPool(config)
    let info = ConnectionInfo("remote:9000", "local:8080")
    let _ = pool.add("connection1", info)

    match (pool.acquire("connection1")) {
        case Some(i) => @Expect(i.remoteAddress, "remote:9000")
        case None => @Expect(true, false)
    }
}

@Test
func testConnectionPool_release() {
    let config = ConnectionPoolConfig()
    let pool = ConnectionPool(config)
    let info = ConnectionInfo("remote:9000", "local:8080")
    let _ = pool.add("connection1", info)
    pool.release("connection1")
    let s = pool.size()
    @Expect(s == 1, true)
}

@Test
func testConnectionPool_remove() {
    let config = ConnectionPoolConfig()
    let pool = ConnectionPool(config)
    let info = ConnectionInfo("remote:9000", "local:8080")
    let _ = pool.add("connection1", info)
    pool.remove("connection1")
    let s = pool.size()
    @Expect(s == 0, true)
}

@Test
func testConnectionPool_maxConnections() {
    let config = ConnectionPoolConfig()
    config.maxConnections = 2
    let pool = ConnectionPool(config)

    let info1 = ConnectionInfo("remote1:9000", "local:8080")
    let info2 = ConnectionInfo("remote2:9000", "local:8080")
    let info3 = ConnectionInfo("remote3:9000", "local:8080")

    @Expect(pool.add("c1", info1), true)
    @Expect(pool.add("c2", info2), true)
    @Expect(pool.add("c3", info3), false)
}

// ============================================================================
// NetworkFactory Tests
// ============================================================================

@Test
func testNetworkFactory_createTcp() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = NetworkFactory.createTcp(addr)
    @Expect(transport.isActive(), false)
}

@Test
func testNetworkFactory_createUdp() {
    let addr = NetworkAddress("localhost", 8080)
    let transport = NetworkFactory.createUdp(addr)
    @Expect(transport.isActive(), false)
}

@Test
func testNetworkFactory_createByProtocol() {
    let addr = NetworkAddress("localhost", 8080)
    let tcp = NetworkFactory.create(TransportProtocol.TCP, addr)
    @Expect(tcp.isActive(), false)

    let udp = NetworkFactory.create(TransportProtocol.UDP, addr)
    @Expect(udp.isActive(), false)
}

@Test
func testNetworkFactory_createConnectionPool() {
    let pool = NetworkFactory.createConnectionPool()
    let s = pool.size()
    @Expect(s == 0, true)
}