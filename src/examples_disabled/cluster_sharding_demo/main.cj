/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Sharding 示例程序
 * 演示集群分片功能
 */
package cactor.examples.cluster_sharding_demo

import std.collection.*
import std.time.*

// ============================================================================
// Cluster Sharding 示例演示
// ============================================================================

/**
 * 实体消息
 */
public class EntityCommand {
    public let entityId: String
    public let payload: String

    public init(entityId: String, payload: String) {
        this.entityId = entityId
        this.payload = payload
    }
}

/**
 * 实体响应
 */
public class EntityResponse {
    public let entityId: String
    public let result: String

    public init(entityId: String, result: String) {
        this.entityId = entityId
        this.result = result
    }
}

/**
 * 分片信息
 */
public class ShardInfo {
    public let shardId: Int64
    public let entityCount: Int64
    public let region: String

    public init(shardId: Int64, entityCount: Int64, region: String) {
        this.shardId = shardId
        this.entityCount = entityCount
        this.region = region
    }

    public func toString(): String {
        "Shard(${shardId}, entities=${entityCount}, region=${region})"
    }
}

/**
 * 实体状态
 */
public class EntityState {
    public let entityId: String
    public var value: String
    public var updateCount: Int64

    public init(entityId: String) {
        this.entityId = entityId
        this.value = ""
        this.updateCount = 0
    }

    public func update(newValue: String): Unit {
        value = newValue
        updateCount += 1
    }
}

/**
 * 实体 Actor 模拟
 */
public class EntityActor {
    private var state: EntityState
    private let persistenceId: String

    public init(entityId: String) {
        this.state = EntityState(entityId)
        this.persistenceId = "sharding-${entityId}"
    }

    public func receive(command: EntityCommand): EntityResponse {
        match (command.entityId) {
            case id where id == state.entityId =>
                state.update(command.payload)
                EntityResponse(state.entityId, "Updated: ${command.payload}")
            case _ =>
                EntityResponse(command.entityId, "Entity mismatch")
        }
    }

    public func getState(): EntityState {
        state
    }

    public func getPersistenceId(): String {
        persistenceId
    }
}

/**
 * 分片协调器状态
 */
public class ShardCoordinatorState {
    public var shards: HashMap[Int64, ShardInfo]
    public var shardAllocations: HashMap[String, Int64]  // node -> shard
    public var shardRegions: HashMap[Int64, String]       // shard -> region

    public init() {
        shards = HashMap[Int64, ShardInfo]()
        shardAllocations = HashMap[String, Int64]()
        shardRegions = HashMap[Int64, String]()
    }

    public func addShard(shardId: Int64, info: ShardInfo): Unit {
        shards.add(shardId, info)
    }

    public func allocateShard(shardId: Int64, node: String): Unit {
        shardAllocations.add(node, shardId)
        match (shards.get(shardId)) {
            case Some(info) =>
                shardRegions.add(shardId, info.region)
            case None => ()
        }
    }

    public func getNodeForShard(shardId: Int64): Option[String] {
        for ((node, sid) in shardAllocations) {
            if (sid == shardId) {
                return Some(node)
            }
        }
        None
    }
}

/**
 * 演示基本分片概念
 */
public func demonstrateBasicSharding(): Unit {
    println("=== 基本分片概念演示 ===")

    // 定义分片数量
    let numberOfShards = 100

    // 计算实体的分片 ID
    func shardId(entityId: String): Int64 {
        // 简单的哈希分片
        var hash: Int64 = 0
        for (c in entityId) {
            hash = hash * 31 + Int64(c)
        }
        (hash.abs() % numberOfShards)
    }

    println("分片数量: ${numberOfShards}")
    println()

    // 测试分片分配
    let entityIds = [
        "user-1", "user-2", "user-3",
        "order-100", "order-200",
        "product-A", "product-B"
    ]

    println("实体分片分配:")
    for (entityId in entityIds) {
        let sid = shardId(entityId)
        println("  ${entityId} -> Shard ${sid}")
    }
    println()
}

/**
 * 演示分片协调器
 */
