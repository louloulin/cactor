/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 断路器测试
 * 验证故障隔离和快速失败机制
 */
package cactor.integration.testing.circuit_breaker_test

import std.sync.*
import std.time.*
import cactor.circuit_breaker.*

/**
 * 测试异常类
 */
class TestException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 测试断路器基础功能
 */
func testCircuitBreakerBasics(): Bool {
    let config = CircuitBreakerConfig(
        3,                          // 失败阈值
        2,                          // 成功阈值
        Duration.second,            // 超时时间
        Duration.second * 2         // 重置超时时间
    )
    let breaker = BasicCircuitBreaker<String>(config)
    
    // 初始状态应该是关闭
    match (breaker.getState()) {
        case CircuitBreakerState.Closed => ()
        case _ => 
            println("✗ 初始状态应该是关闭")
            return false
    }
    
    // 成功操作
    let result1 = breaker.execute({ => "success" })
    if (result1 != "success") {
        println("✗ 成功操作结果不正确")
        return false
    }
    
    let stats = breaker.getStats()
    if (stats.successCount != 1 || stats.totalRequests != 1) {
        println("✗ 统计信息不正确")
        return false
    }
    
    println("✓ 断路器基础功能测试通过")
    return true
}

/**
 * 测试断路器状态转换
 */
func testCircuitBreakerStateTransition(): Bool {
    let config = CircuitBreakerConfig(
        2,                          // 失败阈值
        1,                          // 成功阈值
        Duration.second,            // 超时时间
        Duration.millisecond * 100  // 重置超时时间
    )
    let breaker = BasicCircuitBreaker<String>(config)
    
    // 触发失败，但不超过阈值
    try {
        breaker.execute({ => throw TestException("test failure") })
    } catch (e: TestException) {
        // 预期的异常
    }
    
    // 状态应该仍然是关闭
    match (breaker.getState()) {
        case CircuitBreakerState.Closed => ()
        case _ => 
            println("✗ 单次失败后状态应该仍然是关闭")
            return false
    }
    
    // 再次触发失败，达到阈值
    try {
        breaker.execute({ => throw TestException("test failure") })
    } catch (e: TestException) {
        // 预期的异常
    }
    
    // 状态应该转换为开启
    match (breaker.getState()) {
        case CircuitBreakerState.Open => ()
        case _ => 
            println("✗ 达到失败阈值后状态应该是开启")
            return false
    }
    
    // 在开启状态下执行操作应该快速失败
    try {
        breaker.execute({ => "should not execute" })
        println("✗ 开启状态下应该快速失败")
        return false
    } catch (e: CircuitBreakerOpenException) {
        // 预期的异常
    }
    
    println("✓ 断路器状态转换测试通过")
    return true
}

/**
 * 测试断路器恢复机制
 */
func testCircuitBreakerRecovery(): Bool {
    let config = CircuitBreakerConfig(
        1,                          // 失败阈值
        1,                          // 成功阈值
        Duration.second,            // 超时时间
        Duration.millisecond * 50   // 重置超时时间
    )
    let breaker = BasicCircuitBreaker<String>(config)
    
    // 触发失败，使断路器开启
    try {
        breaker.execute({ => throw TestException("test failure") })
    } catch (e: TestException) {
        // 预期的异常
    }
    
    // 确认状态是开启
    match (breaker.getState()) {
        case CircuitBreakerState.Open => ()
        case _ => 
            println("✗ 失败后状态应该是开启")
            return false
    }
    
    // 等待重置超时时间
    sleep(Duration.millisecond * 100)
    
    // 执行成功操作，应该转换到半开状态，然后关闭
    let result = breaker.execute({ => "recovery success" })
    if (result != "recovery success") {
        println("✗ 恢复操作结果不正确")
        return false
    }
    
    // 状态应该转换为关闭
    match (breaker.getState()) {
        case CircuitBreakerState.Closed => ()
        case _ => 
            println("✗ 成功恢复后状态应该是关闭")
            return false
    }
    
    println("✓ 断路器恢复机制测试通过")
    return true
}

/**
 * 测试断路器统计信息
 */
