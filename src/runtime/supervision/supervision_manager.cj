/*
 * Copyright (c) 2024. All rights reserved.
 * SupervisionManager - 监督管理器
 * 基于plan10.md设计，提供企业级的Actor监督和容错管理
 */
package cactor.runtime.supervision

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef}
import cactor.core.supervision.{SupervisionStrategy, SupervisionDirective, ActorFailure}
import cactor.runtime.events.{ActorEventBus}

/**
 * 监督配置
 */
public struct SupervisionConfig {
    public let maxRetries: Int32                    // 最大重试次数
    public let retryTimeWindow: Duration            // 重试时间窗口
    public let escalationThreshold: Int32           // 升级阈值
    public let enableCircuitBreaker: Bool           // 启用断路器
    public let circuitBreakerTimeout: Duration      // 断路器超时
    
    public init(
        maxRetries: Int32,
        retryTimeWindow: Duration,
        escalationThreshold: Int32,
        enableCircuitBreaker: Bool,
        circuitBreakerTimeout: Duration
    ) {
        this.maxRetries = maxRetries
        this.retryTimeWindow = retryTimeWindow
        this.escalationThreshold = escalationThreshold
        this.enableCircuitBreaker = enableCircuitBreaker
        this.circuitBreakerTimeout = circuitBreakerTimeout
    }
    
    /**
     * 创建默认配置
     */
    public static func createDefault(): SupervisionConfig {
        SupervisionConfig(
            3,                              // 最大重试3次
            Duration.minute * 1,            // 1分钟时间窗口
            5,                              // 5次失败后升级
            true,                           // 启用断路器
            Duration.second * 30            // 30秒断路器超时
        )
    }
    
    /**
     * 创建严格配置
     */
    public static func createStrict(): SupervisionConfig {
        SupervisionConfig(
            1,                              // 最大重试1次
            Duration.second * 30,           // 30秒时间窗口
            2,                              // 2次失败后升级
            true,                           // 启用断路器
            Duration.second * 60            // 60秒断路器超时
        )
    }
}

/**
 * Actor监督状态
 */
public enum SupervisionState {
    | Normal          // 正常状态
    | Warning         // 警告状态
    | Critical        // 严重状态
    | CircuitOpen     // 断路器开启
    | Escalated       // 已升级
}

/**
 * Actor监督信息
 */
public struct ActorSupervisionInfo {
    public let actorRef: ActorRef
    public let strategy: SupervisionStrategy
    public let state: SupervisionState
    public let failureCount: Int32
    public let lastFailureTime: Int64
    public let restartCount: Int32
    public let escalationCount: Int32
    public let circuitBreakerOpenTime: Int64
    
    public init(
        actorRef: ActorRef,
        strategy: SupervisionStrategy,
        state: SupervisionState,
        failureCount: Int32,
        lastFailureTime: Int64,
        restartCount: Int32,
        escalationCount: Int32,
        circuitBreakerOpenTime: Int64
    ) {
        this.actorRef = actorRef
        this.strategy = strategy
        this.state = state
        this.failureCount = failureCount
        this.lastFailureTime = lastFailureTime
        this.restartCount = restartCount
        this.escalationCount = escalationCount
        this.circuitBreakerOpenTime = circuitBreakerOpenTime
    }
}

/**
 * 监督统计信息
 */
public struct SupervisionStats {
    public let totalSupervised: Int64
    public let totalFailures: Int64
    public let totalRestarts: Int64
    public let totalEscalations: Int64
    public let circuitBreakerTrips: Int64
    public let averageRecoveryTime: Float64
    
    public init(
        totalSupervised: Int64,
        totalFailures: Int64,
        totalRestarts: Int64,
        totalEscalations: Int64,
        circuitBreakerTrips: Int64,
        averageRecoveryTime: Float64
    ) {
        this.totalSupervised = totalSupervised
        this.totalFailures = totalFailures
        this.totalRestarts = totalRestarts
        this.totalEscalations = totalEscalations
        this.circuitBreakerTrips = circuitBreakerTrips
        this.averageRecoveryTime = averageRecoveryTime
    }
}

/**
 * 监督管理器
 * 
 * 职责：
 * 1. 管理Actor的监督策略
 * 2. 处理Actor失败和恢复
 * 3. 实现断路器模式
 * 4. 提供监督统计和监控
 */
public class SupervisionManager {
    private let config: SupervisionConfig
    private let supervisionInfos: ConcurrentHashMap<String, ActorSupervisionInfo>
    private let eventBus: ActorEventBus
    
    // 统计计数器
    private let totalSupervised: AtomicInt64
    private let totalFailures: AtomicInt64
    private let totalRestarts: AtomicInt64
    private let totalEscalations: AtomicInt64
    private let circuitBreakerTrips: AtomicInt64
    
    // 管理器状态
    private let isRunning: AtomicBool
    private let managerLock: RwLock
    
