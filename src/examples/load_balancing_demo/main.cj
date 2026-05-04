/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - AdaptiveLoadBalancing 示例程序
 * 展示自适应负载均衡池的使用
 */
package cactor.examples.load_balancing_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 运行基本负载均衡演示
 */
public func runBasicLoadBalancingDemo(): Unit {
    println("=== Basic Load Balancing Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-1")

    println("Registering cluster nodes with different loads...")
    pool.registerNode("worker-1", Address("cactor", "lb", "host1", 2552),
        LoadInfo("worker-1", Address("cactor", "lb", "host1", 2552), 0.3, 0.3, 0.2, 1.0))
    pool.registerNode("worker-2", Address("cactor", "lb", "host2", 2552),
        LoadInfo("worker-2", Address("cactor", "lb", "host2", 2552), 0.7, 0.6, 0.5, 3.5))
    pool.registerNode("worker-3", Address("cactor", "lb", "host3", 2552),
        LoadInfo("worker-3", Address("cactor", "lb", "host3", 2552), 0.1, 0.2, 0.1, 0.5))

    println()
    println("Current pool status:")
    println("  Total nodes: ${pool.totalNodeCount()}")
    println("  Healthy nodes: ${pool.healthyNodeCount()}")

    println()
    println("Selecting best node for routing...")
    let decision = pool.select()
    match (decision) {
        case Some(d) =>
            println("  Selected: ${d.selectedNodeId}")
            println("  Load score: ${d.loadScore}")
            println("  Alternatives: ${d.alternativeCount}")
        case None =>
            println("  No suitable node found")
    }
    println()

    println("Node ranking (by load):")
    let ranking = pool.getNodeRanking()
    for ((nodeId, score) in ranking) {
        println("  ${nodeId}: ${score}")
    }
    println()
}

/**
 * 运行动态负载更新演示
 */
public func runDynamicLoadUpdateDemo(): Unit {
    println("=== Dynamic Load Update Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-2")

    // 初始注册
    pool.registerNode("server-a", Address("cactor", "lb", "server-a", 2552),
        LoadInfo("server-a", Address("cactor", "lb", "server-a", 2552), 0.3, 0.3, 0.3, 1.0))
    pool.registerNode("server-b", Address("cactor", "lb", "server-b", 2552),
        LoadInfo("server-b", Address("cactor", "lb", "server-b", 2552), 0.4, 0.4, 0.4, 2.0))
    pool.registerNode("server-c", Address("cactor", "lb", "server-c", 2552),
        LoadInfo("server-c", Address("cactor", "lb", "server-c", 2552), 0.2, 0.2, 0.2, 0.5))

    println("Initial state:")
    println("  Least loaded: ${pool.getLeastLoadedNode().getOrThrow().nodeId}")
    println("  Most loaded: ${pool.getMostLoadedNode().getOrThrow().nodeId}")

    println()
    println("Simulating server-a becoming overloaded...")
    pool.updateLoad("server-a", LoadInfo("server-a", Address("cactor", "lb", "server-a", 2552), 0.9, 0.9, 0.9, 8.0))

    println()
    println("After overload:")
    println("  Healthy: ${pool.healthyNodeCount()}")
    println("  Unhealthy: ${pool.unhealthyNodeCount()}")
    println("  Least loaded: ${pool.getLeastLoadedNode().getOrThrow().nodeId}")
    println("  Average load: ${pool.averageLoad()}")

    println()
    println("Selecting best node after update...")
    let decision = pool.select()
    match (decision) {
        case Some(d) =>
            println("  Selected: ${d.selectedNodeId}")
        case None => ()
    }
    println()
}

/**
 * 运行多节点选择演示
 */
