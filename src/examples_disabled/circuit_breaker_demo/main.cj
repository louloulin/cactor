/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Circuit Breaker 示例程序
 * 演示断路器模式增强功能
 */
package cactor.examples.circuit_breaker_demo

import std.collection.*
import std.time.*
import cactor.patterns.circuit_breaker.*

// ============================================================================
// Circuit Breaker 示例演示
// ============================================================================

/**
 * 模拟服务调用
 */
public class MockService {
    private var callCount: Int64
    private var shouldFail: Bool
    private var latencyMs: Int64

    public init() {
        this.callCount = 0
        this.shouldFail = false
        this.latencyMs = 0
    }

    public func call(): String {
        callCount += 1
        if (shouldFail) {
            throw Exception("Service unavailable")
        }
        // 模拟延迟
        // Thread.sleep(Duration.millisecond(latencyMs))
        "Success from mock service"
    }

    public func setFailure(enabled: Bool): MockService {
        shouldFail = enabled
        this
    }

    public func setLatency(ms: Int64): MockService {
        latencyMs = ms
        this
    }

    public func reset(): MockService {
        callCount = 0
        shouldFail = false
        latencyMs = 0
        this
    }

    public func getCallCount(): Int64 {
        callCount
    }
}

/**
 * 演示基本断路器
 */
public func demonstrateBasicCircuitBreaker(): Unit {
    println("=== 基本断路器演示 ===")

    let service = MockService()
    let cb = CircuitBreaker(
        maxFailures: 3,
        callTimeout: Duration.second,
        resetTimeout: Duration.second * 5
    )

    println("初始状态: ${cb.state()}")

    // 成功调用
    println("调用 1: ${cb.call(service.call)}")
    println("状态: ${cb.state()}")

    // 设置服务失败
    service.setFailure(true)

    // 触发断路器打开
    for (i in 0..5) {
        let result = cb.call(service.call)
        match (result) {
            case CircuitBreakerResult.Success(msg) => println("调用成功: ${msg}")
            case CircuitBreakerResult.Failure(msg) => println("调用失败: ${msg}")
            case CircuitBreakerResult.Open => println("断路器打开")
            case CircuitBreakerResult.HalfOpen =>
                match (cb.call(service.call)) {
                    case CircuitBreakerResult.Success(msg) =>
                        println("半开状态调用成功: ${msg}")
                    case _ => ()
                }
        }
    }

    println("最终状态: ${cb.state()}")
    println("服务调用次数: ${service.getCallCount()}")
    println()
}

/**
 * 简单事件监听器实现
 */
public class SimpleCircuitBreakerListener <: CircuitBreakerEventListener {
    public let events: ArrayList<CircuitBreakerEvent>

    public init() {
        this.events = ArrayList<CircuitBreakerEvent>()
    }

    public func onStateTransition(event: CircuitBreakerEvent): Unit {
        events.add(event)
        let fromStr = match (event.fromState) {
            case CircuitBreakerState.Closed => "Closed"
            case CircuitBreakerState.Open => "Open"
            case CircuitBreakerState.HalfOpen => "HalfOpen"
        }
        let toStr = match (event.toState) {
            case CircuitBreakerState.Closed => "Closed"
            case CircuitBreakerState.Open => "Open"
            case CircuitBreakerState.HalfOpen => "HalfOpen"
        }
        println("  [断路器事件] ${fromStr} -> ${toStr}")
    }
}

/**
 * 演示带事件监听的断路器
 */
public func demonstrateEventPublishingCircuitBreaker(): Unit {
    println("=== 带事件监听的断路器演示 ===")

    let service = MockService()
    let listener = SimpleCircuitBreakerListener()

    let cb = EventPublishingCircuitBreaker<Int64>(
        CircuitBreakerConfig(2, 1, Duration.second, Duration.second * 3)
    ).withListener(listener)

    println("初始状态: Closed")
    println()

    // 第一次失败
    println("调用 1 (会失败):")
    service.setFailure(true)
    try {
        cb.execute({ => service.call() })
    } catch (_: Exception) {
        println("  调用失败")
    }

    // 第二次失败 - 应该打开断路器
    println("调用 2 (会失败):")
    try {
        cb.execute({ => service.call() })
    } catch (_: Exception) {
        println("  调用失败")
    }

    println()
    let stateStr = match (cb.getState()) {
        case CircuitBreakerState.Closed => "Closed"
        case CircuitBreakerState.Open => "Open"
        case CircuitBreakerState.HalfOpen => "HalfOpen"
    }
    println("断路器状态: ${stateStr}")
    println("收集到的事件数: ${listener.events.size}")
    println()
}

/**
 * 演示断路器状态转换
 */
