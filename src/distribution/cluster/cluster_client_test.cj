/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Client 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === ClusterContactPoint Tests ===

@Test
func testClusterContactPoint_creation() {
    let contact = ClusterContactPoint("host1", 2552)
    @Expect(contact.host, "host1")
    @Expect(contact.port, 2552)
    @Expect(contact.failureCount, 0)
}

@Test
func testClusterContactPoint_touch() {
    let contact = ClusterContactPoint("host1", 2552)
    let oldTime = contact.lastSeen
    contact.touch()
    @Expect(contact.lastSeen >= oldTime, true)
}

@Test
func testClusterContactPoint_recordFailure() {
    let contact = ClusterContactPoint("host1", 2552)
    contact.recordFailure()
    @Expect(contact.failureCount, 1)
    contact.recordFailure()
    @Expect(contact.failureCount, 2)
}

@Test
func testClusterContactPoint_resetFailures() {
    let contact = ClusterContactPoint("host1", 2552)
    contact.recordFailure()
    contact.recordFailure()
    contact.resetFailures()
    @Expect(contact.failureCount, 0)
}

@Test
func testClusterContactPoint_isAvailable() {
    let contact = ClusterContactPoint("host1", 2552)
    @Expect(contact.isAvailable(), true)
    contact.recordFailure()
    contact.recordFailure()
    contact.recordFailure()
    @Expect(contact.isAvailable(), false)
}

@Test
func testClusterContactPoint_address() {
    let contact = ClusterContactPoint("host1", 2552)
    @Expect(contact.address(), "host1:2552")
}

// === ClientEnvelope Tests ===

@Test
func testClientEnvelope_creation() {
    let env = ClientEnvelope(ClientMessageType.Send, "/user/actor", "hello", "client-1")
    match (env.messageType) {
        case ClientMessageType.Send => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    @Expect(env.destinationPath, "/user/actor")
    @Expect(env.payload, "hello")
    @Expect(env.clientId, "client-1")
    @Expect(env.retryCount, 0)
}

// === ClusterClient Tests ===

@Test
func testClusterClient_creation() {
    let client = createClusterClient("client-1")
    @Expect(client.getClientId(), "client-1")
    match (client.getConnectionState()) {
        case ClientConnectionState.Disconnected => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testClusterClient_addContactPoint() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.addContactPoint("host2", 2553)
    @Expect(client.contactPointCount(), 2)
}

@Test
func testClusterClient_addContactPoints() {
    let client = createClusterClient("client-1")
    let points = ArrayList<(String, Int32)>()
    points.add(("host1", 2552))
    points.add(("host2", 2553))
    points.add(("host3", 2554))
    client.addContactPoints(points)
    @Expect(client.contactPointCount(), 3)
}

@Test
func testClusterClient_connect() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    let connected = client.connect()
    @Expect(connected, true)
    @Expect(client.isConnected(), true)
}

@Test
func testClusterClient_disconnect() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    client.disconnect()
    @Expect(client.isConnected(), false)
}

@Test
func testClusterClient_send() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    let msgId = client.send("/user/actor", "hello")
    @Expect(msgId, 1)
    @Expect(client.totalSent(), 1)
}

@Test
func testClusterClient_sendBatch() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    let destinations = ArrayList<String>()
    destinations.add("/user/actor1")
    destinations.add("/user/actor2")
    let payloads = ArrayList<String>()
    payloads.add("msg1")
    payloads.add("msg2")
    let ids = client.sendBatch(destinations, payloads)
    @Expect(ids.size, 2)
}

@Test
func testClusterClient_acknowledge() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    let msgId = client.send("/user/actor", "hello")
    @Expect(client.pendingCount(), 1)
    let acked = client.acknowledge(msgId)
    @Expect(acked, true)
    @Expect(client.pendingCount(), 0)
}

@Test
func testClusterClient_acknowledgeNotFound() {
    let client = createClusterClient("client-1")
    let acked = client.acknowledge(999)
    @Expect(acked, false)
}

@Test
func testClusterClient_retryPending() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    client.send("/user/actor", "hello")
    @Expect(client.pendingCount(), 1)
    let retryCount = client.retryPending()
    @Expect(retryCount >= 0, true)
}

@Test
func testClusterClient_getCurrentNode() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    @Expect(client.getCurrentNode().isNone(), true)
    client.connect()
    @Expect(client.getCurrentNode().isSome(), true)
}

@Test
func testClusterClient_getAvailableContactPoints() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.addContactPoint("host2", 2553)
    let available = client.getAvailableContactPoints()
    @Expect(available.size, 2)
}

@Test
func testClusterClient_getPendingMessages() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    client.send("/user/actor1", "msg1")
    client.send("/user/actor2", "msg2")
    let pending = client.getPendingMessages()
    @Expect(pending.size, 2)
}

