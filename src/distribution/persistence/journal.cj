/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Journal 和 Snapshot Store 实现
 * 对标 Akka Persistence Journal 和 Snapshot Store
 */
package cactor.distribution.persistence

import std.collection.*
import std.sync.*
import std.time.*

/**
 * Journal 接口 - 对标 Akka Persistence Journal
 */
public interface Journal {
    /**
     * 写入事件
     */
    func write(persistenceId: String, event: PersistentEvent): Unit

    /**
     * 批量写入事件
     */
    func writeBatch(persistenceId: String, events: Array<PersistentEvent>): Unit

    /**
     * 读取事件
     * @param persistenceId 持久化 ID
     * @param fromSequenceNr 起始序列号
     * @param toSequenceNr 结束序列号
     * @return 事件列表
     */
    func read(persistenceId: String, fromSequenceNr: Int64, toSequenceNr: Int64): ArrayList<PersistentEvent>

    /**
     * 删除事件
     */
    func delete(persistenceId: String, toSequenceNr: Int64): Unit

    /**
     * 获取最高序列号
     */
    func highestSequenceNr(persistenceId: String): Int64

    /**
     * 检查持久化 ID 是否存在
     */
    func exists(persistenceId: String): Bool
}

/**
 * Journal 配置
 */
public struct JournalConfig {
    public let pluginId: String
    public let maxBatchSize: Int64
    public let replayMax: Int64
    public let circuitBreakerOpen: Duration

    public init(
        pluginId!: String = "journal.default",
        maxBatchSize!: Int64 = 100,
        replayMax!: Int64 = 10000,
        circuitBreakerOpen!: Duration = Duration.second * 10
    ) {
        this.pluginId = pluginId
        this.maxBatchSize = maxBatchSize
        this.replayMax = replayMax
        this.circuitBreakerOpen = circuitBreakerOpen
    }
}

/**
 * 内存 Journal 实现
 */
public class InMemoryJournal <: Journal {
    private let entries: HashMap<String, ArrayList<JournalEntry>>
    private let mutex: ReentrantMutex

    public init() {
        this.entries = HashMap<String, ArrayList<JournalEntry>>()
        this.mutex = ReentrantMutex()
    }

    public func write(persistenceId: String, event: PersistentEvent): Unit {
        mutex.lock()
        let entry = JournalEntry(persistenceId, event)
        match (entries.get(persistenceId)) {
            case Some(list) =>
                list.add(entry)
            case None =>
                let list = ArrayList<JournalEntry>()
                list.add(entry)
                entries.add(persistenceId, list)
        }
        mutex.unlock()
    }

    public func writeBatch(persistenceId: String, events: Array<PersistentEvent>): Unit {
        mutex.lock()
        let list = match (entries.get(persistenceId)) {
            case Some(l) => l
            case None =>
                let newList = ArrayList<JournalEntry>()
                entries.add(persistenceId, newList)
                newList
        }
        for (event in events) {
            list.add(JournalEntry(persistenceId, event))
        }
        mutex.unlock()
    }

    public func read(persistenceId: String, fromSequenceNr: Int64, toSequenceNr: Int64): ArrayList<PersistentEvent> {
        mutex.lock()
        let result = ArrayList<PersistentEvent>()
        match (entries.get(persistenceId)) {
            case Some(list) =>
                for (entry in list) {
                    let seqNr = entry.event.sequenceNr()
                    if (seqNr >= fromSequenceNr && seqNr <= toSequenceNr) {
                        result.add(entry.event)
                    }
                }
            case None => ()
        }
        mutex.unlock()
        result
    }

    public func delete(persistenceId: String, toSequenceNr: Int64): Unit {
        mutex.lock()
        match (entries.get(persistenceId)) {
            case Some(list) =>
                let filtered = ArrayList<JournalEntry>()
                for (entry in list) {
                    if (entry.event.sequenceNr() > toSequenceNr) {
                        filtered.add(entry)
                    }
                }
                entries.add(persistenceId, filtered)
            case None => ()
        }
        mutex.unlock()
    }

    public func highestSequenceNr(persistenceId: String): Int64 {
        mutex.lock()
        var maxSeq: Int64 = 0
        match (entries.get(persistenceId)) {
            case Some(list) =>
                for (entry in list) {
                    if (entry.event.sequenceNr() > maxSeq) {
                        maxSeq = entry.event.sequenceNr()
                    }
                }
            case None => ()
        }
        mutex.unlock()
        maxSeq
    }

    public func exists(persistenceId: String): Bool {
        mutex.lock()
        let exists = entries.contains(persistenceId)
        mutex.unlock()
        exists
    }
}

/**
 * Journal 条目
 */
public class JournalEntry {
    public let persistenceId: String
    public let event: PersistentEvent
    public let timestamp: Int64

    public init(persistenceId: String, event: PersistentEvent) {
        this.persistenceId = persistenceId
        this.event = event
        this.timestamp = DateTime.now().toUnixTimeStamp().toSeconds()
    }
}

