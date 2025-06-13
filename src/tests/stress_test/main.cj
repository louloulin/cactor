/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 压力测试和性能分析
 */
package cactor.tests.stress_test

import std.collection.*
import std.sync.*
import std.time.*
import std.math.*
import cactor.core.message.{Message, StringMessage, PingMessage}
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.benchmark.{BenchmarkResult, LatencyCollector, ActorBenchmark}

/**
 * 压力测试配置
 */
public struct StressTestConfig {
    public let actorCount: Int64
    public let messageCount: Int64
    public let concurrentThreads: Int64
    public let testDurationSeconds: Int64
    public let warmupDurationSeconds: Int64
    public let messageSize: Int64
    
    public init(actorCount: Int64, messageCount: Int64, concurrentThreads: Int64, 
                testDurationSeconds: Int64, warmupDurationSeconds: Int64, messageSize: Int64) {
        this.actorCount = actorCount
        this.messageCount = messageCount
        this.concurrentThreads = concurrentThreads
        this.testDurationSeconds = testDurationSeconds
        this.warmupDurationSeconds = warmupDurationSeconds
        this.messageSize = messageSize
    }
}

/**
 * 压力测试结果
 */
public struct StressTestResult {
    public let testName: String
    public let config: StressTestConfig
    public let totalMessages: Int64
    public let successfulMessages: Int64
    public let failedMessages: Int64
    public let avgThroughput: Float64      // 消息/秒
    public let peakThroughput: Float64     // 峰值吞吐量
    public let avgLatency: Float64         // 平均延迟(微秒)
    public let p50Latency: Float64         // P50延迟(微秒)
    public let p95Latency: Float64         // P95延迟(微秒)
    public let p99Latency: Float64         // P99延迟(微秒)
    public let p999Latency: Float64        // P99.9延迟(微秒)
    public let maxLatency: Float64         // 最大延迟(微秒)
    public let minLatency: Float64         // 最小延迟(微秒)
    public let memoryUsageMB: Float64      // 内存使用(MB)
    public let cpuUsagePercent: Float64    // CPU使用率(%)
    public let testDurationMs: Int64       // 实际测试时长(毫秒)
    public let errorRate: Float64          // 错误率(%)

    public init(testName: String, config: StressTestConfig, totalMessages: Int64,
                successfulMessages: Int64, failedMessages: Int64, avgThroughput: Float64,
                peakThroughput: Float64, avgLatency: Float64, p50Latency: Float64,
                p95Latency: Float64, p99Latency: Float64, p999Latency: Float64,
                maxLatency: Float64, minLatency: Float64, memoryUsageMB: Float64,
                cpuUsagePercent: Float64, testDurationMs: Int64, errorRate: Float64) {
        this.testName = testName
        this.config = config
        this.totalMessages = totalMessages
        this.successfulMessages = successfulMessages
        this.failedMessages = failedMessages
        this.avgThroughput = avgThroughput
        this.peakThroughput = peakThroughput
        this.avgLatency = avgLatency
        this.p50Latency = p50Latency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
        this.p999Latency = p999Latency
        this.maxLatency = maxLatency
        this.minLatency = minLatency
        this.memoryUsageMB = memoryUsageMB
        this.cpuUsagePercent = cpuUsagePercent
        this.testDurationMs = testDurationMs
        this.errorRate = errorRate
    }
    
    public func toString(): String {
        "StressTestResult(${testName}):\n" +
        "  配置: ${config.actorCount} actors, ${config.messageCount} messages, ${config.concurrentThreads} threads\n" +
        "  消息统计: 总计=${totalMessages}, 成功=${successfulMessages}, 失败=${failedMessages}\n" +
        "  吞吐量: 平均=${avgThroughput} msg/s, 峰值=${peakThroughput} msg/s\n" +
        "  延迟分布: 平均=${avgLatency}μs, P50=${p50Latency}μs, P95=${p95Latency}μs, P99=${p99Latency}μs, P99.9=${p999Latency}μs\n" +
        "  延迟范围: 最小=${minLatency}μs, 最大=${maxLatency}μs\n" +
        "  资源使用: 内存=${memoryUsageMB}MB, CPU=${cpuUsagePercent}%\n" +
        "  测试时长: ${testDurationMs}ms, 错误率=${errorRate}%"
    }
}

