/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级监督策略系统
 * 基于plan3.md Phase 5设计，增强现有的监督策略功能
 */
package cactor.core.supervision.advanced

import std.time.*
import std.collection.*
import std.sync.*
import cactor.core.supervision.{
    SupervisionStrategy, 
    SupervisionDirective, 
    ActorFailure, 
    OneForOneStrategy, 
    OneForAllStrategy,
    DefaultSupervisionStrategy,
    Supervisor,
    BasicSupervisor
}
import cactor.core.actor.ActorRef

/**
 * 高级监督策略工厂
 * 提供更多预定义的监督策略和自定义选项
 */
public class AdvancedSupervisionStrategyFactory {
    
    /**
     * 创建快速失败策略
     * 任何异常都立即停止Actor
     */
    public static func createFailFastStrategy(): OneForOneStrategy {
        OneForOneStrategy(
            0,  // 不重试
            Duration.second,
            { exception => SupervisionDirective.Stop }
        )
    }
    
    /**
     * 创建永不放弃策略
     * 无限重试，永远不停止
     */
    public static func createNeverGiveUpStrategy(): OneForOneStrategy {
        OneForOneStrategy(
            2147483647,  // 最大重试次数
            Duration.hour * 24,  // 24小时时间窗口
            { exception => SupervisionDirective.Restart }
        )
    }
    
    /**
     * 创建渐进式退避策略
     * 重试间隔逐渐增加
     */
    public static func createBackoffStrategy(
        initialDelay: Duration,
        maxDelay: Duration,
        maxRetries: Int32
    ): BackoffSupervisionStrategy {
        BackoffSupervisionStrategy(initialDelay, maxDelay, maxRetries)
    }
    
    /**
     * 创建基于异常类型的策略
     * 根据不同异常类型采取不同策略
     */
    public static func createExceptionBasedStrategy(): OneForOneStrategy {
        OneForOneStrategy(
            5,
            Duration.minute * 5,
            createExceptionDecider()
        )
    }
    
    /**
     * 创建异常决策函数
     */
    private static func createExceptionDecider(): (Exception) -> SupervisionDirective {
        { exception =>
            // 根据异常类型决定策略
            let exceptionName = exception.toString()
            
            if (exceptionName.contains("IllegalArgument")) {
                SupervisionDirective.Resume  // 参数错误，恢复继续
            } else if (exceptionName.contains("NullPointer")) {
                SupervisionDirective.Restart  // 空指针，重启
            } else if (exceptionName.contains("OutOfMemory")) {
                SupervisionDirective.Stop  // 内存不足，停止
            } else if (exceptionName.contains("Timeout")) {
                SupervisionDirective.Restart  // 超时，重启
            } else {
                SupervisionDirective.Escalate  // 其他异常，上报
            }
        }
    }
    
    /**
     * 创建电路熔断策略
     * 当失败率过高时暂时停止服务
     */
    public static func createCircuitBreakerStrategy(
        failureThreshold: Int32,
        timeWindow: Duration
    ): CircuitBreakerSupervisionStrategy {
        CircuitBreakerSupervisionStrategy(failureThreshold, timeWindow)
    }
}

/**
 * 退避监督策略
 * 实现渐进式重试延迟
 */
public class BackoffSupervisionStrategy <: SupervisionStrategy {
    private let initialDelay: Duration
    private let maxDelay: Duration
    private let maxRetries: Int32
    private let retryDelays: HashMap<String, Duration>
    private let retryCounts: HashMap<String, Int32>
    
    public init(initialDelay: Duration, maxDelay: Duration, maxRetries: Int32) {
        this.initialDelay = initialDelay
        this.maxDelay = maxDelay
        this.maxRetries = maxRetries
        this.retryDelays = HashMap<String, Duration>()
        this.retryCounts = HashMap<String, Int32>()
    }
    
    public func decide(failure: ActorFailure): SupervisionDirective {
        let actorKey = failure.actor.path.toString()
        
        // 获取当前重试次数
        let currentRetries = match (retryCounts.get(actorKey)) {
            case Some(count) => count
            case None => 0
        }
        
        if (currentRetries >= maxRetries) {
            // 超过最大重试次数，停止
            retryCounts.remove(actorKey)
            retryDelays.remove(actorKey)
            return SupervisionDirective.Stop
        }
        
        // 计算下次重试延迟
        let currentDelay = match (retryDelays.get(actorKey)) {
            case Some(delay) => delay
            case None => initialDelay
        }
        
        // 指数退避：每次延迟翻倍
        let nextDelay = Duration.nanosecond * min(
            currentDelay.toNanoseconds() * 2,
            maxDelay.toNanoseconds()
        )
        
        // 更新状态
        retryCounts.put(actorKey, currentRetries + 1)
        retryDelays.put(actorKey, nextDelay)
        
        println("[BACKOFF] Actor ${actorKey} 将在 ${currentDelay.toMilliseconds()}ms 后重试")
        
        SupervisionDirective.Restart
    }
    