/**
 * Snapshot Store 接口 - 对标 Akka Snapshot Store
 */
public interface SnapshotStore {
    /**
     * 保存快照
     */
    func save(metadata: SnapshotMetadata, snapshot: Any): Unit

    /**
     * 加载最新快照
     */
    func loadLatest(persistenceId: String): Option<(SnapshotMetadata, Any)>

    /**
     * 加载指定快照
     */
    func load(persistenceId: String, sequenceNr: Int64): Option<(SnapshotMetadata, Any)>

    /**
     * 删除快照
     */
    func delete(metadata: SnapshotMetadata): Unit

    /**
     * 删除指定序列号之前的快照
     */
    func deleteUpTo(maxSequenceNr: Int64): Unit

    /**
     * 删除指定持久化 ID 的所有快照
     */
    func deleteAll(persistenceId: String): Unit

    /**
     * 列出快照
     */
    func list(persistenceId: String): ArrayList<SnapshotMetadata>
}

/**
 * Snapshot Store 配置
 */
public struct SnapshotStoreConfig {
    public let pluginId: String
    public let snapshotFormatVersion: Int32
    public let flushInterval: Duration

    public init(
        pluginId!: String = "snapshot.default",
        snapshotFormatVersion!: Int32 = 1,
        flushInterval!: Duration = Duration.second * 1
    ) {
        this.pluginId = pluginId
        this.snapshotFormatVersion = snapshotFormatVersion
        this.flushInterval = flushInterval
    }
}

/**
 * 内存 Snapshot Store 实现
 */
public class InMemorySnapshotStore <: SnapshotStore {
    private let snapshots: HashMap<String, ArrayList<SnapshotEntry>>
    private let mutex: ReentrantMutex

    public init() {
        this.snapshots = HashMap<String, ArrayList<SnapshotEntry>>()
        this.mutex = ReentrantMutex()
    }

    public func save(metadata: SnapshotMetadata, snapshot: Any): Unit {
        mutex.lock()
        let entry = SnapshotEntry(metadata, snapshot)
        match (snapshots.get(metadata.persistenceId)) {
            case Some(list) =>
                list.add(entry)
            case None =>
                let list = ArrayList<SnapshotEntry>()
                list.add(entry)
                snapshots.add(metadata.persistenceId, list)
        }
        mutex.unlock()
        println("快照已保存: ${metadata.toString()}")
    }

    public func loadLatest(persistenceId: String): Option<(SnapshotMetadata, Any)> {
        mutex.lock()
        let result = match (snapshots.get(persistenceId)) {
            case Some(list) =>
                if (list.size > 0) {
                    var latest: Option<SnapshotEntry> = None
                    var maxSeq: Int64 = -1
                    for (entry in list) {
                        if (entry.metadata.sequenceNr > maxSeq) {
                            maxSeq = entry.metadata.sequenceNr
                            latest = Some(entry)
                        }
                    }
                    match (latest) {
                        case Some(e) => Some((e.metadata, e.snapshot))
                        case None => None<(SnapshotMetadata, Any)>
                    }
                } else {
                    None<(SnapshotMetadata, Any)>
                }
            case None => None<(SnapshotMetadata, Any)>
        }
        mutex.unlock()
        result
    }

    public func load(persistenceId: String, sequenceNr: Int64): Option<(SnapshotMetadata, Any)> {
        mutex.lock()
        let result = match (snapshots.get(persistenceId)) {
            case Some(list) =>
                for (entry in list) {
                    if (entry.metadata.sequenceNr == sequenceNr) {
                        mutex.unlock()
                        return Some((entry.metadata, entry.snapshot))
                    }
                }
                None<(SnapshotMetadata, Any)>
            case None => None<(SnapshotMetadata, Any)>
        }
        mutex.unlock()
        result
    }

    public func delete(metadata: SnapshotMetadata): Unit {
        mutex.lock()
        match (snapshots.get(metadata.persistenceId)) {
            case Some(list) =>
                let filtered = ArrayList<SnapshotEntry>()
                for (entry in list) {
                    if (entry.metadata.sequenceNr != metadata.sequenceNr) {
                        filtered.add(entry)
                    }
                }
                snapshots.add(metadata.persistenceId, filtered)
            case None => ()
        }
        mutex.unlock()
        println("快照已删除: ${metadata.toString()}")
    }

    public func deleteUpTo(maxSequenceNr: Int64): Unit {
        mutex.lock()
        for ((persistenceId, list) in snapshots) {
            let filtered = ArrayList<SnapshotEntry>()
            for (entry in list) {
                if (entry.metadata.sequenceNr > maxSequenceNr) {
                    filtered.add(entry)
                }
            }
            snapshots.add(persistenceId, filtered)
        }
        mutex.unlock()
        println("旧快照已删除到序列号: ${maxSequenceNr}")
    }

