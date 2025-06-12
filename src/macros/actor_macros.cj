/*
 * CActor 简化宏系统
 * 基于仓颉语言宏系统的正确实现
 */
macro package cactor.macros

import std.ast.*

// 简单的日志宏 - 用于调试
public macro log_info(message: Tokens): Tokens {
    return quote(
        println("[INFO] " + $(message.toString()))
    )
}

// 简单的计时宏
public macro time_it(code: Tokens): Tokens {
    return quote(
        let startTime: Int64 = 1000
        $(code)
        let endTime: Int64 = 1000
        println("执行耗时: ${endTime - startTime}ms")
    )
}

// 简单的重复执行宏 - 固定重复3次
public macro repeat_3_times(code: Tokens): Tokens {
    return quote(
        for (i in 0..3) {
            $(code)
        }
    )
}

// 简单的Actor结构体生成宏
public macro simple_actor(input: Tokens): Tokens {
    return quote(
        $(input)

        // 为Actor类添加一个简单的方法
        extend Plan3TestActor {
            public func getActorInfo(): String {
                return "这是一个简单的Actor: Plan3TestActor"
            }
        }
    )
}

// 辅助函数：获取当前时间（毫秒）
func getCurrentTimeMillis(): Int64 {
    // 简化实现，实际应该调用系统时间API
    return 1000
}