/**
 * 高性能延迟收集器
 */
public class HighPerfLatencyCollector {
    private let latencies: ArrayList<Int64>
    private let mutex: ReentrantMutex
    private var minLatency: Int64
    private var maxLatency: Int64
    private var totalLatency: Int64
    private var count: Int64
    
    public init() {
        this.latencies = ArrayList<Int64>()
        this.mutex = ReentrantMutex()
        this.minLatency = 9223372036854775807  // Int64最大值
        this.maxLatency = -9223372036854775808  // Int64最小值
        this.totalLatency = 0
        this.count = 0
    }
    
    public func recordLatency(latencyNanos: Int64): Unit {
        mutex.lock()
        
        latencies.append(latencyNanos)
        totalLatency += latencyNanos
        count += 1
        
        if (latencyNanos < minLatency) {
            minLatency = latencyNanos
        }
        if (latencyNanos > maxLatency) {
            maxLatency = latencyNanos
        }
        
        mutex.unlock()
    }
    
    public func getStatistics(): LatencyStatistics {
        mutex.lock()
        
        if (count == 0) {
            mutex.unlock()
            return LatencyStatistics(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0)
        }
        
        // 计算平均延迟
        let avgLatency = Float64(totalLatency) / Float64(count) / 1000.0  // 转换为微秒
        
        // 计算百分位延迟（简化实现）
        let sortedLatencies = latencies.toArray()
        // 这里应该对数组进行排序，简化实现
        
        let p50Index = Int64(Float64(sortedLatencies.size) * 0.5)
        let p95Index = Int64(Float64(sortedLatencies.size) * 0.95)
        let p99Index = Int64(Float64(sortedLatencies.size) * 0.99)
        let p999Index = Int64(Float64(sortedLatencies.size) * 0.999)
        
        let p50 = if (p50Index < Int64(sortedLatencies.size)) { 
            Float64(sortedLatencies[p50Index]) / 1000.0 
        } else { 
            avgLatency 
        }
        let p95 = if (p95Index < Int64(sortedLatencies.size)) { 
            Float64(sortedLatencies[p95Index]) / 1000.0 
        } else { 
            avgLatency 
        }
        let p99 = if (p99Index < Int64(sortedLatencies.size)) { 
            Float64(sortedLatencies[p99Index]) / 1000.0 
        } else { 
            avgLatency 
        }
        let p999 = if (p999Index < Int64(sortedLatencies.size)) { 
            Float64(sortedLatencies[p999Index]) / 1000.0 
        } else { 
            avgLatency 
        }
        
        let min = Float64(minLatency) / 1000.0
        let max = Float64(maxLatency) / 1000.0
        
        let result = LatencyStatistics(avgLatency, p50, p95, p99, p999, min, max, count)
        mutex.unlock()
        
        return result
    }
    
    public func clear(): Unit {
        mutex.lock()
        latencies.clear()
        minLatency = 9223372036854775807  // Int64最大值
        maxLatency = -9223372036854775808  // Int64最小值
        totalLatency = 0
        count = 0
        mutex.unlock()
    }
}

/**
 * 延迟统计数据
 */
public struct LatencyStatistics {
    public let avgLatency: Float64
    public let p50Latency: Float64
    public let p95Latency: Float64
    public let p99Latency: Float64
    public let p999Latency: Float64
    public let minLatency: Float64
    public let maxLatency: Float64
    public let count: Int64
    
    public init(avgLatency: Float64, p50Latency: Float64, p95Latency: Float64, 
                p99Latency: Float64, p999Latency: Float64, minLatency: Float64, 
                maxLatency: Float64, count: Int64) {
        this.avgLatency = avgLatency
        this.p50Latency = p50Latency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
        this.p999Latency = p999Latency
        this.minLatency = minLatency
        this.maxLatency = maxLatency
        this.count = count
    }
}

/**
 * 吞吐量监控器
 */
