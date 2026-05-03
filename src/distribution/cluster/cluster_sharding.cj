/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Sharding 实现
 * 对标 Akka Cluster Sharding
 * 提供跨节点 Actor 分片管理
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.{ActorPath}
import cactor.core.message.Message

/**
 * 分片策略接口 - 对标 Akka ShardRegionResolver
 */
public interface ShardResolver {
    /**
     * 根据实体 ID 计算分片 ID
     * @param entityId 实体 ID
     * @param numberOfShards 分片数量
     * @return 分片 ID
     */
    func shardId(entityId: String, numberOfShards: Int64): String
}

/**
 * 默认分片策略 - 哈希分片
 */
public class HashShardResolver <: ShardResolver {
    public func shardId(entityId: String, numberOfShards: Int64): String {
        let hash = hashCode(entityId)
        let shardNum = ((hash & 0x7FFFFFFF) % numberOfShards) + 1
        "${shardNum}"
    }

    private func hashCode(s: String): Int64 {
        var hash: Int64 = 0
        for (c in s) {
            hash = 31 * hash + Int64(c)
        }
        hash
    }
}

/**
 * 游标分片策略 - 游标式分配
 */
public class CursorShardResolver <: ShardResolver {
    private var cursor: Int64 = 0
    private let mutex: Mutex

    public init() {
        this.cursor = 0
        this.mutex = Mutex()
    }

    public func shardId(entityId: String, numberOfShards: Int64): String {
        mutex.lock()
        cursor = (cursor + 1) % numberOfShards
        let shard = cursor
        mutex.unlock()
        "${shard + 1}"
    }
}

/**
 * 角色分片策略 - 按角色分配
 */
public class RoleShardResolver <: ShardResolver {
    private let numberOfShards: Int64

    public init(numberOfShards: Int64) {
        this.numberOfShards = numberOfShards
    }

    public func shardId(entityId: String, numberOfShards: Int64): String {
        // 简化实现：使用 entityId 的哈希
        let hash = hashCode(entityId)
        let shardNum = ((hash & 0x7FFFFFFF) % numberOfShards) + 1
        "${shardNum}"
    }

    private func hashCode(s: String): Int64 {
        var hash: Int64 = 0
        for (c in s) {
            hash = 31 * hash + Int64(c)
        }
        hash
    }
}

/**
 * 分片设置 - 对标 Akka ClusterShardingSettings
 */
public struct ShardingSettings {
    public let typeName: String           // 实体类型名称
    public let role: String               // 节点角色
    public let numberOfShards: Int64      // 分片数量
    public let rememberEntities: Bool      // 是否记住实体位置
    public let rememberEntitiesStartAfter: Duration  // 启动延迟
    public let passivationStrategy: PassivationStrategy  // 老化策略
    public let shardResolver: ShardResolver  // 分片解析器

    public init(
        typeName: String,
        role!: String = "",
        numberOfShards!: Int64 = 10,
        rememberEntities!: Bool = false,
        rememberEntitiesStartAfter!: Duration = Duration.second * 5,
        passivationStrategy!: PassivationStrategy = PassivationStrategy.getDefault(),
        shardResolver!: ShardResolver = HashShardResolver()
    ) {
        this.typeName = typeName
        this.role = role
        this.numberOfShards = numberOfShards
        this.rememberEntities = rememberEntities
        this.rememberEntitiesStartAfter = rememberEntitiesStartAfter
        this.passivationStrategy = passivationStrategy
        this.shardResolver = shardResolver
    }

    /**
     * 创建默认设置
     */
    public static func getDefault(typeName: String, numberOfShards: Int64): ShardingSettings {
        ShardingSettings(typeName, numberOfShards: numberOfShards)
    }
}

/**
 * 老化策略 - 对标 Akka Passivation
 */
public enum PassivationStrategy {
    | Idle                         // 空闲时老化
    | Count(Int64)               // 消息数量后老化
    | Time(Duration)             // 时间后老化
    | IdleOrCount(Int64, Duration)  // 空闲或计数
    | IdleOrTime(Duration)       // 空闲或时间

