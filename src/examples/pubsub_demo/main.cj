/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Distributed PubSub 示例程序
 * 展示集群发布订阅机制的使用
 */
package cactor.examples.pubsub_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示 PubSub 事件处理器
 */
public class DemoPubSubHandler <: PubSubEventHandler {
    public let subscribeEvents = ArrayList<String>()
    public let unsubscribeEvents = ArrayList<String>()
    public let publishEvents = ArrayList<String>()

    public func onSubscribe(topic: String, actorPath: String, nodeId: String): Unit {
        subscribeEvents.add(topic)
        println("  [EVENT] Subscribe: ${actorPath} -> ${topic} (@${nodeId})")
    }

    public func onUnsubscribe(topic: String, actorPath: String, nodeId: String): Unit {
        unsubscribeEvents.add(topic)
        println("  [EVENT] Unsubscribe: ${actorPath} -> ${topic} (@${nodeId})")
    }

    public func onPublish(topic: String, payload: String, sender: String): Unit {
        publishEvents.add(topic)
        println("  [EVENT] Publish: ${sender} -> ${topic}: ${payload}")
    }

    public func onNodeRegistered(nodeId: String, address: Address): Unit {
        println("  [EVENT] Node registered: ${nodeId} @ ${address.host}:${address.port}")
    }

    public func onNodeUnregistered(nodeId: String): Unit {
        println("  [EVENT] Node unregistered: ${nodeId}")
    }
}

/**
 * 运行基本发布订阅演示
 */
public func runBasicPubSubDemo(): Unit {
    println("=== Basic Pub/Sub Demo ===")
    let mediator = createDistributedPubSubMediator("node-1")
    let handler = DemoPubSubHandler()
    mediator.setEventHandler(handler)

    println("Setting up subscribers...")
    mediator.subscribe("news", "/user/subscriber1", None)
    mediator.subscribe("news", "/user/subscriber2", None)
    mediator.subscribe("sports", "/user/subscriber3", None)

    println()
    println("Publishing to 'news' topic...")
    let receivers = mediator.publish("news", "Breaking: CActor v8.0 released!", "publisher1")
    println("Delivered to ${receivers.size} subscribers")

    println()
    println("Publishing to 'sports' topic...")
    let sportsReceivers = mediator.publish("sports", "World Cup final happening now!", "publisher2")
    println("Delivered to ${sportsReceivers.size} subscribers")
    println()
}

/**
 * 运行节点管理演示
 */
public func runNodeManagementDemo(): Unit {
    println("=== Node Management Demo ===")
    let mediator = createDistributedPubSubMediator("node-1")
    let handler = DemoPubSubHandler()
    mediator.setEventHandler(handler)

    println("Registering cluster nodes...")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))
    mediator.registerNode("node-2", Address("cactor", "pubsub", "host2", 2552))
    mediator.registerNode("node-3", Address("cactor", "pubsub", "host3", 2552))

    println()
    println("Current node count: ${mediator.nodeCount()}")
    println("All nodes: ${mediator.getNodeIds()}")

    println()
    println("Registering actors on nodes...")
    mediator.put("/user/worker1")
    mediator.put("/user/worker2")
    mediator.put("/user/worker3")

    println()
    println("Unregistering node-3...")
    mediator.unregisterNode("node-3")
    println("Current node count: ${mediator.nodeCount()}")
    println()
}

/**
 * 运行分组订阅演示
 */
public func runGroupSubscriptionDemo(): Unit {
    println("=== Group Subscription Demo ===")
    let mediator = createDistributedPubSubMediator("node-1")
    let handler = DemoPubSubHandler()
    mediator.setEventHandler(handler)

    println("Setting up group-based subscriptions...")
    mediator.subscribe("alerts", "/user/team-a-consumer1", Some("team-a"))
    mediator.subscribe("alerts", "/user/team-a-consumer2", Some("team-a"))
    mediator.subscribe("alerts", "/user/team-b-consumer1", Some("team-b"))
    mediator.subscribe("alerts", "/user/team-b-consumer2", Some("team-b"))

    println()
    println("Publishing alert message...")
    let receivers = mediator.publish("alerts", "Critical: System overload detected!", "system")
    println("Message delivered to ${receivers.size} total subscribers")
    println("  (Note: Group subscriptions allow one message per group)")
    println()
}

/**
 * 运行直接发送演示
 */
public func runDirectSendDemo(): Unit {
    println("=== Direct Send Demo ===")
    let mediator = createDistributedPubSubMediator("node-1")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))

    println("Registering actors...")
    mediator.put("/user/actor1")
    mediator.put("/user/actor2")
    mediator.put("/user/actor3")

    println()
    println("Sending direct message to /user/actor2...")
    let result = mediator.send("/user/actor2", "Direct message payload", "sender")
    match (result) {
        case Some((nodeId, actorPath)) =>
            println("Message routed to: ${actorPath} @ ${nodeId}")
        case None =>
            println("Actor not found!")
    }

    println()
    println("Trying to send to non-existent actor...")
    let notFound = mediator.send("/user/nonexistent", "This will fail", "sender")
    @Expect(notFound.isNone(), true)
    println("Confirmed: No route for non-existent actor")
    println()
}

/**
 * 运行主题快照演示
 */
public func runTopicSnapshotDemo(): Unit {
    println("=== Topic Snapshot Demo ===")
    let mediator = createDistributedPubSubMediator("node-1")
    let handler = DemoPubSubHandler()
    mediator.setEventHandler(handler)

    println("Creating topics and subscriptions...")
    mediator.subscribe("topic-a", "/user/sub1", None)
    mediator.subscribe("topic-a", "/user/sub2", None)
    mediator.subscribe("topic-a", "/user/sub3", None)
    mediator.subscribe("topic-b", "/user/sub1", None)
    mediator.subscribe("topic-b", "/user/sub2", None)
    mediator.subscribe("topic-c", "/user/sub1", None)

    println()
    println("Current topics: ${mediator.topicNames()}")
    println()
    println("Topic snapshot:")
    let snapshot = mediator.getTopicsSnapshot()
    for ((topic, count) in snapshot) {
        println("  ${topic}: ${count} subscribers")
    }

    println()
    println("Statistics:")
    println("  Total topics: ${mediator.topicCount()}")
    println("  Total subscribers: ${mediator.totalSubscribers()}")
    println("  Messages processed: ${mediator.messageCount()}")
    println()
}

/**
 * 运行 SendToAll 演示
 */
public func runSendToAllDemo(): Unit {
    println("=== SendToAll Demo ===")
    let mediator = createDistributedPubSubMediator("node-1")

    println("Setting up subscribers for notification...")
    mediator.subscribe("notifications", "/user/email-sender", None)
    mediator.subscribe("notifications", "/user/sms-sender", None)
    mediator.subscribe("notifications", "/user/push-sender", None)

    println()
    println("Sending notification to all notification channels...")
    let receivers = mediator.sendToAll("notifications", "System update available", "admin")
    println("Notification sent to ${receivers.size} channels:")
    for (path in receivers) {
        println("  -> ${path}")
    }
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Distributed Pub/Sub Demo")
    println("=================================")
    println()

    runBasicPubSubDemo()
    runNodeManagementDemo()
    runGroupSubscriptionDemo()
    runDirectSendDemo()
    runTopicSnapshotDemo()
    runSendToAllDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}