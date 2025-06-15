/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Ask模式测试
 * 验证Ask模式功能
 */
package cactor.integration.testing

import std.sync.*
import std.time.*
// import cactor.pattern.ask.*
import cactor.core.message.{Message, PingMessage}

/**
 * 测试Ask消息
 */
func testAskMessage(): Bool {
    let requestId = "test-request-1"
    let originalMessage = PingMessage(42)
    let replyTo = DummyActorRef("reply-actor")

    let askMessage = AskMessage(requestId, originalMessage, replyTo)

    if (askMessage.messageType() != "AskMessage") {
        println("✗ Ask消息类型错误")
        return false
    }

    if (askMessage.getRequestId() != requestId) {
        println("✗ 请求ID错误")
        return false
    }

    if (askMessage.getOriginalMessage().messageType() != "PingMessage") {
        println("✗ 原始消息类型错误")
        return false
    }

    println("✓ Ask消息测试通过")
    return true
}

/**
 * 主测试函数
 */
func runAskPatternTests() {
    println("=== CActor Ask模式测试 ===")

    var allPassed = true

    // 运行所有测试
    allPassed = allPassed && testAskMessage()

    if (allPassed) {
        println("\n🎉 所有Ask模式测试通过！")
        println("✓ Ask消息功能正常")
        println("\n这验证了CActor的Ask模式实现！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