    public func toString(): String {
        match (this) {
            case Idle => "Idle"
            case Count(n) => "Count(${n})"
            case Time(d) => "Time(${d})"
            case IdleOrCount(n, d) => "IdleOrCount(${n}, ${d})"
            case IdleOrTime(d) => "IdleOrTime(${d})"
        }
    }

    public static func getDefault(): PassivationStrategy {
        IdleOrTime(Duration.minute * 2)
    }
}

/**
 * 实体引用 - 对标 Akka EntityRef
 */
public interface EntityRef {
    /**
     * 发送消息
     */
    func tell(message: Message): Unit

    /**
     * 发送消息并等待回复
     */
    func ask(message: Message, timeout: Duration): Option<Message>
}

/**
 * 实体槽位引用
 */
public class EntityRefImpl <: EntityRef {
    private let typeName: String
    private let entityId: String
    private let shardId: String
    private let shardRegion: ActorPath

    public init(typeName: String, entityId: String, shardId: String, shardRegion: ActorPath) {
        this.typeName = typeName
        this.entityId = entityId
        this.shardId = shardId
        this.shardRegion = shardRegion
    }

    public func tell(message: Message): Unit {
        // 构造 ShardEnvelope 并发送
        let envelope = ShardEnvelope(entityId, message)
        // 通过 shardRegion 发送
        println("EntityRef.tell: entity=${entityId}, shard=${shardId}")
    }

    public func ask(message: Message, timeout: Duration): Option<Message> {
        tell(message)
        None  // 简化实现
    }

    public func getEntityId(): String {
        entityId
    }

    public func getShardId(): String {
        shardId
    }
}

/**
 * 分片信封 - 对标 Akka ShardEnvelope
 */
public class ShardEnvelope {
    public let entityId: String
    public let message: Message

    public init(entityId: String, message: Message) {
        this.entityId = entityId
        this.message = message
    }
}

/**
 * 分片命令 - 内部使用
 */
public enum ShardCommand {
    | Add(String, EntityRef)
    | Remove(String)
    | Passivate(String)
    | GetEntityIds
    | GetStats
}

/**
 * 分片区域状态
 */
public class ShardRegionState {
    public let shardId: String
    public let entityIds: ArrayList<String>
    public var totalEntityCount: Int64
    public var avgEntityCountPerShard: Float64

    public init(shardId: String) {
        this.shardId = shardId
        this.entityIds = ArrayList<String>()
        this.totalEntityCount = 0
        this.avgEntityCountPerShard = 0.0
    }
}

/**
 * 分片统计信息
 */
public class ShardingStats {
    public let regions: HashMap<String, ShardRegionState>
    public let totalShards: Int64
    public let totalEntities: Int64
    public let avgEntitiesPerShard: Float64

    public init(
        regions: HashMap<String, ShardRegionState>,
        totalShards: Int64,
        totalEntities: Int64,
        avgEntitiesPerShard: Float64
    ) {
        this.regions = regions
        this.totalShards = totalShards
        this.totalEntities = totalEntities
        this.avgEntitiesPerShard = avgEntitiesPerShard
    }
}

/**
 * 分片 Actor - 对标 Akka Shard
 */
public interface Shard {
    /**
     * 获取分片 ID
     */
    func shardId(): String

    /**
     * 实体 ID 到分片 ID
     */
    func shardIdForEntity(entityId: String): String

    /**
     * 添加实体
     */
    func addEntity(entityId: String): EntityRef

    /**
     * 移除实体
     */
    func removeEntity(entityId: String): Unit

    /**
     * 获取实体数量
     */
    func entityCount(): Int64

    /**
     * 获取实体 ID 列表
     */
    func getEntityIds(): Array<String>
}

/**
 * 简化分片实现
 */
public class SimpleShard <: Shard {
    private let shardIdValue: String
    private let settings: ShardingSettings
    private let entities: HashMap<String, EntityRefImpl>
    private let mutex: Mutex
    private var entityCountValue: Int64

    public init(shardId: String, settings: ShardingSettings) {
        this.shardIdValue = shardId
        this.settings = settings
        this.entities = HashMap<String, EntityRefImpl>()
        this.mutex = Mutex()
        this.entityCountValue = 0
    }

