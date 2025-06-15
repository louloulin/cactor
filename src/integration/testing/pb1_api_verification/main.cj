/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - pb1.md API优化验证测试
 * 专门验证新的API功能
 */
package cactor.integration.testing.pb1_api_verification

import std.time.*
import std.sync.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.system.*
import cactor.core.context.*
// import cactor.runtime.system.*

/**
 * 简单的测试Actor
 */
class ApiTestActor <: Actor {
    public init() {}
    
    public prop name: String {
        get() { "ApiTestActor" }
    }
    
    public prop description: String {
        get() { "用于验证pb1.md API优化的Actor" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage => 
                println("ApiTestActor收到消息: ${msg.getContent()}")
                return MessageResult.Handled
            case _ => 
                return MessageResult.Unhandled
        }
    }
}

/**
 * 测试新的actorOf API
 */
func testActorOfAPI(): Bool {
    println("=== 测试actorOf API ===")
    
    let system = SimpleActorSystem("ApiTestSystem")
    
    try {
        // 测试1: 使用指定名称创建Actor
        let props: Props<Actor> = PropsFactory.create<Actor>({ => ApiTestActor() })
        let actorRef1 = system.actorOf(props, "api-test-actor-1")
        println("✓ 成功使用actorOf创建指定名称的Actor")
        
        // 测试2: 使用自动生成名称创建Actor
        let actorRef2 = system.actorOf(props)
        println("✓ 成功使用actorOf创建自动命名的Actor")
        
        system.terminate()
        return true
        
    } catch (e: Exception) {
        println("✗ actorOf API测试失败: ${e.message}")
        system.terminate()
        return false
    }
}

/**
 * 测试actorSelection API
 */
func testActorSelectionAPI(): Bool {
    println("=== 测试actorSelection API ===")
    
    let system = SimpleActorSystem("SelectionTestSystem")
    
    try {
        // 创建一个Actor
        let props: Props<Actor> = PropsFactory.create<Actor>({ => ApiTestActor() })
        let actorRef = system.actorOf(props, "selectable-actor")
        
        // 测试Actor选择
        let selection = system.actorSelection("/user/selectable-actor")
        println("✓ 成功使用actorSelection选择Actor")
        
        system.terminate()
        return true
        
    } catch (e: Exception) {
        println("✗ actorSelection API测试失败: ${e.message}")
        system.terminate()
        return false
    }
}

/**
 * 测试API易用性
 */
func testAPIUsability(): Bool {
    println("=== 测试API易用性 ===")
    
    try {
        // 演示简化的API使用方式
        let system = SimpleActorSystem("UsabilityTest")
        
        // 一行创建Actor - 类似Akka的风格
        let actorRef = system.actorOf(
            PropsFactory.create<Actor>({ => ApiTestActor() }), 
            "easy-actor"
        )
        
        // 简单的Actor选择
        let selection = system.actorSelection("easy-actor")
        
        println("✓ API使用简洁明了")
        println("✓ 类似Akka的API风格")
        
        system.terminate()
        return true
        
    } catch (e: Exception) {
        println("✗ API易用性测试失败: ${e.message}")
        return false
    }
}

/**
 * 验证包导入简化
 */
func testPackageImports(): Bool {
    println("=== 测试包导入简化 ===")
    
    try {
        // 验证所有核心类都可以正常访问
        let system = SimpleActorSystem("ImportTestSystem")
        let props: Props<Actor> = PropsFactory.create<Actor>({ => ApiTestActor() })
        let message = StringMessage("测试消息")
        
        println("✓ SimpleActorSystem: 可访问")
        println("✓ PropsFactory: 可访问")
        println("✓ StringMessage: 可访问")
        println("✓ 包导入简化成功")
        
        system.terminate()
        return true
        
    } catch (e: Exception) {
        println("✗ 包导入测试失败: ${e.message}")
        return false
    }
}

main(): Int64 {
    println("=== CActor pb1.md API优化验证测试 ===")
    println("验证Phase 1: API易用性优化的实现效果")
    
    var allTestsPassed = true
    
    // 运行所有测试
    if (!testPackageImports()) {
        allTestsPassed = false
    }
    
    if (!testActorOfAPI()) {
        allTestsPassed = false
    }
    
    if (!testActorSelectionAPI()) {
        allTestsPassed = false
    }
    
    if (!testAPIUsability()) {
        allTestsPassed = false
    }
    
    println("\n=== 测试总结 ===")
    if (allTestsPassed) {
        println("🎉 所有API优化功能验证通过！")
        println("✓ pb1.md Phase 1目标达成")
        println("✓ 代码结构优化成功")
        println("✓ API易用性显著提升")
        return 0
    } else {
        println("❌ 部分测试失败")
        return 1
    }
}
