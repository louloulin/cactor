/*
 * CActor 3.0 - 使用宏DSL的计数器Actor示例
 * Phase 1: 宏驱动的Actor DSL系统 - 示例
 */
package cactor.examples

import cactor.macros.*
import cactor.dsl.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 使用@actor宏定义计数器Actor
@actor
struct CounterActor {
    var count: Int64 = 0
    
    @handler
    func increment(msg: IncrementMessage): Unit {
        count += msg.value
        println("计数器增加 ${msg.value}，当前值: ${count}")
    }
    
    @handler
    func decrement(msg: DecrementMessage): Unit {
        count -= msg.value
        println("计数器减少 ${msg.value}，当前值: ${count}")
    }
    
    @handler
    func getCount(msg: GetCountMessage): CountResponse {
        println("获取计数器值: ${count}")
        return CountResponse(count)
    }
    
    @handler
    func reset(msg: ResetMessage): Unit {
        count = 0
        println("计数器已重置")
    }
}

// 使用@monitored宏定义带监控的高性能Actor
@monitored
struct HighPerfActor {
    var processedCount: Int64 = 0
    
    @handler
    func process(msg: ProcessMessage): Unit {
        processedCount += 1
        // 模拟一些处理工作
        for (i in 0..msg.workload) {
            // 空循环模拟工作
        }
        println("处理消息，工作负载: ${msg.workload}")
    }
    
    @handler
    func getStats(msg: GetStatsMessage): StatsResponse {
        return StatsResponse(processedCount)
    }
}

// 使用@route_table宏定义消息路由
@route_table
enum MessageType {
    | Increment(IncrementMessage)
    | Decrement(DecrementMessage)
    | GetCount(GetCountMessage)
    | Reset(ResetMessage)
    | Process(ProcessMessage)
    | GetStats(GetStatsMessage)
}

// 消息类型定义
public class IncrementMessage <: Message {
    public let value: Int64
    
    public init(value: Int64) {
        this.value = value
    }
    
    public func getMessageType(): String {
        return "increment"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class DecrementMessage <: Message {
    public let value: Int64
    
    public init(value: Int64) {
        this.value = value
    }
    
    public func getMessageType(): String {
        return "decrement"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class GetCountMessage <: Message {
    public init() {}
    
    public func getMessageType(): String {
        return "getcount"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class ResetMessage <: Message {
    public init() {}
    
    public func getMessageType(): String {
        return "reset"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class ProcessMessage <: Message {
    public let workload: Int64
    
    public init(workload: Int64) {
        this.workload = workload
    }
    
    public func getMessageType(): String {
        return "process"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class GetStatsMessage <: Message {
    public init() {}
    
    public func getMessageType(): String {
        return "getstats"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

// 响应消息类型
public class CountResponse <: Message {
    public let count: Int64
    
    public init(count: Int64) {
        this.count = count
    }
    
    public func getMessageType(): String {
        return "countresponse"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class StatsResponse <: Message {
    public let processedCount: Int64
    
    public init(processedCount: Int64) {
        this.processedCount = processedCount
    }
    
    public func getMessageType(): String {
        return "statsresponse"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

// DSL使用示例
public func demonstrateActorDSL(): Unit {
    println("=== CActor 3.0 宏DSL系统演示 ===")
    
    // 创建计数器Actor
    let counterRef = createCounterActorActor()
    println("✅ 计数器Actor已创建")
    
    // 创建监控Actor
    let monitoredRef = createMonitoredHighPerfActorActor()
    println("✅ 监控Actor已创建")
    
    // 测试计数器Actor
    println("\n--- 测试计数器Actor ---")
    counterRef.tell(IncrementMessage(5))
    counterRef.tell(IncrementMessage(3))
    counterRef.tell(DecrementMessage(2))
    counterRef.tell(GetCountMessage())
    counterRef.tell(ResetMessage())
    counterRef.tell(GetCountMessage())
    
    // 测试监控Actor
    println("\n--- 测试监控Actor ---")
    monitoredRef.tell(ProcessMessage(100))
    monitoredRef.tell(ProcessMessage(200))
    monitoredRef.tell(ProcessMessage(50))
    monitoredRef.tell(GetStatsMessage())
    
    // 显示性能指标
    println("\n--- 性能指标 ---")
    let counterActor = counterRef.getActor()
    if (let counterActorImpl <- counterActor as CounterActorActor) {
        let metrics = counterActorImpl.getMetrics()
        println("计数器Actor指标: ${metrics.toString()}")
    }
    
    let monitoredActor = monitoredRef.getActor()
    if (let monitoredActorImpl <- monitoredActor as MonitoredHighPerfActorActor) {
        let metrics = monitoredActorImpl.getMetrics()
        println("监控Actor指标: ${metrics.toString()}")
        println("消息处理数量: ${monitoredActorImpl.getMessageCount()}")
        println("平均处理时间: ${monitoredActorImpl.getAverageProcessingTime()}ms")
    }
    
    // 清理资源
    counterRef.stop()
    monitoredRef.stop()
    ActorSystem.getInstance().shutdown()
    
    println("\n✅ DSL演示完成")
}

// 辅助函数
func getCurrentTimeMillis(): Int64 {
    // 简化实现，实际应该调用系统时间API
    return 1000
}
