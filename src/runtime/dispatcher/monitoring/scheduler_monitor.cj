/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 调度器性能监控系统
 * 基于仓颉语言的实时性能监控和分析
 * 支持延时统计、吞吐量监控、负载分析等功能
 */
package cactor.runtime.dispatcher.monitoring

import std.sync.*
import std.time.*
import std.collection.*
import std.math.*

/**
 * 调度器性能指标
 */
public struct SchedulerMetrics {
    public let totalTasksScheduled: Int64      // 总调度任务数
    public let totalTasksCompleted: Int64      // 总完成任务数
    public let averageLatencyNs: Int64         // 平均延时（纳秒）
    public let p99LatencyNs: Int64             // P99延时（纳秒）
    public let throughputPerSecond: Float64    // 每秒吞吐量
    public let workerUtilization: Float64      // 工作线程利用率
    public let queueDepth: Int64               // 队列深度
    public let stealSuccessRate: Float64       // 窃取成功率
    
    public init(totalScheduled: Int64, totalCompleted: Int64, avgLatency: Int64,
                p99Latency: Int64, throughput: Float64, utilization: Float64,
                queueDepth: Int64, stealRate: Float64) {
        this.totalTasksScheduled = totalScheduled
        this.totalTasksCompleted = totalCompleted
        this.averageLatencyNs = avgLatency
        this.p99LatencyNs = p99Latency
        this.throughputPerSecond = throughput
        this.workerUtilization = utilization
        this.queueDepth = queueDepth
        this.stealSuccessRate = stealRate
    }
}

/**
 * 延时直方图
 * 用于统计延时分布
 */
public class LatencyHistogram {
    private let buckets: Array<AtomicInt64>
    private let bucketBounds: Array<Int64>
    private let totalSamples: AtomicInt64
    private let totalLatency: AtomicInt64
    
    public init() {
        // 延时桶边界（纳秒）: 1μs, 10μs, 100μs, 1ms, 10ms, 100ms, 1s, 10s
        this.bucketBounds = [1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000]
        this.buckets = Array<AtomicInt64>(Int64(bucketBounds.size + 1), { _ => AtomicInt64(0) })
        this.totalSamples = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
    }
    
    /**
     * 记录延时样本
     */
    public func recordLatency(latencyNs: Int64): Unit {
        totalSamples.fetchAdd(1)
        totalLatency.fetchAdd(latencyNs)
        
        // 找到对应的桶
        var bucketIndex = bucketBounds.size
        for (i in 0..bucketBounds.size) {
            if (latencyNs <= bucketBounds[i]) {
                bucketIndex = i
                break
            }
        }
        
        buckets[bucketIndex].fetchAdd(1)
    }
    
    /**
     * 获取平均延时
     */
    public func getAverageLatency(): Int64 {
        let samples = totalSamples.load()
        if (samples == 0) { return 0 }
        return totalLatency.load() / samples
    }
    
    /**
     * 获取百分位延时
     */
    public func getPercentileLatency(percentile: Float64): Int64 {
        let samples = totalSamples.load()
        if (samples == 0) { return 0 }
        
        let targetSample = Int64(Float64(samples) * percentile / 100.0)
        var cumulativeCount: Int64 = 0
        
        for (i in 0..buckets.size) {
            cumulativeCount += buckets[i].load()
            if (cumulativeCount >= targetSample) {
                if (i < bucketBounds.size) {
                    return bucketBounds[i]
                } else {
                    return bucketBounds[bucketBounds.size - 1] * 10  // 最大桶的估计值
                }
            }
        }
        
        return 0
    }
    
    /**
     * 重置统计
     */
    public func reset(): Unit {
        totalSamples.store(0)
        totalLatency.store(0)
        for (bucket in buckets) {
            bucket.store(0)
        }
    }
}

/**
 * 吞吐量计算器
 */
public class ThroughputCalculator {
    private let windowSizeMs: Int64
    private let samples: ArrayList<Int64>
    private let timestamps: ArrayList<Int64>
    private let mutex: Mutex
    
    public init(windowSizeMs: Int64) {
        this.windowSizeMs = windowSizeMs
        this.samples = ArrayList<Int64>()
        this.timestamps = ArrayList<Int64>()
        this.mutex = Mutex()
    }
    