    public func shardId(): String {
        shardIdValue
    }

    public func shardIdForEntity(entityId: String): String {
        settings.shardResolver.shardId(entityId, settings.numberOfShards)
    }

    public func addEntity(entityId: String): EntityRef {
        mutex.lock()
        let existing = entities.get(entityId)
        mutex.unlock()

        match (existing) {
            case Some(ref) => ref
            case None =>
                mutex.lock()
                let ref = EntityRefImpl(settings.typeName, entityId, shardIdValue, ActorPath("local", ""))
                entities.add(entityId, ref)
                entityCountValue += 1
                mutex.unlock()
                println("Shard ${shardIdValue}: Added entity ${entityId}")
                ref
        }
    }

    public func removeEntity(entityId: String): Unit {
        mutex.lock()
        entities.remove(entityId)
        entityCountValue -= 1
        mutex.unlock()
        println("Shard ${shardIdValue}: Removed entity ${entityId}")
    }

    public func entityCount(): Int64 {
        mutex.lock()
        let count = entityCountValue
        mutex.unlock()
        count
    }

    public func getEntityIds(): Array<String> {
        mutex.lock()
        let ids = ArrayList<String>()
        for ((id, _) in entities) {
            ids.add(id)
        }
        mutex.unlock()
        ids.toArray()
    }
}

/**
 * 分片区域 - 对标 Akka ShardRegion
 */
public interface ShardRegion {
    /**
     * 获取区域路径
     */
    func path(): ActorPath

    /**
     * 获取指定实体的引用
     */
    func entityRefFor(entityId: String): EntityRef

    /**
     * 初始化分片区域
     */
    func start(): Unit

    /**
     * 关闭分片区域
     */
    func shutdown(): Unit
}

/**
 * 简化分片区域实现
 */
public class SimpleShardRegion <: ShardRegion {
    internal let settings: ShardingSettings
    internal let shards: HashMap<String, SimpleShard>
    internal let entitiesByShard: HashMap<String, ArrayList<String>>
    internal let shardRegionPath: ActorPath
    internal let started: AtomicBool
    internal let mutex: Mutex

    public init(settings: ShardingSettings, path: ActorPath) {
        this.settings = settings
        this.shards = HashMap<String, SimpleShard>()
        this.entitiesByShard = HashMap<String, ArrayList<String>>()
        this.shardRegionPath = path
        this.started = AtomicBool(false)
        this.mutex = Mutex()
    }

    public func path(): ActorPath {
        shardRegionPath
    }

    public func entityRefFor(entityId: String): EntityRef {
        if (!started.load()) {
            throw Exception("ShardRegion not started")
        }

        let shardId = settings.shardResolver.shardId(entityId, settings.numberOfShards)

        mutex.lock()
        let shard = match (shards.get(shardId)) {
            case Some(s) => s
            case None =>
                let newShard = SimpleShard(shardId, settings)
                shards.add(shardId, newShard)
                entitiesByShard.add(shardId, ArrayList<String>())
                newShard
        }
        mutex.unlock()

        let entityRef = shard.addEntity(entityId)

        // 记录实体到分片的映射
        mutex.lock()
        match (entitiesByShard.get(shardId)) {
            case Some(list) =>
                // 检查是否已存在
                var found = false
                for (id in list) {
                    if (id == entityId) {
                        found = true
                        break
                    }
                }
                if (!found) {
                    list.add(entityId)
                }
            case None => ()
        }
        mutex.unlock()

        entityRef
    }

    public func start(): Unit {
        initialize()
    }

    public func initialize(): Unit {
        if (started.compareAndSwap(false, true)) {
            println("ShardRegion initialized for type: ${settings.typeName}")
            println("Number of shards: ${settings.numberOfShards}")
        }
    }

    public func shutdown(): Unit {
        if (started.compareAndSwap(true, false)) {
            mutex.lock()
            shards.clear()
            entitiesByShard.clear()
            mutex.unlock()
            println("ShardRegion shutdown for type: ${settings.typeName}")
        }
    }

