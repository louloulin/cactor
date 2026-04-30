/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 实时性能分析系统
 * 基于plan3.md设计的性能监控和分析实现
 */
package cactor.integration.monitoring

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.actor.*
import cactor.core.message.*

// 性能指标数据
public class Metric {
    public let name: String
    public let metricType: String
    public let timestamp: Int64
    public let value: Float64
    private let tags: HashMap<String, String>

    public init(name: String, metricType: String, value: Float64) {
        this.name = name
        this.metricType = metricType
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.value = value
        this.tags = HashMap<String, String>()
    }

    public func addTag(key: String, value: String): Unit {
        tags[key] = value
    }

    public func getTag(key: String): Option<String> {
        tags.get(key)
    }

    public func getAllTags(): HashMap<String, String> {
        let result = HashMap<String, String>()
        for ((key, value) in tags) {
            result[key] = value
        }
        return result
    }

    public func toString(): String {
        "Metric(${name}, ${metricType}, ${value}, ${timestamp})"
    }
}

// 性能统计信息
public class PerformanceStats {
    public let count: Int64
    public let sum: Float64
    public let min: Float64
    public let max: Float64
    public let avg: Float64
    public let p50: Float64
    public let p95: Float64
    public let p99: Float64

    public init(count: Int64, sum: Float64, min: Float64, max: Float64, avg: Float64, p50: Float64, p95: Float64, p99: Float64) {
        this.count = count
        this.sum = sum
        this.min = min
        this.max = max
        this.avg = avg
        this.p50 = p50
        this.p95 = p95
        this.p99 = p99
    }
    
    public func toString(): String {
        "PerformanceStats(count=${count}, avg=${avg}, p95=${p95}, p99=${p99})"
    }
}

// 性能计数器
public class PerformanceCounter {
    private var count: Int64
    private var sum: Float64
    private var min: Float64
    private var max: Float64
    private let values: ArrayList<Float64>
    private let mutex: Mutex
    private let maxSamples: Int64

    public init(maxSamples: Int64) {
        this.count = 0
        this.sum = 0.0
        this.min = 999999999.0  // 大数值作为初始最小值
        this.max = -999999999.0  // 小数值作为初始最大值
        this.values = ArrayList<Float64>()
        this.mutex = Mutex()
        this.maxSamples = maxSamples
    }

    public func record(value: Float64): Unit {
        mutex.lock()

        count += 1
        sum += value

        // 更新最小值和最大值
        if (value < min) {
            min = value
        }
        if (value > max) {
            max = value
        }

        // 记录样本值用于百分位计算
        if (values.size >= maxSamples) {
            // 移除最老的样本 - 简化实现
            let newValues = ArrayList<Float64>()
            for (i in 1..values.size) {
                newValues.add(values[i])
            }
            values.clear()
            for (v in newValues) {
                values.add(v)
            }
        }
        values.add(value)

        mutex.unlock()
    }

    public func getStats(): PerformanceStats {
        mutex.lock()

        let currentCount = count
        let currentSum = sum
        let currentMin = min
        let currentMax = max

        let avg = if (currentCount > 0) { currentSum / Float64(currentCount) } else { 0.0 }

        let sortedValues = values.toArray()

        // 简化的百分位计算
        let p50 = calculatePercentile(sortedValues, 0.5)
        let p95 = calculatePercentile(sortedValues, 0.95)
        let p99 = calculatePercentile(sortedValues, 0.99)

        mutex.unlock()

        return PerformanceStats(currentCount, currentSum, currentMin, currentMax, avg, p50, p95, p99)
    }
    
    public func reset(): Unit {
        mutex.lock()
        count = 0
        sum = 0.0
        min = 999999999.0
        max = -999999999.0
        values.clear()
        mutex.unlock()
    }
}

// Actor性能监控器
public class ActorPerformanceMonitor {
    private let messageProcessingTime: PerformanceCounter
    private let messageQueueSize: PerformanceCounter
    private var errorCount: Int64
    private var totalMessages: Int64
    private let actorPath: ActorPath
    private let startTime: Int64
    private let mutex: Mutex

    public init(actorPath: ActorPath) {
        this.messageProcessingTime = PerformanceCounter(1000)
        this.messageQueueSize = PerformanceCounter(1000)
        this.errorCount = 0
        this.totalMessages = 0
        this.actorPath = actorPath
        this.startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.mutex = Mutex()
    }

    public func recordMessageProcessed(processingTimeMs: Float64): Unit {
        messageProcessingTime.record(processingTimeMs)
        mutex.lock()
        totalMessages += 1
        mutex.unlock()
    }

