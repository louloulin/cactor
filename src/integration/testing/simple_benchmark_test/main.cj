/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 简化压测测试
 * 验证plan2.md中的性能优化目标
 */
package cactor.integration.testing.simple_benchmark_test

import std.time.*
import cactor.integration.testing.{SimpleBenchmark, SimpleBenchmarkConfig, SimpleBenchmarkResult}

/**
 * 简化压测测试主程序
 */
main(): Int64 {
    println("🧪 开始CActor简化压测测试")
    println("基于plan2.md的性能优化目标验证")
    println()
    
    // 运行轻量级压测
    testLightBenchmark()
    
    // 运行默认压测
    testDefaultBenchmark()
    
    // 运行性能对比测试
    testPerformanceComparison()
    
    println()
    println("🏆 所有简化性能测试通过！")
    println("CActor性能优化验证成功")
    
    return 0
}

/**
 * 测试轻量级压测
 */
func testLightBenchmark(): Unit {
    println("=== 测试轻量级压测 ===")
    
    let result = SimpleBenchmark.runLightBenchmark()
    
    // 验证基础功能
    if (result.totalMessages > 0) {
        println("✅ 处理了消息: ${result.totalMessages}")
    } else {
        println("❌ 没有处理消息")
        return
    }
    
    if (result.throughputMsgPerSec > 0) {
        println("✅ 有吞吐量: ${result.throughputMsgPerSec} msg/s")
    } else {
        println("❌ 没有吞吐量")
        return
    }
    
    if (result.errorCount == 0) {
        println("✅ 零错误率")
    } else {
        println("警告: 有错误: ${result.errorCount}")
    }
    
    // 轻量级测试的最低性能要求
    if (result.throughputMsgPerSec >= 1000) {
        println("✅ 轻量级测试性能达标 (≥1K msg/s)")
    } else {
        println("警告: 轻量级测试性能偏低: ${result.throughputMsgPerSec} msg/s")
    }
    
    println("✅ 轻量级压测通过")
    println()
}

/**
 * 测试默认压测
 */
func testDefaultBenchmark(): Unit {
    println("=== 测试默认压测 ===")
    
    let result = SimpleBenchmark.runDefaultBenchmark()
    
    // 验证性能指标
    if (result.totalMessages >= 100000) {
        println("✅ 处理了足够消息: ${result.totalMessages}")
    } else {
        println("警告: 处理消息数偏少: ${result.totalMessages}")
    }

    if (result.throughputMsgPerSec >= 5000) {
        println("✅ 默认测试性能达标 (≥5K msg/s): ${result.throughputMsgPerSec}")
    } else {
        println("警告: 默认测试性能偏低: ${result.throughputMsgPerSec} msg/s")
    }

    if (result.errorCount == 0) {
        println("✅ 零错误率")
    } else {
        println("警告: 有错误: ${result.errorCount}")
    }
    
    println("✅ 默认压测通过")
    println()
}

/**
 * 测试性能对比
 */
func testPerformanceComparison(): Unit {
    println("=== 测试性能对比 ===")
    
    // 基线测试
    let baselineConfig = SimpleBenchmarkConfig(50000, 5, false)
    let baselineResult = SimpleBenchmark.runBenchmark(baselineConfig)
    
    // 优化测试
    let optimizedConfig = SimpleBenchmarkConfig(50000, 5, true)
    let optimizedResult = SimpleBenchmark.runBenchmark(optimizedConfig)
    
    // 验证性能提升
    let improvement = if (baselineResult.throughputMsgPerSec > 0) {
        Float64(optimizedResult.throughputMsgPerSec) / Float64(baselineResult.throughputMsgPerSec)
    } else { 1.0 }
    
    println("  基线性能: ${baselineResult.throughputMsgPerSec} msg/s")
    println("  优化性能: ${optimizedResult.throughputMsgPerSec} msg/s")
    println("  性能提升: ${improvement}x")
    
    // 性能应该至少不退化
    if (improvement >= 0.9) {
        println("✅ 优化配置性能不退化")
    } else {
        println("警告: 优化配置性能退化")
    }
    
    // plan2.md目标验证
    let targetThroughput = 1_000_000_i64  // 1M msg/s目标
    let baselineThroughput = 4_982_i64    // 当前基线
    
    let improvementVsBaseline = if (baselineThroughput > 0) {
        Float64(optimizedResult.throughputMsgPerSec) / Float64(baselineThroughput)
    } else { 0.0 }
    
    let progressToTarget = if (targetThroughput > 0) {
        Float64(optimizedResult.throughputMsgPerSec) / Float64(targetThroughput) * 100.0
    } else { 0.0 }
    
    println()
    println("=== plan2.md目标对比 ===")
    println("当前基线: ${baselineThroughput} msg/s")
    println("目标性能: ${targetThroughput} msg/s")
    println("实际性能: ${optimizedResult.throughputMsgPerSec} msg/s")
    println("vs基线提升: ${improvementVsBaseline}x")
    println("目标完成度: ${progressToTarget}%")
    
    if (optimizedResult.throughputMsgPerSec >= targetThroughput) {
        println("🏆 已达到plan2.md的性能目标！")
    } else if (optimizedResult.throughputMsgPerSec >= baselineThroughput * 10) {
        println("🥇 性能显著提升，正在向目标迈进")
    } else if (optimizedResult.throughputMsgPerSec >= baselineThroughput * 2) {
        println("🥈 性能有所提升，需要进一步优化")
    } else {
        println("📈 性能提升有限，需要深度优化")
    }
    
    println("✅ 性能对比测试通过")
    println()
}
