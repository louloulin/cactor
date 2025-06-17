/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - 统一运行时管理器
 * 实现plan10.md中的CActorRuntime设计
 */
package cactor.runtime

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.system.{ActorSystem}
import cactor.core.guardian.{GuardianType}
import cactor.runtime.guardian.{RuntimeSystemGuardian, RuntimeUserGuardian}
import cactor.runtime.system.{HighPerformanceActorSystem, HighPerformanceActorSystemConfig, SystemStats}
import cactor.runtime.mailbox.factory.{AdvancedMailboxFactory, DefaultAdvancedMailboxFactory}
import cactor.runtime.dispatcher.factory.{AdvancedDispatcherFactory, DefaultAdvancedDispatcherFactory}
import cactor.runtime.system.{SimpleActorSystem}
import cactor.runtime.dispatcher.{DispatcherPool}
import cactor.runtime.mailbox.{MailboxFactory}
import cactor.core.guardian.{GuardianStats}
import cactor.core.config.{MailboxConfig, DispatcherConfig}
import cactor.runtime.lifecycle.{ActorLifecycleManager}
import cactor.runtime.registry.{SimpleActorRegistry}
import cactor.runtime.supervision.{SupervisionManager, SupervisionConfig}
import cactor.runtime.monitoring.{ActorSystemMetrics}
import cactor.runtime.events.{SimpleActorEventBus}
import cactor.core.supervision.{SupervisionStrategy}
import cactor.runtime.supervision.{SimpleSupervisionStrategy}


/**
 * CActorRuntime - 统一运行时管理器
 * 
 * 核心职责：
 * 1. 统一管理Actor系统的生命周期
 * 2. 提供Guardian Actor的完整实现
 * 3. 集成调度器、邮箱、定时器等运行时组件
 * 4. 提供生产级的Actor创建、停止、重启接口
 */
public class CActorRuntime {
    // 核心组件
    private let systemName: String
    private let actorSystem: ActorSystem
    private let systemGuardian: RuntimeSystemGuardian
    private let userGuardian: RuntimeUserGuardian
    
    // 运行时组件
    private let mailboxFactory: AdvancedMailboxFactory
    private let dispatcherFactory: AdvancedDispatcherFactory
    private let highPerformanceSystem: HighPerformanceActorSystem

    // plan10.md新增的企业级组件
    private let lifecycleManager: ActorLifecycleManager
    private let actorRegistry: SimpleActorRegistry
    private let supervisionManager: SupervisionManager
    private let systemMetrics: ActorSystemMetrics
    private let eventBus: SimpleActorEventBus

    // 运行时状态
    private let isRunning: AtomicBool
    private let startTime: AtomicInt64
    private let actorCount: AtomicInt64

    // 配置
    private let config: CActorRuntimeConfig
    
    public init(systemName: String, config: CActorRuntimeConfig) {
        this.systemName = systemName
        this.config = config

        // 创建基础ActorSystem
        this.actorSystem = SimpleActorSystem(systemName)

        // 创建企业级组件 (plan10.md)
        this.eventBus = SimpleActorEventBus()
        this.systemMetrics = ActorSystemMetrics()
        this.actorRegistry = SimpleActorRegistry()
        this.supervisionManager = SupervisionManager(SupervisionConfig.createDefault())
        this.lifecycleManager = ActorLifecycleManager()

        // 创建Guardian Actors
        this.systemGuardian = RuntimeSystemGuardian(actorSystem)
        this.userGuardian = RuntimeUserGuardian(actorSystem)

        // 创建运行时组件
        this.mailboxFactory = DefaultAdvancedMailboxFactory()
        this.dispatcherFactory = DefaultAdvancedDispatcherFactory()
        this.highPerformanceSystem = HighPerformanceActorSystem(config.highPerformanceConfig)

        // 初始化状态
        this.isRunning = AtomicBool(false)
        this.startTime = AtomicInt64(0)
        this.actorCount = AtomicInt64(0)
    }
    
