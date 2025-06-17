/*
 * Copyright (c) 2024. All rights reserved.
 * DispatcherPool - 高性能调度器池
 * 基于plan10.md设计，提供多种调度器类型的统一管理
 */
package cactor.runtime.dispatcher

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, Envelope}
import cactor.core.config.{ActorSystemConfig}
import cactor.foundation.queue.{LockFreeQueue}

/**
 * 调度器类型枚举
 */
public enum DispatcherType {
    | ForkJoin        // Fork-Join池调度器
    | WorkStealing    // 工作窃取调度器
    | Pinned          // 固定线程调度器
    | CallingThread   // 调用线程调度器
    | NUMA            // NUMA感知调度器
}

/**
 * 调度器配置
 */
public struct DispatcherConfig {
    public let dispatcherType: DispatcherType
    public let threadCount: Int32
    public let queueSize: Int32
    public let batchSize: Int32
    public let enableNUMA: Bool
    public let cpuAffinity: Option<Array<Int32>>
    
    public init(
        dispatcherType: DispatcherType,
        threadCount: Int32,
        queueSize: Int32,
        batchSize: Int32,
        enableNUMA: Bool,
        cpuAffinity: Option<Array<Int32>>
    ) {
        this.dispatcherType = dispatcherType
        this.threadCount = threadCount
        this.queueSize = queueSize
        this.batchSize = batchSize
        this.enableNUMA = enableNUMA
        this.cpuAffinity = cpuAffinity
    }
    
    /**
     * 创建默认配置
     */
    public static func createDefault(): DispatcherConfig {
        DispatcherConfig(
            DispatcherType.ForkJoin,
            8,      // 8个线程
            10000,  // 队列大小
            32,     // 批处理大小
            false,  // 不启用NUMA
            None    // 无CPU亲和性
        )
    }
    
    /**
     * 创建高性能配置
     */
    public static func createHighPerformance(): DispatcherConfig {
        DispatcherConfig(
            DispatcherType.WorkStealing,
            16,     // 16个线程
            50000,  // 大队列
            64,     // 大批处理
            true,   // 启用NUMA
            None    // 自动CPU亲和性
        )
    }
}

/**
 * 调度器接口
 */
public interface Dispatcher {
    /**
     * 调度器名称
     */
    prop name: String
    
    /**
     * 调度器类型
     */
    prop dispatcherType: DispatcherType
    
    /**
     * 是否正在运行
     */
    prop isRunning: Bool
    
    /**
     * 分发消息到Actor
     */
    func dispatch(envelope: Envelope, actorRef: ActorRef): Unit
    
    /**
     * 带优先级的分发
     */
    func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit
    
    /**
     * 启动调度器
     */
    func start(): Unit
    
    /**
     * 停止调度器
     */
    func shutdown(): Unit
    
    /**
     * 获取调度器统计信息
     */
    func getStats(): DispatcherStats
}

/**
 * 调度器统计信息
 */
public struct DispatcherStats {
    public let dispatcherName: String
    public let dispatcherType: DispatcherType
    public let threadCount: Int32
    public let queueSize: Int32
    public let processedMessages: Int64
    public let averageLatency: Float64
    public let throughput: Float64
    public let errorCount: Int64
    
    public init(
        dispatcherName: String,
        dispatcherType: DispatcherType,
        threadCount: Int32,
        queueSize: Int32,
        processedMessages: Int64,
        averageLatency: Float64,
        throughput: Float64,
        errorCount: Int64
    ) {
        this.dispatcherName = dispatcherName
        this.dispatcherType = dispatcherType
        this.threadCount = threadCount
        this.queueSize = queueSize
        this.processedMessages = processedMessages
        this.averageLatency = averageLatency
        this.throughput = throughput
        this.errorCount = errorCount
    }
    
    /**
     * 打印统计报告
     */
    public func printReport(): Unit {
        println("=== 调度器统计报告 ===")
        println("调度器名称: ${dispatcherName}")
        println("调度器类型: ${dispatcherType}")
        println("线程数量: ${threadCount}")
        println("队列大小: ${queueSize}")
        println("处理消息数: ${processedMessages}")
        println("平均延迟: ${averageLatency}μs")
        println("吞吐量: ${throughput} msg/s")
        println("错误数量: ${errorCount}")
        println("===================")
    }
}

/**
 * 消息优先级
 */
public enum Priority {
    | Low
    | Normal
    | High
    | Critical
}

/**
 * 调度器池 - 统一管理多种调度器
 */
public class DispatcherPool {
    private let dispatchers: HashMap<String, Dispatcher>
    private let defaultDispatcher: Dispatcher
    private let config: ActorSystemConfig
    private let isShutdown: AtomicBool
    
