/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ActorEventBus 单元测试
 */
package cactor.runtime.events

import std.time.*
import std.collection.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.Message

// === Test ActorRef ===

class TestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(pathStr: String) {
        this.pathValue = ActorPath("test", pathStr)
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, sender: Option<String>): Unit {}

    public func equals(other: ActorRef): Bool {
        pathValue.toString() == other.path.toString()
    }

    public func hashCode(): Int32 { 0 }
}

// === Test Event Listener ===

class TestEventListener <: SimpleEventListener {
    private let receivedEvents: ArrayList<SimpleActorLifecycleEvent>
    private let eventTypes: ArrayList<String>

    public init() {
        this.receivedEvents = ArrayList<SimpleActorLifecycleEvent>()
        this.eventTypes = ArrayList<String>()
    }

    public func onEvent(event: SimpleActorLifecycleEvent): Unit {
        receivedEvents.add(event)
        eventTypes.add(event.eventType)
    }

    public func getReceivedEvents(): ArrayList<SimpleActorLifecycleEvent> {
        receivedEvents
    }

    public func getEventCount(): Int64 {
        Int64(receivedEvents.size)
    }

    public func hasEventType(eventType: String): Bool {
        eventTypes.contains(eventType)
    }

    public func clear(): Unit {
        receivedEvents.clear()
        eventTypes.clear()
    }
}

// === Test ActorEventListener ===

class TestActorEventListener <: ActorEventListener {
    private let receivedEvents: ArrayList<ActorLifecycleEvent>

    public init() {
        this.receivedEvents = ArrayList<ActorLifecycleEvent>()
    }

    public func onEvent(event: ActorLifecycleEvent): Unit {
        receivedEvents.add(event)
    }

    public func getReceivedEvents(): ArrayList<ActorLifecycleEvent> {
        receivedEvents
    }

    public func getEventCount(): Int64 {
        Int64(receivedEvents.size)
    }

    public func clear(): Unit {
        receivedEvents.clear()
    }
}

// === SimpleActorEventBus Tests ===

@Test
func testSimpleActorEventBus_creation() {
    let bus = SimpleActorEventBus()

    @Expect(bus.hasSubscribers(), false)
    @Expect(bus.getEventCount(), 0)
    @Expect(bus.isActive(), true)
}

@Test
func testSimpleActorEventBus_subscribe() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()

    bus.subscribe(listener)

    @Expect(bus.hasSubscribers(), true)
    @Expect(bus.getSubscriberCount(), 1)
}

@Test
func testSimpleActorEventBus_multipleSubscribers() {
    let bus = SimpleActorEventBus()
    let listener1 = TestEventListener()
    let listener2 = TestEventListener()

    bus.subscribe(listener1)
    bus.subscribe(listener2)

    @Expect(bus.getSubscriberCount(), 2)
}

@Test
func testSimpleActorEventBus_publish() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/test")

    bus.subscribe(listener)
    let event = SimpleActorLifecycleEvent(actorRef, "TEST", "Test message")
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
    @Expect(bus.getEventCount(), 1)
}

@Test
func testSimpleActorEventBus_publishMultipleEvents() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/test")

    bus.subscribe(listener)

    for (i in 0..5) {
        let event = SimpleActorLifecycleEvent(actorRef, "TEST", "Message ${i}")
        bus.publish(event)
    }

    @Expect(listener.getEventCount(), 5)
    @Expect(bus.getEventCount(), 5)
}

@Test
func testSimpleActorEventBus_multipleListeners() {
    let bus = SimpleActorEventBus()
    let listener1 = TestEventListener()
    let listener2 = TestEventListener()
    let actorRef = TestActorRef("/user/test")

    bus.subscribe(listener1)
    bus.subscribe(listener2)

    let event = SimpleActorLifecycleEvent(actorRef, "TEST", "Test")
    bus.publish(event)

    @Expect(listener1.getEventCount(), 1)
    @Expect(listener2.getEventCount(), 1)
}

@Test
func testSimpleActorEventBus_publishActorCreated() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/newActor")

    bus.subscribe(listener)
    bus.publishActorCreated(actorRef)

    @Expect(listener.getEventCount(), 1)
    @Expect(listener.hasEventType("CREATED"), true)
}

@Test
func testSimpleActorEventBus_publishActorStopped() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/stoppedActor")

    bus.subscribe(listener)
    bus.publishActorStopped(actorRef)

    @Expect(listener.getEventCount(), 1)
    @Expect(listener.hasEventType("STOPPED"), true)
}

