/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Adaptive Load Balancing Pool 自适应负载均衡池
 * 对标 Akka AdaptiveLoadBalancingPool
 * 基于集群指标的智能路由
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 负载指标类型
 */
public enum LoadMetric {
    CpuUsage
    MemoryUsage
    HeapUsage
    LoadAverage
    Custom(name: String)
}

/**
 * 负载信息
 */
public class LoadInfo {
    public let nodeId: String
    public let address: Address
    public let cpuUsage: Float64
    public let memoryUsage: Float64
    public let heapUsage: Float64
    public let loadAverage: Float64
    public let customMetrics: HashMap<String, Float64>

    public init(nodeId: String, address: Address, cpuUsage: Float64, memoryUsage: Float64, heapUsage: Float64, loadAverage: Float64) {
        this.nodeId = nodeId
        this.address = address
        this.cpuUsage = cpuUsage
        this.memoryUsage = memoryUsage
        this.heapUsage = heapUsage
        this.loadAverage = loadAverage
        this.customMetrics = HashMap<String, Float64>()
    }

    /**
     * 获取指定指标值
     */
    public func getMetric(metric: LoadMetric): Float64 {
        match (metric) {
            case LoadMetric.CpuUsage => cpuUsage
            case LoadMetric.MemoryUsage => memoryUsage
            case LoadMetric.HeapUsage => heapUsage
            case LoadMetric.LoadAverage => loadAverage
            case LoadMetric.Custom(name) =>
                match (customMetrics.get(name)) {
                    case Some(v) => v
                    case None => 0.0
                }
        }
    }

    /**
     * 计算综合负载分数（越低越好）
     */
    public func compositeScore(): Float64 {
        (cpuUsage * 0.4) + (memoryUsage * 0.3) + (heapUsage * 0.2) + (loadAverage / 10.0 * 0.1)
    }

    /**
     * 获取负载等级
     */
    public func loadLevel(): String {
        let score = compositeScore()
        if (score < 0.3) {
            "LOW"
        } else if (score < 0.6) {
            "MEDIUM"
        } else if (score < 0.8) {
            "HIGH"
        } else {
            "CRITICAL"
        }
    }
}

/**
 * 路由决策
 */
public class RoutingDecision {
    public let selectedNodeId: String
    public let selectedAddress: Address
    public let loadScore: Float64
    public let alternativeCount: Int64
    public let timestamp: Int64

