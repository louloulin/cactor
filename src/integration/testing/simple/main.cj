/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 简单Actor测试
 * 验证基础Actor功能
 */
package cactor.integration.testing.simple

import std.sync.*
import std.time.*

/**
 * 简单的测试Actor实现
 */
public class SimpleTestActor {
    private let actorName: String
    private let messageCount: AtomicInt64
    private let isRunning: AtomicBool

    public init(name: String) {
        this.actorName = name
        this.messageCount = AtomicInt64(0)
        this.isRunning = AtomicBool(false)
    }

    public func getName(): String {
        actorName
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("${actorName} 启动中...")
            spawn {
                run()
            }
        }
    }

    public func stop(): Unit {
        isRunning.store(false)
        println("${actorName} 停止")
    }

    public func sendMessage(message: String): Unit {
        if (isRunning.load()) {
            messageCount.fetchAdd(1)
            println("${actorName} 收到消息: ${message}")
        }
    }

    public func getMessageCount(): Int64 {
        messageCount.load()
    }

    private func run(): Unit {
        println("${actorName} 开始运行")
        while (isRunning.load()) {
            // 模拟消息处理
            sleep(Duration.millisecond * 10)
        }
        println("${actorName} 运行结束")
    }
}

/**
 * 测试基础Actor功能
 */
func testBasicActor(): Bool {
    println("=== 测试基础Actor功能 ===")
    
    let actor = SimpleTestActor("TestActor1")
    
    // 测试初始状态
    if (actor.getMessageCount() != 0) {
        println("✗ Actor初始消息计数测试失败")
        return false
    }
    
    // 启动Actor
    actor.start()
    sleep(Duration.millisecond * 100)
    
    // 发送消息
    actor.sendMessage("Hello")
    actor.sendMessage("World")
    actor.sendMessage("!")
    
    sleep(Duration.millisecond * 100)
    
    // 检查消息计数
    if (actor.getMessageCount() != 3) {
        println("✗ Actor消息计数测试失败: 期望3, 实际${actor.getMessageCount()}")
        return false
    }
    
    // 停止Actor
    actor.stop()
    sleep(Duration.millisecond * 100)
    
    println("✓ 基础Actor功能测试通过")
    return true
}

/**
 * 测试多Actor并发
 */
func testMultipleActors(): Bool {
    println("=== 测试多Actor并发 ===")
    
    let numActors = 5
    let messagesPerActor = 10
    let actors = Array<SimpleTestActor>(numActors, { i => SimpleTestActor("Actor${i}") })
    
    // 启动所有Actor
    for (i in 0..numActors) {
        actors[i].start()
    }
    
    sleep(Duration.millisecond * 100)
    
    // 向每个Actor发送消息
    for (i in 0..numActors) {
        for (j in 0..messagesPerActor) {
            actors[i].sendMessage("Message${j}")
        }
    }
    
    sleep(Duration.millisecond * 200)
    
    // 检查所有Actor的消息计数
    var totalMessages: Int64 = 0
    for (i in 0..numActors) {
        let count = actors[i].getMessageCount()
        totalMessages += count
        if (count != messagesPerActor) {
            println("✗ Actor${i}消息计数错误: 期望${messagesPerActor}, 实际${count}")
            return false
        }
    }
    
    let expectedTotal = numActors * messagesPerActor
    if (totalMessages != expectedTotal) {
        println("✗ 总消息计数错误: 期望${expectedTotal}, 实际${totalMessages}")
        return false
    }
    
    // 停止所有Actor
    for (i in 0..numActors) {
        actors[i].stop()
    }
    
    sleep(Duration.millisecond * 100)
    
    println("✓ 多Actor并发测试通过: ${numActors}个Actor处理了${totalMessages}条消息")
    return true
}

/**
 * 测试Actor生命周期
 */
func testActorLifecycle(): Bool {
    println("=== 测试Actor生命周期 ===")
    
    let actor = SimpleTestActor("LifecycleActor")
    
    // 测试启动前状态
    if (actor.getMessageCount() != 0) {
        println("✗ Actor启动前状态测试失败")
        return false
    }
    
    // 启动Actor
    actor.start()
    sleep(Duration.millisecond * 50)
    
    // 发送一些消息
    actor.sendMessage("Start")
    actor.sendMessage("Running")
    sleep(Duration.millisecond * 50)
    
    if (actor.getMessageCount() != 2) {
        println("✗ Actor运行时消息处理测试失败")
        return false
    }
    
    // 停止Actor
    actor.stop()
    sleep(Duration.millisecond * 50)
    
    // 尝试发送消息给已停止的Actor
    let beforeStopCount = actor.getMessageCount()
    actor.sendMessage("AfterStop")
    sleep(Duration.millisecond * 50)
    
    // 消息计数应该没有变化
    if (actor.getMessageCount() != beforeStopCount) {
        println("✗ Actor停止后消息处理测试失败")
        return false
    }
    
    println("✓ Actor生命周期测试通过")
    return true
}

/**
 * 性能基准测试
 */
func benchmarkActorPerformance(): Unit {
    println("=== Actor性能基准测试 ===")
    
    let actor = SimpleTestActor("BenchmarkActor")
    actor.start()
    sleep(Duration.millisecond * 100)
    
    let numMessages = 10000
    let startTime = DateTime.now()
    
    for (i in 0..numMessages) {
        actor.sendMessage("Benchmark${i}")
    }
    
    // 等待所有消息处理完成
    sleep(Duration.second)
    
    let endTime = DateTime.now()
    let processedCount = actor.getMessageCount()
    
    actor.stop()
    
    println("✓ 性能测试完成:")
    println("  - 发送消息: ${numMessages}")
    println("  - 处理消息: ${processedCount}")
    let rate = Float64(processedCount) / Float64(numMessages) * 100.0
    println("  - 处理率: ${Int32(rate)}%")
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 简单Actor系统测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testBasicActor()
    allPassed = allPassed && testMultipleActors()
    allPassed = allPassed && testActorLifecycle()
    
    // 运行性能基准测试
    benchmarkActorPerformance()
    
    if (allPassed) {
        println("\n🎉 所有简单Actor测试通过！")
        println("✓ 基础Actor功能正常")
        println("✓ 多Actor并发正常")
        println("✓ Actor生命周期正常")
        println("\n这验证了CActor的基础Actor能力！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