    /**
     * 获取统计信息
     */
    public func getStats(): ShardingStats {
        mutex.lock()
        var totalEntities: Int64 = 0
        let regions = HashMap<String, ShardRegionState>()

        for ((shardId, shard) in shards) {
            let count = shard.entityCount()
            totalEntities += count

            let state = ShardRegionState(shardId)
            for (id in shard.getEntityIds()) {
                state.entityIds.add(id)
            }
            state.totalEntityCount = count
            regions.add(shardId, state)
        }

        let avg = if (shards.size > 0) {
            Float64(totalEntities) / Float64(shards.size)
        } else {
            0.0
        }
        mutex.unlock()

        ShardingStats(regions, settings.numberOfShards, totalEntities, avg)
    }

    /**
     * 手动分配分片
     */
    public func allocateShard(shardId: String, nodeAddress: Address): Unit {
        mutex.lock()
        if (!shards.contains(shardId)) {
            let shard = SimpleShard(shardId, settings)
            shards.add(shardId, shard)
            entitiesByShard.add(shardId, ArrayList<String>())
        }
        mutex.unlock()
        println("Allocated shard ${shardId} to ${nodeAddress.toString()}")
    }
}

/**
 * 集群分片管理器 - 对标 Akka ClusterSharding
 */
public class ClusterSharding {
    private let settings: ShardingSettings
    private let regions: HashMap<String, SimpleShardRegion>
    private let rememberingRegions: HashMap<String, RememberingShardRegion>
    private let shardCoordinator: Option<ShardCoordinator>
    private let started: AtomicBool
    private let mutex: Mutex

    public init(settings: ShardingSettings) {
        this.settings = settings
        this.regions = HashMap<String, SimpleShardRegion>()
        this.rememberingRegions = HashMap<String, RememberingShardRegion>()
        this.shardCoordinator = None
        this.started = AtomicBool(false)
        this.mutex = Mutex()
    }

    /**
     * 启动分片系统
     * 如果 rememberEntities 启用，创建 RememberingShardRegion
     */
    public func start(): ShardRegion {
        if (!started.load()) {
            mutex.lock()
            if (!started.load()) {
                let addr = Address("cactor", "sharding", "localhost", 0)
                let path = ActorPath(addr.system, settings.typeName)

                if (settings.rememberEntities) {
                    let region = RememberingShardRegion(settings, path)
                    rememberingRegions.add(settings.typeName, region)
                    region.initialize()
                    println("ClusterSharding (Remembering Entities) started for type: ${settings.typeName}")
                } else {
                    let region = SimpleShardRegion(settings, path)
                    regions.add(settings.typeName, region)
                    region.initialize()
                    println("ClusterSharding started for type: ${settings.typeName}")
                }
                started.store(true)
            }
            mutex.unlock()
        }

        if (settings.rememberEntities) {
            match (rememberingRegions.get(settings.typeName)) {
                case Some(region) => region
                case None => throw Exception("Failed to start ClusterSharding with Remembering Entities")
            }
        } else {
            match (regions.get(settings.typeName)) {
                case Some(region) => region
                case None => throw Exception("Failed to start ClusterSharding")
            }
        }
    }

    /**
     * 获取指定类型的分片区域
     */
    public func shardRegion(typeName: String): Option<ShardRegion> {
        match (regions.get(typeName)) {
            case Some(region) => Some(region)
            case None =>
                match (rememberingRegions.get(typeName)) {
                    case Some(region) => Some(region)
                    case None => None
                }
        }
    }

    /**
     * 获取记住实体的分片区域（如果启用）
     */
    public func rememberingShardRegion(typeName: String): Option<RememberingShardRegion> {
        rememberingRegions.get(typeName)
    }

    /**
     * 停止分片系统
     */
    public func shutdown(): Unit {
        if (started.compareAndSwap(true, false)) {
            mutex.lock()
            for ((_, region) in regions) {
                region.shutdown()
            }
            for ((_, region) in rememberingRegions) {
                region.shutdown()
            }
            regions.clear()
            rememberingRegions.clear()
            mutex.unlock()
            println("ClusterSharding shutdown")
        }
    }