public func demonstrateShardCoordinator(): Unit {
    println("=== 分片协调器演示 ===")

    let coordinator = ShardCoordinatorState()

    // 添加分片
    println("初始化分片:")
    for (i in 0..10) {
        let info = ShardInfo(i, 0, "region-1")
        coordinator.addShard(i, info)
        println("  添加 Shard ${i}")
    }

    // 分配分片到节点
    println()
    println("分配分片到节点:")
    let nodes = ["node-1", "node-2", "node-3"]
    var shardIndex = 0
    for (node in nodes) {
        coordinator.allocateShard(shardIndex, node)
        println("  ${node} -> Shard ${shardIndex}")
        shardIndex += 1
    }

    // 查询分片位置
    println()
    println("查询分片位置:")
    for (i in 0..3) {
        match (coordinator.getNodeForShard(i)) {
            case Some(node) => println("  Shard ${i} 在 ${node}")
            case None => println("  Shard ${i} 未分配")
        }
    }
    println()
}

/**
 * 演示分片感知路由
 */
public func demonstrateShardRouting(): Unit {
    println("=== 分片感知路由演示 ===")

    let coordinator = ShardCoordinatorState()
    let numberOfShards = 10

    // 初始化
    for (i in 0..numberOfShards) {
        let region = if (i < 5) { "us-east" } else { "us-west" }
        coordinator.addShard(i, ShardInfo(i, 0, region))
    }

    coordinator.allocateShard(0, "node-1")
    coordinator.allocateShard(1, "node-1")
    coordinator.allocateShard(2, "node-2")
    coordinator.allocateShard(5, "node-3")

    // 路由到分片
    func routeToShard(entityId: String): Int64 {
        var hash: Int64 = 0
        for (c in entityId) {
            hash = hash * 31 + Int64(c)
        }
        hash.abs() % numberOfShards
    }

    println("路由实体到分片:")
    let entities = ["user:123", "order:456", "product:789"]

    for (entityId in entities) {
        let shardId = routeToShard(entityId)
        match (coordinator.getNodeForShard(shardId)) {
            case Some(node) =>
                match (coordinator.shardRegions.get(shardId)) {
                    case Some(region) =>
                        println("  ${entityId} -> Shard ${shardId} -> ${node} (${region})")
                    case None =>
                        println("  ${entityId} -> Shard ${shardId} -> ${node}")
                }
            case None =>
                println("  ${entityId} -> Shard ${shardId} -> [未分配]")
        }
    }
    println()
}

/**
 * 演示分片再平衡
 */
public func demonstrateShardRebalancing(): Unit {
    println("=== 分片再平衡演示 ===")

    let coordinator = ShardCoordinatorState()

    // 模拟节点负载
    let nodes = ["node-1", "node-2", "node-3"]
    var shardDistribution = HashMap[String, Int64]()

    for (node in nodes) {
        shardDistribution.add(node, 0)
    }

    println("初始分片分布:")
    // 分配 9 个分片 (每节点 3 个)
    for (i in 0..9) {
        let nodeIndex = i % 3
        let node = nodes[nodeIndex]
        coordinator.allocateShard(i, node)
        let count = shardDistribution.get(node).getOrDefault(0) + 1
        shardDistribution.remove(node)
        shardDistribution.add(node, count)
        println("  Shard ${i} -> ${node}")
    }

    println()
    println("当前分布:")
    for ((node, count) in shardDistribution) {
        println("  ${node}: ${count} shards")
    }

    // 模拟添加新节点
    println()
    println("添加新节点 node-4:")

    // 再平衡 - 从 node-1 迁移一些分片
    println("  从 node-1 迁移分片 0, 1 -> node-4")
    coordinator.shardAllocations.remove("node-1")
    coordinator.allocateShard(0, "node-4")
    coordinator.allocateShard(1, "node-4")

    println()
    println("再平衡后分布:")
    var newDist = HashMap[String, Int64]()
    for (node in ["node-1", "node-2", "node-3", "node-4"]) {
        newDist.add(node, 0)
    }
    for ((node, _) in coordinator.shardAllocations) {
        let count = newDist.get(node).getOrDefault(0) + 1
        newDist.remove(node)
        newDist.add(node, count)
    }
    for ((node, count) in newDist) {
        println("  ${node}: ${count} shards")
    }
    println()
}

/**
 * 演示实体迁移
 */
