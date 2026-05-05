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
}

/**
 * 演示基本分片概念
 */
public func demonstrateBasicSharding(): Unit {
    println("=== 基本分片概念演示 ===")

    let numberOfShards = 100

    // 计算实体的分片 ID
    func shardId(entityId: String): Int64 {
        var hash: Int64 = 0
        for (c in entityId) {
            hash = hash * 31 + Int64(c)
        }
        // 确保非负
        if (hash < 0) {
            hash = -hash
        }
        hash % numberOfShards
    }

    println("分片数量: ${numberOfShards}")
    println()

    println("实体分片分配:")
    let entities = ArrayList<String>()
    entities.add("user-1")
    entities.add("user-2")
    entities.add("user-3")
    entities.add("order-100")
    entities.add("order-200")
    entities.add("product-A")
    entities.add("product-B")

    for (entityId in entities) {
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

    let shards = HashMap<Int64, ShardInfo>()

    println("初始化分片:")
    for (i in 0..10) {
        let info = ShardInfo(i, 0, "region-1")
        shards.add(i, info)
        println("  添加 Shard ${i}")
    }

    let allocations = HashMap<String, Int64>()

    println()
    println("分配分片到节点:")
    let nodes = ArrayList<String>()
    nodes.add("node-1")
    nodes.add("node-2")
    nodes.add("node-3")

    var shardIndex = 0
    for (node in nodes) {
        allocations.add(node, shardIndex)
        println("  ${node} -> Shard ${shardIndex}")
        shardIndex += 1
    }

    println()
    println("查询分片位置:")
    for (i in 0..3) {
        var found = false
        for ((node, sid) in allocations) {
            if (sid == i) {
                println("  Shard ${i} 在 ${node}")
                found = true
                break
            }
        }
        if (!found) {
            println("  Shard ${i} 未分配")
        }
    }
    println()
}

/**
 * 演示分片感知路由
 */
public func demonstrateShardRouting(): Unit {
    println("=== 分片感知路由演示 ===")

    let shards = HashMap<Int64, ShardInfo>()
    let numberOfShards = 10

    for (i in 0..numberOfShards) {
        let region = if (i < 5) { "us-east" } else { "us-west" }
        shards.add(i, ShardInfo(i, 0, region))
    }

    let allocations = HashMap<Int64, String>()
    allocations.add(0, "node-1")
    allocations.add(1, "node-1")
    allocations.add(2, "node-2")
    allocations.add(5, "node-3")

    func routeToShard(entityId: String): Int64 {
        var hash: Int64 = 0
        for (c in entityId) {
            hash = hash * 31 + Int64(c)
        }
        if (hash < 0) {
            hash = -hash
        }
        hash % numberOfShards
    }

    println("路由实体到分片:")
    let entities = ArrayList<String>()
    entities.add("user:123")
    entities.add("order:456")
    entities.add("product:789")

    for (entityId in entities) {
        let sid = routeToShard(entityId)
        match (allocations.get(sid)) {
            case Some(node) =>
                match (shards.get(sid)) {
                    case Some(info) =>
                        println("  ${entityId} -> Shard ${sid} -> ${node} (${info.region})")
                    case None =>
                        println("  ${entityId} -> Shard ${sid} -> ${node}")
                }
            case None =>
                println("  ${entityId} -> Shard ${sid} -> [未分配]")
        }
    }
    println()
}

/**
 * 演示分片再平衡
 */
public func demonstrateShardRebalancing(): Unit {
    println("=== 分片再平衡演示 ===")

    let nodes = ArrayList<String>()
    nodes.add("node-1")
    nodes.add("node-2")
    nodes.add("node-3")

    let shardDistribution = HashMap<String, Int64>()
    for (node in nodes) {
        shardDistribution.add(node, 0)
    }

    println("初始分片分布:")
    for (i in 0..9) {
        let nodeIndex = i % 3
        // Get node by iterating
        var targetNode = ""
        var idx = 0
        for (n in nodes) {
            if (idx == nodeIndex) {
                targetNode = n
                break
            }
            idx += 1
        }
        // Update count - use separate tracking
        match (shardDistribution.get(targetNode)) {
            case Some(count) =>
                shardDistribution.remove(targetNode)
                shardDistribution.add(targetNode, count + 1)
            case None => ()
        }
        println("  ${targetNode} 分配 Shard ${i}")
    }

    println()
    println("每节点分片数:")
    for (node in nodes) {
        match (shardDistribution.get(node)) {
            case Some(count) =>
                println("  ${node}: ${count} 个分片")
            case None =>
                println("  ${node}: 0 个分片")
        }
    }
    println()
}

/**
 * 演示跨区域分片
 */
public func demonstrateCrossRegionSharding(): Unit {
    println("=== 跨区域分片演示 ===")

    let regionNodes = HashMap<String, ArrayList<String>>()

    let regions = ArrayList<String>()
    regions.add("us-east")
    regions.add("us-west")
    regions.add("eu-central")

    for (region in regions) {
        let nodes = ArrayList<String>()
        nodes.add("${region}-1")
        nodes.add("${region}-2")
        regionNodes.add(region, nodes)
        println("  初始化区域 ${region}")
    }

    println()
    println("按区域分配分片:")
    var shardId = 0
    for (region in regions) {
        match (regionNodes.get(region)) {
            case Some(nodes) =>
                for (node in nodes) {
                    println("  Shard ${shardId} -> ${node} (${region})")
                    shardId += 1
                }
            case None => ()
        }
    }
    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor Cluster Sharding 分片演示")
    println("========================================")
    println()

    demonstrateBasicSharding()
    demonstrateShardCoordinator()
    demonstrateShardRouting()
    demonstrateShardRebalancing()
    demonstrateCrossRegionSharding()

    println("========================================")
    println("   Cluster Sharding 演示完成!")
    println("========================================")
}