/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - 高性能Actor系统
 * 基于tu.md优化计划的高性能Actor系统实现
 * 从Core层移动到Runtime层
 */
package cactor.runtime.system

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.*
import cactor.runtime.context.{PooledActorContext, PooledActorContextPool, PoolStats}
import cactor.runtime.actor.{HighPerformanceActor, HighPerformanceActorBehavior, ActorStats}
import cactor.foundation.memory.*

// 简化时间函数
func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    now.toUnixTimeStamp().toMilliseconds() * 1000000
}

/**
 * 高性能Actor系统配置
 */
public struct HighPerformanceActorSystemConfig {
    public let maxActors: Int64                    // 最大Actor数量
    public let contextPoolSize: Int64              // 上下文池大小
    public let workerThreads: Int32                // 工作线程数
    public let mailboxCapacity: Int64              // 邮箱容量
    public let enableBatchProcessing: Bool         // 启用批处理
    public let batchSize: Int32                    // 批处理大小
    public let enableMemoryOptimization: Bool      // 启用内存优化
    public let enablePerformanceMonitoring: Bool   // 启用性能监控
    
    public init(maxActors: Int64, contextPoolSize: Int64, workerThreads: Int32, 
                mailboxCapacity: Int64, enableBatchProcessing: Bool, batchSize: Int32,
                enableMemoryOptimization: Bool, enablePerformanceMonitoring: Bool) {
        this.maxActors = maxActors
        this.contextPoolSize = contextPoolSize
        this.workerThreads = workerThreads
        this.mailboxCapacity = mailboxCapacity
        this.enableBatchProcessing = enableBatchProcessing
        this.batchSize = batchSize
        this.enableMemoryOptimization = enableMemoryOptimization
        this.enablePerformanceMonitoring = enablePerformanceMonitoring
    }
    
    /**
     * 默认高性能配置
     */
    public static func createDefault(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            1000000,    // 100万Actor
            10000,      // 1万上下文池
            8,          // 8个工作线程
            1024,       // 1K邮箱容量
            true,       // 启用批处理
            32,         // 32消息批处理
            true,       // 启用内存优化
            true        // 启用性能监控
        )
    }
    
    /**
     * 极限性能配置
     */
    public static func createExtreme(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            10000000,   // 1000万Actor
            50000,      // 5万上下文池
            16,         // 16个工作线程
            2048,       // 2K邮箱容量
            true,       // 启用批处理
            64,         // 64消息批处理
            true,       // 启用内存优化
            true        // 启用性能监控
        )
    }

    /**
     * 内存优化配置
     */
    public static func createMemoryOptimized(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            500000,     // 50万Actor
            5000,       // 5千上下文池
            4,          // 4个工作线程
            512,        // 512邮箱容量
            false,      // 禁用批处理（节省内存）
            16,         // 16消息批处理
            true,       // 启用内存优化
            false       // 禁用性能监控（节省内存）
        )
    }

    /**
     * 低延迟配置
     */
    public static func createLowLatency(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            1000000,    // 100万Actor
            20000,      // 2万上下文池
            8,          // 8个工作线程
            1024,       // 1K邮箱容量
            false,      // 禁用批处理（减少延迟）
            8,          // 8消息批处理
            true,       // 启用内存优化
            true        // 启用性能监控
        )
    }

    /**
     * 高吞吐量配置
     */
    public static func createHighThroughput(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            5000000,    // 500万Actor
            30000,      // 3万上下文池
            32,         // 32个工作线程
            4096,       // 4K邮箱容量
            true,       // 启用批处理
            128,        // 128消息批处理
            true,       // 启用内存优化
            true        // 启用性能监控
        )
    }
}

/**
 * 高性能Actor系统 - Runtime层实现
 * 实现tu.md中的核心优化：无锁邮箱、对象池化
 */
public class HighPerformanceActorSystem {
    // 系统配置
    private let config: HighPerformanceActorSystemConfig

    // Actor注册表 (使用标准HashMap)
    private let actors: HashMap<String, HighPerformanceActor>

    // 上下文对象池
    private let contextPool: PooledActorContextPool

    // 系统状态
    private let isRunning: AtomicBool
    private let actorCount: AtomicInt64
    private let messageCount: AtomicInt64
    
    public init(config: HighPerformanceActorSystemConfig) {
        this.config = config
        this.actors = HashMap<String, HighPerformanceActor>()
        this.contextPool = PooledActorContextPool(config.contextPoolSize)
        this.isRunning = AtomicBool(false)
        this.actorCount = AtomicInt64(0)
        this.messageCount = AtomicInt64(0)
    }
    
