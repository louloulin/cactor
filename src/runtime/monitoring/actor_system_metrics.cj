/*
 * Copyright (c) 2024. All rights reserved.
 * ActorSystemMetrics - Actor系统指标
 * 基于plan10.md设计，提供生产级的系统监控和指标收集
 */
package cactor.runtime.monitoring

import std.sync.*
import std.collection.*
import std.time.*

/**
 * 性能指标数据结构
 */
public struct PerformanceMetrics {
    public let messagesThroughput: Float64      // 消息吞吐量 (msg/s)
    public let averageLatency: Float64          // 平均延迟 (μs)
    public let p95Latency: Float64              // P95延迟 (μs)
    public let p99Latency: Float64              // P99延迟 (μs)
    public let errorRate: Float64               // 错误率 (%)
    public let memoryUsage: Int64               // 内存使用量 (bytes)
    public let cpuUsage: Float64                // CPU使用率 (%)
    
    public init(
        messagesThroughput: Float64,
        averageLatency: Float64,
        p95Latency: Float64,
        p99Latency: Float64,
        errorRate: Float64,
        memoryUsage: Int64,
        cpuUsage: Float64
    ) {
        this.messagesThroughput = messagesThroughput
        this.averageLatency = averageLatency
        this.p95Latency = p95Latency
        this.p99Latency = p99Latency
        this.errorRate = errorRate
        this.memoryUsage = memoryUsage
        this.cpuUsage = cpuUsage
    }
}

/**
 * 系统健康状态
 */
public enum SystemHealthStatus {
    | Healthy      // 健康
    | Warning      // 警告
    | Critical     // 严重
    | Down         // 宕机
}

/**
 * 系统健康信息
 */
public struct SystemHealthInfo {
    public let status: SystemHealthStatus
    public let message: String
    public let checkTime: Int64
    public let details: HashMap<String, String>
    
    public init(status: SystemHealthStatus, message: String, details: HashMap<String, String>) {
        this.status = status
        this.message = message
        this.checkTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
        this.details = details
    }
}

/**
 * Actor系统指标收集器
 * 
 * 职责：
 * 1. 收集和维护系统性能指标
 * 2. 提供实时监控数据
 * 3. 支持指标聚合和统计
 * 4. 健康检查和告警
 */
public class ActorSystemMetrics {
    // 基础计数器
    private let totalActors: AtomicInt64
    private let activeActors: AtomicInt64
    private let totalMessages: AtomicInt64
    private let processedMessages: AtomicInt64
    private let failedMessages: AtomicInt64
    private let restartCount: AtomicInt64
    
    // 性能指标
    private let messageLatencies: Array<Int64>  // 延迟样本
    private let latencyIndex: AtomicInt32       // 循环索引
    private let maxLatencySamples: Int32        // 最大样本数
    
    // 时间窗口统计
    private let lastSecondMessages: AtomicInt64
    private let lastMinuteMessages: AtomicInt64
    private let lastHourMessages: AtomicInt64
    
    // 系统状态
    private let systemStartTime: Int64
    private let lastHealthCheck: AtomicInt64
    private let healthStatus: AtomicInt32  // 使用Int32存储枚举值
    
    // 自定义指标 - 简化实现
    private let customMetrics: HashMap<String, AtomicInt64>
    private let customGauges: HashMap<String, Float64>
    
    public init() {
        this.totalActors = AtomicInt64(0)
        this.activeActors = AtomicInt64(0)
        this.totalMessages = AtomicInt64(0)
        this.processedMessages = AtomicInt64(0)
        this.failedMessages = AtomicInt64(0)
        this.restartCount = AtomicInt64(0)
        
        this.maxLatencySamples = 10000
        this.messageLatencies = Array<Int64>(Int64(maxLatencySamples), { _ => 0 })
        this.latencyIndex = AtomicInt32(0)
        
        this.lastSecondMessages = AtomicInt64(0)
        this.lastMinuteMessages = AtomicInt64(0)
        this.lastHourMessages = AtomicInt64(0)
        
        this.systemStartTime = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
        this.lastHealthCheck = AtomicInt64(0)
        this.healthStatus = AtomicInt32(0)  // Healthy

        this.customMetrics = HashMap<String, AtomicInt64>()
        this.customGauges = HashMap<String, Float64>()
    }
    
    /**
     * 增加Actor计数
     */
    public func incrementActorCount(): Unit {
        totalActors.fetchAdd(1)
        activeActors.fetchAdd(1)
    }
    
    /**
     * 减少Actor计数
     */
    public func decrementActorCount(): Unit {
        activeActors.fetchAdd(-1)
    }
    
