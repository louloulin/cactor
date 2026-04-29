/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级路由器工厂系统
 * 基于plan3.md Phase 6设计，支持多种路由器类型的创建和管理
 */
package cactor.patterns.routing.factory

import std.time.*
import std.collection.*
import cactor.core.message.Message
import cactor.core.actor.ActorRef
import cactor.patterns.routing.{
    RoutingStrategy,
    Router,
    BasicRouter,
    RoundRobinRoutingStrategy,
    RandomRoutingStrategy,
    ConsistentHashRoutingStrategy,
    BroadcastRoutingStrategy,
    RouterFactory
}
import cactor.patterns.routing.advanced.{
    AdvancedRouter,
    AdvancedRoutingStrategyFactory,
    WeightedRoundRobinRoutingStrategy,
    LeastConnectionsRoutingStrategy,
    FastestResponseRoutingStrategy,
    FailoverRoutingStrategy,
    ContentBasedRoutingStrategy
}

/**
 * 路由器类型枚举
 */
public enum RouterType {
    | RoundRobin           // 轮询路由
    | Random               // 随机路由
    | ConsistentHash       // 一致性哈希路由
    | Broadcast            // 广播路由
    | WeightedRoundRobin   // 加权轮询路由
    | LeastConnections     // 最少连接路由
    | FastestResponse      // 最快响应路由
    | Failover             // 故障转移路由
    | ContentBased         // 基于内容路由
    | Custom               // 自定义路由
}

/**
 * 路由器配置
 */
public class RouterConfig {
    public let routerType: RouterType
    public let name: String
    public let description: String
    public let weights: Array<Int32>
    public let primaryIndex: Int32
    public let contentSelector: Option<(Message) -> String>
    public let customStrategy: Option<RoutingStrategy>
    
    public init(
        routerType: RouterType,
        name: String
    ) {
        this.routerType = routerType
        this.name = name
        this.description = ""
        this.weights = Array<Int32>(0, { _ => 0 })
        this.primaryIndex = 0
        this.contentSelector = None
        this.customStrategy = None
    }

    public init(
        routerType: RouterType,
        name: String,
        description: String,
        weights: Array<Int32>,
        primaryIndex: Int32,
        contentSelector: Option<(Message) -> String>,
        customStrategy: Option<RoutingStrategy>
    ) {
        this.routerType = routerType
        this.name = name
        this.description = description
        this.weights = weights
        this.primaryIndex = primaryIndex
        this.contentSelector = contentSelector
        this.customStrategy = customStrategy
    }
}

/**
 * 高级路由器工厂接口
 */
public interface AdvancedRouterFactory {
    /**
     * 根据配置创建路由器
     */
    func createRouter(config: RouterConfig): Router
    
    /**
     * 创建优化的路由器（根据使用场景自动选择）
     */
    func createOptimizedRouter(config: RouterConfig, scenario: RoutingScenario): Router
    
    /**
     * 获取支持的路由器类型
     */
    func getSupportedTypes(): Array<RouterType>
    
    /**
     * 验证配置是否有效
     */
    func validateConfig(config: RouterConfig): Bool
    
    /**
     * 获取创建统计信息
     */
    func getCreationStats(): String
}

/**
 * 路由场景枚举
 * 用于自动选择最优的路由器实现
 */
public enum RoutingScenario {
    | HighThroughput       // 高吞吐量场景
    | LowLatency           // 低延迟场景
    | LoadBalancing        // 负载均衡场景
    | FaultTolerance       // 容错场景
    | ContentRouting       // 内容路由场景
    | Broadcast            // 广播场景
}

/**
 * 默认高级路由器工厂实现
 */
public class DefaultAdvancedRouterFactory <: AdvancedRouterFactory {
    private let supportedTypes: Array<RouterType>
    private let creationStats: HashMap<String, Int64>
    
    public init() {
        this.supportedTypes = [
            RouterType.RoundRobin,
            RouterType.Random,
            RouterType.ConsistentHash,
            RouterType.Broadcast,
            RouterType.WeightedRoundRobin,
            RouterType.LeastConnections,
            RouterType.FastestResponse,
            RouterType.Failover,
            RouterType.ContentBased,
            RouterType.Custom
        ]
        this.creationStats = HashMap<String, Int64>()
    }
    
