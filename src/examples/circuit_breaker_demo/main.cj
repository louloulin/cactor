/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Circuit Breaker 示例程序
 * 演示断路器模式功能
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

    public init() {
        this.callCount = 0
        this.shouldFail = false
    }

    public func call(): String {
        callCount += 1
        if (shouldFail) {
            throw Exception("Service unavailable")
        }
        "Success from mock service"
    }

    public func setFailure(enabled: Bool): MockService {
        shouldFail = enabled
        this
    }

    public func reset(): MockService {
        callCount = 0
        shouldFail = false
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
    let config = CircuitBreakerConfig(
        3,                          // failureThreshold
        2,                          // successThreshold
        Duration.second,            // timeout
        Duration.second * 5         // resetTimeout
    )
    let cb = BasicCircuitBreaker<String>(config)

    println("初始状态: ${cb.getState().toString()}")

    // 成功调用
    let result = cb.execute({ => service.call() })
    println("调用 1: ${result}")
    println("状态: ${cb.getState().toString()}")

    // 设置服务失败
    service.setFailure(true)

    // 触发断路器打开
    for (i in 0..5) {
        try {
            let r = cb.execute({ => service.call() })
            println("调用 ${i + 2}: ${r}")
        } catch (e: CircuitBreakerOpenException) {
            println("断路器打开，拒绝调用")
        } catch (e: Exception) {
            println("调用失败")
        }
    }

    println("最终状态: ${cb.getState().toString()}")
    let stats = cb.getStats()
    println("统计: 成功=${stats.successCount}, 失败=${stats.failureCount}")
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

    let cb = EventPublishingCircuitBreaker<String>(CircuitBreakerConfig(
        2,                          // failureThreshold
        1,                          // successThreshold
        Duration.second,            // timeout
        Duration.second * 3          // resetTimeout
    ))

    cb.subscribe(listener)

    println("初始状态: Closed")
    println()

    // 第一次失败
    println("调用 1 (会失败):")
    service.setFailure(true)
    try {
        cb.execute({ => service.call() })
    } catch (e: Exception) {
        println("  调用失败")
    }

    // 第二次失败 - 应该打开断路器
    println("调用 2 (会失败):")
    try {
        cb.execute({ => service.call() })
    } catch (e: Exception) {
        println("  调用失败")
    }

    println()
    let stateStr = match (cb.getState()) {
        case CircuitBreakerState.Closed => "Closed"
        case CircuitBreakerState.Open => "Open"
        case CircuitBreakerState.HalfOpen => "HalfOpen"
    }
    println("断路器状态: ${stateStr.toString()}")
    println("收集到的事件数: ${listener.events.size}")
    println()
}

/**
 * 演示断路器状态转换
 */
public func demonstrateStateTransitions(): Unit {
    println("=== 断路器状态转换演示 ===")

    let service = MockService()
    let cb = BasicCircuitBreaker<String>(CircuitBreakerConfig(
        2,                          // failureThreshold
        1,                          // successThreshold
        Duration.second,            // timeout
        Duration.second * 2          // resetTimeout
    ))

    println("初始状态: ${cb.getState().toString()}")
    println("  Closed -> 正常，允许调用")

    // 触发失败
    service.setFailure(true)
    println("服务设置为失败模式")

    // 失败 1
    try {
        cb.execute({ => service.call() })
    } catch (e: Exception) {
        println("失败 1: 调用失败")
    }
    println("  状态: ${cb.getState().toString()}")

    // 失败 2
    try {
        cb.execute({ => service.call() })
    } catch (e: CircuitBreakerOpenException) {
        println("失败 2: 断路器打开")
    } catch (e: Exception) {
        println("失败 2: 调用失败")
    }
    println("  状态: ${cb.getState().toString()}")
    println("  Closed -> Open -> 快速失败，拒绝调用")

    println()
}

/**
 * 演示断路器统计数据
 */
public func demonstrateCircuitBreakerStats(): Unit {
    println("=== 断路器统计数据演示 ===")

    let service = MockService()
    let cb = BasicCircuitBreaker<String>(CircuitBreakerConfig(
        3,                          // failureThreshold
        1,                          // successThreshold
        Duration.second,            // timeout
        Duration.second * 2          // resetTimeout
    ))

    // 模拟一系列调用
    println("模拟一系列调用:")

    // 成功调用
    for (i in 0..3) {
        service.setFailure(false)
        try {
            cb.execute({ => service.call() })
            println("  调用 ${i + 1}: 成功")
        } catch (e: Exception) {
            println("  调用 ${i + 1}: 失败")
        }
    }

    // 失败调用
    service.setFailure(true)
    for (i in 0..4) {
        try {
            cb.execute({ => service.call() })
            println("  调用 ${i + 4}: 成功")
        } catch (e: Exception) {
            println("  调用 ${i + 4}: 失败")
        }
    }

    println()
    println("断路器最终状态: ${cb.getState().toString()}")
    let stats = cb.getStats()
    println("统计信息:")
    println("  总调用数: ${stats.totalRequests}")
    println("  成功数: ${stats.successCount}")
    println("  失败数: ${stats.failureCount}")
    println()
}

/**
 * 演示 CircuitBreakerFactory
 */
public func demonstrateFactory(): Unit {
    println("=== CircuitBreakerFactory 演示 ===")

    // 使用默认配置
    let cb1 = CircuitBreakerFactory.createDefault<String>()
    println("createDefault: ${cb1.getState().toString()}")

    // 创建带事件发布
    let cb2 = CircuitBreakerFactory.createWithEvents<String>()
    println("createWithEvents: ${cb2.getState().toString()}")

    // 快速失败配置
    let cb3 = CircuitBreakerFactory.createFastFail<String>()
    println("createFastFail: ${cb3.getState().toString()}")

    // 容错配置
    let cb4 = CircuitBreakerFactory.createTolerant<String>()
    println("createTolerant: ${cb4.getState().toString()}")

    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor Circuit Breaker 断路器演示")
    println("========================================")
    println()

    demonstrateStateTransitions()
    demonstrateBasicCircuitBreaker()
    demonstrateEventPublishingCircuitBreaker()
    demonstrateCircuitBreakerStats()
    demonstrateFactory()

    println("========================================")
    println("   Circuit Breaker 演示完成!")
    println("========================================")
}