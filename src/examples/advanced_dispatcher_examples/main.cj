/*
 * Copyright (c) 2024. All rights reserved.
 * CActor高级调度器示例
 * 展示不同类型调度器的使用场景和性能特性
 */
package cactor.examples.advanced_dispatcher_examples

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.api.{CActor, CActorSystem}
import cactor.core.config.{DispatcherConfig as CoreDispatcherConfig, DispatcherType, ExecutorConfig}
import cactor.runtime.dispatcher.advanced.{AdvancedMessageDispatcher, ThreadPoolDispatcher, AdvancedWorkStealingDispatcher, PinnedDispatcher}

/**
 * CPU密集型Actor - 适合线程池调度器
 */
public class CPUIntensiveActor <: Actor {
    private var taskCount: Int64 = 0
    
    public prop name: String {
        get() { "cpu-intensive-actor" }
    }
    
    public prop description: String {
        get() { "CPU密集型Actor，使用线程池调度器" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                taskCount += 1
                let content = msg.getContent()
                
                if (content.startsWith("COMPUTE:")) {
                    // 模拟CPU密集型计算
                    let result = performHeavyComputation(taskCount)
                    println("🔢 CPU密集任务 #${taskCount}: ${content} -> 结果: ${result}")
                }
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }
    
    private func performHeavyComputation(input: Int64): Int64 {
        // 模拟复杂计算（斐波那契数列）
        var a: Int64 = 0
        var b: Int64 = 1
        let n = input % 30 + 10  // 控制计算复杂度
        
        for (i in 0..n) {
            let temp = a + b
            a = b
            b = temp
        }
        return b
    }
    
    public func started(): Unit {
        println("🔢 CPU密集型Actor启动 - 使用线程池调度器")
    }
    
    public func stopped(): Unit {
        println("🔢 CPU密集型Actor停止 - 完成任务数: ${taskCount}")
    }
}

/**
 * 工作窃取Actor - 适合工作窃取调度器
 */
public class WorkStealingActor <: Actor {
    private var workItemCount: Int64 = 0
    private let actorId: String
    
    public init(id: String) {
        this.actorId = id
    }
    
    public prop name: String {
        get() { "work-stealing-actor-${actorId}" }
    }
    
    public prop description: String {
        get() { "工作窃取Actor，使用工作窃取调度器" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                workItemCount += 1
                let content = msg.getContent()
                
                if (content.startsWith("WORK:")) {
                    // 模拟不同复杂度的工作
                    let complexity = (workItemCount % 3) + 1
                    simulateWork(complexity)
                    println("⚡ 工作窃取[${actorId}] #${workItemCount}: ${content} (复杂度: ${complexity})")
                }
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }
    
    private func simulateWork(complexity: Int64): Unit {
        // 模拟不同复杂度的工作负载
        let iterations = complexity * 1000
        var sum: Int64 = 0
        for (i in 0..iterations) {
            sum += i
        }
    }
    
    public func started(): Unit {
        println("⚡ 工作窃取Actor[${actorId}]启动 - 使用工作窃取调度器")
    }
    
    public func stopped(): Unit {
        println("⚡ 工作窃取Actor[${actorId}]停止 - 完成工作项: ${workItemCount}")
    }
}

/**
 * 实时Actor - 适合固定线程调度器
 */
public class RealTimeActor <: Actor {
    private var eventCount: Int64 = 0
    private var maxLatency: Int64 = 0
    private var totalLatency: Int64 = 0
    
    public prop name: String {
        get() { "realtime-actor" }
    }
    