func testCircuitBreakerStats(): Bool {
    let config = CircuitBreakerConfig(
        5,                          // 失败阈值
        3,                          // 成功阈值
        Duration.second,            // 超时时间
        Duration.second * 2         // 重置超时时间
    )
    let breaker = BasicCircuitBreaker<String>(config)
    
    // 执行一些成功操作
    breaker.execute({ => "success1" })
    breaker.execute({ => "success2" })
    
    // 执行一些失败操作
    try {
        breaker.execute({ => throw TestException("failure1") })
    } catch (e: TestException) {}
    
    try {
        breaker.execute({ => throw TestException("failure2") })
    } catch (e: TestException) {}
    
    let stats = breaker.getStats()
    
    if (stats.successCount != 2) {
        println("✗ 成功计数不正确: ${stats.successCount}")
        return false
    }
    
    if (stats.failureCount != 2) {
        println("✗ 失败计数不正确: ${stats.failureCount}")
        return false
    }
    
    if (stats.totalRequests != 4) {
        println("✗ 总请求数不正确: ${stats.totalRequests}")
        return false
    }
    
    let failureRate = stats.getFailureRate()
    if (failureRate != 0.5) {
        println("✗ 失败率不正确: ${failureRate}")
        return false
    }
    
    println("✓ 断路器统计信息测试通过")
    return true
}

/**
 * 测试断路器工厂
 */
func testCircuitBreakerFactory(): Bool {
    let defaultBreaker = CircuitBreakerFactory.createDefault<String>()
    let fastFailBreaker = CircuitBreakerFactory.createFastFail<String>()
    let tolerantBreaker = CircuitBreakerFactory.createTolerant<String>()
    
    // 测试默认断路器
    let result1 = defaultBreaker.execute({ => "default test" })
    if (result1 != "default test") {
        println("✗ 默认断路器执行失败")
        return false
    }
    
    // 测试快速失败断路器
    let result2 = fastFailBreaker.execute({ => "fast fail test" })
    if (result2 != "fast fail test") {
        println("✗ 快速失败断路器执行失败")
        return false
    }
    
    // 测试容错断路器
    let result3 = tolerantBreaker.execute({ => "tolerant test" })
    if (result3 != "tolerant test") {
        println("✗ 容错断路器执行失败")
        return false
    }
    
    println("✓ 断路器工厂测试通过")
    return true
}

/**
 * 测试断路器装饰器
 */
func testCircuitBreakerDecorator(): Bool {
    let breaker = CircuitBreakerFactory.createFastFail<String>()
    let fallback = { => "fallback result" }
    let decorator = CircuitBreakerDecorator<String>(breaker, Some(fallback))
    
    // 正常操作
    let result1 = decorator.call({ => "normal result" })
    if (result1 != "normal result") {
        println("✗ 装饰器正常操作失败")
        return false
    }
    
    // 手动触发断路器
    breaker.trip()
    
    // 断路器开启时应该使用fallback
    let result2 = decorator.call({ => "should not execute" })
    if (result2 != "fallback result") {
        println("✗ 装饰器fallback失败")
        return false
    }
    
    println("✓ 断路器装饰器测试通过")
    return true
}

/**
 * 测试手动控制
 */
func testManualControl(): Bool {
    let breaker = CircuitBreakerFactory.createDefault<String>()
    
    // 手动触发断路器
    breaker.trip()
    match (breaker.getState()) {
        case CircuitBreakerState.Open => ()
        case _ => 
            println("✗ 手动触发后状态应该是开启")
            return false
    }
    
    // 手动重置断路器
    breaker.reset()
    match (breaker.getState()) {
        case CircuitBreakerState.Closed => ()
        case _ => 
            println("✗ 手动重置后状态应该是关闭")
            return false
    }
    
    println("✓ 手动控制测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 断路器测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testCircuitBreakerBasics()
    allPassed = allPassed && testCircuitBreakerStateTransition()
    allPassed = allPassed && testCircuitBreakerRecovery()
    allPassed = allPassed && testCircuitBreakerStats()
    allPassed = allPassed && testCircuitBreakerFactory()
    allPassed = allPassed && testCircuitBreakerDecorator()
    allPassed = allPassed && testManualControl()
    
    if (allPassed) {
        println("\n🎉 所有断路器测试通过！")
        println("✓ 断路器基础功能正常")
        println("✓ 状态转换机制正确")
        println("✓ 恢复机制正常")
        println("✓ 统计信息准确")
        println("✓ 工厂模式正常")
        println("✓ 装饰器模式正常")
        println("✓ 手动控制正常")
        println("\n这验证了CActor的断路器实现！")
        println("🚀 Phase 3: 断路器功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