    /**
     * 启动Runtime系统
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            startTime.store(getCurrentTimeNanos())
            
            // 启动高性能系统
            highPerformanceSystem.start()
            
            // 创建用户Guardian
            systemGuardian.createUserGuardian()
            
            println("🚀 CActorRuntime启动成功")
            println("  系统名称: ${systemName}")
            println("  启动时间: ${DateTime.now()}")
            println("  配置: ${config.getDescription()}")
        }
    }
    
    /**
     * 停止Runtime系统
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            // 停止高性能系统
            highPerformanceSystem.shutdown()
            
            // 停止所有Guardian
            // systemGuardian和userGuardian的停止逻辑
            
            println("🛑 CActorRuntime已停止")
        }
    }
    
    /**
     * 创建Actor - 统一接口 (plan10.md设计)
     * 实现完整的Actor创建流程
     */
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        if (!isRunning.load()) {
            throw Exception("Runtime系统未启动")
        }

        // 1. 验证和准备
        validateActorCreation(name, None<ActorRef>)

        // 2. 通过用户Guardian创建Actor
        let actorRef = userGuardian.createUserActor(props, name)

        // 3. 注册到Actor注册表
        actorRegistry.register(actorRef, Some("/user"))

        // 4. 注册到生命周期管理器
        lifecycleManager.registerActor(actorRef)

        // 5. 设置监督策略
        setupSupervision(actorRef, props, None<ActorRef>)

        // 6. 启动Actor
        lifecycleManager.startActor(actorRef)

        // 7. 更新统计
        systemMetrics.incrementActorCount()
        actorCount.fetchAdd(1)

        return actorRef
    }
    
    /**
     * 创建Actor - 自动生成名称
     */
    public func actorOf(props: Props<Actor>): ActorRef {
        let autoName = generateActorName()
        return actorOf(props, autoName)
    }
    
    /**
     * 停止Actor
     */
    public func stop(actorRef: ActorRef): Unit {
        userGuardian.stopChild(actorRef)
        actorCount.fetchAdd(-1)
    }
    
    /**
     * 重启Actor
     */
    public func restart(actorRef: ActorRef, reason: Exception): Unit {
        userGuardian.restartChild(actorRef, reason)
    }
    
    /**
     * 获取系统Guardian
     */
    public func getSystemGuardian(): RuntimeSystemGuardian {
        systemGuardian
    }
    
    /**
     * 获取用户Guardian
     */
    public func getUserGuardian(): RuntimeUserGuardian {
        userGuardian
    }
    
    /**
     * 获取高性能系统
     */
    public func getHighPerformanceSystem(): HighPerformanceActorSystem {
        highPerformanceSystem
    }
    
    /**
     * 获取运行时统计
     */
    public func getRuntimeStats(): CActorRuntimeStats {
        let uptime = if (startTime.load() > 0) {
            getCurrentTimeNanos() - startTime.load()
        } else {
            0
        }
        
        CActorRuntimeStats(
            systemName,
            isRunning.load(),
            actorCount.load(),
            uptime,
            systemGuardian.getStats(),
            userGuardian.getStats(),
            highPerformanceSystem.getSystemStats()
        )
    }
    
    /**
     * 获取配置
     */
    public func getConfig(): CActorRuntimeConfig {
        config
    }
    
    // 私有辅助方法
    private func createBaseActorSystem(name: String): ActorSystem {
        // 创建基础ActorSystem实现
        // 这里应该使用Core层的基础实现
        SimpleActorSystem(name)
    }

    /**
     * 获取邮箱工厂
     */
    public func getMailboxFactory(): AdvancedMailboxFactory {
        mailboxFactory
    }

    /**
     * 获取调度器工厂
     */
    public func getDispatcherFactory(): AdvancedDispatcherFactory {
        dispatcherFactory
    }

    /**
     * 获取基础Actor系统
     */
    public func getActorSystem(): ActorSystem {
        actorSystem
    }
    
    private func generateActorName(): String {
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let counter = actorCount.load()
        "actor-${timestamp}-${counter}"
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }

    /**
     * 验证Actor创建参数
     */
    private func validateActorCreation(name: String, parent: Option<ActorRef>): Unit {
        if (name.isEmpty()) {
            throw Exception("Actor名称不能为空")
        }

        // 检查名称是否已存在
        match (actorRegistry.findByName(name)) {
            case Some(existingActor) =>
                throw Exception("Actor名称已存在: ${name}")
            case None =>
                ()  // 名称可用
        }
    }

    /**
     * 设置Actor监督策略
     */
    private func setupSupervision(actorRef: ActorRef, props: Props<Actor>, parent: Option<ActorRef>): Unit {
        // 使用默认监督策略
        let strategy = createDefaultSupervisionStrategy()
        supervisionManager.supervise(actorRef, strategy)
    }

    /**
     * 创建默认监督策略
     */
    private func createDefaultSupervisionStrategy(): SupervisionStrategy {
        // 简化实现，返回一个基本的监督策略
        // 这里需要实现一个具体的SupervisionStrategy
        SimpleSupervisionStrategy(3, 60)
    }

    /**
     * 获取生命周期管理器
     */
    public func getLifecycleManager(): ActorLifecycleManager {
        lifecycleManager
    }

    /**
     * 获取Actor注册表
     */
    public func getActorRegistry(): SimpleActorRegistry {
        actorRegistry
    }

    /**
     * 获取监督管理器
     */
    public func getSupervisionManager(): SupervisionManager {
        supervisionManager
    }

    /**
     * 获取系统指标
     */
    public func getSystemMetrics(): ActorSystemMetrics {
        systemMetrics
    }

    /**
     * 获取事件总线
     */
    public func getEventBus(): SimpleActorEventBus {
        eventBus
    }
}