@Test
func testSimpleActorEventBus_stop() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/test")

    bus.subscribe(listener)
    bus.stop()

    @Expect(bus.isActive(), false)

    let event = SimpleActorLifecycleEvent(actorRef, "TEST", "Should not be received")
    bus.publish(event)

    @Expect(listener.getEventCount(), 0)
}

@Test
func testSimpleActorEventBus_start() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/test")

    bus.subscribe(listener)
    bus.stop()
    bus.start()

    @Expect(bus.isActive(), true)

    let event = SimpleActorLifecycleEvent(actorRef, "TEST", "Should be received")
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testSimpleActorEventBus_clear() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()

    bus.subscribe(listener)
    @Expect(bus.hasSubscribers(), true)

    bus.clear()

    @Expect(bus.hasSubscribers(), false)
}

@Test
func testSimpleActorEventBus_shutdown() {
    let bus = SimpleActorEventBus()

    bus.shutdown()

    @Expect(bus.isActive(), false)
}

@Test
func testSimpleActorLifecycleEvent_creation() {
    let actorRef = TestActorRef("/user/actor")
    let event = SimpleActorLifecycleEvent(actorRef, "CREATED", "Actor created")

    @Expect(event.actorRef.path.toString().contains("/user/actor"), true)
    @Expect(event.eventType, "CREATED")
    @Expect(event.message, "Actor created")
    @Expect(event.timestamp > 0, true)
}

// === ActorEventBus Tests ===

@Test
func testActorEventBus_creation() {
    let bus = ActorEventBus()

    @Expect(bus.hasSubscribers(), false)
    @Expect(bus.getEventCount(), 0)
    @Expect(bus.getSubscriberCount(), 0)
}

@Test
func testActorEventBus_subscribe() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()

    bus.subscribe(listener)

    @Expect(bus.hasSubscribers(), true)
    @Expect(bus.getSubscriberCount(), 1)
}

@Test
func testActorEventBus_subscribeWithEventTypes() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let eventTypes = HashSet<String>()
    eventTypes.add("ActorCreated")
    eventTypes.add("ActorStopped")

    bus.subscribe(listener, eventTypes)

    @Expect(bus.hasSubscribers(), true)
}

@Test
func testActorEventBus_publishCreatedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)
    let event = ActorCreatedEvent(actorRef, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
    @Expect(bus.getEventCount(), 1)
}

@Test
func testActorEventBus_publishStartedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)
    let event = ActorStartedEvent(actorRef, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishStoppedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)
    let event = ActorStoppedEvent(actorRef, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishRestartedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let reason = Exception("Test exception")

    bus.subscribe(listener)
    let event = ActorRestartedEvent(actorRef, reason, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishRegisteredEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)
    let event = ActorRegisteredEvent(actorRef, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishUnregisteredEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)
    let event = ActorUnregisteredEvent(actorRef, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishStartFailedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let error = Exception("Start failed")

    bus.subscribe(listener)
    let event = ActorStartFailedEvent(actorRef, error, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishStopFailedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let error = Exception("Stop failed")

    bus.subscribe(listener)
    let event = ActorStopFailedEvent(actorRef, error, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_publishRestartFailedEvent() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let error = Exception("Restart failed")

    bus.subscribe(listener)
    let event = ActorRestartFailedEvent(actorRef, error, now)
    bus.publish(event)

    @Expect(listener.getEventCount(), 1)
}

@Test
func testActorEventBus_multipleEvents() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)

    bus.publish(ActorCreatedEvent(actorRef, now))
    bus.publish(ActorStartedEvent(actorRef, now))
    bus.publish(ActorStoppedEvent(actorRef, now))

    @Expect(listener.getEventCount(), 3)
    @Expect(bus.getEventCount(), 3)
}

@Test
func testActorEventBus_multipleSubscribers() {
    let bus = ActorEventBus()
    let listener1 = TestActorEventListener()
    let listener2 = TestActorEventListener()
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener1)
    bus.subscribe(listener2)

    let event = ActorCreatedEvent(actorRef, now)
    bus.publish(event)

    @Expect(listener1.getEventCount(), 1)
    @Expect(listener2.getEventCount(), 1)
}

// === EventSubscription Tests ===

@Test
func testEventSubscription_emptyEventTypes() {
    let listener = TestActorEventListener()
    let eventTypes = HashSet<String>()
    let subscription = EventSubscription(listener, eventTypes)

    @Expect(subscription.matches("ActorCreated"), true)
    @Expect(subscription.matches("ActorStopped"), true)
    @Expect(subscription.matches("AnyEvent"), true)
}

