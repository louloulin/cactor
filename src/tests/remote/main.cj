/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 远程通信测试主程序
 */
package cactor.tests.remote

main(): Int64 {
    println("=== CACtor 2.0 远程通信功能测试 ===")
    
    try {
        runRemoteCommunicationTests()
        println("✅ 所有测试通过")
        return 0
    } catch (e: Exception) {
        println("❌ 测试失败: ${e.message}")
        return 1
    }
}
