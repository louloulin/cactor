/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - AdaptiveLoadBalancing 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === LoadMetric Tests ===

@Test
func testLoadMetric_values() {
    @Expect(LoadMetric.CpuUsage.toString().size > 0, true)
    @Expect(LoadMetric.MemoryUsage.toString().size > 0, true)
    @Expect(LoadMetric.HeapUsage.toString().size > 0, true)
    @Expect(LoadMetric.LoadAverage.toString().size > 0, true)
}

// === LoadInfo Tests ===

@Test
func testLoadInfo_creation() {
    let info = LoadInfo("node-1", Address("cactor", "test", "host", 2552), 0.5, 0.6, 0.3, 1.0)
    @Expect(info.nodeId, "node-1")
    @Expect(info.cpuUsage, 0.5)
    @Expect(info.memoryUsage, 0.6)
}

@Test
func testLoadInfo_getMetric() {
    let info = LoadInfo("node-1", Address("cactor", "test", "host", 2552), 0.7, 0.5, 0.3, 2.0)
    @Expect(info.getMetric(LoadMetric.CpuUsage), 0.7)
    @Expect(info.getMetric(LoadMetric.MemoryUsage), 0.5)
    @Expect(info.getMetric(LoadMetric.HeapUsage), 0.3)
    @Expect(info.getMetric(LoadMetric.LoadAverage), 2.0)
}

@Test
func testLoadInfo_compositeScore() {
    let info = LoadInfo("node-1", Address("cactor", "test", "host", 2552), 0.5, 0.4, 0.3, 1.0)
    let score = info.compositeScore()
    @Expect(score >= 0.0, true)
    @Expect(score <= 1.0, true)
}

@Test
func testLoadInfo_loadLevel() {
    let lowLoad = LoadInfo("node-1", Address("cactor", "test", "host", 2552), 0.1, 0.1, 0.1, 0.1)
    @Expect(lowLoad.loadLevel(), "LOW")

    let highLoad = LoadInfo("node-2", Address("cactor", "test", "host", 2552), 0.9, 0.9, 0.9, 5.0)
    @Expect(highLoad.loadLevel(), "CRITICAL")
}

// === RoutingDecision Tests ===

@Test
func testRoutingDecision_creation() {
    let decision = RoutingDecision("node-1", Address("cactor", "test", "host", 2552), 0.5, 3)
    @Expect(decision.selectedNodeId, "node-1")
    @Expect(decision.loadScore, 0.5)
    @Expect(decision.alternativeCount, 3)
}

// === AdaptiveLoadBalancingPool Tests ===

@Test
func testAdaptiveLoadBalancingPool_creation() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    @Expect(pool.getPoolId(), "pool-1")
    @Expect(pool.totalNodeCount(), 0)
}

@Test
func testAdaptiveLoadBalancingPool_registerNode() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    let info = LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.3, 0.3, 0.2, 1.0)
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), info)
    @Expect(pool.totalNodeCount(), 1)
    @Expect(pool.healthyNodeCount(), 1)
}

@Test
func testAdaptiveLoadBalancingPool_registerFromNodeMetrics() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    let metrics = NodeMetrics("node-1", Address("cactor", "test", "host1", 2552))
        .addMetric("cpu-usage", 0.4)
        .addMetric("memory-usage", 0.3)
        .addMetric("heap-used", 512.0)
        .addMetric("heap-max", 1024.0)
        .addMetric("load-average", 1.5)
    pool.registerFromNodeMetrics("node-1", Address("cactor", "test", "host1", 2552), metrics)
    @Expect(pool.totalNodeCount(), 1)
}

@Test
func testAdaptiveLoadBalancingPool_updateLoad() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    let info1 = LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.3, 0.3, 0.2, 1.0)
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), info1)

    let info2 = LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.8, 0.8, 0.8, 5.0)
    pool.updateLoad("node-1", info2)
    @Expect(pool.unhealthyNodeCount(), 1)
}

@Test
func testAdaptiveLoadBalancingPool_unregisterNode() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    let info = LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.3, 0.3, 0.2, 1.0)
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), info)
    @Expect(pool.totalNodeCount(), 1)
    let removed = pool.unregisterNode("node-1")
    @Expect(removed.isSome(), true)
    @Expect(pool.totalNodeCount(), 0)
}

@Test
func testAdaptiveLoadBalancingPool_select() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.2, 0.2, 0.5))
    pool.registerNode("node-3", Address("cactor", "test", "host3", 2552), LoadInfo("node-3", Address("cactor", "test", "host3", 2552), 0.4, 0.4, 0.4, 1.0))

    let decision = pool.select()
    @Expect(decision.isSome(), true)
    // node-2 has lowest load, should be selected
    @Expect(decision.getOrThrow().selectedNodeId, "node-2")
}

@Test
func testAdaptiveLoadBalancingPool_selectNoNodes() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    let decision = pool.select()
    @Expect(decision.isNone(), true)
}

@Test
func testAdaptiveLoadBalancingPool_selectMultiple() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.2, 0.2, 0.5))
    pool.registerNode("node-3", Address("cactor", "test", "host3", 2552), LoadInfo("node-3", Address("cactor", "test", "host3", 2552), 0.4, 0.4, 0.4, 1.0))

    let selections = pool.selectMultiple(2)
    @Expect(selections.size, 2)
    // Should be sorted by load, node-2 first
    @Expect(selections[0].selectedNodeId, "node-2")
}

@Test
func testAdaptiveLoadBalancingPool_selectMultipleMoreThanAvailable() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.2, 0.2, 0.5))

    let selections = pool.selectMultiple(10)
    @Expect(selections.size, 2)
}

