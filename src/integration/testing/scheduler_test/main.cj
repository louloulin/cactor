/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 高性能调度器系统测试
 * 验证批量处理、性能监控等高级调度器功能
 */
package cactor.integration.testing.scheduler_test

import std.sync.*
import std.time.*
import std.collection.*
import cactor.dispatcher.batch_processing.*
import cactor.dispatcher.monitoring.*
import cactor.core.message.*
import cactor.dispatcher.work_stealing.*

// ============================================================================
// 1. 测试批量处理器
// ============================================================================

func testBatchProcessor(): Bool {
    println("🧪 测试批量处理器...")

    // 简化测试，不使用lambda捕获可变变量
    let config = BatchConfig(5, 100, true, 1000)
    let processor = BatchProcessor<Int32>(config, { batch =>
        println("处理批次: ${batch.size} 条消息")
    })

    processor.start()

    // 添加消息
    for (i in 0..12) {  // 0到11，共12条消息
        if (!processor.addMessage(Int32(i))) {
            println("❌ 添加消息失败: ${i}")
            return false
        }
    }

    // 等待处理完成
    sleep(Duration.millisecond * 200)
    processor.stop()

    let stats = processor.getStats()

    if (stats.getTotalBatches() < 1) {
        println("❌ 应该至少处理1个批次")
        return false
    }

    if (stats.getTotalMessages() != 12) {
        println("❌ 应该处理12条消息，实际: ${stats.getTotalMessages()}")
        return false
    }

    println("✅ 批量处理器测试通过")
    println("  - 处理批次: ${stats.getTotalBatches()}")
    println("  - 总消息数: ${stats.getTotalMessages()}")
    println("  - 平均批量大小: ${stats.getAverageBatchSize()}")
    return true
}

// ============================================================================
// 2. 测试延时直方图
// ============================================================================

func testLatencyHistogram(): Bool {
    println("🧪 测试延时直方图...")
    
    let histogram = LatencyHistogram()
    
    // 添加一些延时样本（纳秒）
    let latencies = [500, 1500, 15000, 150000, 1500000]  // 0.5μs, 1.5μs, 15μs, 150μs, 1.5ms
    
    for (latency in latencies) {
        histogram.recordLatency(Int64(latency))
    }
    
    let avgLatency = histogram.getAverageLatency()
    let p99Latency = histogram.getPercentileLatency(99.0)
    
    if (avgLatency <= 0) {
        println("❌ 平均延时应该大于0")
        return false
    }
    
    if (p99Latency <= 0) {
        println("❌ P99延时应该大于0")
        return false
    }
    
    println("✅ 延时直方图测试通过")
    println("  - 平均延时: ${avgLatency / 1000}μs")
    println("  - P99延时: ${p99Latency / 1000}μs")
    return true
}

// ============================================================================
// 3. 测试吞吐量计算器
// ============================================================================

func testThroughputCalculator(): Bool {
    println("🧪 测试吞吐量计算器...")
    
    let calculator = ThroughputCalculator(1000)  // 1秒窗口
    
    // 模拟事件
    for (i in 0..10) {  // 0到9，共10次
        calculator.recordEvent(1)
        sleep(Duration.millisecond * 50)  // 50ms间隔
    }
    
    let throughput = calculator.getCurrentThroughput()

    if (throughput <= 0.0) {
        println("❌ 吞吐量应该大于0，实际: ${throughput}")
        return false
    }
    
    println("✅ 吞吐量计算器测试通过")
    println("  - 当前吞吐量: ${throughput} events/s")
    return true
}

// ============================================================================
// 4. 测试调度器监控器
// ============================================================================

