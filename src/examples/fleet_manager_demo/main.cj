/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Fleet Manager 示例程序
 * 展示集群节点管理机制的使用
 */
package cactor.examples.fleet_manager_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示事件处理器
 */
public class DemoFleetHandler <: FleetEventHandler {
    public let joined = ArrayList<String>()
    public let up = ArrayList<String>()
    public let left = ArrayList<String>()
    public let down = ArrayList<String>()
    public let removed = ArrayList<String>()

    public func onNodeJoined(node: FleetNode): Unit {
        joined.add(node.nodeId)
        println("  [EVENT] Node joined: ${node.nodeId}")
    }

    public func onNodeUp(node: FleetNode): Unit {
        up.add(node.nodeId)
        println("  [EVENT] Node up: ${node.nodeId}")
    }

    public func onNodeLeft(node: FleetNode): Unit {
        left.add(node.nodeId)
        println("  [EVENT] Node left: ${node.nodeId}")
    }

    public func onNodeDown(node: FleetNode): Unit {
        down.add(node.nodeId)
        println("  [EVENT] Node down: ${node.nodeId}")
    }

    public func onNodeRemoved(node: FleetNode): Unit {
        removed.add(node.nodeId)
        println("  [EVENT] Node removed: ${node.nodeId}")
    }

    public func onHealthChanged(node: FleetNode, oldHealth: NodeHealth, newHealth: NodeHealth): Unit {
        println("  [EVENT] Health changed: ${node.nodeId} from ${oldHealth} to ${newHealth}")
    }
}

/**
 * 运行基本操作演示
 */
public func runBasicOperationsDemo(): Unit {
    println("=== Basic Fleet Manager Operations ===")
    let manager = createFleetManager("demo-fleet")
    let handler = DemoFleetHandler()
    manager.setEventHandler(handler)

    println("Registering nodes...")
    manager.registerNode(FleetNode("node-1", Address("cactor", "fleet", "host1", 2552)))
    manager.registerNode(FleetNode("node-2", Address("cactor", "fleet", "host2", 2552)))
    manager.registerNode(FleetNode("node-3", Address("cactor", "fleet", "host3", 2552)))

    println("Bringing nodes up...")
    manager.nodeUp(FleetNode("node-1", Address("cactor", "fleet", "host1", 2552)))
    manager.nodeUp(FleetNode("node-2", Address("cactor", "fleet", "host2", 2552)))
    manager.nodeUp(FleetNode("node-3", Address("cactor", "fleet", "host3", 2552)))

    println()
    println("Fleet status:")
    println("  Total nodes: ${manager.nodeCount()}")
    println("  Active nodes: ${manager.activeNodeCount()}")
    println("  Is all healthy: ${manager.isAllHealthy()}")
    println()
}

/**
 * 运行健康检查演示
 */
public func runHealthCheckDemo(): Unit {
    println("=== Health Check Demo ===")
    let manager = createFleetManager("health-fleet")
    let handler = DemoFleetHandler()
    manager.setEventHandler(handler)

    // 注册并上线节点
    manager.registerNode(FleetNode("worker-1", Address("cactor", "fleet", "worker1", 2552)))
    manager.registerNode(FleetNode("worker-2", Address("cactor", "fleet", "worker2", 2552)))
    manager.registerNode(FleetNode("worker-3", Address("cactor", "fleet", "worker3", 2552)))
    manager.nodeUp(FleetNode("worker-1", Address("cactor", "fleet", "worker1", 2552)))
    manager.nodeUp(FleetNode("worker-2", Address("cactor", "fleet", "worker2", 2552)))
    manager.nodeUp(FleetNode("worker-3", Address("cactor", "fleet", "worker3", 2552)))

    // 设置健康状态
    manager.updateHealth("worker-1", NodeHealth.Healthy)
    manager.updateHealth("worker-2", NodeHealth.Healthy)
    manager.updateHealth("worker-3", NodeHealth.Healthy)

    println("Initial health status: all healthy")
    println("  Healthy nodes: ${manager.getHealthyNodes().size}")
    println("  Health ratio: ${manager.healthRatio()}")

    // 模拟节点降级
    println()
    println("Simulating node degradation...")
    manager.updateHealth("worker-2", NodeHealth.Degraded)

    println()
    println("After degradation:")
    println("  Healthy nodes: ${manager.getHealthyNodes().size}")
    println("  Unhealthy nodes: ${manager.getUnhealthyNodes().size}")
    println("  Health ratio: ${manager.healthRatio()}")

    // 模拟节点恢复
    println()
    println("Simulating recovery...")
    manager.updateHealth("worker-2", NodeHealth.Healthy)

    println()
    println("After recovery:")
    println("  Health ratio: ${manager.healthRatio()}")
    println()
}

/**
 * 运行节点生命周期演示
 */
