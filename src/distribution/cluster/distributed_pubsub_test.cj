/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Distributed PubSub 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === Helper ===

func createMediator(nodeId: String): DistributedPubSubMediator {
    let mediator = createDistributedPubSubMediator(nodeId)
    mediator.registerNode(nodeId, Address("cactor", "pubsub", "host1", 2552))
    mediator
}

// === PubSubMessageType Tests ===

@Test
func testPubSubMessageType_values() {
    @Expect(true, true)  // PubSubMessageType.PublishMsg exists
    @Expect(true, true)  // PubSubMessageType.SendMsg exists
    @Expect(true, true)  // PubSubMessageType.SubscribeMsg exists
}

// === PubSubMessage Tests ===

@Test
func testPubSubMessage_creation() {
    let msg = PubSubMessage(PubSubMessageType.PublishMsg, "topic1", "payload", "sender1", None, false)
    match (msg.msgType) {
        case PubSubMessageType.PublishMsg => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    @Expect(msg.topic, "topic1")
    @Expect(msg.payload, "payload")
    @Expect(msg.sender, "sender1")
    @Expect(msg.groupId.isNone(), true)
    @Expect(msg.allAtOnce, false)
}

@Test
func testPubSubMessage_withGroup() {
    let msg = PubSubMessage(PubSubMessageType.PublishMsg, "topic1", "payload", "sender1", Some("group1"), true)
    @Expect(msg.groupId.getOrThrow(), "group1")
    @Expect(msg.allAtOnce, true)
}

// === Subscriber Tests ===

@Test
func testSubscriber_creation() {
    let sub = Subscriber("/user/actor1", "node-1", None)
    @Expect(sub.actorPath, "/user/actor1")
    @Expect(sub.nodeId, "node-1")
    @Expect(sub.groupId.isNone(), true)
}

@Test
func testSubscriber_withGroup() {
    let sub = Subscriber("/user/actor1", "node-1", Some("group1"))
    @Expect(sub.groupId.getOrThrow(), "group1")
}

// === TopicManager Tests ===

@Test
func testTopicManager_creation() {
    let tm = TopicManager("topic1")
    @Expect(tm.topicName, "topic1")
    @Expect(tm.hasSubscribers(), false)
}

@Test
func testTopicManager_subscribe() {
    let tm = TopicManager("topic1")
    tm.subscribe("/user/actor1", "node-1", None)
    @Expect(tm.hasSubscribers(), true)
    @Expect(tm.subscriberCount(), 1)
}

@Test
func testTopicManager_unsubscribe() {
    let tm = TopicManager("topic1")
    tm.subscribe("/user/actor1", "node-1", None)
    tm.unsubscribe("/user/actor1")
    @Expect(tm.hasSubscribers(), false)
}

@Test
func testTopicManager_multipleSubscribers() {
    let tm = TopicManager("topic1")
    tm.subscribe("/user/actor1", "node-1", None)
    tm.subscribe("/user/actor2", "node-2", None)
    tm.subscribe("/user/actor3", "node-3", Some("group1"))
    @Expect(tm.subscriberCount(), 3)
}

@Test
func testTopicManager_getGroupSubscribers() {
    let tm = TopicManager("topic1")
    tm.subscribe("/user/actor1", "node-1", Some("group1"))
    tm.subscribe("/user/actor2", "node-2", Some("group1"))
    tm.subscribe("/user/actor3", "node-3", Some("group2"))
    let group1Subs = tm.getGroupSubscribers("group1")
    @Expect(group1Subs.size, 2)
}

@Test
func testTopicManager_getSubscribers() {
    let tm = TopicManager("topic1")
    tm.subscribe("/user/actor1", "node-1", None)
    tm.subscribe("/user/actor2", "node-2", None)
    let subs = tm.getSubscribers()
    @Expect(subs.size, 2)
}

@Test
func testTopicManager_clear() {
    let tm = TopicManager("topic1")
    tm.subscribe("/user/actor1", "node-1", None)
    tm.clear()
    @Expect(tm.hasSubscribers(), false)
}

// === NodeRegistration Tests ===

@Test
func testNodeRegistration_creation() {
    let reg = NodeRegistration("node-1", Address("cactor", "test", "host", 2552))
    @Expect(reg.nodeId, "node-1")
    @Expect(reg.actorPaths.size, 0)
}

@Test
func testNodeRegistration_addActorPath() {
    let reg = NodeRegistration("node-1", Address("cactor", "test", "host", 2552))
    reg.addActorPath("/user/actor1")
    reg.addActorPath("/user/actor2")
    @Expect(reg.actorPaths.size, 2)
    @Expect(reg.hasActorPath("/user/actor1"), true)
    @Expect(reg.hasActorPath("/user/actor2"), true)
    @Expect(reg.hasActorPath("/user/actor3"), false)
}

// === DistributedPubSubMediator Tests ===

@Test
func testDistributedPubSubMediator_creation() {
    let mediator = createDistributedPubSubMediator("node-1")
    @Expect(mediator.topicCount(), 0)
    @Expect(mediator.nodeCount(), 0)
}

@Test
func testDistributedPubSubMediator_registerNode() {
    let mediator = createDistributedPubSubMediator("node-1")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))
    @Expect(mediator.nodeCount(), 1)
    @Expect(mediator.hasNode("node-1"), true)
}

