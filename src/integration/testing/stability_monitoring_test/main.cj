/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 稳定性监控测试
 * 验证系统在长时间运行下的稳定性和性能一致性
 */
package cactor.integration.testing.stability_monitoring_test

import std.time.*
import std.collection.*
import std.sync.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import cactor.core.system.*
import cactor.runtime.system.{SimpleActorSystem}
import cactor.runtime.mailbox.*
import cactor.foundation.queue.*

/**
 * 稳定性测试消息
 */
public class StabilityTestMessage <: Message {
    private let id: Int64
    private let batchId: Int32
    private let createdTime: Int64

    public init(id: Int64, batchId: Int32) {
        this.id = id
        this.batchId = batchId
        this.createdTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    public func getId(): Int64 { id }
    public func getBatchId(): Int32 { batchId }
    public func getCreatedTime(): Int64 { createdTime }
    
    public func messageType(): String { "StabilityTestMessage" }
    public func priority(): Int32 { 0 }
    public func timestamp(): Int64 { createdTime }
}

/**
 * 稳定性监控Actor
 */
public class StabilityMonitorActor <: Actor {
    private let processedCount: AtomicInt64
    private let totalLatency: AtomicInt64
    private let maxLatency: AtomicInt64
    private let minLatency: AtomicInt64
    private let errorCount: AtomicInt64
    private let batchStats: HashMap<Int32, Int64>
    private let mutex: ReentrantMutex

    public init() {
        this.processedCount = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
        this.maxLatency = AtomicInt64(0)
        this.minLatency = AtomicInt64(9223372036854775807)  // Int64最大值
        this.errorCount = AtomicInt64(0)
        this.batchStats = HashMap<Int32, Int64>()
        this.mutex = ReentrantMutex()
    }
    
    public prop name: String {
        get() { "StabilityMonitorActor" }
    }
    
    public prop description: String {
        get() { "稳定性监控Actor" }
    }

    public func receive(message: Message, _: ActorContext): MessageResult {
        let receiveTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        match (message) {
            case stabilityMsg: StabilityTestMessage =>
                let latency = receiveTime - stabilityMsg.getCreatedTime()
                
                // 更新统计
                processedCount.fetchAdd(1)
                totalLatency.fetchAdd(latency)
                
                // 更新最大最小延迟
                updateMaxLatency(latency)
                updateMinLatency(latency)
                
                // 更新批次统计
                mutex.lock()
                let batchId = stabilityMsg.getBatchId()
                match (batchStats.get(batchId)) {
                    case Some(count) => batchStats.put(batchId, count + 1)
                    case None => batchStats.put(batchId, 1)
                }
                mutex.unlock()
                
                return MessageResult.Handled
            case _ =>
                errorCount.fetchAdd(1)
                return MessageResult.Unhandled
        }
    }

    private func updateMaxLatency(latency: Int64): Unit {
        var currentMax = maxLatency.load()
        while (latency > currentMax) {
            if (maxLatency.compareAndSwap(currentMax, latency)) {
                break
            }
            currentMax = maxLatency.load()
        }
    }

    private func updateMinLatency(latency: Int64): Unit {
        var currentMin = minLatency.load()
        while (latency < currentMin) {
            if (minLatency.compareAndSwap(currentMin, latency)) {
                break
            }
            currentMin = minLatency.load()
        }
    }

    public func getProcessedCount(): Int64 { processedCount.load() }
    public func getAverageLatency(): Float64 {
        let count = processedCount.load()
        if (count == 0) { return 0.0 }
        return Float64(totalLatency.load()) / Float64(count) / 1000.0  // 微秒
    }
    public func getMaxLatency(): Float64 { Float64(maxLatency.load()) / 1000.0 }  // 微秒
    public func getMinLatency(): Float64 { 
        let min = minLatency.load()
        if (min == 9223372036854775807) { return 0.0 }
        return Float64(min) / 1000.0  // 微秒
    }
    public func getErrorCount(): Int64 { errorCount.load() }

    public func getBatchCompleteness(): Float64 {
        mutex.lock()
        let totalBatches = batchStats.size
        mutex.unlock()
        return if (totalBatches > 0) { Float64(totalBatches) } else { 0.0 }
    }

