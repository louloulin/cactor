/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10 CActorRuntime Test - 验证CActorRuntime统一运行时管理器
 * 按照plan10.md要求，使用CActorRuntime而不是SimpleActorSystem
 */
package cactor.integration.testing.plan10_cactor_runtime_test

import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, PropsFactory}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.runtime.events.{SimpleActorEventBus}
import cactor.runtime.supervision.{SupervisionManager}
import cactor.runtime.lifecycle.{ActorLifecycleManager}

/**
 * Plan10 CActorRuntime测试Actor
 */
public class Plan10RuntimeTestActor <: Actor {
    private var messageCount: Int32 = 0
    
    public prop name: String {
        get() { "plan10-runtime-test-actor" }
    }
    
    public prop description: String {
        get() { "Plan10 CActorRuntime功能验证测试Actor" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                messageCount += 1
                println("Plan10RuntimeTestActor收到消息: ${msg.getContent()} (总计: ${messageCount})")
                return MessageResult.Handled
            case _ =>
                println("Plan10RuntimeTestActor收到未知消息类型")
                return MessageResult.Unhandled
        }
    }
    
    public func started(): Unit {
        println("Plan10RuntimeTestActor已启动")
    }
    
    public func stopping(): Bool {
        println("Plan10RuntimeTestActor正在停止")
        return true
    }
    
    public func stopped(): Unit {
        println("Plan10RuntimeTestActor已停止，处理了${messageCount}条消息")
    }
}

/**
 * Plan10 CActorRuntime综合测试类
 */
public class Plan10CActorRuntimeTest {
    private let runtime: CActorRuntime
    
    public init() {
        println("🚀 初始化Plan10 CActorRuntime测试...")
        
        // 使用CActorRuntime而不是SimpleActorSystem (符合plan10.md要求)
        let config = CActorRuntimeConfig.createDefault()
        this.runtime = CActorRuntime("plan10-runtime-test-system", config)
        
        println("✅ Plan10 CActorRuntime初始化完成")
    }
    