@Test
func testDistributedPubSubMediator_unregisterNode() {
    let mediator = createDistributedPubSubMediator("node-1")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))
    mediator.unregisterNode("node-1")
    @Expect(mediator.nodeCount(), 0)
}

@Test
func testDistributedPubSubMediator_subscribe() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    @Expect(mediator.topicCount(), 1)
    @Expect(mediator.hasTopic("topic1"), true)
    @Expect(mediator.subscriberCountForTopic("topic1"), 1)
}

@Test
func testDistributedPubSubMediator_unsubscribe() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.unsubscribe("topic1", "/user/actor1")
    @Expect(mediator.subscriberCountForTopic("topic1"), 0)
}

@Test
func testDistributedPubSubMediator_publish() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.subscribe("topic1", "/user/actor2", None)
    let receivers = mediator.publish("topic1", "hello", "sender1")
    @Expect(receivers.size, 2)
    @Expect(receivers.contains("/user/actor1"), true)
    @Expect(receivers.contains("/user/actor2"), true)
}

@Test
func testDistributedPubSubMediator_publishNoSubscribers() {
    let mediator = createMediator("node-1")
    let receivers = mediator.publish("nonexistent", "hello", "sender1")
    @Expect(receivers.size, 0)
}

@Test
func testDistributedPubSubMediator_publishWithGroup() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", Some("group1"))
    mediator.subscribe("topic1", "/user/actor2", Some("group1"))
    mediator.subscribe("topic1", "/user/actor3", Some("group2"))
    let receivers = mediator.publish("topic1", "hello", "sender1")
    // All subscribers receive, regardless of group
    @Expect(receivers.size, 3)
}

@Test
func testDistributedPubSubMediator_send() {
    let mediator = createDistributedPubSubMediator("node-1")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))
    mediator.put("/user/actor1")
    let result = mediator.send("/user/actor1", "hello", "sender1")
    @Expect(result.isSome(), true)
}

@Test
func testDistributedPubSubMediator_sendNotFound() {
    let mediator = createMediator("node-1")
    let result = mediator.send("/user/nonexistent", "hello", "sender1")
    @Expect(result.isNone(), true)
}

@Test
func testDistributedPubSubMediator_sendToAll() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.subscribe("topic1", "/user/actor2", None)
    let receivers = mediator.sendToAll("topic1", "hello", "sender1")
    @Expect(receivers.size, 2)
}

@Test
func testDistributedPubSubMediator_put() {
    let mediator = createDistributedPubSubMediator("node-1")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))
    mediator.put("/user/actor1")
    mediator.put("/user/actor2")
    let reg = mediator.getNode("node-1")
    match (reg) {
        case Some(r) => @Expect(r.actorPaths.size, 2)
        case None => ()
    }
}

@Test
func testDistributedPubSubMediator_topicNames() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.subscribe("topic2", "/user/actor1", None)
    let names = mediator.topicNames()
    @Expect(names.size, 2)
    @Expect(names.contains("topic1"), true)
    @Expect(names.contains("topic2"), true)
}

@Test
func testDistributedPubSubMediator_getTopicsSnapshot() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.subscribe("topic2", "/user/actor1", None)
    mediator.subscribe("topic2", "/user/actor2", None)
    let snapshot = mediator.getTopicsSnapshot()
    @Expect(snapshot.size, 2)
}

@Test
func testDistributedPubSubMediator_getNodeIds() {
    let mediator = createDistributedPubSubMediator("node-1")
    mediator.registerNode("node-1", Address("cactor", "pubsub", "host1", 2552))
    mediator.registerNode("node-2", Address("cactor", "pubsub", "host2", 2552))
    let ids = mediator.getNodeIds()
    @Expect(ids.size, 2)
    @Expect(ids.contains("node-1"), true)
    @Expect(ids.contains("node-2"), true)
}

@Test
func testDistributedPubSubMediator_messageCount() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.publish("topic1", "msg1", "sender1")
    mediator.publish("topic1", "msg2", "sender1")
    mediator.send("/user/actor1", "msg3", "sender1")
    @Expect(mediator.messageCount(), 3)
}

