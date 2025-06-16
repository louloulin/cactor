/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级路由系统
 * 基于plan3.md Phase 6设计，增强现有的路由功能
 */
package cactor.patterns.routing.advanced

import std.time.*
import std.collection.*
import std.sync.*
import cactor.core.message.{Message, Envelope}
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

/**
 * 高级路由策略工厂
 * 提供更多预定义的路由策略和自定义选项
 */
public class AdvancedRoutingStrategyFactory {
    
    /**
     * 创建加权轮询路由策略
     * 根据权重分配消息
     */
    public static func createWeightedRoundRobin(weights: Array<Int32>): WeightedRoundRobinRoutingStrategy {
        WeightedRoundRobinRoutingStrategy(weights)
    }
    
    /**
     * 创建最少连接路由策略
     * 选择当前处理消息最少的Actor
     */
    public static func createLeastConnections(): LeastConnectionsRoutingStrategy {
        LeastConnectionsRoutingStrategy()
    }
    
    /**
     * 创建响应时间路由策略
     * 选择平均响应时间最短的Actor
     */
    public static func createFastestResponse(): FastestResponseRoutingStrategy {
        FastestResponseRoutingStrategy()
    }
    
    /**
     * 创建故障转移路由策略
     * 主Actor失败时自动切换到备用Actor
     */
    public static func createFailover(primaryIndex: Int32): FailoverRoutingStrategy {
        FailoverRoutingStrategy(primaryIndex)
    }
    
    /**
     * 创建基于内容的路由策略
     * 根据消息内容选择Actor
     */
    public static func createContentBased(selector: (Message) -> String): ContentBasedRoutingStrategy {
        ContentBasedRoutingStrategy(selector)
    }
}

/**
 * 加权轮询路由策略
 * 根据权重分配消息，权重高的Actor处理更多消息
 */
public class WeightedRoundRobinRoutingStrategy <: RoutingStrategy {
    private let weights: Array<Int32>
    private let currentWeights: Array<AtomicInt32>
    private let totalWeight: Int32
    private let mutex: ReentrantMutex
    