public func runMultipleSelectionDemo(): Unit {
    println("=== Multiple Node Selection Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-3")

    println("Registering 5 worker nodes...")
    pool.registerNode("node-1", Address("cactor", "lb", "n1", 2552), LoadInfo("node-1", Address("cactor", "lb", "n1", 2552), 0.3, 0.3, 0.3, 1.0))
    pool.registerNode("node-2", Address("cactor", "lb", "n2", 2552), LoadInfo("node-2", Address("cactor", "lb", "n2", 2552), 0.5, 0.5, 0.5, 2.5))
    pool.registerNode("node-3", Address("cactor", "lb", "n3", 2552), LoadInfo("node-3", Address("cactor", "lb", "n3", 2552), 0.2, 0.2, 0.2, 0.5))
    pool.registerNode("node-4", Address("cactor", "lb", "n4", 2552), LoadInfo("node-4", Address("cactor", "lb", "n4", 2552), 0.7, 0.7, 0.7, 4.0))
    pool.registerNode("node-5", Address("cactor", "lb", "n5", 2552), LoadInfo("node-5", Address("cactor", "lb", "n5", 2552), 0.1, 0.1, 0.1, 0.3))

    println()
    println("Selecting 3 least loaded nodes for broadcast...")
    let selections = pool.selectMultiple(3)
    println("  Selected ${selections.size} nodes:")
    for (i in 0..selections.size) {
        println("    ${i + 1}. ${selections[i].selectedNodeId} (score: ${selections[i].loadScore})")
    }
    println()
}

/**
 * 运行特定指标选择演示
 */
public func runSpecificMetricDemo(): Unit {
    println("=== Specific Metric Selection Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-4")

    // 节点在不同指标上有不同表现
    println("Registering nodes with varying metrics...")
    pool.registerNode("high-cpu", Address("cactor", "lb", "high-cpu", 2552),
        LoadInfo("high-cpu", Address("cactor", "lb", "high-cpu", 2552), 0.8, 0.2, 0.2, 1.0)) // High CPU
    pool.registerNode("high-mem", Address("cactor", "lb", "high-mem", 2552),
        LoadInfo("high-mem", Address("cactor", "lb", "high-mem", 2552), 0.2, 0.9, 0.8, 2.0)) // High memory
    pool.registerNode("balanced", Address("cactor", "lb", "balanced", 2552),
        LoadInfo("balanced", Address("cactor", "lb", "balanced", 2552), 0.4, 0.4, 0.4, 1.5)) // Balanced

    println()
    println("Selecting based on different metrics:")

    println()
    println("1. Best CPU:")
    match (pool.selectWithMetric(LoadMetric.CpuUsage)) {
        case Some(d) => println("   Selected: ${d.selectedNodeId} (CPU: ${d.loadScore})")
        case None => ()
    }

    println()
    println("2. Best Memory:")
    match (pool.selectWithMetric(LoadMetric.MemoryUsage)) {
        case Some(d) => println("   Selected: ${d.selectedNodeId} (Memory: ${d.loadScore})")
        case None => ()
    }

    println()
    println("3. Best Heap Usage:")
    match (pool.selectWithMetric(LoadMetric.HeapUsage)) {
        case Some(d) => println("   Selected: ${d.selectedNodeId} (Heap: ${d.loadScore})")
        case None => ()
    }

    println()
    println("4. Default composite score:")
    match (pool.select()) {
        case Some(d) => println("   Selected: ${d.selectedNodeId} (Composite: ${d.loadScore})")
        case None => ()
    }
    println()
}

/**
 * 运行节点统计演示
 */
public func runNodeStatisticsDemo(): Unit {
    println("=== Node Statistics Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-5")

    println("Registering cluster nodes...")
    pool.registerNode("compute-1", Address("cactor", "lb", "comp1", 2552), LoadInfo("compute-1", Address("cactor", "lb", "comp1", 2552), 0.6, 0.3, 0.4, 2.5))
    pool.registerNode("compute-2", Address("cactor", "lb", "comp2", 2552), LoadInfo("compute-2", Address("cactor", "lb", "comp2", 2552), 0.3, 0.7, 0.5, 1.8))
    pool.registerNode("compute-3", Address("cactor", "lb", "comp3", 2552), LoadInfo("compute-3", Address("cactor", "lb", "comp3", 2552), 0.1, 0.2, 0.2, 0.8))

    println()
    println("Pool Statistics:")
    println("  Pool ID: ${pool.getPoolId()}")
    println("  Total nodes: ${pool.totalNodeCount()}")
    println("  Healthy: ${pool.healthyNodeCount()}")
    println("  Unhealthy: ${pool.unhealthyNodeCount()}")
    println("  Route count: ${pool.getRouteCount()}")
    println("  Average load: ${pool.averageLoad()}")

    println()
    println("Node details:")
    let stats = pool.getNodeStats()
    for ((nodeId, loadInfo) in stats) {
        println("  ${nodeId}:")
        println("    Load level: ${loadInfo.loadLevel()}")
        println("    CPU: ${loadInfo.cpuUsage}")
        println("    Memory: ${loadInfo.memoryUsage}")
        println("    Heap: ${loadInfo.heapUsage}")
        println("    Load Avg: ${loadInfo.loadAverage}")
        println("    Composite score: ${loadInfo.compositeScore()}")
    }
    println()
}

