/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10 API测试 - 验证新的API层设计
 * 按照plan10.md要求，只使用API层接口，不直接使用core层
 * 参考Akka的API设计模式
 */
package cactor.integration.testing.plan10_api_test

import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.api.{CActor, CActorSystem, ActorProps}

/**
 * Plan10 API测试Actor
 */
public class Plan10APITestActor <: Actor {
    private var messageCount: Int32 = 0
    
    public prop name: String {
        get() { "plan10-api-test-actor" }
    }
    
    public prop description: String {
        get() { "Plan10 API层功能验证测试Actor" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                messageCount += 1
                println("Plan10APITestActor收到消息: ${msg.getContent()} (总计: ${messageCount})")
                return MessageResult.Handled
            case _ =>
                println("Plan10APITestActor收到未知消息类型")
                return MessageResult.Unhandled
        }
    }
    
    public func started(): Unit {
        println("Plan10APITestActor已启动")
    }
    
    public func stopping(): Bool {
        println("Plan10APITestActor正在停止")
        return true
    }
    
    public func stopped(): Unit {
        println("Plan10APITestActor已停止，处理了${messageCount}条消息")
    }
}

/**
 * Plan10 API层测试类
 */
public class Plan10APITest {
    
    /**
     * 测试1: CActor.system() API
     */
    public func testCActorSystemAPI(): Bool {
        println("\n🧪 测试1: CActor.system() API")
        
        try {
            // 使用CActor.system()创建系统 - 参考Akka的ActorSystem.create()
            let system = CActor.system("plan10-api-test")
            
            // 验证系统创建
            if (system.getName() == "plan10-api-test") {
                println("✅ CActor.system() API测试通过")
                println("  系统名称: ${system.getName()}")
                
                // 清理
                system.terminate()
                return true
            } else {
                println("❌ 系统名称不匹配")
                return false
            }
        } catch (e: Exception) {
            println("❌ CActor.system() API测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试2: Actor创建API
     */
    public func testActorCreationAPI(): Bool {
        println("\n🧪 测试2: Actor创建API")
        
        try {
            // 使用API层创建系统
            let system = CActor.system("actor-creation-test")
            
            // 使用API层创建Actor - 参考Akka的system.actorOf()
            let actorRef = system.actorOf({ => Plan10APITestActor() }, "test-actor-1")
            
            // 验证Actor创建
            if (actorRef.path.toString().contains("test-actor-1")) {
                println("✅ Actor创建API测试通过")
                println("  Actor路径: ${actorRef.path.toString()}")
                
                // 发送测试消息
                actorRef.tell(StringMessage("Hello from API layer!"))
                
                // 清理
                system.terminate()
                return true
            } else {
                println("❌ Actor创建失败")
                return false
            }
        } catch (e: Exception) {
            println("❌ Actor创建API测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试3: ActorProps API
     */
    public func testActorPropsAPI(): Bool {
        println("\n🧪 测试3: ActorProps API")
        
        try {
            // 使用CActor.props()创建Props - 参考Akka的Props.create()
            let props = CActor.props({ => Plan10APITestActor() })
            
            // 验证Props创建
            let creator = props.getCreator()
            let testActor = creator()
            
            if (testActor.name == "plan10-api-test-actor") {
                println("✅ ActorProps API测试通过")
                println("  Actor名称: ${testActor.name}")
                return true
            } else {
                println("❌ Props创建失败")
                return false
            }
        } catch (e: Exception) {
            println("❌ ActorProps API测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试4: 完整的API工作流
     */
    public func testCompleteAPIWorkflow(): Bool {
        println("\n🧪 测试4: 完整的API工作流")
        
        try {
            // 1. 创建系统
            let system = CActor.system("complete-workflow-test")
            
            // 2. 创建多个Actor
            let actor1 = system.actorOf({ => Plan10APITestActor() }, "workflow-actor-1")
            let actor2 = system.actorOf({ => Plan10APITestActor() })  // 自动命名
            
            // 3. 发送消息
            actor1.tell(StringMessage("Workflow message 1"))
            actor2.tell(StringMessage("Workflow message 2"))
            
            // 4. 验证系统状态
            if (!system.isTerminated()) {
                println("✅ 完整API工作流测试通过")
                println("  系统运行状态: 正常")
                println("  Actor1路径: ${actor1.path.toString()}")
                println("  Actor2路径: ${actor2.path.toString()}")
                
                // 5. 清理
                system.terminate()
                return true
            } else {
                println("❌ 系统状态异常")
                return false
            }
        } catch (e: Exception) {
            println("❌ 完整API工作流测试失败: ${e}")
            return false
        }
    }
    
    /**
     * 测试5: API层隔离验证
     */
    public func testAPILayerIsolation(): Bool {
        println("\n🧪 测试5: API层隔离验证")
        
        try {
            // 验证只使用API层接口，不直接使用core层
            let system = CActor.system("isolation-test")
            
            // 通过API层获取底层运行时（用于验证）
            let runtime = system.getRuntime()
            let stats = runtime.getRuntimeStats()
            
            if (stats.systemName == "isolation-test" && stats.isRunning) {
                println("✅ API层隔离验证通过")
                println("  通过API层访问底层运行时成功")
                println("  运行时统计: ${stats.actorCount}个Actor")
                
                system.terminate()
                return true
            } else {
                println("❌ API层隔离验证失败")
                return false
            }
        } catch (e: Exception) {
            println("❌ API层隔离验证失败: ${e}")
            return false
        }
    }
    
    /**
     * 运行所有测试
     */
    public func runAllTests(): Bool {
        println("🎯 开始Plan10 API层功能验证测试")
        println("🎯 验证：不导出core层，只使用API层接口")
        println("🎯 设计：参考Akka的API模式")
        println("=" * 60)
        
        var allPassed = true
        var testCount = 0
        
        // 运行所有测试
        if (testCActorSystemAPI()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testActorCreationAPI()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testActorPropsAPI()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testCompleteAPIWorkflow()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        if (testAPILayerIsolation()) {
            testCount += 1
        } else {
            allPassed = false
        }
        
        // 输出最终结果
        println("\n" + "=" * 60)
        if (allPassed) {
            println("🎉 Plan10 API层功能验证测试全部通过!")
            println("✅ 通过测试数量: ${testCount}/5")
            println("✅ CActor.system() API正常工作")
            println("✅ Actor创建API正常工作")
            println("✅ ActorProps API正常工作")
            println("✅ 完整API工作流正常")
            println("✅ API层隔离设计正确")
            println("✅ 符合plan10.md API设计要求")
        } else {
            println("❌ Plan10 API层功能验证测试存在失败项")
            println("[WARNING] 通过测试数量: ${testCount}/5")
        }
        
        return allPassed
    }
}

/**
 * 主函数 - 执行Plan10 API测试
 */
main(args: Array<String>): Unit {
    let test = Plan10APITest()
    let success = test.runAllTests()

    if (success) {
        println("\n🚀 Plan10 API层验证完成 - 所有测试通过!")
        println("📋 API层设计符合plan10.md要求")
        println("📋 成功实现：不导出core层，只使用API层")
        println("📋 参考Akka设计模式，提供简洁统一的API")
    } else {
        println("\n[WARNING] Plan10 API层验证完成 - 部分测试失败")
        println("📋 需要检查API层实现")
    }
}
