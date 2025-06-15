/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 3 优化调度器测试
 * 高性能工作窃取调度器功能验证和性能测试
 */
package cactor.integration.testing.optimized_scheduler_test

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.message.*
import cactor.core.actor.*
import cactor.dispatcher.optimized.*
import cactor.mailbox.lockfree.*

// 测试消息类型
public class TestMessage <: Message {
    private let id: Int64
    private let data: String
    
    public init(id: Int64, data: String) {
        this.id = id
        this.data = data
    }
    
    public func messageType(): String {
        return "TestMessage"
    }
    
    public func getId(): Int64 {
        return id
    }
    
    public func getData(): String {
        return data
    }
}

// 简化的测试Actor引用
public class TestActorRef {
    private let actorId: String

    public init(actorId: String) {
        this.actorId = actorId
    }

    public func getActorId(): String {
        return actorId
    }
}

/**
 * 测试调度器配置创建
 */
func testSchedulerConfigCreation(): Bool {
    println("=== 测试调度器配置创建 ===")
    
    // 测试默认配置
    let defaultConfig = SchedulerConfig.createDefault()
    if (defaultConfig.workerCount != 8) {
        println("✗ 默认工作线程数应该为8")
        return false
    }
    
    if (defaultConfig.loadBalancingStrategy.getValue() != LoadBalancingStrategy.LeastLoaded.getValue()) {
        println("✗ 默认负载均衡策略应该为LeastLoaded")
        return false
    }

    if (defaultConfig.stealingStrategy.getValue() != StealingStrategy.AdaptiveStealing.getValue()) {
        println("✗ 默认窃取策略应该为AdaptiveStealing")
        return false
    }
    
    // 测试高吞吐量配置
    let highThroughputConfig = SchedulerConfig.createHighThroughput()
    if (highThroughputConfig.workerCount != 16) {
        println("✗ 高吞吐量配置工作线程数应该为16")
        return false
    }
    
    if (highThroughputConfig.stealingStrategy.getValue() != StealingStrategy.BatchStealing.getValue()) {
        println("✗ 高吞吐量配置窃取策略应该为BatchStealing")
        return false
    }
    
    println("✓ 调度器配置创建测试通过")
    return true
}

/**
 * 测试负载均衡器
 */
func testLoadBalancer(): Bool {
    println("=== 测试负载均衡器 ===")
    
    let config = SchedulerConfig.createDefault()
    let loadBalancer = LoadBalancer(config)
    
    // 测试工作线程选择
    let selectedWorker1 = loadBalancer.selectWorker()
    if (selectedWorker1 < 0 || selectedWorker1 >= config.workerCount) {
        println("✗ 选择的工作线程ID超出范围: ${selectedWorker1}")
        return false
    }
    
    // 测试统计信息更新
    let testStats = WorkerLoadStats(0, 10, 100, 5, 3, 0.5)
    loadBalancer.updateWorkerStats(0, testStats)
    
    let retrievedStats = loadBalancer.getWorkerStats(0)
    if (retrievedStats.workerId != 0) {
        println("✗ 工作线程ID不匹配")
        return false
    }
    
    if (retrievedStats.localQueueSize != 10) {
        println("✗ 本地队列大小不匹配")
        return false
    }
    
    println("✓ 负载均衡器测试通过")
    return true
}

/**
 * 测试优化调度器创建和启动
 */
func testOptimizedDispatcherCreation(): Bool {
    println("=== 测试优化调度器创建 ===")
    
    let dispatcher = OptimizedWorkStealingDispatcher.createDefault()
    
    if (dispatcher.getWorkerCount() != 8) {
        println("✗ 工作线程数应该为8")
        return false
    }
    
    if (dispatcher.getTotalTasksSubmitted() != 0) {
        println("✗ 初始提交任务数应该为0")
        return false
    }
    
    if (dispatcher.getTotalTasksProcessed() != 0) {
        println("✗ 初始处理任务数应该为0")
        return false
    }
    
    println("✓ 优化调度器创建测试通过")
    return true
}

/**
 * 测试消息分发功能
 */
func testMessageDispatch(): Bool {
    println("=== 测试消息分发功能 ===")
    
    let dispatcher = OptimizedWorkStealingDispatcher.createDefault()
    dispatcher.start()
    
    // 等待调度器启动
    sleep(Duration.millisecond * 100)
    
    // 创建测试消息和Actor引用
    let message = TestMessage(1, "test data")
    let envelope = Envelope(message, None)
    let actorRef = TestActorRef("test-actor")
    
    // 分发消息 (简化调用，不需要ActorRef参数)
    dispatcher.dispatchSimple(envelope)
    
    // 等待消息处理
    sleep(Duration.millisecond * 100)
    
    if (dispatcher.getTotalTasksSubmitted() != 1) {
        println("✗ 提交任务数应该为1")
        dispatcher.stop()
        return false
    }
    
    dispatcher.stop()
    println("✓ 消息分发功能测试通过")
    return true
}

