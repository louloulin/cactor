/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 断路器模式
 * 提供故障隔离和快速失败机制
 */
package cactor.circuit_breaker

import std.sync.*
import std.time.*
import std.collection.*

/**
 * 断路器状态
 */
public enum CircuitBreakerState {
    | Closed      // 关闭状态，正常工作
    | Open        // 开启状态，快速失败
    | HalfOpen    // 半开状态，尝试恢复
}

/**
 * 断路器配置
 */
public struct CircuitBreakerConfig {
    public let failureThreshold: Int32        // 失败阈值
    public let successThreshold: Int32        // 成功阈值（半开状态）
    public let timeout: Duration              // 超时时间
    public let resetTimeout: Duration         // 重置超时时间

    public init(failureThreshold: Int32, successThreshold: Int32, 
                timeout: Duration, resetTimeout: Duration) {
        this.failureThreshold = failureThreshold
        this.successThreshold = successThreshold
        this.timeout = timeout
        this.resetTimeout = resetTimeout
    }
}

/**
 * 断路器统计信息
 */
public struct CircuitBreakerStats {
    public let state: CircuitBreakerState
    public let failureCount: Int64
    public let successCount: Int64
    public let totalRequests: Int64
    public let lastFailureTime: Int64
    public let lastSuccessTime: Int64

    public init(state: CircuitBreakerState, failureCount: Int64, successCount: Int64,
                totalRequests: Int64, lastFailureTime: Int64, lastSuccessTime: Int64) {
        this.state = state
        this.failureCount = failureCount
        this.successCount = successCount
        this.totalRequests = totalRequests
        this.lastFailureTime = lastFailureTime
        this.lastSuccessTime = lastSuccessTime
    }

    public func getFailureRate(): Float64 {
        if (totalRequests == 0) {
            return 0.0
        }
        Float64(failureCount) / Float64(totalRequests)
    }

    public func getSuccessRate(): Float64 {
        if (totalRequests == 0) {
            return 0.0
        }
        Float64(successCount) / Float64(totalRequests)
    }
}

/**
 * 断路器异常
 */
public class CircuitBreakerOpenException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 断路器接口
 */
public interface CircuitBreaker<T> {
    /**
     * 执行操作
     */
    func execute(operation: () -> T): T

    /**
     * 获取当前状态
     */
    func getState(): CircuitBreakerState

    /**
     * 获取统计信息
     */
    func getStats(): CircuitBreakerStats

    /**
     * 手动重置断路器
     */
    func reset(): Unit

    /**
     * 手动触发断路器
     */
    func trip(): Unit
}

/**
 * 基础断路器实现
 */
public class BasicCircuitBreaker<T> <: CircuitBreaker<T> {
    private let config: CircuitBreakerConfig
    private var state: CircuitBreakerState
    private let failureCount: AtomicInt64
    private let successCount: AtomicInt64
    private let totalRequests: AtomicInt64
    private let lastFailureTime: AtomicInt64
    private let lastSuccessTime: AtomicInt64
    private let lastStateChangeTime: AtomicInt64
    private let mutex: ReentrantMutex

    public init(config: CircuitBreakerConfig) {
        this.config = config
        this.state = CircuitBreakerState.Closed
        this.failureCount = AtomicInt64(0)
        this.successCount = AtomicInt64(0)
        this.totalRequests = AtomicInt64(0)
        this.lastFailureTime = AtomicInt64(0)
        this.lastSuccessTime = AtomicInt64(0)
        this.lastStateChangeTime = AtomicInt64(DateTime.now().toUnixTimeStamp().toMilliseconds())
        this.mutex = ReentrantMutex()
    }

    public func execute(operation: () -> T): T {
        totalRequests.fetchAdd(1)
        
        mutex.lock()
        let currentState = state
        mutex.unlock()

        match (currentState) {
            case CircuitBreakerState.Open => 
                if (shouldAttemptReset()) {
                    transitionToHalfOpen()
                    return attemptOperation(operation)
                } else {
                    throw CircuitBreakerOpenException("断路器处于开启状态")
                }
            case CircuitBreakerState.HalfOpen => 
                return attemptOperation(operation)
            case CircuitBreakerState.Closed => 
                return attemptOperation(operation)
        }
    }

    private func attemptOperation(operation: () -> T): T {
        try {
            let result = operation()
            onSuccess()
            result
        } catch (e: Exception) {
            onFailure()
            throw e
        }
    }

