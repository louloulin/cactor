/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 极限压力测试和深度性能分析
 */
package cactor.tests.extreme_stress_test

import std.collection.*
import std.sync.*
import std.time.*
import std.math.*
import cactor.core.message.{Message, StringMessage, PingMessage}
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.benchmark.{BenchmarkResult, LatencyCollector, ActorBenchmark}

/**
 * 极限压力测试配置
 */
public struct ExtremeStressConfig {
    public let actorCount: Int64
    public let messageCount: Int64
    public let concurrentThreads: Int64
    public let testDurationSeconds: Int64
    public let messageSize: Int64
    public let batchSize: Int64
    public let targetThroughput: Int64  // 目标吞吐量 msg/s
    
    public init(actorCount: Int64, messageCount: Int64, concurrentThreads: Int64, 
                testDurationSeconds: Int64, messageSize: Int64, batchSize: Int64, targetThroughput: Int64) {
        this.actorCount = actorCount
        this.messageCount = messageCount
        this.concurrentThreads = concurrentThreads
        this.testDurationSeconds = testDurationSeconds
        this.messageSize = messageSize
        this.batchSize = batchSize
        this.targetThroughput = targetThroughput
    }
}

/**
 * 高性能消息生成器
 */
public class MessageGenerator {
    private let messagePool: ArrayList<Message>
    private var currentIndex: AtomicInt64
    private let poolSize: Int64
    
    public init(poolSize: Int64, messageSize: Int64) {
        this.messagePool = ArrayList<Message>()
        this.currentIndex = AtomicInt64(0)
        this.poolSize = poolSize
        
        // 预生成消息池
        for (i in 0..poolSize) {
            let payload = generatePayload(messageSize)
            messagePool.append(StringMessage(payload))
        }
    }
    
    public func getNextMessage(): Message {
        let index = currentIndex.fetchAdd(1) % poolSize
        return messagePool[index]
    }
    
    private func generatePayload(size: Int64): String {
        var payload = ""
        for (i in 0..size) {
            payload = payload + "A"
        }
        return payload
    }
}

/**
 * 高性能延迟测量器
 */
public class HighResolutionLatencyMeter {
    private let samples: Array<Int64>
    private var sampleIndex: AtomicInt64
    private let maxSamples: Int64
    private var minLatency: AtomicInt64
    private var maxLatency: AtomicInt64
    private var totalLatency: AtomicInt64
    private var sampleCount: AtomicInt64
    
    public init(maxSamples: Int64) {
        this.maxSamples = maxSamples
        this.samples = Array<Int64>(maxSamples, { i => 0 })
        this.sampleIndex = AtomicInt64(0)
        this.minLatency = AtomicInt64(Int64.maxValue)
        this.maxLatency = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
        this.sampleCount = AtomicInt64(0)
    }
    
    public func recordLatency(latencyNanos: Int64): Unit {
        let index = sampleIndex.fetchAdd(1) % maxSamples
        samples[index] = latencyNanos
        
        totalLatency.fetchAdd(latencyNanos)
        sampleCount.fetchAdd(1)
        
        // 更新最小值
        var currentMin = minLatency.load()
        while (latencyNanos < currentMin && !minLatency.compareAndSwap(currentMin, latencyNanos)) {
            currentMin = minLatency.load()
        }
        
        // 更新最大值
        var currentMax = maxLatency.load()
        while (latencyNanos > currentMax && !maxLatency.compareAndSwap(currentMax, latencyNanos)) {
            currentMax = maxLatency.load()
        }
    }
    