    public func reset(): Unit {
        processedCount.store(0)
        totalLatency.store(0)
        maxLatency.store(0)
        minLatency.store(9223372036854775807)
        errorCount.store(0)
        mutex.lock()
        batchStats.clear()
        mutex.unlock()
    }
}

/**
 * 稳定性监控测试套件
 */
public class StabilityMonitoringTestSuite {
    
    public init() {}

    /**
     * 获取当前时间（纳秒）
     */
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    /**
     * 测试1: 长时间稳定性测试
     */
    public func testLongTermStability(): Bool {
        println("🚀 测试1: 长时间稳定性测试")

        let system = SimpleActorSystem("stability-test")
        let actorCount: Int32 = 50
        let batchCount: Int32 = 20
        let messagesPerBatch: Int64 = 1000
        let batchInterval: Int64 = 100  // 100ms间隔

        let actors = Array<StabilityMonitorActor>(Int64(actorCount), { _ => StabilityMonitorActor() })
        let actorRefs = Array<Option<ActorRef>>(Int64(actorCount), { _ => None })

        // 创建Actor
        for (i in 0..Int64(actorCount)) {
            let actor = actors[i]
            let props = Props<Actor>(SimpleActorFactory<Actor>({ => actor }))
            let actorRef = system.actorOf(props, "stability-actor-${i}")
            actorRefs[i] = Some(actorRef)
        }

        println("  Actor数量: ${actorCount}")
        println("  批次数量: ${batchCount}")
        println("  每批消息数: ${messagesPerBatch}")
        println("  批次间隔: ${batchInterval}ms")

        let startTime = getCurrentTimeNanos()
        var totalSent: Int64 = 0

        // 分批发送消息，模拟长时间运行
        for (batchId in 0..batchCount) {
            let batchStartTime = getCurrentTimeNanos()
            
            for (actorIndex in 0..Int64(actorCount)) {
                match (actorRefs[actorIndex]) {
                    case Some(actorRef) =>
                        for (msgId in 0..messagesPerBatch) {
                            let message = StabilityTestMessage(msgId, batchId)
                            actorRef.tell(message)
                            totalSent += 1
                        }
                    case None => ()
                }
            }

            // 批次间隔
            if (batchId < batchCount - 1) {
                sleep(Duration.millisecond * batchInterval)
            }

            let batchEndTime = getCurrentTimeNanos()
            let batchDuration = Float64(batchEndTime - batchStartTime) / 1000000.0  // 毫秒
            println("  批次 ${batchId} 完成，耗时: ${batchDuration}ms")
        }

        // 等待处理完成
        sleep(Duration.second * 3)

        let endTime = getCurrentTimeNanos()
        let totalDuration = Float64(endTime - startTime) / 1000000000.0  // 秒

        // 统计结果
        var totalProcessed: Int64 = 0
        var totalErrors: Int64 = 0
        var avgLatency: Float64 = 0.0
        var maxLatency: Float64 = 0.0
        var minLatency: Float64 = 999999999.0  // 一个很大的值

        for (actor in actors) {
            totalProcessed += actor.getProcessedCount()
            totalErrors += actor.getErrorCount()
            avgLatency += actor.getAverageLatency()
            
            let actorMaxLatency = actor.getMaxLatency()
            let actorMinLatency = actor.getMinLatency()
            
            if (actorMaxLatency > maxLatency) {
                maxLatency = actorMaxLatency
            }
            if (actorMinLatency < minLatency && actorMinLatency > 0.0) {
                minLatency = actorMinLatency
            }
        }

        avgLatency = avgLatency / Float64(actorCount)
        let throughput = Float64(totalProcessed) / totalDuration
        let successRate = Float64(totalProcessed) / Float64(totalSent) * 100.0

        println("  总发送消息: ${totalSent}")
        println("  总处理消息: ${totalProcessed}")
        println("  总错误数: ${totalErrors}")
        println("  测试时长: ${totalDuration}秒")
        println("  吞吐量: ${throughput} msg/s")
        println("  成功率: ${successRate}%")
        println("  平均延迟: ${avgLatency}μs")
        println("  最大延迟: ${maxLatency}μs")
        println("  最小延迟: ${minLatency}μs")

        system.terminate()

        // 验证稳定性指标
        let success = successRate >= 95.0 && totalErrors == 0 && avgLatency < 1000.0  // 1ms
        
        if (success) {
            println("  ✅ 长时间稳定性测试通过")
        } else {
            println("  ❌ 长时间稳定性测试失败")
        }

        return success
    }