    public init(config: ActorSystemConfig) {
        this.config = config
        this.dispatchers = HashMap<String, Dispatcher>()
        this.isShutdown = AtomicBool(false)
        
        // 创建默认调度器
        this.defaultDispatcher = createDefaultDispatcher()
        
        // 初始化调度器池
        initializeDispatchers()
    }
    
    /**
     * 选择合适的调度器
     */
    public func selectDispatcher(actor: Actor, props: Props<Actor>): Dispatcher {
        // 根据Actor类型和Props选择最合适的调度器
        match (props.dispatcherName) {
            case Some(name) =>
                match (dispatchers.get(name)) {
                    case Some(dispatcher) => dispatcher
                    case None => defaultDispatcher
                }
            case None =>
                // 根据Actor特性自动选择
                selectOptimalDispatcher(actor, props)
        }
    }
    
    /**
     * 获取指定名称的调度器
     */
    public func getDispatcher(name: String): Option<Dispatcher> {
        dispatchers.get(name)
    }
    
    /**
     * 添加调度器
     */
    public func addDispatcher(name: String, dispatcher: Dispatcher): Unit {
        dispatchers.put(name, dispatcher)
        dispatcher.start()
    }
    
    /**
     * 移除调度器
     */
    public func removeDispatcher(name: String): Unit {
        match (dispatchers.get(name)) {
            case Some(dispatcher) =>
                dispatcher.shutdown()
                dispatchers.remove(name)
            case None => ()
        }
    }
    
    /**
     * 启动所有调度器
     */
    public func start(): Unit {
        defaultDispatcher.start()
        for ((name, dispatcher) in dispatchers) {
            dispatcher.start()
        }
    }
    
    /**
     * 关闭所有调度器
     */
    public func shutdown(): Unit {
        if (isShutdown.compareAndSwap(false, true)) {
            for ((name, dispatcher) in dispatchers) {
                dispatcher.shutdown()
            }
            defaultDispatcher.shutdown()
        }
    }
    
    /**
     * 获取池统计信息
     */
    public func getPoolStats(): DispatcherPoolStats {
        let dispatcherStats = Array<DispatcherStats>()
        
        dispatcherStats.append(defaultDispatcher.getStats())
        for ((name, dispatcher) in dispatchers) {
            dispatcherStats.append(dispatcher.getStats())
        }
        
        DispatcherPoolStats(dispatcherStats.size(), dispatcherStats)
    }
    
    /**
     * 创建默认调度器
     */
    private func createDefaultDispatcher(): Dispatcher {
        let config = DispatcherConfig.createDefault()
        ForkJoinDispatcher("default", config)
    }
    
    /**
     * 初始化调度器池
     */
    private func initializeDispatchers(): Unit {
        // 创建工作窃取调度器
        let workStealingConfig = DispatcherConfig.createHighPerformance()
        let workStealingDispatcher = WorkStealingDispatcher("work-stealing", workStealingConfig)
        addDispatcher("work-stealing", workStealingDispatcher)
        
        // 创建固定线程调度器
        let pinnedConfig = DispatcherConfig(
            DispatcherType.Pinned, 4, 5000, 16, false, None
        )
        let pinnedDispatcher = PinnedDispatcher("pinned", pinnedConfig)
        addDispatcher("pinned", pinnedDispatcher)
        
        // 创建调用线程调度器（用于测试）
        let callingThreadDispatcher = CallingThreadDispatcher("calling-thread")
        addDispatcher("calling-thread", callingThreadDispatcher)
    }
    
    /**
     * 自动选择最优调度器
     */
    private func selectOptimalDispatcher(actor: Actor, props: Props<Actor>): Dispatcher {
        // 简化的选择逻辑，可以根据Actor特性进行优化
        if (props.isHighThroughput) {
            match (dispatchers.get("work-stealing")) {
                case Some(dispatcher) => dispatcher
                case None => defaultDispatcher
            }
        } else {
            defaultDispatcher
        }
    }
}

/**
 * 调度器池统计信息
 */
public struct DispatcherPoolStats {
    public let dispatcherCount: Int32
    public let dispatcherStats: Array<DispatcherStats>
    
    public init(dispatcherCount: Int32, dispatcherStats: Array<DispatcherStats>) {
        this.dispatcherCount = dispatcherCount
        this.dispatcherStats = dispatcherStats
    }
    
    /**
     * 打印池统计报告
     */
    public func printPoolReport(): Unit {
        println("=== 调度器池统计报告 ===")
        println("调度器数量: ${dispatcherCount}")
        
        for (stats in dispatcherStats) {
            stats.printReport()
        }
        
        println("=====================")
    }
}
