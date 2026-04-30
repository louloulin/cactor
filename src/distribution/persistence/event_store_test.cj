/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - EventStore 单元测试
 */
package cactor.distribution.persistence

import std.time.*

// === BasicEvent Tests ===

@Test
func testBasicEvent_creation() {
    let event = BasicEvent("event-1", "actor-1", "UserCreated", "{\"name\":\"test\"}")

    @Expect(event.getEventId(), "event-1")
    @Expect(event.getActorId(), "actor-1")
    @Expect(event.getEventType(), "UserCreated")
    @Expect(event.getEventData(), "{\"name\":\"test\"}")
    @Expect(event.getTimestamp() > 0, true)
}

@Test
func testBasicEvent_toString() {
    let event = BasicEvent("evt-123", "actor-A", "OrderPlaced", "{data}")

    let str = event.toString()
    let hasEventId = str.contains("evt-123")
    let hasActorId = str.contains("actor-A")
    let hasEventType = str.contains("OrderPlaced")

    @Expect(hasEventId, true)
    @Expect(hasActorId, true)
    @Expect(hasEventType, true)
}

@Test
func testBasicEvent_timestampIsSet() {
    let before = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let event = BasicEvent("evt-1", "actor-1", "Test", "data")
    let after = DateTime.now().toUnixTimeStamp().toMilliseconds()

    let ts = event.getTimestamp()
    @Expect(ts >= before, true)
    @Expect(ts <= after, true)
}

// === MemoryEventStore Tests ===

@Test
func testMemoryEventStore_creation() {
    let store = MemoryEventStore()
    // Basic creation - just verify no exception thrown
    @Expect(true, true)
}

@Test
func testMemoryEventStore_saveEvent() {
    let store = MemoryEventStore()
    let event = BasicEvent("evt-1", "actor-A", "Created", "test data")

    store.saveEvent(event)
    @Expect(true, true)
}

@Test
func testMemoryEventStore_getEvents_empty() {
    let store = MemoryEventStore()
    let events = store.getEvents("non-existent")

    @Expect(events.size, 0)
}

@Test
func testMemoryEventStore_getEvents_single() {
    let store = MemoryEventStore()
    let event = BasicEvent("evt-1", "actor-B", "TestEvent", "test")
    store.saveEvent(event)

    let events = store.getEvents("actor-B")
    @Expect(events.size, 1)
    @Expect(events[0].getEventType(), "TestEvent")
}

@Test
func testMemoryEventStore_getEvents_multiple() {
    let store = MemoryEventStore()

    store.saveEvent(BasicEvent("evt-1", "actor-C", "Event1", "data1"))
    store.saveEvent(BasicEvent("evt-2", "actor-C", "Event2", "data2"))
    store.saveEvent(BasicEvent("evt-3", "actor-C", "Event3", "data3"))

    let events = store.getEvents("actor-C")
    @Expect(events.size, 3)
}

@Test
func testMemoryEventStore_getEventsAfter() {
    let store = MemoryEventStore()
    let event1 = BasicEvent("evt-1", "actor-D", "E1", "d1")
    store.saveEvent(event1)
    let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()

    let event2 = BasicEvent("evt-2", "actor-D", "E2", "d2")
    store.saveEvent(event2)

    let events = store.getEventsAfter("actor-D", timestamp)
    @Expect(events.size, 1)
    @Expect(events[0].getEventType(), "E2")
}

@Test
func testMemoryEventStore_deleteEvents() {
    let store = MemoryEventStore()
    store.saveEvent(BasicEvent("evt-1", "actor-E", "Test", "data"))

    let events = store.getEvents("actor-E")
    @Expect(events.size, 1)

    store.deleteEvents("actor-E")

    let eventsAfter = store.getEvents("actor-E")
    @Expect(eventsAfter.size, 0)
}

@Test
func testMemoryEventStore_close() {
    let store = MemoryEventStore()
    store.close()
    // close() should not throw
    @Expect(true, true)
}

// === Integration Tests ===

@Test
func testEventStore_eventOrdering() {
    let store = MemoryEventStore()

    for (i in 0..5) {
        let event = BasicEvent("evt-${i}", "ordering-actor", "Ordered", "item ${i}")
        store.saveEvent(event)
    }

    let events = store.getEvents("ordering-actor")
    @Expect(events.size, 5)

    // Verify order is preserved
    @Expect(events[0].getEventId(), "evt-0")
    @Expect(events[1].getEventId(), "evt-1")
    @Expect(events[2].getEventId(), "evt-2")
}

@Test
func testEventStore_differentActors() {
    let store = MemoryEventStore()

    store.saveEvent(BasicEvent("e1", "actor-1", "TypeA", "data1"))
    store.saveEvent(BasicEvent("e2", "actor-2", "TypeB", "data2"))
    store.saveEvent(BasicEvent("e3", "actor-1", "TypeC", "data3"))

    let events1 = store.getEvents("actor-1")
    let events2 = store.getEvents("actor-2")

    @Expect(events1.size, 2)
    @Expect(events2.size, 1)
}

@Test
func testEventStore_eventDataPreservation() {
    let store = MemoryEventStore()
    let jsonData = "{\"key\":\"value\",\"num\":123,\"nested\":{\"a\":1}}"
    let event = BasicEvent("preserve-1", "test-actor", "JSONEvent", jsonData)
    store.saveEvent(event)

    let events = store.getEvents("test-actor")
    @Expect(events.size, 1)
    @Expect(events[0].getEventData(), jsonData)
}