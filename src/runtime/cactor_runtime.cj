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
import cactor.core.guardian.{GuardianStats}
import cactor.core.config.{MailboxConfig, DispatcherConfig}

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
        this.actorSystem = createBaseActorSystem(systemName)
        
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
     * 创建Actor - 统一接口
     */
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        if (!isRunning.load()) {
            throw Exception("Runtime系统未启动")
        }
        
        // 通过用户Guardian创建Actor
        let actorRef = userGuardian.createUserActor(props, name)
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