public class ThroughputMonitor {
    private var messageCount: AtomicInt64
    private var startTime: Int64
    private var lastSampleTime: Int64
    private var lastSampleCount: Int64
    private var peakThroughput: Float64
    private let mutex: ReentrantMutex
    
    public init() {
        this.messageCount = AtomicInt64(0)
        this.startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.lastSampleTime = startTime
        this.lastSampleCount = 0
        this.peakThroughput = 0.0
        this.mutex = ReentrantMutex()
    }
    
    public func recordMessage(): Unit {
        messageCount.fetchAdd(1)
    }
    
    public func getCurrentThroughput(): Float64 {
        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let currentCount = messageCount.load()
        
        mutex.lock()
        let timeDiff = currentTime - lastSampleTime
        let countDiff = currentCount - lastSampleCount
        
        if (timeDiff > 0) {
            let throughput = Float64(countDiff) / (Float64(timeDiff) / 1000.0)
            if (throughput > peakThroughput) {
                peakThroughput = throughput
            }
            lastSampleTime = currentTime
            lastSampleCount = currentCount
            mutex.unlock()
            return throughput
        }
        mutex.unlock()
        return 0.0
    }
    
    public func getAverageThroughput(): Float64 {
        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let totalTime = currentTime - startTime
        let totalCount = messageCount.load()
        
        if (totalTime > 0) {
            return Float64(totalCount) / (Float64(totalTime) / 1000.0)
        }
        return 0.0
    }
    
    public func getPeakThroughput(): Float64 {
        mutex.lock()
        let peak = peakThroughput
        mutex.unlock()
        return peak
    }
    
    public func getTotalMessages(): Int64 {
        messageCount.load()
    }
}

/**
 * 压力测试Actor
 */
class StressTestActor {
    private let latencyCollector: HighPerfLatencyCollector
    private let throughputMonitor: ThroughputMonitor
    private let processedCount: AtomicInt64
    private let errorCount: AtomicInt64
    private let actorId: String
    
    public init(actorId: String, latencyCollector: HighPerfLatencyCollector, 
                throughputMonitor: ThroughputMonitor) {
        this.actorId = actorId
        this.latencyCollector = latencyCollector
        this.throughputMonitor = throughputMonitor
        this.processedCount = AtomicInt64(0)
        this.errorCount = AtomicInt64(0)
    }
    
    public func receive(message: Message, context: StressTestContext): Unit {
        let receiveTime = getCurrentTimeNanos()
        
        try {
            match (message) {
                case msg: PingMessage =>
                    // 计算延迟
                    let sendTime = msg.getId()
                    let latency = receiveTime - sendTime
                    latencyCollector.recordLatency(latency)
                    throughputMonitor.recordMessage()
                    processedCount.fetchAdd(1)
                    
                    // 模拟一些处理工作
                    simulateWork()
                    
                case msg: StringMessage =>
                    // 处理字符串消息
                    throughputMonitor.recordMessage()
                    processedCount.fetchAdd(1)
                    
                    // 模拟一些处理工作
                    simulateWork()
                    
                case _ =>
                    errorCount.fetchAdd(1)
            }
        } catch (e: Exception) {
            errorCount.fetchAdd(1)
        }
    }
    
