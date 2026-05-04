/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Metrics 示例程序
 * 展示集群指标收集机制的使用
 */
package cactor.examples.cluster_metrics_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示指标事件处理器
 */
public class DemoMetricsHandler <: MetricsEventHandler {
    public let nodeUpdates = ArrayList<String>()
    public var clusterUpdateCount = 0

    public func onNodeMetricsUpdated(nodeId: String, metrics: NodeMetrics): Unit {
        nodeUpdates.add(nodeId)
        println("  [EVENT] Node metrics updated: ${nodeId}")
        println("    CPU: ${metrics.cpuUsage()}, Memory: ${metrics.memoryUsage()}, Heap: ${metrics.heapUsage()}")
    }

    public func onClusterMetricsUpdated(snapshot: ClusterMetricsSnapshot): Unit {
        clusterUpdateCount += 1
        println("  [EVENT] Cluster metrics updated, ${snapshot.nodeCount()} nodes")
    }
}

/**
 * 自定义指标收集器 - 模拟负载
 */
public class LoadSimulatingCollector <: MetricsCollector {
    private let nodeId: String
    private let address: Address
    private var baseLoad: Float64

    public init(nodeId: String, address: Address) {
        this.nodeId = nodeId
        this.address = address
        this.baseLoad = 0.3
    }

    public func name(): String {
        "load-simulating-collector"
    }

    public func collect(): NodeMetrics {
        let nm = NodeMetrics(nodeId, address)
        // 模拟不同的负载级别
        nm.addMetric("cpu-usage", baseLoad + 0.1)
        nm.addMetric("memory-usage", 0.5)
        nm.addMetric("heap-used", 640.0)
        nm.addMetric("heap-max", 1024.0)
        nm.addMetric("load-average", 2.0)
        nm
    }
}

/**
 * 运行基本指标演示
 */
public func runBasicMetricsDemo(): Unit {
    println("=== Basic Cluster Metrics Demo ===")
    let manager = createClusterMetricsManager(Duration.second * 10)
    let handler = DemoMetricsHandler()
    manager.setEventHandler(handler)

    // 注册标准收集器
    let collector1 = StandardMetricsCollector("node-1", Address("cactor", "metrics", "host1", 2552))
    let collector2 = StandardMetricsCollector("node-2", Address("cactor", "metrics", "host2", 2552))
    manager.registerCollector(collector1)
    manager.registerCollector(collector2)

    println("Collecting metrics...")
    let snapshot = manager.collectAll()
    println()
    println("Collected ${snapshot.nodeCount()} nodes")
    println()
}

/**
 * 运行节点指标更新演示
 */
public func runNodeMetricsUpdateDemo(): Unit {
    println("=== Node Metrics Update Demo ===")
    let manager = createClusterMetricsManager(Duration.second * 30)
    let handler = DemoMetricsHandler()
    manager.setEventHandler(handler)

    // 创建并注册节点指标
    let node1 = NodeMetrics("worker-1", Address("cactor", "metrics", "worker1", 2552))
        .addMetric("cpu-usage", 0.8)
        .addMetric("memory-usage", 0.6)
        .addMetric("heap-used", 768.0)
        .addMetric("heap-max", 1024.0)

    let node2 = NodeMetrics("worker-2", Address("cactor", "metrics", "worker2", 2552))
        .addMetric("cpu-usage", 0.3)
        .addMetric("memory-usage", 0.4)
        .addMetric("heap-used", 256.0)
        .addMetric("heap-max", 1024.0)

    let node3 = NodeMetrics("worker-3", Address("cactor", "metrics", "worker3", 2552))
        .addMetric("cpu-usage", 0.5)
        .addMetric("memory-usage", 0.5)
        .addMetric("heap-used", 512.0)
        .addMetric("heap-max", 1024.0)

    println("Updating node metrics...")
    manager.updateNodeMetrics("worker-1", node1)
    manager.updateNodeMetrics("worker-2", node2)
    manager.updateNodeMetrics("worker-3", node3)
    println()

    // 获取快照
    let snapshot = manager.getSnapshot()
    println("Snapshot contains ${snapshot.nodeCount()} nodes:")
    for (nm in snapshot.getAllNodeMetrics()) {
        println("  ${nm.nodeId}:")
        println("    CPU: ${nm.cpuUsage()}, Memory: ${nm.memoryUsage()}")
        println("    Heap: ${nm.heapUsed()}/${nm.heapMax()} (${nm.heapUsage() * 100.0}%)")
    }
    println()
}

/**
 * 运行负载均衡演示
 */
