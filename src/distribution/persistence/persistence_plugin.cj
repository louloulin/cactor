package cactor.distribution.persistence

import cactor.core.actor.*
import cactor.core.message.*
import std.collection.*
import std.time.*
import std.sync.*

// 持久化配置
public class PersistenceConfig {
    private let enabled: Bool
    private let eventStoreType: String
    private let snapshotStoreType: String
    private let eventStorePath: String
    private let snapshotStorePath: String
    private let snapshotInterval: Int64
    private let autoRecover: Bool
    
    public init(
        enabled: Bool,
        eventStoreType: String,
        snapshotStoreType: String,
        eventStorePath: String,
        snapshotStorePath: String,
        snapshotInterval: Int64,
        autoRecover: Bool
    ) {
        this.enabled = enabled
        this.eventStoreType = eventStoreType
        this.snapshotStoreType = snapshotStoreType
        this.eventStorePath = eventStorePath
        this.snapshotStorePath = snapshotStorePath
        this.snapshotInterval = snapshotInterval
        this.autoRecover = autoRecover
    }
    
    public func isEnabled(): Bool { enabled }
    public func getEventStoreType(): String { eventStoreType }
    public func getSnapshotStoreType(): String { snapshotStoreType }
    public func getEventStorePath(): String { eventStorePath }
    public func getSnapshotStorePath(): String { snapshotStorePath }
    public func getSnapshotInterval(): Int64 { snapshotInterval }
    public func isAutoRecover(): Bool { autoRecover }
    
    // 工厂方法
    public static func createDefault(): PersistenceConfig {
        PersistenceConfig(false, "memory", "memory", "./data/events", "./data/snapshots", 100, true)
    }
    
    public static func createEnabled(eventStoreType: String, snapshotStoreType: String): PersistenceConfig {
        PersistenceConfig(true, eventStoreType, snapshotStoreType, "./data/events", "./data/snapshots", 100, true)
    }
}

// 持久化插件接口
public interface PersistencePlugin {
    func isEnabled(): Bool
    func persistEvent(actorName: String, eventType: String, eventData: String): Unit
    func recoverActor(actorName: String, onEvent: (Event) -> Unit, onSnapshot: (Snapshot) -> Unit): Unit
    func takeSnapshot(actorName: String, stateData: String): Unit
    func deleteData(actorName: String): Unit
    func close(): Unit
}

// 默认持久化插件实现
public class DefaultPersistencePlugin <: PersistencePlugin {
    private let config: PersistenceConfig
    private let eventStore: EventStore
    private let snapshotStore: SnapshotStore
    private let sequenceNumbers: HashMap<String, Int64>
    private let mutex: Mutex
    
    public init(config: PersistenceConfig) {
        this.config = config
        this.eventStore = if (config.isEnabled()) {
            match (config.getEventStoreType()) {
                case "file" => EventStoreFactory.createFileStore(config.getEventStorePath())
                case _ => EventStoreFactory.createMemoryStore()
            }
        } else {
            EventStoreFactory.createMemoryStore()
        }
        this.snapshotStore = if (config.isEnabled()) {
            match (config.getSnapshotStoreType()) {
                case "file" => SnapshotStoreFactory.createFileStore(config.getSnapshotStorePath())
                case _ => SnapshotStoreFactory.createMemoryStore()
            }
        } else {
            SnapshotStoreFactory.createMemoryStore()
        }
        this.sequenceNumbers = HashMap<String, Int64>()
        this.mutex = Mutex()
    }
    
    public func isEnabled(): Bool {
        config.isEnabled()
    }
    