    public func getStatistics(): LatencyStats {
        let count = sampleCount.load()
        if (count == 0) {
            return LatencyStats(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        }
        
        let avgNanos = Float64(totalLatency.load()) / Float64(count)
        let minNanos = Float64(minLatency.load())
        let maxNanos = Float64(maxLatency.load())
        
        // 计算百分位数（简化实现）
        let sampleSize = if (count < maxSamples) { count } else { maxSamples }
        let sortedSamples = Array<Int64>(sampleSize, { i => samples[i] })
        
        let p50 = calculatePercentile(sortedSamples, 0.5)
        let p95 = calculatePercentile(sortedSamples, 0.95)
        let p99 = calculatePercentile(sortedSamples, 0.99)
        let p999 = calculatePercentile(sortedSamples, 0.999)
        
        return LatencyStats(
            avgNanos / 1000.0,    // 转换为微秒
            p50 / 1000.0,
            p95 / 1000.0,
            p99 / 1000.0,
            p999 / 1000.0,
            minNanos / 1000.0,
            maxNanos / 1000.0
        )
    }
    
    private func calculatePercentile(sortedArray: Array<Int64>, percentile: Float64): Float64 {
        if (sortedArray.size == 0) {
            return 0.0
        }
        
        let index = Int64(Float64(sortedArray.size) * percentile)
        let safeIndex = if (index >= Int64(sortedArray.size)) { 
            Int64(sortedArray.size) - 1 
        } else { 
            index 
        }
        
        return Float64(sortedArray[safeIndex])
    }
}

/**
 * 延迟统计结果
 */
public struct LatencyStats {
    public let avgLatency: Float64
    public let p50Latency: Float64
    public let p95Latency: Float64
    public let p99Latency: Float64
    public let p999Latency: Float64
    public let minLatency: Float64
    public let maxLatency: Float64
    
    public init(avgLatency: Float64, p50Latency: Float64, p95Latency: Float64, 
                p99Latency: Float64, p999Latency: Float64, minLatency: Float64, maxLatency: Float64) {
        this.avgLatency = avgLatency
        this.p50Latency = p50Latency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
        this.p999Latency = p999Latency
        this.minLatency = minLatency
        this.maxLatency = maxLatency
    }
}

/**
 * 实时吞吐量监控器
 */
public class RealTimeThroughputMonitor {
    private var messageCount: AtomicInt64
    private var startTime: Int64
    private var lastReportTime: Int64
    private var lastReportCount: Int64
    private var peakThroughput: AtomicFloat64
    private let reportIntervalMs: Int64
    
    public init(reportIntervalMs: Int64) {
        this.messageCount = AtomicInt64(0)
        this.startTime = getCurrentTimeMs()
        this.lastReportTime = startTime
        this.lastReportCount = 0
        this.peakThroughput = AtomicFloat64(0.0)
        this.reportIntervalMs = reportIntervalMs
    }
    
    public func recordMessage(): Unit {
        messageCount.fetchAdd(1)
    }
    
    public func getCurrentThroughput(): Float64 {
        let currentTime = getCurrentTimeMs()
        let currentCount = messageCount.load()
        
        if (currentTime - lastReportTime >= reportIntervalMs) {
            let timeDiff = currentTime - lastReportTime
            let countDiff = currentCount - lastReportCount
            
            if (timeDiff > 0) {
                let throughput = Float64(countDiff) / (Float64(timeDiff) / 1000.0)
                
                // 更新峰值吞吐量
                var currentPeak = peakThroughput.load()
                while (throughput > currentPeak && !peakThroughput.compareAndSwap(currentPeak, throughput)) {
                    currentPeak = peakThroughput.load()
                }
                
                lastReportTime = currentTime
                lastReportCount = currentCount
                
                return throughput
            }
        }
        
        return 0.0
    }
    
    public func getAverageThroughput(): Float64 {
        let currentTime = getCurrentTimeMs()
        let totalTime = currentTime - startTime
        let totalCount = messageCount.load()
        
        if (totalTime > 0) {
            return Float64(totalCount) / (Float64(totalTime) / 1000.0)
        }
        return 0.0
    }
    
    public func getPeakThroughput(): Float64 {
        peakThroughput.load()
    }
    
    public func getTotalMessages(): Int64 {
        messageCount.load()
    }
    