public func demonstrateEntityMigration(): Unit {
    println("=== 实体迁移演示 ===")

    // 创建实体
    var entities = HashMap[String, EntityActor]()
    entities.add("user-1", EntityActor("user-1"))
    entities.add("user-2", EntityActor("user-2"))
    entities.add("user-3", EntityActor("user-3"))

    println("初始实体状态:")
    for ((id, entity) in entities) {
        let state = entity.getState()
        println("  ${id}: value='${state.value}', updates=${state.updateCount}")
    }

    // 模拟更新
    println()
    println("更新实体:")
    let cmd1 = EntityCommand("user-1", "Hello")
    let cmd2 = EntityCommand("user-2", "World")
    let cmd3 = EntityCommand("user-3", "!")

    match (entities.get("user-1")) {
        case Some(e) => let _ = e.receive(cmd1)
        case None => ()
    }
    match (entities.get("user-2")) {
        case Some(e) => let _ = e.receive(cmd2)
        case None => ()
    }
    match (entities.get("user-3")) {
        case Some(e) => let _ = e.receive(cmd3)
        case None => ()
    }

    println("更新后实体状态:")
    for ((id, entity) in entities) {
        let state = entity.getState()
        println("  ${id}: value='${state.value}', updates=${state.updateCount}")
    }

    // 模拟迁移
    println()
    println("模拟实体迁移 (user-2 迁移到新节点):")
    match (entities.get("user-2")) {
        case Some(e) =>
            println("  持久化 user-2 状态...")
            println("  序列化实体...")
            println("  传输到新节点...")
            println("  在新节点恢复实体...")
        case None => ()
    }

    println()
    println("迁移后状态保持不变:")
    match (entities.get("user-2")) {
        case Some(e) =>
            let state = e.getState()
            println("  user-2: value='${state.value}', updates=${state.updateCount}")
        case None => ()
    }
    println()
}

/**
 * 演示 HA 分片协调器
 */
public func demonstrateHAShardCoordinator(): Unit {
    println("=== HA 分片协调器演示 ===")

    let coordinator = ShardCoordinatorState()
    var currentLeader: Option[String] = None
    var leaderTerm: Int64 = 0

    // 模拟选举
    println("模拟领袖选举:")
    println("  节点列表: [node-1, node-2, node-3]")

    // node-1 当选
    currentLeader = Some("node-1")
    leaderTerm = 1
    println("  node-1 当选领袖 (Term ${leaderTerm})")

    // 模拟领袖变更
    println()
    println("模拟领袖变更 (node-1 故障):")

    // 检测故障
    println("  检测到 node-1 不可达")
    println("  触发重新选举...")

    // node-2 当选
    currentLeader = Some("node-2")
    leaderTerm = 2
    println("  node-2 当选领袖 (Term ${leaderTerm})")

    println()
    println("领袖选举日志:")
    println("  Term 1: node-1 (主)")
    println("  Term 2: node-2 (主)")
    println()
    println("当前状态:")
    println("  领袖: ${currentLeader}")
    println("  Term: ${leaderTerm}")
    println()
}

/**
 * 演示分片设置
 */
public func demonstrateShardSettings(): Unit {
    println("=== 分片设置演示 ===")

    let settings = ShardSettings(
        "user",
        10,         // shards
        Duration.second * 5,  // retryInterval
        Duration.second * 10   // handOffTimeout
    )

    println("分片设置:")
    println("  类型名称: ${settings.typeName}")
    println("  分片数: ${settings.numberOfShards}")
    println("  重试间隔: ${settings.retryInterval}")
    println("  移交超时: ${settings.handOffTimeout}")
    println()
}

/**
 * 分片设置
 */
public class ShardSettings {
    public let typeName: String
    public let numberOfShards: Int64
    public let retryInterval: Duration
    public let handOffTimeout: Duration

    public init(
        typeName: String,
        numberOfShards: Int64,
        retryInterval: Duration,
        handOffTimeout: Duration
    ) {
        this.typeName = typeName
        this.numberOfShards = numberOfShards
        this.retryInterval = retryInterval
        this.handOffTimeout = handOffTimeout
    }
}

/**
 * 运行所有演示
 */
main(): Unit {
    println("========================================")
    println("   CActor Cluster Sharding 分片演示")
    println("========================================")
    println()

    demonstrateBasicSharding()
    demonstrateShardCoordinator()
    demonstrateShardRouting()
    demonstrateShardRebalancing()
    demonstrateEntityMigration()
    demonstrateHAShardCoordinator()
    demonstrateShardSettings()

    println("========================================")
    println("   Cluster Sharding 演示完成!")
    println("========================================")
}