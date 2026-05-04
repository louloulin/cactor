/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Metrics 集群指标收集机制
 * 对标 Akka Cluster Metrics
 * 收集和分发集群节点指标，用于负载均衡路由
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 指标值类型
 */
public class MetricValue {
    public let name: String
    public let value: Float64
    public let timestamp: Int64
    public let tags: HashMap<String, String>

    public init(name: String, value: Float64) {
        this.name = name
        this.value = value
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.tags = HashMap<String, String>()
    }

    public func withTag(key: String, val: String): MetricValue {
        let mv = MetricValue(name, this.value)
        for ((k, v) in tags) {
            mv.tags.add(k, v)
        }
        mv.tags.add(key, val)
        mv
    }

    public func isExpired(ttl: Duration): Bool {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        (now - timestamp) > ttl.toMilliseconds()
    }
}

/**
 * 节点指标快照
 */
public class NodeMetrics {
    public let nodeId: String
    public let address: Address
    public let metrics: HashMap<String, MetricValue>
    public let timestamp: Int64

    public init(nodeId: String, address: Address) {
        this.nodeId = nodeId
        this.address = address
        this.metrics = HashMap<String, MetricValue>()
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func addMetric(name: String, value: Float64): NodeMetrics {
        metrics.add(name, MetricValue(name, value))
        this
    }

    public func getMetric(name: String): Option<MetricValue> {
        metrics.get(name)
    }

    public func getMetricValue(name: String): Float64 {
        match (metrics.get(name)) {
            case Some(mv) => mv.value
            case None => 0.0
        }
    }

    public func cpuUsage(): Float64 {
        getMetricValue("cpu-usage")
    }

    public func memoryUsage(): Float64 {
        getMetricValue("memory-usage")
    }

    public func loadAverage(): Float64 {
        getMetricValue("load-average")
    }

    public func heapUsed(): Float64 {
        getMetricValue("heap-used")
    }

    public func heapMax(): Float64 {
        getMetricValue("heap-max")
    }

    public func heapUsage(): Float64 {
        let max = heapMax()
        if (max > 0.0) {
            heapUsed() / max
        } else {
            0.0
        }
    }

    public func metricNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for ((name, _) in metrics) {
            names.add(name)
        }
        names
    }
}

/**
 * 集群指标快照
 */
public class ClusterMetricsSnapshot {
    public let nodeMetrics: HashMap<String, NodeMetrics>
    public let timestamp: Int64

    public init() {
        this.nodeMetrics = HashMap<String, NodeMetrics>()
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func addNodeMetrics(nm: NodeMetrics): ClusterMetricsSnapshot {
        nodeMetrics.add(nm.nodeId, nm)
        this
    }

    public func getNodeMetrics(nodeId: String): Option<NodeMetrics> {
        nodeMetrics.get(nodeId)
    }

    public func getAllNodeMetrics(): ArrayList<NodeMetrics> {
        let result = ArrayList<NodeMetrics>()
        for ((_, nm) in nodeMetrics) {
            result.add(nm)
        }
        result
    }

    public func nodeCount(): Int64 {
        nodeMetrics.size
    }
}

/**
 * 指标收集器接口
 */
public interface MetricsCollector {
    /**
     * 收集当前节点指标
     */
    func collect(): NodeMetrics

    /**
     * 收集器名称
     */
    func name(): String
}

/**
 * 指标事件处理器
 */
public interface MetricsEventHandler {
    /**
     * 节点指标更新
     */
    func onNodeMetricsUpdated(nodeId: String, metrics: NodeMetrics): Unit

    /**
     * 集群指标更新
     */
    func onClusterMetricsUpdated(snapshot: ClusterMetricsSnapshot): Unit
}

/**
 * 指标管理器 - 对标 Akka Cluster Metrics
 * 收集和分发集群指标
 */
public class ClusterMetricsManager {
    private let collectors: ArrayList<MetricsCollector>
    private let snapshot: ClusterMetricsSnapshot
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<MetricsEventHandler>
    private let collectInterval: Duration
    private let metricTtl: Duration

