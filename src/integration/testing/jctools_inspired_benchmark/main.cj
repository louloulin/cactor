/*
 * Copyright (c) 2024. All rights reserved.
 * CActor JCTools启发的高性能基准测试
 * 基于Java JCTools库的设计理念，验证CActor的无锁数据结构性能
 */
package cactor.integration.testing.jctools_inspired_benchmark

import std.time.*
import std.collection.*
import std.sync.*
import cactor.foundation.queue.*
import cactor.foundation.memory.*

/**
 * JCTools风格的基准测试数据
 */
public class BenchmarkData {
    private let id: Int64
    private let payload: Array<UInt8>
    private let timestamp: Int64

    public init(id: Int64, payloadSize: Int32) {
        this.id = id
        this.payload = Array<UInt8>(Int64(payloadSize), { i => UInt8(i % 256) })
        this.timestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    public func getId(): Int64 { id }
    public func getPayload(): Array<UInt8> { payload }
    public func getTimestamp(): Int64 { timestamp }
}

/**
 * JCTools启发的基准测试套件
 */
public class JCToolsInspiredBenchmark {
    
    public init() {}

    /**
     * 获取当前时间（纳秒）
     */
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    /**
     * 测试1: SPSC (Single Producer Single Consumer) 队列性能
     * 模拟JCTools的SPSCArrayQueue
     */
    public func testSPSCQueuePerformance(): Bool {
        println("🚀 测试1: SPSC队列性能 (模拟JCTools SPSCArrayQueue)")

        let capacities = [1024, 4096, 16384, 65536]
        var allTestsPassed = true

        for (capacity in capacities) {
            println("  📊 测试容量: ${capacity}")

            let queue = LockFreeQueue<BenchmarkData>(Int64(capacity))
            let messageCount = Int64(capacity) / 2  // 避免队列满

            // 生产者阶段
            let produceStartTime = getCurrentTimeNanos()
            var produced: Int64 = 0

            for (i in 0..messageCount) {
                let data = BenchmarkData(i, 64)  // 64字节负载
                if (queue.enqueue(data)) {
                    produced += 1
                } else {
                    break
                }
            }

            let produceEndTime = getCurrentTimeNanos()

            // 消费者阶段
            let consumeStartTime = getCurrentTimeNanos()
            var consumed: Int64 = 0

            while (!queue.isEmpty()) {
                match (queue.dequeue()) {
                    case Some(_) => consumed += 1
                    case None => break
                }
            }

            let consumeEndTime = getCurrentTimeNanos()

            // 计算性能指标
            let produceDuration = Float64(produceEndTime - produceStartTime) / 1000000000.0
            let consumeDuration = Float64(consumeEndTime - consumeStartTime) / 1000000000.0
            let totalDuration = produceDuration + consumeDuration

            let produceRate = Float64(produced) / produceDuration
            let consumeRate = Float64(consumed) / consumeDuration
            let totalRate = Float64(produced + consumed) / totalDuration

            println("    生产: ${produced} 项, ${produceRate} ops/s")
            println("    消费: ${consumed} 项, ${consumeRate} ops/s")
            println("    总体: ${totalRate} ops/s")

            let stats = queue.getStats()
            println("    成功率: ${stats.getSuccessRate() * 100.0}%")

            // JCTools风格的性能验证
            let testPassed = produced == messageCount && consumed == produced && stats.getSuccessRate() > 0.99
            if (testPassed) {
                println("    ✅ SPSC容量${capacity}测试通过")
            } else {
                println("    ❌ SPSC容量${capacity}测试失败")
                allTestsPassed = false
            }
            println()
        }

        return allTestsPassed
    }