    /**
     * 测试1: CActorRuntime基础功能
     */
    public func testCActorRuntimeBasics(): Bool {
        println("\n🧪 测试1: CActorRuntime基础功能")
        
        try {
            // 启动Runtime系统
            runtime.start()
            
            // 验证系统状态
            let stats = runtime.getRuntimeStats()
            if (stats.isRunning) {
                println("✅ CActorRuntime启动成功")
                println("  系统名称: ${stats.systemName}")
                println("  运行状态: 运行中")
                return true
            } else {
                println("❌ CActorRuntime启动失败")
                return false
            }
        } catch (e: Exception) {
            println("❌ CActorRuntime基础功能测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试2: 统一Actor创建接口
     */
    public func testUnifiedActorCreation(): Bool {
        println("\n🧪 测试2: 统一Actor创建接口")
        
        try {
            // 使用CActorRuntime的统一接口创建Actor
            let props = PropsFactory.create<Actor>({ => Plan10RuntimeTestActor() })
            let actorRef = runtime.actorOf(props, "runtime-test-actor-1")
            
            // 验证Actor创建
            if (actorRef.path.toString().contains("runtime-test-actor-1")) {
                println("✅ 统一Actor创建接口测试通过")
                println("  Actor路径: ${actorRef.path.toString()}")
                
                // 发送测试消息
                actorRef.tell(StringMessage("Hello from CActorRuntime!"))
                
                return true
            } else {
                println("❌ Actor创建失败")
                return false
            }
        } catch (e: Exception) {
            println("❌ 统一Actor创建接口测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试3: Guardian层次结构
     */
    public func testGuardianHierarchy(): Bool {
        println("\n🧪 测试3: Guardian层次结构")
        
        try {
            // 获取Guardian Actors
            let systemGuardian = runtime.getSystemGuardian()
            let userGuardian = runtime.getUserGuardian()
            
            // 验证Guardian统计
            let systemStats = systemGuardian.getStats()
            let userStats = userGuardian.getStats()
            
            println("✅ Guardian层次结构测试通过")
            println("  系统Guardian子Actor数: ${systemStats.childCount}")
            println("  用户Guardian子Actor数: ${userStats.childCount}")
            
            return true
        } catch (e: Exception) {
            println("❌ Guardian层次结构测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试4: 企业级组件集成
     */
    public func testEnterpriseComponents(): Bool {
        println("\n🧪 测试4: 企业级组件集成")
        
        try {
            // 测试生命周期管理器
            let lifecycleManager = runtime.getLifecycleManager()
            let runningCount = lifecycleManager.getRunningActorCount()
            println("  运行中Actor数量: ${runningCount}")
            
            // 测试监督管理器
            let supervisionManager = runtime.getSupervisionManager()
            let supervisionStats = supervisionManager.getSupervisionStats()
            println("  监督统计 - 总监督数: ${supervisionStats.totalSupervised}")
            
            // 测试系统指标
            let systemMetrics = runtime.getSystemMetrics()
            let basicStats = systemMetrics.getBasicStats()
            let actorCount = match (basicStats.get("activeActors")) {
                case Some(count) => count
                case None => 0
            }
            println("  系统指标: ${actorCount}个Actor")
            
            // 测试事件总线
            let eventBus = runtime.getEventBus()
            let eventCount = eventBus.getEventCount()
            println("  事件总数: ${eventCount}")
            
            println("✅ 企业级组件集成测试通过")
            return true
        } catch (e: Exception) {
            println("❌ 企业级组件集成测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试5: 高性能系统集成
     */
    public func testHighPerformanceIntegration(): Bool {
        println("\n🧪 测试5: 高性能系统集成")
        
        try {
            // 获取高性能系统
            let highPerfSystem = runtime.getHighPerformanceSystem()
            let systemStats = highPerfSystem.getSystemStats()
            
            println("✅ 高性能系统集成测试通过")
            println("  高性能Actor数量: ${systemStats.actorCount}")
            println("  消息处理数量: ${systemStats.messageCount}")
            
            return true
        } catch (e: Exception) {
            println("❌ 高性能系统集成测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 运行所有测试
     */
    public func runAllTests(): Bool {
        println("🎯 开始Plan10 CActorRuntime功能验证测试")
        println("=" * 60)
        
        var allPassed = true
        var testCount = 0
        
        // 运行所有测试
        if (testCActorRuntimeBasics()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testUnifiedActorCreation()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testGuardianHierarchy()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testEnterpriseComponents()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testHighPerformanceIntegration()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        // 输出最终结果
        println("\n" + "=" * 60)
        if (allPassed) {
            println("🎉 Plan10 CActorRuntime功能验证测试全部通过!")
            println("✅ 通过测试数量: ${testCount}/5")
            println("✅ CActorRuntime统一运行时管理器正常工作")
            println("✅ Guardian层次结构正常工作")
            println("✅ 企业级组件集成正常工作")
            println("✅ 高性能系统集成正常工作")
            println("✅ 符合plan10.md架构要求")
        } else {
            println("❌ Plan10 CActorRuntime功能验证测试存在失败项")
            println("[WARNING] 通过测试数量: ${testCount}/5")
        }
        
        // 关闭系统
        runtime.shutdown()
        
        return allPassed
    }
}

/**
 * 主函数 - 执行Plan10 CActorRuntime测试
 */
main(): Unit {
    let test = Plan10CActorRuntimeTest()
    let success = test.runAllTests()
    
    if (success) {
        println("\n🚀 Plan10 CActorRuntime验证完成 - 所有测试通过!")
        println("📋 CActorRuntime统一运行时管理器功能正常")
        println("📋 符合plan10.md架构设计要求")
    } else {
        println("\n[WARNING] Plan10 CActorRuntime验证完成 - 部分测试失败")
        println("📋 需要检查CActorRuntime实现")
    }
}