    public func persistEvent(actorName: String, eventType: String, eventData: String): Unit {
        if (!config.isEnabled()) {
            return
        }
        
        mutex.lock()
        try {
            let currentSeq = match (sequenceNumbers.get(actorName)) {
                case Some(seq) => seq + 1
                case None => 1
            }
            sequenceNumbers.add(actorName, currentSeq)
            
            let event = BasicEvent("${actorName}_${currentSeq}", actorName, eventType, eventData)
            eventStore.saveEvent(event)
            
            // 检查是否需要快照
            if (currentSeq % config.getSnapshotInterval() == 0) {
                println("${actorName}: 达到快照间隔，序列号=${currentSeq}")
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func recoverActor(actorName: String, onEvent: (Event) -> Unit, onSnapshot: (Snapshot) -> Unit): Unit {
        if (!config.isEnabled() || !config.isAutoRecover()) {
            return
        }
        
        println("${actorName}: 开始恢复...")
        
        // 首先尝试从快照恢复
        match (snapshotStore.getLatestSnapshot(actorName)) {
            case Some(snapshot) => 
                println("${actorName}: 从快照恢复，序列号=${snapshot.getSequenceNumber()}")
                onSnapshot(snapshot)
                
                // 恢复快照之后的事件
                let events = eventStore.getEventsAfter(actorName, snapshot.getTimestamp())
                for (event in events) {
                    onEvent(event)
                }
                
                mutex.lock()
                sequenceNumbers.add(actorName, snapshot.getSequenceNumber())
                mutex.unlock()
                
            case None => 
                println("${actorName}: 从头开始恢复")
                // 恢复所有事件
                let events = eventStore.getEvents(actorName)
                var maxSeq: Int64 = 0
                for (event in events) {
                    onEvent(event)
                    if (maxSeq < 1) {
                        maxSeq = 1
                    }
                }
                
                mutex.lock()
                sequenceNumbers.add(actorName, maxSeq)
                mutex.unlock()
        }
        
        println("${actorName}: 恢复完成")
    }
    
    public func takeSnapshot(actorName: String, stateData: String): Unit {
        if (!config.isEnabled()) {
            return
        }
        
        mutex.lock()
        let currentSeq = match (sequenceNumbers.get(actorName)) {
            case Some(seq) => seq
            case None => 0
        }
        mutex.unlock()
        
        let snapshot = BasicSnapshot(actorName, currentSeq, stateData)
        snapshotStore.saveSnapshot(snapshot)
        
        println("${actorName}: 快照已保存，序列号=${currentSeq}")
    }
    
    public func deleteData(actorName: String): Unit {
        eventStore.deleteEvents(actorName)
        snapshotStore.deleteSnapshots(actorName)
        
        mutex.lock()
        sequenceNumbers.remove(actorName)
        mutex.unlock()
        
        println("${actorName}: 持久化数据已清理")
    }
    
    public func close(): Unit {
        eventStore.close()
        snapshotStore.close()
    }
}

// 持久化插件工厂
public class PersistencePluginFactory {
    public static func create(config: PersistenceConfig): PersistencePlugin {
        DefaultPersistencePlugin(config)
    }
    
    public static func createDisabled(): PersistencePlugin {
        DefaultPersistencePlugin(PersistenceConfig.createDefault())
    }
    
    public static func createMemoryEnabled(): PersistencePlugin {
        DefaultPersistencePlugin(PersistenceConfig.createEnabled("memory", "memory"))
    }
    
    public static func createFileEnabled(): PersistencePlugin {
        DefaultPersistencePlugin(PersistenceConfig.createEnabled("file", "file"))
    }
}

// 持久化消息类型
public class PersistEventMessage <: Message {
    private let eventType: String
    private let eventData: String
    
    public init(eventType: String, eventData: String) {
        this.eventType = eventType
        this.eventData = eventData
    }
    
    public func getEventType(): String { eventType }
    public func getEventData(): String { eventData }
    public func messageType(): String { "PersistEventMessage" }

    public func toString(): String {
        "PersistEventMessage(${eventType}, ${eventData})"
    }
}

public class TakeSnapshotMessage <: Message {
    private let stateData: String
    
    public init(stateData: String) {
        this.stateData = stateData
    }
    
    public func getStateData(): String { stateData }
    public func messageType(): String { "TakeSnapshotMessage" }

    public func toString(): String {
        "TakeSnapshotMessage"
    }
}

public class RecoveryCompleteMessage <: Message {
    public init() {}

    public func messageType(): String { "RecoveryCompleteMessage" }

    public func toString(): String {
        "RecoveryCompleteMessage"
    }
}