public func runLifecycleDemo(): Unit {
    println("=== Node Lifecycle Demo ===")
    let manager = createFleetManager("lifecycle-fleet")
    let handler = DemoFleetHandler()
    manager.setEventHandler(handler)

    println("1. Registering node...")
    manager.registerNode(FleetNode("lifecycle-node", Address("cactor", "fleet", "node", 2552)))

    println("2. Bringing node up...")
    manager.nodeUp(FleetNode("lifecycle-node", Address("cactor", "fleet", "node", 2552)))
    manager.updateHealth("lifecycle-node", NodeHealth.Healthy)

    println("3. Simulating work...")
    println("  Node status: ${manager.getNode("lifecycle-node").getOrThrow().status}")

    println("4. Node leaving cluster...")
    manager.nodeLeft("lifecycle-node")

    println("5. Node down (detected by cluster)...")
    manager.nodeDown("lifecycle-node")

    println("6. Node removed (cleanup)...")
    manager.removeNode("lifecycle-node")

    println()
    println("Final state: ${manager.nodeCount()} nodes")
    println()
}

/**
 * 运行故障转移演示
 */
public func runFailoverDemo(): Unit {
    println("=== Failover Demo ===")
    let manager = createFleetManager("failover-fleet")
    let handler = DemoFleetHandler()
    manager.setEventHandler(handler)

    // 初始化 5 个节点
    println("Initializing 5 nodes...")
    for (i in 1..6) {
        let nodeId = "node-${i}"
        let addr = Address("cactor", "fleet", "host${i}", 2552)
        manager.registerNode(FleetNode(nodeId, addr))
        manager.nodeUp(FleetNode(nodeId, addr))
        manager.updateHealth(nodeId, NodeHealth.Healthy)
    }

    println("Initial active nodes: ${manager.activeNodeCount()}")
    println("Health ratio: ${manager.healthRatio()}")
    println()

    // 模拟节点故障
    println("Simulating node failures...")
    manager.updateHealth("node-3", NodeHealth.Unhealthy)
    manager.updateHealth("node-4", NodeHealth.Unhealthy)
    manager.nodeDown("node-5")

    println()
    println("After failures:")
    println("  Active nodes: ${manager.activeNodeCount()}")
    println("  Healthy nodes: ${manager.getHealthyNodes().size}")
    println("  Unhealthy nodes: ${manager.getUnhealthyNodes().size}")
    println("  Health ratio: ${manager.healthRatio()}")

    // 恢复故障节点
    println()
    println("Recovering failed nodes...")
    manager.updateHealth("node-3", NodeHealth.Healthy)
    manager.updateHealth("node-4", NodeHealth.Healthy)
    manager.nodeUp(FleetNode("node-5", Address("cactor", "fleet", "host5", 2552)))

    println()
    println("After recovery:")
    println("  Active nodes: ${manager.activeNodeCount()}")
    println("  Health ratio: ${manager.healthRatio()}")
    println()
}

/**
 * 运行节点选择演示
 */
public func runSelectionDemo(): Unit {
    println("=== Node Selection Demo ===")
    let manager = createFleetManager("selection-fleet")

    // 创建不同状态的节点
    let healthyNode = FleetNode("healthy-1", Address("cactor", "fleet", "h1", 2552))
    let healthyAddr = healthyNode.address

    manager.registerNode(healthyNode)
    manager.nodeUp(healthyNode)
    manager.updateHealth("healthy-1", NodeHealth.Healthy)

    manager.registerNode(FleetNode("healthy-2", Address("cactor", "fleet", "h2", 2552)))
    manager.nodeUp(FleetNode("healthy-2", Address("cactor", "fleet", "h2", 2552)))
    manager.updateHealth("healthy-2", NodeHealth.Healthy)

    let degradedNode = FleetNode("degraded-1", Address("cactor", "fleet", "d1", 2552))
    manager.registerNode(degradedNode)
    manager.nodeUp(degradedNode)
    manager.updateHealth("degraded-1", NodeHealth.Degraded)

    println("Node selection scenarios:")
    println()

    println("1. Select healthy node for critical task:")
    let healthy = manager.getHealthyNodes()
    match (healthy.size > 0) {
        case true => println("   Selected: ${healthy[0].nodeId}")
        case false => println("   No healthy nodes available")
    }

    println("2. Select any active node for normal task:")
    let active = manager.getActiveNodes()
    match (active.size > 0) {
        case true => println("   Available: ${active.size} nodes")
        case false => println("   No active nodes")
    }

    println("3. Check all nodes status:")
    let all = manager.getAllNodes()
    for (node in all) {
        println("   ${node.nodeId}: status=${node.status}, health=${node.health}")
    }

    println()
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    println("CActor Fleet Manager Demo")
    println("==========================")
    println()

    runBasicOperationsDemo()
    runHealthCheckDemo()
    runLifecycleDemo()
    runFailoverDemo()
    runSelectionDemo()

    println("=== Demo Complete ===")
}