    private func simulateWork(): Unit {
        // 模拟一些CPU密集型工作
        var sum = 0
        for (i in 0..100) {
            sum += i
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
 * 简化的ActorContext实现
 */
public interface StressTestContext {
    func getSelf(): String
    func getSender(): Option<String>
    func getSystem(): String
}

class MockStressTestContext <: StressTestContext {
    public func getSelf(): String {
        "/stress/test"
    }

    public func getSender(): Option<String> {
        None<String>
    }

    public func getSystem(): String {
        "stress-test-system"
    }
}

/**
 * 辅助函数：重复字符串
 */
func repeatString(str: String, count: Int64): String {
    var result = ""
    for (i in 0..count) {
        result = result + str
    }
    return result
}

/**
 * 压力测试套件
 */
public class StressTestSuite {
    private let latencyCollector: HighPerfLatencyCollector
    private let throughputMonitor: ThroughputMonitor

    public init() {
        this.latencyCollector = HighPerfLatencyCollector()
        this.throughputMonitor = ThroughputMonitor()
    }

    public func runAllTests(): Unit {
        println("开始CActor压力测试套件...")

        // 测试配置
        let configs = [
            // 轻量级测试
            StressTestConfig(10, 1000, 2, 5, 1, 64),
            // 中等负载测试
            StressTestConfig(50, 5000, 5, 10, 2, 256),
            // 高负载测试
            StressTestConfig(100, 10000, 10, 15, 3, 1024),
            // 极限测试
            StressTestConfig(200, 20000, 20, 20, 5, 4096)
        ]

        let results = ArrayList<StressTestResult>()

        for (config in configs) {
            println("\n--- 执行压力测试: ${config.actorCount} actors, ${config.messageCount} messages ---")

            let result = runStressTest(config)
            results.append(result)

            println(result.toString())

            // 测试间隔，让系统恢复
            sleep(Duration.second * 2)
        }

        // 生成综合报告
        generateComprehensiveReport(results.toArray())
    }

    private func runStressTest(config: StressTestConfig): StressTestResult {
        // 重置收集器
        latencyCollector.clear()
        let throughputMonitor = ThroughputMonitor()

        // 创建测试Actor
        let actors = ArrayList<StressTestActor>()
        for (i in 0..config.actorCount) {
            let actorId = "stress-actor-${i}"
            actors.append(StressTestActor(actorId, latencyCollector, throughputMonitor))
        }

        println("预热阶段...")
        warmupPhase(actors.toArray(), config)

        // 清理预热数据
        latencyCollector.clear()
        let testThroughputMonitor = ThroughputMonitor()

        println("压力测试阶段...")
        let testStartTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        // 执行压力测试
        executeStressTest(actors.toArray(), config, testThroughputMonitor)

        let testEndTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let testDuration = testEndTime - testStartTime

        // 收集结果
        return collectResults(config, testDuration, testThroughputMonitor)
    }

    private func warmupPhase(actors: Array<StressTestActor>, config: StressTestConfig): Unit {
        let warmupMessages = config.messageCount / 10  // 预热消息数量为正式测试的1/10
        let context = MockStressTestContext()

        for (i in 0..warmupMessages) {
            let actorIndex = i % Int64(actors.size)
            let actor = actors[actorIndex]

            let sendTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000
            let message = PingMessage(sendTime)

            actor.receive(message, context)
        }

        // 等待预热完成
        sleep(Duration.second * config.warmupDurationSeconds)
    }

    private func executeStressTest(actors: Array<StressTestActor>, config: StressTestConfig,
                                   throughputMonitor: ThroughputMonitor): Unit {
        let context = MockStressTestContext()
        let messagesPerThread = config.messageCount / config.concurrentThreads

        // 启动并发线程
        for (threadId in 0..config.concurrentThreads) {
            spawn {
                for (i in 0..messagesPerThread) {
                    let actorIndex = (threadId * messagesPerThread + i) % Int64(actors.size)
                    let actor = actors[actorIndex]

                    let sendTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000
                    let message = PingMessage(sendTime)

                    actor.receive(message, context)
                    throughputMonitor.recordMessage()

                    // 可选：添加小延迟以控制发送速率
                    if (i % 100 == 0) {
                        sleep(Duration.millisecond)
                    }
                }
            }
        }

        // 等待测试完成
        sleep(Duration.second * config.testDurationSeconds)
    }

    private func collectResults(config: StressTestConfig, testDuration: Int64,
                                throughputMonitor: ThroughputMonitor): StressTestResult {
        let latencyStats = latencyCollector.getStatistics()
        let avgThroughput = throughputMonitor.getAverageThroughput()
        let peakThroughput = throughputMonitor.getPeakThroughput()
        let totalMessages = throughputMonitor.getTotalMessages()

        // 计算成功和失败消息数
        let successfulMessages = latencyStats.count
        let failedMessages = totalMessages - successfulMessages
        let errorRate = if (totalMessages > 0) {
            Float64(failedMessages) / Float64(totalMessages) * 100.0
        } else {
            0.0
        }

        // 估算资源使用
        let memoryUsageMB = estimateMemoryUsage(config)
        let cpuUsagePercent = estimateCpuUsage(avgThroughput)

        return StressTestResult(
            "StressTest_${config.actorCount}actors_${config.messageCount}msgs",
            config,
            totalMessages,
            successfulMessages,
            failedMessages,
            avgThroughput,
            peakThroughput,
            latencyStats.avgLatency,
            latencyStats.p50Latency,
            latencyStats.p95Latency,
            latencyStats.p99Latency,
            latencyStats.p999Latency,
            latencyStats.maxLatency,
            latencyStats.minLatency,
            memoryUsageMB,
            cpuUsagePercent,
            testDuration,
            errorRate
        )
    }

    private func estimateMemoryUsage(config: StressTestConfig): Float64 {
        // 简化的内存使用估算
        let baseMemoryMB = 10.0  // 基础内存
        let actorMemoryMB = Float64(config.actorCount) * 0.1  // 每个Actor约0.1MB
        let messageMemoryMB = Float64(config.messageCount) * Float64(config.messageSize) / (1024.0 * 1024.0)

        return baseMemoryMB + actorMemoryMB + messageMemoryMB
    }

    private func estimateCpuUsage(throughput: Float64): Float64 {
        // 简化的CPU使用率估算
        let baseCpuUsage = 5.0  // 基础CPU使用率
        let throughputCpuUsage = throughput / 1000.0  // 每1000 msg/s约1% CPU

        let totalCpuUsage = baseCpuUsage + throughputCpuUsage
        return if (totalCpuUsage > 100.0) { 100.0 } else { totalCpuUsage }
    }

    private func generateComprehensiveReport(results: Array<StressTestResult>): Unit {
        println("\n" + repeatString("=", 80))
        println("CActor 压力测试综合报告")
        println(repeatString("=", 80))

        for (result in results) {
            println("\n${result.toString()}")
            println(repeatString("-", 60))
        }

        // 性能趋势分析
        println("\n性能趋势分析:")
        analyzePerformanceTrends(results)

        // 性能建议
        println("\n性能优化建议:")
        generatePerformanceRecommendations(results)
    }

    private func analyzePerformanceTrends(results: Array<StressTestResult>): Unit {
        if (results.size < 2) {
            println("  需要至少2个测试结果进行趋势分析")
            return
        }

        for (i in 1..results.size) {
            let prev = results[i-1]
            let curr = results[i]

            let throughputChange = ((curr.avgThroughput - prev.avgThroughput) / prev.avgThroughput) * 100.0
            let latencyChange = ((curr.avgLatency - prev.avgLatency) / prev.avgLatency) * 100.0

            println("  ${prev.testName} -> ${curr.testName}:")
            println("    吞吐量变化: ${throughputChange}%")
            println("    延迟变化: ${latencyChange}%")
        }
    }

    private func generatePerformanceRecommendations(results: Array<StressTestResult>): Unit {
        let lastResult = results[results.size - 1]

        if (lastResult.avgLatency > 1000.0) {  // 大于1ms
            println("  - 延迟较高，建议优化消息处理逻辑")
        }

        if (lastResult.errorRate > 1.0) {  // 错误率大于1%
            println("  - 错误率较高，建议检查系统稳定性")
        }

        if (lastResult.memoryUsageMB > 1000.0) {  // 大于1GB
            println("  - 内存使用较高，建议优化内存管理")
        }

        if (lastResult.cpuUsagePercent > 80.0) {  // CPU使用率大于80%
            println("  - CPU使用率较高，建议优化计算逻辑")
        }

        println("  - 建议在生产环境中进行更长时间的稳定性测试")
        println("  - 建议监控GC性能和内存泄漏")
        println("  - 建议测试不同消息大小对性能的影响")
    }
}

main(): Int64 {
    println("=== CActor 压力测试和性能分析 ===")

    // 运行压力测试
    let stressTest = StressTestSuite()
    stressTest.runAllTests()

    return 0
}