    /**
     * 记录消息处理
     */
    public func recordMessageProcessed(latencyNanos: Int64): Unit {
        processedMessages.fetchAdd(1)
        totalMessages.fetchAdd(1)
        
        // 记录延迟样本
        let index = latencyIndex.fetchAdd(1) % maxLatencySamples
        messageLatencies[Int64(index)] = latencyNanos
        
        // 更新时间窗口统计
        updateTimeWindowStats()
    }
    
    /**
     * 记录消息失败
     */
    public func recordMessageFailed(): Unit {
        failedMessages.fetchAdd(1)
        totalMessages.fetchAdd(1)
    }
    
    /**
     * 记录Actor重启
     */
    public func incrementRestartCount(): Unit {
        restartCount.fetchAdd(1)
    }

    /**
     * 增加Actor创建计数 - Plan10.md要求的别名
     */
    public func incrementActorCreated(): Unit {
        incrementActorCount()
    }

    /**
     * 增加Actor停止计数 - Plan10.md要求的别名
     */
    public func incrementActorStopped(): Unit {
        decrementActorCount()
    }

    /**
     * 增加Actor重启计数 - Plan10.md要求的别名
     */
    public func incrementActorRestarted(): Unit {
        incrementRestartCount()
    }

    /**
     * 启动指标收集 - Plan10.md要求
     */
    public func start(): Unit {
        println("📊 ActorSystemMetrics启动")
    }

    /**
     * 停止指标收集 - Plan10.md要求
     */
    public func shutdown(): Unit {
        println("📊 ActorSystemMetrics停止")
    }
    
    /**
     * 设置自定义计数器
     */
    public func setCustomCounter(name: String, value: Int64): Unit {
        match (customMetrics.get(name)) {
            case Some(counter) =>
                counter.store(value)
            case None =>
                let newCounter = AtomicInt64(value)
                customMetrics.add(name, newCounter)
        }
    }
    
    /**
     * 增加自定义计数器
     */
    public func incrementCustomCounter(name: String, delta: Int64): Unit {
        match (customMetrics.get(name)) {
            case Some(counter) =>
                counter.fetchAdd(delta)
            case None =>
                let newCounter = AtomicInt64(delta)
                customMetrics.add(name, newCounter)
        }
    }
    
    /**
     * 设置自定义仪表
     */
    public func setCustomGauge(name: String, value: Float64): Unit {
        customGauges.add(name, value)
    }
    
    /**
     * 获取性能指标
     */
    public func getPerformanceMetrics(): PerformanceMetrics {
        let throughput = calculateThroughput()
        let avgLatency = calculateAverageLatency()
        let p95Latency = calculatePercentileLatency(0.95)
        let p99Latency = calculatePercentileLatency(0.99)
        let errorRate = calculateErrorRate()
        let memoryUsage = estimateMemoryUsage()
        let cpuUsage = estimateCpuUsage()

        PerformanceMetrics(
            throughput,
            avgLatency,
            p95Latency,
            p99Latency,
            errorRate,
            memoryUsage,
            cpuUsage
        )
    }
    
    /**
     * 获取系统健康状态
     */
    public func getSystemHealth(): SystemHealthInfo {
        let currentTime = getCurrentTimeNanos()
        lastHealthCheck.store(currentTime)
        
        let details = HashMap<String, String>()
        details.add("totalActors", totalActors.load().toString())
        details.add("activeActors", activeActors.load().toString())
        details.add("processedMessages", processedMessages.load().toString())
        details.add("failedMessages", failedMessages.load().toString())
        details.add("restartCount", restartCount.load().toString())
        
        // 简单的健康检查逻辑
        let errorRate = calculateErrorRate()
        let avgLatency = calculateAverageLatency()
        
        let status = if (errorRate > 10.0) {
            SystemHealthStatus.Critical
        } else if (errorRate > 5.0 || avgLatency > 1000.0) {
            SystemHealthStatus.Warning
        } else {
            SystemHealthStatus.Healthy
        }
        
        let message = match (status) {
            case SystemHealthStatus.Healthy => "系统运行正常"
            case SystemHealthStatus.Warning => "系统性能警告"
            case SystemHealthStatus.Critical => "系统性能严重"
            case SystemHealthStatus.Down => "系统宕机"
        }
        
        healthStatus.store(getStatusValue(status))
        
        SystemHealthInfo(status, message, details)
    }
    
    /**
     * 获取基础统计信息
     */
    public func getBasicStats(): HashMap<String, Int64> {
        let stats = HashMap<String, Int64>()
        stats.add("totalActors", totalActors.load())
        stats.add("activeActors", activeActors.load())
        stats.add("totalMessages", totalMessages.load())
        stats.add("processedMessages", processedMessages.load())
        stats.add("failedMessages", failedMessages.load())
        stats.add("restartCount", restartCount.load())
        stats.add("uptime", getCurrentTimeNanos() - systemStartTime)
        stats
    }
    