    /**
     * 重置Actor的退避状态
     */
    public func resetBackoff(actor: ActorRef): Unit {
        let actorKey = actor.path.toString()
        retryCounts.remove(actorKey)
        retryDelays.remove(actorKey)
    }
}

/**
 * 电路熔断监督策略
 * 当失败率过高时暂时停止服务
 */
public class CircuitBreakerSupervisionStrategy <: SupervisionStrategy {
    private let failureThreshold: Int32
    private let timeWindow: Duration
    private let failureCounts: HashMap<String, Int32>
    private let lastFailureTime: HashMap<String, Int64>
    private let circuitState: HashMap<String, CircuitState>
    
    public init(failureThreshold: Int32, timeWindow: Duration) {
        this.failureThreshold = failureThreshold
        this.timeWindow = timeWindow
        this.failureCounts = HashMap<String, Int32>()
        this.lastFailureTime = HashMap<String, Int64>()
        this.circuitState = HashMap<String, CircuitState>()
    }
    
    public func decide(failure: ActorFailure): SupervisionDirective {
        let actorKey = failure.actor.path.toString()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        // 获取当前电路状态
        let currentState = match (circuitState.get(actorKey)) {
            case Some(state) => state
            case None => CircuitState.Closed
        }
        
        match (currentState) {
            case CircuitState.Closed =>
                handleClosedState(actorKey, now)
            case CircuitState.Open =>
                handleOpenState(actorKey, now)
            case CircuitState.HalfOpen =>
                handleHalfOpenState(actorKey, now)
        }
    }
    
    private func handleClosedState(actorKey: String, now: Int64): SupervisionDirective {
        // 记录失败
        let currentFailures = match (failureCounts.get(actorKey)) {
            case Some(count) => count + 1
            case None => 1
        }
        
        failureCounts.put(actorKey, currentFailures)
        lastFailureTime.put(actorKey, now)
        
        if (currentFailures >= failureThreshold) {
            // 达到失败阈值，打开电路
            circuitState.put(actorKey, CircuitState.Open)
            println("[CIRCUIT] 电路熔断器打开: ${actorKey}")
            return SupervisionDirective.Stop
        }
        
        SupervisionDirective.Restart
    }
    
    private func handleOpenState(actorKey: String, now: Int64): SupervisionDirective {
        let lastFailure = match (lastFailureTime.get(actorKey)) {
            case Some(time) => time
            case None => now
        }
        
        if (now - lastFailure > timeWindow.toMilliseconds()) {
            // 时间窗口过期，进入半开状态
            circuitState.put(actorKey, CircuitState.HalfOpen)
            println("[CIRCUIT] 电路熔断器进入半开状态: ${actorKey}")
            return SupervisionDirective.Restart
        }
        
        // 仍在熔断期间
        SupervisionDirective.Stop
    }
    
    private func handleHalfOpenState(actorKey: String, now: Int64): SupervisionDirective {
        // 半开状态下的失败，重新打开电路
        circuitState.put(actorKey, CircuitState.Open)
        lastFailureTime.put(actorKey, now)
        println("[CIRCUIT] 电路熔断器重新打开: ${actorKey}")
        SupervisionDirective.Stop
    }
    
    /**
     * 手动重置电路状态
     */
    public func resetCircuit(actor: ActorRef): Unit {
        let actorKey = actor.path.toString()
        circuitState.put(actorKey, CircuitState.Closed)
        failureCounts.remove(actorKey)
        lastFailureTime.remove(actorKey)
        println("[CIRCUIT] 电路熔断器已重置: ${actorKey}")
    }
}

/**
 * 电路状态枚举
 */
public enum CircuitState {
    | Closed      // 关闭状态，正常工作
    | Open        // 打开状态，熔断中
    | HalfOpen    // 半开状态，试探性恢复
}

/**
 * 高级监督者
 * 提供更丰富的监督功能
 */
public class AdvancedSupervisor <: Supervisor {
    private let strategy: SupervisionStrategy
    private let children: HashMap<String, ActorRef>
    private let failureHistory: ArrayList<ActorFailure>
    private let maxHistorySize: Int32
    private let supervisionMetrics: SupervisionMetrics
    