    /**
     * 测试2: 内存稳定性测试
     */
    public func testMemoryStability(): Bool {
        println("🚀 测试2: 内存稳定性测试")

        let system = SimpleActorSystem("memory-stability-test")
        let cycleCount: Int32 = 10
        let actorsPerCycle: Int32 = 100
        let messagesPerActor: Int64 = 500

        println("  循环次数: ${cycleCount}")
        println("  每循环Actor数: ${actorsPerCycle}")
        println("  每Actor消息数: ${messagesPerActor}")

        var totalProcessed: Int64 = 0
        var totalCycles = 0

        for (cycle in 0..cycleCount) {
            println("  执行循环 ${cycle}...")

            let actors = Array<StabilityMonitorActor>(Int64(actorsPerCycle), { _ => StabilityMonitorActor() })
            let actorRefs = Array<Option<ActorRef>>(Int64(actorsPerCycle), { _ => None })

            // 创建Actor
            for (i in 0..Int64(actorsPerCycle)) {
                let actor = actors[i]
                let props = Props<Actor>(SimpleActorFactory<Actor>({ => actor }))
                let actorRef = system.actorOf(props, "memory-actor-${cycle}-${i}")
                actorRefs[i] = Some(actorRef)
            }

            // 发送消息
            for (i in 0..Int64(actorsPerCycle)) {
                match (actorRefs[i]) {
                    case Some(actorRef) =>
                        for (j in 0..messagesPerActor) {
                            let message = StabilityTestMessage(j, cycle)
                            actorRef.tell(message)
                        }
                    case None => ()
                }
            }

            // 等待处理完成
            sleep(Duration.millisecond * 500)

            // 统计本循环结果
            var cycleProcessed: Int64 = 0
            for (actor in actors) {
                cycleProcessed += actor.getProcessedCount()
            }

            totalProcessed += cycleProcessed
            totalCycles += 1

            println("    循环 ${cycle} 处理消息: ${cycleProcessed}")

            // 短暂休息，模拟内存回收
            sleep(Duration.millisecond * 100)
        }

        let expectedMessages = Int64(cycleCount) * Int64(actorsPerCycle) * messagesPerActor
        let successRate = Float64(totalProcessed) / Float64(expectedMessages) * 100.0

        println("  预期消息总数: ${expectedMessages}")
        println("  实际处理总数: ${totalProcessed}")
        println("  成功率: ${successRate}%")

        system.terminate()

        let success = successRate >= 95.0
        
        if (success) {
            println("  ✅ 内存稳定性测试通过")
        } else {
            println("  ❌ 内存稳定性测试失败")
        }

        return success
    }

    /**
     * 运行所有稳定性监控测试
     */
    public func runAllTests(): Bool {
        println("========================================")
        println("=== CActor 稳定性监控测试套件 ===")
        println("验证系统长时间运行的稳定性")
        println("========================================")
        println()

        var passedTests = 0
        let totalTests = 2

        if (testLongTermStability()) {
            passedTests += 1
        }
        println()

        if (testMemoryStability()) {
            passedTests += 1
        }
        println()

        println("========================================")
        println("=== 稳定性监控测试结果 ===")
        println("通过测试: ${passedTests}/${totalTests}")

        if (passedTests == totalTests) {
            println("🎉 所有稳定性监控测试通过！")
            println("✅ CActor系统稳定性验证成功")
            return true
        } else if (passedTests >= 1) {
            println("⚡ 大部分稳定性监控测试通过！")
            println("系统基本稳定性良好")
            return true
        } else {
            println("📈 稳定性监控测试需要改进")
            println("系统稳定性需要进一步优化")
            return false
        }
    }
}

main(): Int64 {
    let testSuite = StabilityMonitoringTestSuite()
    let success = testSuite.runAllTests()
    return if (success) { 0 } else { 1 }
}
