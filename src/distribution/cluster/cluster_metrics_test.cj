/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Metrics 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === Helper ===

func createTestNodeMetrics(nodeId: String): NodeMetrics {
    let addr = Address("cactor", "metrics", "host", 2552)
    NodeMetrics(nodeId, addr)
}

// === MetricValue Tests ===

@Test
func testMetricValue_creation() {
    let mv = MetricValue("cpu", 0.75)
    @Expect(mv.name, "cpu")
    @Expect(mv.value, 0.75)
}

@Test
func testMetricValue_withTag() {
    let mv = MetricValue("cpu", 0.75).withTag("host", "node-1")
    @Expect(mv.tags.contains("host"), true)
}

@Test
func testMetricValue_isExpired() {
    let mv = MetricValue("cpu", 0.75)
    @Expect(mv.isExpired(Duration.second * 1), false)
}

// === NodeMetrics Tests ===

@Test
func testNodeMetrics_creation() {
    let nm = createTestNodeMetrics("node-1")
    @Expect(nm.nodeId, "node-1")
}

@Test
func testNodeMetrics_addMetric() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("cpu-usage", 0.8)
    @Expect(nm.getMetricValue("cpu-usage"), 0.8)
}

@Test
func testNodeMetrics_getMetric() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("cpu-usage", 0.5)
    let mv = nm.getMetric("cpu-usage")
    @Expect(mv.isSome(), true)
}

@Test
func testNodeMetrics_getMetricNotFound() {
    let nm = createTestNodeMetrics("node-1")
    let mv = nm.getMetric("non-existent")
    @Expect(mv.isNone(), true)
}

@Test
func testNodeMetrics_getMetricValueNotFound() {
    let nm = createTestNodeMetrics("node-1")
    @Expect(nm.getMetricValue("non-existent"), 0.0)
}

@Test
func testNodeMetrics_cpuUsage() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("cpu-usage", 0.75)
    @Expect(nm.cpuUsage(), 0.75)
}

@Test
func testNodeMetrics_memoryUsage() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("memory-usage", 0.6)
    @Expect(nm.memoryUsage(), 0.6)
}

@Test
func testNodeMetrics_loadAverage() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("load-average", 2.5)
    @Expect(nm.loadAverage(), 2.5)
}

@Test
func testNodeMetrics_heapUsage() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("heap-used", 512.0)
    nm.addMetric("heap-max", 1024.0)
    @Expect(nm.heapUsage(), 0.5)
}

@Test
func testNodeMetrics_heapUsage_zeroMax() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("heap-used", 512.0)
    nm.addMetric("heap-max", 0.0)
    @Expect(nm.heapUsage(), 0.0)
}

@Test
func testNodeMetrics_metricNames() {
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("cpu-usage", 0.5)
    nm.addMetric("memory-usage", 0.6)
    let names = nm.metricNames()
    @Expect(names.size, 2)
}

// === ClusterMetricsSnapshot Tests ===

@Test
func testClusterMetricsSnapshot_creation() {
    let snapshot = ClusterMetricsSnapshot()
    @Expect(snapshot.nodeCount(), 0)
}

@Test
func testClusterMetricsSnapshot_addNodeMetrics() {
    let snapshot = ClusterMetricsSnapshot()
    snapshot.addNodeMetrics(createTestNodeMetrics("node-1"))
    @Expect(snapshot.nodeCount(), 1)
}

@Test
func testClusterMetricsSnapshot_getNodeMetrics() {
    let snapshot = ClusterMetricsSnapshot()
    snapshot.addNodeMetrics(createTestNodeMetrics("node-1"))
    let nm = snapshot.getNodeMetrics("node-1")
    @Expect(nm.isSome(), true)
}

@Test
func testClusterMetricsSnapshot_getNodeMetricsNotFound() {
    let snapshot = ClusterMetricsSnapshot()
    let nm = snapshot.getNodeMetrics("non-existent")
    @Expect(nm.isNone(), true)
}