    public init(weights: Array<Int32>) {
        this.weights = weights
        this.mutex = ReentrantMutex()
        
        // 计算总权重
        var total: Int32 = 0
        for (weight in weights) {
            total += weight
        }
        this.totalWeight = total
        
        // 初始化当前权重
        this.currentWeights = Array<AtomicInt32>(Int64(weights.size), { i =>
            AtomicInt32(weights[i])
        })
    }
    
    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0 || weights.size == 0) {
            return None
        }
        
        mutex.lock()
        try {
            var selectedIndex: Int64 = -1
            var maxWeight: Int32 = -1

            // 找到当前权重最大的Actor
            let maxIndex = if (Int64(routees.size) < Int64(weights.size)) { Int64(routees.size) } else { Int64(weights.size) }
            for (i in 0..maxIndex) {
                let currentWeight = currentWeights[i].load()
                if (currentWeight > maxWeight) {
                    maxWeight = currentWeight
                    selectedIndex = i
                }
            }
            
            if (selectedIndex >= 0) {
                // 减少选中Actor的当前权重
                currentWeights[selectedIndex].fetchSub(totalWeight)
                
                // 增加所有Actor的当前权重
                for (i in 0..currentWeights.size) {
                    currentWeights[i].fetchAdd(weights[i])
                }
                
                return Some(routees[selectedIndex])
            }
            
            return None
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 最少连接路由策略
 * 选择当前处理消息最少的Actor
 */
public class LeastConnectionsRoutingStrategy <: RoutingStrategy {
    private let connectionCounts: HashMap<String, AtomicInt32>
    private let mutex: ReentrantMutex
    
    public init() {
        this.connectionCounts = HashMap<String, AtomicInt32>()
        this.mutex = ReentrantMutex()
    }
    
    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }
        
        mutex.lock()
        try {
            var selectedActor: Option<ActorRef> = None
            var minConnections: Int32 = 2147483647  // Int32.MAX_VALUE

            for (routee in routees) {
                let actorKey = routee.path.toString()
                let connections = match (connectionCounts.get(actorKey)) {
                    case Some(counter) => counter.load()
                    case None =>
                        let newCounter = AtomicInt32(0)
                        connectionCounts.put(actorKey, newCounter)
                        Int32(0)
                }
                
                if (connections < minConnections) {
                    minConnections = connections
                    selectedActor = Some(routee)
                }
            }
            
            // 增加选中Actor的连接计数
            match (selectedActor) {
                case Some(actor) =>
                    let actorKey = actor.path.toString()
                    match (connectionCounts.get(actorKey)) {
                        case Some(counter) => counter.fetchAdd(1)
                        case None => ()
                    }
                case None => ()
            }
            
            return selectedActor
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 减少Actor的连接计数（消息处理完成时调用）
     */
    public func decreaseConnections(actor: ActorRef): Unit {
        mutex.lock()
        try {
            let actorKey = actor.path.toString()
            match (connectionCounts.get(actorKey)) {
                case Some(counter) => 
                    if (counter.load() > 0) {
                        counter.fetchSub(1)
                    }
                case None => ()
            }
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 最快响应路由策略
 * 选择平均响应时间最短的Actor
 */
public class FastestResponseRoutingStrategy <: RoutingStrategy {
    private let responseTimes: HashMap<String, ResponseTimeTracker>
    private let mutex: ReentrantMutex
    
    public init() {
        this.responseTimes = HashMap<String, ResponseTimeTracker>()
        this.mutex = ReentrantMutex()
    }
    
    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }
        
        mutex.lock()
        try {
            var selectedActor: Option<ActorRef> = None
            var minResponseTime: Float64 = 1000000.0  // 很大的初始值
            
            for (routee in routees) {
                let actorKey = routee.path.toString()
                let avgResponseTime = match (responseTimes.get(actorKey)) {
                    case Some(tracker) => tracker.getAverageResponseTime()
                    case None => 
                        let newTracker = ResponseTimeTracker()
                        responseTimes.put(actorKey, newTracker)
                        100.0  // 默认响应时间
                }
                
                if (avgResponseTime < minResponseTime) {
                    minResponseTime = avgResponseTime
                    selectedActor = Some(routee)
                }
            }
            
            return selectedActor
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 记录Actor的响应时间
     */
    public func recordResponseTime(actor: ActorRef, responseTime: Duration): Unit {
        mutex.lock()
        try {
            let actorKey = actor.path.toString()
            match (responseTimes.get(actorKey)) {
                case Some(tracker) => 
                    tracker.recordResponseTime(responseTime.toMilliseconds())
                case None => 
                    let newTracker = ResponseTimeTracker()
                    newTracker.recordResponseTime(responseTime.toMilliseconds())
                    responseTimes.put(actorKey, newTracker)
            }
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 响应时间跟踪器
 */
public class ResponseTimeTracker {
    private let totalResponseTime: AtomicInt64
    private let requestCount: AtomicInt64
    private let recentTimes: ArrayList<Int64>
    private let maxRecentCount: Int32
    
    public init() {
        this.totalResponseTime = AtomicInt64(0)
        this.requestCount = AtomicInt64(0)
        this.recentTimes = ArrayList<Int64>()
        this.maxRecentCount = 100  // 保留最近100次的响应时间
    }
    
    public func recordResponseTime(responseTimeMs: Int64): Unit {
        totalResponseTime.fetchAdd(responseTimeMs)
        requestCount.fetchAdd(1)
        
        // 保留最近的响应时间
        recentTimes.append(responseTimeMs)
        if (recentTimes.size > Int64(maxRecentCount)) {
            recentTimes.remove(0)
        }
    }
    
    public func getAverageResponseTime(): Float64 {
        let count = requestCount.load()
        if (count == 0) {
            return 100.0  // 默认值
        }
        
        let total = totalResponseTime.load()
        Float64(total) / Float64(count)
    }
    
    public func getRecentAverageResponseTime(): Float64 {
        if (recentTimes.isEmpty()) {
            return 100.0
        }
        
        var total: Int64 = 0
        for (time in recentTimes) {
            total += time
        }
        
        Float64(total) / Float64(recentTimes.size)
    }
}

/**
 * 故障转移路由策略
 * 主Actor失败时自动切换到备用Actor
 */
public class FailoverRoutingStrategy <: RoutingStrategy {
    private let primaryIndex: Int32
    private let failedActors: HashSet<String>
    private let mutex: ReentrantMutex
    
    public init(primaryIndex: Int32) {
        this.primaryIndex = primaryIndex
        this.failedActors = HashSet<String>()
        this.mutex = ReentrantMutex()
    }
    
    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }
        
        mutex.lock()
        try {
            // 首先尝试主Actor
            if (primaryIndex >= 0 && Int64(primaryIndex) < routees.size) {
                let primaryActor = routees[Int64(primaryIndex)]
                let primaryKey = primaryActor.path.toString()
                
                if (!failedActors.contains(primaryKey)) {
                    return Some(primaryActor)
                }
            }
            
            // 主Actor失败，选择第一个可用的备用Actor
            for (i in 0..routees.size) {
                if (Int32(i) != primaryIndex) {
                    let actor = routees[i]
                    let actorKey = actor.path.toString()
                    
                    if (!failedActors.contains(actorKey)) {
                        return Some(actor)
                    }
                }
            }
            
            return None
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 标记Actor为失败状态
     */
    public func markActorAsFailed(actor: ActorRef): Unit {
        mutex.lock()
        try {
            failedActors.put(actor.path.toString())
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 恢复Actor（从失败状态中移除）
     */
    public func recoverActor(actor: ActorRef): Unit {
        mutex.lock()
        try {
            failedActors.remove(actor.path.toString())
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 基于内容的路由策略
 * 根据消息内容选择Actor
 */
public class ContentBasedRoutingStrategy <: RoutingStrategy {
    private let contentSelector: (Message) -> String
    private let routingTable: HashMap<String, Int32>
    private let mutex: ReentrantMutex
    
    public init(contentSelector: (Message) -> String) {
        this.contentSelector = contentSelector
        this.routingTable = HashMap<String, Int32>()
        this.mutex = ReentrantMutex()
    }
    
    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }
        
        let content = contentSelector(message)
        
        mutex.lock()
        try {
            // 检查是否有预定义的路由规则
            match (routingTable.get(content)) {
                case Some(index) =>
                    if (index >= 0 && Int64(index) < routees.size) {
                        return Some(routees[Int64(index)])
                    }
                case None => ()
            }

            // 没有预定义规则，使用内容哈希
            let hash = content.hashCode()
            let index = Int64(hash) % Int64(routees.size)
            return Some(routees[index])
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 添加路由规则
     */
    public func addRoutingRule(content: String, actorIndex: Int32): Unit {
        mutex.lock()
        try {
            routingTable.put(content, actorIndex)
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 移除路由规则
     */
    public func removeRoutingRule(content: String): Unit {
        mutex.lock()
        try {
            routingTable.remove(content)
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 高级路由器
 * 提供更丰富的路由功能和监控
 */
public class AdvancedRouter <: Router {
    private let strategy: RoutingStrategy
    private let routees: ArrayList<ActorRef>
    private let mutex: ReentrantMutex
    private let routingMetrics: RoutingMetrics
    private let healthChecker: RouterHealthChecker

    public init(strategy: RoutingStrategy) {
        this.strategy = strategy
        this.routees = ArrayList<ActorRef>()
        this.mutex = ReentrantMutex()
        this.routingMetrics = RoutingMetrics()
        this.healthChecker = RouterHealthChecker()
    }

    public func route(message: Message): Unit {
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        mutex.lock()
        let routeeArray = routees.toArray()
        mutex.unlock()

        // 过滤健康的Actor
        let healthyRoutees = healthChecker.filterHealthyActors(routeeArray)

        if (healthyRoutees.size == 0) {
            routingMetrics.recordFailedRoute("no_healthy_routees")
            println("警告: 没有健康的路由目标")
            return
        }

        // 特殊处理广播策略
        match (strategy) {
            case broadcast: BroadcastRoutingStrategy =>
                broadcast.broadcast(healthyRoutees, message)
                routingMetrics.recordSuccessfulRoute(Int32(healthyRoutees.size))
            case _ =>
                match (strategy.selectRoutee(healthyRoutees, message)) {
                    case Some(routee) =>
                        routee.tell(message)
                        routingMetrics.recordSuccessfulRoute(1)

                        // 记录响应时间（如果是FastestResponseStrategy）
                        match (strategy) {
                            case fastestResponse: FastestResponseRoutingStrategy =>
                                let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                                let responseTime = Duration.millisecond * (endTime - startTime)
                                fastestResponse.recordResponseTime(routee, responseTime)
                            case _ => ()
                        }
                    case None =>
                        routingMetrics.recordFailedRoute("no_routee_selected")
                        println("警告: 没有选中路由目标")
                }
        }
    }

    public func addRoutee(routee: ActorRef): Unit {
        mutex.lock()
        try {
            routees.append(routee)
            healthChecker.addActor(routee)
            routingMetrics.recordRouteeAdded()
        } finally {
            mutex.unlock()
        }
    }

    public func removeRoutee(routee: ActorRef): Unit {
        mutex.lock()
        try {
            // 简化实现：遍历查找并移除
            var index = -1
            for (i in 0..routees.size) {
                if (routees[i].equals(routee)) {
                    index = i
                    break
                }
            }
            if (index >= 0) {
                routees.remove(index)
                healthChecker.removeActor(routee)
                routingMetrics.recordRouteeRemoved()
            }
        } finally {
            mutex.unlock()
        }
    }

    public func getRoutees(): Array<ActorRef> {
        mutex.lock()
        try {
            routees.toArray()
        } finally {
            mutex.unlock()
        }
    }

    public func getStrategy(): RoutingStrategy {
        strategy
    }

    /**
     * 获取路由指标
     */
    public func getRoutingMetrics(): RoutingMetrics {
        routingMetrics
    }

    /**
     * 获取健康检查器
     */
    public func getHealthChecker(): RouterHealthChecker {
        healthChecker
    }
}

/**
 * 路由指标
 * 收集和统计路由相关的指标
 */
public class RoutingMetrics {
    private let totalRoutes: AtomicInt64
    private let successfulRoutes: AtomicInt64
    private let failedRoutes: AtomicInt64
    private let routeesAdded: AtomicInt64
    private let routeesRemoved: AtomicInt64
    private let failureReasons: HashMap<String, AtomicInt64>
    private let startTime: Int64
    private let mutex: ReentrantMutex

    public init() {
        this.totalRoutes = AtomicInt64(0)
        this.successfulRoutes = AtomicInt64(0)
        this.failedRoutes = AtomicInt64(0)
        this.routeesAdded = AtomicInt64(0)
        this.routeesRemoved = AtomicInt64(0)
        this.failureReasons = HashMap<String, AtomicInt64>()
        this.startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.mutex = ReentrantMutex()
    }

    public func recordSuccessfulRoute(routeeCount: Int32): Unit {
        totalRoutes.fetchAdd(1)
        successfulRoutes.fetchAdd(1)
    }

    public func recordFailedRoute(reason: String): Unit {
        totalRoutes.fetchAdd(1)
        failedRoutes.fetchAdd(1)

        mutex.lock()
        try {
            let currentCount = match (failureReasons.get(reason)) {
                case Some(counter) => counter.load()
                case None => 0
            }
            failureReasons.put(reason, AtomicInt64(currentCount + 1))
        } finally {
            mutex.unlock()
        }
    }

    public func recordRouteeAdded(): Unit {
        routeesAdded.fetchAdd(1)
    }

    public func recordRouteeRemoved(): Unit {
        routeesRemoved.fetchAdd(1)
    }

    public func getTotalRoutes(): Int64 {
        totalRoutes.load()
    }

    public func getSuccessfulRoutes(): Int64 {
        successfulRoutes.load()
    }

    public func getFailedRoutes(): Int64 {
        failedRoutes.load()
    }

    public func getSuccessRate(): Float64 {
        let total = totalRoutes.load()
        if (total == 0) {
            return 1.0
        }
        Float64(successfulRoutes.load()) / Float64(total)
    }

    public func getRouteRate(): Float64 {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let elapsedSeconds = Float64(now - startTime) / 1000.0

        if (elapsedSeconds > 0.0) {
            Float64(totalRoutes.load()) / elapsedSeconds
        } else {
            0.0
        }
    }

    public func getMetricsSummary(): String {
        "RoutingMetrics[" +
        "总路由: ${getTotalRoutes()}, " +
        "成功: ${getSuccessfulRoutes()}, " +
        "失败: ${getFailedRoutes()}, " +
        "成功率: ${getSuccessRate()}, " +
        "路由率: ${getRouteRate()}/s, " +
        "添加: ${routeesAdded.load()}, " +
        "移除: ${routeesRemoved.load()}]"
    }
}

/**
 * 路由器健康检查器
 * 监控Actor的健康状态
 */
public class RouterHealthChecker {
    private let actorHealth: HashMap<String, ActorHealthStatus>
    private let mutex: ReentrantMutex
    private let healthCheckInterval: Duration

    public init() {
        this.actorHealth = HashMap<String, ActorHealthStatus>()
        this.mutex = ReentrantMutex()
        this.healthCheckInterval = Duration.second * 30  // 30秒检查一次
    }

    public func addActor(actor: ActorRef): Unit {
        mutex.lock()
        try {
            let actorKey = actor.path.toString()
            actorHealth.put(actorKey, ActorHealthStatus())
        } finally {
            mutex.unlock()
        }
    }

    public func removeActor(actor: ActorRef): Unit {
        mutex.lock()
        try {
            let actorKey = actor.path.toString()
            actorHealth.remove(actorKey)
        } finally {
            mutex.unlock()
        }
    }

    public func markActorUnhealthy(actor: ActorRef, reason: String): Unit {
        mutex.lock()
        try {
            let actorKey = actor.path.toString()
            match (actorHealth.get(actorKey)) {
                case Some(status) =>
                    status.markUnhealthy(reason)
                case None => ()
            }
        } finally {
            mutex.unlock()
        }
    }

    public func markActorHealthy(actor: ActorRef): Unit {
        mutex.lock()
        try {
            let actorKey = actor.path.toString()
            match (actorHealth.get(actorKey)) {
                case Some(status) =>
                    status.markHealthy()
                case None => ()
            }
        } finally {
            mutex.unlock()
        }
    }

    public func filterHealthyActors(actors: Array<ActorRef>): Array<ActorRef> {
        mutex.lock()
        try {
            let healthyActors = ArrayList<ActorRef>()

            for (actor in actors) {
                let actorKey = actor.path.toString()
                match (actorHealth.get(actorKey)) {
                    case Some(status) =>
                        if (status.isHealthy()) {
                            healthyActors.append(actor)
                        }
                    case None =>
                        // 未知状态的Actor默认为健康
                        healthyActors.append(actor)
                }
            }

            Array<ActorRef>(Int64(healthyActors.size), { i => healthyActors[i] })
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * Actor健康状态
 */
public class ActorHealthStatus {
    private let isHealthyFlag: AtomicBool
    private let lastFailureTime: AtomicInt64
    private let failureCount: AtomicInt32
    private let lastFailureReason: String

    public init() {
        this.isHealthyFlag = AtomicBool(true)
        this.lastFailureTime = AtomicInt64(0)
        this.failureCount = AtomicInt32(0)
        this.lastFailureReason = ""
    }

    public func isHealthy(): Bool {
        isHealthyFlag.load()
    }

    public func markHealthy(): Unit {
        isHealthyFlag.store(true)
        failureCount.store(0)
    }

    public func markUnhealthy(reason: String): Unit {
        isHealthyFlag.store(false)
        lastFailureTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
        failureCount.fetchAdd(1)
    }

    public func getFailureCount(): Int32 {
        failureCount.load()
    }

    public func getLastFailureTime(): Int64 {
        lastFailureTime.load()
    }
}
