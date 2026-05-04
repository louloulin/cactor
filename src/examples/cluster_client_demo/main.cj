/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Client 示例程序
 * 展示外部客户端与集群通信的使用
 */
package cactor.examples.cluster_client_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示集群客户端事件处理器
 */
public class DemoClusterClientHandler <: ClusterClientEventHandler {
    public let connectedEvents = ArrayList<String>()
    public let disconnectedEvents = ArrayList<String>()
    public let sentEvents = ArrayList<Int64>()
    public let receivedEvents = ArrayList<String>()

    public func onConnected(nodeId: String): Unit {
        connectedEvents.add(nodeId)
        println("  [CONNECTED] Connected to ${nodeId}")
    }

    public func onDisconnected(nodeId: String): Unit {
        disconnectedEvents.add(nodeId)
        println("  [DISCONNECTED] Disconnected from ${nodeId}")
    }

    public func onMessageSent(destination: String, messageId: Int64): Unit {
        sentEvents.add(messageId)
        println("  [SENT] msg-${messageId} -> ${destination}")
    }

    public func onMessageReceived(from: String, payload: String): Unit {
        receivedEvents.add(payload)
        println("  [RECEIVED] From ${from}: ${payload}")
    }

    public func onConnectionFailed(reason: String): Unit {
        println("  [FAILED] Connection failed: ${reason}")
    }
}

/**
 * 运行基本连接演示
 */
public func runBasicConnectionDemo(): Unit {
    println("=== Basic Connection Demo ===")
    let client = createClusterClient("external-client-1")
    let handler = DemoClusterClientHandler()
    client.setEventHandler(handler)

    println("Adding cluster contact points...")
    client.addContactPoint("cluster-node-1", 2552)
    client.addContactPoint("cluster-node-2", 2553)
    client.addContactPoint("cluster-node-3", 2554)

    println()
    println("Connecting to cluster...")
    let connected = client.connect()
    println("Connection result: ${connected}")
    println("  Is connected: ${client.isConnected()}")
    println("  Current node: ${client.getCurrentNode().getOrThrow()}")
    println("  Available contact points: ${client.getAvailableContactPoints().size}")
    println()
}

/**
 * 运行消息发送演示
 */
public func runMessageSendingDemo(): Unit {
    println("=== Message Sending Demo ===")
    let client = createClusterClient("external-client-2")
    let handler = DemoClusterClientHandler()
    client.setEventHandler(handler)

    client.addContactPoint("cluster-node-1", 2552)
    client.connect()

    println("Sending messages to cluster actors...")
    let msgId1 = client.send("/user/user-service", "Get user info: id=123")
    let msgId2 = client.send("/user/order-service", "Get orders for user: 123")
    let msgId3 = client.send("/user/payment-service", "Process payment: amount=99.99")

    println()
    println("Message status:")
    println("  Total sent: ${client.totalSent()}")
    println("  Pending: ${client.pendingCount()}")
    println()

    // 模拟确认
    println("Simulating acknowledgments...")
    client.acknowledge(msgId1)
    client.acknowledge(msgId2)
    println("  After ack: ${client.pendingCount()} pending")
    println()
}

/**
 * 运行批量发送演示
 */
public func runBatchSendingDemo(): Unit {
    println("=== Batch Sending Demo ===")
    let client = createClusterClient("external-client-3")
    let handler = DemoClusterClientHandler()
    client.setEventHandler(handler)

    client.addContactPoint("cluster-node-1", 2552)
    client.connect()

    println("Preparing batch messages...")
    let destinations = ArrayList<String>()
    destinations.append("/user/processor-1")
    destinations.append("/user/processor-2")
    destinations.append("/user/processor-3")
    destinations.append("/user/processor-4")
    destinations.append("/user/processor-5")

    let payloads = ArrayList<String>()
    payloads.append("Task 1: Process data set A")
    payloads.append("Task 2: Process data set B")
    payloads.append("Task 3: Process data set C")
    payloads.append("Task 4: Process data set D")
    payloads.append("Task 5: Process data set E")

    println("Sending batch of ${destinations.size} messages...")
    let messageIds = client.sendBatch(destinations, payloads)

    println()
    println("Batch sent:")
    println("  Message IDs: ${messageIds[0]} to ${messageIds[messageIds.size - 1]}")
    println("  Total sent: ${client.totalSent()}")
    println("  Pending: ${client.pendingCount()}")
    println()

    // 显示待确认消息
    let pending = client.getPendingMessages()
    println("Pending messages:")
    for ((msgId, dest, payload, retries) in pending) {
        println("  msg-${msgId}: ${dest} (retries: ${retries})")
    }
    println()
}

/**
 * 运行连接管理演示
 */
public func runConnectionManagementDemo(): Unit {
    println("=== Connection Management Demo ===")
    let client = createClusterClient("external-client-4")
    let handler = DemoClusterClientHandler()
    client.setEventHandler(handler)

    println("Setting up multiple contact points...")
    client.addContactPoint("node-1", 2552)
    client.addContactPoint("node-2", 2553)
    client.addContactPoint("node-3", 2554)

    println()
    println("Connection states:")
    println("  Initial state: ${client.getConnectionState()}")

    println()
    println("Connecting...")
    client.connect()
    println("  After connect: ${client.getConnectionState()}")

    println()
    println("Disconnecting...")
    client.disconnect()
    println("  After disconnect: ${client.getConnectionState()}")

    println()
    println("Reconnecting...")
    client.reconnect()
    println("  After reconnect: ${client.isConnected()}")
    println()
}

/**
 * 运行重试机制演示
 */
public func runRetryDemo(): Unit {
    println("=== Retry Mechanism Demo ===")
    let config = ClusterClientConfig(
        Duration.second * 1,    // Short reconnect
        Duration.second * 10,
        3,                      // Max 3 retries
        100,
        true
    )
    let client = createClusterClientWithConfig("retry-client", config)
    let handler = DemoClusterClientHandler()
    client.setEventHandler(handler)

    client.addContactPoint("unreliable-node", 2552)
    client.connect()

    println("Sending message...")
    client.send("/user/service", "Important message")

    println()
    println("Pending messages: ${client.pendingCount()}")
    println("Simulating retry...")
    let retryCount = client.retryPending()
    println("  Messages to retry: ${retryCount}")

    println()
    println("Getting pending messages for inspection...")
    let pending = client.getPendingMessages()
    for ((msgId, dest, payload, retries) in pending) {
        println("  msg-${msgId}: retries=${retries}, max=${config.maxRetries}")
    }
    println()
}

/**
 * 运行接收消息演示
 */
public func runMessageReceivingDemo(): Unit {
    println("=== Message Receiving Demo ===")
    let client = createClusterClient("receiver-client")
    let handler = DemoClusterClientHandler()
    client.setEventHandler(handler)

    client.addContactPoint("cluster-node-1", 2552)
    client.connect()

    println("Simulating received responses...")
    client.recordReceive("User data: John Doe, 30 years old", "from-user-service")
    client.recordReceive("Orders: [123, 456, 789]", "from-order-service")
    client.recordReceive("Payment status: Success", "from-payment-service")

    println()
    println("Statistics:")
    println("  Total sent: ${client.totalSent()}")
    println("  Total received: ${client.totalReceived()}")
    println()

    println("Received messages:")
    for (msg in handler.receivedEvents) {
        println("  - ${msg}")
    }
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Cluster Client Demo")
    println("=============================")
    println()

    runBasicConnectionDemo()
    runMessageSendingDemo()
    runBatchSendingDemo()
    runConnectionManagementDemo()
    runRetryDemo()
    runMessageReceivingDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}