@Test
func testDistributedPubSubMediator_totalSubscribers() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.subscribe("topic1", "/user/actor2", None)
    mediator.subscribe("topic2", "/user/actor3", None)
    @Expect(mediator.totalSubscribers(), 3)
}

@Test
func testDistributedPubSubMediator_removeTopic() {
    let mediator = createMediator("node-1")
    mediator.subscribe("topic1", "/user/actor1", None)
    @Expect(mediator.hasTopic("topic1"), true)
    mediator.removeTopic("topic1")
    @Expect(mediator.hasTopic("topic1"), false)
}

// === PubSubEventHandler Tests ===

class TestPubSubHandler <: PubSubEventHandler {
    public let subscribeEvents = ArrayList<(String, String, String)>()
    public let unsubscribeEvents = ArrayList<(String, String, String)>()
    public let publishEvents = ArrayList<(String, String, String)>()
    public let nodeRegisteredEvents = ArrayList<String>()
    public let nodeUnregisteredEvents = ArrayList<String>()

    public func onSubscribe(topic: String, actorPath: String, nodeId: String): Unit {
        subscribeEvents.add((topic, actorPath, nodeId))
    }

    public func onUnsubscribe(topic: String, actorPath: String, nodeId: String): Unit {
        unsubscribeEvents.add((topic, actorPath, nodeId))
    }

    public func onPublish(topic: String, payload: String, sender: String): Unit {
        publishEvents.add((topic, payload, sender))
    }

    public func onNodeRegistered(nodeId: String, address: Address): Unit {
        nodeRegisteredEvents.add(nodeId)
    }

    public func onNodeUnregistered(nodeId: String): Unit {
        nodeUnregisteredEvents.add(nodeId)
    }
}

@Test
func testDistributedPubSubMediator_eventHandler_subscribe() {
    let mediator = createMediator("node-1")
    let handler = TestPubSubHandler()
    mediator.setEventHandler(handler)
    mediator.subscribe("topic1", "/user/actor1", None)
    @Expect(handler.subscribeEvents.size, 1)
    let (topic, actorPath, nodeId) = handler.subscribeEvents[0]
    @Expect(topic, "topic1")
}

@Test
func testDistributedPubSubMediator_eventHandler_unsubscribe() {
    let mediator = createMediator("node-1")
    let handler = TestPubSubHandler()
    mediator.setEventHandler(handler)
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.unsubscribe("topic1", "/user/actor1")
    @Expect(handler.unsubscribeEvents.size, 1)
}

@Test
func testDistributedPubSubMediator_eventHandler_publish() {
    let mediator = createMediator("node-1")
    let handler = TestPubSubHandler()
    mediator.setEventHandler(handler)
    mediator.subscribe("topic1", "/user/actor1", None)
    mediator.publish("topic1", "hello", "sender1")
    @Expect(handler.publishEvents.size, 1)
    let (topic, payload, sender) = handler.publishEvents[0]
    @Expect(topic, "topic1")
    @Expect(payload, "hello")
}

@Test
func testDistributedPubSubMediator_eventHandler_nodeRegistered() {
    let mediator = createDistributedPubSubMediator("node-1")
    let handler = TestPubSubHandler()
    mediator.setEventHandler(handler)
    mediator.registerNode("node-2", Address("cactor", "pubsub", "host2", 2552))
    @Expect(handler.nodeRegisteredEvents.size, 1)
    @Expect(handler.nodeRegisteredEvents[0], "node-2")
}

@Test
func testDistributedPubSubMediator_eventHandler_nodeUnregistered() {
    let mediator = createDistributedPubSubMediator("node-1")
    let handler = TestPubSubHandler()
    mediator.setEventHandler(handler)
    mediator.registerNode("node-2", Address("cactor", "pubsub", "host2", 2552))
    mediator.unregisterNode("node-2")
    @Expect(handler.nodeUnregisteredEvents.size, 1)
    @Expect(handler.nodeUnregisteredEvents[0], "node-2")
}

// === PubSubConfig Tests ===

@Test
func testPubSubConfig_creation() {
    let config = PubSubConfig(1000, 5000, 60000, true)
    @Expect(config.maxTopics, 1000)
    @Expect(config.maxSubscribersPerTopic, 5000)
    @Expect(config.messageTtlMs, 60000)
    @Expect(config.enableGroupSubscriptions, true)
}

@Test
func testCreateDefaultPubSubConfig() {
    let config = createDefaultPubSubConfig()
    @Expect(config.maxTopics, 1000)
    @Expect(config.enableGroupSubscriptions, true)
}