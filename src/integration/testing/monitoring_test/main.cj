/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 性能监控测试
 * 验证指标收集和性能监控功能
 */
package cactor.integration.testing.monitoring_test

import std.time.*
import std.collection.*
import cactor.monitoring.*

/**
 * 简单的延迟函数
 */
func delay(ms: Int32): Unit {
    let start = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let target = start + Int64(ms)
    while (DateTime.now().toUnixTimeStamp().toMilliseconds() < target) {
        // 忙等待
    }
}

/**
 * 测试计数器指标
 */
func testCounter(): Bool {
    let counter = Counter("test.counter")
    
    // 初始值应该是0
    if (counter.get() != 0) {
        println("✗ 计数器初始值应该是0")
        return false
    }
    
    // 测试递增
    counter.increment()
    if (counter.get() != 1) {
        println("✗ 计数器递增后应该是1")
        return false
    }
    
    // 测试指定增量
    counter.increment(5)
    if (counter.get() != 6) {
        println("✗ 计数器增量后应该是6")
        return false
    }
    
    // 测试重置
    counter.reset()
    if (counter.get() != 0) {
        println("✗ 计数器重置后应该是0")
        return false
    }
    
    println("✓ 计数器测试通过")
    return true
}

/**
 * 测试仪表盘指标
 */
func testGauge(): Bool {
    let gauge = Gauge("test.gauge")
    
    // 初始值应该是0
    if (gauge.get() != 0.0) {
        println("✗ 仪表盘初始值应该是0.0")
        return false
    }
    
    // 测试设置值
    gauge.set(42.5)
    let value = gauge.get()
    if (value < 42.4 || value > 42.6) {
        println("✗ 仪表盘设置值不正确: ${value}")
        return false
    }
    
    // 测试递增
    gauge.increment()
    let newValue = gauge.get()
    if (newValue < 43.4 || newValue > 43.6) {
        println("✗ 仪表盘递增后值不正确: ${newValue}")
        return false
    }
    
    // 测试递减
    gauge.decrement()
    let finalValue = gauge.get()
    if (finalValue < 42.4 || finalValue > 42.6) {
        println("✗ 仪表盘递减后值不正确: ${finalValue}")
        return false
    }
    
    println("✓ 仪表盘测试通过")
    return true
}

/**
 * 测试直方图指标
 */
func testHistogram(): Bool {
    let buckets = [10, 50, 100, 500, 1000]
    let histogram = Histogram("test.histogram", buckets)
    
    // 初始状态
    if (histogram.getCount() != 0) {
        println("✗ 直方图初始计数应该是0")
        return false
    }
    
    if (histogram.getSum() != 0.0) {
        println("✗ 直方图初始总和应该是0.0")
        return false
    }
    
    // 观察一些值
    histogram.observe(25.0)
    histogram.observe(75.0)
    histogram.observe(150.0)
    
    if (histogram.getCount() != 3) {
        println("✗ 直方图计数应该是3")
        return false
    }
    
    let sum = histogram.getSum()
    if (sum < 249.0 || sum > 251.0) {
        println("✗ 直方图总和不正确: ${sum}")
        return false
    }
    
    let mean = histogram.getMean()
    if (mean < 83.0 || mean > 84.0) {
        println("✗ 直方图平均值不正确: ${mean}")
        return false
    }
    
    println("✓ 直方图测试通过")
    return true
}

/**
 * 测试计时器指标
 */
func testTimer(): Bool {
    let timer = Timer("test.timer")
    
    // 测试计时操作
    let result = timer.time({ => 
        delay(10)
        "test result"
    })
    
    if (result != "test result") {
        println("✗ 计时器操作结果不正确")
        return false
    }
    
    if (timer.getCount() != 1) {
        println("✗ 计时器计数应该是1")
        return false
    }
    
    let mean = timer.getMean()
    if (mean < 5.0 || mean > 50.0) {
        println("✗ 计时器平均时间不在预期范围: ${mean}ms")
        return false
    }
    
    // 测试记录持续时间
    timer.record(Duration.millisecond * 20)
    
    if (timer.getCount() != 2) {
        println("✗ 计时器计数应该是2")
        return false
    }
    
    println("✓ 计时器测试通过")
    return true
}

/**
 * 测试指标注册表
 */
func testMetricRegistry(): Bool {
    let registry = MetricRegistry()
    
    // 测试计数器注册
    let counter1 = registry.counter("test.counter1")
    let counter2 = registry.counter("test.counter1")  // 应该返回同一个实例
    
    counter1.increment()
    if (counter2.get() != 1) {
        println("✗ 注册表应该返回同一个计数器实例")
        return false
    }
    
    // 测试仪表盘注册
    let gauge = registry.gauge("test.gauge1")
    gauge.set(100.0)
    
    // 测试计时器注册
    let timer = registry.timer("test.timer1")
    timer.record(Duration.millisecond * 50)
    
    // 测试获取所有指标
    let counters = registry.getAllCounters()
    if (counters.size == 0) {
        println("✗ 注册表应该包含计数器")
        return false
    }
    
    let gauges = registry.getAllGauges()
    if (gauges.size == 0) {
        println("✗ 注册表应该包含仪表盘")
        return false
    }
    
    let timers = registry.getAllTimers()
    if (timers.size == 0) {
        println("✗ 注册表应该包含计时器")
        return false
    }
    
    println("✓ 指标注册表测试通过")
    return true
}

