/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 调试工具实现
 */
package cactor.integration.logging

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.{Message, StringMessage}
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.integration.logging.{Logger, LoggerFactory, LogLevel}

/**
 * Actor状态快照
 */
public struct ActorSnapshot {
    public let actorPath: String
    public let actorType: String
    public let state: String
    public let messageCount: Int64
    public let lastActivity: DateTime
    public let memoryUsage: Int64
    
    public init(actorPath: String, actorType: String, state: String,
                messageCount: Int64, lastActivity: DateTime, memoryUsage: Int64) {
        this.actorPath = actorPath
        this.actorType = actorType
        this.state = state
        this.messageCount = messageCount
        this.lastActivity = lastActivity
        this.memoryUsage = memoryUsage
    }
    
    public func toString(): String {
        "ActorSnapshot(path=${actorPath}, type=${actorType}, state=${state}, " +
        "messages=${messageCount}, memory=${memoryUsage}bytes)"
    }
}

/**
 * 系统状态快照
 */
public struct SystemSnapshot {
    public let timestamp: DateTime
    public let totalActors: Int64
    public let activeActors: Int64
    public let totalMessages: Int64
    public let memoryUsage: Int64
    public let cpuUsage: Float64
    public let actors: Array<ActorSnapshot>
    
    public init(totalActors: Int64, activeActors: Int64, totalMessages: Int64,
                memoryUsage: Int64, cpuUsage: Float64, actors: Array<ActorSnapshot>) {
        this.timestamp = DateTime.now()
        this.totalActors = totalActors
        this.activeActors = activeActors
        this.totalMessages = totalMessages
        this.memoryUsage = memoryUsage
        this.cpuUsage = cpuUsage
        this.actors = actors
    }
    
    public func toString(): String {
        "SystemSnapshot(actors=${totalActors}/${activeActors}, messages=${totalMessages}, " +
        "memory=${memoryUsage}bytes, cpu=${cpuUsage}%)"
    }
}

/**
 * 消息跟踪记录
 */
public struct MessageTrace {
    public let messageId: String
    public let messageType: String
    public let sender: String
    public let receiver: String
    public let timestamp: DateTime
    public let processingTime: Int64
    public let status: String
    
    public init(messageId: String, messageType: String, sender: String,
                receiver: String, processingTime: Int64, status: String) {
        this.messageId = messageId
        this.messageType = messageType
        this.sender = sender
        this.receiver = receiver
        this.timestamp = DateTime.now()
        this.processingTime = processingTime
        this.status = status
    }
    
    public func toString(): String {
        "MessageTrace(id=${messageId}, ${sender}->${receiver}, " +
        "type=${messageType}, time=${processingTime}ms, status=${status})"
    }
}

/**
 * 性能分析器
 */
public class PerformanceProfiler {
    private let samples: ArrayList<PerformanceSample>
    private let mutex: ReentrantMutex
    private let maxSamples: Int64
    private let isEnabled: AtomicBool
    
    public init(maxSamples: Int64) {
        this.samples = ArrayList<PerformanceSample>()
        this.mutex = ReentrantMutex()
        this.maxSamples = maxSamples
        this.isEnabled = AtomicBool(false)
    }
    
    public func enable(): Unit {
        isEnabled.store(true)
        println("性能分析器已启用")
    }
    
    public func disable(): Unit {
        isEnabled.store(false)
        println("性能分析器已禁用")
    }
    
    public func recordSample(actorPath: String, operation: String, duration: Int64): Unit {
        if (isEnabled.load()) {
            let sample = PerformanceSample(actorPath, operation, duration)
            
            mutex.lock()
            samples.append(sample)
            
            // 保持样本数量在限制内
            while (samples.size > maxSamples) {
                // 简化实现：清空重建
                let newSamples = ArrayList<PerformanceSample>()
                for (i in 1..samples.size) {
                    newSamples.append(samples[i])
                }
                samples.clear()
                for (sample in newSamples) {
                    samples.append(sample)
                }
                break
            }
            mutex.unlock()
        }
    }
    
    public func getReport(): PerformanceReport {
        mutex.lock()
        let currentSamples = ArrayList<PerformanceSample>()
        for (sample in samples) {
            currentSamples.append(sample)
        }
        mutex.unlock()
        
        PerformanceReport(currentSamples.toArray())
    }
    
    public func clear(): Unit {
        mutex.lock()
        samples.clear()
        mutex.unlock()
        println("性能分析数据已清除")
    }
}

