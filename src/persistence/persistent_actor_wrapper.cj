package cactor.persistence

import cactor.core.actor.*
import cactor.core.message.*
import cactor.runtime.actor.*
import std.collection.*
import std.time.*
import std.sync.*

// 持久化状态接口
public interface PersistentState {
    func serialize(): String
    func deserialize(data: String): Unit
}

// 基础持久化状态实现
public class BasicPersistentState <: PersistentState {
    private var data: HashMap<String, String>
    
    public init() {
        this.data = HashMap<String, String>()
    }
    
    public func put(key: String, value: String): Unit {
        data.put(key, value)
    }
    
    public func get(key: String): Option<String> {
        data.get(key)
    }
    
    public func serialize(): String {
        var result = ""
        for ((key, value) in data) {
            result = "${result}${key}:${value};"
        }
        result
    }
    
    public func deserialize(data: String): Unit {
        this.data.clear()
        if (data.size > 0) {
            let pairs = data.split(';')
            for (pair in pairs) {
                if (pair.size > 0) {
                    let parts = pair.split(':')
                    if (parts.size >= 2) {
                        this.data.put(parts[0], parts[1])
                    }
                }
            }
        }
    }
}

// 持久化Actor包装器
public class PersistentActorWrapper <: SimpleActor {
    private let wrappedActor: SimpleActor
    private let persistencePlugin: PersistencePlugin
    private let persistentState: PersistentState
    private var isRecovering: Bool
    private let mutex: ReentrantMutex
    
    public init(wrappedActor: SimpleActor, persistencePlugin: PersistencePlugin) {
        super(wrappedActor.name)
        this.wrappedActor = wrappedActor
        this.persistencePlugin = persistencePlugin
        this.persistentState = BasicPersistentState()
        this.isRecovering = false
        this.mutex = ReentrantMutex()
    }
    
    public override func receive(message: Message, context: ActorContext): MessageResult {
        mutex.lock()
        let recovering = isRecovering
        mutex.unlock()
        
        if (recovering) {
            // 恢复期间缓存消息
            return MessageResult.Unhandled
        }
        
        match (message) {
            case persistMsg: PersistEventMessage => 
                handlePersistEvent(persistMsg)
                MessageResult.Handled
                
            case snapshotMsg: TakeSnapshotMessage => 
                handleTakeSnapshot(snapshotMsg)
                MessageResult.Handled
                
            case recoveryMsg: RecoveryCompleteMessage => 
                handleRecoveryComplete()
                MessageResult.Handled
                
            case _ => 
                // 处理普通消息前先持久化
                let result = wrappedActor.receive(message, context)
                
                // 如果消息被处理，可以选择持久化事件
                if (result == MessageResult.Handled) {
                    persistMessageEvent(message)
                }
                
                result
        }
    }
    
    private func handlePersistEvent(message: PersistEventMessage): Unit {
        persistencePlugin.persistEvent(name, message.getEventType(), message.getEventData())
    }
    
    private func handleTakeSnapshot(message: TakeSnapshotMessage): Unit {
        persistencePlugin.takeSnapshot(name, message.getStateData())
    }
    
    private func handleRecoveryComplete(): Unit {
        mutex.lock()
        isRecovering = false
        mutex.unlock()
        println("${name}: 恢复完成，开始处理新消息")
    }
    
    private func persistMessageEvent(message: Message): Unit {
        if (persistencePlugin.isEnabled()) {
            let eventType = message.toString().split('(')[0] // 简化的消息类型提取
            let eventData = message.toString()
            persistencePlugin.persistEvent(name, eventType, eventData)
        }
    }
    
    // 开始恢复过程
    public func startRecovery(): Unit {
        if (!persistencePlugin.isEnabled()) {
            return
        }
        
        mutex.lock()
        isRecovering = true
        mutex.unlock()
        
        println("${name}: 开始持久化恢复...")
        
        persistencePlugin.recoverActor(
            name,
            { event => handleRecoveryEvent(event) },
            { snapshot => handleRecoverySnapshot(snapshot) }
        )
        
        // 发送恢复完成消息
        let context = ActorContext("recovery")
        receive(RecoveryCompleteMessage(), context)
    }
    
    private func handleRecoveryEvent(event: Event): Unit {
        println("${name}: 恢复事件 ${event.getEventType()}: ${event.getEventData()}")
        // 这里可以根据事件类型重放状态变化
        // 简化实现：将事件数据存储到持久化状态中
        persistentState.put("event_${event.getEventId()}", event.getEventData())
    }
    
    private func handleRecoverySnapshot(snapshot: Snapshot): Unit {
        println("${name}: 恢复快照，序列号=${snapshot.getSequenceNumber()}")
        persistentState.deserialize(snapshot.getStateData())
    }
    
    // 手动持久化事件
    public func persistEvent(eventType: String, eventData: String): Unit {
        let context = ActorContext("persist")
        receive(PersistEventMessage(eventType, eventData), context)
    }
    
    // 手动创建快照
    public func takeSnapshot(): Unit {
        let stateData = persistentState.serialize()
        let context = ActorContext("snapshot")
        receive(TakeSnapshotMessage(stateData), context)
    }
    
    // 获取持久化状态
    public func getPersistentState(): PersistentState {
        persistentState
    }
    
    // 清理持久化数据
    public func deletePersistentData(): Unit {
        persistencePlugin.deleteData(name)
    }
    
    public override func preStart(): Unit {
        wrappedActor.preStart()
        startRecovery()
    }
    
    public override func postStop(): Unit {
        wrappedActor.postStop()
        persistencePlugin.close()
    }
    
    public override func preRestart(reason: Exception): Unit {
        wrappedActor.preRestart(reason)
    }
    
    public override func postRestart(reason: Exception): Unit {
        wrappedActor.postRestart(reason)
        startRecovery()
    }
}

// 持久化Actor工厂
public class PersistentActorFactory {
    public static func wrap(actor: SimpleActor, config: PersistenceConfig): PersistentActorWrapper {
        let plugin = PersistencePluginFactory.create(config)
        PersistentActorWrapper(actor, plugin)
    }
    
    public static func wrapWithMemoryPersistence(actor: SimpleActor): PersistentActorWrapper {
        let plugin = PersistencePluginFactory.createMemoryEnabled()
        PersistentActorWrapper(actor, plugin)
    }
    
    public static func wrapWithFilePersistence(actor: SimpleActor): PersistentActorWrapper {
        let plugin = PersistencePluginFactory.createFileEnabled()
        PersistentActorWrapper(actor, plugin)
    }
    
    public static func wrapDisabled(actor: SimpleActor): PersistentActorWrapper {
        let plugin = PersistencePluginFactory.createDisabled()
        PersistentActorWrapper(actor, plugin)
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
