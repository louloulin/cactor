/*
 * Copyright (c) 2024. All rights reserved.
 * EnterpriseActorSystem - 企业级Actor系统
 * 基于plan10.md设计，提供生产级Actor系统实现
 */
package cactor.integration.enterprise

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.system.{ActorSystem}
import cactor.core.config.{ActorSystemConfig}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.runtime.lifecycle.{ActorLifecycleManager}
import cactor.runtime.registry.{SimpleActorRegistry}
import cactor.runtime.supervision.{SupervisionManager}
import cactor.runtime.monitoring.{ActorSystemMetrics}
import cactor.runtime.events.{SimpleActorEventBus}

/**
 * 企业级Actor系统
 * 
 * 基于plan10.md设计，提供：
 * 1. 统一的CActorRuntime管理
 * 2. 企业级配置和监控
 * 3. 高性能和可扩展性
 * 4. 生产级容错和恢复
 */
public class EnterpriseActorSystem <: ActorSystem {
    private let runtime: CActorRuntime
    private let config: EnterpriseActorSystemConfig
    private let isShutdown: AtomicBool
    
    public init(name: String, config: EnterpriseActorSystemConfig) {
        let runtimeConfig = config.toCActorRuntimeConfig()
        this.runtime = CActorRuntime(name, runtimeConfig)
        this.config = config
        this.isShutdown = AtomicBool(false)
    }
    
    /**
     * 系统名称
     */
    public prop name: String {
        get() { runtime.systemName }
    }
    
    /**
     * 创建Actor
     */
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        if (isShutdown.load()) {
            throw Exception("ActorSystem已关闭")
        }
        return runtime.actorOf(props, name)
    }
    
    /**
     * 创建Actor（自动生成名称）
     */
    public func actorOf(props: Props<Actor>): ActorRef {
        if (isShutdown.load()) {
            throw Exception("ActorSystem已关闭")
        }
        return runtime.actorOf(props)
    }
    
    /**
     * 启动系统
     */
    public func start(): Unit {
        runtime.start()
        println("🏢 EnterpriseActorSystem启动完成")
        printSystemInfo()
    }
    
    /**
     * 关闭系统
     */
    public func shutdown(): Unit {
        if (isShutdown.compareAndSwap(false, true)) {
            println("🏢 EnterpriseActorSystem开始关闭...")
            runtime.shutdown()
            println("🏢 EnterpriseActorSystem关闭完成")
        }
    }
    
    /**
     * 获取系统统计信息
     */
    public func getSystemStats(): EnterpriseSystemStats {
        let runtimeStats = runtime.getRuntimeStats()
        let metrics = runtime.getSystemMetrics()
        let perfMetrics = metrics.getPerformanceMetrics()
        
        EnterpriseSystemStats(
            runtimeStats.systemName,
            runtimeStats.isRunning,
            runtimeStats.actorCount,
            runtimeStats.uptime,
            perfMetrics.messagesThroughput,
            perfMetrics.averageLatency,
            perfMetrics.errorRate,
            metrics.getBasicStats().get("totalMessages")
        )
    }
    
    /**
     * 获取CActorRuntime
     */
    public func getRuntime(): CActorRuntime {
        runtime
    }
    
    /**
     * 获取配置
     */
    public func getConfig(): EnterpriseActorSystemConfig {
        config
    }
    
    /**
     * 检查系统是否已关闭
     */
    public func isTerminated(): Bool {
        isShutdown.load()
    }
    
    /**
     * 打印系统信息
     */
    private func printSystemInfo(): Unit {
        println("=== 企业级Actor系统信息 ===")
        println("系统名称: ${name}")
        println("配置模式: ${config.mode}")
        println("监控启用: ${config.enableMonitoring}")
        println("持久化启用: ${config.enablePersistence}")
        println("扩展启用: ${config.enableExtensions}")
        println("性能模式: ${config.performanceMode}")
        println("========================")
    }
}

/**
 * 企业级Actor系统配置
 */
public struct EnterpriseActorSystemConfig {
    public let mode: SystemMode
    public let enableMonitoring: Bool
    public let enablePersistence: Bool
    public let enableExtensions: Bool
    public let performanceMode: PerformanceMode
    public let maxActors: Int64
    public let maxThroughput: Int64
    
    public init(
        mode: SystemMode,
        enableMonitoring: Bool,
        enablePersistence: Bool,
        enableExtensions: Bool,
        performanceMode: PerformanceMode,
        maxActors: Int64,
        maxThroughput: Int64
    ) {
        this.mode = mode
        this.enableMonitoring = enableMonitoring
        this.enablePersistence = enablePersistence
        this.enableExtensions = enableExtensions
        this.performanceMode = performanceMode
        this.maxActors = maxActors
        this.maxThroughput = maxThroughput
    }
    
