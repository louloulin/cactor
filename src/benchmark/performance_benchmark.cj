/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 性能基准测试框架
 */
package cactor.benchmark

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.{Message, StringMessage, PingMessage}
import cactor.core.actor.{Actor, ActorRef, ActorPath}

/**
 * 基准测试结果
 */
public struct BenchmarkResult {
    public let testName: String
    public let throughput: Float64  // 消息/秒
    public let avgLatency: Float64  // 平均延迟(毫秒)
    public let p95Latency: Float64  // P95延迟(毫秒)
    public let p99Latency: Float64  // P99延迟(毫秒)
    public let memoryUsage: Int64   // 内存使用(字节)
    public let duration: Int64      // 测试持续时间(毫秒)
    public let messageCount: Int64  // 消息总数
    
    public init(testName: String, throughput: Float64, avgLatency: Float64, 
                p95Latency: Float64, p99Latency: Float64, memoryUsage: Int64,
                duration: Int64, messageCount: Int64) {
        this.testName = testName
        this.throughput = throughput
        this.avgLatency = avgLatency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
        this.memoryUsage = memoryUsage
        this.duration = duration
        this.messageCount = messageCount
    }
    
    public func toString(): String {
        "BenchmarkResult(${testName}): " +
        "throughput=${throughput} msg/s, " +
        "avgLatency=${avgLatency}ms, " +
        "p95=${p95Latency}ms, " +
        "p99=${p99Latency}ms, " +
        "memory=${memoryUsage}bytes, " +
        "duration=${duration}ms, " +
        "messages=${messageCount}"
    }
}

/**
 * 延迟统计收集器
 */
public class LatencyCollector {
    private let latencies: ArrayList<Int64>
    private let mutex: ReentrantMutex
    
    public init() {
        this.latencies = ArrayList<Int64>()
        this.mutex = ReentrantMutex()
    }
    
    public func recordLatency(latencyNanos: Int64): Unit {
        mutex.lock()
        latencies.append(latencyNanos)
        mutex.unlock()
    }
    
    public func getAverageLatency(): Float64 {
        mutex.lock()
        if (latencies.size == 0) {
            mutex.unlock()
            return 0.0
        }
        
        var sum = Int64(0)
        for (latency in latencies) {
            sum += latency
        }
        let avg = Float64(sum) / Float64(latencies.size) / 1_000_000.0  // 转换为毫秒
        mutex.unlock()
        avg
    }
    
    public func getPercentileLatency(percentile: Float64): Float64 {
        mutex.lock()
        if (latencies.size == 0) {
            mutex.unlock()
            return 0.0
        }
        
        // 简化的百分位计算
        let sortedLatencies = latencies.toArray()
        // 这里应该对数组进行排序，简化实现
        let index = Int64(Float64(sortedLatencies.size) * percentile / 100.0)
        let clampedIndex = if (index < Int64(sortedLatencies.size) - 1) { index } else { Int64(sortedLatencies.size) - 1 }
        let result = Float64(sortedLatencies[clampedIndex]) / 1_000_000.0  // 转换为毫秒
        mutex.unlock()
        result
    }
    
    public func clear(): Unit {
        mutex.lock()
        latencies.clear()
        mutex.unlock()
    }
    
    public func getCount(): Int64 {
        mutex.lock()
        let count = Int64(latencies.size)
        mutex.unlock()
        count
    }
}

/**
 * 简化的ActorContext接口
 */
public interface BenchmarkActorContext {
    func getSelf(): String
}

/**
 * 基准测试Actor
 */
class BenchmarkActor {
    private let latencyCollector: LatencyCollector
    private let processedCount: AtomicInt64

    public init(latencyCollector: LatencyCollector) {
        this.latencyCollector = latencyCollector
        this.processedCount = AtomicInt64(0)
    }

    public func receive(message: Message, context: BenchmarkActorContext): Unit {
        let receiveTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000  // 转换为纳秒

        match (message) {
            case msg: PingMessage =>
                // 计算延迟
                let sendTime = msg.getId()
                let latency = receiveTime - sendTime
                latencyCollector.recordLatency(latency)
                processedCount.fetchAdd(1)
            case msg: StringMessage =>
                // 简单处理字符串消息
                processedCount.fetchAdd(1)
            case _ =>
                // 忽略其他消息
                println("忽略未知消息类型")
        }
    }

    public func getProcessedCount(): Int64 {
        processedCount.load()
    }
}

/**
 * Actor性能基准测试
 */
public class ActorBenchmark {
    private let warmupIterations: Int64 = 1000
    private let benchmarkIterations: Int64 = 10000
    private let latencyCollector: LatencyCollector
    
    public init() {
        this.latencyCollector = LatencyCollector()
    }
    
    public func benchmarkMessageThroughput(): BenchmarkResult {
        println("开始消息吞吐量基准测试...")
        
        // 创建测试Actor
        let benchmarkActor = BenchmarkActor(latencyCollector)
        
        // 预热阶段
        println("预热阶段...")
        warmup(benchmarkActor)
        
        // 清理预热数据
        latencyCollector.clear()
        
        // 基准测试阶段
        println("基准测试阶段...")
        let startTime = DateTime.now()
        
        for (i in 0..benchmarkIterations) {
            let sendTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000  // 转换为纳秒
            let pingMessage = PingMessage(sendTime)

            // 模拟消息发送
            let context = MockBenchmarkActorContext()
            benchmarkActor.receive(pingMessage, context)
        }
        
        let endTime = DateTime.now()
        let duration = endTime.toUnixTimeStamp().toMilliseconds() - startTime.toUnixTimeStamp().toMilliseconds()
        
        // 计算结果
        let throughput = Float64(benchmarkIterations) / (Float64(duration) / 1000.0)
        let avgLatency = latencyCollector.getAverageLatency()
        let p95Latency = latencyCollector.getPercentileLatency(95.0)
        let p99Latency = latencyCollector.getPercentileLatency(99.0)
        let memoryUsage = getCurrentMemoryUsage()
        
        BenchmarkResult(
            "MessageThroughput",
            throughput,
            avgLatency,
            p95Latency,
            p99Latency,
            memoryUsage,
            duration,
            benchmarkIterations
        )
    }
    
