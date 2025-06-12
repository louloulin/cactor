/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 批量处理邮箱测试
 * 验证批量处理功能
 */
package cactor.tests

import std.sync.*
import std.time.*
import cactor.mailbox.batching.*
import cactor.core.message.{Envelope, PingMessage}

/**
 * 测试批量处理邮箱基础功能
 */
func testBatchingMailboxBasics(): Bool {
    let batchSize: Int64 = 3
    let batchTimeout = Duration.second
    let mailbox = BatchingMailbox(batchSize, batchTimeout)

    // 测试初始状态
    if (!mailbox.isEmpty()) {
        println("✗ 邮箱初始状态应该为空")
        return false
    }

    if (mailbox.size() != 0) {
        println("✗ 邮箱初始大小应该为0")
        return false
    }

    if (mailbox.getBatchSize() != batchSize) {
        println("✗ 批次大小应该为${batchSize}")
        return false
    }

    // 添加消息但不触发批处理
    let message1 = PingMessage(1)
    let envelope1 = Envelope(message1, Some("sender1"))
    if (!mailbox.enqueue(envelope1)) {
        println("✗ 入队应该成功")
        return false
    }

    let message2 = PingMessage(2)
    let envelope2 = Envelope(message2, Some("sender2"))
    if (!mailbox.enqueue(envelope2)) {
        println("✗ 入队应该成功")
        return false
    }

    if (mailbox.isEmpty()) {
        println("✗ 添加消息后邮箱不应该为空")
        return false
    }

    if (mailbox.size() != 2) {
        println("✗ 添加2条消息后大小应该为2")
        return false
    }

    // 此时不应该有批次产生（未达到批次大小）
    let batch1 = mailbox.processBatch()
    if (!batch1.isEmpty()) {
        println("✗ 未达到批次大小时不应该产生批次")
        return false
    }

    println("✓ 批量处理邮箱基础功能测试通过")
    return true
}

/**
 * 主测试函数
 */
func runBatchingTests() {
    println("=== CACtor 2.0 批量处理邮箱测试 ===")

    var allPassed = true

    // 运行所有测试
    allPassed = allPassed && testBatchingMailboxBasics()

    if (allPassed) {
        println("\n🎉 所有批量处理邮箱测试通过！")
        println("✓ 批量处理邮箱基础功能正常")
        println("\n这验证了CACtor 2.0的批量处理邮箱实现！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
