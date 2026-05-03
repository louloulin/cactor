/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster HA 分片协调器演示
 * 展示 HA 分片协调器的功能
 */
package cactor.examples.cluster_ha_demo

import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorPath}
import cactor.core.message.{Message, MessageResult}
import cactor.distribution.cluster.*

/**
 * HA 协调器事件处理器实现
 */
class DemoCoordinatorHandler <: ShardCoordinatorEventHandler {
    public let stateChanges = ArrayList<String>()
    public let shardAllocations = ArrayList<(String, String)>()
    public let rebalanceEvents = ArrayList<Array<String>>()

    public func onCoordinatorStateChange(oldState: CoordinatorState, newState: CoordinatorState): Unit {
        let msg = "状态变更: ${oldState.toString()} -> ${newState.toString()}"
        stateChanges.add(msg)
        println("[Handler] ${msg}")
    }

    public func onShardAllocated(shardId: String, nodeAddress: Address): Unit {
        let msg = "分片分配: shard=${shardId} -> node=${nodeAddress.toString()}"
        shardAllocations.add((shardId, nodeAddress.toString()))
        println("[Handler] ${msg}")
    }

    public func onShardDeallocated(shardId: String): Unit {
        println("[Handler] 分片取消分配: shard=${shardId}")
    }

    public func onRebalanceRequired(shardIds: Array<String>): Unit {
        let msg = "触发再平衡: ${shardIds.size} 个分片需要迁移"
        rebalanceEvents.add(shardIds)
        println("[Handler] ${msg}")
    }
}

/**
 * HA 协调器演示
 */
public func runHAShardCoordinatorDemo(): Unit {
    println("=== HA 分片协调器演示 ===")
    println("")

    // 创建本地地址
    let localAddress = Address("cactor", "demo-system", "localhost", 2552)
    println("创建 HA 分片协调器: ${localAddress.toString()}")
    println("")

    // 创建 HA 协调器
    let coordinator = createHAShardCoordinator(localAddress)
    let handler = DemoCoordinatorHandler()
    coordinator.setEventHandler(handler)

    // 启动协调器
    println("1. 启动协调器...")
    coordinator.start()
    println("")

    // 检查状态
    println("2. 检查协调器状态...")
    let state = coordinator.getState()
    let isLeader = coordinator.isLeaderNode()
    println("   状态: ${state.toString()}")
    println("   是否为 Leader: ${isLeader}")
    println("")

    // 获取统计数据
    println("3. 获取统计数据...")
    let stats = coordinator.getStats()
    println("   ${stats.toString()}")
    println("")

    // 分配分片
    println("4. 分配分片...")
    let node1 = Address("cactor", "demo-system", "node1.local", 2552)
    let node2 = Address("cactor", "demo-system", "node2.local", 2552)
    let node3 = Address("cactor", "demo-system", "node3.local", 2552)

    coordinator.allocateShard("shard-1", node1)
    coordinator.allocateShard("shard-2", node1)
    coordinator.allocateShard("shard-3", node2)
    coordinator.allocateShard("shard-4", node2)
    coordinator.allocateShard("shard-5", node3)
    println("")

    // 获取分配信息
    println("5. 获取分配信息...")
    let shard1Loc = coordinator.getShardLocation("shard-1")
    match (shard1Loc) {
        case Some(addr) => println("   shard-1 位置: ${addr.toString()}")
        case None => println("   shard-1 未分配")
    }
    let allAllocations = coordinator.getAllAllocations()
    println("   总分配数: ${allAllocations.size}")
    println("")

    // 获取节点分片映射
    println("6. 获取节点分片映射...")
    let nodeMap = coordinator.getNodeShardMap()
    for ((nodeKey, shards) in nodeMap) {
        println("   节点 ${nodeKey}: ${shards.size} 个分片")
    }
    println("")

    // 获取统计
    println("7. 更新后的统计数据...")
    let stats2 = coordinator.getStats()
    println("   ${stats2.toString()}")
    println("")

    // 测试节点移除
    println("8. 模拟节点移除...")
    coordinator.removeNode(node1)
    println("   已移除 node1")
    let stats3 = coordinator.getStats()
    println("   移除后: ${stats3.toString()}")
    println("")

    // 停止协调器
    println("9. 停止协调器...")
    coordinator.stop()
    println("")

    // 显示事件日志
    println("10. 事件日志:")
    for (change in handler.stateChanges) {
        println("    - ${change}")
    }
    println("")

    println("=== HA 分片协调器演示完成 ===")
}

/**
 * CoordinatorState 状态转换演示
 */
public func runCoordinatorStateDemo(): Unit {
    println("=== CoordinatorState 状态转换演示 ===")
    println("")

    let states = [
        CoordinatorState.INACTIVE,
        CoordinatorState.ACTIVATING,
        CoordinatorState.ACTIVE,
        CoordinatorState.PASSIVE
    ]

    for (state in states) {
        println("- ${state.toString()}: isActive=${state.isActive()}")
    }
    println("")

    println("=== CoordinatorState 演示完成 ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    println("")
    println("========================================")
    println("  CActor Cluster HA 分片协调器演示")
    println("========================================")
    println("")

    // 状态转换演示
    runCoordinatorStateDemo()
    println("")

    // HA 协调器演示
    runHAShardCoordinatorDemo()
    println("")

    println("演示完成!")
}