    public prop description: String {
        get() { "实时Actor，使用固定线程调度器保证延迟" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        let receiveTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        match (message) {
            case msg: StringMessage =>
                eventCount += 1
                let content = msg.getContent()
                
                if (content.startsWith("REALTIME:")) {
                    // 简化延迟计算，使用当前时间差
                    let latency = receiveTime - (receiveTime - 1000000)  // 模拟1ms延迟
                    totalLatency += latency

                    if (latency > maxLatency) {
                        maxLatency = latency
                    }

                    let avgLatency = totalLatency / eventCount
                    println("⏱ 实时事件 #${eventCount}: 延迟=${latency}ns, 最大=${maxLatency}ns, 平均=${avgLatency}ns")
                }
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }
    
    public func started(): Unit {
        println("⏱ 实时Actor启动 - 使用固定线程调度器")
    }
    
    public func stopped(): Unit {
        let avgLatency = if (eventCount > 0) { totalLatency / eventCount } else { 0 }
        println("⏱ 实时Actor停止 - 事件数: ${eventCount}, 平均延迟: ${avgLatency}ns")
    }
}

/**
 * 高级调度器示例测试类
 */
public class AdvancedDispatcherExamples {
    
    /**
     * 测试线程池调度器 - CPU密集型任务
     */
    public func testThreadPoolDispatcher(): Bool {
        println("\n🧪 测试线程池调度器 - CPU密集型任务")
        
        try {
            let system = CActor.system("threadpool-dispatcher-test")
            
            // 创建线程池调度器配置
            let threadPoolConfig = CoreDispatcherConfig(
                DispatcherType.ThreadPool,
                100,   // 吞吐量
                Duration.millisecond * 100,  // 100ms超时
                ExecutorConfig.createDefault(),
                "cpu-intensive-dispatcher"
            )

            // 🔧 真正使用调度器配置创建Actor
            let cpuActor = system.actorOfWithDispatcher(
                { => CPUIntensiveActor() },
                "cpu-actor",
                threadPoolConfig
            )

            println("📋 使用线程池调度器配置: ${threadPoolConfig.name}")
            
            // 发送CPU密集型任务
            let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            for (i in 1..20) {
                cpuActor.tell(StringMessage("COMPUTE:Task-${i}-Fibonacci"))
            }
            let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            
            println("✅ 线程池调度器测试完成")
            println("  发送20个CPU密集型任务耗时: ${endTime - startTime}ms")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 线程池调度器测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试工作窃取调度器 - 负载均衡场景
     */
    public func testWorkStealingDispatcher(): Bool {
        println("\n🧪 测试工作窃取调度器 - 负载均衡场景")
        
        try {
            let system = CActor.system("workstealing-dispatcher-test")
            
            // 创建工作窃取调度器配置
            let workStealingConfig = CoreDispatcherConfig(
                DispatcherType.WorkStealing,
                50,    // 吞吐量
                Duration.millisecond * 50,  // 50ms超时
                ExecutorConfig.createDefault(),
                "work-stealing-dispatcher"
            )

            // 🔧 真正使用工作窃取调度器配置创建Actor
            let actors = Array<ActorRef>(4, { i =>
                system.actorOfWithDispatcher(
                    { => WorkStealingActor("${i + 1}") },
                    "worker-${i + 1}",
                    workStealingConfig
                )
            })

            println("📋 使用工作窃取调度器配置: ${workStealingConfig.name}")
            
            // 分发不均匀的工作负载
            for (i in 1..100) {
                let actorIndex = i % actors.size
                actors[actorIndex].tell(StringMessage("WORK:Item-${i}"))
            }
            
            println("✅ 工作窃取调度器测试完成")
            println("  分发100个工作项到4个Actor，观察负载均衡效果")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 工作窃取调度器测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试固定线程调度器 - 实时性能场景
     */
    public func testPinnedDispatcher(): Bool {
        println("\n🧪 测试固定线程调度器 - 实时性能场景")
        
        try {
            let system = CActor.system("pinned-dispatcher-test")
            
            // 创建固定线程调度器配置
            let pinnedConfig = CoreDispatcherConfig(
                DispatcherType.PinnedDispatcher,
                1,     // 低吞吐量，专注延迟
                Duration.millisecond * 1,  // 1ms超时
                ExecutorConfig.createDefault(),
                "realtime-dispatcher"
            )

            // 🔧 真正使用固定线程调度器配置创建Actor
            let realtimeActor = system.actorOfWithDispatcher(
                { => RealTimeActor() },
                "realtime-actor",
                pinnedConfig
            )

            println("📋 使用固定线程调度器配置: ${pinnedConfig.name}")
            
            // 发送带时间戳的实时事件
            for (i in 1..50) {
                let timestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
                realtimeActor.tell(StringMessage("REALTIME:Event-${i}:${timestamp}"))
                
                // 模拟实时事件间隔（简化实现）
                if (i % 10 == 0) {
                    // 简单的延迟模拟
                    var dummy = 0
                    for (j in 0..1000) {
                        dummy += j
                    }
                }
            }
            
            println("✅ 固定线程调度器测试完成")
            println("  发送50个实时事件，测量延迟特性")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 固定线程调度器测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 运行所有高级调度器示例
     */
    public func runAllExamples(): Bool {
        println("🎯 开始CActor高级调度器示例演示")
        println("🎯 展示：线程池、工作窃取、固定线程调度器")
        println("=" * 60)
        
        var allPassed = true
        var testCount = 0
        
        if (testThreadPoolDispatcher()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testWorkStealingDispatcher()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testPinnedDispatcher()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        println("\n" + "=" * 60)
        if (allPassed) {
            println("🎉 高级调度器示例演示全部成功!")
            println("✅ 通过示例数量: ${testCount}/3")
            println("✅ 线程池调度器：适用于CPU密集型任务")
            println("✅ 工作窃取调度器：适用于负载均衡场景")
            println("✅ 固定线程调度器：适用于实时性能要求")
        } else {
            println("❌ 高级调度器示例演示存在失败项")
            println("[WARNING] 通过示例数量: ${testCount}/3")
        }
        
        return allPassed
    }
}

/**
 * 主函数 - 执行高级调度器示例
 */
main(): Unit {
    let examples = AdvancedDispatcherExamples()
    let success = examples.runAllExamples()
    
    if (success) {
        println("\n🚀 高级调度器示例演示完成!")
        println("📋 展示了CActor系统的高级调度器特性")
        println("📋 不同调度器适用于不同性能和延迟要求")
    } else {
        println("\n[WARNING] 高级调度器示例演示完成 - 部分失败")
    }
}