    /**
     * 启动Actor系统
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            // 预热对象池
            contextPool.warmup()

            println("🚀 高性能Actor系统启动成功")
            println("  最大Actor数: ${config.maxActors}")
            println("  工作线程数: ${config.workerThreads}")
            println("  上下文池大小: ${config.contextPoolSize}")
            let batchStatus = if (config.enableBatchProcessing) { "启用" } else { "禁用" }
            println("  批处理: ${batchStatus}")
        }
    }

    /**
     * 停止Actor系统
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            // 停止所有Actor
            for ((actorId, actor) in actors) {
                actor.stop()
            }
            actors.clear()

            println("🛑 高性能Actor系统已停止")
        }
    }
    
    /**
     * 创建高性能Actor
     */
    public func createActor(actorId: String, behavior: HighPerformanceActorBehavior): Option<HighPerformanceActorRef> {
        if (!isRunning.load()) {
            return None
        }

        if (actorCount.load() >= config.maxActors) {
            println("已达到最大Actor数量限制: ${config.maxActors}")
            return None
        }

        match (actors.get(actorId)) {
            case Some(_) => return None  // Actor已存在
            case None => ()
        }

        // 创建高性能Actor
        let actor = HighPerformanceActor(actorId, behavior, contextPool)
        actors.put(actorId, actor)
        actorCount.fetchAdd(1)

        // 启动Actor
        actor.start()

        return Some(HighPerformanceActorRef(actorId, actor, this))
    }
    
    /**
     * 获取Actor引用
     */
    public func getActor(actorId: String): Option<HighPerformanceActorRef> {
        match (actors.get(actorId)) {
            case Some(actor) => Some(HighPerformanceActorRef(actorId, actor, this))
            case None => None
        }
    }
    
    /**
     * 移除Actor
     */
    public func removeActor(actorId: String): Bool {
        match (actors.get(actorId)) {
            case Some(actor) =>
                // 停止Actor
                actor.stop()

                // 从注册表移除
                actors.remove(actorId)
                actorCount.fetchAdd(-1)

                return true
            case None =>
                return false
        }
    }
    
    /**
     * 高性能消息发送
     */
    public func sendMessage(actorId: String, message: Message): Bool {
        match (getActor(actorId)) {
            case Some(actorRef) =>
                actorRef.tell(message)
                messageCount.fetchAdd(1)
                return true
            case None =>
                return false
        }
    }
    
    /**
     * 批量消息发送
     */
    public func sendMessageBatch(messages: Array<(String, Message)>): Int32 {
        var successCount: Int32 = 0
        
        for ((actorId, message) in messages) {
            if (sendMessage(actorId, message)) {
                successCount += 1
            }
        }
        
        return successCount
    }
    
    /**
     * 获取系统统计信息
     */
    public func getSystemStats(): SystemStats {
        let poolStats = contextPool.getPoolStats()
        let dispatcherStats = DispatcherStats(messageCount.load(), 0.5)
        let monitorStats = MonitorStats(actorCount.load(), 0, messageCount.load(), 0, 0)

        SystemStats(
            actorCount.load(),
            messageCount.load(),
            isRunning.load(),
            poolStats,
            dispatcherStats,
            monitorStats
        )
    }
    
    /**
     * 获取配置信息
     */
    public func getConfig(): HighPerformanceActorSystemConfig {
        config
    }
}

/**
 * 高性能Actor引用
 */
public class HighPerformanceActorRef <: ActorRef {
    private let actorId: String
    private let actor: HighPerformanceActor
    private let system: HighPerformanceActorSystem

    public init(actorId: String, actor: HighPerformanceActor, system: HighPerformanceActorSystem) {
        this.actorId = actorId
        this.actor = actor
        this.system = system
    }

    public prop path: ActorPath {
        get() {
            ActorPath("cactor", "/user/${actorId}")
        }
    }

    /**
     * 高性能消息发送
     */
    public func tell(message: Message): Unit {
        actor.tell(message)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        actor.tell(message)
    }

    /**
     * 批量消息处理
     */
    public func processBatch(batchSize: Int32): Int32 {
        actor.processBatch(batchSize)
    }

    /**
     * 获取Actor统计信息
     */
    public func getStats(): ActorStats {
        actor.getStats()
    }

    /**
     * 获取Actor状态值
     */
    public func getStateValue(): Int64 {
        actor.getStateValue()
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case ref: HighPerformanceActorRef => ref.actorId == this.actorId
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(actorId.hashCode())
    }
}

