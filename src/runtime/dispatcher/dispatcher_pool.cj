/*
 * Copyright (c) 2024. All rights reserved.
 * DispatcherPool - Plan10.md要求的调度器池
 * 实现动态调度器选择和管理
 */
package cactor.runtime.dispatcher

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, Envelope}
import cactor.core.config.{DispatcherConfig, DispatcherType}
import cactor.runtime.dispatcher.advanced.{AdvancedMessageDispatcher, ThreadPoolDispatcher, AdvancedWorkStealingDispatcher, PinnedDispatcher, CallingThreadDispatcher}
import cactor.runtime.dispatcher.factory.{DefaultAdvancedDispatcherFactory}

/**
 * 调度器选择策略
 */
public enum DispatcherSelectionStrategy {
    RoundRobin      // 轮询选择
    | LoadBased     // 基于负载选择
    | ActorType     // 基于Actor类型选择
    | Random        // 随机选择
    | Consistent    // 一致性哈希选择
}

/**
 * 调度器池配置
 */
public struct DispatcherPoolConfig {
    public let defaultDispatcherType: DispatcherType
    public let selectionStrategy: DispatcherSelectionStrategy
    public let maxDispatchers: Int32
    public let enableLoadBalancing: Bool
    public let enableMetrics: Bool
    
    public init(
        defaultDispatcherType: DispatcherType,
        selectionStrategy: DispatcherSelectionStrategy,
        maxDispatchers: Int32,
        enableLoadBalancing: Bool,
        enableMetrics: Bool
    ) {
        this.defaultDispatcherType = defaultDispatcherType
        this.selectionStrategy = selectionStrategy
        this.maxDispatchers = maxDispatchers
        this.enableLoadBalancing = enableLoadBalancing
        this.enableMetrics = enableMetrics
    }
    
    public static func createDefault(): DispatcherPoolConfig {
        DispatcherPoolConfig(
            DispatcherType.WorkStealing,
            DispatcherSelectionStrategy.LoadBased,
            16,
            true,
            true
        )
    }
}

/**
 * 调度器池统计信息
 */
public struct DispatcherPoolStats {
    public let totalDispatchers: Int32
    public let activeDispatchers: Int32
    public let totalSelections: Int64
    public let averageLoadPerDispatcher: Float64
    
    public init(totalDispatchers: Int32, activeDispatchers: Int32, totalSelections: Int64, averageLoadPerDispatcher: Float64) {
        this.totalDispatchers = totalDispatchers
        this.activeDispatchers = activeDispatchers
        this.totalSelections = totalSelections
        this.averageLoadPerDispatcher = averageLoadPerDispatcher
    }
}

/**
 * DispatcherPool - Plan10.md要求的核心组件
 * 
 * 职责：
 * 1. 管理多个调度器实例
 * 2. 根据策略选择合适的调度器
 * 3. 负载均衡和性能监控
 * 4. 调度器生命周期管理
 */
public class DispatcherPool {
    private let config: DispatcherPoolConfig
    private let dispatchers: HashMap<String, AdvancedMessageDispatcher>
    private let dispatcherFactory: DefaultAdvancedDispatcherFactory
    private let selectionCounter: AtomicInt64
    private let totalSelections: AtomicInt64
    private let isRunning: AtomicBool
    
    public init(config: DispatcherPoolConfig) {
        this.config = config
        this.dispatchers = HashMap<String, AdvancedMessageDispatcher>()
        this.dispatcherFactory = DefaultAdvancedDispatcherFactory()
        this.selectionCounter = AtomicInt64(0)
        this.totalSelections = AtomicInt64(0)
        this.isRunning = AtomicBool(false)
        
        // 初始化默认调度器
        initializeDefaultDispatchers()
    }
    
