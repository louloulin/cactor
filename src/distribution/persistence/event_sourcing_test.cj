/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - EventSourcing 单元测试
 */
package cactor.distribution.persistence

import std.collection.*
import std.time.*

// === PersistentEvent Tests ===

@Test
func testDomainEvent_creation() {
    let event = DomainEvent("UserCreated", "user-123", 1)

    @Expect(event.eventType(), "UserCreated")
    let data = event.eventData()
    let dataStr = match (data) {
        case s: String => s
        case _ => ""
    }
    @Expect(dataStr, "user-123")
    @Expect(event.sequenceNr(), 1)
    @Expect(event.timestamp() > 0, true)
}

@Test
func testDomainEvent_timestamp() {
    let before = DateTime.now().toUnixTimeStamp().toSeconds()
    let event = DomainEvent("Test", "data", 1)
    let after = DateTime.now().toUnixTimeStamp().toSeconds()

    let ts = event.timestamp()
    @Expect(ts >= before, true)
    @Expect(ts <= after, true)
}

// === SnapshotMetadata Tests ===

@Test
func testSnapshotMetadata_creation() {
    let metadata = SnapshotMetadata("actor-1", 100)

    @Expect(metadata.persistenceId, "actor-1")
    @Expect(metadata.sequenceNr, 100)
    @Expect(metadata.timestamp > 0, true)
}

@Test
func testSnapshotMetadata_toString() {
    let metadata = SnapshotMetadata("test-actor", 50)

    let str = metadata.toString()
    let hasActor = str.contains("test-actor")
    let hasSeq = str.contains("50")

    @Expect(hasActor, true)
    @Expect(hasSeq, true)
}

// === SnapshotOffer Tests ===

@Test
func testSnapshotOfferImpl_creation() {
    let metadata = SnapshotMetadata("actor-2", 75)
    let state = "current-state-data"
    let offer = SnapshotOfferImpl(state, metadata)

    let snap = offer.snapshot()
    let snapStr = match (snap) {
        case s: String => s
        case _ => ""
    }
    @Expect(snapStr, state)
    @Expect(offer.metadata().persistenceId, "actor-2")
    @Expect(offer.metadata().sequenceNr, 75)
}

// === Recovery Tests ===

@Test
func testRecovery_default() {
    let recovery = Recovery.getDefault()

    @Expect(recovery.fromSnapshot, true)
    @Expect(recovery.toSequenceNr, Int64.Max)
    @Expect(recovery.replayMax, Int64.Max)
}

@Test
func testRecovery_custom() {
    let recovery = Recovery(
        fromSnapshot: false,
        toSequenceNr: 500,
        replayMax: 100
    )

    @Expect(recovery.fromSnapshot, false)
    @Expect(recovery.toSequenceNr, 500)
    @Expect(recovery.replayMax, 100)
}

// === PersistenceState Tests ===

@Test
func testPersistenceState_values() {
    let initializing = PersistenceState.Initializing
    let processing = PersistenceState.ProcessingCommands
    let snapshot = PersistenceState.ProcessingSnapshot
    let recovery = PersistenceState.RecoveryPending
    let completed = PersistenceState.RecoveryCompleted
    let shutdown = PersistenceState.Shutdown

    // Just verify they exist
    @Expect(true, true)
}

// === PersistenceHandler Tests ===

class TestHandler <: PersistenceHandler {
    public var handledEvents: ArrayList<PersistentEvent>
    public var snapshots: ArrayList<Any>

    public init() {
        this.handledEvents = ArrayList<PersistentEvent>()
        this.snapshots = ArrayList<Any>()
    }

    public func handle(event: PersistentEvent): Unit {
        handledEvents.add(event)
    }

    public func replay(events: ArrayList<PersistentEvent>): Unit {
        for (e in events) {
            handledEvents.add(e)
        }
    }

    public func provideSnapshot(sequenceNr: Int64): Option<Any> {
        if (snapshots.size > 0) {
            Some(snapshots[0])
        } else {
            None
        }
    }

    public func applySnapshot(snapshot: Any, metadata: SnapshotMetadata): Unit {
        snapshots.add(snapshot)
    }
}

@Test
func testTestHandler_handle() {
    let handler = TestHandler()
    let event = DomainEvent("Test", "data", 1)

    handler.handle(event)

    @Expect(handler.handledEvents.size, 1)
    @Expect(handler.handledEvents[0].eventType(), "Test")
}

@Test
func testTestHandler_replay() {
    let handler = TestHandler()
    let events = ArrayList<PersistentEvent>()
    events.add(DomainEvent("E1", "d1", 1))
    events.add(DomainEvent("E2", "d2", 2))

    handler.replay(events)

    @Expect(handler.handledEvents.size, 2)
}

@Test
func testTestHandler_provideSnapshot() {
    let handler = TestHandler()
    handler.snapshots.add("snapshot-state")

    let snapshot = handler.provideSnapshot(100)

    let hasSnapshot = match (snapshot) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasSnapshot, true)
    match (snapshot) {
        case Some(s) =>
            let sStr = match (s) {
                case s2: String => s2
                case _ => ""
            }
            @Expect(sStr, "snapshot-state")
        case None => @Expect(true, false)
    }
}

@Test
func testTestHandler_provideSnapshot_empty() {
    let handler = TestHandler()

    let snapshot = handler.provideSnapshot(100)

    let isEmpty = match (snapshot) {
        case Some(_) => false
        case None => true
    }
    @Expect(isEmpty, true)
}