    private func onSuccess(): Unit {
        successCount.fetchAdd(1)
        lastSuccessTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
        
        mutex.lock()
        try {
            match (state) {
                case CircuitBreakerState.HalfOpen => 
                    if (successCount.load() >= Int64(config.successThreshold)) {
                        transitionToClosed()
                    }
                case _ => ()
            }
        } finally {
            mutex.unlock()
        }
    }

    private func onFailure(): Unit {
        failureCount.fetchAdd(1)
        lastFailureTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
        
        mutex.lock()
        try {
            match (state) {
                case CircuitBreakerState.Closed => 
                    if (failureCount.load() >= Int64(config.failureThreshold)) {
                        transitionToOpen()
                    }
                case CircuitBreakerState.HalfOpen => 
                    transitionToOpen()
                case _ => ()
            }
        } finally {
            mutex.unlock()
        }
    }

    private func shouldAttemptReset(): Bool {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let lastChange = lastStateChangeTime.load()
        (now - lastChange) >= config.resetTimeout.toMilliseconds()
    }

    private func transitionToOpen(): Unit {
        state = CircuitBreakerState.Open
        lastStateChangeTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
        println("断路器转换到开启状态")
    }

    private func transitionToHalfOpen(): Unit {
        mutex.lock()
        try {
            state = CircuitBreakerState.HalfOpen
            lastStateChangeTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
            // 重置成功计数器
            successCount.store(0)
            println("断路器转换到半开状态")
        } finally {
            mutex.unlock()
        }
    }

    private func transitionToClosed(): Unit {
        state = CircuitBreakerState.Closed
        lastStateChangeTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
        // 重置计数器
        failureCount.store(0)
        successCount.store(0)
        println("断路器转换到关闭状态")
    }

    public func getState(): CircuitBreakerState {
        mutex.lock()
        try {
            state
        } finally {
            mutex.unlock()
        }
    }

    public func getStats(): CircuitBreakerStats {
        mutex.lock()
        try {
            CircuitBreakerStats(
                state,
                failureCount.load(),
                successCount.load(),
                totalRequests.load(),
                lastFailureTime.load(),
                lastSuccessTime.load()
            )
        } finally {
            mutex.unlock()
        }
    }

    public func reset(): Unit {
        mutex.lock()
        try {
            state = CircuitBreakerState.Closed
            failureCount.store(0)
            successCount.store(0)
            lastStateChangeTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
            println("断路器手动重置")
        } finally {
            mutex.unlock()
        }
    }

    public func trip(): Unit {
        mutex.lock()
        try {
            transitionToOpen()
            println("断路器手动触发")
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 断路器工厂
 */
public struct CircuitBreakerFactory {
    /**
     * 创建默认配置的断路器
     */
    public static func createDefault<T>(): BasicCircuitBreaker<T> {
        let config = CircuitBreakerConfig(
            5,                          // 失败阈值
            3,                          // 成功阈值
            Duration.second * 5,        // 超时时间
            Duration.second * 30        // 重置超时时间
        )
        BasicCircuitBreaker<T>(config)
    }

    /**
     * 创建快速失败的断路器
     */
    public static func createFastFail<T>(): BasicCircuitBreaker<T> {
        let config = CircuitBreakerConfig(
            3,                          // 失败阈值
            2,                          // 成功阈值
            Duration.second * 2,        // 超时时间
            Duration.second * 10        // 重置超时时间
        )
        BasicCircuitBreaker<T>(config)
    }

    /**
     * 创建容错的断路器
     */
    public static func createTolerant<T>(): BasicCircuitBreaker<T> {
        let config = CircuitBreakerConfig(
            10,                         // 失败阈值
            5,                          // 成功阈值
            Duration.second * 10,       // 超时时间
            Duration.minute             // 重置超时时间
        )
        BasicCircuitBreaker<T>(config)
    }
}

/**
 * 断路器装饰器
 * 为现有函数添加断路器功能
 */
public class CircuitBreakerDecorator<T> {
    private let circuitBreaker: CircuitBreaker<T>
    private let fallback: Option<() -> T>

    public init(circuitBreaker: CircuitBreaker<T>, fallback: Option<() -> T>) {
        this.circuitBreaker = circuitBreaker
        this.fallback = fallback
    }

    public func call(operation: () -> T): T {
        try {
            circuitBreaker.execute(operation)
        } catch (e: CircuitBreakerOpenException) {
            match (fallback) {
                case Some(fb) => fb()
                case None => throw e
            }
        }
    }

    public func getCircuitBreaker(): CircuitBreaker<T> {
        circuitBreaker
    }
}
