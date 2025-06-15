/*
 * CActor 简单宏功能测试
 * 验证基础宏功能是否正常工作
 */
package cactor.integration.testing.simple_macro_test

import cactor.macros.*

// 测试简单宏功能
func testLogMacro(): Bool {
    println("🧪 测试日志宏...")
    
    // 测试log_info宏
    @log_info("这是一条测试日志")
    
    println("✅ 日志宏测试通过")
    return true
}

func testTimeMacro(): Bool {
    println("🧪 测试计时宏...")

    // 测试time_it宏
    @time_it(
        var sum: Int64 = 0
        for (i in 0..1000) {
            sum += i
        }
        println("计算结果: ${sum}")
    )

    println("✅ 计时宏测试通过")
    return true
}

func testRepeatMacro(): Bool {
    println("🧪 测试重复执行宏...")

    var counter: Int64 = 0

    // 测试repeat_3_times宏
    @repeat_3_times(
        counter += 1
        println("重复执行第${counter}次")
    )

    if (counter == 3) {
        println("✅ 重复执行宏测试通过")
        return true
    } else {
        println("❌ 重复执行宏测试失败，期望3，实际${counter}")
        return false
    }
}

// 简单宏测试函数 - 供主测试调用
func runSimpleMacroTests(): Bool {
    println("=== CActor 简单宏功能测试 ===")

    var allTestsPassed = true

    // 运行宏测试
    allTestsPassed = allTestsPassed && testLogMacro()
    allTestsPassed = allTestsPassed && testTimeMacro()
    allTestsPassed = allTestsPassed && testRepeatMacro()

    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有宏测试通过！")
        println("✅ 宏功能验证成功")
    } else {
        println("❌ 部分宏测试失败")
    }

    return allTestsPassed
}