public func demonstrateStateTransitions(): Unit {
    println("=== 断路器状态转换演示 ===")

    let service = MockService()
    let cb = CircuitBreaker(
        maxFailures: 2,
        callTimeout: Duration.second,
        resetTimeout: Duration.second * 2
    )

    println("初始状态: ${cb.state()}")
    println("  Closed -> 正常，允许调用")

    // 触发失败
    service.setFailure(true)
    println("服务设置为失败模式")

    // 失败 1
    match (cb.call(service.call)) {
        case CircuitBreakerResult.Failure(msg) =>
            println("失败 1: ${msg}")
        case _ => ()
    }
    println("  状态: ${cb.state()}")

    // 失败 2
    match (cb.call(service.call)) {
        case CircuitBreakerResult.Failure(msg) =>
            println("失败 2: ${msg}")
        case _ => ()
    }

    // 失败 3 - 断路器打开
    match (cb.call(service.call)) {
        case CircuitBreakerResult.Open =>
            println("失败 3: 断路器打开")
        case _ => ()
    }
    println("  状态: ${cb.state()}")
    println("  Closed -> Open -> 快速失败，拒绝调用")

    // 等待恢复超时
    println("等待恢复超时 (2秒)...")
    // Thread.sleep(Duration.second * 3)

    println("  状态: ${cb.state()}")
    println("  Open -> HalfOpen -> 允许一个测试调用")

    // 恢复服务
    service.setFailure(false)

    // 半开状态调用
    match (cb.call(service.call)) {
        case CircuitBreakerResult.Success(msg) =>
            println("成功: ${msg}")
            println("  HalfOpen -> Closed -> 恢复正常")
        case CircuitBreakerResult.Failure(msg) =>
            println("失败: ${msg}")
            println("  HalfOpen -> Open -> 重新开始倒计时")
        case _ => ()
    }

    println()
}

/**
 * 演示断路器统计数据
 */
public func demonstrateCircuitBreakerStats(): Unit {
    println("=== 断路器统计数据演示 ===")

    let service = MockService()
    let cb = CircuitBreaker(
        maxFailures: 3,
        callTimeout: Duration.second,
        resetTimeout: Duration.second * 2
    )

    // 模拟一系列调用
    println("模拟一系列调用:")

    // 成功调用
    for (i in 0..3) {
        service.setFailure(false)
        match (cb.call(service.call)) {
            case CircuitBreakerResult.Success(msg) =>
                println("  调用 ${i + 1}: 成功")
            case _ => ()
        }
    }

    // 失败调用
    service.setFailure(true)
    for (i in 0..4) {
        let _ = cb.call(service.call)
        println("  调用 ${i + 4}: 失败")
    }

    println()
    println("断路器最终状态: ${cb.state()}")
    println("统计信息:")
    println("  总调用数: ${cb.successCount() + cb.failureCount()}")
    println("  成功数: ${cb.successCount()}")
    println("  失败数: ${cb.failureCount()}")
    println("  短路数: ${cb.shortCircuits()}")
    println()
}

/**
 * 演示 CircuitBreakerUtil
 */
public func demonstrateCircuitBreakerUtil(): Unit {
    println("=== CircuitBreakerUtil 演示 ===")

    let service = MockService()
    service.setFailure(true)

    let cb = CircuitBreaker(
        maxFailures: 2,
        callTimeout: Duration.second,
        resetTimeout: Duration.second
    )

    println("使用 CircuitBreakerUtil.callProtected:")

    let result = CircuitBreakerUtil.callProtected(cb, { => service.call() })
    match (result) {
        case CircuitBreakerResult.Success(msg) =>
            println("  结果: 成功 - ${msg}")
        case CircuitBreakerResult.Failure(msg) =>
            println("  结果: 失败 - ${msg}")
        case CircuitBreakerResult.Open =>
            println("  结果: 断路器打开")
        case CircuitBreakerResult.HalfOpen =>
            println("  结果: 半开状态")
    }

    println()
}

/**
 * 演示工厂方法
 */
public func demonstrateFactory(): Unit {
    println("=== CircuitBreakerFactory 演示 ===")

    // 创建配置
    let config = CircuitBreakerConfig(
        maxFailures: 5,
        callTimeout: Duration.second * 2,
        resetTimeout: Duration.second * 10,
        maxResetTimeout: Duration.second * 60
    )

    // 使用工厂创建
    let cb1 = CircuitBreakerFactory.create(config)
    println("工厂创建 (配置): ${cb1.state()}")

    // 创建带事件监听
    let events = ArrayList<CircuitBreakerEvent>()
    let cb2 = CircuitBreakerFactory.createWithEvents(
        3,
        Duration.second,
        Duration.second * 5,
        { e: CircuitBreakerEvent =>
            events.add(e)
            println("  [事件] ${e}")
        }
    )
    println("工厂创建 (带事件监听): ${cb2.state()}")

    // 快速失败配置
    let cb3 = CircuitBreakerFactory.createQuickFail()
    println("快速失败配置: ${cb3.state()}")

    // 容错配置
    let cb4 = CircuitBreakerFactory.createTolerant()
    println("容错配置: ${cb4.state()}")

    println()
}

/**
 * 运行所有演示
 */
main(): Unit {
    println("========================================")
    println("   CActor Circuit Breaker 断路器演示")
    println("========================================")
    println()

    demonstrateStateTransitions()
    demonstrateBasicCircuitBreaker()
    demonstrateEventPublishingCircuitBreaker()
    demonstrateCircuitBreakerStats()
    demonstrateCircuitBreakerUtil()
    demonstrateFactory()

    println("========================================")
    println("   Circuit Breaker 演示完成!")
    println("========================================")
}