func testSchedulerMonitor(): Bool {
    println("🧪 测试调度器监控器...")
    
    let monitor = SchedulerMonitor()
    
    // 模拟调度器活动
    for (i in 0..100) {  // 明确使用0到99，共100次
        monitor.recordTaskScheduled()

        // 模拟任务执行延时
        let latency = Int64(1000 + i * 100)  // 1μs到10μs
        monitor.recordTaskCompleted(latency)

        // 模拟工作窃取
        if (i % 10 == 0) {
            monitor.recordStealAttempt(true)
        } else if (i % 20 == 0) {
            monitor.recordStealAttempt(false)
        }

        // 模拟工作时间
        monitor.recordWorkerTime(latency, latency / 10)
    }
    
    let metrics = monitor.getCurrentMetrics()

    if (metrics.totalTasksScheduled != 100) {
        println("❌ 调度任务数应该为100，实际: ${metrics.totalTasksScheduled}")
        return false
    }

    if (metrics.totalTasksCompleted != 100) {
        println("❌ 完成任务数应该为100，实际: ${metrics.totalTasksCompleted}")
        return false
    }
    
    if (metrics.averageLatencyNs <= 0) {
        println("❌ 平均延时应该大于0")
        return false
    }
    
    if (metrics.throughputPerSecond <= 0.0) {
        println("❌ 吞吐量应该大于0")
        return false
    }
    
    println("✅ 调度器监控器测试通过")
    println("  - 调度任务: ${metrics.totalTasksScheduled}")
    println("  - 完成任务: ${metrics.totalTasksCompleted}")
    println("  - 平均延时: ${metrics.averageLatencyNs / 1000}μs")
    println("  - P99延时: ${metrics.p99LatencyNs / 1000}μs")
    println("  - 吞吐量: ${metrics.throughputPerSecond} tasks/s")
    println("  - 工作线程利用率: ${metrics.workerUtilization * 100.0}%")
    println("  - 窃取成功率: ${metrics.stealSuccessRate * 100.0}%")
    return true
}

// ============================================================================
// 5. 测试批量处理器工厂
// ============================================================================

func testBatchProcessorFactory(): Bool {
    println("🧪 测试批量处理器工厂...")

    // 简化测试，不使用lambda捕获可变变量
    let messageProcessor = BatchProcessorFactory.createDefault<String>({ batch =>
        println("处理消息批次: ${batch.size} 条")
    })

    messageProcessor.start()

    // 添加消息
    let messages = ["msg1", "msg2", "msg3", "msg4", "msg5"]
    for (msg in messages) {
        if (!messageProcessor.addMessage(msg)) {
            println("❌ 添加消息失败: ${msg}")
            return false
        }
    }

    // 等待处理
    sleep(Duration.millisecond * 100)
    messageProcessor.stop()

    let stats = messageProcessor.getStats()
    if (stats.getTotalMessages() != 5) {
        println("❌ 应该处理5条消息，实际: ${stats.getTotalMessages()}")
        return false
    }

    println("✅ 批量处理器工厂测试通过")
    println("  - 处理消息数: ${stats.getTotalMessages()}")
    return true
}

// ============================================================================
// 主测试函数
// ============================================================================

main(): Int64 {
    println("=== CActor 3.0 高性能调度器系统测试 ===")
    println("验证批量处理、性能监控等高级功能")
    
    var passedTests = 0
    var totalTests = 0
    
    // 运行所有测试
    totalTests += 1
    if (testBatchProcessor()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testLatencyHistogram()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testThroughputCalculator()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testSchedulerMonitor()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testBatchProcessorFactory()) {
        passedTests += 1
    }
    
    println("========================================")
    println("=== 测试结果 ===")
    println("通过测试: ${passedTests}/${totalTests}")
    
    if (passedTests == totalTests) {
        println("🎉 所有高性能调度器测试通过！")
        println("✅ 批量处理器功能正常")
        println("✅ 延时统计功能正常")
        println("✅ 吞吐量监控功能正常")
        println("✅ 调度器监控功能正常")
        println("✅ 工厂模式功能正常")
        println("")
        println("🚀 Phase 3: 高性能调度器系统功能完成！")
        println("这验证了CActor 3.0的高级调度器功能！")
        return 0
    } else {
        println("❌ 部分高性能调度器测试失败")
        return 1
    }
}
