/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Projections 单元测试
 */
package cactor.distribution.persistence

import std.collection.*

// === LongOffset Tests ===

@Test
func testLongOffset_creation() {
    let offset = LongOffset(100)
    @Expect(offset.getValue(), 100)
}

@Test
func testLongOffset_toOffsetString() {
    let offset = LongOffset(42)
    let str = offset.toOffsetString()
    @Expect(str, "42")
}

@Test
func testLongOffset_compareTo() {
    let offset1 = LongOffset(10)
    let offset2 = LongOffset(20)
    let offset3 = LongOffset(10)

    @Expect(offset1.compareTo(offset2) < 0, true)
    @Expect(offset2.compareTo(offset1) > 0, true)
    @Expect(offset1.compareTo(offset3) == 0, true)
}

// === StringOffset Tests ===

@Test
func testStringOffset_creation() {
    let offset = StringOffset("event-123")
    @Expect(offset.getValue(), "event-123")
}

@Test
func testStringOffset_toOffsetString() {
    let offset = StringOffset("test")
    @Expect(offset.toOffsetString(), "test")
}

@Test
func testStringOffset_compareTo() {
    let offset1 = StringOffset("a")
    let offset2 = StringOffset("b")
    let offset3 = StringOffset("a")

    @Expect(offset1.compareTo(offset2) < 0, true)
    @Expect(offset2.compareTo(offset1) > 0, true)
    @Expect(offset1.compareTo(offset3) == 0, true)
}

// === InMemoryOffsetStore Tests ===

@Test
func testInMemoryOffsetStore_creation() {
    let store = InMemoryOffsetStore()
    @Expect(true, true)
}

@Test
func testInMemoryOffsetStore_saveAndRead() {
    let store = InMemoryOffsetStore()
    let offset = LongOffset(100)

    store.saveOffset("proj1", offset)
    let readOffset = store.readOffset("proj1")

    match (readOffset) {
        case Some(o) => @Expect(o.compareTo(offset) == 0, true)
        case None => @Expect(true, false)
    }
}

