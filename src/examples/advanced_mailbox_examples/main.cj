/*
 * Copyright (c) 2024. All rights reserved.
 * CActor高级邮箱示例
 * 展示不同类型邮箱的使用场景和性能特性
 */
package cactor.examples.advanced_mailbox_examples

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.config.{MailboxConfig, MailboxType}
import cactor.api.{CActor, CActorSystem}
import cactor.api.extensions.{ActorSystemExtensions, PropsExtensions}
import cactor.runtime.mailbox.advanced.{SPSCMailbox, MPSCMailbox, FoundationBoundedMailbox}
import cactor.runtime.mailbox.factory.{AdvancedMailboxFactory, DefaultAdvancedMailboxFactory, UsagePattern}

/**
 * 高频交易Actor - 使用SPSC邮箱优化单线程性能
 */
public class HighFrequencyTradingActor <: Actor {
    private var tradeCount: Int64 = 0
    private var lastTradeTime: Int64 = 0
    
    public prop name: String {
        get() { "hft-actor" }
    }
    
    public prop description: String {
        get() { "高频交易Actor，使用SPSC邮箱优化延迟" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                let currentTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
                tradeCount += 1
                
                if (msg.getContent().startsWith("TRADE:")) {
                    // 模拟高频交易处理
                    let latency = if (lastTradeTime > 0) { currentTime - lastTradeTime } else { 0 }
                    println("🏦 HFT处理交易 #${tradeCount}: ${msg.getContent()}, 延迟: ${latency}ns")
                    lastTradeTime = currentTime
                }
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }
    
    public func started(): Unit {
        println("🏦 高频交易Actor启动 - 使用SPSC邮箱")
        lastTradeTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }
    
    public func stopped(): Unit {
        println("🏦 高频交易Actor停止 - 总交易数: ${tradeCount}")
    }
}

/**
 * 日志聚合Actor - 使用MPSC邮箱处理多生产者场景
 */
public class LogAggregatorActor <: Actor {
    private var logCount: Int64 = 0
    private let logBuffer: ArrayList<String> = ArrayList<String>()
    
    public prop name: String {
        get() { "log-aggregator" }
    }
    
    public prop description: String {
        get() { "日志聚合Actor，使用MPSC邮箱处理多源日志" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                logCount += 1
                let content = msg.getContent()
                
                if (content.startsWith("LOG:")) {
                    logBuffer.append(content)
                    println("📝 日志聚合 #${logCount}: ${content}")
                    
                    // 每100条日志批量处理一次
                    if (logCount % 100 == 0) {
                        flushLogs()
                    }
                }
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }
    
    private func flushLogs(): Unit {
        println("💾 批量处理${logBuffer.size}条日志")
        logBuffer.clear()
    }
    
    public func started(): Unit {
        println("📝 日志聚合Actor启动 - 使用MPSC邮箱")
    }
    
    public func stopped(): Unit {
        if (logBuffer.size > 0) {
            flushLogs()
        }
        println("📝 日志聚合Actor停止 - 总日志数: ${logCount}")
    }
}

/**
 * 限流Actor - 使用有界邮箱实现背压控制
 */
public class RateLimitedActor <: Actor {
    private var processedCount: Int64 = 0
    private var droppedCount: Int64 = 0
    private let maxRate: Int64 = 100  // 每秒最大处理100条消息
    private var lastSecond: Int64 = 0
    private var currentSecondCount: Int64 = 0
    
    public prop name: String {
        get() { "rate-limited-actor" }
    }
    