    /**
     * 获取所有分片统计
     */
    public func getStats(typeName: String): Option<ShardingStats> {
        if (settings.rememberEntities) {
            match (rememberingRegions.get(typeName)) {
                case Some(region) => Some(region.getStats())
                case None => None
            }
        } else {
            match (regions.get(typeName)) {
                case Some(region) => Some(region.getStats())
                case None => None
            }
        }
    }
}

/**
 * 分片协调器接口 - 对标 Akka ShardCoordinator
 */
public interface ShardCoordinator {
    /**
     * 分配分片到节点
     */
    func allocateShard(shardId: String, nodeAddress: Address): Unit

    /**
     * 更新分片位置
     */
    func updateShardLocation(shardId: String, nodeAddress: Address): Unit

    /**
     * 获取分片位置
     */
    func getShardLocation(shardId: String): Option<Address>

    /**
     * 获取所有分配
     */
    func getAllAllocations(): HashMap<String, Address>
}

/**
 * 简化分片协调器
 */
public class SimpleShardCoordinator <: ShardCoordinator {
    private let allocations: HashMap<String, Address>
    private let mutex: Mutex

    public init() {
        this.allocations = HashMap<String, Address>()
        this.mutex = Mutex()
    }

    public func allocateShard(shardId: String, nodeAddress: Address): Unit {
        mutex.lock()
        allocations.add(shardId, nodeAddress)
        mutex.unlock()
    }

    public func updateShardLocation(shardId: String, nodeAddress: Address): Unit {
        mutex.lock()
        allocations.add(shardId, nodeAddress)
        mutex.unlock()
    }

    public func getShardLocation(shardId: String): Option<Address> {
        mutex.lock()
        let result = allocations.get(shardId)
        mutex.unlock()
        result
    }

    public func getAllAllocations(): HashMap<String, Address> {
        mutex.lock()
        let result = HashMap<String, Address>()
        for ((k, v) in allocations) {
            result.add(k, v)
        }
        mutex.unlock()
        result
    }
}

/**
 * 集群分片工厂
 */
public class ClusterShardingFactory {
    /**
     * 创建默认分片系统
     */
    public static func create(
        typeName: String,
        numberOfShards!: Int64 = 10,
        rememberEntities!: Bool = false
    ): ClusterSharding {
        let settings = ShardingSettings.getDefault(typeName, numberOfShards)
        ClusterSharding(settings)
    }

    /**
     * 创建带自定义分片策略的分片系统
     */
    public static func createWithResolver(
        typeName: String,
        resolver: ShardResolver,
        numberOfShards!: Int64 = 10,
        rememberEntities!: Bool = false
    ): ClusterSharding {
        let settings = ShardingSettings(
            typeName,
            numberOfShards: numberOfShards,
            rememberEntities: rememberEntities,
            shardResolver: resolver
        )
        ClusterSharding(settings)
    }

    /**
     * 创建哈希分片系统
     */
    public static func createHashSharded(
        typeName: String,
        numberOfShards!: Int64 = 10
    ): ClusterSharding {
        createWithResolver(typeName, HashShardResolver(), numberOfShards: numberOfShards)
    }
}

/**
 * 分片系统事件
 */
public enum ShardingEvent {
    | ShardStarted(String, Array<String>)
    | ShardStoped(String)
    | EntityStarted(String, String)
    | EntityPassivated(String, String)

    public func toString(): String {
        match (this) {
            case ShardStarted(sid, ids) => "ShardStarted(${sid}, ${ids.size} entities)"
            case ShardStoped(sid) => "ShardStoped(${sid})"
            case EntityStarted(eid, sid) => "EntityStarted(${eid} in ${sid})"
            case EntityPassivated(eid, sid) => "EntityPassivated(${eid} in ${sid})"
        }
    }
}

/**
 * 分片事件监听器
 */
public interface ShardingEventListener {
    func onShardingEvent(event: ShardingEvent): Unit
}

// ============================================================================
// Remembering Entities - 对标 Akka Remembering Entities
// ============================================================================

/**
 * 实体存储接口 - 对标 Akka RememberEntitiesStore
 * 持久化实体到分片的映射关系
 */
public interface EntityStore {
    /**
     * 添加实体到分片
     */
    func addEntity(shardId: String, entityId: String): Unit

    /**
     * 从分片移除实体
     */
    func removeEntity(shardId: String, entityId: String): Unit