@Test
func testInMemoryOffsetStore_delete() {
    let store = InMemoryOffsetStore()
    let offset = LongOffset(100)

    store.saveOffset("proj1", offset)
    store.deleteOffset("proj1")
    let readOffset = store.readOffset("proj1")

    match (readOffset) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testInMemoryOffsetStore_getProjectionIds() {
    let store = InMemoryOffsetStore()

    store.saveOffset("proj1", LongOffset(1))
    store.saveOffset("proj2", LongOffset(2))
    store.saveOffset("proj3", LongOffset(3))

    let ids = store.getProjectionIds()
    @Expect(ids.size, 3)
}

@Test
func testInMemoryOffsetStore_clear() {
    let store = InMemoryOffsetStore()

    store.saveOffset("proj1", LongOffset(1))
    store.clear()

    let ids = store.getProjectionIds()
    @Expect(ids.size, 0)
}

// === Envelope Tests ===

@Test
func testEnvelope_creation() {
    let offset = LongOffset(100)
    let env = Envelope("event", offset)
    @Expect(env.timestamp > 0, true)
}

@Test
func testEnvelope_withTimestamp() {
    let offset = LongOffset(100)
    let env = Envelope("event", offset, 1000)
    @Expect(env.timestamp, 1000)
}

// === SimpleEventIterator Tests ===

@Test
func testSimpleEventIterator_empty() {
    let events = ArrayList<Envelope>()
    let iter = SimpleEventIterator(events)
    @Expect(iter.hasNext(), false)
}

@Test
func testSimpleEventIterator_singleItem() {
    let events = ArrayList<Envelope>()
    events.add(Envelope("a", LongOffset(1)))

    let iter = SimpleEventIterator(events)

    @Expect(iter.hasNext(), true)
    match (iter.next()) {
        case Some(env) => @Expect(true, true)
        case None => @Expect(true, false)
    }
    @Expect(iter.hasNext(), false)
}

@Test
func testSimpleEventIterator_multipleItems() {
    let events = ArrayList<Envelope>()
    events.add(Envelope("a", LongOffset(1)))
    events.add(Envelope("b", LongOffset(2)))
    events.add(Envelope("c", LongOffset(3)))

    let iter = SimpleEventIterator(events)

    let count = iterateAll(iter)
    @Expect(count, 3)
}

private func iterateAll(iter: SimpleEventIterator): Int64 {
    var count = 0
    while (iter.hasNext()) {
        match (iter.next()) {
            case Some(_) => count += 1
            case None => ()
        }
    }
    count
}

// === SimpleSourceProvider Tests ===

@Test
func testSimpleSourceProvider_creation() {
    let events = ArrayList<Envelope>()
    events.add(Envelope("a", LongOffset(1)))
    let provider = SimpleSourceProvider(events)
    @Expect(true, true)
}

@Test
func testSimpleSourceProvider_initialOffset() {
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)

    match (provider.initialOffset()) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testSimpleSourceProvider_source() {
    let events = ArrayList<Envelope>()
    events.add(Envelope("a", LongOffset(1)))
    events.add(Envelope("b", LongOffset(2)))
    let provider = SimpleSourceProvider(events)

    let iter = provider.source()
    let count = countIterator(iter)
    @Expect(count, 2)
}

private func countIterator(iter: EventIterator): Int64 {
    var count = 0
    while (iter.hasNext()) {
        match (iter.next()) {
            case Some(_) => count += 1
            case None => ()
        }
    }
    count
}

// === ProjectionConfig Tests ===

@Test
func testProjectionConfig_default() {
    let config = ProjectionConfig()
    @Expect(config.name, "")
    match (config.offsetStrategy) {
        case OffsetStrategy.Store => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}

@Test
func testProjectionConfig_custom() {
    let config = ProjectionConfig(
        name: "my-projection",
        offsetStrategy: OffsetStrategy.NoStore,
        restartBackoff: Duration.second * 5,
        emitTrackProgress: false
    )

    @Expect(config.name, "my-projection")
    match (config.offsetStrategy) {
        case OffsetStrategy.NoStore => @Expect(true, true)
        case _ => @Expect(true, false)
    }
    @Expect(config.emitTrackProgress, false)
}

// === ProjectionState Tests ===

@Test
func testProjectionState_isRunning() {
    @Expect(ProjectionState.Running.isRunning(), true)
    @Expect(ProjectionState.Stopped.isRunning(), false)
    @Expect(ProjectionState.Paused.isRunning(), false)
}

@Test
func testProjectionState_isStopped() {
    @Expect(ProjectionState.Stopped.isStopped(), true)
    @Expect(ProjectionState.Running.isStopped(), false)
}

// === ProjectionRegistry Tests ===

@Test
func testProjectionRegistry_creation() {
    let registry = ProjectionRegistry()
    @Expect(registry.size(), 0)
}

@Test
func testProjectionRegistry_register() {
    let registry = ProjectionRegistry()
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)

    registry.register(projection)
    @Expect(registry.size(), 1)
}

@Test
func testProjectionRegistry_get() {
    let registry = ProjectionRegistry()
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)

    registry.register(projection)

    match (registry.get("test")) {
        case Some(p) => @Expect(p.projectionId(), "test")
        case None => @Expect(true, false)
    }
}

@Test
func testProjectionRegistry_getNonExistent() {
    let registry = ProjectionRegistry()

    match (registry.get("non-existent")) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

// === ProjectionBuilder Tests ===

@Test
func testProjectionBuilder_creation() {
    let builder = ProjectionBuilder()
    @Expect(true, true)
}

@Test
func testProjectionBuilder_buildWithoutHandler() {
    let builder = ProjectionBuilder()
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)

    builder.withSourceProvider(provider)
    builder.withOffsetStore(store)

    match (builder.build()) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testProjectionBuilder_buildComplete() {
    let builder = ProjectionBuilder()
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    builder.withProjectionId("test-proj")
    builder.withHandler(handler)
    builder.withSourceProvider(provider)
    builder.withOffsetStore(store)

    match (builder.build()) {
        case Some(p) => @Expect(p.projectionId(), "test-proj")
        case None => @Expect(true, false)
    }
}

@Test
func testProjectionBuilder_autoName() {
    let builder = ProjectionBuilder()
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    builder.withHandler(handler)
    builder.withSourceProvider(provider)
    builder.withOffsetStore(store)

    match (builder.build()) {
        case Some(p) => @Expect(p.projectionId().startsWith("projection-"), true)
        case None => @Expect(true, false)
    }
}

// === ProjectionInstance Tests ===

@Test
func testProjectionInstance_creation() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)

    let instance = ProjectionInstance(projection, store)
    @Expect(instance.getProjection().projectionId(), "test")
}