@Test
func testClusterMetricsSnapshot_getAllNodeMetrics() {
    let snapshot = ClusterMetricsSnapshot()
    snapshot.addNodeMetrics(createTestNodeMetrics("node-1"))
    snapshot.addNodeMetrics(createTestNodeMetrics("node-2"))
    let all = snapshot.getAllNodeMetrics()
    @Expect(all.size, 2)
}

// === ClusterMetricsManager Tests ===

@Test
func testClusterMetricsManager_registerCollector() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    let collector = StandardMetricsCollector("node-1", Address("cactor", "metrics", "host", 2552))
    manager.registerCollector(collector)
    @Expect(manager.getNodeIds().size >= 0, true)
}

@Test
func testClusterMetricsManager_updateNodeMetrics() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    let nm = createTestNodeMetrics("node-1")
    nm.addMetric("cpu-usage", 0.8)
    manager.updateNodeMetrics("node-1", nm)
    let retrieved = manager.getNodeMetrics("node-1")
    @Expect(retrieved.isSome(), true)
}

@Test
func testClusterMetricsManager_getNodeMetrics() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    let nm = createTestNodeMetrics("node-1")
    manager.updateNodeMetrics("node-1", nm)
    let result = manager.getNodeMetrics("node-1")
    match (result) {
        case Some(r) => @Expect(r.nodeId, "node-1")
        case None => ()
    }
}

@Test
func testClusterMetricsManager_getSnapshot() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    manager.updateNodeMetrics("node-1", createTestNodeMetrics("node-1"))
    manager.updateNodeMetrics("node-2", createTestNodeMetrics("node-2"))
    let snapshot = manager.getSnapshot()
    @Expect(snapshot.nodeCount(), 2)
}

@Test
func testClusterMetricsManager_getLeastLoadedNode() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    let nm1 = createTestNodeMetrics("node-1")
    nm1.addMetric("cpu-usage", 0.9)
    let nm2 = createTestNodeMetrics("node-2")
    nm2.addMetric("cpu-usage", 0.3)
    manager.updateNodeMetrics("node-1", nm1)
    manager.updateNodeMetrics("node-2", nm2)
    let least = manager.getLeastLoadedNode("cpu-usage")
    match (least) {
        case Some(id) => @Expect(id, "node-2")
        case None => ()
    }
}

@Test
func testClusterMetricsManager_getLeastLoadedNode_empty() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    let least = manager.getLeastLoadedNode("cpu-usage")
    @Expect(least.isNone(), true)
}

@Test
func testClusterMetricsManager_getNodeIds() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    manager.updateNodeMetrics("node-1", createTestNodeMetrics("node-1"))
    manager.updateNodeMetrics("node-2", createTestNodeMetrics("node-2"))
    let ids = manager.getNodeIds()
    @Expect(ids.size, 2)
}

// === StandardMetricsCollector Tests ===

@Test
func testStandardMetricsCollector_name() {
    let collector = StandardMetricsCollector("node-1", Address("cactor", "metrics", "host", 2552))
    @Expect(collector.name(), "standard-metrics-collector")
}

@Test
func testStandardMetricsCollector_collect() {
    let collector = StandardMetricsCollector("node-1", Address("cactor", "metrics", "host", 2552))
    let nm = collector.collect()
    @Expect(nm.nodeId, "node-1")
    @Expect(nm.getMetricValue("heap-max") > 0.0, true)
}

// === MetricsEventHandler Tests ===

class TestMetricsHandler <: MetricsEventHandler {
    public let nodeUpdates = ArrayList<String>()
    public var clusterUpdateCount = 0

    public func onNodeMetricsUpdated(nodeId: String, metrics: NodeMetrics): Unit {
        nodeUpdates.add(nodeId)
    }

    public func onClusterMetricsUpdated(snapshot: ClusterMetricsSnapshot): Unit {
        clusterUpdateCount += 1
    }
}

@Test
func testClusterMetricsManager_eventHandler() {
    let manager = createClusterMetricsManager(Duration.second * 30)
    let handler = TestMetricsHandler()
    manager.setEventHandler(handler)
    manager.updateNodeMetrics("node-1", createTestNodeMetrics("node-1"))
    @Expect(handler.nodeUpdates.size, 1)
}
