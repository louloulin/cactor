/*
 * CActor cjpm宏编译测试
 * 验证通过cjpm编译的宏功能是否正常工作
 */
package cactor.tests.cjpm_macro_test

import cactor.macros.*

// 测试日志宏
func testLogMacro(): Bool {
    println("🧪 测试cjpm编译的日志宏...")
    
    @log_info("这是通过cjpm编译的宏测试")
    
    println("✅ 日志宏测试通过")
    return true
}

// 测试计时宏
func testTimeMacro(): Bool {
    println("🧪 测试cjpm编译的计时宏...")
    
    @time_it(
        var sum: Int64 = 0
        for (i in 0..1000) {
            sum += i
        }
        println("计算1到1000的和: ${sum}")
    )
    
    println("✅ 计时宏测试通过")
    return true
}

// 测试重复执行宏
func testRepeatMacro(): Bool {
    println("🧪 测试cjpm编译的重复执行宏...")
    
    var counter: Int64 = 0
    
    @repeat_3_times(
        counter += 1
        println("cjpm宏重复执行第${counter}次")
    )
    
    if (counter == 3) {
        println("✅ 重复执行宏测试通过")
        return true
    } else {
        println("❌ 重复执行宏测试失败，期望3，实际${counter}")
        return false
    }
}

// 使用simple_actor宏定义Actor（必须在顶层）
@simple_actor(
    struct CjpmCounterActor {
        var count: Int64 = 0

        public mut func increment(): Unit {
            count += 1
            println("cjpm Actor计数增加，当前值: ${count}")
        }

        public func getCount(): Int64 {
            return count
        }
    }
)

// 测试Actor宏
func testActorMacro(): Bool {
    println("🧪 测试cjpm编译的Actor宏...")

    // 测试Actor功能
    var actor = CjpmCounterActor()
    actor.increment()
    actor.increment()

    let count = actor.getCount()
    if (count != 2) {
        println("❌ Actor基本功能测试失败，期望2，实际${count}")
        return false
    }

    // 测试宏生成的方法
    let info = actor.getActorInfo()
    println("cjpm Actor信息: ${info}")

    println("✅ Actor宏测试通过")
    return true
}

// 综合测试
func testAllMacros(): Bool {
    println("🧪 测试所有cjpm编译的宏功能...")
    
    @log_info("开始cjpm宏综合测试")
    
    // 组合使用多个宏
    @time_it(
        @repeat_3_times(
            @log_info("组合宏测试执行中...")
        )
    )
    
    @log_info("cjpm宏综合测试完成")
    
    println("✅ 所有宏功能测试通过")
    return true
}

// 主测试函数
main(): Int64 {
    println("=== CActor cjpm宏编译功能测试 ===")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testLogMacro()
    allTestsPassed = allTestsPassed && testTimeMacro()
    allTestsPassed = allTestsPassed && testRepeatMacro()
    allTestsPassed = allTestsPassed && testActorMacro()
    allTestsPassed = allTestsPassed && testAllMacros()
    
    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有cjpm宏测试通过！")
        println("✅ cjpm宏编译功能验证成功")
        println("🚀 宏包通过cjpm成功编译和使用")
        return 0
    } else {
        println("❌ 部分cjpm宏测试失败")
        return 1
    }
}