    /**
     * 获取分片中的所有实体 ID
     */
    func getEntitiesForShard(shardId: String): Array<String>

    /**
     * 获取所有分片的实体映射
     */
    func getAllShardEntities(): HashMap<String, Array<String>>

    /**
     * 清空存储
     */
    func clear(): Unit
}

/**
 * 内存实体存储实现
 */
public class MemoryEntityStore <: EntityStore {
    private let store: HashMap<String, ArrayList<String>>
    private let mutex: Mutex

    public init() {
        this.store = HashMap<String, ArrayList<String>>()
        this.mutex = Mutex()
    }

    public func addEntity(shardId: String, entityId: String): Unit {
        mutex.lock()
        match (store.get(shardId)) {
            case Some(list) =>
                // 检查是否已存在
                var found = false
                for (id in list) {
                    if (id == entityId) {
                        found = true
                        break
                    }
                }
                if (!found) {
                    list.add(entityId)
                }
            case None =>
                let list = ArrayList<String>()
                list.add(entityId)
                store.add(shardId, list)
        }
        mutex.unlock()
    }

    public func removeEntity(shardId: String, entityId: String): Unit {
        mutex.lock()
        match (store.get(shardId)) {
            case Some(list) =>
                let newList = ArrayList<String>()
                for (id in list) {
                    if (id != entityId) {
                        newList.add(id)
                    }
                }
                store.add(shardId, newList)
            case None => ()
        }
        mutex.unlock()
    }

    public func getEntitiesForShard(shardId: String): Array<String> {
        mutex.lock()
        let result = match (store.get(shardId)) {
            case Some(list) => list.toArray()
            case None => Array<String>(0, { i: Int64 => "" })
        }
        mutex.unlock()
        result
    }

    public func getAllShardEntities(): HashMap<String, Array<String>> {
        mutex.lock()
        let result = HashMap<String, Array<String>>()
        for ((shardId, list) in store) {
            result.add(shardId, list.toArray())
        }
        mutex.unlock()
        result
    }

    public func clear(): Unit {
        mutex.lock()
        store.clear()
        mutex.unlock()
    }
}

/**
 * 分片分配策略接口 - 对标 Akka ShardAllocationStrategy
 */
public interface ShardAllocationStrategy {
    /**
     * 分配分片到节点
     * @param shardId 分片 ID
     * @param requester 请求节点
     * @param currentAllocations 当前分配
     * @return 分配的节点地址
     */
    func allocateShard(
        shardId: String,
        requester: Address,
        currentAllocations: HashMap<String, Address>
    ): Address

    /**
     * 是否需要重新平衡分片
     * @param currentAllocations 当前分配
     * @param rebalanceInProgress 是否正在重新平衡
     * @return 需要重新平衡的分片 ID 列表
     */
    func rebalance(
        currentAllocations: HashMap<String, Address>,
        rebalanceInProgress: Array<String>
    ): Array<String>
}

/**
 * 最少分片分配策略 - 对标 Akka LeastShardAllocationStrategy
 */
public class LeastShardAllocationStrategy <: ShardAllocationStrategy {
    public func allocateShard(
        shardId: String,
        requester: Address,
        currentAllocations: HashMap<String, Address>
    ): Address {
        // 计算每个节点的分片数量
        let nodeShardCount = HashMap<String, Int64>()
        for ((_, addr) in currentAllocations) {
            let key = addr.toString()
            match (nodeShardCount.get(key)) {
                case Some(count) => nodeShardCount.add(key, count + 1)
                case None => nodeShardCount.add(key, 1)
            }
        }

        // 找到最少分片的节点
        var minCount: Int64 = 9223372036854775807i64  // Int64 max value
        var selectedAddr = requester
        for ((_, addr) in currentAllocations) {
            let key = addr.toString()
            let count = match (nodeShardCount.get(key)) {
                case Some(c) => c
                case None => 0
            }
            if (count < minCount) {
                minCount = count
                selectedAddr = addr
            }
        }
        selectedAddr
    }

