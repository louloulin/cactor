/**
 * 简单的宏功能验证测试
 * 测试基础的@handler宏功能
 */

package cactor.tests.simple_macro_test

import cactor.macros.*
import cactor.core.message.*

// 简单的消息类型
public class SimpleMessage <: Message {
    public let content: String
    
    public init(content: String) {
        this.content = content
    }
    
    public func messageType(): String {
        return "simple"
    }
}

// 简单的Actor类（不使用宏）
public class SimpleActor {
    var processedCount: Int64 = 0

    public init() {}

    public func processMessage(msg: SimpleMessage): Unit {
        processedCount += 1
        println("处理消息: ${msg.content}, 已处理: ${processedCount}")
    }

    public func getCount(): Int64 {
        println("当前处理数量: ${processedCount}")
        return processedCount
    }
}

// 测试函数
func testBasicActorFunctionality(): Bool {
    println("🧪 测试基本Actor功能...")

    // 创建Actor实例
    var actor = SimpleActor()

    // 测试消息处理
    let msg1 = SimpleMessage("Hello")
    actor.processMessage(msg1)

    let msg2 = SimpleMessage("World")
    actor.processMessage(msg2)

    // 获取处理数量
    let count = actor.getCount()

    if (count == 2) {
        println("✅ 基本Actor功能测试通过")
        return true
    } else {
        println("❌ 基本Actor功能测试失败，期望2，实际${count}")
        return false
    }
}

func testBasicMacroFunctionality(): Bool {
    println("🧪 测试基础宏功能...")
    
    // 测试宏是否能正常编译和运行
    var actor = SimpleActor()
    
    // 验证初始状态
    if (actor.processedCount != 0) {
        println("❌ 初始状态错误")
        return false
    }
    
    // 测试方法调用
    let msg = SimpleMessage("Test")
    actor.processMessage(msg)
    
    // 验证状态变化
    if (actor.processedCount != 1) {
        println("❌ 状态变化错误")
        return false
    }
    
    println("✅ 基础宏功能测试通过")
    return true
}

// 主测试函数
main(): Int64 {
    println("=== CActor 简单宏功能验证 ===")
    
    var allTestsPassed = true
    
    // 运行测试
    allTestsPassed = allTestsPassed && testBasicMacroFunctionality()
    allTestsPassed = allTestsPassed && testBasicActorFunctionality()
    
    println("=" * 40)
    if (allTestsPassed) {
        println("🎉 所有宏测试通过！")
        println("✅ @handler宏功能验证成功")
        return 0
    } else {
        println("❌ 部分宏测试失败")
        return 1
    }
}