/**
 * 运行NodeMetrics集成演示
 */
public func runNodeMetricsIntegrationDemo(): Unit {
    println("=== NodeMetrics Integration Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-6")

    println("Registering nodes from ClusterMetrics...")
    let metrics1 = NodeMetrics("app-1", Address("cactor", "lb", "app1", 2552))
        .addMetric("cpu-usage", 0.35)
        .addMetric("memory-usage", 0.4)
        .addMetric("heap-used", 512.0)
        .addMetric("heap-max", 1024.0)
        .addMetric("load-average", 1.2)
    pool.registerFromNodeMetrics("app-1", Address("cactor", "lb", "app1", 2552), metrics1)

    let metrics2 = NodeMetrics("app-2", Address("cactor", "lb", "app2", 2552))
        .addMetric("cpu-usage", 0.75)
        .addMetric("memory-usage", 0.65)
        .addMetric("heap-used", 768.0)
        .addMetric("heap-max", 1024.0)
        .addMetric("load-average", 3.5)
    pool.registerFromNodeMetrics("app-2", Address("cactor", "lb", "app2", 2552), metrics2)

    let metrics3 = NodeMetrics("app-3", Address("cactor", "lb", "app3", 2552))
        .addMetric("cpu-usage", 0.15)
        .addMetric("memory-usage", 0.25)
        .addMetric("heap-used", 256.0)
        .addMetric("heap-max", 1024.0)
        .addMetric("load-average", 0.5)
    pool.registerFromNodeMetrics("app-3", Address("cactor", "lb", "app3", 2552), metrics3)

    println()
    println("Using adaptive routing for load distribution...")
    for (i in 1..6) {
        match (pool.select()) {
            case Some(d) =>
                println("  Request ${i} -> ${d.selectedNodeId} (score: ${d.loadScore})")
            case None =>
                println("  Request ${i} -> No available nodes")
        }
    }
    println()
    println("Total routes: ${pool.getRouteCount()}")
    println()
}

/**
 * 运行节点注销演示
 */
public func runNodeUnregistrationDemo(): Unit {
    println("=== Node Unregistration Demo ===")
    let pool = createAdaptiveLoadBalancingPool("demo-pool-7")

    println("Registering initial nodes...")
    pool.registerNode("node-a", Address("cactor", "lb", "node-a", 2552), LoadInfo("node-a", Address("cactor", "lb", "node-a", 2552), 0.3, 0.3, 0.3, 1.0))
    pool.registerNode("node-b", Address("cactor", "lb", "node-b", 2552), LoadInfo("node-b", Address("cactor", "lb", "node-b", 2552), 0.5, 0.5, 0.5, 2.0))
    pool.registerNode("node-c", Address("cactor", "lb", "node-c", 2552), LoadInfo("node-c", Address("cactor", "lb", "node-c", 2552), 0.2, 0.2, 0.2, 0.5))

    println()
    println("Before unregistration: ${pool.totalNodeCount()} nodes")
    println("  Selecting: ${pool.select().getOrThrow().selectedNodeId}")

    println()
    println("Unregistering node-b...")
    let removed = pool.unregisterNode("node-b")
    match (removed) {
        case Some(info) => println("  Removed: ${info.nodeId}")
        case None => println("  Not found")
    }

    println()
    println("After unregistration: ${pool.totalNodeCount()} nodes")
    match (pool.select()) {
        case Some(d) =>
            println("  Now selecting: ${d.selectedNodeId}")
        case None => ()
    }
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Adaptive Load Balancing Demo")
    println("=====================================")
    println()

    runBasicLoadBalancingDemo()
    runDynamicLoadUpdateDemo()
    runMultipleSelectionDemo()
    runSpecificMetricDemo()
    runNodeStatisticsDemo()
    runNodeMetricsIntegrationDemo()
    runNodeUnregistrationDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}