@Test
func testAdaptiveLoadBalancingPool_selectWithMetric() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.3, 0.3, 2.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.6, 0.3, 1.0))

    let decision = pool.selectWithMetric(LoadMetric.CpuUsage)
    @Expect(decision.isSome(), true)
    @Expect(decision.getOrThrow().selectedNodeId, "node-2") // Lower CPU
}

@Test
func testAdaptiveLoadBalancingPool_getNodeStats() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.2, 0.2, 0.5))

    let stats = pool.getNodeStats()
    @Expect(stats.size, 2)
}

@Test
func testAdaptiveLoadBalancingPool_getLeastLoadedNode() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.8, 0.8, 0.8, 5.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.1, 0.1, 0.1, 0.2))

    let least = pool.getLeastLoadedNode()
    @Expect(least.isSome(), true)
    @Expect(least.getOrThrow().nodeId, "node-2")
}

@Test
func testAdaptiveLoadBalancingPool_getMostLoadedNode() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.1, 0.1, 0.1, 0.2))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.9, 0.9, 0.9, 5.0))

    let most = pool.getMostLoadedNode()
    @Expect(most.isSome(), true)
    @Expect(most.getOrThrow().nodeId, "node-2")
}

@Test
func testAdaptiveLoadBalancingPool_averageLoad() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    @Expect(pool.averageLoad(), 0.0) // No nodes

    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.2, 0.2, 0.2, 0.5))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.4, 0.4, 0.4, 1.5))

    let avg = pool.averageLoad()
    @Expect(avg > 0.0, true)
}

@Test
func testAdaptiveLoadBalancingPool_getNodeRanking() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.6, 0.6, 0.6, 3.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.2, 0.2, 0.5))
    pool.registerNode("node-3", Address("cactor", "test", "host3", 2552), LoadInfo("node-3", Address("cactor", "test", "host3", 2552), 0.4, 0.4, 0.4, 1.5))

    let ranking = pool.getNodeRanking()
    @Expect(ranking.size, 3)
    @Expect(ranking[0].get<0>(), "node-2") // Lowest load first
}

@Test
func testAdaptiveLoadBalancingPool_clear() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    pool.registerNode("node-2", Address("cactor", "test", "host2", 2552), LoadInfo("node-2", Address("cactor", "test", "host2", 2552), 0.2, 0.2, 0.2, 0.5))
    @Expect(pool.totalNodeCount(), 2)
    pool.clear()
    @Expect(pool.totalNodeCount(), 0)
}

@Test
func testAdaptiveLoadBalancingPool_hasHealthyNodes() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    @Expect(pool.hasHealthyNodes(), false)
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    @Expect(pool.hasHealthyNodes(), true)
}

@Test
func testAdaptiveLoadBalancingPool_routeCount() {
    let pool = createAdaptiveLoadBalancingPool("pool-1")
    pool.registerNode("node-1", Address("cactor", "test", "host1", 2552), LoadInfo("node-1", Address("cactor", "test", "host1", 2552), 0.5, 0.5, 0.5, 2.0))
    @Expect(pool.getRouteCount(), 0)
    pool.select()
    @Expect(pool.getRouteCount(), 1)
    pool.select()
    pool.select()
    @Expect(pool.getRouteCount(), 3)
}

// === AdaptiveLoadBalancingConfig Tests ===

@Test
func testAdaptiveLoadBalancingConfig_creation() {
    let metrics = ArrayList<LoadMetric>()
    metrics.append(LoadMetric.CpuUsage)
    metrics.append(LoadMetric.MemoryUsage)
    let weights = HashMap<LoadMetric, Float64>()
    weights.add(LoadMetric.CpuUsage, 0.6)
    weights.add(LoadMetric.MemoryUsage, 0.4)

    let config = AdaptiveLoadBalancingConfig(
        metrics,
        weights,
        20,
        0.9,
        true,
        false,
        Duration.second * 2
    )
    @Expect(config.virtualNodesFactor, 20)
    @Expect(config.mixHealthies, 0.9)
    @Expect(config.允许Unhealthy, true)
}

@Test
func testCreateDefaultAdaptiveLoadBalancingConfig() {
    let config = createDefaultAdaptiveLoadBalancingConfig()
    @Expect(config.virtualNodesFactor, 10)
    @Expect(config.mixHealthies, 0.8)
}

@Test
func testCreateLoadBalancingConfigWithMetrics() {
    let metrics = ArrayList<LoadMetric>()
    metrics.append(LoadMetric.CpuUsage)
    metrics.append(LoadMetric.HeapUsage)
    let config = createLoadBalancingConfigWithMetrics(metrics)
    @Expect(config.metrics.size, 2)
}

// === Unhealthy Node Handling Tests ===

@Test
func testAdaptiveLoadBalancingPool_withUnhealthyNodes() {
    // Create config that allows unhealthy nodes
    let metrics = ArrayList<LoadMetric>()
    metrics.append(LoadMetric.CpuUsage)
    let weights = HashMap<LoadMetric, Float64>()
    weights.add(LoadMetric.CpuUsage, 1.0)
    let config = AdaptiveLoadBalancingConfig(
        metrics, weights, 10, 0.5, true, false, Duration.second * 1
    )
    let pool = createAdaptiveLoadBalancingPoolWithConfig("pool-unhealthy", config)

    // Add unhealthy node
    pool.registerNode("unhealthy-node", Address("cactor", "test", "host", 2552), LoadInfo("unhealthy-node", Address("cactor", "test", "host", 2552), 0.95, 0.95, 0.95, 10.0))
    @Expect(pool.unhealthyNodeCount(), 1)

    // Should still be able to select if no healthy nodes (with allowUnhealthy=true)
    // But we have no healthy nodes, so select should return None
    @Expect(pool.select().isNone(), true)
}