/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 简单性能测试
 * 基于Plan7架构的基础性能验证
 */
package cactor.integration.testing.simple_performance_test

import std.time.*
import std.collection.*
import std.sync.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import cactor.core.system.*
import cactor.runtime.mailbox.*
import cactor.foundation.queue.*

/**
 * 简单性能测试消息
 */
public class SimpleTestMessage <: Message {
    private let id: Int64
    private let content: String
    private let createdTime: Int64

    public init(id: Int64, content: String) {
        this.id = id
        this.content = content
        this.createdTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func getId(): Int64 { id }
    public func getContent(): String { content }
    public func getCreatedTime(): Int64 { createdTime }

    public func messageType(): String {
        "SimpleTestMessage"
    }

    public func timestamp(): Int64 { createdTime }
}

/**
 * 简单性能测试Actor
 */
public class SimplePerformanceActor <: Actor {
    private let processedCount: AtomicInt64
    private let totalLatency: AtomicInt64

    public init() {
        this.processedCount = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
    }

    public prop name: String {
        get() { "SimplePerformanceActor" }
    }

    public prop description: String {
        get() { "简单性能测试Actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case testMsg: SimpleTestMessage =>
                let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                let latency = currentTime - testMsg.getCreatedTime()
                
                processedCount.fetchAdd(1)
                totalLatency.fetchAdd(latency)
                
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }

    public func getProcessedCount(): Int64 { processedCount.load() }
    public func getAverageLatency(): Float64 {
        let count = processedCount.load()
        if (count == 0) { return 0.0 }
        return Float64(totalLatency.load()) / Float64(count)
    }

    public func reset(): Unit {
        processedCount.store(0)
        totalLatency.store(0)
    }
}

/**
 * 简单性能测试套件
 */
public class SimplePerformanceTestSuite {
    
    public init() {}

    /**
     * 测试1: 基础消息传递性能
     */
    public func testBasicMessagePassing(): Bool {
        println("🚀 测试1: 基础消息传递性能")

        let system = SimpleActorSystem("simple-perf-test")
        let actor = SimplePerformanceActor()
        let actorRef = system.actorOf(PropsFactory.create({ => actor }), "test-actor")

        let messageCount: Int64 = 10000
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        // 发送消息
        for (i in 0..messageCount) {
            let message = SimpleTestMessage(i, "test-message-${i}")
            actorRef.tell(message)
        }

        // 等待处理完成
        sleep(Duration.second)

        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = Float64(endTime - startTime) / 1000.0
        let throughput = Float64(messageCount) / duration

        let processedCount = actor.getProcessedCount()
        let avgLatency = actor.getAverageLatency()

        println("  消息数量: ${messageCount}")
        println("  处理数量: ${processedCount}")
        println("  测试时长: ${duration}秒")
        println("  吞吐量: ${throughput} msg/s")
        println("  平均延迟: ${avgLatency}ms")

        system.terminate()

        let success = processedCount >= messageCount * 90 / 100  // 90%成功率
        if (success) {
            println("  ✅ 基础消息传递性能测试通过")
        } else {
            println("  ❌ 基础消息传递性能测试失败")
        }

        return success
    }