/**
 * 测试全局指标
 */
func testGlobalMetrics(): Bool {
    // 测试全局计数器
    let counter = Metrics.counter("global.test.counter")
    counter.increment()
    
    if (counter.get() != 1) {
        println("✗ 全局计数器不正确")
        return false
    }
    
    // 测试全局仪表盘
    let gauge = Metrics.gauge("global.test.gauge")
    gauge.set(50.0)
    
    let value = gauge.get()
    if (value < 49.0 || value > 51.0) {
        println("✗ 全局仪表盘值不正确: ${value}")
        return false
    }
    
    // 测试全局计时器
    let timer = Metrics.timer("global.test.timer")
    timer.record(Duration.millisecond * 30)
    
    if (timer.getCount() != 1) {
        println("✗ 全局计时器计数不正确")
        return false
    }
    
    println("✓ 全局指标测试通过")
    return true
}

/**
 * 测试性能监控器
 */
func testPerformanceMonitor(): Bool {
    let monitor = PerformanceMonitor()
    
    // 测试消息处理记录
    monitor.recordMessageProcessed()
    monitor.recordMessageProcessed()
    
    // 测试Actor创建记录
    monitor.recordActorCreated()
    monitor.recordActorCreated()
    monitor.recordActorCreated()
    
    // 测试Actor停止记录
    monitor.recordActorStopped()
    
    // 测试邮箱大小更新
    monitor.updateMailboxSize(10)
    
    // 测试错误记录
    monitor.recordError()
    
    // 测试消息处理时间记录
    let result = monitor.recordMessageProcessingTime({ => 
        delay(5)
        "processed"
    })
    
    if (result != "processed") {
        println("✗ 监控器处理时间记录结果不正确")
        return false
    }
    
    // 获取统计信息
    let stats = monitor.getStats()
    
    if (stats.messagesProcessed != 2) {
        println("✗ 消息处理数量不正确: ${stats.messagesProcessed}")
        return false
    }
    
    if (stats.actorsCreated != 3) {
        println("✗ Actor创建数量不正确: ${stats.actorsCreated}")
        return false
    }
    
    if (stats.actorsStopped != 1) {
        println("✗ Actor停止数量不正确: ${stats.actorsStopped}")
        return false
    }
    
    if (stats.getActiveActors() != 2) {
        println("✗ 活跃Actor数量不正确: ${stats.getActiveActors()}")
        return false
    }
    
    if (stats.errors != 1) {
        println("✗ 错误数量不正确: ${stats.errors}")
        return false
    }
    
    if (stats.currentMailboxSize != 10.0) {
        println("✗ 邮箱大小不正确: ${stats.currentMailboxSize}")
        return false
    }
    
    println("✓ 性能监控器测试通过")
    return true
}

/**
 * 测试全局监控器
 */
func testGlobalMonitor(): Bool {
    // 清理之前的状态
    let registry = Metrics.getRegistry()
    registry.clear()
    
    // 测试全局监控器
    GlobalMonitor.recordMessageProcessed()
    GlobalMonitor.recordActorCreated()
    GlobalMonitor.recordActorCreated()
    GlobalMonitor.updateMailboxSize(5)
    
    let result = GlobalMonitor.recordMessageProcessingTime({ => 
        delay(3)
        "global processed"
    })
    
    if (result != "global processed") {
        println("✗ 全局监控器处理时间记录结果不正确")
        return false
    }
    
    let stats = GlobalMonitor.getStats()

    // 由于全局监控器在之前的测试中可能已经有数据，我们只检查增量
    if (stats.messagesProcessed < 1) {
        println("✗ 全局监控器消息处理数量应该至少为1: ${stats.messagesProcessed}")
        return false
    }

    if (stats.actorsCreated < 2) {
        println("✗ 全局监控器Actor创建数量应该至少为2: ${stats.actorsCreated}")
        return false
    }
    
    println("✓ 全局监控器测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 性能监控测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testCounter()
    allPassed = allPassed && testGauge()
    allPassed = allPassed && testHistogram()
    allPassed = allPassed && testTimer()
    allPassed = allPassed && testMetricRegistry()
    allPassed = allPassed && testGlobalMetrics()
    allPassed = allPassed && testPerformanceMonitor()
    allPassed = allPassed && testGlobalMonitor()
    
    if (allPassed) {
        println("\n🎉 所有性能监控测试通过！")
        println("✓ 计数器指标正常")
        println("✓ 仪表盘指标正常")
        println("✓ 直方图指标正常")
        println("✓ 计时器指标正常")
        println("✓ 指标注册表正常")
        println("✓ 全局指标正常")
        println("✓ 性能监控器正常")
        println("✓ 全局监控器正常")
        println("\n这验证了CActor的性能监控实现！")
        println("🚀 Phase 3: 性能监控功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