    public init(selectedNodeId: String, selectedAddress: Address, loadScore: Float64, alternativeCount: Int64) {
        this.selectedNodeId = selectedNodeId
        this.selectedAddress = selectedAddress
        this.loadScore = loadScore
        this.alternativeCount = alternativeCount
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 自适应负载均衡配置
 */
public class AdaptiveLoadBalancingConfig {
    public let metrics: ArrayList<LoadMetric>
    public let weights: HashMap<LoadMetric, Float64>
    public let virtualNodesFactor: Int64
    public let mixHealthies: Float64
    public let允许Unhealthy: Bool
    public let unsafeMode: Bool
    public let throttleInterval: Duration

    public init(
        metrics: ArrayList<LoadMetric>,
        weights: HashMap<LoadMetric, Float64>,
        virtualNodesFactor: Int64,
        mixHealthies: Float64,
        allowUnhealthy: Bool,
        unsafeMode: Bool,
        throttleInterval: Duration
    ) {
        this.metrics = metrics
        this.weights = weights
        this.virtualNodesFactor = virtualNodesFactor
        this.mixHealthies = mixHealthies
        this.允许Unhealthy = allowUnhealthy
        this.unsafeMode = unsafeMode
        this.throttleInterval = throttleInterval
    }
}

/**
 * 自适应负载均衡池
 * 对标 Akka AdaptiveLoadBalancingPool
 * 根据集群指标动态选择最佳节点
 */
public class AdaptiveLoadBalancingPool {
    private let poolId: String
    private let config: AdaptiveLoadBalancingConfig
    private var healthyNodes: HashMap<String, LoadInfo>
    private var unhealthyNodes: HashMap<String, LoadInfo>
    private let nodeWeights: HashMap<String, Float64>
    private let lock: ReentrantReadWriteMutex
    private var routeCount: Int64
    private var lastRouteTime: Int64

    public init(poolId: String, config: AdaptiveLoadBalancingConfig) {
        this.poolId = poolId
        this.config = config
        this.healthyNodes = HashMap<String, LoadInfo>()
        this.unhealthyNodes = HashMap<String, LoadInfo>()
        this.nodeWeights = HashMap<String, Float64>()
        this.lock = ReentrantReadWriteMutex()
        this.routeCount = 0
        this.lastRouteTime = 0
    }

    /**
     * 注册节点
     */
    public func registerNode(nodeId: String, address: Address, loadInfo: LoadInfo): Unit {
        lock.writeMutex.lock()
        if (loadInfo.compositeScore() < 0.7) {
            healthyNodes.add(nodeId, loadInfo)
        } else {
            if (config.允许Unhealthy) {
                unhealthyNodes.add(nodeId, loadInfo)
            }
        }
        // 初始化权重
        if (!nodeWeights.contains(nodeId)) {
            nodeWeights.add(nodeId, 1.0)
        }
        lock.writeMutex.unlock()
    }

    /**
     * 注册节点（从 NodeMetrics）
     */
    public func registerFromNodeMetrics(nodeId: String, address: Address, nodeMetrics: NodeMetrics): Unit {
        let loadInfo = LoadInfo(
            nodeId,
            address,
            nodeMetrics.cpuUsage(),
            nodeMetrics.memoryUsage(),
            nodeMetrics.heapUsage(),
            nodeMetrics.loadAverage()
        )
        registerNode(nodeId, address, loadInfo)
    }

    /**
     * 更新节点负载
     */
    public func updateLoad(nodeId: String, loadInfo: LoadInfo): Unit {
        lock.writeMutex.lock()
        let score = loadInfo.compositeScore()
        if (score < 0.7) {
            healthyNodes.add(nodeId, loadInfo)
            unhealthyNodes.remove(nodeId)
        } else {
            if (config.允许Unhealthy) {
                unhealthyNodes.add(nodeId, loadInfo)
                healthyNodes.remove(nodeId)
            }
        }
        lock.writeMutex.unlock()
    }

    /**
     * 注销节点
     */
    public func unregisterNode(nodeId: String): Option<LoadInfo> {
        lock.writeMutex.lock()
        let removed = match (healthyNodes.get(nodeId)) {
            case Some(info) =>
                healthyNodes.remove(nodeId)
                nodeWeights.remove(nodeId)
                Some(info)
            case None =>
                match (unhealthyNodes.get(nodeId)) {
                    case Some(info) =>
                        unhealthyNodes.remove(nodeId)
                        nodeWeights.remove(nodeId)
                        Some(info)
                    case None => None
                }
        }
        lock.writeMutex.unlock()
        removed
    }

    /**
     * 选择最佳节点
     */
    public func select(): Option<RoutingDecision> {
        lock.writeMutex.lock()
        if (healthyNodes.size == 0) {
            // 如果允许使用不健康节点
            if (config.允许Unhealthy && unhealthyNodes.size > 0) {
                let firstEntry = unhealthyNodes.getIterator().next()
                match (firstEntry) {
                    case Some((nodeId, loadInfo)) =>
                        lock.writeMutex.unlock()
                        routeCount += 1
                        lastRouteTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                        return Some(RoutingDecision(nodeId, loadInfo.address, loadInfo.compositeScore(), unhealthyNodes.size))
                    case None => ()
                }
            }
            lock.writeMutex.unlock()
            return None
        }

        // 找到负载最低的节点
        var bestNodeId: Option<String> = None
        var bestScore: Float64 = Float64.MaxValue

        for ((nodeId, loadInfo) in healthyNodes) {
            let score = loadInfo.compositeScore()
            if (score < bestScore) {
                bestScore = score
                bestNodeId = Some(nodeId)
            }
        }

        match (bestNodeId) {
            case Some(nodeId) =>
                match (healthyNodes.get(nodeId)) {
                    case Some(loadInfo) =>
                        let decision = RoutingDecision(nodeId, loadInfo.address, loadInfo.compositeScore(), healthyNodes.size)
                        lock.writeMutex.unlock()
                        routeCount += 1
                        lastRouteTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                        return Some(decision)
                    case None =>
                        lock.writeMutex.unlock()
                        return None
                }
            case None =>
                lock.writeMutex.unlock()
                return None
        }
    }

    /**
     * 选择多个节点（用于广播）
     */
    public func selectMultiple(count: Int64): ArrayList<RoutingDecision> {
        let result = ArrayList<RoutingDecision>()
        lock.readMutex.lock()
        let nodesCopy = ArrayList<(String, LoadInfo)>()
        for ((nodeId, loadInfo) in healthyNodes) {
            nodesCopy.add((nodeId, loadInfo))
        }
        lock.readMutex.unlock()

        // 按负载排序
        nodesCopy.sortBy({ (a, b) => a.get<1>().compositeScore() < b.get<1>().compositeScore() })

        let actualCount = if (count > nodesCopy.size) { nodesCopy.size } else { count }
        for (i in 0..actualCount) {
            let (nodeId, loadInfo) = nodesCopy[i]
            result.add(RoutingDecision(nodeId, loadInfo.address, loadInfo.compositeScore(), nodesCopy.size))
        }

        routeCount += actualCount
        lastRouteTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        result
    }

    /**
     * 获取路由决策（基于特定指标）
     */
    public func selectWithMetric(metric: LoadMetric): Option<RoutingDecision> {
        lock.readMutex.lock()
        if (healthyNodes.size == 0) {
            lock.readMutex.unlock()
            return None
        }

        var bestNodeId: Option<String> = None
        var bestValue: Float64 = Float64.MaxValue

        for ((nodeId, loadInfo) in healthyNodes) {
            let value = loadInfo.getMetric(metric)
            if (value < bestValue) {
                bestValue = value
                bestNodeId = Some(nodeId)
            }
        }

        match (bestNodeId) {
            case Some(nodeId) =>
                match (healthyNodes.get(nodeId)) {
                    case Some(loadInfo) =>
                        let decision = RoutingDecision(nodeId, loadInfo.address, loadInfo.getMetric(metric), healthyNodes.size)
                        lock.readMutex.unlock()
                        routeCount += 1
                        lastRouteTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                        return Some(decision)
                    case None =>
                        lock.readMutex.unlock()
                        return None
                }
            case None =>
                lock.readMutex.unlock()
                return None
        }
    }

    /**
     * 获取节点统计
     */
    public func getNodeStats(): HashMap<String, LoadInfo> {
        lock.readMutex.lock()
        let result = HashMap<String, LoadInfo>()
        for ((nodeId, loadInfo) in healthyNodes) {
            result.add(nodeId, loadInfo)
        }
        for ((nodeId, loadInfo) in unhealthyNodes) {
            if (!result.contains(nodeId)) {
                result.add(nodeId, loadInfo)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取健康节点数量
     */
    public func healthyNodeCount(): Int64 {
        lock.readMutex.lock()
        let count = healthyNodes.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取不健康节点数量
     */
    public func unhealthyNodeCount(): Int64 {
        lock.readMutex.lock()
        let count = unhealthyNodes.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取总节点数量
     */
    public func totalNodeCount(): Int64 {
        lock.readMutex.lock()
        let count = healthyNodes.size + unhealthyNodes.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取路由次数
     */
    public func getRouteCount(): Int64 {
        lock.readMutex.lock()
        let count = routeCount
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取池 ID
     */
    public func getPoolId(): String {
        poolId
    }

    /**
     * 获取配置
     */
    public func getConfig(): AdaptiveLoadBalancingConfig {
        config
    }

    /**
     * 获取最繁忙的节点
     */
    public func getMostLoadedNode(): Option<LoadInfo> {
        lock.readMutex.lock()
        var worstNodeId: Option<String> = None
        var worstScore: Float64 = Float64.MinValue

        for ((nodeId, loadInfo) in healthyNodes) {
            let score = loadInfo.compositeScore()
            if (score > worstScore) {
                worstScore = score
                worstNodeId = Some(nodeId)
            }
        }

        match (worstNodeId) {
            case Some(nodeId) =>
                let result = healthyNodes.get(nodeId)
                lock.readMutex.unlock()
                result
            case None =>
                lock.readMutex.unlock()
                None
        }
    }

    /**
     * 获取最空闲的节点
     */
    public func getLeastLoadedNode(): Option<LoadInfo> {
        lock.readMutex.lock()
        var bestNodeId: Option<String> = None
        var bestScore: Float64 = Float64.MaxValue

        for ((nodeId, loadInfo) in healthyNodes) {
            let score = loadInfo.compositeScore()
            if (score < bestScore) {
                bestScore = score
                bestNodeId = Some(nodeId)
            }
        }

        match (bestNodeId) {
            case Some(nodeId) =>
                let result = healthyNodes.get(nodeId)
                lock.readMutex.unlock()
                result
            case None =>
                lock.readMutex.unlock()
                None
        }
    }

    /**
     * 获取平均负载
     */
    public func averageLoad(): Float64 {
        lock.readMutex.lock()
        if (healthyNodes.size == 0) {
            lock.readMutex.unlock()
            return 0.0
        }
        var total: Float64 = 0.0
        for ((_, loadInfo) in healthyNodes) {
            total += loadInfo.compositeScore()
        }
        let avg = total / Float64(healthyNodes.size)
        lock.readMutex.unlock()
        avg
    }

    /**
     * 检查是否有健康节点
     */
    public func hasHealthyNodes(): Bool {
        lock.readMutex.lock()
        let result = healthyNodes.size > 0
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取节点负载排名
     */
    public func getNodeRanking(): ArrayList<(String, Float64)> {
        lock.readMutex.lock()
        let result = ArrayList<(String, Float64)>()
        for ((nodeId, loadInfo) in healthyNodes) {
            result.add((nodeId, loadInfo.compositeScore()))
        }
        lock.readMutex.unlock()
        result.sortBy({ (a, b) => a.get<1>() < b.get<1>() })
        result
    }

    /**
     * 清除所有节点
     */
    public func clear(): Unit {
        lock.writeMutex.lock()
        healthyNodes.clear()
        unhealthyNodes.clear()
        nodeWeights.clear()
        lock.writeMutex.unlock()
    }

    /**
     * 获取上次路由时间
     */
    public func getLastRouteTime(): Int64 {
        lock.readMutex.lock()
        let time = lastRouteTime
        lock.readMutex.unlock()
        time
    }
}

/**
 * 创建自适应负载均衡池
 */
public func createAdaptiveLoadBalancingPool(poolId: String): AdaptiveLoadBalancingPool {
    let metrics = ArrayList<LoadMetric>()
    metrics.append(LoadMetric.CpuUsage)
    metrics.append(LoadMetric.MemoryUsage)
    metrics.append(LoadMetric.HeapUsage)
    metrics.append(LoadMetric.LoadAverage)

    let weights = HashMap<LoadMetric, Float64>()
    weights.add(LoadMetric.CpuUsage, 0.4)
    weights.add(LoadMetric.MemoryUsage, 0.3)
    weights.add(LoadMetric.HeapUsage, 0.2)
    weights.add(LoadMetric.LoadAverage, 0.1)

    let config = AdaptiveLoadBalancingConfig(
        metrics,
        weights,
        10,                      // virtualNodesFactor
        0.8,                      // mixHealthies
        false,                    // allowUnhealthy
        false,                    // unsafeMode
        Duration.second * 1      // throttleInterval
    )

    AdaptiveLoadBalancingPool(poolId, config)
}

/**
 * 创建带配置的负载均衡池
 */
public func createAdaptiveLoadBalancingPoolWithConfig(poolId: String, config: AdaptiveLoadBalancingConfig): AdaptiveLoadBalancingPool {
    AdaptiveLoadBalancingPool(poolId, config)
}

/**
 * 创建默认配置
 */
public func createDefaultAdaptiveLoadBalancingConfig(): AdaptiveLoadBalancingConfig {
    let metrics = ArrayList<LoadMetric>()
    metrics.append(LoadMetric.CpuUsage)
    metrics.append(LoadMetric.MemoryUsage)
    metrics.append(LoadMetric.HeapUsage)

    let weights = HashMap<LoadMetric, Float64>()
    weights.add(LoadMetric.CpuUsage, 0.5)
    weights.add(LoadMetric.MemoryUsage, 0.3)
    weights.add(LoadMetric.HeapUsage, 0.2)

    AdaptiveLoadBalancingConfig(
        metrics,
        weights,
        10,
        0.8,
        false,
        false,
        Duration.second * 1
    )
}

/**
 * 创建自定义指标的负载均衡池配置
 */
public func createLoadBalancingConfigWithMetrics(metrics: ArrayList<LoadMetric>): AdaptiveLoadBalancingConfig {
    let weights = HashMap<LoadMetric, Float64>()
    var totalWeight: Float64 = 1.0
    let weightPerMetric = totalWeight / Float64(metrics.size)

    for (metric in metrics) {
        weights.add(metric, weightPerMetric)
    }

    AdaptiveLoadBalancingConfig(
        metrics,
        weights,
        10,
        0.8,
        false,
        false,
        Duration.second * 1
    )
}