/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - PersistenceFSM 接口定义
 * 为 PersistenceFSM 提供所需的持久化接口
 */
package cactor.distribution.persistence

import std.collection.*

/**
 * 持久化 Journal 接口 - 对标 Akka Persistence Journal
 */
public interface PersistenceJournal {
    /**
     * 追加事件
     */
    func append(persistenceId: String, event: PersistentEvent): Unit

    /**
     * 加载事件
     */
    func loadEvents(persistenceId: String, fromSeq: Int64, toSeq: Int64): ArrayList<PersistentEvent>

    /**
     * 删除事件
     */
    func deleteEvents(persistenceId: String, toSeq: Int64): Unit

    /**
     * 持久化确认
     */
    func persistConfirm(persistenceId: String, sequenceNr: Int64): Unit
}

/**
 * 持久化快照存储接口 - 对标 Akka Snapshot Store
 */
public interface PersistenceSnapshotStore {
    /**
     * 保存快照
     */
    func save(metadata: SnapshotMetadata, snapshot: Any): Unit

    /**
     * 加载最新快照
     */
    func loadLatest(persistenceId: String): Option<Any>

    /**
     * 加载指定序列号的快照
     */
    func load(persistenceId: String, sequenceNr: Int64): Option<Any>

    /**
     * 删除快照
     */
    func delete(persistenceId: String, sequenceNr: Int64): Unit

    /**
     * 删除旧快照
     */
    func deleteBefore(persistenceId: String, sequenceNr: Int64): Unit
}

/**
 * 状态机状态基类
 */
public class BaseState {
    private let nameVal: String

    public init(name: String) {
        this.nameVal = name
    }

    public func stateName(): String { nameVal }
}

/**
 * 状态机数据基类
 */
public class BaseStateData {
    private let defined: Bool

    public init() {
        this.defined = true
    }

    public func isDefined(): Bool { defined }
}

/**
 * 状态机事件基类
 */
public class BaseFSMEvent {
    private let nameVal: String

    public init(name: String) {
        this.nameVal = name
    }

    public func eventName(): String { nameVal }
}

/**
 * PersistenceFSM 配置
 */
public class PersistenceFSMConfig {
    public let journalPluginId: String
    public let snapshotPluginId: String
    public let journalInterval: Int64
    public let snapshotInterval: Int64

    public init(
        journalPluginId!: String = "journal",
        snapshotPluginId!: String = "snapshot",
        journalInterval!: Int64 = 100,
        snapshotInterval!: Int64 = 1000
    ) {
        this.journalPluginId = journalPluginId
        this.snapshotPluginId = snapshotPluginId
        this.journalInterval = journalInterval
        this.snapshotInterval = snapshotInterval
    }

    public static func getDefault(): PersistenceFSMConfig {
        PersistenceFSMConfig()
    }
}