@Test
func testProjectionInstance_getCurrentOffset() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)

    let instance = ProjectionInstance(projection, store)

    match (instance.getCurrentOffset()) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testProjectionInstance_resetOffset() {
    let store = InMemoryOffsetStore()
    store.saveOffset("test", LongOffset(100))

    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)

    let instance = ProjectionInstance(projection, store)
    instance.resetOffset()

    match (instance.getCurrentOffset()) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testProjectionInstance_getStats() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)

    let instance = ProjectionInstance(projection, store)
    let stats = instance.getStats()

    @Expect(stats.projectionId, "test")
    @Expect(stats.state.isStopped(), true)
}

// === Integration Tests ===

// Test helper to verify event processing
private func createTestProjection(name: String, eventCount: Int64, store: InMemoryOffsetStore): SimpleProjection {
    let events = ArrayList<Envelope>()
    for (i in 0..eventCount) {
        events.add(Envelope("event${i}", LongOffset(i)))
    }
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }
    SimpleProjection(name, ProjectionConfig(), handler, provider, store)
}

@Test
func testProjection_runWithEvents() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    events.add(Envelope("event1", LongOffset(1)))
    events.add(Envelope("event2", LongOffset(2)))
    events.add(Envelope("event3", LongOffset(3)))
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)
    projection.start()

    @Expect(projection.state().isRunning(), true)
}

@Test
func testProjection_withOffsetStrategy() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    events.add(Envelope("event1", LongOffset(1)))
    events.add(Envelope("event2", LongOffset(2)))
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    let config = ProjectionConfig(offsetStrategy: OffsetStrategy.NoStore)
    let projection = SimpleProjection("test", config, handler, provider, store)
    projection.start()

    // Offset should not be saved
    match (store.readOffset("test")) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testProjection_pauseResume() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    events.add(Envelope("event1", LongOffset(1)))
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)
    projection.start()

    projection.pause()
    @Expect(projection.state().isRunning(), false)

    projection.resume()
    @Expect(projection.state().isRunning(), true)
}

@Test
func testProjectionRegistry_startAll() {
    let registry = ProjectionRegistry()

    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    events.add(Envelope("event1", LongOffset(1)))
    let provider = SimpleSourceProvider(events)
    let handler1: ProjectionHandler = { env => () }
    let proj1 = SimpleProjection("proj1", ProjectionConfig(), handler1, provider, store)

    let handler2: ProjectionHandler = { env => () }
    let proj2 = SimpleProjection("proj2", ProjectionConfig(), handler2, provider, store)

    registry.register(proj1)
    registry.register(proj2)

    registry.startAll()

    // Verify projections ran (offset saved means they processed events)
    match (store.readOffset("proj1")) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, false)
    }
    match (store.readOffset("proj2")) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, false)
    }
}

@Test
func testProjection_stop() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    events.add(Envelope("event1", LongOffset(1)))
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)
    projection.start()
    projection.stop()

    @Expect(projection.state().isStopped(), true)
}

@Test
func testProjection_startMultipleTimes() {
    let store = InMemoryOffsetStore()
    let events = ArrayList<Envelope>()
    events.add(Envelope("event1", LongOffset(1)))
    let provider = SimpleSourceProvider(events)
    let handler: ProjectionHandler = { env => () }

    let projection = SimpleProjection("test", ProjectionConfig(), handler, provider, store)
    projection.start()
    projection.stop()
    projection.start()

    @Expect(projection.state().isRunning(), true)
}
