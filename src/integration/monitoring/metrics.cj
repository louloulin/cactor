/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 性能监控
 * 提供系统性能指标收集和监控功能
 */
package cactor.integration.monitoring

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*

/**
 * 指标类型
 */
public enum MetricType {
    | Counter     // 计数器
    | Gauge       // 仪表盘
    | Histogram   // 直方图
    | Timer       // 计时器
}

/**
 * 指标值
 */
public struct MetricValue {
    public let value: Float64
    public let timestamp: Int64
    public let tags: HashMap<String, String>

    public init(value: Float64, timestamp: Int64, tags: HashMap<String, String>) {
        this.value = value
        this.timestamp = timestamp
        this.tags = tags
    }

    public init(value: Float64) {
        this.value = value
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.tags = HashMap<String, String>()
    }
}

/**
 * 计数器指标
 */
public class Counter {
    private let value: AtomicInt64
    private let name: String
    private let tags: HashMap<String, String>

    public init(name: String, tags: HashMap<String, String>) {
        this.value = AtomicInt64(0)
        this.name = name
        this.tags = tags
    }

    public init(name: String) {
        this.value = AtomicInt64(0)
        this.name = name
        this.tags = HashMap<String, String>()
    }

    public func increment(): Unit {
        value.fetchAdd(1)
    }

    public func increment(delta: Int64): Unit {
        value.fetchAdd(delta)
    }

    public func get(): Int64 {
        value.load()
    }

    public func reset(): Unit {
        value.store(0)
    }

    public func getName(): String {
        name
    }

    public func getTags(): HashMap<String, String> {
        tags
    }
}

/**
 * 仪表盘指标
 */
public class Gauge {
    private let value: AtomicInt64  // 使用整数表示，实际值需要除以1000
    private let name: String
    private let tags: HashMap<String, String>

    public init(name: String, tags: HashMap<String, String>) {
        this.value = AtomicInt64(0)
        this.name = name
        this.tags = tags
    }

    public init(name: String) {
        this.value = AtomicInt64(0)
        this.name = name
        this.tags = HashMap<String, String>()
    }

    public func set(newValue: Float64): Unit {
        value.store(Int64(newValue * 1000.0))
    }

    public func get(): Float64 {
        Float64(value.load()) / 1000.0
    }

    public func increment(): Unit {
        value.fetchAdd(1000)
    }

    public func decrement(): Unit {
        value.fetchAdd(-1000)
    }

    public func getName(): String {
        name
    }

    public func getTags(): HashMap<String, String> {
        tags
    }
}

/**
 * 直方图指标
 */
public class Histogram {
    private let buckets: Array<Int64>
    private let counts: Array<AtomicInt64>
    private let totalCount: AtomicInt64
    private let totalSum: AtomicInt64  // 使用整数表示，实际值需要除以1000
    private let name: String
    private let tags: HashMap<String, String>

    public init(name: String, buckets: Array<Int64>, tags: HashMap<String, String>) {
        this.buckets = buckets
        this.counts = Array<AtomicInt64>(buckets.size, { _ => AtomicInt64(0) })
        this.totalCount = AtomicInt64(0)
        this.totalSum = AtomicInt64(0)
        this.name = name
        this.tags = tags
    }

    public init(name: String, buckets: Array<Int64>) {
        this.buckets = buckets
        this.counts = Array<AtomicInt64>(buckets.size, { _ => AtomicInt64(0) })
        this.totalCount = AtomicInt64(0)
        this.totalSum = AtomicInt64(0)
        this.name = name
        this.tags = HashMap<String, String>()
    }

    public func observe(value: Float64): Unit {
        let intValue = Int64(value * 1000.0)
        totalCount.fetchAdd(1)
        totalSum.fetchAdd(intValue)

        for (i in 0..buckets.size) {
            if (intValue <= buckets[i] * 1000) {
                counts[i].fetchAdd(1)
                break
            }
        }
    }

    public func getCount(): Int64 {
        totalCount.load()
    }

    public func getSum(): Float64 {
        Float64(totalSum.load()) / 1000.0
    }

    public func getMean(): Float64 {
        let count = totalCount.load()
        if (count == 0) {
            return 0.0
        }
        Float64(totalSum.load()) / (Float64(count) * 1000.0)
    }

    public func getBucketCount(bucketIndex: Int64): Int64 {
        if (bucketIndex >= 0 && bucketIndex < Int64(counts.size)) {
            counts[bucketIndex].load()
        } else {
            0
        }
    }