/**
 * CActorRuntime配置
 */
public struct CActorRuntimeConfig {
    public let mailboxConfig: MailboxConfig
    public let dispatcherConfig: DispatcherConfig
    public let highPerformanceConfig: HighPerformanceActorSystemConfig
    public let enableMonitoring: Bool
    public let enablePersistence: Bool

    public init(
        mailboxConfig: MailboxConfig,
        dispatcherConfig: DispatcherConfig,
        highPerformanceConfig: HighPerformanceActorSystemConfig,
        enableMonitoring: Bool,
        enablePersistence: Bool
    ) {
        this.mailboxConfig = mailboxConfig
        this.dispatcherConfig = dispatcherConfig
        this.highPerformanceConfig = highPerformanceConfig
        this.enableMonitoring = enableMonitoring
        this.enablePersistence = enablePersistence
    }
    
    /**
     * 创建默认配置
     */
    public static func createDefault(): CActorRuntimeConfig {
        CActorRuntimeConfig(
            MailboxConfig.createUnbounded(),
            DispatcherConfig.createThreadPool(),
            HighPerformanceActorSystemConfig.createDefault(),
            true,  // 启用监控
            false  // 禁用持久化
        )
    }

    /**
     * 创建生产级配置
     */
    public static func createProduction(): CActorRuntimeConfig {
        CActorRuntimeConfig(
            MailboxConfig.createBounded(10000),
            DispatcherConfig.createWorkStealing(),
            HighPerformanceActorSystemConfig.createExtreme(),
            true,  // 启用监控
            true   // 启用持久化
        )
    }