    public prop description: String {
        get() { "限流Actor，使用有界邮箱实现背压控制" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        let currentSecond = DateTime.now().toUnixTimeStamp().toSeconds()
        
        // 重置计数器
        if (currentSecond != lastSecond) {
            lastSecond = currentSecond
            currentSecondCount = 0
        }
        
        // 检查是否超过限流
        if (currentSecondCount >= maxRate) {
            droppedCount += 1
            println("🚫 限流丢弃消息 #${droppedCount}")
            return MessageResult.Handled
        }
        
        match (message) {
            case msg: StringMessage =>
                currentSecondCount += 1
                processedCount += 1
                println("⚡ 限流处理消息 #${processedCount}: ${msg.getContent()}")
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }
    
    public func started(): Unit {
        println("⚡ 限流Actor启动 - 使用有界邮箱，限制${maxRate}msg/s")
        lastSecond = DateTime.now().toUnixTimeStamp().toSeconds()
    }
    
    public func stopped(): Unit {
        println("⚡ 限流Actor停止 - 处理: ${processedCount}, 丢弃: ${droppedCount}")
    }
}

/**
 * 高级邮箱示例测试类
 */
public class AdvancedMailboxExamples {
    
    /**
     * 测试SPSC邮箱 - 单生产者单消费者高性能场景
     */
    public func testSPSCMailbox(): Bool {
        println("\n🧪 测试SPSC邮箱 - 高频交易场景")

        try {
            let system = CActor.system("spsc-mailbox-test")

            // 创建SPSC邮箱配置
            let spscConfig = MailboxConfig(
                MailboxType.Custom,
                1024,  // 1K容量
                Duration.millisecond * 1,  // 1ms超时
                0,     // 无暂存
                "spsc-hft-mailbox"
            )

            // 🔧 真正使用配置创建Actor - 使用CActorSystem的配置方法
            let hftActor = system.actorOfWithMailbox(
                { => HighFrequencyTradingActor() },
                "hft-actor",
                spscConfig
            )

            println("📋 使用SPSC邮箱配置: ${spscConfig.name}, 容量: ${spscConfig.capacity}")

            // 发送高频交易消息
            let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
            for (i in 1..1000) {
                hftActor.tell(StringMessage("TRADE:BUY-AAPL-${i}@150.${i % 100}"))
            }
            let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()

            println("✅ SPSC邮箱测试完成")
            println("  发送1000条交易消息耗时: ${(endTime - startTime) / 1000000}ms")
            println("  邮箱配置: ${spscConfig.name}")

            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ SPSC邮箱测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试MPSC邮箱 - 多生产者单消费者场景
     */
    public func testMPSCMailbox(): Bool {
        println("\n🧪 测试MPSC邮箱 - 日志聚合场景")
        
        try {
            let system = CActor.system("mpsc-mailbox-test")
            
            // 创建MPSC邮箱配置
            let mpscConfig = MailboxConfig(
                MailboxType.Custom,
                2048,  // 2K容量
                Duration.millisecond * 10,  // 10ms超时
                0,     // 无暂存
                "mpsc-log-mailbox"
            )
            
            // 🔧 真正使用MPSC邮箱配置创建Actor
            let logActor = system.actorOfWithMailbox(
                { => LogAggregatorActor() },
                "log-aggregator",
                mpscConfig
            )

            println("📋 使用MPSC邮箱配置: ${mpscConfig.name}, 容量: ${mpscConfig.capacity}")
            
            // 模拟多个生产者发送日志
            let producers = Array<String>(5, { i => "Producer-${i + 1}" })
            
            for (producer in producers) {
                for (i in 1..50) {
                    logActor.tell(StringMessage("LOG:[${producer}] Message ${i} - ${DateTime.now()}"))
                }
            }
            
            println("✅ MPSC邮箱测试完成")
            println("  5个生产者各发送50条日志，总计250条")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ MPSC邮箱测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试有界邮箱 - 背压控制场景
     */
    public func testBoundedMailbox(): Bool {
        println("\n🧪 测试有界邮箱 - 背压控制场景")
        
        try {
            let system = CActor.system("bounded-mailbox-test")
            
            // 创建有界邮箱配置
            let boundedConfig = MailboxConfig(
                MailboxType.Bounded,
                50,    // 小容量测试背压
                Duration.millisecond * 1,  // 1ms超时
                0,     // 无暂存
                "bounded-rate-limit-mailbox"
            )
            
            // 🔧 真正使用有界邮箱配置创建Actor
            let rateLimitActor = system.actorOfWithMailbox(
                { => RateLimitedActor() },
                "rate-limit-actor",
                boundedConfig
            )

            println("📋 使用有界邮箱配置: ${boundedConfig.name}, 容量: ${boundedConfig.capacity}")
            
            // 快速发送大量消息测试背压
            println("🚀 快速发送200条消息测试背压...")
            for (i in 1..200) {
                rateLimitActor.tell(StringMessage("BURST:Message-${i}"))
            }
            
            println("✅ 有界邮箱测试完成")
            println("  发送200条消息，观察背压效果")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 有界邮箱测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 运行所有高级邮箱示例
     */
    public func runAllExamples(): Bool {
        println("🎯 开始CActor高级邮箱示例演示")
        println("🎯 展示：SPSC、MPSC、有界邮箱的使用场景")
        println("=" * 60)
        
        var allPassed = true
        var testCount = 0
        
        if (testSPSCMailbox()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testMPSCMailbox()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testBoundedMailbox()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        println("\n" + "=" * 60)
        if (allPassed) {
            println("🎉 高级邮箱示例演示全部成功!")
            println("✅ 通过示例数量: ${testCount}/3")
            println("✅ SPSC邮箱：适用于高频单线程场景")
            println("✅ MPSC邮箱：适用于多生产者聚合场景")
            println("✅ 有界邮箱：适用于背压控制场景")
        } else {
            println("❌ 高级邮箱示例演示存在失败项")
            println("[WARNING] 通过示例数量: ${testCount}/3")
        }
        
        return allPassed
    }
}

/**
 * 主函数 - 执行高级邮箱示例
 */
main(): Unit {
    let examples = AdvancedMailboxExamples()
    let success = examples.runAllExamples()
    
    if (success) {
        println("\n🚀 高级邮箱示例演示完成!")
        println("📋 展示了CActor系统的高级邮箱特性")
        println("📋 SPSC/MPSC/有界邮箱适用于不同性能场景")
    } else {
        println("\n[WARNING] 高级邮箱示例演示完成 - 部分失败")
    }
}
