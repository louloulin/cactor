/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 5 监控系统测试
 * 测试分布式追踪、性能分析和可视化系统
 */
package cactor.tests.phase5_monitoring_test

import std.time.*
import cactor.monitoring.*
import cactor.core.actor.*

// 测试分布式追踪功能
func testDistributedTracing(): Bool {
    println("=== 测试分布式追踪系统 ===")
    
    // 创建追踪器
    let collector = MemorySpanCollector(100)
    let sampler = SimpleSampler(1.0)  // 100%采样
    let tracer = DistributedTracer(collector, sampler)
    
    // 创建根span
    let rootSpan = tracer.startSpan("test_operation", None)
    rootSpan.setTag("service", "test_service")
    rootSpan.setTag("version", "1.0")
    rootSpan.log("开始测试操作")
    
    // 模拟一些处理时间
    delay(10)
    
    // 创建子span
    let childContext = rootSpan.getContext()
    let childSpan = tracer.startSpan("child_operation", Some(childContext))
    childSpan.setTag("operation", "data_processing")
    childSpan.log("处理数据")
    
    delay(5)
    
    // 完成span
    tracer.finishSpan(childSpan)
    tracer.finishSpan(rootSpan)
    
    // 验证结果
    if (tracer.getActiveSpanCount() != 0) {
        println("✗ 活跃span数量应该为0")
        return false
    }
    
    if (collector.getSpanCount() != 2) {
        println("✗ 收集的span数量应该为2")
        return false
    }
    
    println("✓ 分布式追踪测试通过")
    return true
}

// 测试性能分析功能
func testPerformanceAnalyzer(): Bool {
    println("=== 测试性能分析系统 ===")
    
    // 创建性能分析器
    let analyzer = SystemPerformanceAnalyzer(1000)
    analyzer.start()
    
    // 创建Actor监控器
    let actorPath = ActorPath("test", "/user/test_actor")
    let monitor = analyzer.getOrCreateActorMonitor(actorPath)
    
    // 模拟消息处理
    for (i in 0..10) {
        let processingTime = Float64(i * 10 + 5)  // 5-95ms
        monitor.recordMessageProcessed(processingTime)
        monitor.recordQueueSize(Int64(i))
    }
    
    // 模拟一个错误
    monitor.recordError()
    
    // 获取统计信息
    let msgStats = monitor.getMessageProcessingStats()
    let queueStats = monitor.getQueueSizeStats()
    
    // 验证结果
    if (msgStats.count != 10) {
        println("✗ 消息处理统计计数不正确: ${msgStats.count}")
        return false
    }
    
    if (monitor.getErrorCount() != 1) {
        println("✗ 错误计数不正确: ${monitor.getErrorCount()}")
        return false
    }
    
    if (msgStats.avg <= 0.0) {
        println("✗ 平均处理时间应该大于0: ${msgStats.avg}")
        return false
    }
    
    // 生成报告
    let report = monitor.generateReport()
    if (report.size <= 0) {
        println("✗ 报告应该有内容")
        return false
    }
    
    analyzer.stop()
    println("✓ 性能分析测试通过")
    return true
}

// 测试可视化系统
func testVisualizationSystem(): Bool {
    println("=== 测试可视化监控系统 ===")
    
    // 创建依赖组件
    let analyzer = SystemPerformanceAnalyzer(1000)
    let collector = MemorySpanCollector(100)
    let sampler = SimpleSampler(1.0)
    let tracer = DistributedTracer(collector, sampler)
    
    // 创建可视化管理器
    let vizManager = VisualizationManager(analyzer, tracer)
    vizManager.start()
    
    // 验证默认仪表板
    if (vizManager.getDashboardCount() != 2) {
        println("✗ 默认仪表板数量应该为2: ${vizManager.getDashboardCount()}")
        return false
    }
    
    // 获取系统概览仪表板
    match (vizManager.getDashboard("系统概览")) {
        case Some(dashboard) =>
            if (dashboard.getComponentCount() != 3) {
                println("✗ 系统概览仪表板组件数量应该为3: ${dashboard.getComponentCount()}")
                return false
            }

            if (!dashboard.isActive()) {
                println("✗ 系统概览仪表板应该是活跃的")
                return false
            }
        case None =>
            println("✗ 系统概览仪表板不存在")
            return false
    }
    
    // 创建自定义仪表板
    let customDashboard = MonitoringDashboard("自定义仪表板", 2000)
    let customComponent = DashboardComponent("custom_metric", "自定义指标", DashboardComponentType.Counter)
    let customSeries = TimeSeries("测试指标", 50)
    
    // 添加测试数据
    for (i in 0..5) {
        customSeries.addDataPoint(Float64(i * 10), "测试数据${i}")
    }
    
    customComponent.addTimeSeries(customSeries)
    customDashboard.addComponent(customComponent)
    vizManager.addDashboard(customDashboard)
    
    // 验证自定义仪表板
    if (vizManager.getDashboardCount() != 3) {
        println("✗ 添加自定义仪表板后数量应该为3: ${vizManager.getDashboardCount()}")
        return false
    }
    
    // 更新指标
    vizManager.updateMetrics()
    
    // 渲染仪表板
    let dashboardOutput = vizManager.renderAllDashboards()
    if (dashboardOutput.size <= 0) {
        println("✗ 仪表板输出应该有内容")
        return false
    }
    
    vizManager.stop()
    println("✓ 可视化系统测试通过")
    return true
}