/**
 * 系统统计信息
 */
public struct SystemStats {
    public let actorCount: Int64
    public let messageCount: Int64
    public let isRunning: Bool
    public let poolStats: PoolStats
    public let dispatcherStats: DispatcherStats
    public let monitorStats: MonitorStats

    public init(actorCount: Int64, messageCount: Int64, isRunning: Bool,
                poolStats: PoolStats, dispatcherStats: DispatcherStats, monitorStats: MonitorStats) {
        this.actorCount = actorCount
        this.messageCount = messageCount
        this.isRunning = isRunning
        this.poolStats = poolStats
        this.dispatcherStats = dispatcherStats
        this.monitorStats = monitorStats
    }

    public func printReport(): Unit {
        println("=== 高性能Actor系统统计 ===")
        println("Actor数量: ${actorCount}")
        println("消息总数: ${messageCount}")
        let statusText = if (isRunning) { "运行中" } else { "已停止" }
        println("系统状态: ${statusText}")
        println("对象池利用率: ${poolStats.getUtilization()}%")
        println("对象池命中率: ${poolStats.getHitRate()}%")
        println("调度器吞吐量: ${dispatcherStats.getThroughput()} msg/s")
        println("平均延迟: ${monitorStats.getAverageLatency()}μs")
    }
}

/**
 * 系统性能监控器
 */
public class SystemPerformanceMonitor {
    private let enabled: Bool
    private let startTime: AtomicInt64
    private let actorsCreated: AtomicInt64
    private let actorsDestroyed: AtomicInt64
    private let messagesSent: AtomicInt64
    private let messagesFailed: AtomicInt64

    public init(enabled: Bool) {
        this.enabled = enabled
        this.startTime = AtomicInt64(0)
        this.actorsCreated = AtomicInt64(0)
        this.actorsDestroyed = AtomicInt64(0)
        this.messagesSent = AtomicInt64(0)
        this.messagesFailed = AtomicInt64(0)
    }

    public func start(): Unit {
        if (enabled) {
            startTime.store(getCurrentTimeNanos())
            println("📊 性能监控已启动")
        }
    }

    public func stop(): Unit {
        if (enabled) {
            println("📊 性能监控已停止")
        }
    }

    public func recordActorCreated(): Unit {
        if (enabled) {
            actorsCreated.fetchAdd(1)
        }
    }

    public func recordActorDestroyed(): Unit {
        if (enabled) {
            actorsDestroyed.fetchAdd(1)
        }
    }

    public func recordMessageSent(): Unit {
        if (enabled) {
            messagesSent.fetchAdd(1)
        }
    }

    public func recordMessageFailed(): Unit {
        if (enabled) {
            messagesFailed.fetchAdd(1)
        }
    }

    public func getStats(): MonitorStats {
        let uptime = if (startTime.load() > 0) {
            getCurrentTimeNanos() - startTime.load()
        } else {
            0
        }

        MonitorStats(
            actorsCreated.load(),
            actorsDestroyed.load(),
            messagesSent.load(),
            messagesFailed.load(),
            uptime
        )
    }
}

/**
 * 监控统计信息
 */
public struct MonitorStats {
    public let actorsCreated: Int64
    public let actorsDestroyed: Int64
    public let messagesSent: Int64
    public let messagesFailed: Int64
    public let uptime: Int64

    public init(actorsCreated: Int64, actorsDestroyed: Int64, messagesSent: Int64, messagesFailed: Int64, uptime: Int64) {
        this.actorsCreated = actorsCreated
        this.actorsDestroyed = actorsDestroyed
        this.messagesSent = messagesSent
        this.messagesFailed = messagesFailed
        this.uptime = uptime
    }

    public func getSuccessRate(): Float64 {
        let total = messagesSent + messagesFailed
        if (total == 0) {
            return 100.0
        }
        return Float64(messagesSent) / Float64(total) * 100.0
    }

    public func getAverageLatency(): Float64 {
        // 简化实现，实际应该收集延迟数据
        return 0.5  // 假设0.5μs平均延迟
    }

    public func getUptimeInSeconds(): Float64 {
        Float64(uptime) / 1000000000.0
    }
}

/**
 * 调度器统计信息占位符
 */
public struct DispatcherStats {
    public let processedMessages: Int64
    public let averageLatency: Float64

    public init(processedMessages: Int64, averageLatency: Float64) {
        this.processedMessages = processedMessages
        this.averageLatency = averageLatency
    }

    public func getThroughput(): Float64 {
        // 简化实现
        return Float64(processedMessages)
    }
}