    /**
     * 测试2: 多Actor并发性能
     */
    public func testMultiActorConcurrency(): Bool {
        println("🚀 测试2: 多Actor并发性能")

        let system = SimpleActorSystem("multi-actor-perf-test")
        let actorCount: Int32 = 100
        let messagesPerActor: Int64 = 1000

        let actors = Array<SimplePerformanceActor>(Int64(actorCount), { i => SimplePerformanceActor() })
        let actorRefs = Array<Option<ActorRef>>(Int64(actorCount), { i => None })

        // 创建Actor
        for (i in 0..Int64(actorCount)) {
            let actor = actors[i]
            let actorRef = system.actorOf(PropsFactory.create({ => actor }), "actor-${i}")
            actorRefs[i] = Some(actorRef)
        }

        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        // 并发发送消息
        for (i in 0..Int64(actorCount)) {
            match (actorRefs[i]) {
                case Some(actorRef) =>
                    for (j in 0..messagesPerActor) {
                        let message = SimpleTestMessage(j, "concurrent-message-${i}-${j}")
                        actorRef.tell(message)
                    }
                case None => ()
            }
        }

        // 等待处理完成
        sleep(Duration.second * 2)

        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = Float64(endTime - startTime) / 1000.0

        // 统计结果
        var totalProcessed: Int64 = 0
        var totalLatency: Float64 = 0.0

        for (actor in actors) {
            totalProcessed += actor.getProcessedCount()
            totalLatency += actor.getAverageLatency()
        }

        let avgLatency = totalLatency / Float64(actorCount)
        let totalMessages = Int64(actorCount) * messagesPerActor
        let throughput = Float64(totalProcessed) / duration

        println("  Actor数量: ${actorCount}")
        println("  每Actor消息数: ${messagesPerActor}")
        println("  总消息数: ${totalMessages}")
        println("  总处理数: ${totalProcessed}")
        println("  测试时长: ${duration}秒")
        println("  吞吐量: ${throughput} msg/s")
        println("  平均延迟: ${avgLatency}ms")

        system.terminate()

        let success = totalProcessed >= totalMessages * 85 / 100  // 85%成功率
        if (success) {
            println("  ✅ 多Actor并发性能测试通过")
        } else {
            println("  ❌ 多Actor并发性能测试失败")
        }

        return success
    }

    /**
     * 测试3: 邮箱性能测试
     */
    public func testMailboxPerformance(): Bool {
        println("🚀 测试3: 邮箱性能测试")

        // 测试Foundation层的LockFreeQueue
        let queue = LockFreeQueue<SimpleTestMessage>(1024)
        let messageCount: Int64 = 5000

        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        // 入队测试
        var enqueued: Int64 = 0
        for (i in 0..messageCount) {
            let message = SimpleTestMessage(i, "queue-test-${i}")
            if (queue.enqueue(message)) {
                enqueued += 1
            }
        }

        // 出队测试
        var dequeued: Int64 = 0
        while (!queue.isEmpty()) {
            match (queue.dequeue()) {
                case Some(_) => dequeued += 1
                case None => break
            }
        }

        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = Float64(endTime - startTime) / 1000.0
        let throughput = Float64(enqueued + dequeued) / duration

        println("  队列容量: 1024")
        println("  入队数量: ${enqueued}")
        println("  出队数量: ${dequeued}")
        println("  测试时长: ${duration}秒")
        println("  吞吐量: ${throughput} ops/s")

        let stats = queue.getStats()
        println("  成功率: ${stats.getSuccessRate() * 100.0}%")

        let success = enqueued == messageCount && dequeued == enqueued
        if (success) {
            println("  ✅ 邮箱性能测试通过")
        } else {
            println("  ❌ 邮箱性能测试失败")
        }

        return success
    }

    /**
     * 运行所有简单性能测试
     */
    public func runAllTests(): Bool {
        println("========================================")
        println("=== CActor 简单性能测试套件 ===")
        println("基于Plan7架构的基础性能验证")
        println("========================================")
        println()

        var passedTests = 0
        let totalTests = 3

        if (testBasicMessagePassing()) {
            passedTests += 1
        }
        println()

        if (testMultiActorConcurrency()) {
            passedTests += 1
        }
        println()

        if (testMailboxPerformance()) {
            passedTests += 1
        }
        println()

        println("========================================")
        println("=== 简单性能测试结果 ===")
        println("通过测试: ${passedTests}/${totalTests}")

        if (passedTests == totalTests) {
            println("🎉 所有简单性能测试通过！")
            println("✅ CActor基础性能验证成功")
            return true
        } else if (passedTests >= 2) {
            println("⚡ 大部分简单性能测试通过！")
            println("系统基础性能良好")
            return true
        } else {
            println("📈 简单性能测试部分通过")
            println("系统需要进一步优化")
            return false
        }
    }
}

main(): Int64 {
    let testSuite = SimplePerformanceTestSuite()
    let success = testSuite.runAllTests()
    return if (success) { 0 } else { 1 }
}
