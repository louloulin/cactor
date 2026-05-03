/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Stash Pattern 单元测试
 */
package cactor.patterns.stash

import std.collection.*
import cactor.core.message.Message

// === Test Messages ===

class TestStashMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestStashMessage"
    }
}

// === StashedMessage Tests ===

@Test
func testStashedMessage_creation() {
    let msg = TestStashMessage("test")
    let stashed = StashedMessage(msg)

    match (stashed.message) {
        case m: TestStashMessage => @Expect(m.content, "test")
        case _ => @Expect(false, true)
    }
    @Expect(stashed.timestamp > 0, true)
}

// === StashSupport Tests ===

@Test
func testStashSupport_creation() {
    let stash = StashSupport()

    @Expect(stash.stashSize(), 0)
    @Expect(stash.isStashEmpty(), true)
}

@Test
func testStashSupport_stashMessage() {
    let stash = StashSupport()
    let msg = TestStashMessage("hello")

    stash.stashMessage(msg)

    @Expect(stash.stashSize(), 1)
    @Expect(stash.isStashEmpty(), false)
}

@Test
func testStashSupport_unstash() {
    let stash = StashSupport()
    let msg = TestStashMessage("hello")

    stash.stashMessage(msg)
    @Expect(stash.stashSize(), 1)

    let unstash = stash.unstash()
    match (unstash) {
        case Some(m) =>
            match (m) {
                case tm: TestStashMessage => @Expect(tm.content, "hello")
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    @Expect(stash.stashSize(), 0)
}

@Test
func testStashSupport_unstashEmpty() {
    let stash = StashSupport()

    let unstash = stash.unstash()
    match (unstash) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}

@Test
func testStashSupport_multipleMessages() {
    let stash = StashSupport()

    stash.stashMessage(TestStashMessage("msg1"))
    stash.stashMessage(TestStashMessage("msg2"))
    stash.stashMessage(TestStashMessage("msg3"))

    @Expect(stash.stashSize(), 3)

    // FIFO 顺序
    let first = stash.unstash()
    match (first) {
        case Some(m) =>
            match (m) {
                case tm: TestStashMessage => @Expect(tm.content, "msg1")
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    @Expect(stash.stashSize(), 2)
}

@Test
func testStashSupport_clearStash() {
    let stash = StashSupport()

    stash.stashMessage(TestStashMessage("msg1"))
    stash.stashMessage(TestStashMessage("msg2"))

    @Expect(stash.stashSize(), 2)

    stash.clearStash()

    @Expect(stash.stashSize(), 0)
    @Expect(stash.isStashEmpty(), true)
}

@Test
func testStashSupport_getStashedMessages() {
    let stash = StashSupport()

    stash.stashMessage(TestStashMessage("msg1"))
    stash.stashMessage(TestStashMessage("msg2"))

    let messages = stash.getStashedMessages()
    @Expect(messages.size, 2)
}

// === BoundedStash Tests ===

@Test
func testBoundedStash_defaultCreation() {
    let stash = BoundedStash()

    @Expect(stash.stashSize(), 0)
    @Expect(stash.isStashEmpty(), true)
}

@Test
func testBoundedStash_withSettings() {
    let settings = StashSettings.withMaxSize(3)
    let stash = BoundedStash.create(settings)

    stash.stashMessage(TestStashMessage("1"))
    stash.stashMessage(TestStashMessage("2"))
    stash.stashMessage(TestStashMessage("3"))

    @Expect(stash.stashSize(), 3)
}

@Test
func testBoundedStash_sizeLimit() {
    let settings = StashSettings.withMaxSize(2)
    let stash = BoundedStash.create(settings)

    stash.stashMessage(TestStashMessage("1"))
    stash.stashMessage(TestStashMessage("2"))

    // 第三次应该失败
    var threw = false
    try {
        stash.stashMessage(TestStashMessage("3"))
    } catch (e: Exception) {
        threw = true
    }
    @Expect(threw, true)
}

// === Integration Tests ===

@Test
func testStash_patternUsage() {
    // 模拟 Actor 使用 stash
    let stash = StashSupport()
    let processing = Ref(true)

    // 模拟处理状态 - 当忙碌时 stash 消息
    if (processing.load()) {
        stash.stashMessage(TestStashMessage("urgent"))
    }

    @Expect(stash.stashSize(), 1)

    // 处理完成后 unstash
    processing.store(false)
    let msg = stash.unstash()
    match (msg) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testStash_multipleUnstash() {
    let stash = StashSupport()

    stash.stashMessage(TestStashMessage("a"))
    stash.stashMessage(TestStashMessage("b"))
    stash.stashMessage(TestStashMessage("c"))

    let msg1 = stash.unstash()
    let msg2 = stash.unstash()
    let msg3 = stash.unstash()
    let msg4 = stash.unstash()

    match (msg1) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
    match (msg2) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
    match (msg3) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
    match (msg4) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}