    /**
     * 启动调度器池
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            // 启动所有调度器
            for ((name, dispatcher) in dispatchers) {
                dispatcher.start()
            }
            let dispatcherCount = countDispatchers()
            println("🚀 DispatcherPool启动成功，包含${dispatcherCount}个调度器")
        }
    }
    
    /**
     * 停止调度器池
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            // 停止所有调度器
            for ((name, dispatcher) in dispatchers) {
                dispatcher.stop()
            }
            println("🛑 DispatcherPool已停止")
        }
    }
    
    /**
     * 选择调度器 - Plan10.md要求的核心方法
     */
    public func selectDispatcher(actor: Actor, props: Props<Actor>): AdvancedMessageDispatcher {
        if (!isRunning.load()) {
            throw Exception("DispatcherPool未运行")
        }
        
        totalSelections.fetchAdd(1)
        
        // 检查Props中是否指定了调度器
        let dispatcherName = props.getDispatcherName()
        if (dispatcherName != "default") {
            match (dispatchers.get(dispatcherName)) {
                case Some(dispatcher) => return dispatcher
                case None =>
                    println("警告：指定的调度器'${dispatcherName}'不存在，使用默认调度器")
            }
        }
        
        // 根据选择策略选择调度器
        match (config.selectionStrategy) {
            case DispatcherSelectionStrategy.RoundRobin =>
                selectRoundRobin()
            case DispatcherSelectionStrategy.LoadBased =>
                selectByLoad()
            case DispatcherSelectionStrategy.ActorType =>
                selectByActorType(actor)
            case DispatcherSelectionStrategy.Random =>
                selectRandom()
            case DispatcherSelectionStrategy.Consistent =>
                selectConsistent(actor)
        }
    }
    
    /**
     * 添加调度器
     */
    public func addDispatcher(name: String, dispatcher: AdvancedMessageDispatcher): Unit {
        if (countDispatchers() >= config.maxDispatchers) {
            throw Exception("已达到最大调度器数量限制: ${config.maxDispatchers}")
        }
        
        dispatchers.add(name, dispatcher)
        
        if (isRunning.load()) {
            dispatcher.start()
        }
    }
    
    /**
     * 移除调度器
     */
    public func removeDispatcher(name: String): Unit {
        match (dispatchers.get(name)) {
            case Some(dispatcher) =>
                dispatcher.stop()
                dispatchers.remove(name)
            case None =>
                println("警告：调度器'${name}'不存在")
        }
    }
    
    /**
     * 获取调度器
     */
    public func getDispatcher(name: String): Option<AdvancedMessageDispatcher> {
        dispatchers.get(name)
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): DispatcherPoolStats {
        let totalDispatchers = countDispatchers()
        let activeDispatchers = countActiveDispatchers()
        let totalSelections = this.totalSelections.load()
        let averageLoad = calculateAverageLoad()
        
        DispatcherPoolStats(totalDispatchers, activeDispatchers, totalSelections, averageLoad)
    }
    
    /**
     * 初始化默认调度器
     */
    private func initializeDefaultDispatchers(): Unit {
        // 创建默认的工作窃取调度器
        let defaultConfig = DispatcherConfig.createWorkStealingWithName("default-work-stealing")
        let defaultDispatcher = dispatcherFactory.createDispatcher(defaultConfig)
        dispatchers.add("default", defaultDispatcher)

        // 创建线程池调度器
        let threadPoolConfig = DispatcherConfig.createThreadPoolWithName("thread-pool")
        let threadPoolDispatcher = dispatcherFactory.createDispatcher(threadPoolConfig)
        dispatchers.add("thread-pool", threadPoolDispatcher)

        // 创建固定线程调度器
        let pinnedConfig = DispatcherConfig.createPinnedWithName("pinned")
        let pinnedDispatcher = dispatcherFactory.createDispatcher(pinnedConfig)
        dispatchers.add("pinned", pinnedDispatcher)

        // 创建调用线程调度器 - 使用线程池配置作为替代
        let callingThreadConfig = DispatcherConfig.createThreadPoolWithName("calling-thread")
        let callingThreadDispatcher = dispatcherFactory.createDispatcher(callingThreadConfig)
        dispatchers.add("calling-thread", callingThreadDispatcher)
    }
    