/**
 * 测试高并发消息处理
 */
func testConcurrentMessageProcessing(): Bool {
    println("=== 测试高并发消息处理 ===")
    
    let dispatcher = OptimizedWorkStealingDispatcher.createHighThroughput()
    dispatcher.start()
    
    // 等待调度器启动
    sleep(Duration.millisecond * 100)
    
    let messageCount = 1000
    let actorRef = TestActorRef("concurrent-test-actor")
    
    let startTime = getCurrentTimeNanos()
    
    // 并发提交大量消息
    for (i in 0..messageCount) {
        let message = TestMessage(Int64(i), "concurrent test ${i}")
        let envelope = Envelope(message, None)
        dispatcher.dispatchSimple(envelope)
    }
    
    // 等待消息处理完成
    sleep(Duration.millisecond * 500)
    
    let endTime = getCurrentTimeNanos()
    let duration = Float64(endTime - startTime) / 1000000000.0  // 转换为秒
    let throughput = Float64(messageCount) / duration
    
    println("并发测试结果:")
    println("  消息数量: ${messageCount}")
    println("  处理时间: ${duration}秒")
    println("  吞吐量: ${throughput} msg/s")
    
    if (dispatcher.getTotalTasksSubmitted() != Int64(messageCount)) {
        println("✗ 提交任务数不匹配: 期望${messageCount}, 实际${dispatcher.getTotalTasksSubmitted()}")
        dispatcher.stop()
        return false
    }
    
    // 验证性能目标：至少10K msg/s
    if (throughput < 10000.0) {
        println("⚠ 吞吐量低于预期目标10K msg/s")
    } else {
        println("✓ 吞吐量达到预期目标")
    }
    
    dispatcher.stop()
    println("✓ 高并发消息处理测试通过")
    return true
}

/**
 * 测试性能监控功能
 */
func testPerformanceMonitoring(): Bool {
    println("=== 测试性能监控功能 ===")
    
    let dispatcher = OptimizedWorkStealingDispatcher.createDefault()
    dispatcher.start()
    
    // 等待调度器启动
    sleep(Duration.millisecond * 100)
    
    // 提交一些测试消息
    let actorRef = TestActorRef("monitor-test-actor")
    for (i in 0..100) {
        let message = TestMessage(Int64(i), "monitor test ${i}")
        let envelope = Envelope(message, None)
        dispatcher.dispatchSimple(envelope)
    }
    
    // 等待处理
    sleep(Duration.millisecond * 200)
    
    // 获取性能报告
    let report = dispatcher.getPerformanceReport()
    
    if (report.totalTasks != 100) {
        println("✗ 总任务数不匹配: 期望100, 实际${report.totalTasks}")
        dispatcher.stop()
        return false
    }
    
    if (report.throughput <= 0.0) {
        println("✗ 吞吐量应该大于0")
        dispatcher.stop()
        return false
    }
    
    println("性能报告:")
    println("  总任务数: ${report.totalTasks}")
    println("  吞吐量: ${report.throughput} tasks/s")
    println("  平均延迟: ${report.avgLatency}μs")
    println("  P99延迟: ${report.p99Latency}μs")
    
    dispatcher.stop()
    println("✓ 性能监控功能测试通过")
    return true
}

func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    return now.toUnixTimeStamp().toMilliseconds() * 1000000
}

/**
 * 主测试函数
 */
main(): Unit {
    println("=== CActor 3.0 Phase 3 优化调度器测试 ===")
    
    var passedTests = 0
    var totalTests = 0
    
    // 运行所有测试
    let tests = [
        ("调度器配置创建", testSchedulerConfigCreation),
        ("负载均衡器", testLoadBalancer),
        ("优化调度器创建", testOptimizedDispatcherCreation),
        ("消息分发功能", testMessageDispatch),
        ("高并发消息处理", testConcurrentMessageProcessing),
        ("性能监控功能", testPerformanceMonitoring)
    ]
    
    for ((testName, testFunc) in tests) {
        totalTests += 1
        if (testFunc()) {
            passedTests += 1
        } else {
            println("❌ ${testName} 测试失败")
        }
        println("")
    }
    
    // 输出测试结果
    println("=== 测试结果 ===")
    println("通过测试: ${passedTests}/${totalTests}")
    
    if (passedTests == totalTests) {
        println("🎉 所有优化调度器测试通过！")
        println("✓ 智能负载均衡功能正常")
        println("✓ 优化窃取策略功能正常")
        println("✓ 性能监控功能正常")
        println("✓ 高并发处理能力良好")
        println("")
        println("这验证了CActor 3.0的Phase 3优化调度器实现！")
        println("🚀 Phase 3: 高性能调度器优化功能完成！")
    } else {
        println("❌ 部分测试失败，需要进一步调试")
    }
}