    /**
     * 创建极限性能配置 - 基于plan2.md优化方案
     * 目标：从4,982 msg/s提升到1M msg/s (200x提升)
     */
    public static func createExtreme(): CActorRuntimeConfig {
        // 高性能邮箱配置
        let mailboxConfig = MailboxConfig.createUnbounded()

        // 工作窃取调度器配置
        let dispatcherConfig = DispatcherConfig.createWorkStealing()

        // 极限性能系统配置
        let highPerfConfig = HighPerformanceActorSystemConfig.createExtreme()

        return CActorRuntimeConfig(
            mailboxConfig,
            dispatcherConfig,
            highPerfConfig,
            true,  // 启用监控
            false  // 禁用持久化（性能优先）
        )
    }

    /**
     * 创建内存优化配置
     * 目标：<1KB/Actor内存使用
     */
    public static func createMemoryOptimized(): CActorRuntimeConfig {
        let mailboxConfig = MailboxConfig.createBounded(1000)
        let dispatcherConfig = DispatcherConfig.createThreadPool()
        let highPerfConfig = HighPerformanceActorSystemConfig.createMemoryOptimized()

        return CActorRuntimeConfig(
            mailboxConfig,
            dispatcherConfig,
            highPerfConfig,
            false, // 禁用监控（节省内存）
            false  // 禁用持久化
        )
    }

    /**
     * 创建低延迟配置
     * 目标：P99 < 100μs
     */
    public static func createLowLatency(): CActorRuntimeConfig {
        let mailboxConfig = MailboxConfig.createUnbounded()
        let dispatcherConfig = DispatcherConfig.createPinned()
        let highPerfConfig = HighPerformanceActorSystemConfig.createLowLatency()

        return CActorRuntimeConfig(
            mailboxConfig,
            dispatcherConfig,
            highPerfConfig,
            true,  // 启用监控（延迟统计）
            false  // 禁用持久化
        )
    }

    /**
     * 创建高吞吐量配置
     * 目标：50M msg/s
     */
    public static func createHighThroughput(): CActorRuntimeConfig {
        let mailboxConfig = MailboxConfig.createUnbounded()
        let dispatcherConfig = DispatcherConfig.createWorkStealing()
        let highPerfConfig = HighPerformanceActorSystemConfig.createHighThroughput()

        return CActorRuntimeConfig(
            mailboxConfig,
            dispatcherConfig,
            highPerfConfig,
            true,  // 启用监控（吞吐量统计）
            false  // 禁用持久化
        )
    }
    
    public func getDescription(): String {
        "CActorRuntimeConfig(monitoring=${enableMonitoring}, persistence=${enablePersistence})"
    }
}

/**
 * CActorRuntime统计信息
 */
public struct CActorRuntimeStats {
    public let systemName: String
    public let isRunning: Bool
    public let actorCount: Int64
    public let uptime: Int64
    public let systemGuardianStats: GuardianStats
    public let userGuardianStats: GuardianStats
    public let highPerformanceStats: SystemStats
    
    public init(
        systemName: String,
        isRunning: Bool,
        actorCount: Int64,
        uptime: Int64,
        systemGuardianStats: GuardianStats,
        userGuardianStats: GuardianStats,
        highPerformanceStats: SystemStats
    ) {
        this.systemName = systemName
        this.isRunning = isRunning
        this.actorCount = actorCount
        this.uptime = uptime
        this.systemGuardianStats = systemGuardianStats
        this.userGuardianStats = userGuardianStats
        this.highPerformanceStats = highPerformanceStats
    }
    
    public func printReport(): Unit {
        println("=== CActorRuntime统计报告 ===")
        println("系统名称: ${systemName}")
        let status = if (isRunning) { "运行中" } else { "已停止" }
        println("运行状态: ${status}")
        println("Actor数量: ${actorCount}")
        println("运行时长: ${getUptimeInSeconds()}秒")
        println("系统Guardian: ${systemGuardianStats.childCount}个子Actor")
        println("用户Guardian: ${userGuardianStats.childCount}个子Actor")
        println("高性能系统: ${highPerformanceStats.actorCount}个高性能Actor")
    }
    
    public func getUptimeInSeconds(): Float64 {
        Float64(uptime) / 1000000000.0
    }
}