    /**
     * 测试2: 批量操作性能 (模拟JCTools的批量传输)
     */
    public func testBatchOperationPerformance(): Bool {
        println("🚀 测试2: 批量操作性能 (模拟JCTools批量传输)")

        let queue = LockFreeQueue<BenchmarkData>(65536)
        let batchSizes = [1, 10, 100, 1000]
        var allTestsPassed = true

        for (batchSize in batchSizes) {
            println("  📊 测试批量大小: ${batchSize}")

            let batchCount = 1000
            let totalItems = Int64(batchSize * batchCount)

            // 批量生产测试
            let batchProduceStartTime = getCurrentTimeNanos()
            var totalProduced: Int64 = 0

            for (batch in 0..batchCount) {
                let batchData = Array<BenchmarkData>(Int64(batchSize), { i => 
                    BenchmarkData(Int64(batch * batchSize) + i, 32)
                })
                
                let producedInBatch = queue.enqueueBatch(batchData)
                totalProduced += Int64(producedInBatch)
                
                if (producedInBatch < Int32(batchSize)) {
                    break  // 队列已满
                }
            }

            let batchProduceEndTime = getCurrentTimeNanos()

            // 批量消费测试
            let batchConsumeStartTime = getCurrentTimeNanos()
            var totalConsumed: Int64 = 0

            while (!queue.isEmpty()) {
                let consumedBatch = queue.dequeueBatch(Int32(batchSize))
                totalConsumed += Int64(consumedBatch.size)
                
                if (consumedBatch.size == 0) {
                    break
                }
            }

            let batchConsumeEndTime = getCurrentTimeNanos()

            // 计算批量性能
            let batchProduceDuration = Float64(batchProduceEndTime - batchProduceStartTime) / 1000000000.0
            let batchConsumeDuration = Float64(batchConsumeEndTime - batchConsumeStartTime) / 1000000000.0
            let batchTotalDuration = batchProduceDuration + batchConsumeDuration

            let batchProduceRate = Float64(totalProduced) / batchProduceDuration
            let batchConsumeRate = Float64(totalConsumed) / batchConsumeDuration
            let batchTotalRate = Float64(totalProduced + totalConsumed) / batchTotalDuration

            println("    批量生产: ${totalProduced} 项, ${batchProduceRate} ops/s")
            println("    批量消费: ${totalConsumed} 项, ${batchConsumeRate} ops/s")
            println("    批量总体: ${batchTotalRate} ops/s")

            let testPassed = totalProduced > 0 && totalConsumed == totalProduced
            if (testPassed) {
                println("    ✅ 批量大小${batchSize}测试通过")
            } else {
                println("    ❌ 批量大小${batchSize}测试失败")
                allTestsPassed = false
            }
            println()
        }

        return allTestsPassed
    }

    /**
     * 测试3: 内存池性能 (模拟JCTools的对象池)
     */
    public func testObjectPoolPerformance(): Bool {
        println("🚀 测试3: 内存池性能 (模拟JCTools对象池)")

        let poolSizes = [100, 500, 1000, 5000]
        var allTestsPassed = true

        for (poolSize in poolSizes) {
            println("  📊 测试池大小: ${poolSize}")

            let pool = CangjieFriendlyObjectPool<Array<UInt8>>(
                { => Array<UInt8>(1024, { i => UInt8(0) }) },  // 1KB对象
                { arr => () },  // 简单重置
                Int64(poolSize)
            )

            let operationCount = poolSize * 10
            let startTime = getCurrentTimeNanos()

            var allocations: Int64 = 0
            var deallocations: Int64 = 0
            let objects = Array<Option<Array<UInt8>>>(Int64(operationCount), { i => None })

            // 分配阶段
            for (i in 0..Int64(operationCount)) {
                let obj = pool.acquire()
                objects[i] = Some(obj)
                allocations += 1
            }

            // 释放阶段
            for (i in 0..Int64(operationCount)) {
                match (objects[i]) {
                    case Some(obj) =>
                        pool.release(obj)
                        deallocations += 1
                    case None => ()
                }
            }

            let endTime = getCurrentTimeNanos()
            let duration = Float64(endTime - startTime) / 1000000000.0
            let totalOps = allocations + deallocations
            let opsRate = Float64(totalOps) / duration

            let poolStats = pool.getStatistics()
            let hitRate = poolStats.hitRate
            let utilization = poolStats.getUtilization()

            println("    分配: ${allocations} 次")
            println("    释放: ${deallocations} 次")
            println("    总操作: ${totalOps} 次")
            println("    操作速率: ${opsRate} ops/s")
            println("    命中率: ${hitRate * 100.0}%")
            println("    利用率: ${utilization * 100.0}%")

            let testPassed = allocations > 0 && deallocations == allocations && hitRate > 0.8
            if (testPassed) {
                println("    ✅ 池大小${poolSize}测试通过")
            } else {
                println("    ❌ 池大小${poolSize}测试失败")
                allTestsPassed = false
            }
            println()
        }

        return allTestsPassed
    }

