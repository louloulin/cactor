/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - SnapshotStore 单元测试
 */
package cactor.distribution.persistence

import std.collection.*
import std.time.*

// === BasicSnapshot Tests ===

@Test
func testBasicSnapshot_creation() {
    let snapshot = BasicSnapshot("actor-1", 100, "{\"state\":\"active\"}")

    @Expect(snapshot.getActorId(), "actor-1")
    @Expect(snapshot.getSequenceNumber(), 100)
    @Expect(snapshot.getStateData(), "{\"state\":\"active\"}")
    @Expect(snapshot.getTimestamp() > 0, true)
}

@Test
func testBasicSnapshot_toString() {
    let snapshot = BasicSnapshot("snap-actor", 50, "state data")

    let str = snapshot.toString()
    let hasActor = str.contains("snap-actor")
    let hasSeq = str.contains("seq=50")

    @Expect(hasActor, true)
    @Expect(hasSeq, true)
}

@Test
func testBasicSnapshot_timestampIsSet() {
    let before = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let snapshot = BasicSnapshot("actor", 1, "data")
    let after = DateTime.now().toUnixTimeStamp().toMilliseconds()

    let ts = snapshot.getTimestamp()
    @Expect(ts >= before, true)
    @Expect(ts <= after, true)
}

// === MemorySnapshotStore Tests ===

@Test
func testMemorySnapshotStore_creation() {
    let store = MemorySnapshotStore()
    // Basic creation - just verify no exception thrown
    @Expect(true, true)
}

@Test
func testMemorySnapshotStore_saveSnapshot() {
    let store = MemorySnapshotStore()
    let snapshot = BasicSnapshot("actor-A", 1, "initial state")

    store.saveSnapshot(snapshot)
    @Expect(true, true)
}

@Test
func testMemorySnapshotStore_getLatestSnapshot_empty() {
    let store = MemorySnapshotStore()
    let result = store.getLatestSnapshot("non-existent")

    let isNone = match (result) {
        case Some(_) => false
        case None => true
    }
    @Expect(isNone, true)
}

@Test
func testMemorySnapshotStore_getLatestSnapshot_single() {
    let store = MemorySnapshotStore()
    let snapshot = BasicSnapshot("actor-B", 1, "state v1")
    store.saveSnapshot(snapshot)

    let result = store.getLatestSnapshot("actor-B")
    match (result) {
        case Some(s) => @Expect(s.getStateData(), "state v1")
        case None => @Expect(false, true)
    }
}

@Test
func testMemorySnapshotStore_getLatestSnapshot_multiple() {
    let store = MemorySnapshotStore()

    store.saveSnapshot(BasicSnapshot("actor-C", 1, "v1"))
    store.saveSnapshot(BasicSnapshot("actor-C", 2, "v2"))
    store.saveSnapshot(BasicSnapshot("actor-C", 3, "v3"))

    let result = store.getLatestSnapshot("actor-C")
    match (result) {
        case Some(s) => @Expect(s.getSequenceNumber(), 3)
        case None => @Expect(false, true)
    }
}

@Test
func testMemorySnapshotStore_getSnapshot_specific() {
    let store = MemorySnapshotStore()

    store.saveSnapshot(BasicSnapshot("actor-D", 1, "v1"))
    store.saveSnapshot(BasicSnapshot("actor-D", 2, "v2"))
    store.saveSnapshot(BasicSnapshot("actor-D", 3, "v3"))

    let result = store.getSnapshot("actor-D", 2)
    match (result) {
        case Some(s) => @Expect(s.getStateData(), "v2")
        case None => @Expect(false, true)
    }
}

@Test
func testMemorySnapshotStore_getSnapshot_notFound() {
    let store = MemorySnapshotStore()
    store.saveSnapshot(BasicSnapshot("actor-E", 1, "v1"))

    let result = store.getSnapshot("actor-E", 99)
    let isNone = match (result) {
        case Some(_) => false
        case None => true
    }
    @Expect(isNone, true)
}

@Test
func testMemorySnapshotStore_deleteSnapshots() {
    let store = MemorySnapshotStore()
    store.saveSnapshot(BasicSnapshot("actor-F", 1, "v1"))

    let result = store.getLatestSnapshot("actor-F")
    let hasSnapshot = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasSnapshot, true)

    store.deleteSnapshots("actor-F")

    let resultAfter = store.getLatestSnapshot("actor-F")
    let isEmpty = match (resultAfter) {
        case Some(_) => false
        case None => true
    }
    @Expect(isEmpty, true)
}

@Test
func testMemorySnapshotStore_close() {
    let store = MemorySnapshotStore()
    store.close()
    // close() should not throw
    @Expect(true, true)
}

// === Integration Tests ===

@Test
func testSnapshotStore_sequenceOrdering() {
    let store = MemorySnapshotStore()

    for (i in 1..=5) {
        let snapshot = BasicSnapshot("seq-actor", Int64(i), "state ${i}")
        store.saveSnapshot(snapshot)
    }

    let latest = store.getLatestSnapshot("seq-actor")
    match (latest) {
        case Some(s) => @Expect(s.getSequenceNumber(), 5)
        case None => @Expect(false, true)
    }
}

@Test
func testSnapshotStore_differentActors() {
    let store = MemorySnapshotStore()

    store.saveSnapshot(BasicSnapshot("actor-1", 1, "state-A"))
    store.saveSnapshot(BasicSnapshot("actor-2", 1, "state-B"))
    store.saveSnapshot(BasicSnapshot("actor-1", 2, "state-A2"))

    let latest1 = store.getLatestSnapshot("actor-1")
    let latest2 = store.getLatestSnapshot("actor-2")

    match (latest1) {
        case Some(s) => @Expect(s.getSequenceNumber(), 2)
        case None => @Expect(false, true)
    }
    match (latest2) {
        case Some(s) => @Expect(s.getSequenceNumber(), 1)
        case None => @Expect(false, true)
    }
}

@Test
func testSnapshotStore_stateDataPreservation() {
    let store = MemorySnapshotStore()
    let jsonState = "{\"users\":[{\"id\":1},{\"id\":2}],\"count\":2}"
    let snapshot = BasicSnapshot("state-actor", 10, jsonState)
    store.saveSnapshot(snapshot)

    let result = store.getLatestSnapshot("state-actor")
    match (result) {
        case Some(s) => @Expect(s.getStateData(), jsonState)
        case None => @Expect(false, true)
    }
}

@Test
func testSnapshotStore_retrieveBySequence() {
    let store = MemorySnapshotStore()
    let states = ["alpha", "beta", "gamma", "delta", "epsilon"]

    for (i in 0..5) {
        store.saveSnapshot(BasicSnapshot("multi-seq", Int64(i + 1), states[Int64(i)]))
    }

    // Retrieve middle snapshot
    let mid = store.getSnapshot("multi-seq", 3)
    match (mid) {
        case Some(s) => @Expect(s.getStateData(), "gamma")
        case None => @Expect(false, true)
    }

    // Retrieve first snapshot
    let first = store.getSnapshot("multi-seq", 1)
    match (first) {
        case Some(s) => @Expect(s.getStateData(), "alpha")
        case None => @Expect(false, true)
    }
}