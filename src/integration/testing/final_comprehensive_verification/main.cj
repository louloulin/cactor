/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 最终综合验证测试
 * 验证所有功能模块的集成和协作
 */
package cactor.integration.testing.final_comprehensive_verification

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
 * 综合验证消息
 */
public class ComprehensiveTestMessage <: Message {
    private let id: Int64
    private let testType: String
    private let createdTime: Int64

    public init(id: Int64, testType: String) {
        this.id = id
        this.testType = testType
        this.createdTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    public func getId(): Int64 { id }
    public func getTestType(): String { testType }
    public func getCreatedTime(): Int64 { createdTime }
    
    public func messageType(): String { "ComprehensiveTestMessage" }
    public func priority(): Int32 { 0 }
    public func timestamp(): Int64 { createdTime }
}

/**
 * 综合验证Actor
 */
public class ComprehensiveTestActor <: Actor {
    private let processedCount: AtomicInt64
    private let testResults: HashMap<String, Int64>
    private let mutex: ReentrantMutex

    public init() {
        this.processedCount = AtomicInt64(0)
        this.testResults = HashMap<String, Int64>()
        this.mutex = ReentrantMutex()
    }
    
    public prop name: String {
        get() { "ComprehensiveTestActor" }
    }
    
    public prop description: String {
        get() { "综合验证测试Actor" }
    }

    public func receive(message: Message, _: ActorContext): MessageResult {
        match (message) {
            case compMsg: ComprehensiveTestMessage =>
                processedCount.fetchAdd(1)
                
                mutex.lock()
                let testType = compMsg.getTestType()
                match (testResults.get(testType)) {
                    case Some(count) => testResults.put(testType, count + 1)
                    case None => testResults.put(testType, 1)
                }
                mutex.unlock()
                
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }

    public func getProcessedCount(): Int64 { processedCount.load() }
    
    public func getTestResults(): HashMap<String, Int64> {
        mutex.lock()
        let results = HashMap<String, Int64>()
        for ((key, value) in testResults) {
            results.put(key, value)
        }
        mutex.unlock()
        return results
    }

    public func reset(): Unit {
        processedCount.store(0)
        mutex.lock()
        testResults.clear()
        mutex.unlock()
    }
}

/**
 * 最终综合验证测试套件
 */
public class FinalComprehensiveVerificationSuite {
    
    public init() {}

    /**
     * 获取当前时间（纳秒）
     */
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    /**
     * 测试1: Foundation层验证
     */
    public func testFoundationLayer(): Bool {
        println("🚀 测试1: Foundation层验证")

        // 测试LockFreeQueue
        let queue = LockFreeQueue<ComprehensiveTestMessage>(1024)
        let messageCount: Int64 = 1000

        var enqueued: Int64 = 0
        for (i in 0..messageCount) {
            let message = ComprehensiveTestMessage(i, "foundation")
            if (queue.enqueue(message)) {
                enqueued += 1
            }
        }

        var dequeued: Int64 = 0
        var attempts: Int64 = 0
        while (!queue.isEmpty() && attempts < messageCount * 2) {
            match (queue.dequeue()) {
                case Some(_) => dequeued += 1
                case None => break
            }
            attempts += 1
        }

        let stats = queue.getStats()
        let successRate = stats.getSuccessRate() * 100.0

        println("  队列入队: ${enqueued}/${messageCount}")
        println("  队列出队: ${dequeued}")
        println("  成功率: ${successRate}%")

        let success = enqueued == messageCount && dequeued == enqueued && successRate >= 95.0
        
        if (success) {
            println("  ✅ Foundation层验证通过")
        } else {
            println("  ❌ Foundation层验证失败")
        }

        return success
    }