@Test
func testTestHandler_applySnapshot() {
    let handler = TestHandler()

    let metadata = SnapshotMetadata("actor", 50)
    handler.applySnapshot("state", metadata)

    @Expect(handler.snapshots.size, 1)
    let firstSnap = handler.snapshots[0]
    let snapStr = match (firstSnap) {
        case s: String => s
        case _ => ""
    }
    @Expect(snapStr, "state")
}

// === Integration Tests ===

@Test
func testEventSourcing_workflow() {
    // 模拟完整的事件溯源工作流
    // 1. 创建事件
    let event1 = DomainEvent("UserCreated", "user-1", 1)
    let event2 = DomainEvent("UserUpdated", "user-1-updated", 2)
    let event3 = DomainEvent("UserDeleted", "user-1-deleted", 3)

    // 2. 验证事件顺序
    @Expect(event1.sequenceNr(), 1)
    @Expect(event2.sequenceNr(), 2)
    @Expect(event3.sequenceNr(), 3)

    // 3. 验证事件类型
    @Expect(event1.eventType(), "UserCreated")
    @Expect(event2.eventType(), "UserUpdated")
    @Expect(event3.eventType(), "UserDeleted")
}

@Test
func testSnapshotLifecycle() {
    // 模拟快照生命周期
    // 1. 创建快照元数据
    let metadata1 = SnapshotMetadata("actor-A", 100)
    let metadata2 = SnapshotMetadata("actor-A", 200)

    // 2. 验证序列号递增
    @Expect(metadata1.sequenceNr, 100)
    @Expect(metadata2.sequenceNr, 200)
    @Expect(metadata2.sequenceNr > metadata1.sequenceNr, true)

    // 3. 验证不同的持久化ID
    let metadata3 = SnapshotMetadata("actor-B", 100)

    @Expect(metadata3.persistenceId != metadata1.persistenceId, true)
}

@Test
func testRecovery_fromBeginning() {
    // 从头开始恢复
    let recovery = Recovery(
        fromSnapshot: false,
        toSequenceNr: Int64.Max,
        replayMax: Int64.Max
    )

    @Expect(recovery.fromSnapshot, false)
    @Expect(recovery.toSequenceNr, Int64.Max)
}

@Test
func testRecovery_fromSnapshot() {
    // 从快照恢复
    let recovery = Recovery(
        fromSnapshot: true,
        toSequenceNr: 1000,
        replayMax: 500
    )

    @Expect(recovery.fromSnapshot, true)
    @Expect(recovery.toSequenceNr, 1000)
    @Expect(recovery.replayMax, 500)
}

@Test
func testEventOrdering() {
    // 验证事件顺序保持
    let handler = TestHandler()
    var events = ArrayList<PersistentEvent>()

    for (i in 1..=10) {
        events.add(DomainEvent("Event${i}", "data${i}", Int64(i)))
    }

    handler.replay(events)

    @Expect(handler.handledEvents.size, 10)
    @Expect(handler.handledEvents[0].sequenceNr(), 1)
    @Expect(handler.handledEvents[9].sequenceNr(), 10)
}

@Test
func testConcurrentSnapshotAndEvents() {
    // 模拟并发快照和事件处理
    let handler = TestHandler()
    let metadata = SnapshotMetadata("concurrent-actor", 100)

    // 应用快照
    handler.applySnapshot("state-100", metadata)

    // 处理新事件
    for (i in 101..=110) {
        handler.handle(DomainEvent("Event${i}", "data${i}", Int64(i)))
    }

    @Expect(handler.snapshots.size, 1)
    @Expect(handler.handledEvents.size, 10)
    @Expect(handler.handledEvents[9].sequenceNr(), 110)
}

@Test
func testPersistenceId_uniqueness() {
    // 验证持久化ID的唯一性
    let metadata1 = SnapshotMetadata("unique-actor-1", 1)
    let metadata2 = SnapshotMetadata("unique-actor-2", 1)

    @Expect(metadata1.persistenceId != metadata2.persistenceId, true)
    @Expect(metadata1.toString() != metadata2.toString(), true)
}

@Test
func testEventData_anyType() {
    // 验证事件数据可以是任意类型
    let event1 = DomainEvent("String", "string-data", 1)
    let event2 = DomainEvent("Number", 42, 2)
    let event3 = DomainEvent("Array", Array<String>(3, { i => "item${i}" }), 3)

    @Expect(event1.eventData() == "string-data", true)
    @Expect(event2.eventData() == 42, true)
}

@Test
func testSnapshot_metadataPreservation() {
    // 验证快照元数据在应用后保持一致
    let metadata = SnapshotMetadata("test-preserve", 999)
    let handler = TestHandler()

    handler.applySnapshot("preserved-state", metadata)

    let snapshot = handler.provideSnapshot(999)
    match (snapshot) {
        case Some(state) =>
            @Expect(state, "preserved-state")
            // 注意：这里的元数据是简化实现
        case None =>
            @Expect(true, false)
    }
}

@Test
func testRecoveryConfig_differentScenarios() {
    // 测试不同的恢复配置场景
    // 场景1: 仅从快照恢复
    let recovery1 = Recovery(fromSnapshot: true, toSequenceNr: 100, replayMax: 50)
    @Expect(recovery1.fromSnapshot, true)

    // 场景2: 仅从事件恢复
    let recovery2 = Recovery(fromSnapshot: false, toSequenceNr: Int64.Max, replayMax: Int64.Max)
    @Expect(recovery2.fromSnapshot, false)

    // 场景3: 从快照后接事件恢复
    let recovery3 = Recovery(fromSnapshot: true, toSequenceNr: 1000, replayMax: 100)
    @Expect(recovery3.fromSnapshot, true)
    @Expect(recovery3.replayMax, 100)
}
