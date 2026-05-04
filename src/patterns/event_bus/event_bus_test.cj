/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Event Bus 单元测试
 */
package cactor.patterns.event_bus

import std.collection.*
import std.time.*

// ============================================================================
// SubscriberId Tests
// ============================================================================

@Test
func testSubscriberId_creation() {
    let id = SubscriberId("sub-1")
    @Expect(id.id, "sub-1")
}

@Test
func testSubscriberId_equals() {
    let id1 = SubscriberId("sub-1")
    let id2 = SubscriberId("sub-1")
    let id3 = SubscriberId("sub-2")
    @Expect(id1.equals(id2), true)
    @Expect(id1.equals(id3), false)
}

// ============================================================================
// SimpleSubscriber Tests
// ============================================================================

@Test
func testSimpleSubscriber_creation() {
    var received: Int64 = 0
    let handler = { e: Event => received += 1 }
    let subscriber = SimpleSubscriber("sub-1", handler)
    @Expect(subscriber.subscriberId().id, "sub-1")
}

@Test
func testSimpleSubscriber_notify() {
    var received: Int64 = 0
    let handler = { e: Event => received += 1 }
    let subscriber = SimpleSubscriber("sub-1", handler)

    let event = Event("test")
    subscriber.notify(event)
    @Expect(received, 1)
}

// ============================================================================
// Event Tests
// ============================================================================

@Test
func testEvent_creation() {
    let event = Event("test data")
    @Expect(true, true)
}

@Test
func testEvent_creationWithSource() {
    let event = Event("test data", "source-1")
    @Expect(true, true)
}

// ============================================================================
// SubclassificationBasedEventBus Tests
// ============================================================================

@Test
func testEventBus_subscribe() {
    let bus = SubclassificationBasedEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let result = bus.subscribe(subscriber, "test.channel")
    @Expect(result, true)
}

@Test
func testEventBus_subscribeDuplicate() {
    let bus = SubclassificationBasedEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let result1 = bus.subscribe(subscriber, "test.channel")
    let result2 = bus.subscribe(subscriber, "test.channel")
    @Expect(result1, true)
    @Expect(result2, false)
}

@Test
func testEventBus_unsubscribe() {
    let bus = SubclassificationBasedEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let _ = bus.subscribe(subscriber, "test.channel")
    let result = bus.unsubscribe(subscriber, "test.channel")
    @Expect(result, true)
}

@Test
func testEventBus_unsubscribeNonExistent() {
    let bus = SubclassificationBasedEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let result = bus.unsubscribe(subscriber, "test.channel")
    @Expect(result, false)
}

@Test
func testEventBus_unsubscribeAll() {
    let bus = SubclassificationBasedEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let _ = bus.subscribe(subscriber, "channel.1")
    let _ = bus.subscribe(subscriber, "channel.2")
    let _ = bus.subscribe(subscriber, "channel.3")

    bus.unsubscribeAll(subscriber)

    @Expect(bus.getSubscriberCount("channel.1"), 0)
    @Expect(bus.getSubscriberCount("channel.2"), 0)
    @Expect(bus.getSubscriberCount("channel.3"), 0)
}

@Test
func testEventBus_publish() {
    let bus = SubclassificationBasedEventBus()
    var receivedCount: Int64 = 0
    let handler = { e: Event => receivedCount += 1 }
    let subscriber = SimpleSubscriber("sub-1", handler)

    let _ = bus.subscribe(subscriber, "test.channel")

    bus.publishToClassifier(Event("test message"), "test.channel")
    @Expect(receivedCount, 1)
}

@Test
func testEventBus_publishToMultipleSubscribers() {
    let bus = SubclassificationBasedEventBus()
    var count1: Int64 = 0
    var count2: Int64 = 0

    let handler1 = { e: Event => count1 += 1 }
    let handler2 = { e: Event => count2 += 1 }

    let sub1 = SimpleSubscriber("sub-1", handler1)
    let sub2 = SimpleSubscriber("sub-2", handler2)

    let _ = bus.subscribe(sub1, "test.channel")
    let _ = bus.subscribe(sub2, "test.channel")

    bus.publishToClassifier(Event("test message"), "test.channel")
    @Expect(count1, 1)
    @Expect(count2, 1)
}

@Test
func testEventBus_publishNoSubscribers() {
    let bus = SubclassificationBasedEventBus()
    // 不应该崩溃
    bus.publishToClassifier(Event("test message"), "empty.channel")
    @Expect(true, true)
}

