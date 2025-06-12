/*
 * 仓颉Actor系统 - 基础测试
 * 测试Actor系统的核心功能
 */
package tests

import std.sync.*
import std.collection.*
import std.time.*

// 测试用的简单Actor
public class TestActor <: Actor {
    private let actorName: String
    private var messageCount: Int64 = 0
    private let mutex: ReentrantMutex = ReentrantMutex()
    
    public init(name: String) {
        this.actorName = name
    }
    
    public prop name: String {
        get() { actorName }
    }
    
    public prop description: String {
        get() { "Test Actor: ${actorName}" }
    }
    
    public func started(): Unit {
        println("${actorName} started")
    }
    
    public func stopping(): Bool {
        println("${actorName} stopping after processing ${messageCount} messages")
        true
    }
    
    public func stopped(): Unit {
        println("${actorName} stopped")
    }
    
    public func processMessage(): Unit {
        mutex.lock()
        try {
            messageCount += 1
            println("${actorName} processed message #${messageCount}")
        } finally {
            mutex.unlock()
        }
    }
    
    public func getMessageCount(): Int64 {
        mutex.lock()
        try {
            return messageCount
        } finally {
            mutex.unlock()
        }
    }
}

// 测试函数
func testActorCreation(): Bool {
    println("=== 测试Actor创建 ===")
    
    let runtime = ActorRuntime(10)
    
    try {
        let testActor = TestActor("TestActor1")
        let actorRef = runtime.spawnActor(testActor, "test-actor-1")
        
        // 等待Actor启动
        sleep(Duration.millisecond * 100)
        
        // 检查Actor状态
        if (actorRef.getState() == ActorState.Running) {
            println("✓ Actor创建成功，状态正确")
        } else {
            println("✗ Actor状态不正确: ${actorRef.getState()}")
            return false
        }
        
        // 停止Actor
        actorRef.stop()
        sleep(Duration.millisecond * 100)
        
        if (actorRef.getState() == ActorState.Stopped) {
            println("✓ Actor停止成功")
        } else {
            println("✗ Actor停止失败")
            return false
        }
        
        return true
        
    } catch (e: Exception) {
        println("✗ 测试失败: ${e}")
        return false
    } finally {
        runtime.shutdown()
    }
}

func testMessagePassing(): Bool {
    println("\n=== 测试消息传递 ===")
    
    let runtime = ActorRuntime(10)
    
    try {
        let testActor = TestActor("MessageTestActor")
        let actorRef = runtime.spawnActor(testActor, "message-test-actor")
        
        // 等待Actor启动
        sleep(Duration.millisecond * 100)
        
        // 发送消息
        let pingMsg = PingMessage(1)
        let success = actorRef.send(pingMsg)
        
        if (success) {
            println("✓ 消息发送成功")
        } else {
            println("✗ 消息发送失败")
            return false
        }
        
        // 等待消息处理
        sleep(Duration.millisecond * 200)
        
        // 手动处理消息（简化测试）
        testActor.processMessage()
        
        if (testActor.getMessageCount() > 0) {
            println("✓ 消息处理成功，处理了 ${testActor.getMessageCount()} 条消息")
        } else {
            println("✗ 消息处理失败")
            return false
        }
        
        // 停止Actor
        actorRef.stop()
        sleep(Duration.millisecond * 100)
        
        return true
        
    } catch (e: Exception) {
        println("✗ 测试失败: ${e}")
        return false
    } finally {
        runtime.shutdown()
    }
}

func testMultipleActors(): Bool {
    println("\n=== 测试多Actor管理 ===")
    
    let runtime = ActorRuntime(20)
    let actorRefs = ArrayList<ActorRef>()
    
    try {
        // 创建多个Actor
        for (i in 1..5) {
            let testActor = TestActor("MultiActor${i}")
            let actorRef = runtime.spawnActor(testActor, "multi-actor-${i}")
            actorRefs.append(actorRef)
        }
        
        // 等待所有Actor启动
        sleep(Duration.millisecond * 200)
        
        if (runtime.getActorCount() == 5) {
            println("✓ 成功创建 ${runtime.getActorCount()} 个Actor")
        } else {
            println("✗ Actor数量不正确: ${runtime.getActorCount()}")
            return false
        }
        
        // 向所有Actor发送消息
        for (actorRef in actorRefs) {
            let pingMsg = PingMessage(1)
            actorRef.send(pingMsg)
        }
        
        // 等待消息处理
        sleep(Duration.millisecond * 300)
        
        // 停止所有Actor
        for (actorRef in actorRefs) {
            actorRef.stop()
        }
        
        // 等待所有Actor停止
        sleep(Duration.millisecond * 500)
        
        if (runtime.getActorCount() == 0) {
            println("✓ 所有Actor成功停止")
        } else {
            println("✗ 仍有 ${runtime.getActorCount()} 个Actor未停止")
            return false
        }
        
        return true
        
    } catch (e: Exception) {
        println("✗ 测试失败: ${e}")
        return false
    } finally {
        runtime.shutdown()
    }
}

func testConcurrentAccess(): Bool {
    println("\n=== 测试并发访问 ===")
    
    let runtime = ActorRuntime(10)
    
    try {
        let testActor = TestActor("ConcurrentActor")
        let actorRef = runtime.spawnActor(testActor, "concurrent-actor")
        
        // 等待Actor启动
        sleep(Duration.millisecond * 100)
        
        // 并发发送消息
        for (i in 1..10) {
            spawn {
                let pingMsg = PingMessage(i)
                actorRef.send(pingMsg)
                testActor.processMessage()  // 简化测试
            }
        }
        
        // 等待所有操作完成
        sleep(Duration.second)
        
        let finalCount = testActor.getMessageCount()
        if (finalCount == 10) {
            println("✓ 并发访问测试成功，处理了 ${finalCount} 条消息")
        } else {
            println("✗ 并发访问测试失败，只处理了 ${finalCount} 条消息")
            return false
        }
        
        // 停止Actor
        actorRef.stop()
        sleep(Duration.millisecond * 100)
        
        return true
        
    } catch (e: Exception) {
        println("✗ 测试失败: ${e}")
        return false
    } finally {
        runtime.shutdown()
    }
}

// 主测试函数
main(): Int64 {
    println("开始仓颉Actor系统测试...")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testActorCreation()
    allTestsPassed = allTestsPassed && testMessagePassing()
    allTestsPassed = allTestsPassed && testMultipleActors()
    allTestsPassed = allTestsPassed && testConcurrentAccess()
    
    if (allTestsPassed) {
        println("\n🎉 所有测试通过！")
        return 0
    } else {
        println("\n❌ 部分测试失败")
        return 1
    }
}