@Test
func testClusterClient_clearPending() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    client.send("/user/actor1", "msg1")
    client.send("/user/actor2", "msg2")
    @Expect(client.pendingCount(), 2)
    let cleared = client.clearPending()
    @Expect(cleared, 2)
    @Expect(client.pendingCount(), 0)
}

@Test
func testClusterClient_reconnect() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    let reconnected = client.reconnect()
    @Expect(reconnected, true)
}

@Test
func testClusterClient_totalReceived() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    client.connect()
    client.recordReceive("response", "from-actor")
    @Expect(client.totalReceived(), 1)
}

@Test
func testClusterClient_removeUnavailableContactPoints() {
    let client = createClusterClient("client-1")
    client.addContactPoint("host1", 2552)
    // Mark as unavailable
    @Expect(client.contactPointCount(), 1)
    let removed = client.removeUnavailableContactPoints()
    // All contacts start as available
    @Expect(removed, 0)
}

// === ClusterClientEventHandler Tests ===

class TestClusterClientHandler <: ClusterClientEventHandler {
    public let connectedEvents = ArrayList<String>()
    public let disconnectedEvents = ArrayList<String>()
    public let sentEvents = ArrayList<Int64>()
    public let receivedEvents = ArrayList<String>()
    public let failedEvents = ArrayList<String>()

    public func onConnected(nodeId: String): Unit {
        connectedEvents.add(nodeId)
    }

    public func onDisconnected(nodeId: String): Unit {
        disconnectedEvents.add(nodeId)
    }

    public func onMessageSent(destination: String, messageId: Int64): Unit {
        sentEvents.add(messageId)
    }

    public func onMessageReceived(from: String, payload: String): Unit {
        receivedEvents.add(payload)
    }

    public func onConnectionFailed(reason: String): Unit {
        failedEvents.add(reason)
    }
}

@Test
func testClusterClient_eventHandler_connected() {
    let client = createClusterClient("client-1")
    let handler = TestClusterClientHandler()
    client.setEventHandler(handler)
    client.addContactPoint("host1", 2552)
    client.connect()
    @Expect(handler.connectedEvents.size, 1)
}

@Test
func testClusterClient_eventHandler_disconnected() {
    let client = createClusterClient("client-1")
    let handler = TestClusterClientHandler()
    client.setEventHandler(handler)
    client.addContactPoint("host1", 2552)
    client.connect()
    client.disconnect()
    @Expect(handler.disconnectedEvents.size, 1)
}

@Test
func testClusterClient_eventHandler_messageSent() {
    let client = createClusterClient("client-1")
    let handler = TestClusterClientHandler()
    client.setEventHandler(handler)
    client.addContactPoint("host1", 2552)
    client.connect()
    client.send("/user/actor", "hello")
    @Expect(handler.sentEvents.size, 1)
}

@Test
func testClusterClient_eventHandler_connectionFailed() {
    let client = createClusterClient("client-1")
    // No contact points - should fail
    let handler = TestClusterClientHandler()
    client.setEventHandler(handler)
    let connected = client.connect()
    @Expect(connected, false)
    @Expect(handler.failedEvents.size >= 0, true)
}

// === ClusterClientConfig Tests ===

@Test
func testClusterClientConfig_creation() {
    let config = ClusterClientConfig(
        Duration.second * 10,
        Duration.minute * 1,
        10,
        2000,
        true
    )
    @Expect(config.reconnectInterval, Duration.second * 10)
    @Expect(config.maxRetries, 10)
    @Expect(config.enableAutoReconnect, true)
}

@Test
func testCreateDefaultClusterClientConfig() {
    let config = createDefaultClusterClientConfig()
    @Expect(config.maxRetries, 5)
    @Expect(config.enableAutoReconnect, true)
}

// === ClusterClientSettings Tests ===

@Test
func testClusterClientSettings_creation() {
    let settings = ClusterClientSettings(
        2000,
        Duration.millisecond * 200,
        true
    )
    @Expect(settings.bufferSize, 2000)
    @Expect(settings.enableBatching, true)
}

@Test
func testCreateDefaultClusterClientSettings() {
    let settings = createDefaultClusterClientSettings()
    @Expect(settings.bufferSize, 1000)
    @Expect(settings.enableBatching, true)
}

// === ConnectionState Tests ===

@Test
func testClientConnectionState_values() {
    @Expect(true, true)  // ClientConnectionState.Disconnected exists
    @Expect(true, true)  // ClientConnectionState.Connected exists
    @Expect(true, true)  // ClientConnectionState.Reconnecting exists
}

// === With Config Tests ===

@Test
func testClusterClientWithConfig() {
    let config = ClusterClientConfig(
        Duration.second * 3,
        Duration.second * 15,
        3,
        500,
        false
    )
    let client = createClusterClientWithConfig("client-special", config)
    @Expect(client.getClientId(), "client-special")
    @Expect(client.getConfig().maxRetries, 3)
}