    public init(config: SupervisionConfig) {
        this.config = config
        this.supervisionInfos = ConcurrentHashMap<String, ActorSupervisionInfo>()
        this.eventBus = ActorEventBus()
        
        this.totalSupervised = AtomicInt64(0)
        this.totalFailures = AtomicInt64(0)
        this.totalRestarts = AtomicInt64(0)
        this.totalEscalations = AtomicInt64(0)
        this.circuitBreakerTrips = AtomicInt64(0)
        
        this.isRunning = AtomicBool(true)
        this.managerLock = RwLock()
    }
    
    /**
     * 注册Actor监督
     */
    public func supervise(actorRef: ActorRef, strategy: SupervisionStrategy): Unit {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        managerLock.lockWrite()
        try {
            let info = ActorSupervisionInfo(
                actorRef,
                strategy,
                SupervisionState.Normal,
                0,      // failureCount
                0,      // lastFailureTime
                0,      // restartCount
                0,      // escalationCount
                0       // circuitBreakerOpenTime
            )
            
            supervisionInfos.put(path, info)
            totalSupervised.fetchAdd(1)
            
        } finally {
            managerLock.unlockWrite()
        }
    }
    
    /**
     * 取消Actor监督
     */
    public func unsupervise(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        
        managerLock.lockWrite()
        try {
            supervisionInfos.remove(path)
        } finally {
            managerLock.unlockWrite()
        }
    }
    
    /**
     * 处理Actor失败
     */
    public func handleFailure(actorRef: ActorRef, failure: ActorFailure): SupervisionDirective {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        managerLock.lockRead()
        try {
            match (supervisionInfos.get(path)) {
                case Some(info) =>
                    // 检查断路器状态
                    if (info.state == SupervisionState.CircuitOpen) {
                        if (shouldCloseCircuitBreaker(info, currentTime)) {
                            // 关闭断路器，尝试恢复
                            updateSupervisionState(actorRef, SupervisionState.Normal)
                        } else {
                            // 断路器仍然开启，直接停止
                            return SupervisionDirective.Stop
                        }
                    }
                    
                    // 更新失败统计
                    totalFailures.fetchAdd(1)
                    
                    // 根据监督策略决定处理方式
                    let directive = info.strategy.decide(failure)
                    
                    // 执行监督决策
                    executeSupervisionDirective(actorRef, directive, failure, currentTime)
                    
                    return directive
                    
                case None =>
                    // Actor未被监督，使用默认策略
                    return SupervisionDirective.Stop
            }
        } finally {
            managerLock.unlockRead()
        }
    }
    
    /**
     * 获取Actor监督信息
     */
    public func getSupervisionInfo(actorRef: ActorRef): Option<ActorSupervisionInfo> {
        let path = actorRef.path.toString()
        supervisionInfos.get(path)
    }
    
    /**
     * 获取所有监督信息
     */
    public func getAllSupervisionInfos(): Array<ActorSupervisionInfo> {
        let result = Array<ActorSupervisionInfo>()
        for ((path, info) in supervisionInfos) {
            result.append(info)
        }
        result
    }
    
    /**
     * 获取监督统计
     */
    public func getSupervisionStats(): SupervisionStats {
        SupervisionStats(
            totalSupervised.load(),
            totalFailures.load(),
            totalRestarts.load(),
            totalEscalations.load(),
            circuitBreakerTrips.load(),
            calculateAverageRecoveryTime()
        )
    }
    
    /**
     * 重置统计信息
     */
    public func resetStats(): Unit {
        totalSupervised.store(0)
        totalFailures.store(0)
        totalRestarts.store(0)
        totalEscalations.store(0)
        circuitBreakerTrips.store(0)
    }
    
    /**
     * 关闭监督管理器
     */
    public func shutdown(): Unit {
        isRunning.store(false)
        supervisionInfos.clear()
    }
    
    /**
     * 打印监督统计报告
     */
    public func printReport(): Unit {
        let stats = getSupervisionStats()
        
        println("=== 监督管理器统计报告 ===")
        println("监督Actor总数: ${stats.totalSupervised}")
        println("失败总数: ${stats.totalFailures}")
        println("重启总数: ${stats.totalRestarts}")
        println("升级总数: ${stats.totalEscalations}")
        println("断路器触发次数: ${stats.circuitBreakerTrips}")
        println("平均恢复时间: ${stats.averageRecoveryTime:.2f}ms")
        
        // 打印各状态的Actor数量
        var normalCount = 0
        var warningCount = 0
        var criticalCount = 0
        var circuitOpenCount = 0
        var escalatedCount = 0
        
        for ((path, info) in supervisionInfos) {
            match (info.state) {
                case SupervisionState.Normal => normalCount += 1
                case SupervisionState.Warning => warningCount += 1
                case SupervisionState.Critical => criticalCount += 1
                case SupervisionState.CircuitOpen => circuitOpenCount += 1
                case SupervisionState.Escalated => escalatedCount += 1
            }
        }
        
        println("状态分布:")
        println("  正常: ${normalCount}")
        println("  警告: ${warningCount}")
        println("  严重: ${criticalCount}")
        println("  断路器开启: ${circuitOpenCount}")
        println("  已升级: ${escalatedCount}")
    }
    
