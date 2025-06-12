/*
 * CActor Actor宏功能测试
 * 验证Actor相关宏功能是否正常工作
 */
package cactor.tests.simple_macro_test

import cactor.macros.*

// 使用simple_actor宏定义一个简单的Actor
@simple_actor(
    struct CounterActor {
        var count: Int64 = 0

        public mut func increment(): Unit {
            count += 1
            println("计数器增加，当前值: ${count}")
        }

        public func getCount(): Int64 {
            return count
        }
    }
)

// 测试Actor宏功能
func testActorMacro(): Bool {
    println("🧪 测试Actor宏...")
    
    // 创建Actor实例
    var actor = CounterActor()
    
    // 测试基本功能
    actor.increment()
    actor.increment()
    
    let count = actor.getCount()
    if (count != 2) {
        println("❌ Actor基本功能测试失败，期望2，实际${count}")
        return false
    }
    
    // 测试宏生成的方法
    let info = actor.getActorInfo()
    println("Actor信息: ${info}")
    
    println("✅ Actor宏测试通过")
    return true
}

// 测试所有宏功能
func testAllMacros(): Bool {
    println("🧪 测试所有宏功能...")
    
    var success = true
    
    // 测试日志宏
    @log_info("开始测试所有宏功能")
    
    // 测试计时宏
    @time_it(
        var sum: Int64 = 0
        for (i in 0..100) {
            sum += i
        }
        println("计算1到100的和: ${sum}")
    )
    
    // 测试重复宏
    var repeatCount: Int64 = 0
    @repeat_3_times(
        repeatCount += 1
        println("重复计数: ${repeatCount}")
    )
    
    if (repeatCount != 3) {
        println("❌ 重复宏测试失败")
        success = false
    }
    
    @log_info("所有宏功能测试完成")
    
    if (success) {
        println("✅ 所有宏功能测试通过")
    }
    
    return success
}

// 主测试函数
main(): Int64 {
    println("=== CActor Actor宏功能测试 ===")
    
    var allTestsPassed = true
    
    // 运行测试
    allTestsPassed = allTestsPassed && testActorMacro()
    allTestsPassed = allTestsPassed && testAllMacros()
    
    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有Actor宏测试通过！")
        println("✅ Actor宏功能验证成功")
        return 0
    } else {
        println("❌ 部分Actor宏测试失败")
        return 1
    }
}