/**
 * 性能样本
 */
public struct PerformanceSample {
    public let actorPath: String
    public let operation: String
    public let duration: Int64
    public let timestamp: DateTime
    
    public init(actorPath: String, operation: String, duration: Int64) {
        this.actorPath = actorPath
        this.operation = operation
        this.duration = duration
        this.timestamp = DateTime.now()
    }
    
    public func toString(): String {
        "PerformanceSample(${actorPath}.${operation}: ${duration}ms)"
    }
}

/**
 * 性能报告
 */
public struct PerformanceReport {
    public let samples: Array<PerformanceSample>
    public let totalSamples: Int64
    public let averageDuration: Float64
    public let maxDuration: Int64
    public let minDuration: Int64
    
    public init(samples: Array<PerformanceSample>) {
        this.samples = samples
        this.totalSamples = Int64(samples.size)
        
        if (samples.size > 0) {
            var total = Int64(0)
            var max = samples[0].duration
            var min = samples[0].duration
            
            for (sample in samples) {
                total += sample.duration
                if (sample.duration > max) {
                    max = sample.duration
                }
                if (sample.duration < min) {
                    min = sample.duration
                }
            }
            
            this.averageDuration = Float64(total) / Float64(samples.size)
            this.maxDuration = max
            this.minDuration = min
        } else {
            this.averageDuration = 0.0
            this.maxDuration = 0
            this.minDuration = 0
        }
    }
    
    public func toString(): String {
        "PerformanceReport(samples=${totalSamples}, avg=${averageDuration}ms, " +
        "max=${maxDuration}ms, min=${minDuration}ms)"
    }
}

/**
 * 消息跟踪器
 */
public class MessageTracer {
    private let traces: ArrayList<MessageTrace>
    private let mutex: ReentrantMutex
    private let maxTraces: Int64
    private let isEnabled: AtomicBool
    private let messageIdCounter: AtomicInt64
    
    public init(maxTraces: Int64) {
        this.traces = ArrayList<MessageTrace>()
        this.mutex = ReentrantMutex()
        this.maxTraces = maxTraces
        this.isEnabled = AtomicBool(false)
        this.messageIdCounter = AtomicInt64(0)
    }
    
    public func enable(): Unit {
        isEnabled.store(true)
        println("消息跟踪器已启用")
    }
    
    public func disable(): Unit {
        isEnabled.store(false)
        println("消息跟踪器已禁用")
    }
    
    public func traceMessage(messageType: String, sender: String, receiver: String,
                           processingTime: Int64, status: String): Unit {
        if (isEnabled.load()) {
            let messageId = "msg-${messageIdCounter.fetchAdd(1)}"
            let trace = MessageTrace(messageId, messageType, sender, receiver, processingTime, status)
            
            mutex.lock()
            traces.append(trace)
            
            // 保持跟踪记录数量在限制内
            while (traces.size > maxTraces) {
                // 简化实现：清空重建
                let newTraces = ArrayList<MessageTrace>()
                for (i in 1..traces.size) {
                    newTraces.append(traces[i])
                }
                traces.clear()
                for (trace in newTraces) {
                    traces.append(trace)
                }
                break
            }
            mutex.unlock()
        }
    }
    
    public func getTraces(): Array<MessageTrace> {
        mutex.lock()
        let currentTraces = ArrayList<MessageTrace>()
        for (trace in traces) {
            currentTraces.append(trace)
        }
        mutex.unlock()
        currentTraces.toArray()
    }
    
    public func getTracesByActor(actorPath: String): Array<MessageTrace> {
        mutex.lock()
        let actorTraces = ArrayList<MessageTrace>()
        for (trace in traces) {
            if (trace.sender == actorPath || trace.receiver == actorPath) {
                actorTraces.append(trace)
            }
        }
        mutex.unlock()
        actorTraces.toArray()
    }
    
    public func clear(): Unit {
        mutex.lock()
        traces.clear()
        mutex.unlock()
        println("消息跟踪数据已清除")
    }
}

/**
 * 系统诊断器
 */
public class SystemDiagnostics {
    private let logger: Logger
    private let profiler: PerformanceProfiler
    private let tracer: MessageTracer
    private let actorRegistry: HashMap<String, ActorSnapshot>
    private let mutex: ReentrantMutex
    