    public func deleteAll(persistenceId: String): Unit {
        mutex.lock()
        snapshots.remove(persistenceId)
        mutex.unlock()
        println("所有快照已删除: ${persistenceId}")
    }

    public func list(persistenceId: String): ArrayList<SnapshotMetadata> {
        mutex.lock()
        let result = ArrayList<SnapshotMetadata>()
        match (snapshots.get(persistenceId)) {
            case Some(list) =>
                for (entry in list) {
                    result.add(entry.metadata)
                }
            case None => ()
        }
        mutex.unlock()
        result
    }
}

/**
 * 快照条目
 */
public class SnapshotEntry {
    public let metadata: SnapshotMetadata
    public let snapshot: Any

    public init(metadata: SnapshotMetadata, snapshot: Any) {
        this.metadata = metadata
        this.snapshot = snapshot
    }
}

/**
 * Persistence 插件
 */
public interface PersistencePlugin {
    /**
     * 获取插件 ID
     */
    func getPluginId(): String

    /**
     * 获取 Journal
     */
    func journal(): Journal

    /**
     * 获取 Snapshot Store
     */
    func snapshotStore(): SnapshotStore
}

/**
 * 默认 Persistence 插件
 */
public class DefaultPersistencePlugin <: PersistencePlugin {
    private let pluginIdValue: String
    private let journalInstance: InMemoryJournal
    private let snapshotStoreInstance: InMemorySnapshotStore

    public init(pluginId!: String = "persistence.default") {
        this.pluginIdValue = pluginId
        this.journalInstance = InMemoryJournal()
        this.snapshotStoreInstance = InMemorySnapshotStore()
    }

    public func getPluginId(): String {
        pluginIdValue
    }

    public func journal(): Journal {
        journalInstance
    }

    public func snapshotStore(): SnapshotStore {
        snapshotStoreInstance
    }
}

/**
 * Persistence 系统
 */
public class PersistenceSystem {
    private let plugins: HashMap<String, PersistencePlugin>
    private let defaultPlugin: PersistencePlugin
    private let mutex: ReentrantMutex

    public init() {
        this.plugins = HashMap<String, PersistencePlugin>()
        this.defaultPlugin = DefaultPersistencePlugin()
        this.mutex = ReentrantMutex()
        registerPlugin(defaultPlugin)
    }

    /**
     * 注册插件
     */
    public func registerPlugin(plugin: PersistencePlugin): Unit {
        mutex.lock()
        plugins.add(plugin.getPluginId(), plugin)
        mutex.unlock()
    }

    /**
     * 获取 Journal
     */
    public func journal(pluginId!: String = "persistence.default"): Journal {
        mutex.lock()
        let plugin = match (plugins.get(pluginId)) {
            case Some(p) => p
            case None => defaultPlugin
        }
        mutex.unlock()
        plugin.journal()
    }

    /**
     * 获取 Snapshot Store
     */
    public func snapshotStore(pluginId!: String = "persistence.default"): SnapshotStore {
        mutex.lock()
        let plugin = match (plugins.get(pluginId)) {
            case Some(p) => p
            case None => defaultPlugin
        }
        mutex.unlock()
        plugin.snapshotStore()
    }

    /**
     * 创建持久化 Actor
     */
    public func createPersistentActor(persistenceId: String, pluginId!: String = "persistence.default"): SimplePersistentActor {
        let j = journal(pluginId: pluginId)
        let s = snapshotStore(pluginId: pluginId)
        SimplePersistentActor(persistenceId, j, s)
    }
}

/**
 * 全局 Persistence 系统实例
 */
public class GlobalPersistenceSystem {
    private static var instance: Option<PersistenceSystem> = None
    private static let mutex: ReentrantMutex = ReentrantMutex()

    public static func getInstance(): PersistenceSystem {
        mutex.lock()
        let result = match (instance) {
            case Some(system) => system
            case None =>
                let system = PersistenceSystem()
                instance = Some(system)
                system
        }
        mutex.unlock()
        result
    }

    public static func reset(): Unit {
        mutex.lock()
        instance = None
        mutex.unlock()
    }
}

/**
 * Persistence 查询接口 - 对标 Akka PersistenceQuery
 */
public interface PersistenceQuery {
    /**
     * 获取指定持久化 ID 的当前状态
     */
    func currentPersistenceIds(): ArrayList<String>

    /**
     * 获取指定持久化 ID 的当前事件
     */
    func currentEvents(persistenceId: String): ArrayList<PersistentEvent>
}

/**
 * 简单 Persistence Query 实现
 */
public class SimplePersistenceQuery <: PersistenceQuery {
    private let journalInstance: Journal

    public init(journalInstance: Journal) {
        this.journalInstance = journalInstance
    }

    public func currentPersistenceIds(): ArrayList<String> {
        ArrayList<String>()
    }

    public func currentEvents(persistenceId: String): ArrayList<PersistentEvent> {
        journalInstance.read(persistenceId, 0, Int64.Max)
    }
}