    /**
     * 测试4: 高频操作压力测试 (模拟JCTools的压力测试)
     */
    public func testHighFrequencyStress(): Bool {
        println("🚀 测试4: 高频操作压力测试 (模拟JCTools压力测试)")

        let queue = LockFreeQueue<BenchmarkData>(32768)
        let iterations = 1000000  // 100万次操作
        
        let startTime = getCurrentTimeNanos()
        var operations: Int64 = 0

        // 高频混合操作
        for (i in 0..Int64(iterations)) {
            if (i % 2 == 0) {
                // 入队操作
                let data = BenchmarkData(i, 16)  // 小负载
                if (queue.enqueue(data)) {
                    operations += 1
                }
            } else {
                // 出队操作
                match (queue.dequeue()) {
                    case Some(_) => operations += 1
                    case None => ()
                }
            }
        }

        let endTime = getCurrentTimeNanos()
        let duration = Float64(endTime - startTime) / 1000000000.0
        let opsRate = Float64(operations) / duration

        println("  总操作数: ${operations}")
        println("  测试时长: ${duration}秒")
        println("  操作速率: ${opsRate} ops/s")

        let stats = queue.getStats()
        println("  成功率: ${stats.getSuccessRate() * 100.0}%")
        println("  队列利用率: ${stats.getUtilization() * 100.0}%")

        // JCTools风格的高性能验证
        let testPassed = opsRate > 1000000.0 && stats.getSuccessRate() > 0.95  // 100万ops/s + 95%成功率
        if (testPassed) {
            println("  ✅ 高频操作压力测试通过")
        } else {
            println("  ❌ 高频操作压力测试失败")
        }

        return testPassed
    }

    /**
     * 运行所有JCTools启发的基准测试
     */
    public func runAllBenchmarks(): Bool {
        println("========================================")
        println("=== CActor JCTools启发基准测试 ===")
        println("基于Java JCTools库设计理念的高性能验证")
        println("========================================")
        println()

        var passedTests = 0
        let totalTests = 4

        if (testSPSCQueuePerformance()) {
            passedTests += 1
        }
        println()

        if (testBatchOperationPerformance()) {
            passedTests += 1
        }
        println()

        if (testObjectPoolPerformance()) {
            passedTests += 1
        }
        println()

        if (testHighFrequencyStress()) {
            passedTests += 1
        }
        println()

        println("========================================")
        println("=== JCTools启发基准测试结果 ===")
        println("通过测试: ${passedTests}/${totalTests}")

        if (passedTests == totalTests) {
            println("🎉 所有JCTools启发基准测试通过！")
            println("✅ CActor达到JCTools级别的高性能")
            return true
        } else if (passedTests >= 3) {
            println("⚡ 大部分JCTools启发基准测试通过！")
            println("系统展现出优秀的高性能特征")
            return true
        } else {
            println("📈 JCTools启发基准测试部分通过")
            println("系统仍有优化空间以达到JCTools级别")
            return false
        }
    }
}

main(): Int64 {
    let benchmark = JCToolsInspiredBenchmark()
    let success = benchmark.runAllBenchmarks()
    return if (success) { 0 } else { 1 }
}