    // 私有辅助方法
    private func executeSupervisionDirective(
        actorRef: ActorRef,
        directive: SupervisionDirective,
        failure: ActorFailure,
        currentTime: Int64
    ): Unit {
        let path = actorRef.path.toString()
        
        match (directive) {
            case SupervisionDirective.Resume =>
                // 恢复Actor，不做特殊处理
                updateFailureCount(actorRef, currentTime)
                
            case SupervisionDirective.Restart =>
                // 重启Actor
                totalRestarts.fetchAdd(1)
                updateFailureCount(actorRef, currentTime)
                incrementRestartCount(actorRef)
                
            case SupervisionDirective.Stop =>
                // 停止Actor
                updateSupervisionState(actorRef, SupervisionState.Critical)
                
            case SupervisionDirective.Escalate =>
                // 升级到父Actor
                totalEscalations.fetchAdd(1)
                updateSupervisionState(actorRef, SupervisionState.Escalated)
                incrementEscalationCount(actorRef)
        }
        
        // 检查是否需要开启断路器
        checkCircuitBreaker(actorRef, currentTime)
    }
    
    private func updateFailureCount(actorRef: ActorRef, currentTime: Int64): Unit {
        let path = actorRef.path.toString()
        match (supervisionInfos.get(path)) {
            case Some(oldInfo) =>
                let newInfo = ActorSupervisionInfo(
                    oldInfo.actorRef,
                    oldInfo.strategy,
                    oldInfo.state,
                    oldInfo.failureCount + 1,
                    currentTime,
                    oldInfo.restartCount,
                    oldInfo.escalationCount,
                    oldInfo.circuitBreakerOpenTime
                )
                supervisionInfos.put(path, newInfo)
            case None =>
                // Actor不存在，忽略
        }
    }
    
    private func incrementRestartCount(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        match (supervisionInfos.get(path)) {
            case Some(oldInfo) =>
                let newInfo = ActorSupervisionInfo(
                    oldInfo.actorRef,
                    oldInfo.strategy,
                    oldInfo.state,
                    oldInfo.failureCount,
                    oldInfo.lastFailureTime,
                    oldInfo.restartCount + 1,
                    oldInfo.escalationCount,
                    oldInfo.circuitBreakerOpenTime
                )
                supervisionInfos.put(path, newInfo)
            case None =>
                // Actor不存在，忽略
        }
    }
    
    private func incrementEscalationCount(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        match (supervisionInfos.get(path)) {
            case Some(oldInfo) =>
                let newInfo = ActorSupervisionInfo(
                    oldInfo.actorRef,
                    oldInfo.strategy,
                    oldInfo.state,
                    oldInfo.failureCount,
                    oldInfo.lastFailureTime,
                    oldInfo.restartCount,
                    oldInfo.escalationCount + 1,
                    oldInfo.circuitBreakerOpenTime
                )
                supervisionInfos.put(path, newInfo)
            case None =>
                // Actor不存在，忽略
        }
    }
    
    private func updateSupervisionState(actorRef: ActorRef, newState: SupervisionState): Unit {
        let path = actorRef.path.toString()
        match (supervisionInfos.get(path)) {
            case Some(oldInfo) =>
                let newInfo = ActorSupervisionInfo(
                    oldInfo.actorRef,
                    oldInfo.strategy,
                    newState,
                    oldInfo.failureCount,
                    oldInfo.lastFailureTime,
                    oldInfo.restartCount,
                    oldInfo.escalationCount,
                    oldInfo.circuitBreakerOpenTime
                )
                supervisionInfos.put(path, newInfo)
            case None =>
                // Actor不存在，忽略
        }
    }
    
    private func checkCircuitBreaker(actorRef: ActorRef, currentTime: Int64): Unit {
        if (!config.enableCircuitBreaker) {
            return
        }
        
        let path = actorRef.path.toString()
        match (supervisionInfos.get(path)) {
            case Some(info) =>
                if (info.failureCount >= config.escalationThreshold) {
                    // 开启断路器
                    circuitBreakerTrips.fetchAdd(1)
                    let newInfo = ActorSupervisionInfo(
                        info.actorRef,
                        info.strategy,
                        SupervisionState.CircuitOpen,
                        info.failureCount,
                        info.lastFailureTime,
                        info.restartCount,
                        info.escalationCount,
                        currentTime
                    )
                    supervisionInfos.put(path, newInfo)
                }
            case None =>
                // Actor不存在，忽略
        }
    }
    
    private func shouldCloseCircuitBreaker(info: ActorSupervisionInfo, currentTime: Int64): Bool {
        let timeoutNanos = config.circuitBreakerTimeout.toNanoseconds()
        (currentTime - info.circuitBreakerOpenTime) > timeoutNanos
    }
    
    private func calculateAverageRecoveryTime(): Float64 {
        // 简化实现，实际应该跟踪恢复时间
        let restarts = totalRestarts.load()
        if (restarts > 0) {
            Float64(restarts) * 100.0  // 假设平均恢复时间100ms
        } else {
            0.0
        }
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }
}
