package cactor.distribution.persistence

import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import std.collection.*
import std.time.*
import std.sync.*

// 持久化Actor管理器
public class PersistentActorManager {
    private let persistencePlugin: PersistencePlugin
    private let actors: HashMap<String, Actor>
    private let mutex: ReentrantMutex
    
    public init(persistencePlugin: PersistencePlugin) {
        this.persistencePlugin = persistencePlugin
        this.actors = HashMap<String, Actor>()
        this.mutex = ReentrantMutex()
    }
    
    // 注册Actor进行持久化管理
    public func registerActor(actor: Actor): Unit {
        mutex.lock()
        try {
            actors.put(actor.name, actor)
            if (persistencePlugin.isEnabled()) {
                startRecovery(actor)
            }
        } finally {
            mutex.unlock()
        }
    }
    
    // 持久化事件
    public func persistEvent(actorName: String, eventType: String, eventData: String): Unit {
        if (persistencePlugin.isEnabled()) {
            persistencePlugin.persistEvent(actorName, eventType, eventData)
        }
    }
    
    // 创建快照
    public func takeSnapshot(actorName: String, stateData: String): Unit {
        if (persistencePlugin.isEnabled()) {
            persistencePlugin.takeSnapshot(actorName, stateData)
        }
    }
    
    // 开始恢复过程
    private func startRecovery(actor: Actor): Unit {
        println("${actor.name}: 开始持久化恢复...")
        
        persistencePlugin.recoverActor(
            actor.name,
            { event => handleRecoveryEvent(actor, event) },
            { snapshot => handleRecoverySnapshot(actor, snapshot) }
        )
        
        println("${actor.name}: 恢复完成")
    }
    
    private func handleRecoveryEvent(actor: Actor, event: Event): Unit {
        println("${actor.name}: 恢复事件 ${event.getEventType()}: ${event.getEventData()}")
        // 这里可以根据事件类型重放状态变化
        // 简化实现：只打印事件信息
    }
    
    private func handleRecoverySnapshot(actor: Actor, snapshot: Snapshot): Unit {
        println("${actor.name}: 恢复快照，序列号=${snapshot.getSequenceNumber()}")
        // 这里可以恢复Actor状态
        // 简化实现：只打印快照信息
    }
    
    // 清理持久化数据
    public func deletePersistentData(actorName: String): Unit {
        persistencePlugin.deleteData(actorName)
    }
    
    // 关闭管理器
    public func close(): Unit {
        persistencePlugin.close()
    }
}

// 持久化Actor工厂
public class PersistentActorFactory {
    public static func createManager(config: PersistenceConfig): PersistentActorManager {
        let plugin = PersistencePluginFactory.create(config)
        PersistentActorManager(plugin)
    }
    
    public static func createMemoryManager(): PersistentActorManager {
        let plugin = PersistencePluginFactory.createMemoryEnabled()
        PersistentActorManager(plugin)
    }
    
    public static func createFileManager(): PersistentActorManager {
        let plugin = PersistencePluginFactory.createFileEnabled()
        PersistentActorManager(plugin)
    }
    
    public static func createDisabledManager(): PersistentActorManager {
        let plugin = PersistencePluginFactory.createDisabled()
        PersistentActorManager(plugin)
    }
}

// 持久化配置构建器
public class PersistenceConfigBuilder {
    private var enabled: Bool
    private var eventStoreType: String
    private var snapshotStoreType: String
    private var eventStorePath: String
    private var snapshotStorePath: String
    private var snapshotInterval: Int64
    private var autoRecover: Bool
    
    public init() {
        this.enabled = false
        this.eventStoreType = "memory"
        this.snapshotStoreType = "memory"
        this.eventStorePath = "./data/events"
        this.snapshotStorePath = "./data/snapshots"
        this.snapshotInterval = 100
        this.autoRecover = true
    }
    
    public func enable(): PersistenceConfigBuilder {
        this.enabled = true
        this
    }
    
    public func withEventStore(storeType: String, path: String): PersistenceConfigBuilder {
        this.eventStoreType = storeType
        this.eventStorePath = path
        this
    }
    
    public func withSnapshotStore(storeType: String, path: String): PersistenceConfigBuilder {
        this.snapshotStoreType = storeType
        this.snapshotStorePath = path
        this
    }
    
    public func withSnapshotInterval(interval: Int64): PersistenceConfigBuilder {
        this.snapshotInterval = interval
        this
    }
    
    public func withAutoRecover(autoRecover: Bool): PersistenceConfigBuilder {
        this.autoRecover = autoRecover
        this
    }
    
    public func build(): PersistenceConfig {
        PersistenceConfig(
            enabled,
            eventStoreType,
            snapshotStoreType,
            eventStorePath,
            snapshotStorePath,
            snapshotInterval,
            autoRecover
        )
    }
}

// 持久化消息类型已在persistence_plugin.cj中定义