    public init() {
        this.logger = LoggerFactory.getLogger("cactor.debug")
        this.profiler = PerformanceProfiler(1000)
        this.tracer = MessageTracer(1000)
        this.actorRegistry = HashMap<String, ActorSnapshot>()
        this.mutex = ReentrantMutex()
    }
    
    public func enableProfiling(): Unit {
        profiler.enable()
        logger.info("系统性能分析已启用")
    }
    
    public func disableProfiling(): Unit {
        profiler.disable()
        logger.info("系统性能分析已禁用")
    }
    
    public func enableTracing(): Unit {
        tracer.enable()
        logger.info("消息跟踪已启用")
    }
    
    public func disableTracing(): Unit {
        tracer.disable()
        logger.info("消息跟踪已禁用")
    }
    
    public func recordActorSnapshot(snapshot: ActorSnapshot): Unit {
        mutex.lock()
        actorRegistry[snapshot.actorPath] = snapshot
        mutex.unlock()
    }
    
    public func getSystemSnapshot(): SystemSnapshot {
        mutex.lock()
        let actors = ArrayList<ActorSnapshot>()
        var totalActors = Int64(0)
        var activeActors = Int64(0)
        var totalMessages = Int64(0)
        var totalMemory = Int64(0)
        
        for ((_, snapshot) in actorRegistry) {
            actors.append(snapshot)
            totalActors += 1
            if (snapshot.state == "RUNNING") {
                activeActors += 1
            }
            totalMessages += snapshot.messageCount
            totalMemory += snapshot.memoryUsage
        }
        mutex.unlock()
        
        let cpuUsage = getCurrentCpuUsage()
        SystemSnapshot(totalActors, activeActors, totalMessages, totalMemory, cpuUsage, actors.toArray())
    }
    
    public func getPerformanceReport(): PerformanceReport {
        profiler.getReport()
    }
    
    public func getMessageTraces(): Array<MessageTrace> {
        tracer.getTraces()
    }
    
    public func diagnoseSystem(): DiagnosticReport {
        let systemSnapshot = getSystemSnapshot()
        let performanceReport = getPerformanceReport()
        let messageTraces = getMessageTraces()
        
        DiagnosticReport(systemSnapshot, performanceReport, messageTraces)
    }
    
    private func getCurrentCpuUsage(): Float64 {
        // 简化的CPU使用率获取
        Float64(DateTime.now().toUnixTimeStamp().toMilliseconds() % 100) / 100.0 * 50.0
    }
    
    public func printDiagnostics(): Unit {
        let report = diagnoseSystem()
        
        logger.info("=== 系统诊断报告 ===")
        logger.info("系统状态: ${report.systemSnapshot.toString()}")
        logger.info("性能报告: ${report.performanceReport.toString()}")
        logger.info("消息跟踪: ${report.messageTraces.size}条记录")
        
        // 检查潜在问题
        if (report.systemSnapshot.cpuUsage > 80.0) {
            logger.warn("CPU使用率过高: ${report.systemSnapshot.cpuUsage}%")
        }
        
        if (report.performanceReport.averageDuration > 100.0) {
            logger.warn("平均处理时间过长: ${report.performanceReport.averageDuration}ms")
        }
        
        if (report.systemSnapshot.memoryUsage > 1024 * 1024 * 100) {  // 100MB
            logger.warn("内存使用量过高: ${report.systemSnapshot.memoryUsage}bytes")
        }
    }
    
    public func clear(): Unit {
        profiler.clear()
        tracer.clear()
        mutex.lock()
        actorRegistry.clear()
        mutex.unlock()
        logger.info("诊断数据已清除")
    }
}

/**
 * 诊断报告
 */
public struct DiagnosticReport {
    public let systemSnapshot: SystemSnapshot
    public let performanceReport: PerformanceReport
    public let messageTraces: Array<MessageTrace>
    public let timestamp: DateTime
    
    public init(systemSnapshot: SystemSnapshot, performanceReport: PerformanceReport,
                messageTraces: Array<MessageTrace>) {
        this.systemSnapshot = systemSnapshot
        this.performanceReport = performanceReport
        this.messageTraces = messageTraces
        this.timestamp = DateTime.now()
    }
    
    public func toString(): String {
        "DiagnosticReport(timestamp=${timestamp}, " +
        "system=${systemSnapshot.toString()}, " +
        "performance=${performanceReport.toString()}, " +
        "traces=${messageTraces.size})"
    }
}
