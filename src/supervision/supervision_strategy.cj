/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 监督策略
 * 实现Actor监督和容错机制
 */
package cactor.supervision

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.actor.{ActorRef, ActorLifecycleState}

/**
 * 监督指令
 * 定义当Actor失败时应该采取的行动
 */
public enum SupervisionDirective {
    | Resume      // 恢复Actor，忽略失败
    | Restart     // 重启Actor
    | Stop        // 停止Actor
    | Escalate    // 将失败上报给上级监督者
}

/**
 * Actor失败信息
 */
public struct ActorFailure {
    public let actor: ActorRef
    public let cause: Exception
    public let timestamp: Int64
    public let failureCount: Int64

    public init(actor: ActorRef, cause: Exception, failureCount: Int64) {
        this.actor = actor
        this.cause = cause
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.failureCount = failureCount
    }
}

/**
 * 重试信息
 */
public class RetryInfo {
    private let retryCount: AtomicInt64
    private let firstFailureTime: AtomicInt64
    private let lastFailureTime: AtomicInt64

    public init() {
        this.retryCount = AtomicInt64(0)
        this.firstFailureTime = AtomicInt64(0)
        this.lastFailureTime = AtomicInt64(0)
    }

    public func recordRetry(): Unit {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        retryCount.fetchAdd(1)
        lastFailureTime.store(now)
        
        if (firstFailureTime.load() == 0) {
            firstFailureTime.store(now)
        }
    }

    public func shouldRetry(maxRetries: Int32, withinTimeRange: Duration): Bool {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let firstFailure = firstFailureTime.load()

        // 如果是第一次失败，允许重试
        if (firstFailure == 0) {
            return true
        }

        let timeElapsed = now - firstFailure

        // 如果超出时间窗口，重置计数器并允许重试
        if (timeElapsed > withinTimeRange.toMilliseconds()) {
            reset()
            return true
        }

        // 在时间窗口内，检查重试次数
        let currentRetries = retryCount.load()
        return currentRetries < Int64(maxRetries)
    }

    public func reset(): Unit {
        retryCount.store(0)
        firstFailureTime.store(0)
        lastFailureTime.store(0)
    }

    public func getRetryCount(): Int64 {
        retryCount.load()
    }
}

/**
 * 监督策略接口
 */
public interface SupervisionStrategy {
    /**
     * 决定如何处理Actor失败
     */
    func decide(failure: ActorFailure): SupervisionDirective
}

/**
 * 一对一监督策略
 * 每个子Actor的失败只影响自己
 */
public class OneForOneStrategy <: SupervisionStrategy {
    private let maxRetries: Int32
    private let withinTimeRange: Duration
    private let retryHistory: ConcurrentHashMap<String, RetryInfo>
    private let decider: (Exception) -> SupervisionDirective

    public init(maxRetries: Int32, withinTimeRange: Duration, 
                decider: (Exception) -> SupervisionDirective) {
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
        this.retryHistory = ConcurrentHashMap<String, RetryInfo>()
        this.decider = decider
    }

    public func decide(failure: ActorFailure): SupervisionDirective {
        // 首先使用决策函数判断
        let directive = decider(failure.cause)
        
        match (directive) {
            case SupervisionDirective.Restart =>
                // 检查重试限制
                let retryInfo = getOrCreateRetryInfo(failure.actor)

                if (retryInfo.shouldRetry(maxRetries, withinTimeRange)) {
                    retryInfo.recordRetry()
                    SupervisionDirective.Restart
                } else {
                    // 超出重试限制，停止Actor
                    SupervisionDirective.Stop
                }
            case _ => directive
        }
    }

    private func getOrCreateRetryInfo(actor: ActorRef): RetryInfo {
        let actorKey = actor.path.toString()
        match (retryHistory.get(actorKey)) {
            case Some(info) => info
            case None =>
                let newInfo = RetryInfo()
                retryHistory.put(actorKey, newInfo)
                newInfo
        }
    }

    public func resetRetryInfo(actor: ActorRef): Unit {
        let actorKey = actor.path.toString()
        match (retryHistory.get(actorKey)) {
            case Some(info) => info.reset()
            case None => ()
        }
    }
}

/**
 * 一对全监督策略
 * 一个子Actor的失败会影响所有兄弟Actor
 */