    /**
     * 创建开发环境配置
     */
    public static func createDevelopment(): EnterpriseActorSystemConfig {
        EnterpriseActorSystemConfig(
            SystemMode.Development,
            true,   // 启用监控
            false,  // 禁用持久化
            true,   // 启用扩展
            PerformanceMode.Balanced,
            100_000,    // 10万Actor
            1_000_000   // 100万msg/s
        )
    }
    
    /**
     * 创建生产环境配置
     */
    public static func createProduction(): EnterpriseActorSystemConfig {
        EnterpriseActorSystemConfig(
            SystemMode.Production,
            true,   // 启用监控
            true,   // 启用持久化
            true,   // 启用扩展
            PerformanceMode.HighThroughput,
            1_000_000,   // 100万Actor
            50_000_000   // 5000万msg/s
        )
    }
    
    /**
     * 创建极限性能配置
     */
    public static func createExtreme(): EnterpriseActorSystemConfig {
        EnterpriseActorSystemConfig(
            SystemMode.Production,
            true,   // 启用监控
            true,   // 启用持久化
            true,   // 启用扩展
            PerformanceMode.Extreme,
            10_000_000,   // 1000万Actor
            100_000_000   // 1亿msg/s
        )
    }
    
    /**
     * 转换为CActorRuntimeConfig
     */
    public func toCActorRuntimeConfig(): CActorRuntimeConfig {
        match (performanceMode) {
            case PerformanceMode.Balanced =>
                CActorRuntimeConfig.createDefault()
            case PerformanceMode.HighThroughput =>
                CActorRuntimeConfig.createProduction()
            case PerformanceMode.Extreme =>
                CActorRuntimeConfig.createProduction()
        }
    }
}

/**
 * 系统模式枚举
 */
public enum SystemMode {
    | Development
    | Testing
    | Production
}

/**
 * 性能模式枚举
 */
public enum PerformanceMode {
    | Balanced      // 平衡模式
    | HighThroughput // 高吞吐量模式
    | LowLatency    // 低延迟模式
    | Extreme       // 极限性能模式
}

/**
 * 企业级系统统计信息
 */
public struct EnterpriseSystemStats {
    public let systemName: String
    public let isRunning: Bool
    public let actorCount: Int64
    public let uptime: Int64
    public let throughput: Float64
    public let averageLatency: Float64
    public let errorRate: Float64
    public let totalMessages: Int64
    
    public init(
        systemName: String,
        isRunning: Bool,
        actorCount: Int64,
        uptime: Int64,
        throughput: Float64,
        averageLatency: Float64,
        errorRate: Float64,
        totalMessages: Int64
    ) {
        this.systemName = systemName
        this.isRunning = isRunning
        this.actorCount = actorCount
        this.uptime = uptime
        this.throughput = throughput
        this.averageLatency = averageLatency
        this.errorRate = errorRate
        this.totalMessages = totalMessages
    }
    
    /**
     * 打印企业级统计报告
     */
    public func printEnterpriseReport(): Unit {
        println("=== 企业级Actor系统统计报告 ===")
        println("系统名称: ${systemName}")
        let status = if (isRunning) { "🟢 运行中" } else { "🔴 已停止" }
        println("运行状态: ${status}")
        println("Actor数量: ${formatNumber(actorCount)}")
        println("运行时长: ${formatUptime(uptime)}")
        println("消息吞吐量: ${formatThroughput(throughput)}")
        println("平均延迟: ${formatLatency(averageLatency)}")
        println("错误率: ${formatErrorRate(errorRate)}")
        println("总消息数: ${formatNumber(totalMessages)}")
        println("==============================")
    }
    
    private func formatNumber(num: Int64): String {
        if (num >= 1_000_000) {
            "${num / 1_000_000}M"
        } else if (num >= 1_000) {
            "${num / 1_000}K"
        } else {
            "${num}"
        }
    }
    
    private func formatUptime(nanos: Int64): String {
        let seconds = nanos / 1_000_000_000
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        "${hours}h ${minutes}m ${secs}s"
    }
    
    private func formatThroughput(throughput: Float64): String {
        if (throughput >= 1_000_000.0) {
            "${throughput / 1_000_000.0}M msg/s"
        } else if (throughput >= 1_000.0) {
            "${throughput / 1_000.0}K msg/s"
        } else {
            "${throughput} msg/s"
        }
    }
    
    private func formatLatency(latency: Float64): String {
        if (latency >= 1000.0) {
            "${latency / 1000.0}ms"
        } else {
            "${latency}μs"
        }
    }
    
    private func formatErrorRate(rate: Float64): String {
        "${rate}%"
    }
}