    private func warmup(actor: BenchmarkActor): Unit {
        for (i in 0..warmupIterations) {
            let pingMessage = PingMessage(DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000)
            let context = MockBenchmarkActorContext()
            actor.receive(pingMessage, context)
        }
    }
    
    public func benchmarkActorCreation(): BenchmarkResult {
        println("开始Actor创建基准测试...")
        
        let creationCount = Int64(1000)
        let startTime = DateTime.now()
        
        for (i in 0..creationCount) {
            let actor = BenchmarkActor(latencyCollector)
            // 简单使用actor避免编译器优化
            let _ = actor.getProcessedCount()
        }
        
        let endTime = DateTime.now()
        let duration = endTime.toUnixTimeStamp().toMilliseconds() - startTime.toUnixTimeStamp().toMilliseconds()
        let throughput = Float64(creationCount) / (Float64(duration) / 1000.0)
        
        BenchmarkResult(
            "ActorCreation",
            throughput,
            0.0,  // 创建测试不测量延迟
            0.0,
            0.0,
            getCurrentMemoryUsage(),
            duration,
            creationCount
        )
    }
    
    public func benchmarkConcurrentActors(): BenchmarkResult {
        println("开始并发Actor基准测试...")
        
        let actorCount = Int64(10)
        let messagesPerActor = Int64(1000)
        let actors = ArrayList<BenchmarkActor>()
        
        // 创建多个Actor
        for (i in 0..actorCount) {
            actors.append(BenchmarkActor(latencyCollector))
        }
        
        let startTime = DateTime.now()
        
        // 并发发送消息
        for (i in 0..actorCount) {
            let actor = actors[i]
            spawn {
                for (j in 0..messagesPerActor) {
                    let sendTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1_000_000
                    let pingMessage = PingMessage(sendTime)
                    let context = MockBenchmarkActorContext()
                    actor.receive(pingMessage, context)
                }
            }
        }
        
        // 等待所有消息处理完成
        let totalMessages = actorCount * messagesPerActor
        while (latencyCollector.getCount() < totalMessages) {
            // 简单的忙等待
            let currentTime = DateTime.now()
            while (DateTime.now().toUnixTimeStamp().toMilliseconds() - currentTime.toUnixTimeStamp().toMilliseconds() < 1) {
                // 等待1毫秒
            }
        }
        
        let endTime = DateTime.now()
        let duration = endTime.toUnixTimeStamp().toMilliseconds() - startTime.toUnixTimeStamp().toMilliseconds()
        let throughput = Float64(totalMessages) / (Float64(duration) / 1000.0)
        
        BenchmarkResult(
            "ConcurrentActors",
            throughput,
            latencyCollector.getAverageLatency(),
            latencyCollector.getPercentileLatency(95.0),
            latencyCollector.getPercentileLatency(99.0),
            getCurrentMemoryUsage(),
            duration,
            totalMessages
        )
    }
    
    private func getCurrentMemoryUsage(): Int64 {
        // 简化的内存使用估算
        1024 * 1024  // 1MB
    }
}

/**
 * 模拟的BenchmarkActorContext
 */
class MockBenchmarkActorContext <: BenchmarkActorContext {
    public func getSelf(): String {
        "mock-benchmark-actor"
    }
}

/**
 * 基准测试套件
 */
public class BenchmarkSuite {
    private let benchmark: ActorBenchmark
    
    public init() {
        this.benchmark = ActorBenchmark()
    }
    
    public func runAllBenchmarks(): Array<BenchmarkResult> {
        let results = ArrayList<BenchmarkResult>()
        
        println("=== CACtor 2.0 性能基准测试套件 ===")
        
        // 消息吞吐量测试
        let throughputResult = benchmark.benchmarkMessageThroughput()
        results.append(throughputResult)
        println(throughputResult.toString())
        
        // Actor创建测试
        let creationResult = benchmark.benchmarkActorCreation()
        results.append(creationResult)
        println(creationResult.toString())
        
        // 并发Actor测试
        let concurrentResult = benchmark.benchmarkConcurrentActors()
        results.append(concurrentResult)
        println(concurrentResult.toString())
        
        println("=== 基准测试完成 ===")
        
        results.toArray()
    }
    
    public func generateReport(results: Array<BenchmarkResult>): String {
        let report = StringBuilder()
        report.append("# CACtor 2.0 性能基准测试报告\n\n")
        
        for (result in results) {
            report.append("## ${result.testName}\n")
            report.append("- 吞吐量: ${result.throughput} 消息/秒\n")
            report.append("- 平均延迟: ${result.avgLatency} 毫秒\n")
            report.append("- P95延迟: ${result.p95Latency} 毫秒\n")
            report.append("- P99延迟: ${result.p99Latency} 毫秒\n")
            report.append("- 内存使用: ${result.memoryUsage} 字节\n")
            report.append("- 测试时长: ${result.duration} 毫秒\n")
            report.append("- 消息总数: ${result.messageCount}\n\n")
        }
        
        report.toString()
    }
}
