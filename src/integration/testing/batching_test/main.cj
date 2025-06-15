/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 批量处理邮箱测试
 * 验证批量处理功能
 */
package cactor.integration.testing.batching_test

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
 * 测试批量处理按大小触发
 */
func testBatchingBySize(): Bool {
    let batchSize: Int64 = 3
    let batchTimeout = Duration.second * 10  // 长超时，确保按大小触发
    let mailbox = BatchingMailbox(batchSize, batchTimeout)
    
    // 添加足够的消息触发批处理
    for (i in 1..4) {
        let message = PingMessage(Int64(i))
        let envelope = Envelope(message, Some("sender"))
        if (!mailbox.enqueue(envelope)) {
            println("✗ 入队应该成功")
            return false
        }
    }
    
    if (mailbox.size() != 3) {
        println("✗ 应该有3条消息")
        return false
    }
    
    // 现在应该可以处理一个批次
    let batch = mailbox.processBatch()
    if (batch.size != 3) {
        println("✗ 批次大小应该为3")
        return false
    }
    
    if (!mailbox.isEmpty()) {
        println("✗ 处理批次后邮箱应该为空")
        return false
    }
    
    // 验证批次内容
    for (i in 0..3) {
        let envelope = batch[i]
        if (envelope.getMessage().messageType() != "PingMessage") {
            println("✗ 批次中的消息类型错误")
            return false
        }
    }
    
    println("✓ 批量处理按大小触发测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 批量处理邮箱测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testBatchingMailboxBasics()
    allPassed = allPassed && testBatchingBySize()
    
    if (allPassed) {
        println("\n🎉 所有批量处理邮箱测试通过！")
        println("✓ 批量处理邮箱基础功能正常")
        println("✓ 按大小触发批处理正确")
        println("\n这验证了CActor的批量处理邮箱实现！")
        println("🚀 Phase 2: 批量处理机制功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