@Test
func testEventBus_getSubscriberCount() {
    let bus = SubclassificationBasedEventBus()
    let sub1 = SimpleSubscriber("sub-1", { e: Event => () })
    let sub2 = SimpleSubscriber("sub-2", { e: Event => () })

    let _ = bus.subscribe(sub1, "channel")
    let _ = bus.subscribe(sub2, "channel")

    @Expect(bus.getSubscriberCount("channel"), 2)
}

@Test
func testEventBus_getSubscriberCountEmpty() {
    let bus = SubclassificationBasedEventBus()
    @Expect(bus.getSubscriberCount("empty"), 0)
}

@Test
func testEventBus_getClassifiers() {
    let bus = SubclassificationBasedEventBus()
    let sub1 = SimpleSubscriber("sub-1", { e: Event => () })

    let _ = bus.subscribe(sub1, "channel.1")
    let _ = bus.subscribe(sub1, "channel.2")

    let classifiers = bus.getClassifiers()
    @Expect(classifiers.size, 2)
}

// ============================================================================
// ClusterEvent Tests
// ============================================================================

@Test
func testClusterEvent_MemberJoined() {
    let event = ClusterEvent(ClusterEventType.MemberJoined, "node-1")
    @Expect(event.classify(), "cluster.member.joined")
    @Expect(event.nodeId, "node-1")
}

@Test
func testClusterEvent_MemberUp() {
    let event = ClusterEvent(ClusterEventType.MemberUp, "node-1")
    @Expect(event.classify(), "cluster.member.up")
}

@Test
func testClusterEvent_MemberUnreachable() {
    let event = ClusterEvent(ClusterEventType.MemberUnreachable, "node-1")
    @Expect(event.classify(), "cluster.member.unreachable")
}

@Test
func testClusterEvent_LeaderChanged() {
    let event = ClusterEvent(ClusterEventType.LeaderChanged, "node-1")
    @Expect(event.classify(), "cluster.leader.changed")
}

@Test
func testClusterEvent_toString() {
    let event = ClusterEvent(ClusterEventType.MemberUp, "node-1")
    let s = event.toString()
    @Expect(s.size > 0, true)
}

// ============================================================================
// ClusterEventBus Tests
// ============================================================================

@Test
func testClusterEventBus_subscribeToMemberChanges() {
    let bus = ClusterEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let result = bus.subscribeToMemberChanges(subscriber)
    @Expect(result, true)
}

@Test
func testClusterEventBus_subscribeToReachabilityChanges() {
    let bus = ClusterEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let result = bus.subscribeToReachabilityChanges(subscriber)
    @Expect(result, true)
}

@Test
func testClusterEventBus_subscribeToLeaderChanges() {
    let bus = ClusterEventBus()
    let subscriber = SimpleSubscriber("sub-1", { e: Event => () })

    let result = bus.subscribeToLeaderChanges(subscriber)
    @Expect(result, true)
}

@Test
func testClusterEventBus_publishMemberJoined() {
    let bus = ClusterEventBus()
    var received: Int64 = 0
    let handler = { e: Event => received += 1 }
    let subscriber = SimpleSubscriber("sub-1", handler)

    let _ = bus.subscribe(subscriber, "cluster.member.joined")
    bus.publishMemberJoined("node-1")
    @Expect(received, 1)
}

@Test
func testClusterEventBus_publishMemberUp() {
    let bus = ClusterEventBus()
    var received: Int64 = 0
    let handler = { e: Event => received += 1 }
    let subscriber = SimpleSubscriber("sub-1", handler)

    let _ = bus.subscribe(subscriber, "cluster.member.up")
    bus.publishMemberUp("node-1")
    @Expect(received, 1)
}

@Test
func testClusterEventBus_publishLeaderChanged() {
    let bus = ClusterEventBus()
    var received: Int64 = 0
    let handler = { e: Event => received += 1 }
    let subscriber = SimpleSubscriber("sub-1", handler)

    let _ = bus.subscribe(subscriber, "cluster.leader.changed")
    bus.publishLeaderChanged("node-1")
    @Expect(received, 1)
}

// ============================================================================
// EventBusFactory Tests
// ============================================================================

@Test
func testEventBusFactory_createEventBus() {
    let bus = EventBusFactory.createEventBus()
    @Expect(true, true)
}

@Test
func testEventBusFactory_createClusterEventBus() {
    let bus = EventBusFactory.createClusterEventBus()
    @Expect(true, true)
}