    public init(collectInterval: Duration) {
        this.collectors = ArrayList<MetricsCollector>()
        this.snapshot = ClusterMetricsSnapshot()
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
        this.collectInterval = collectInterval
        this.metricTtl = Duration.minute * 5
    }

    public func setEventHandler(handler: MetricsEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 注册指标收集器
     */
    public func registerCollector(collector: MetricsCollector): Unit {
        lock.writeMutex.lock()
        collectors.add(collector)
        lock.writeMutex.unlock()
    }

    /**
     * 收集所有指标
     */
    public func collectAll(): ClusterMetricsSnapshot {
        lock.writeMutex.lock()
        let newSnapshot = ClusterMetricsSnapshot()
        for (collector in collectors) {
            let nm = collector.collect()
            newSnapshot.addNodeMetrics(nm)
        }
        // 合并现有指标
        for ((nodeId, nm) in snapshot.nodeMetrics) {
            if (newSnapshot.getNodeMetrics(nodeId).isNone()) {
                newSnapshot.addNodeMetrics(nm)
            }
        }
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onClusterMetricsUpdated(newSnapshot)
            case None => ()
        }

        newSnapshot
    }

    /**
     * 更新节点指标
     */
    public func updateNodeMetrics(nodeId: String, metrics: NodeMetrics): Unit {
        lock.writeMutex.lock()
        snapshot.addNodeMetrics(metrics)
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onNodeMetricsUpdated(nodeId, metrics)
            case None => ()
        }
    }

    /**
     * 获取节点指标
     */
    public func getNodeMetrics(nodeId: String): Option<NodeMetrics> {
        lock.readMutex.lock()
        let nm = snapshot.getNodeMetrics(nodeId)
        lock.readMutex.unlock()
        nm
    }

    /**
     * 获取集群指标快照
     */
    public func getSnapshot(): ClusterMetricsSnapshot {
        lock.readMutex.lock()
        let result = ClusterMetricsSnapshot()
        for ((nodeId, nm) in snapshot.nodeMetrics) {
            result.addNodeMetrics(nm)
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取指标值最低的节点（用于负载均衡）
     */
    public func getLeastLoadedNode(metricName: String): Option<String> {
        lock.readMutex.lock()
        var leastNodeId: Option<String> = None
        var leastValue: Float64 = 1e18
        for ((nodeId, nm) in snapshot.nodeMetrics) {
            let mv = nm.getMetric(metricName)
            match (mv) {
                case Some(m) =>
                    if (m.value < leastValue) {
                        leastValue = m.value
                        leastNodeId = Some(nodeId)
                    }
                case None => ()
            }
        }
        lock.readMutex.unlock()
        leastNodeId
    }

    /**
     * 获取所有节点 ID
     */
    public func getNodeIds(): ArrayList<String> {
        lock.readMutex.lock()
        let ids = ArrayList<String>()
        for ((id, _) in snapshot.nodeMetrics) {
            ids.add(id)
        }
        lock.readMutex.unlock()
        ids
    }
}

/**
 * 标准指标收集器
 * 收集节点基本指标（模拟）
 */
public class StandardMetricsCollector <: MetricsCollector {
    private let nodeId: String
    private let address: Address

    public init(nodeId: String, address: Address) {
        this.nodeId = nodeId
        this.address = address
    }

    public func name(): String {
        "standard-metrics-collector"
    }

    public func collect(): NodeMetrics {
        let nm = NodeMetrics(nodeId, address)
        // 模拟收集指标
        nm.addMetric("cpu-usage", 0.0)
        nm.addMetric("memory-usage", 0.0)
        nm.addMetric("heap-used", 0.0)
        nm.addMetric("heap-max", 1073741824.0)
        nm.addMetric("load-average", 0.0)
        nm
    }
}

/**
 * 创建 Cluster Metrics Manager
 */
public func createClusterMetricsManager(collectInterval: Duration): ClusterMetricsManager {
    ClusterMetricsManager(collectInterval)
}