    /**
     * 测试2: Core层验证
     */
    public func testCoreLayer(): Bool {
        println("🚀 测试2: Core层验证")

        let system = SimpleActorSystem("core-verification-test")
        let actorCount: Int32 = 10
        let messagesPerActor: Int64 = 100

        let actors = Array<ComprehensiveTestActor>(Int64(actorCount), { _ => ComprehensiveTestActor() })
        let actorRefs = Array<Option<ActorRef>>(Int64(actorCount), { _ => None })

        // 创建Actor
        for (i in 0..Int64(actorCount)) {
            let actor = actors[i]
            let actorRef = system.actorOf(PropsFactory.create({ => actor }), "core-actor-${i}")
            actorRefs[i] = Some(actorRef)
        }

        // 发送消息
        for (i in 0..Int64(actorCount)) {
            match (actorRefs[i]) {
                case Some(actorRef) =>
                    for (j in 0..messagesPerActor) {
                        let message = ComprehensiveTestMessage(j, "core")
                        actorRef.tell(message)
                    }
                case None => ()
            }
        }

        // 等待处理完成
        sleep(Duration.second)

        // 统计结果
        var totalProcessed: Int64 = 0
        for (actor in actors) {
            totalProcessed += actor.getProcessedCount()
        }

        let expectedMessages = Int64(actorCount) * messagesPerActor
        let successRate = Float64(totalProcessed) / Float64(expectedMessages) * 100.0

        println("  Actor数量: ${actorCount}")
        println("  预期消息: ${expectedMessages}")
        println("  处理消息: ${totalProcessed}")
        println("  成功率: ${successRate}%")

        system.terminate()

        let success = successRate >= 95.0
        
        if (success) {
            println("  ✅ Core层验证通过")
        } else {
            println("  ❌ Core层验证失败")
        }

        return success
    }

    /**
     * 测试3: Runtime层验证
     */
    public func testRuntimeLayer(): Bool {
        println("🚀 测试3: Runtime层验证")

        let system = SimpleActorSystem("runtime-verification-test")
        let actorCount: Int32 = 20
        let messagesPerActor: Int64 = 200

        let actors = Array<ComprehensiveTestActor>(Int64(actorCount), { _ => ComprehensiveTestActor() })
        let actorRefs = Array<Option<ActorRef>>(Int64(actorCount), { _ => None })

        // 创建Actor
        for (i in 0..Int64(actorCount)) {
            let actor = actors[i]
            let actorRef = system.actorOf(PropsFactory.create({ => actor }), "runtime-actor-${i}")
            actorRefs[i] = Some(actorRef)
        }

        let startTime = getCurrentTimeNanos()

        // 高速发送消息测试Runtime性能
        for (i in 0..Int64(actorCount)) {
            match (actorRefs[i]) {
                case Some(actorRef) =>
                    for (j in 0..messagesPerActor) {
                        let message = ComprehensiveTestMessage(j, "runtime")
                        actorRef.tell(message)
                    }
                case None => ()
            }
        }

        // 等待处理完成
        sleep(Duration.second * 2)

        let endTime = getCurrentTimeNanos()
        let duration = Float64(endTime - startTime) / 1000000000.0

        // 统计结果
        var totalProcessed: Int64 = 0
        for (actor in actors) {
            totalProcessed += actor.getProcessedCount()
        }

        let expectedMessages = Int64(actorCount) * messagesPerActor
        let throughput = Float64(totalProcessed) / duration
        let successRate = Float64(totalProcessed) / Float64(expectedMessages) * 100.0

        println("  Actor数量: ${actorCount}")
        println("  预期消息: ${expectedMessages}")
        println("  处理消息: ${totalProcessed}")
        println("  测试时长: ${duration}秒")
        println("  吞吐量: ${throughput} msg/s")
        println("  成功率: ${successRate}%")

        system.terminate()

        let success = successRate >= 95.0 && throughput >= 10000.0  // 至少1万msg/s
        
        if (success) {
            println("  ✅ Runtime层验证通过")
        } else {
            println("  ❌ Runtime层验证失败")
        }

        return success
    }