    public init(strategy: SupervisionStrategy, maxHistorySize: Int32 = 1000) {
        this.strategy = strategy
        this.children = HashMap<String, ActorRef>()
        this.failureHistory = ArrayList<ActorFailure>()
        this.maxHistorySize = maxHistorySize
        this.supervisionMetrics = SupervisionMetrics()
    }
    
    public func handleFailure(failure: ActorFailure): Unit {
        // 记录失败历史
        recordFailure(failure)
        
        // 更新指标
        supervisionMetrics.recordFailure(failure)
        
        // 执行监督决策
        let directive = strategy.decide(failure)
        executeDirective(directive, failure)
        
        // 更新指标
        supervisionMetrics.recordDirective(directive)
    }
    
    private func recordFailure(failure: ActorFailure): Unit {
        failureHistory.append(failure)
        
        // 限制历史记录大小
        while (failureHistory.size > maxHistorySize) {
            failureHistory.removeAt(0)
        }
    }
    
    private func executeDirective(directive: SupervisionDirective, failure: ActorFailure): Unit {
        match (directive) {
            case SupervisionDirective.Resume =>
                println("[SUPERVISION] 恢复Actor: ${failure.actor.path.toString()}")
            case SupervisionDirective.Restart =>
                println("[SUPERVISION] 重启Actor: ${failure.actor.path.toString()}")
            case SupervisionDirective.Stop =>
                println("[SUPERVISION] 停止Actor: ${failure.actor.path.toString()}")
                removeChild(failure.actor)
            case SupervisionDirective.Escalate =>
                println("[SUPERVISION] 上报失败: ${failure.actor.path.toString()}")
        }
    }
    
    public func getSupervisionStrategy(): SupervisionStrategy {
        strategy
    }
    
    public func addChild(child: ActorRef): Unit {
        children.put(child.path.toString(), child)
    }
    
    public func removeChild(child: ActorRef): Unit {
        children.remove(child.path.toString())
    }
    
    public func getChildren(): Array<ActorRef> {
        let childList = ArrayList<ActorRef>()
        for ((_, actor) in children) {
            childList.append(actor)
        }
        Array<ActorRef>(Int64(childList.size), { i => childList[i] })
    }
    
    /**
     * 获取失败历史
     */
    public func getFailureHistory(): Array<ActorFailure> {
        Array<ActorFailure>(Int64(failureHistory.size), { i => failureHistory[i] })
    }
    
    /**
     * 获取监督指标
     */
    public func getSupervisionMetrics(): SupervisionMetrics {
        supervisionMetrics
    }
}

/**
 * 监督指标
 * 收集和统计监督相关的指标
 */
public class SupervisionMetrics {
    private let totalFailures: AtomicInt64
    private let resumeCount: AtomicInt64
    private let restartCount: AtomicInt64
    private let stopCount: AtomicInt64
    private let escalateCount: AtomicInt64
    private let startTime: Int64
    
    public init() {
        this.totalFailures = AtomicInt64(0)
        this.resumeCount = AtomicInt64(0)
        this.restartCount = AtomicInt64(0)
        this.stopCount = AtomicInt64(0)
        this.escalateCount = AtomicInt64(0)
        this.startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
    
    public func recordFailure(failure: ActorFailure): Unit {
        totalFailures.fetchAdd(1)
    }
    
    public func recordDirective(directive: SupervisionDirective): Unit {
        match (directive) {
            case SupervisionDirective.Resume => resumeCount.fetchAdd(1)
            case SupervisionDirective.Restart => restartCount.fetchAdd(1)
            case SupervisionDirective.Stop => stopCount.fetchAdd(1)
            case SupervisionDirective.Escalate => escalateCount.fetchAdd(1)
        }
    }
    
    public func getTotalFailures(): Int64 {
        totalFailures.load()
    }
    
    public func getResumeCount(): Int64 {
        resumeCount.load()
    }
    
    public func getRestartCount(): Int64 {
        restartCount.load()
    }
    
    public func getStopCount(): Int64 {
        stopCount.load()
    }
    
    public func getEscalateCount(): Int64 {
        escalateCount.load()
    }
    
    public func getFailureRate(): Float64 {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let elapsedSeconds = Float64(now - startTime) / 1000.0
        
        if (elapsedSeconds > 0) {
            Float64(totalFailures.load()) / elapsedSeconds
        } else {
            0.0
        }
    }
    
    public func getMetricsSummary(): String {
        "SupervisionMetrics[" +
        "总失败: ${getTotalFailures()}, " +
        "恢复: ${getResumeCount()}, " +
        "重启: ${getRestartCount()}, " +
        "停止: ${getStopCount()}, " +
        "上报: ${getEscalateCount()}, " +
        "失败率: ${getFailureRate()}/s]"
    }
}