public class OneForAllStrategy <: SupervisionStrategy {
    private let maxRetries: Int32
    private let withinTimeRange: Duration
    private let globalRetryInfo: RetryInfo
    private let decider: (Exception) -> SupervisionDirective

    public init(maxRetries: Int32, withinTimeRange: Duration,
                decider: (Exception) -> SupervisionDirective) {
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
        this.globalRetryInfo = RetryInfo()
        this.decider = decider
    }

    public func decide(failure: ActorFailure): SupervisionDirective {
        let directive = decider(failure.cause)
        
        match (directive) {
            case SupervisionDirective.Restart =>
                if (globalRetryInfo.shouldRetry(maxRetries, withinTimeRange)) {
                    globalRetryInfo.recordRetry()
                    SupervisionDirective.Restart
                } else {
                    SupervisionDirective.Stop
                }
            case _ => directive
        }
    }

    public func resetRetryInfo(): Unit {
        globalRetryInfo.reset()
    }
}

/**
 * 默认监督策略
 * 提供常用的异常处理决策
 */
public struct DefaultSupervisionStrategy {
    /**
     * 默认的异常决策函数
     */
    public static func defaultDecider(exception: Exception): SupervisionDirective {
        // 简化实现：根据异常类型决定策略
        // 实际实现中可以根据具体的异常类型进行更细粒度的控制
        SupervisionDirective.Restart
    }

    /**
     * 创建默认的一对一策略
     */
    public static func oneForOne(): OneForOneStrategy {
        OneForOneStrategy(
            3,
            Duration.minute,
            defaultDecider
        )
    }

    /**
     * 创建默认的一对全策略
     */
    public static func oneForAll(): OneForAllStrategy {
        OneForAllStrategy(
            3,
            Duration.minute,
            defaultDecider
        )
    }

    /**
     * 创建停止策略（遇到任何异常都停止）
     */
    public static func stoppingStrategy(): OneForOneStrategy {
        OneForOneStrategy(
            0,
            Duration.second,
            { exception => SupervisionDirective.Stop }
        )
    }

    /**
     * 创建恢复策略（遇到任何异常都恢复）
     */
    public static func resumingStrategy(): OneForOneStrategy {
        OneForOneStrategy(
            2147483647,
            Duration.hour,
            { exception => SupervisionDirective.Resume }
        )
    }
}

/**
 * 监督者接口
 */
public interface Supervisor {
    /**
     * 处理子Actor的失败
     */
    func handleFailure(failure: ActorFailure): Unit

    /**
     * 获取监督策略
     */
    func getSupervisionStrategy(): SupervisionStrategy

    /**
     * 添加子Actor
     */
    func addChild(child: ActorRef): Unit

    /**
     * 移除子Actor
     */
    func removeChild(child: ActorRef): Unit

    /**
     * 获取所有子Actor
     */
    func getChildren(): Array<ActorRef>
}

/**
 * 基础监督者实现
 */
public class BasicSupervisor <: Supervisor {
    private let strategy: SupervisionStrategy
    private let children: ConcurrentHashMap<String, ActorRef>
    private let failureCount: AtomicInt64

    public init(strategy: SupervisionStrategy) {
        this.strategy = strategy
        this.children = ConcurrentHashMap<String, ActorRef>()
        this.failureCount = AtomicInt64(0)
    }

    public func handleFailure(failure: ActorFailure): Unit {
        failureCount.fetchAdd(1)
        
        let directive = strategy.decide(failure)
        
        match (directive) {
            case SupervisionDirective.Resume =>
                // 恢复Actor - 简化实现
                println("恢复Actor: ${failure.actor.path.toString()}")
            case SupervisionDirective.Restart =>
                // 重启Actor - 简化实现
                println("重启Actor: ${failure.actor.path.toString()}")
            case SupervisionDirective.Stop =>
                // 停止Actor
                println("停止Actor: ${failure.actor.path.toString()}")
                removeChild(failure.actor)
            case SupervisionDirective.Escalate =>
                // 上报失败 - 简化实现
                println("上报失败: ${failure.actor.path.toString()}")
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
        childList.toArray()
    }

    public func getFailureCount(): Int64 {
        failureCount.load()
    }
}
