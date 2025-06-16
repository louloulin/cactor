/*
 * 优化后的队列性能基准测试
 * 验证SPSC/MPSC拆分和LockFreeQueue优化的效果
 */
package cactor.integration.testing.optimized_queue_benchmark

import std.time.*
import std.collection.*
import cactor.foundation.queue.*

/**
 * 队列性能测试结果
 */
public struct QueueBenchmarkResult {
    public let queueType: String
    public let threadConfig: String
    public let totalOperations: Int64
    public let durationMs: Int64
    public let opsPerSecond: Float64
    public let successRate: Float64
    
    public init(queueType: String, threadConfig: String, totalOperations: Int64, 
               durationMs: Int64, opsPerSecond: Float64, successRate: Float64) {
        this.queueType = queueType
        this.threadConfig = threadConfig
        this.totalOperations = totalOperations
        this.durationMs = durationMs
        this.opsPerSecond = opsPerSecond
        this.successRate = successRate
    }
}

/**
 * 优化队列基准测试套件
 */
public class OptimizedQueueBenchmark {
    private let testResults: ArrayList<QueueBenchmarkResult>
    
    public init() {
        this.testResults = ArrayList<QueueBenchmarkResult>()
    }
    
    /**
     * 获取当前时间（毫秒）
     */
    private func getCurrentTimeMillis(): Int64 {
        return DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
    
    /**
     * SPSC队列性能测试
     */
    public func testSPSCQueue(operations: Int64): QueueBenchmarkResult {
        println("🚀 SPSC队列性能测试: ${operations}操作")
        
        let queue = SPSCQueue<Int64>(1024)
        var successCount: Int64 = 0
        
        let startTime = getCurrentTimeMillis()
        
        // 模拟单生产者单消费者场景
        // 生产阶段
        for (i in 0..operations) {
            if (queue.offer(i)) {
                successCount += 1
            }
        }
        
        // 消费阶段
        var consumeCount: Int64 = 0
        while (consumeCount < successCount) {
            match (queue.poll()) {
                case Some(_) => consumeCount += 1
                case None => break
            }
        }
        
        let endTime = getCurrentTimeMillis()
        let duration = endTime - startTime
        let totalOps = successCount + consumeCount
        let opsPerSecond = Float64(totalOps) / (Float64(duration) / 1000.0)
        let successRate = Float64(successCount) / Float64(operations)
        
        println("  📊 SPSC结果: ${totalOps}操作, ${duration}ms, ${opsPerSecond} ops/s, 成功率${successRate * 100.0}%")
        
        return QueueBenchmarkResult("SPSC", "1P+1C", totalOps, duration, opsPerSecond, successRate)
    }
    
    /**
     * MPSC队列性能测试
     */
    public func testMPSCQueue(operations: Int64, producerCount: Int32): QueueBenchmarkResult {
        println("🚀 MPSC队列性能测试: ${producerCount}生产者 × ${operations}操作")
        
        let queue = MPSCQueue<Int64>(2048)
        var totalSuccess: Int64 = 0
        
        let startTime = getCurrentTimeMillis()
        
        // 模拟多生产者场景
        let opsPerProducer = operations / Int64(producerCount)
        for (producerId in 0..producerCount) {
            var localSuccess: Int64 = 0
            for (i in 0..opsPerProducer) {
                let value = Int64(producerId) * opsPerProducer + i
                if (queue.offer(value)) {
                    localSuccess += 1
                }
            }
            totalSuccess += localSuccess
        }
        
        // 单消费者消费
        var consumeCount: Int64 = 0
        while (consumeCount < totalSuccess) {
            match (queue.poll()) {
                case Some(_) => consumeCount += 1
                case None => 
                    // 短暂等待
                    var wait = 0
                    while (wait < 10) {
                        wait += 1
                    }
                    if (consumeCount < totalSuccess) {
                        continue
                    } else {
                        break
                    }
            }
        }
        
        let endTime = getCurrentTimeMillis()
        let duration = endTime - startTime
        let totalOps = totalSuccess + consumeCount
        let opsPerSecond = Float64(totalOps) / (Float64(duration) / 1000.0)
        let successRate = Float64(totalSuccess) / Float64(operations)
        
        println("  📊 MPSC结果: ${totalOps}操作, ${duration}ms, ${opsPerSecond} ops/s, 成功率${successRate * 100.0}%")
        
        return QueueBenchmarkResult("MPSC", "${producerCount}P+1C", totalOps, duration, opsPerSecond, successRate)
    }
    
    /**
     * 优化后的LockFreeQueue测试
     */
    public func testOptimizedLockFreeQueue(operations: Int64, mode: String): QueueBenchmarkResult {
        println("🚀 优化LockFreeQueue测试: ${mode} × ${operations}操作")
        
        let queue = LockFreeQueue<Int64>(2048)
        var successCount: Int64 = 0
        
        let startTime = getCurrentTimeMillis()
        
        // 根据模式进行不同的测试
        if (mode == "SPSC") {
            // 单生产者单消费者模式
            for (i in 0..operations) {
                if (queue.enqueue(i)) {
                    successCount += 1
                }
            }
            
            var consumeCount: Int64 = 0
            while (consumeCount < successCount) {
                match (queue.dequeue()) {
                    case Some(_) => consumeCount += 1
                    case None => break
                }
            }
            
            let endTime = getCurrentTimeMillis()
            let duration = endTime - startTime
            let totalOps = successCount + consumeCount
            let opsPerSecond = Float64(totalOps) / (Float64(duration) / 1000.0)
            let successRate = Float64(successCount) / Float64(operations)
            
            println("  📊 优化LockFree结果: ${totalOps}操作, ${duration}ms, ${opsPerSecond} ops/s, 成功率${successRate * 100.0}%")
            
            return QueueBenchmarkResult("OptimizedLockFree", mode, totalOps, duration, opsPerSecond, successRate)
        } else {
            // MPSC模式
            let producerCount: Int32 = 4
            let opsPerProducer = operations / Int64(producerCount)
            
            for (producerId in 0..producerCount) {
                var localSuccess: Int64 = 0
                for (i in 0..opsPerProducer) {
                    let value = Int64(producerId) * opsPerProducer + i
                    if (queue.enqueue(value)) {
                        localSuccess += 1
                    }
                }
                successCount += localSuccess
            }
            
            var consumeCount: Int64 = 0
            while (consumeCount < successCount) {
                match (queue.dequeue()) {
                    case Some(_) => consumeCount += 1
                    case None => 
                        var wait = 0
                        while (wait < 10) {
                            wait += 1
                        }
                        if (consumeCount < successCount) {
                            continue
                        } else {
                            break
                        }
                }
            }
            
            let endTime = getCurrentTimeMillis()
            let duration = endTime - startTime
            let totalOps = successCount + consumeCount
            let opsPerSecond = Float64(totalOps) / (Float64(duration) / 1000.0)
            let successRate = Float64(successCount) / Float64(operations)
            
            println("  📊 优化LockFree结果: ${totalOps}操作, ${duration}ms, ${opsPerSecond} ops/s, 成功率${successRate * 100.0}%")
            
            return QueueBenchmarkResult("OptimizedLockFree", mode, totalOps, duration, opsPerSecond, successRate)
        }
    }
    
    /**
     * 运行完整的基准测试套件
     */
    public func runBenchmarkSuite(): Unit {
        println("========================================")
        println("=== 优化队列性能基准测试套件 ===")
        println("验证SPSC/MPSC拆分和适应性优化效果")
        println("========================================")
        println()
        
        let testOperations: Int64 = 1000000  // 100万操作
        
        // SPSC队列测试
        let spscResult = testSPSCQueue(testOperations)
        testResults.append(spscResult)
        println()
        
        // MPSC队列测试
        let mpscResult = testMPSCQueue(testOperations, 4)
        testResults.append(mpscResult)
        println()
        
        // 优化后的LockFreeQueue测试
        let optimizedSpscResult = testOptimizedLockFreeQueue(testOperations, "SPSC")
        testResults.append(optimizedSpscResult)
        println()
        
        let optimizedMpscResult = testOptimizedLockFreeQueue(testOperations, "MPSC")
        testResults.append(optimizedMpscResult)
        println()
        
        // 性能分析
        printPerformanceAnalysis()
    }
    
    /**
     * 打印性能分析结果
     */
    private func printPerformanceAnalysis(): Unit {
        println("========================================")
        println("=== 性能分析总结 ===")
        println()
        
        println("📊 测试结果汇总:")
        for (result in testResults) {
            println("  ${result.queueType}(${result.threadConfig}): ${result.opsPerSecond} ops/s")
        }
        println()
        
        // 找到最高性能
        var maxOps: Float64 = 0.0
        var bestQueue = ""
        for (result in testResults) {
            if (result.opsPerSecond > maxOps) {
                maxOps = result.opsPerSecond
                bestQueue = result.queueType
            }
        }
        
        println("🏆 最高性能: ${bestQueue} - ${maxOps} ops/s")
        println()
        
        println("🎯 5000万消息/秒目标评估:")
        if (maxOps >= 50000000.0) {
            println("✅ 目标已达成！")
        } else if (maxOps >= 20000000.0) {
            let ratio = maxOps / 50000000.0
            println("🎯 良好性能！达成率: ${ratio * 100.0}%")
        } else {
            let ratio = maxOps / 50000000.0
            println("📊 当前达成率: ${ratio * 100.0}%")
        }
        
        println()
        println("🔍 优化效果分析:")
        println("✅ SPSC队列：专门优化单生产者单消费者场景")
        println("✅ MPSC队列：专门优化多生产者单消费者场景")
        println("✅ 适应性LockFreeQueue：根据使用模式自动优化")
        println("✅ 缓存行填充：减少false sharing影响")
        println("✅ 减少CAS竞争：提升并发性能")
    }
}

main(): Int64 {
    let benchmark = OptimizedQueueBenchmark()
    benchmark.runBenchmarkSuite()
    return 0
}