// 测试时间序列数据
func testTimeSeries(): Bool {
    println("=== 测试时间序列数据 ===")
    
    let series = TimeSeries("测试序列", 5)
    
    // 添加数据点
    for (i in 0..10) {
        series.addDataPoint(Float64(i), "数据${i}")
    }
    
    // 验证数据点数量（应该被限制为5个）
    if (series.size() != 5) {
        println("✗ 时间序列大小应该被限制为5: ${series.size()}")
        return false
    }
    
    // 验证最新值
    match (series.getLatestValue()) {
        case Some(value) =>
            if (value != 9.0) {
                println("✗ 最新值应该是9.0: ${value}")
                return false
            }
        case None =>
            println("✗ 应该有最新值")
            return false
    }
    
    // 获取所有数据点
    let points = series.getDataPoints()
    if (points.size != 5) {
        println("✗ 数据点数组大小应该为5: ${points.size}")
        return false
    }
    
    // 验证数据点是最新的5个
    if (points[0].value != 5.0) {
        println("✗ 最老的保留值应该是5.0: ${points[0].value}")
        return false
    }
    
    if (points[4].value != 9.0) {
        println("✗ 最新的值应该是9.0: ${points[4].value}")
        return false
    }
    
    println("✓ 时间序列测试通过")
    return true
}

// 测试性能计数器
func testPerformanceCounter(): Bool {
    println("=== 测试性能计数器 ===")
    
    let counter = PerformanceCounter(100)
    
    // 记录一些值
    let testValues = [10.0, 20.0, 30.0, 40.0, 50.0]
    for (value in testValues) {
        counter.record(value)
    }
    
    // 获取统计信息
    let stats = counter.getStats()
    
    // 验证统计信息
    if (stats.count != 5) {
        println("✗ 计数应该为5: ${stats.count}")
        return false
    }
    
    if (stats.sum != 150.0) {
        println("✗ 总和应该为150.0: ${stats.sum}")
        return false
    }
    
    if (stats.min != 10.0) {
        println("✗ 最小值应该为10.0: ${stats.min}")
        return false
    }
    
    if (stats.max != 50.0) {
        println("✗ 最大值应该为50.0: ${stats.max}")
        return false
    }
    
    if (stats.avg != 30.0) {
        println("✗ 平均值应该为30.0: ${stats.avg}")
        return false
    }
    
    // 重置计数器
    counter.reset()
    let resetStats = counter.getStats()
    if (resetStats.count != 0) {
        println("✗ 重置后计数应该为0: ${resetStats.count}")
        return false
    }
    
    println("✓ 性能计数器测试通过")
    return true
}

// 简单的延迟函数
func delay(ms: Int32): Unit {
    let start = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let target = start + Int64(ms)
    while (DateTime.now().toUnixTimeStamp().toMilliseconds() < target) {
        // 忙等待
    }
}

// 主测试函数
main(): Int64 {
    println("========================================")
    println("CActor 3.0 - Phase 5 监控系统测试")
    println("========================================")
    
    var allTestsPassed = true
    
    try {
        allTestsPassed = allTestsPassed && testDistributedTracing()
        allTestsPassed = allTestsPassed && testPerformanceAnalyzer()
        allTestsPassed = allTestsPassed && testVisualizationSystem()
        allTestsPassed = allTestsPassed && testTimeSeries()
        allTestsPassed = allTestsPassed && testPerformanceCounter()
        
        println("\n========================================")
        if (allTestsPassed) {
            println("🎉 所有Phase 5监控系统测试通过！")
            println("✅ 分布式追踪系统验证成功")
            println("✅ 实时性能分析系统验证成功")
            println("✅ 可视化监控界面验证成功")
            println("✅ Phase 5: 可观测性和调试系统实现完成")
            return 0
        } else {
            println("❌ 部分Phase 5监控系统测试失败")
            return 1
        }
        
    } catch (e: Exception) {
        println("❌ 测试过程中发生异常: ${e.message}")
        return 1
    }
}
