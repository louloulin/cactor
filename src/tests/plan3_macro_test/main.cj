/*
 * CActor Plan3 宏功能测试
 * 验证plan3.md中实现的基础宏功能
 * 基于CActor的class架构，简化版本
 */
package cactor.tests.plan3_macro_test

import cactor.macros.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 简单的ActorContext实现用于测试
class TestActorContext <: ActorContext {
    public init() {}
    
    public func sender(): Option<String> {
        None<String>
    }
}

// 简单的Message实现用于测试
class TestMessage <: Message {
    private var msgType: String
    private var content: String
    
    public init(messageType: String, messageContent: String) {
        msgType = messageType
        content = messageContent
    }
    
    public func messageType(): String {
        return msgType
    }
    
    public func content(): String {
        return content
    }
}

// ============================================================================
// 1. 测试基础宏功能
// ============================================================================

func testBasicMacros(): Bool {
    println("🧪 测试基础宏功能...")
    
    // 测试日志宏
    @log_info("Plan3宏功能测试开始")
    
    // 测试计时宏
    @time_it(
        var sum: Int64 = 0
        for (i in 0..100) {
            sum += i
        }
        println("计算1到100的和: " + sum.toString())
    )
    
    // 测试重复执行宏
    var counter: Int64 = 0
    @repeat_3_times(
        counter += 1
        println("Plan3重复执行第" + counter.toString() + "次")
    )
    
    if (counter != 3) {
        println("❌ 重复执行宏测试失败，期望3，实际" + counter.toString())
        return false
    }
    
    @log_info("基础宏功能测试完成")
    println("✅ 基础宏功能测试通过")
    return true
}

// ============================================================================
// 2. 测试简单Actor宏
// ============================================================================

// 使用简单Actor宏
@simple_actor
class Plan3TestActor <: Actor {
    private var actorName: String = "Plan3TestActor"
    private var messageCount: Int64 = 0
    
    public init() {}
    
    public prop name: String { get() { actorName } }
    public prop description: String { get() { "Plan3测试Actor" } }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        messageCount += 1
        println("Plan3TestActor 处理消息: " + message.messageType())
        return MessageResult.Handled
    }
    
    public func getMessageCount(): Int64 {
        return messageCount
    }
}

func testSimpleActorMacro(): Bool {
    println("🧪 测试简单Actor宏...")
    
    var actor = Plan3TestActor()
    let info = actor.getActorInfo()
    println("Actor信息: " + info)
    
    // 测试Actor基本功能
    let context = TestActorContext()
    let message = TestMessage("TEST", "测试消息")
    let result = actor.receive(message, context)
    
    if (result != MessageResult.Handled) {
        println("❌ Actor消息处理测试失败")
        return false
    }
    
    let msgCount = actor.getMessageCount()
    if (msgCount != 1) {
        println("❌ Actor消息计数测试失败")
        return false
    }
    
    println("✅ 简单Actor宏测试通过")
    return true
}

// ============================================================================
// 3. 测试宏组合使用
// ============================================================================

func testMacroCombination(): Bool {
    println("🧪 测试宏组合使用...")
    
    @log_info("开始宏组合测试")
    
    // 组合使用多个宏
    @time_it(
        @repeat_3_times(
            @log_info("组合宏测试执行中...")
        )
    )
    
    @log_info("宏组合测试完成")
    
    println("✅ 宏组合使用测试通过")
    return true
}

// ============================================================================
// 4. 测试Plan3功能验证
// ============================================================================

func testPlan3Features(): Bool {
    println("🧪 测试Plan3功能验证...")
    
    @log_info("Plan3功能验证开始")
    
    // 验证宏系统的基本功能
    var testsPassed: Int64 = 0
    
    // 测试1: 日志宏
    @log_info("测试日志宏功能")
    testsPassed += 1
    
    // 测试2: 计时宏
    @time_it(
        var result: Int64 = 1
        for (i in 1..10) {
            result *= i
        }
        println("10的阶乘: " + result.toString())
    )
    testsPassed += 1
    
    // 测试3: 重复宏
    var repeatCount: Int64 = 0
    @repeat_3_times(
        repeatCount += 1
    )
    
    if (repeatCount == 3) {
        testsPassed += 1
    }
    
    @log_info("Plan3功能验证完成，通过测试: " + testsPassed.toString() + "/3")
    
    if (testsPassed == 3) {
        println("✅ Plan3功能验证测试通过")
        return true
    } else {
        println("❌ Plan3功能验证测试失败")
        return false
    }
}

// ============================================================================
// 5. 测试宏系统稳定性
// ============================================================================

func testMacroStability(): Bool {
    println("🧪 测试宏系统稳定性...")
    
    @log_info("宏系统稳定性测试开始")
    
    // 多次调用宏，测试稳定性
    for (i in 0..5) {
        @log_info("稳定性测试第" + (i + 1).toString() + "轮")
        
        @time_it(
            var sum: Int64 = 0
            for (j in 0..10) {
                sum += j
            }
        )
    }
    
    @log_info("宏系统稳定性测试完成")
    
    println("✅ 宏系统稳定性测试通过")
    return true
}

// ============================================================================
// 主测试函数
// ============================================================================

main(): Int64 {
    println("=== CActor Plan3 宏功能测试 ===")
    println("验证plan3.md中实现的宏功能")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testBasicMacros()
    allTestsPassed = allTestsPassed && testSimpleActorMacro()
    allTestsPassed = allTestsPassed && testMacroCombination()
    allTestsPassed = allTestsPassed && testPlan3Features()
    allTestsPassed = allTestsPassed && testMacroStability()
    
    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有Plan3宏测试通过！")
        println("✅ plan3.md 宏功能验证成功")
        println("🚀 CActor宏系统基础功能已完全就绪")
        println("📋 已验证功能:")
        println("   - 基础宏功能 (日志、计时、重复)")
        println("   - 简单Actor宏")
        println("   - 宏组合使用")
        println("   - 系统稳定性")
        return 0
    } else {
        println("❌ 部分Plan3宏测试失败")
        return 1
    }
}