    private func getCurrentTimeMs(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 极限压力测试Actor
 */
class ExtremeStressActor {
    private let latencyMeter: HighResolutionLatencyMeter
    private let throughputMonitor: RealTimeThroughputMonitor
    private let processedCount: AtomicInt64
    private let errorCount: AtomicInt64
    private let actorId: String
    private let messageGenerator: MessageGenerator
    
    public init(actorId: String, latencyMeter: HighResolutionLatencyMeter, 
                throughputMonitor: RealTimeThroughputMonitor, messageGenerator: MessageGenerator) {
        this.actorId = actorId
        this.latencyMeter = latencyMeter
        this.throughputMonitor = throughputMonitor
        this.messageGenerator = messageGenerator
        this.processedCount = AtomicInt64(0)
        this.errorCount = AtomicInt64(0)
    }
    
    public func processMessage(message: Message): Unit {
        let startTime = getCurrentTimeNanos()
        
        try {
            // 模拟消息处理
            match (message) {
                case msg: PingMessage =>
                    let sendTime = msg.getId()
                    let latency = startTime - sendTime
                    latencyMeter.recordLatency(latency)
                    
                case msg: StringMessage =>
                    // 模拟一些计算工作
                    simulateWork()
                    
                case _ =>
                    errorCount.fetchAdd(1)
                    return
            }
            
            throughputMonitor.recordMessage()
            processedCount.fetchAdd(1)
            
        } catch (e: Exception) {
            errorCount.fetchAdd(1)
        }
    }
    
    private func simulateWork(): Unit {
        // 模拟CPU密集型工作
        var sum = 0
        for (i in 0..50) {
            sum += i * i
        }
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000
    }
    
    public func getProcessedCount(): Int64 {
        processedCount.load()
    }
    
    public func getErrorCount(): Int64 {
        errorCount.load()
    }
}

/**
 * 极限压力测试套件
 */
public class ExtremeStressTestSuite {
    
    public init() {}
    
    public func runExtremeTests(): Unit {
        println("=== CActor 极限压力测试套件 ===")
        
        // 极限测试配置
        let configs = [
            // 高并发测试
            ExtremeStressConfig(500, 50000, 50, 30, 1024, 100, 10000),
            // 大规模Actor测试
            ExtremeStressConfig(1000, 100000, 100, 60, 512, 200, 20000),
            // 超高吞吐量测试
            ExtremeStressConfig(2000, 200000, 200, 120, 256, 500, 50000)
        ]
        
        for (config in configs) {
            println("\n--- 极限压力测试: ${config.actorCount} actors, ${config.messageCount} messages ---")
            println("目标吞吐量: ${config.targetThroughput} msg/s")
            
            runExtremeStressTest(config)
            
            // 测试间隔，让系统恢复
            println("等待系统恢复...")
            sleep(Duration.second * 5)
        }
    }
    
    private func runExtremeStressTest(config: ExtremeStressConfig): Unit {
        // 创建高性能组件
        let latencyMeter = HighResolutionLatencyMeter(100000)
        let throughputMonitor = RealTimeThroughputMonitor(1000)  // 每秒报告
        let messageGenerator = MessageGenerator(10000, config.messageSize)
        
        // 创建大量Actor
        let actors = ArrayList<ExtremeStressActor>()
        for (i in 0..config.actorCount) {
            let actorId = "extreme-actor-${i}"
            actors.append(ExtremeStressActor(actorId, latencyMeter, throughputMonitor, messageGenerator))
        }
        
        println("开始极限压力测试...")
        let testStartTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        // 启动高强度消息发送
        executeExtremeTest(actors.toArray(), config, throughputMonitor)
        
        let testEndTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let testDuration = testEndTime - testStartTime
        
        // 收集和分析结果
        analyzeExtremeResults(config, testDuration, latencyMeter, throughputMonitor)
    }
    
    private func executeExtremeTest(actors: Array<ExtremeStressActor>, config: ExtremeStressConfig, 
                                    throughputMonitor: RealTimeThroughputMonitor): Unit {
        let messagesPerThread = config.messageCount / config.concurrentThreads
        
        // 启动高并发线程
        for (threadId in 0..config.concurrentThreads) {
            spawn {
                for (i in 0..messagesPerThread) {
                    let actorIndex = (threadId * messagesPerThread + i) % Int64(actors.size)
                    let actor = actors[actorIndex]
                    
                    let message = PingMessage(DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000)
                    actor.processMessage(message)
                    
                    // 控制发送速率以达到目标吞吐量
                    if (i % config.batchSize == 0) {
                        let currentThroughput = throughputMonitor.getCurrentThroughput()
                        if (currentThroughput > Float64(config.targetThroughput) * 1.1) {
                            sleep(Duration.microsecond * 100)  // 稍微减慢
                        }
                    }
                }
            }
        }
        
        // 等待测试完成
        sleep(Duration.second * config.testDurationSeconds)
    }
    
    private func analyzeExtremeResults(config: ExtremeStressConfig, testDuration: Int64,
                                       latencyMeter: HighResolutionLatencyMeter, 
                                       throughputMonitor: RealTimeThroughputMonitor): Unit {
        let latencyStats = latencyMeter.getStatistics()
        let avgThroughput = throughputMonitor.getAverageThroughput()
        let peakThroughput = throughputMonitor.getPeakThroughput()
        let totalMessages = throughputMonitor.getTotalMessages()
        
        println("\n🚀 极限压力测试结果:")
        println("配置: ${config.actorCount} actors, ${config.messageCount} messages, ${config.concurrentThreads} threads")
        println("目标吞吐量: ${config.targetThroughput} msg/s")
        println("实际吞吐量: 平均=${avgThroughput} msg/s, 峰值=${peakThroughput} msg/s")
        println("吞吐量达成率: ${(avgThroughput / Float64(config.targetThroughput)) * 100.0}%")
        println("总消息数: ${totalMessages}")
        println("测试时长: ${testDuration}ms")
        
        println("\n⚡ 延迟分析:")
        println("平均延迟: ${latencyStats.avgLatency}μs")
        println("P50延迟: ${latencyStats.p50Latency}μs")
        println("P95延迟: ${latencyStats.p95Latency}μs")
        println("P99延迟: ${latencyStats.p99Latency}μs")
        println("P99.9延迟: ${latencyStats.p999Latency}μs")
        println("最小延迟: ${latencyStats.minLatency}μs")
        println("最大延迟: ${latencyStats.maxLatency}μs")
        
        // 性能评估
        evaluatePerformance(config, avgThroughput, latencyStats)
    }
    
    private func evaluatePerformance(config: ExtremeStressConfig, avgThroughput: Float64, latencyStats: LatencyStats): Unit {
        println("\n📊 性能评估:")
        
        // 吞吐量评估
        let throughputRatio = avgThroughput / Float64(config.targetThroughput)
        if (throughputRatio >= 0.9) {
            println("✅ 吞吐量: 优秀 (${throughputRatio * 100.0}%)")
        } else if (throughputRatio >= 0.7) {
            println("⚠ 吞吐量: 良好 (${throughputRatio * 100.0}%)")
        } else {
            println("❌ 吞吐量: 需要改进 (${throughputRatio * 100.0}%)")
        }

        // 延迟评估
        if (latencyStats.p99Latency < 100.0) {
            println("✅ P99延迟: 优秀 (${latencyStats.p99Latency}μs < 100μs)")
        } else if (latencyStats.p99Latency < 1000.0) {
            println("⚠ P99延迟: 良好 (${latencyStats.p99Latency}μs < 1ms)")
        } else {
            println("❌ P99延迟: 需要改进 (${latencyStats.p99Latency}μs > 1ms)")
        }

        // 一致性评估
        let latencyVariance = latencyStats.maxLatency - latencyStats.minLatency
        if (latencyVariance < 1000.0) {
            println("✅ 延迟一致性: 优秀 (变化范围${latencyVariance}μs)")
        } else {
            println("⚠ 延迟一致性: 需要改进 (变化范围${latencyVariance}μs)")
        }
    }
}

main(): Int64 {
    println("=== CActor 极限压力测试和深度性能分析 ===")
    
    let extremeTest = ExtremeStressTestSuite()
    extremeTest.runExtremeTests()
    
    return 0
}