    public func createRouter(config: RouterConfig): Router {
        // 验证配置
        if (!validateConfig(config)) {
            throw Exception("Invalid router configuration: ${config.name}")
        }
        
        // 记录创建统计
        recordCreation(config.routerType)
        
        // 根据类型创建路由器
        let strategy = createRoutingStrategy(config)
        AdvancedRouter(strategy)
    }
    
    public func createOptimizedRouter(config: RouterConfig, scenario: RoutingScenario): Router {
        // 根据场景选择最优的路由器实现
        let optimizedConfig = optimizeConfig(config, scenario)
        createRouter(optimizedConfig)
    }
    
    public func getSupportedTypes(): Array<RouterType> {
        supportedTypes
    }
    
    public func validateConfig(config: RouterConfig): Bool {
        // 验证基本配置
        if (config.name.isEmpty()) {
            return false
        }
        
        // 验证特定类型的配置
        match (config.routerType) {
            case RouterType.WeightedRoundRobin =>
                if (config.weights.size == 0) {
                    return false
                }
            case RouterType.Failover =>
                if (config.primaryIndex < 0) {
                    return false
                }
            case RouterType.ContentBased =>
                match (config.contentSelector) {
                    case None => return false
                    case Some(_) => ()
                }
            case RouterType.Custom =>
                match (config.customStrategy) {
                    case None => return false
                    case Some(_) => ()
                }
            case _ => () // 其他类型暂时不验证
        }
        
        return true
    }
    
    public func getCreationStats(): String {
        let stats = ArrayList<String>()
        for ((typeName, count) in creationStats) {
            stats.append("${typeName}: ${count}")
        }
        
        if (stats.isEmpty()) {
            return "No routers created yet"
        }
        
        let result = StringBuilder()
        result.append("Router Creation Stats: ")
        for (i in 0..stats.size) {
            if (i > 0) {
                result.append(", ")
            }
            result.add(stats[i])
        }
        result.toString()
    }
    
    /**
     * 创建路由策略
     */
    private func createRoutingStrategy(config: RouterConfig): RoutingStrategy {
        match (config.routerType) {
            case RouterType.RoundRobin =>
                RoundRobinRoutingStrategy()
            case RouterType.Random =>
                RandomRoutingStrategy()
            case RouterType.ConsistentHash =>
                ConsistentHashRoutingStrategy()
            case RouterType.Broadcast =>
                BroadcastRoutingStrategy()
            case RouterType.WeightedRoundRobin =>
                AdvancedRoutingStrategyFactory.createWeightedRoundRobin(config.weights)
            case RouterType.LeastConnections =>
                AdvancedRoutingStrategyFactory.createLeastConnections()
            case RouterType.FastestResponse =>
                AdvancedRoutingStrategyFactory.createFastestResponse()
            case RouterType.Failover =>
                AdvancedRoutingStrategyFactory.createFailover(config.primaryIndex)
            case RouterType.ContentBased =>
                match (config.contentSelector) {
                    case Some(selector) => 
                        AdvancedRoutingStrategyFactory.createContentBased(selector)
                    case None => 
                        throw Exception("ContentBased router requires content selector")
                }
            case RouterType.Custom =>
                match (config.customStrategy) {
                    case Some(strategy) => strategy
                    case None => 
                        throw Exception("Custom router requires custom strategy")
                }
        }
    }
    