@Test
func testEventSubscription_specificEventTypes() {
    let listener = TestActorEventListener()
    let eventTypes = HashSet<String>()
    eventTypes.add("ActorCreated")
    eventTypes.add("ActorStopped")

    let subscription = EventSubscription(listener, eventTypes)

    @Expect(subscription.matches("ActorCreated"), true)
    @Expect(subscription.matches("ActorStopped"), true)
    @Expect(subscription.matches("ActorRestarted"), false)
}

// === ActorLifecycleEvent Tests ===

@Test
func testActorCreatedEvent_getEventType() {
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let event = ActorCreatedEvent(actorRef, now)

    @Expect(event.getEventType(), "ActorCreated")
    @Expect(event.getActorRef().path.toString().contains("/user/actor"), true)
    @Expect(event.getTimestamp(), now)
}

@Test
func testActorStartedEvent_getEventType() {
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let event = ActorStartedEvent(actorRef, now)

    @Expect(event.getEventType(), "ActorStarted")
}

@Test
func testActorStoppedEvent_getEventType() {
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let event = ActorStoppedEvent(actorRef, now)

    @Expect(event.getEventType(), "ActorStopped")
}

@Test
func testActorRestartedEvent_getEventType() {
    let actorRef = TestActorRef("/user/actor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    let reason = Exception("Test reason")
    let event = ActorRestartedEvent(actorRef, reason, now)

    @Expect(event.getEventType(), "ActorRestarted")
}

// === Helper Function Tests ===

@Test
func testCreateActorStartedEvent() {
    let actorRef = TestActorRef("/user/actor")
    let event = createActorStartedEvent(actorRef)

    @Expect(event.eventType, "STARTED")
    @Expect(event.actorRef.path.toString().contains("/user/actor"), true)
}

@Test
func testCreateActorStoppedEvent() {
    let actorRef = TestActorRef("/user/actor")
    let event = createActorStoppedEvent(actorRef)

    @Expect(event.eventType, "STOPPED")
    @Expect(event.actorRef.path.toString().contains("/user/actor"), true)
}

@Test
func testCreateActorCreatedEvent() {
    let actorRef = TestActorRef("/user/actor")
    let event = createActorCreatedEvent(actorRef)

    @Expect(event.eventType, "CREATED")
    @Expect(event.actorRef.path.toString().contains("/user/actor"), true)
}

// === Integration Tests ===

@Test
func testSimpleEventBus_fullLifecycle() {
    let bus = SimpleActorEventBus()
    let listener = TestEventListener()
    let actorRef = TestActorRef("/user/lifecycleActor")

    bus.subscribe(listener)

    // Simulate actor lifecycle
    bus.publishActorCreated(actorRef)
    bus.publishActorStopped(actorRef)

    @Expect(listener.getEventCount(), 2)
    @Expect(listener.hasEventType("CREATED"), true)
    @Expect(listener.hasEventType("STOPPED"), true)
}

@Test
func testActorEventBus_fullLifecycle() {
    let bus = ActorEventBus()
    let listener = TestActorEventListener()
    let actorRef = TestActorRef("/user/fullLifecycleActor")
    let now = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000

    bus.subscribe(listener)

    // Simulate actor lifecycle
    bus.publish(ActorCreatedEvent(actorRef, now))
    bus.publish(ActorStartedEvent(actorRef, now))
    bus.publish(ActorStoppedEvent(actorRef, now))

    @Expect(listener.getEventCount(), 3)
}

@Test
func testEventBus_broadcastsToAllSubscribers() {
    let bus = SimpleActorEventBus()
    let listener1 = TestEventListener()
    let listener2 = TestEventListener()
    let actorRef1 = TestActorRef("/user/actor1")
    let actorRef2 = TestActorRef("/user/actor2")

    bus.subscribe(listener1)
    bus.subscribe(listener2)

    // All subscribers receive all events (broadcast behavior)
    let event1 = SimpleActorLifecycleEvent(actorRef1, "TEST", "For actor1")
    bus.publish(event1)

    @Expect(listener1.getEventCount(), 1)
    @Expect(listener2.getEventCount(), 1)  // Both listeners receive the same event

    // Publish another event
    let event2 = SimpleActorLifecycleEvent(actorRef2, "TEST", "For actor2")
    bus.publish(event2)

    @Expect(listener1.getEventCount(), 2)
    @Expect(listener2.getEventCount(), 2)  // Both listeners receive both events
}
