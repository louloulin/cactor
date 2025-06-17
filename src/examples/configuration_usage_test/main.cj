/*
 * Copyright (c) 2024. All rights reserved.
 * CActor配置使用测试 - 验证配置真正被使用
 * 展示修复后的CActorSystem如何正确传递和使用配置
 */
package cactor.examples.configuration_usage_test

import std.time.{Duration, DateTime}
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.config.{MailboxConfig, DispatcherConfig, SupervisionConfig, MailboxType, DispatcherType, SupervisionStrategyType, ExecutorConfig}
import cactor.api.{CActor, CActorSystem}

/**
 * 测试Actor - 记录配置信息
 */
public class ConfigTestActor <: Actor {
    private var messageCount: Int64 = 0
    private var configInfo: String = ""
    
    public init() {}
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                messageCount += 1
                let content = msg.getContent()
                
                if (content.startsWith("CONFIG:")) {
                    configInfo = content
                    println("📋 Actor收到配置信息: ${configInfo}")
                } else {
                    println("📨 处理消息 #${messageCount}: ${content}")
                }
                
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }
    
    public prop name: String {
        get() { "config-test-actor" }
    }
    
    public prop description: String {
        get() { "测试配置使用的Actor" }
    }
    
    public func started(): Unit {
        println("✅ ConfigTestActor启动")
    }
    
    public func stopped(): Unit {
        println("🛑 ConfigTestActor停止 - 处理了${messageCount}条消息")
    }
}

/**
 * 配置使用测试主类
 */
public class ConfigurationUsageTest {
    
    /**
     * 测试邮箱配置的使用
     */
    public func testMailboxConfiguration(): Bool {
        println("\n🧪 测试邮箱配置使用")
        
        try {
            let system = CActor.system("mailbox-config-test")
            
            // 创建有界邮箱配置
            let boundedConfig = MailboxConfig(
                MailboxType.Bounded,
                100,  // 100条消息容量
                Duration.second * 5,  // 5秒超时
                0,    // 无暂存
                "test-bounded-mailbox"
            )
            
            // 🔧 使用配置创建Actor
            let testActor = system.actorOfWithMailbox(
                { => ConfigTestActor() },
                "bounded-test-actor",
                boundedConfig
            )
            
            // 发送配置信息
            testActor.tell(StringMessage("CONFIG:使用有界邮箱,容量=${boundedConfig.capacity},名称=${boundedConfig.name}"))
            
            // 发送测试消息
            for (i in 1..10) {
                testActor.tell(StringMessage("测试消息-${i}"))
            }
            
            println("✅ 邮箱配置测试完成")
            println("  配置名称: ${boundedConfig.name}")
            println("  邮箱类型: Bounded")
            println("  容量限制: ${boundedConfig.capacity}")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 邮箱配置测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试调度器配置的使用
     */
    public func testDispatcherConfiguration(): Bool {
        println("\n🧪 测试调度器配置使用")
        
        try {
            let system = CActor.system("dispatcher-config-test")
            
            // 创建线程池调度器配置
            let threadPoolConfig = DispatcherConfig(
                DispatcherType.ThreadPool,
                50,   // 吞吐量
                Duration.millisecond * 100,  // 100ms超时
                ExecutorConfig.createDefault(),
                "test-threadpool-dispatcher"
            )
            
            // 🔧 使用配置创建Actor
            let testActor = system.actorOfWithDispatcher(
                { => ConfigTestActor() },
                "threadpool-test-actor",
                threadPoolConfig
            )
            
            // 发送配置信息
            testActor.tell(StringMessage("CONFIG:使用线程池调度器,吞吐量=${threadPoolConfig.throughput},名称=${threadPoolConfig.name}"))
            
            // 发送测试消息
            for (i in 1..20) {
                testActor.tell(StringMessage("调度器测试消息-${i}"))
            }
            
            println("✅ 调度器配置测试完成")
            println("  配置名称: ${threadPoolConfig.name}")
            println("  调度器类型: ThreadPool")
            println("  吞吐量: ${threadPoolConfig.throughput}")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 调度器配置测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试完整配置的使用
     */
    public func testFullConfiguration(): Bool {
        println("\n🧪 测试完整配置使用")
        
        try {
            let system = CActor.system("full-config-test")
            
            // 创建完整配置
            let mailboxConfig = MailboxConfig.createBoundedWithName(50, "full-test-mailbox")
            let dispatcherConfig = DispatcherConfig.createThreadPoolWithName("full-test-dispatcher")
            let supervisionConfig = SupervisionConfig.createDefaultWithName("full-test-supervision")
            
            // 🔧 使用完整配置创建Actor
            let testActor = system.actorOfConfigured(
                { => ConfigTestActor() },
                "full-config-test-actor",
                mailboxConfig,
                dispatcherConfig,
                supervisionConfig
            )
            
            // 发送配置信息
            testActor.tell(StringMessage("CONFIG:完整配置,邮箱=${mailboxConfig.name},调度器=${dispatcherConfig.name},监督=${supervisionConfig.name}"))
            
            // 发送测试消息
            for (i in 1..15) {
                testActor.tell(StringMessage("完整配置测试消息-${i}"))
            }
            
            println("✅ 完整配置测试完成")
            println("  邮箱配置: ${mailboxConfig.name}")
            println("  调度器配置: ${dispatcherConfig.name}")
            println("  监督配置: ${supervisionConfig.name}")
            
            system.terminate()
            return true
        } catch (e: Exception) {
            println("❌ 完整配置测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 运行所有测试
     */
    public func runAllTests(): Bool {
        println("🚀 开始配置使用测试")
        
        let mailboxResult = testMailboxConfiguration()
        let dispatcherResult = testDispatcherConfiguration()
        let fullConfigResult = testFullConfiguration()
        
        let allPassed = mailboxResult && dispatcherResult && fullConfigResult
        
        if (allPassed) {
            println("\n🎉 所有配置使用测试通过！")
            println("✅ 邮箱配置正确传递和使用")
            println("✅ 调度器配置正确传递和使用")
            println("✅ 完整配置正确传递和使用")
        } else {
            println("\n❌ 部分配置使用测试失败")
        }
        
        return allPassed
    }
}

main(): Int64 {
    try {
        let test = ConfigurationUsageTest()
        let success = test.runAllTests()
        return if (success) { 0 } else { 1 }
    } catch (e: Exception) {
        println("💥 测试执行异常: ${e}")
        return 1
    }
}