    public func getName(): String {
        name
    }

    public func getTags(): HashMap<String, String> {
        tags
    }
}

/**
 * 计时器指标
 */
public class Timer {
    private let histogram: Histogram
    private let name: String

    public init(name: String, tags: HashMap<String, String>) {
        // 默认的时间桶（毫秒）
        let buckets = [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
        this.histogram = Histogram(name, buckets, tags)
        this.name = name
    }

    public init(name: String) {
        let buckets = [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
        this.histogram = Histogram(name, buckets, HashMap<String, String>())
        this.name = name
    }

    public func time<T>(operation: () -> T): T {
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let result = operation()
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = Float64(endTime - startTime)
        histogram.observe(duration)
        result
    }

    public func record(duration: Duration): Unit {
        histogram.observe(Float64(duration.toMilliseconds()))
    }

    public func getCount(): Int64 {
        histogram.getCount()
    }

    public func getMean(): Float64 {
        histogram.getMean()
    }

    public func getTotalTime(): Float64 {
        histogram.getSum()
    }

    public func getName(): String {
        name
    }

    public func getHistogram(): Histogram {
        histogram
    }
}

/**
 * 指标注册表
 */
public class MetricRegistry {
    private let counters: ConcurrentHashMap<String, Counter>
    private let gauges: ConcurrentHashMap<String, Gauge>
    private let histograms: ConcurrentHashMap<String, Histogram>
    private let timers: ConcurrentHashMap<String, Timer>
    private let mutex: Mutex

    public init() {
        this.counters = ConcurrentHashMap<String, Counter>()
        this.gauges = ConcurrentHashMap<String, Gauge>()
        this.histograms = ConcurrentHashMap<String, Histogram>()
        this.timers = ConcurrentHashMap<String, Timer>()
        this.mutex = Mutex()
    }

    public func counter(name: String): Counter {
        match (counters.get(name)) {
            case Some(counter) => counter
            case None => 
                let newCounter = Counter(name)
                counters.add(name, newCounter)
                newCounter
        }
    }

    public func counter(name: String, tags: HashMap<String, String>): Counter {
        let key = "${name}:${tagsToString(tags)}"
        match (counters.get(key)) {
            case Some(counter) => counter
            case None => 
                let newCounter = Counter(name, tags)
                counters.add(key, newCounter)
                newCounter
        }
    }

    public func gauge(name: String): Gauge {
        match (gauges.get(name)) {
            case Some(gauge) => gauge
            case None => 
                let newGauge = Gauge(name)
                gauges.add(name, newGauge)
                newGauge
        }
    }

    public func histogram(name: String, buckets: Array<Int64>): Histogram {
        match (histograms.get(name)) {
            case Some(histogram) => histogram
            case None => 
                let newHistogram = Histogram(name, buckets)
                histograms.add(name, newHistogram)
                newHistogram
        }
    }

    public func timer(name: String): Timer {
        match (timers.get(name)) {
            case Some(timer) => timer
            case None => 
                let newTimer = Timer(name)
                timers.add(name, newTimer)
                newTimer
        }
    }

    private func tagsToString(tags: HashMap<String, String>): String {
        // 简化实现，实际应该排序并格式化
        "tags"
    }

    public func getAllCounters(): Array<Counter> {
        let result = ArrayList<Counter>()
        for ((_, counter) in counters) {
            result.add(counter)
        }
        result.toArray()
    }

    public func getAllGauges(): Array<Gauge> {
        let result = ArrayList<Gauge>()
        for ((_, gauge) in gauges) {
            result.add(gauge)
        }
        result.toArray()
    }

    public func getAllTimers(): Array<Timer> {
        let result = ArrayList<Timer>()
        for ((_, timer) in timers) {
            result.add(timer)
        }
        result.toArray()
    }

    public func clear(): Unit {
        mutex.lock()
        try {
            // 重新创建空的映射
            // 注意：这是简化实现，实际应该有更好的清理方法
            println("清理指标注册表")
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 全局指标注册表
 */
public struct Metrics {
    private static let registry: MetricRegistry = MetricRegistry()

    public static func counter(name: String): Counter {
        registry.counter(name)
    }

    public static func gauge(name: String): Gauge {
        registry.gauge(name)
    }

    public static func timer(name: String): Timer {
        registry.timer(name)
    }

    public static func getRegistry(): MetricRegistry {
        registry
    }
}

/**
 * 性能监控器
 */
public class PerformanceMonitor {
    private let messageProcessedCounter: Counter
    private let messageProcessingTimer: Timer
    private let actorCreatedCounter: Counter
    private let actorStoppedCounter: Counter
    private let mailboxSizeGauge: Gauge
    private let errorCounter: Counter
    private let enabled: AtomicBool

    public init() {
        this.messageProcessedCounter = Metrics.counter("cactor.messages.processed")
        this.messageProcessingTimer = Metrics.timer("cactor.messages.processing.time")
        this.actorCreatedCounter = Metrics.counter("cactor.actors.created")
        this.actorStoppedCounter = Metrics.counter("cactor.actors.stopped")
        this.mailboxSizeGauge = Metrics.gauge("cactor.mailbox.size")
        this.errorCounter = Metrics.counter("cactor.errors")
        this.enabled = AtomicBool(true)
    }

    public func recordMessageProcessed(): Unit {
        if (enabled.load()) {
            messageProcessedCounter.increment()
        }
    }

    public func recordMessageProcessingTime<T>(operation: () -> T): T {
        if (enabled.load()) {
            messageProcessingTimer.time(operation)
        } else {
            operation()
        }
    }

    public func recordActorCreated(): Unit {
        if (enabled.load()) {
            actorCreatedCounter.increment()
        }
    }

    public func recordActorStopped(): Unit {
        if (enabled.load()) {
            actorStoppedCounter.increment()
        }
    }

    public func updateMailboxSize(size: Int64): Unit {
        if (enabled.load()) {
            mailboxSizeGauge.set(Float64(size))
        }
    }

    public func recordError(): Unit {
        if (enabled.load()) {
            errorCounter.increment()
        }
    }

    public func enable(): Unit {
        enabled.store(true)
    }

    public func disable(): Unit {
        enabled.store(false)
    }

    public func isEnabled(): Bool {
        enabled.load()
    }

    public func getStats(): MonitoringStats {
        MonitoringStats(
            messageProcessedCounter.get(),
            messageProcessingTimer.getCount(),
            messageProcessingTimer.getMean(),
            actorCreatedCounter.get(),
            actorStoppedCounter.get(),
            mailboxSizeGauge.get(),
            errorCounter.get()
        )
    }
}

/**
 * 监控统计信息
 */
public struct MonitoringStats {
    public let messagesProcessed: Int64
    public let messageProcessingCount: Int64
    public let averageProcessingTime: Float64
    public let actorsCreated: Int64
    public let actorsStopped: Int64
    public let currentMailboxSize: Float64
    public let errors: Int64

    public init(messagesProcessed: Int64, messageProcessingCount: Int64,
                averageProcessingTime: Float64, actorsCreated: Int64,
                actorsStopped: Int64, currentMailboxSize: Float64, errors: Int64) {
        this.messagesProcessed = messagesProcessed
        this.messageProcessingCount = messageProcessingCount
        this.averageProcessingTime = averageProcessingTime
        this.actorsCreated = actorsCreated
        this.actorsStopped = actorsStopped
        this.currentMailboxSize = currentMailboxSize
        this.errors = errors
    }

    public func getActiveActors(): Int64 {
        actorsCreated - actorsStopped
    }

    public func getErrorRate(): Float64 {
        if (messagesProcessed == 0) {
            return 0.0
        }
        Float64(errors) / Float64(messagesProcessed)
    }
}

/**
 * 全局性能监控器实例
 */
public struct GlobalMonitor {
    private static let monitor: PerformanceMonitor = PerformanceMonitor()

    public static func getInstance(): PerformanceMonitor {
        monitor
    }

    public static func recordMessageProcessed(): Unit {
        monitor.recordMessageProcessed()
    }

    public static func recordMessageProcessingTime<T>(operation: () -> T): T {
        monitor.recordMessageProcessingTime(operation)
    }

    public static func recordActorCreated(): Unit {
        monitor.recordActorCreated()
    }

    public static func recordActorStopped(): Unit {
        monitor.recordActorStopped()
    }

    public static func updateMailboxSize(size: Int64): Unit {
        monitor.updateMailboxSize(size)
    }

    public static func recordError(): Unit {
        monitor.recordError()
    }

    public static func getStats(): MonitoringStats {
        monitor.getStats()
    }
}