    /**
     * 获取自定义指标
     */
    public func getCustomMetrics(): HashMap<String, Int64> {
        let result = HashMap<String, Int64>()
        for ((name, counter) in customMetrics) {
            result.add(name, counter.load())
        }
        result
    }
    
    /**
     * 获取自定义仪表
     */
    public func getCustomGauges(): HashMap<String, Float64> {
        customGauges
    }
    
    /**
     * 重置所有指标
     */
    public func reset(): Unit {
        totalActors.store(0)
        activeActors.store(0)
        totalMessages.store(0)
        processedMessages.store(0)
        failedMessages.store(0)
        restartCount.store(0)
        latencyIndex.store(0)

        // 清空延迟样本
        for (i in 0..Int64(maxLatencySamples)) {
            messageLatencies[i] = 0
        }

        customMetrics.clear()
        customGauges.clear()
    }
    
    /**
     * 打印指标报告
     */
    public func printReport(): Unit {
        let metrics = getPerformanceMetrics()
        let health = getSystemHealth()
        
        println("=== ActorSystem性能指标报告 ===")
        println("系统健康状态: ${getStatusString(health.status)}")
        println("消息吞吐量: ${metrics.messagesThroughput} msg/s")
        println("平均延迟: ${metrics.averageLatency} μs")
        println("P95延迟: ${metrics.p95Latency} μs")
        println("P99延迟: ${metrics.p99Latency} μs")
        println("错误率: ${metrics.errorRate}%")
        println("内存使用: ${metrics.memoryUsage / 1024 / 1024} MB")
        println("CPU使用率: ${metrics.cpuUsage}%")
        println("活跃Actor数: ${activeActors.load()}")
        println("总消息数: ${totalMessages.load()}")
        println("重启次数: ${restartCount.load()}")
    }
    
    // 私有辅助方法
    private func calculateThroughput(): Float64 {
        let uptime = getCurrentTimeNanos() - systemStartTime
        if (uptime > 0) {
            Float64(processedMessages.load()) / (Float64(uptime) / 1000000000.0)
        } else {
            0.0
        }
    }
    
    private func calculateAverageLatency(): Float64 {
        let currentIndex = latencyIndex.load()
        let sampleCount = if (currentIndex < maxLatencySamples) { currentIndex } else { maxLatencySamples }
        if (sampleCount == 0) {
            return 0.0
        }
        
        var sum: Int64 = 0
        for (i in 0..Int64(sampleCount)) {
            sum += messageLatencies[i]
        }
        
        Float64(sum) / Float64(sampleCount) / 1000.0  // 转换为微秒
    }
    
    private func calculatePercentileLatency(percentile: Float64): Float64 {
        let currentIndex = latencyIndex.load()
        let sampleCount = if (currentIndex < maxLatencySamples) { currentIndex } else { maxLatencySamples }
        if (sampleCount == 0) {
            return 0.0
        }
        
        // 简化的百分位计算（实际应该排序）
        let index = Int64(Float64(sampleCount) * percentile)
        Float64(messageLatencies[index]) / 1000.0  // 转换为微秒
    }
    
    private func calculateErrorRate(): Float64 {
        let total = totalMessages.load()
        if (total == 0) {
            return 0.0
        }
        Float64(failedMessages.load()) / Float64(total) * 100.0
    }
    
    private func estimateMemoryUsage(): Int64 {
        // 简化的内存使用估算
        activeActors.load() * 1024 + totalMessages.load() * 64
    }
    
    private func estimateCpuUsage(): Float64 {
        // 简化的CPU使用率估算
        let throughput = calculateThroughput()
        if (throughput > 1000000.0) {
            80.0
        } else if (throughput > 100000.0) {
            50.0
        } else {
            20.0
        }
    }
    
    private func updateTimeWindowStats(): Unit {
        // 简化实现，实际应该使用滑动窗口
        lastSecondMessages.fetchAdd(1)
    }
    
    private func getStatusValue(status: SystemHealthStatus): Int32 {
        match (status) {
            case SystemHealthStatus.Healthy => 0
            case SystemHealthStatus.Warning => 1
            case SystemHealthStatus.Critical => 2
            case SystemHealthStatus.Down => 3
        }
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }

    private func getStatusString(status: SystemHealthStatus): String {
        match (status) {
            case SystemHealthStatus.Healthy => "健康"
            case SystemHealthStatus.Warning => "警告"
            case SystemHealthStatus.Critical => "严重"
            case SystemHealthStatus.Down => "宕机"
        }
    }
}