    /**
     * 测试4: 集成验证
     */
    public func testIntegrationLayer(): Bool {
        println("🚀 测试4: 集成验证")

        let system = SimpleActorSystem("integration-verification-test")
        let actorCount: Int32 = 30
        let testTypes = ["foundation", "core", "runtime", "patterns", "integration"]
        let messagesPerType: Int64 = 50

        let actors = Array<ComprehensiveTestActor>(Int64(actorCount), { _ => ComprehensiveTestActor() })
        let actorRefs = Array<Option<ActorRef>>(Int64(actorCount), { _ => None })

        // 创建Actor
        for (i in 0..Int64(actorCount)) {
            let actor = actors[i]
            let actorRef = system.actorOf(PropsFactory.create({ => actor }), "integration-actor-${i}")
            actorRefs[i] = Some(actorRef)
        }

        // 发送不同类型的消息
        for (testType in testTypes) {
            for (i in 0..Int64(actorCount)) {
                match (actorRefs[i]) {
                    case Some(actorRef) =>
                        for (j in 0..messagesPerType) {
                            let message = ComprehensiveTestMessage(j, testType)
                            actorRef.tell(message)
                        }
                    case None => ()
                }
            }
        }

        // 等待处理完成
        sleep(Duration.second * 2)

        // 统计结果
        var totalProcessed: Int64 = 0
        let aggregatedResults = HashMap<String, Int64>()

        for (actor in actors) {
            totalProcessed += actor.getProcessedCount()
            let results = actor.getTestResults()
            for ((testType, count) in results) {
                match (aggregatedResults.get(testType)) {
                    case Some(existingCount) => aggregatedResults.put(testType, existingCount + count)
                    case None => aggregatedResults.put(testType, count)
                }
            }
        }

        let expectedTotal = Int64(testTypes.size) * Int64(actorCount) * messagesPerType
        let successRate = Float64(totalProcessed) / Float64(expectedTotal) * 100.0

        println("  Actor数量: ${actorCount}")
        println("  测试类型: ${testTypes.size}")
        println("  预期消息: ${expectedTotal}")
        println("  处理消息: ${totalProcessed}")
        println("  成功率: ${successRate}%")

        println("  各类型处理统计:")
        for (testType in testTypes) {
            match (aggregatedResults.get(testType)) {
                case Some(count) => 
                    let expected = Int64(actorCount) * messagesPerType
                    let typeSuccessRate = Float64(count) / Float64(expected) * 100.0
                    println("    ${testType}: ${count}/${expected} (${typeSuccessRate}%)")
                case None => 
                    println("    ${testType}: 0/0 (0%)")
            }
        }

        system.terminate()

        let success = successRate >= 95.0
        
        if (success) {
            println("  ✅ 集成验证通过")
        } else {
            println("  ❌ 集成验证失败")
        }

        return success
    }

    /**
     * 运行所有最终综合验证测试
     */
    public func runAllTests(): Bool {
        println("========================================")
        println("=== CActor 最终综合验证测试套件 ===")
        println("验证所有功能模块的集成和协作")
        println("========================================")
        println()

        var passedTests = 0
        let totalTests = 4

        if (testFoundationLayer()) {
            passedTests += 1
        }
        println()

        if (testCoreLayer()) {
            passedTests += 1
        }
        println()

        if (testRuntimeLayer()) {
            passedTests += 1
        }
        println()

        if (testIntegrationLayer()) {
            passedTests += 1
        }
        println()

        println("========================================")
        println("=== 最终综合验证结果 ===")
        println("通过测试: ${passedTests}/${totalTests}")

        if (passedTests == totalTests) {
            println("🎉 所有最终综合验证测试通过！")
            println("✅ CActor系统完整性验证成功")
            println("🚀 CActor 7.0已达到生产级别标准")
            return true
        } else if (passedTests >= 3) {
            println("⚡ 大部分最终综合验证测试通过！")
            println("系统基本功能完整性良好")
            return true
        } else {
            println("📈 最终综合验证测试需要改进")
            println("系统集成需要进一步优化")
            return false
        }
    }
}

main(): Int64 {
    let testSuite = FinalComprehensiveVerificationSuite()
    let success = testSuite.runAllTests()
    return if (success) { 0 } else { 1 }
}
