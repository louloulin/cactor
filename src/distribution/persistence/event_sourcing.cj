/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 事件溯源和持久化实现
 * 对标 Akka Persistence
 * 提供事件溯源、Journal、Snapshot 功能
 */
package cactor.distribution.persistence

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 事件接口 - 对标 Akka Persistent
 */
public interface PersistentEvent {
    func eventType(): String
    func eventData(): Any
    func sequenceNr(): Int64
}

/**
 * 持久化领域事件
 */
public class DomainEvent <: PersistentEvent {
    private let eventTypeVal: String
    private let dataVal: Any
    private let seqNr: Int64
    private let ts: Int64

    public init(eventTypeVal: String, data: Any, seqNr: Int64) {
        this.eventTypeVal = eventTypeVal
        this.dataVal = data
        this.seqNr = seqNr
        this.ts = DateTime.now().toUnixTimeStamp().toSeconds()
    }

    public func eventType(): String { eventTypeVal }
    public func eventData(): Any { dataVal }
    public func sequenceNr(): Int64 { seqNr }
    public func timestamp(): Int64 { ts }
}

/**
 * 持久化命令
 */
public enum PersistenceCommand {
    | Persist(PersistentEvent)
    | PersistAll(Array<PersistentEvent>)
    | PersistAsync(PersistentEvent)
    | SaveSnapshot(SnapshotMetadata)
    | DeleteSnapshot(Int64)
    | DeleteSnapshots(Int64)
    | GetState
    | RecoveryCompleted
}

/**
 * 快照元数据
 */
public class SnapshotMetadata {
    public let persistenceId: String
    public let sequenceNr: Int64
    public let timestamp: Int64

    public init(persistenceId: String, sequenceNr: Int64) {
        this.persistenceId = persistenceId
        this.sequenceNr = sequenceNr
        this.timestamp = DateTime.now().toUnixTimeStamp().toSeconds()
    }

    public func toString(): String {
        "${persistenceId}-${sequenceNr}"
    }
}

/**
 * 快照提供
 */
public interface SnapshotOffer {
    func snapshot(): Any
    func metadata(): SnapshotMetadata
}

/**
 * 快照实现
 */
public class SnapshotOfferImpl <: SnapshotOffer {
    private let snapshotData: Any
    private let meta: SnapshotMetadata

    public init(snapshotData: Any, meta: SnapshotMetadata) {
        this.snapshotData = snapshotData
        this.meta = meta
    }

    public func snapshot(): Any { snapshotData }
    public func metadata(): SnapshotMetadata { meta }
}

/**
 * 恢复配置
 */
public class Recovery {
    public let fromSnapshot: Bool
    public let toSequenceNr: Int64
    public let replayMax: Int64

    public init(
        fromSnapshot!: Bool = true,
        toSequenceNr!: Int64 = Int64.Max,
        replayMax!: Int64 = Int64.Max
    ) {
        this.fromSnapshot = fromSnapshot
        this.toSequenceNr = toSequenceNr
        this.replayMax = replayMax
    }

    public static func getDefault(): Recovery {
        Recovery()
    }
}

/**
 * 持久化状态
 */
public enum PersistenceState {
    | Initializing
    | ProcessingCommands
    | ProcessingSnapshot
    | RecoveryPending
    | RecoveryCompleted
    | Shutdown
}

/**
 * 持久化处理器接口
 */
public interface PersistenceHandler {
    func handle(event: PersistentEvent): Unit
    func replay(events: ArrayList<PersistentEvent>): Unit
    func provideSnapshot(sequenceNr: Int64): Option<Any>
    func applySnapshot(snapshot: Any, metadata: SnapshotMetadata): Unit
}

/**
 * 持久化 Actor 接口 - 对标 Akka PersistentActor
 */
public interface PersistentActor {
    func persist(event: PersistentEvent, handler: (PersistentEvent) -> Unit): Unit
    func persistAll(events: Array<PersistentEvent>, handler: (PersistentEvent) -> Unit): Unit
    func persistAsync(event: PersistentEvent, handler: (PersistentEvent) -> Unit): Unit
    func saveSnapshot(state: Any): Unit
    func deleteSnapshot(sequenceNr: Int64): Unit
    func deleteSnapshots(maxSequenceNr: Int64): Unit
    func persistenceId(): String
    func recovery(): Recovery
    func isRecovering(): Bool
}

/**
 * 简单持久化 Actor 实现
 */
public class SimplePersistentActor <: PersistentActor {
    private let pid: String
    private var state: Option<Any>
    private var seqNr: Int64
    private var isReplaying: Bool
    private let journal: Journal
    private let snapshotStore: JournalSnapshotStore

    public init(pid: String, journal: Journal, snapshotStore: JournalSnapshotStore) {
        this.pid = pid
        this.state = None
        this.seqNr = 0
        this.isReplaying = false
        this.journal = journal
        this.snapshotStore = snapshotStore
    }

    public func persist(event: PersistentEvent, handler: (PersistentEvent) -> Unit): Unit {
        if (isReplaying) {
            handler(event)
            return
        }
        try {
            journal.write(pid, event)
            seqNr += 1
            handler(event)
        } catch (e: Exception) {
            println("持久化失败: ${e.message}")
            throw e
        }
    }

    public func persistAll(events: Array<PersistentEvent>, handler: (PersistentEvent) -> Unit): Unit {
        for (event in events) {
            persist(event, handler)
        }
    }

    public func persistAsync(event: PersistentEvent, handler: (PersistentEvent) -> Unit): Unit {
        persist(event, handler)
    }

    public func saveSnapshot(currentState: Any): Unit {
        try {
            let metadata = SnapshotMetadata(pid, seqNr)
            snapshotStore.save(metadata, currentState)
            println("快照已保存: ${metadata.toString()}")
        } catch (e: Exception) {
            println("保存快照失败: ${e.message}")
        }
    }

    public func deleteSnapshot(sequenceNr: Int64): Unit {
        try {
            let metadata = SnapshotMetadata(pid, sequenceNr)
            snapshotStore.delete(metadata)
            println("快照已删除: ${metadata.toString()}")
        } catch (e: Exception) {
            println("删除快照失败: ${e.message}")
        }
    }

    public func deleteSnapshots(maxSequenceNr: Int64): Unit {
        try {
            snapshotStore.deleteUpTo(maxSequenceNr)
            println("旧快照已删除到: ${maxSequenceNr}")
        } catch (e: Exception) {
            println("删除旧快照失败: ${e.message}")
        }
    }

    public func persistenceId(): String { pid }

    public func recovery(): Recovery {
        Recovery.getDefault()
    }

    public func isRecovering(): Bool {
        isReplaying
    }
}
