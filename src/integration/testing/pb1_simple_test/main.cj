/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - pb1.md API优化简化验证测试
 */
package cactor.integration.testing.pb1_simple_test

import std.time.*
import std.sync.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.system.*
import cactor.core.context.*
// import cactor.runtime.system.*

/**
 * 简化的测试Actor
 */
class SimpleTestActor <: Actor {
    public init() {}
    
    public prop name: String {
        get() { "SimpleTestActor" }
    }
    
    public prop description: String {
        get() { "简化的测试Actor" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage => 
                println("收到消息: ${msg.getContent()}")
                return MessageResult.Handled
            case _ => 
                return MessageResult.Unhandled
        }
    }
}

/**
 * 测试新的API功能
 */
func testNewAPI(): Unit {
    println("=== 测试pb1.md API优化 ===")
    
    // 测试1: 创建Actor系统
    let system = SimpleActorSystem("TestSystem")
    println("✓ 成功创建SimpleActorSystem")
    
    // 测试2: 创建Props
    let props: Props<Actor> = PropsFactory.create<Actor>({ => SimpleTestActor() })
    println("✓ 成功创建Props")
    
    // 测试3: 使用actorOf创建Actor
    try {
        let actorRef = system.actorOf(props, "test-actor")
        println("✓ 成功使用actorOf创建Actor")
    } catch (e: Exception) {
        println("✗ actorOf失败: ${e.message}")
    }
    
    // 测试4: 使用actorSelection
    try {
        let selection = system.actorSelection("test-actor")
        println("✓ 成功使用actorSelection")
    } catch (e: Exception) {
        println("✗ actorSelection失败: ${e.message}")
    }
    
    // 测试5: 自动生成名称的actorOf
    try {
        let actorRef2 = system.actorOf(props)
        println("✓ 成功使用自动生成名称的actorOf")
    } catch (e: Exception) {
        println("✗ 自动生成名称的actorOf失败: ${e.message}")
    }
    
    system.terminate()
    println("✓ 系统正常终止")
}

main(): Int64 {
    println("=== CActor pb1.md API优化验证 ===")
    testNewAPI()
    println("=== 测试完成 ===")
    return 0
}