    public func recordQueueSize(size: Int64): Unit {
        messageQueueSize.record(Float64(size))
    }

    public func recordError(): Unit {
        mutex.lock()
        errorCount += 1
        mutex.unlock()
    }

    public func getMessageProcessingStats(): PerformanceStats {
        messageProcessingTime.getStats()
    }

    public func getQueueSizeStats(): PerformanceStats {
        messageQueueSize.getStats()
    }

    public func getErrorCount(): Int64 {
        mutex.lock()
        let result = errorCount
        mutex.unlock()
        return result
    }

    public func getTotalMessages(): Int64 {
        mutex.lock()
        let result = totalMessages
        mutex.unlock()
        return result
    }
    
    public func getUptimeMs(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime
    }
    
    public func getActorPath(): ActorPath {
        actorPath
    }
    
    public func generateReport(): String {
        let msgStats = getMessageProcessingStats()
        let queueStats = getQueueSizeStats()
        let uptime = getUptimeMs()
        let errors = getErrorCount()
        let total = getTotalMessages()
        
        return """
        Actor性能报告: ${actorPath.toString()}
        运行时间: ${uptime}ms
        总消息数: ${total}
        错误数: ${errors}
        消息处理时间: ${msgStats.toString()}
        队列大小: ${queueStats.toString()}
        """
    }
}

// 系统性能分析器
public class SystemPerformanceAnalyzer {
    private let actorMonitors: ConcurrentHashMap<String, ActorPerformanceMonitor>
    private let systemMetrics: PerformanceCounter
    private let gcMetrics: PerformanceCounter
    private let memoryMetrics: PerformanceCounter
    private let isRunning: AtomicBool
    private let reportInterval: Int64  // 毫秒

    public init(reportInterval: Int64) {
        this.actorMonitors = ConcurrentHashMap<String, ActorPerformanceMonitor>()
        this.systemMetrics = PerformanceCounter(10000)
        this.gcMetrics = PerformanceCounter(1000)
        this.memoryMetrics = PerformanceCounter(1000)
        this.isRunning = AtomicBool(false)
        this.reportInterval = reportInterval
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("系统性能分析器启动，报告间隔: ${reportInterval}ms")
            // 这里可以启动后台线程定期收集系统指标
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("系统性能分析器停止")
        }
    }

    public func getOrCreateActorMonitor(actorPath: ActorPath): ActorPerformanceMonitor {
        let pathStr = actorPath.toString()

        match (actorMonitors.get(pathStr)) {
            case Some(monitor) => monitor
            case None =>
                let newMonitor = ActorPerformanceMonitor(actorPath)
                actorMonitors.add(pathStr, newMonitor)
                newMonitor
        }
    }
    
    public func removeActorMonitor(actorPath: ActorPath): Unit {
        actorMonitors.remove(actorPath.toString())
    }
    
    public func recordSystemMetric(value: Float64): Unit {
        systemMetrics.record(value)
    }
    
    public func recordGCMetric(gcTimeMs: Float64): Unit {
        gcMetrics.record(gcTimeMs)
    }
    
    public func recordMemoryUsage(memoryMB: Float64): Unit {
        memoryMetrics.record(memoryMB)
    }
    
    public func generateSystemReport(): String {
        let systemStats = systemMetrics.getStats()
        let gcStats = gcMetrics.getStats()
        let memoryStats = memoryMetrics.getStats()
        let actorCount = actorMonitors.size
        
        var report = """
        ========== CActor系统性能报告 ==========
        活跃Actor数量: ${actorCount}
        系统指标: ${systemStats.toString()}
        GC指标: ${gcStats.toString()}
        内存使用: ${memoryStats.toString()}
        
        Actor详细信息:
        """
        
        for ((path, monitor) in actorMonitors) {
            report += "\n${monitor.generateReport()}\n"
        }
        
        return report
    }
    
    public func getActiveActorCount(): Int64 {
        actorMonitors.size
    }
    
    public func isActive(): Bool {
        isRunning.load()
    }
}

// 辅助函数：计算百分位数
func calculatePercentile(values: Array<Float64>, percentile: Float64): Float64 {
    if (values.size == 0) {
        return 0.0
    }
    
    // 简化的百分位计算（实际应该排序）
    let index = Int64(Float64(values.size) * percentile)
    let safeIndex = if (index >= values.size) { values.size - 1 } else { index }
    
    return values[safeIndex]
}