    /**
     * 轮询选择调度器
     */
    private func selectRoundRobin(): AdvancedMessageDispatcher {
        if (dispatchers.isEmpty()) {
            throw Exception("没有可用的调度器")
        }
        
        let dispatcherCount = countDispatchers()
        let index = selectionCounter.fetchAdd(1) % Int64(dispatcherCount)
        let dispatcherNames = getDispatcherNames()
        
        let selectedName = dispatcherNames[index]
        match (dispatchers.get(selectedName)) {
            case Some(dispatcher) => dispatcher
            case None => getDefaultDispatcher()
        }
    }
    
    /**
     * 基于负载选择调度器
     */
    private func selectByLoad(): AdvancedMessageDispatcher {
        // 简化实现：选择第一个可用的调度器
        // 实际实现应该考虑每个调度器的当前负载
        for ((name, dispatcher) in dispatchers) {
            return dispatcher
        }
        throw Exception("没有可用的调度器")
    }
    
    /**
     * 基于Actor类型选择调度器
     */
    private func selectByActorType(actor: Actor): AdvancedMessageDispatcher {
        // 简化实现：根据Actor名称选择
        let actorName = actor.name
        if (actorName.contains("high-performance")) {
            match (dispatchers.get("pinned")) {
                case Some(dispatcher) => return dispatcher
                case None => ()
            }
        }
        
        return getDefaultDispatcher()
    }
    
    /**
     * 随机选择调度器
     */
    private func selectRandom(): AdvancedMessageDispatcher {
        // 简化实现：使用时间戳作为随机种子
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let dispatcherCount = countDispatchers()
        let index = timestamp % Int64(dispatcherCount)

        let dispatcherNames = getDispatcherNames()
        
        let selectedName = dispatcherNames[index]
        match (dispatchers.get(selectedName)) {
            case Some(dispatcher) => dispatcher
            case None => getDefaultDispatcher()
        }
    }
    
    /**
     * 一致性哈希选择调度器
     */
    private func selectConsistent(actor: Actor): AdvancedMessageDispatcher {
        // 简化实现：基于Actor名称的哈希值选择
        let hash = actor.name.hashCode()
        let dispatcherCount = countDispatchers()
        let index = hash % Int64(dispatcherCount)

        let dispatcherNames = getDispatcherNames()
        
        let selectedName = dispatcherNames[index]
        match (dispatchers.get(selectedName)) {
            case Some(dispatcher) => dispatcher
            case None => getDefaultDispatcher()
        }
    }
    
    /**
     * 获取默认调度器
     */
    private func getDefaultDispatcher(): AdvancedMessageDispatcher {
        match (dispatchers.get("default")) {
            case Some(dispatcher) => dispatcher
            case None => throw Exception("默认调度器不存在")
        }
    }
    
    /**
     * 统计活跃调度器数量
     */
    private func countActiveDispatchers(): Int32 {
        var count = 0
        for ((name, dispatcher) in dispatchers) {
            // 简化实现：假设所有调度器都是活跃的
            count += 1
        }
        Int32(count)
    }
    
    /**
     * 计算平均负载
     */
    private func calculateAverageLoad(): Float64 {
        // 简化实现：返回固定值
        // 实际实现应该计算每个调度器的实际负载
        50.0
    }

    /**
     * 统计调度器数量
     */
    private func countDispatchers(): Int32 {
        var count = 0
        for ((name, dispatcher) in dispatchers) {
            count += 1
        }
        Int32(count)
    }

    /**
     * 获取调度器名称列表
     */
    private func getDispatcherNames(): Array<String> {
        let names = ArrayList<String>()
        for ((name, _) in dispatchers) {
            names.add(name)
        }
        names.toArray()
    }
}