    public func rebalance(
        currentAllocations: HashMap<String, Address>,
        rebalanceInProgress: Array<String>
    ): Array<String> {
        // 简化实现：不主动重新平衡
        Array<String>(0, { i: Int64 => "" })
    }
}

/**
 * 记住实体的分片区域 - 对标 Akka Remembering Entities ShardRegion
 * 提供完整的实体位置记忆功能
 */
public class RememberingShardRegion <: ShardRegion {
    private let settings: ShardingSettings
    private let shards: HashMap<String, SimpleShard>
    private let entityStore: EntityStore
    private let shardRegionPath: ActorPath
    private let started: AtomicBool
    private let mutex: Mutex

    public init(settings: ShardingSettings, path: ActorPath, entityStore!: EntityStore = MemoryEntityStore()) {
        this.settings = settings
        this.shards = HashMap<String, SimpleShard>()
        this.entityStore = entityStore
        this.shardRegionPath = path
        this.started = AtomicBool(false)
        this.mutex = Mutex()
    }

    public func path(): ActorPath {
        shardRegionPath
    }

    public func entityRefFor(entityId: String): EntityRef {
        if (!started.load()) {
            throw Exception("RememberingShardRegion not started")
        }

        let shardId = settings.shardResolver.shardId(entityId, settings.numberOfShards)

        mutex.lock()
        let shard = match (shards.get(shardId)) {
            case Some(s) => s
            case None =>
                let newShard = SimpleShard(shardId, settings)
                shards.add(shardId, newShard)
                newShard
        }
        mutex.unlock()

        let entityRef = shard.addEntity(entityId)

        // 记住实体位置
        entityStore.addEntity(shardId, entityId)

        entityRef
    }

    public func start(): Unit {
        initialize()
    }

    public func initialize(): Unit {
        if (started.compareAndSwap(false, true)) {
            println("RememberingShardRegion initialized for type: ${settings.typeName}")

            // 恢复已记住的实体
            restoreEntities()
        }
    }

    /**
     * 从存储恢复实体
     */
    public func restoreEntities(): Unit {
        let allEntities = entityStore.getAllShardEntities()
        var restoredCount: Int64 = 0

        for ((shardId, entityIds) in allEntities) {
            // 创建分片（如果不存在）
            mutex.lock()
            match (shards.get(shardId)) {
                case Some(_) => ()
                case None =>
                    let newShard = SimpleShard(shardId, settings)
                    shards.add(shardId, newShard)
            }
            mutex.unlock()

            // 恢复每个实体
            for (entityId in entityIds) {
                let ref = entityRefFor(entityId)
                restoredCount += 1
            }
        }

        println("RememberingShardRegion restored ${restoredCount} entities from store")
    }

    public func shutdown(): Unit {
        if (started.compareAndSwap(true, false)) {
            mutex.lock()
            shards.clear()
            mutex.unlock()
            println("RememberingShardRegion shutdown for type: ${settings.typeName}")
        }
    }

    /**
     * 移除实体并从存储中删除
     */
    public func removeAndForget(shardId: String, entityId: String): Unit {
        mutex.lock()
        match (shards.get(shardId)) {
            case Some(shard) => shard.removeEntity(entityId)
            case None => ()
        }
        mutex.unlock()

        entityStore.removeEntity(shardId, entityId)
    }

    /**
     * 获取统计信息
     */
    public func getStats(): ShardingStats {
        mutex.lock()
        var totalEntities: Int64 = 0
        let regions = HashMap<String, ShardRegionState>()

        for ((shardId, shard) in shards) {
            let count = shard.entityCount()
            totalEntities += count

            let state = ShardRegionState(shardId)
            for (id in shard.getEntityIds()) {
                state.entityIds.add(id)
            }
            state.totalEntityCount = count
            regions.add(shardId, state)
        }

        let avg = if (shards.size > 0) {
            Float64(totalEntities) / Float64(shards.size)
        } else {
            0.0
        }
        mutex.unlock()

        ShardingStats(regions, settings.numberOfShards, totalEntities, avg)
    }

    /**
     * 获取实体存储
     */
    public func getEntityStore(): EntityStore {
        entityStore
    }

    /**
     * 检查是否已启动
     */
    public func isStarted(): Bool {
        started.load()
    }
}