    /**
     * 根据场景优化配置
     */
    private func optimizeConfig(config: RouterConfig, scenario: RoutingScenario): RouterConfig {
        match (scenario) {
            case RoutingScenario.HighThroughput =>
                RouterConfig(
                    RouterType.LeastConnections,
                    "${config.name}-high-throughput",
                    "Optimized for high throughput",
                    Array<Int32>(0, { _ => 0 }),
                    0,
                    None,
                    None
                )
            case RoutingScenario.LowLatency =>
                RouterConfig(
                    RouterType.FastestResponse,
                    "${config.name}-low-latency",
                    "Optimized for low latency",
                    Array<Int32>(0, { _ => 0 }),
                    0,
                    None,
                    None
                )
            case RoutingScenario.LoadBalancing =>
                RouterConfig(
                    RouterType.WeightedRoundRobin,
                    "${config.name}-load-balancing",
                    "Optimized for load balancing",
                    if (config.weights.size > 0) { config.weights } else { Array<Int32>(3, { _ => 1 }) },
                    0,
                    None,
                    None
                )
            case RoutingScenario.FaultTolerance =>
                RouterConfig(
                    RouterType.Failover,
                    "${config.name}-fault-tolerance",
                    "Optimized for fault tolerance",
                    Array<Int32>(0, { _ => 0 }),
                    config.primaryIndex,
                    None,
                    None
                )
            case RoutingScenario.ContentRouting =>
                RouterConfig(
                    RouterType.ConsistentHash,
                    "${config.name}-content-routing",
                    "Optimized for content routing",
                    Array<Int32>(0, { _ => 0 }),
                    0,
                    None,
                    None
                )
            case RoutingScenario.Broadcast =>
                RouterConfig(
                    RouterType.Broadcast,
                    "${config.name}-broadcast",
                    "Optimized for broadcast",
                    Array<Int32>(0, { _ => 0 }),
                    0,
                    None,
                    None
                )
        }
    }
    
    /**
     * 记录创建统计
     */
    private func recordCreation(routerType: RouterType): Unit {
        let typeName = match (routerType) {
            case RouterType.RoundRobin => "roundrobin"
            case RouterType.Random => "random"
            case RouterType.ConsistentHash => "consistenthash"
            case RouterType.Broadcast => "broadcast"
            case RouterType.WeightedRoundRobin => "weightedroundrobin"
            case RouterType.LeastConnections => "leastconnections"
            case RouterType.FastestResponse => "fastestresponse"
            case RouterType.Failover => "failover"
            case RouterType.ContentBased => "contentbased"
            case RouterType.Custom => "custom"
        }
        
        let currentCount = match (creationStats.get(typeName)) {
            case Some(count) => count
            case None => 0
        }
        creationStats.add(typeName, currentCount + 1)
    }
}

/**
 * 简化的StringBuilder实现
 */
public class StringBuilder {
    private let parts: ArrayList<String>
    
    public init() {
        this.parts = ArrayList<String>()
    }
    
    public func append(str: String): Unit {
        parts.add(str)
    }
    
    public func toString(): String {
        if (parts.isEmpty()) {
            return ""
        }
        
        var result = parts[0]
        for (i in 1..parts.size) {
            result = result + parts[i]
        }
        result
    }
}

/**
 * 路由器工厂注册表
 * 管理多个路由器工厂实例
 */
public class RouterFactoryRegistry {
    private let factories: HashMap<String, AdvancedRouterFactory>
    private let defaultFactory: AdvancedRouterFactory
    
    public init() {
        this.factories = HashMap<String, AdvancedRouterFactory>()
        this.defaultFactory = DefaultAdvancedRouterFactory()
        
        // 注册默认工厂
        registerFactory("default", defaultFactory)
    }
    
    /**
     * 注册路由器工厂
     */
    public func registerFactory(name: String, factory: AdvancedRouterFactory): Unit {
        factories.add(name, factory)
    }
    
    /**
     * 获取路由器工厂
     */
    public func getFactory(name: String): AdvancedRouterFactory {
        match (factories.get(name)) {
            case Some(factory) => factory
            case None => defaultFactory
        }
    }
    
    /**
     * 获取默认工厂
     */
    public func getDefaultFactory(): AdvancedRouterFactory {
        defaultFactory
    }
    
    /**
     * 获取所有注册的工厂名称
     */
    public func getFactoryNames(): Array<String> {
        let names = ArrayList<String>()
        for ((name, _) in factories) {
            names.add(name)
        }
        Array<String>(Int64(names.size), { i => names[i] })
    }
}