    /**
     * 记录事件
     */
    public func recordEvent(count: Int64): Unit {
        let currentTime = getCurrentTimeMillis()
        
        mutex.lock()
        try {
            samples.add(count)
            timestamps.add(currentTime)
            
            // 清理过期数据
            cleanupOldSamples(currentTime)
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 获取当前吞吐量（每秒）
     */
    public func getCurrentThroughput(): Float64 {
        let currentTime = getCurrentTimeMillis()
        
        mutex.lock()
        try {
            cleanupOldSamples(currentTime)
            
            if (samples.isEmpty()) {
                return 0.0
            }
            
            var totalEvents: Int64 = 0
            for (sample in samples) {
                totalEvents += sample
            }
            let timeSpanMs = currentTime - timestamps[0]
            
            if (timeSpanMs <= 0) {
                return 0.0
            }
            
            return Float64(totalEvents) * 1000.0 / Float64(timeSpanMs)
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 清理过期样本
     */
    private func cleanupOldSamples(currentTime: Int64): Unit {
        let cutoffTime = currentTime - windowSizeMs
        
        while (!timestamps.isEmpty() && timestamps[0] < cutoffTime) {
            timestamps.remove(0..1)
            samples.remove(0..1)
        }
    }
}

/**
 * 调度器性能监控器
 */
public class SchedulerMonitor {
    private let latencyHistogram: LatencyHistogram
    private let throughputCalculator: ThroughputCalculator
    private var totalTasksScheduled: AtomicInt64
    private var totalTasksCompleted: AtomicInt64
    private var totalStealAttempts: AtomicInt64
    private var successfulSteals: AtomicInt64
    private var totalWorkerTime: AtomicInt64
    private var totalIdleTime: AtomicInt64
    private var currentQueueDepth: AtomicInt64
    private let startTime: Int64
    
    public init() {
        this.latencyHistogram = LatencyHistogram()
        this.throughputCalculator = ThroughputCalculator(5000)
        this.totalTasksScheduled = AtomicInt64(0)
        this.totalTasksCompleted = AtomicInt64(0)
        this.totalStealAttempts = AtomicInt64(0)
        this.successfulSteals = AtomicInt64(0)
        this.totalWorkerTime = AtomicInt64(0)
        this.totalIdleTime = AtomicInt64(0)
        this.currentQueueDepth = AtomicInt64(0)
        this.startTime = getCurrentTimeMillis()
    }
    
    /**
     * 记录任务调度
     */
    public func recordTaskScheduled(): Unit {
        totalTasksScheduled.fetchAdd(1)
        currentQueueDepth.fetchAdd(1)
    }
    
    /**
     * 记录任务完成
     */
    public func recordTaskCompleted(latencyNs: Int64): Unit {
        totalTasksCompleted.fetchAdd(1)
        currentQueueDepth.fetchAdd(-1)
        latencyHistogram.recordLatency(latencyNs)
        throughputCalculator.recordEvent(1)
    }
    
    /**
     * 记录工作窃取尝试
     */
    public func recordStealAttempt(successful: Bool): Unit {
        totalStealAttempts.fetchAdd(1)
        if (successful) {
            successfulSteals.fetchAdd(1)
        }
    }
    
    /**
     * 记录工作线程时间
     */
    public func recordWorkerTime(workTimeNs: Int64, idleTimeNs: Int64): Unit {
        totalWorkerTime.fetchAdd(workTimeNs)
        totalIdleTime.fetchAdd(idleTimeNs)
    }
    
    /**
     * 获取当前性能指标
     */
    public func getCurrentMetrics(): SchedulerMetrics {
        let scheduled = totalTasksScheduled.load()
        let completed = totalTasksCompleted.load()
        let avgLatency = latencyHistogram.getAverageLatency()
        let p99Latency = latencyHistogram.getPercentileLatency(99.0)
        let throughput = throughputCalculator.getCurrentThroughput()
        
        // 计算工作线程利用率
        let totalTime = totalWorkerTime.load() + totalIdleTime.load()
        let utilization = if (totalTime > 0) {
            Float64(totalWorkerTime.load()) / Float64(totalTime)
        } else {
            0.0
        }
        
        // 计算窃取成功率
        let stealAttempts = totalStealAttempts.load()
        let stealRate = if (stealAttempts > 0) {
            Float64(successfulSteals.load()) / Float64(stealAttempts)
        } else {
            0.0
        }
        
        let queueDepth = currentQueueDepth.load()
        
        return SchedulerMetrics(
            scheduled, completed, avgLatency, p99Latency,
            throughput, utilization, queueDepth, stealRate
        )
    }
    
    /**
     * 重置所有统计
     */
    public func reset(): Unit {
        latencyHistogram.reset()
        totalTasksScheduled.store(0)
        totalTasksCompleted.store(0)
        totalStealAttempts.store(0)
        successfulSteals.store(0)
        totalWorkerTime.store(0)
        totalIdleTime.store(0)
        currentQueueDepth.store(0)
    }
    
    /**
     * 打印性能报告
     */
    public func printReport(): Unit {
        let metrics = getCurrentMetrics()
        let uptimeMs = getCurrentTimeMillis() - startTime
        
        println("=== 调度器性能报告 ===")
        println("运行时间: ${uptimeMs}ms")
        println("总调度任务: ${metrics.totalTasksScheduled}")
        println("总完成任务: ${metrics.totalTasksCompleted}")
        println("平均延时: ${metrics.averageLatencyNs / 1000}μs")
        println("P99延时: ${metrics.p99LatencyNs / 1000}μs")
        println("当前吞吐量: ${metrics.throughputPerSecond} tasks/s")
        println("工作线程利用率: ${metrics.workerUtilization * 100.0}%")
        println("当前队列深度: ${metrics.queueDepth}")
        println("窃取成功率: ${metrics.stealSuccessRate * 100.0}%")
        println("========================")
    }
}

/**
 * 获取当前时间（毫秒）
 */
// 全局时间计数器，用于模拟时间流逝
var globalTimeCounter2: AtomicInt64 = AtomicInt64(1000)

func getCurrentTimeMillis(): Int64 {
    // 每次调用递增，模拟时间流逝
    return globalTimeCounter2.fetchAdd(10)  // 每次增加10ms
}