public func runLoadBalancingDemo(): Unit {
    println("=== Load Balancing Demo ===")
    let manager = createClusterMetricsManager(Duration.second * 30)

    // 创建不同负载的节点
    let nodes = ArrayList<(String, Float64)>()
    nodes.add(("server-1", 0.2))
    nodes.add(("server-2", 0.5))
    nodes.add(("server-3", 0.1))
    nodes.add(("server-4", 0.8))
    nodes.add(("server-5", 0.3))

    println("Registering nodes with different CPU loads:")
    for ((nodeId, cpuLoad) in nodes) {
        let nm = NodeMetrics(nodeId, Address("cactor", "metrics", nodeId, 2552))
            .addMetric("cpu-usage", cpuLoad)
            .addMetric("memory-usage", 0.5)
        manager.updateNodeMetrics(nodeId, nm)
        println("  ${nodeId}: ${Int64(cpuLoad * 100.0)}% CPU")
    }
    println()

    // 查找负载最低的节点
    let leastLoaded = manager.getLeastLoadedNode("cpu-usage")
    match (leastLoaded) {
        case Some(nodeId) =>
            let metrics = manager.getNodeMetrics(nodeId)
            match (metrics) {
                case Some(m) =>
                    println("Least loaded node: ${nodeId}")
                    println("  CPU usage: ${m.cpuUsage()}")
                case None => ()
            }
        case None => println("No nodes available")
    }
    println()

    // 列出所有节点
    let allIds = manager.getNodeIds()
    println("All registered nodes: ${allIds.size}")
    for (id in allIds) {
        match (manager.getNodeMetrics(id)) {
            case Some(m) => println("  ${id}: ${Int64(m.cpuUsage() * 100.0)}% CPU")
            case None => ()
        }
    }
    println()
}

/**
 * 运行指标过期演示
 */
public func runMetricExpirationDemo(): Unit {
    println("=== Metric Expiration Demo ===")
    let mv = MetricValue("test-metric", 0.5)

    println("Created metric with value ${mv.value}")
    println("  Timestamp: ${mv.timestamp}")
    println("  Expired (1s TTL): ${mv.isExpired(Duration.second * 1)}")

    // 模拟旧指标
    let oldMv = MetricValue("old-metric", 0.9)
    println()
    println("Checking old metric expiration...")

    // 注意：实际过期检查需要基于时间戳差值
    // 这里仅演示接口，实际使用时需要模拟时间
    println()
}

/**
 * 运行自定义收集器演示
 */
public func runCustomCollectorDemo(): Unit {
    println("=== Custom Metrics Collector Demo ===")
    let manager = createClusterMetricsManager(Duration.second * 5)

    // 注册自定义收集器
    let customCollector = LoadSimulatingCollector("custom-node", Address("cactor", "metrics", "custom", 2552))
    manager.registerCollector(customCollector)

    println("Using custom LoadSimulatingCollector...")
    println("Collecting metrics multiple times:")
    for (i in 1..4) {
        let snapshot = manager.collectAll()
        match (snapshot.getNodeMetrics("custom-node")) {
            case Some(nm) =>
                println("  Round ${i}: CPU=${nm.cpuUsage()}, Load=${nm.loadAverage()}")
            case None => println("  Round ${i}: No data yet")
        }
    }
    println()
}

/**
 * 运行指标快照演示
 */
public func runSnapshotDemo(): Unit {
    println("=== Cluster Metrics Snapshot Demo ===")
    let manager = createClusterMetricsManager(Duration.second * 30)

    // 添加多个节点
    let hosts = ["app-1", "app-2", "app-3"]
    for (host in hosts) {
        let nm = NodeMetrics(host, Address("cactor", "metrics", host, 2552))
            .addMetric("cpu-usage", 0.5)
            .addMetric("memory-usage", 0.6)
        manager.updateNodeMetrics(host, nm)
    }

    // 获取快照
    let snapshot = manager.getSnapshot()
    println("Cluster snapshot: ${snapshot.nodeCount()} nodes")
    println("Timestamp: ${snapshot.timestamp}")
    println()

    // 遍历快照中的所有节点
    println("All nodes in snapshot:")
    for (nm in snapshot.getAllNodeMetrics()) {
        println("  ${nm.nodeId} @ ${nm.address.host}:${nm.address.port}")
        let names = nm.metricNames()
        println("    Metrics: ${names.size} items")
        for (name in names) {
            match (nm.getMetric(name)) {
                case Some(mv) => println("      ${mv.name} = ${mv.value}")
                case None => ()
            }
        }
    }
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Cluster Metrics Demo")
    println("============================")
    println()

    runBasicMetricsDemo()
    runNodeMetricsUpdateDemo()
    runLoadBalancingDemo()
    runMetricExpirationDemo()
    runCustomCollectorDemo()
    runSnapshotDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}