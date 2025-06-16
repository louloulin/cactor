/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - 简单测试
 * 验证新API的基本功能（不依赖扩展方法）
 */
package cactor.api.test

import cactor.core.actor.{Actor, PropsFactory}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.system.{SimpleActorSystem}
import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}
import std.time.*

/**
 * 简单测试Actor
 */
class ApiTestActor <: Actor {
    public prop name: String { get() { "ApiTestActor" } }
    public prop description: String { get() { "简单API测试Actor" } }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                println("ApiTestActor收到消息: ${msg.getContent()}")
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }
}

/**
 * 简单API测试主函数
 */
main(): Int64 {
    println("🚀 开始测试CActor新API...")
    
    try {
        // 1. 测试ActorSystem创建
        println("\n=== 测试ActorSystem创建 ===")
        let system = SimpleActorSystem("test-system")
        println("✅ 创建ActorSystem成功")
        
        // 2. 测试Props工厂
        println("\n=== 测试Props工厂 ===")
        let props = PropsFactory.create<Actor>({ => ApiTestActor() })
        println("✅ Props工厂创建成功")
        
        // 3. 测试Actor创建
        println("\n=== 测试Actor创建 ===")
        let actor = system.actorOf(props, "test-actor")
        println("✅ 创建Actor成功")
        
        // 4. 测试消息发送
        println("\n=== 测试消息发送 ===")
        actor.tell(StringMessage("Hello from new API!"))
        println("✅ 消息发送成功")
        
        // 5. 测试配置工厂
        println("\n=== 测试配置工厂 ===")
        let mailboxConfig = MailboxConfig.unbounded()
        let dispatcherConfig = DispatcherConfig.workStealing(4)
        let supervisionConfig = SupervisionConfig.restart(3, Duration.second * 1)
        println("✅ 配置工厂创建成功")
        
        // 6. 测试带配置的Props
        println("\n=== 测试带配置的Props ===")
        let configuredProps = PropsFactory.create<Actor>({ => ApiTestActor() })
            .withMailbox(mailboxConfig.getMailboxType())
            .withDispatcher(dispatcherConfig.getDispatcherType())
            .withSupervisionStrategy(supervisionConfig.getStrategyType())
        let configuredActor = system.actorOf(configuredProps, "configured-actor")
        configuredActor.tell(StringMessage("配置化Actor消息"))
        println("✅ 带配置的Actor创建成功")
        
        println("\n🎉 所有API测试通过！")
        println("==================")
        println("新API特点:")
        println("- 简化的Props创建")
        println("- 类型安全的配置工厂")
        println("- 链式配置支持")
        println("- 向后兼容")
        
        return 0
        
    } catch (e: Exception) {
        println("❌ 测试失败: ${e.message}")
        return 1
    }
}
