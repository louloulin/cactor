/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - MessageAdapter 消息适配器单元测试
 */
package cactor.core.message

import std.collection.*

// === Test Messages ===

class UserCreatedEvent <: Message {
    public let userId: String
    public let name: String

    public init(userId: String, name: String) {
        this.userId = userId
        this.name = name
    }

    public func messageType(): String {
        "UserCreatedEvent"
    }
}

class UserNotificationMessage <: Message {
    public let content: String
    public let userId: String

    public init(content: String, userId: String) {
        this.content = content
        this.userId = userId
    }

    public func messageType(): String {
        "UserNotificationMessage"
    }
}

// === MessageAdapterRegistration Tests ===

@Test
func testMessageAdapterRegistration_creation() {
    let adapter: MessageAdapter<String, Int64> = { s => Int64(s.size) }
    let reg = MessageAdapterRegistration<String, Int64>(adapter, "String", "Int64")

    @Expect(reg.manifest, "String")
    @Expect(reg.targetManifest, "Int64")
}

@Test
func testMessageAdapterRegistration_invoke() {
    let adapter: MessageAdapter<String, Int64> = { s => Int64(s.size) }
    let reg = MessageAdapterRegistration<String, Int64>(adapter, "String", "Int64")

    let result = reg.adapter("hello")
    @Expect(result, 5)
}

// === SimpleMessageAdapterRegistry Tests ===

@Test
func testSimpleMessageAdapterRegistry_creation() {
    let registry = SimpleMessageAdapterRegistry()
    @Expect(registry.adapterCount(), 0)
}

@Test
func testSimpleMessageAdapterRegistry_register() {
    let registry = SimpleMessageAdapterRegistry()
    let adapter: MessageAdapter<String, Int64> = { s => Int64(s.size) }

    registry.register(adapter, "String", "Int64")
    @Expect(registry.adapterCount(), 1)
}

@Test
func testSimpleMessageAdapterRegistry_registerMultiple() {
    let registry = SimpleMessageAdapterRegistry()
    let adapter1: MessageAdapter<String, Int64> = { s => Int64(s.size) }
    let adapter2: MessageAdapter<String, String> = { s => s + "_adapted" }

    registry.register(adapter1, "String", "Int64")
    registry.register(adapter2, "String", "String")
    @Expect(registry.adapterCount(), 2)
}

@Test
func testSimpleMessageAdapterRegistry_clear() {
    let registry = SimpleMessageAdapterRegistry()
    let adapter: MessageAdapter<String, Int64> = { s => Int64(s.size) }

    registry.register(adapter, "String", "Int64")
    @Expect(registry.adapterCount(), 1)
    registry.clear()
    @Expect(registry.adapterCount(), 0)
}

// === SimpleMessageAdapterRegistry.adapt Tests ===

@Test
func testSimpleMessageAdapterRegistry_adapt_noRegistration() {
    let registry = SimpleMessageAdapterRegistry()

    // 没有注册适配器时，应该返回原消息
    let msg = StringMessage("test")
    let result = registry.adapt(msg)
    @Expect(result.messageType(), "StringMessage")
}

// === MessageTypeTag Tests ===

@Test
func testMessageTypeTag_creation() {
    let tag = MessageTypeTag<String>("StringType")
    @Expect(tag.typeName, "StringType")
}

@Test
func testMessageTypeTag_of() {
    let tag = MessageTypeTag<String>("MyType")
    @Expect(tag.typeName, "MyType")
}

// === TypedMessage Tests ===

@Test
func testTypedMessage_creation() {
    let event = UserCreatedEvent("123", "Alice")
    let typedMsg = TypedMessage<UserCreatedEvent>(event, "UserCreatedEvent")

    @Expect(typedMsg.messageType(), "UserCreatedEvent")
    @Expect(typedMsg.getPayload().userId, "123")
    @Expect(typedMsg.getPayload().name, "Alice")
}

// === MessageAdapters Tests ===

@Test
func testMessageAdapters_adapt() {
    let adapter = MessageAdapters.adapt<String, Int64>({ s => Int64(s.size) })
    let result = adapter("hello world")
    @Expect(result, 11)
}

// === Integration Test: Adapter Pattern ===

@Test
func testAdapterPattern_registrationAndRetrieval() {
    let registry = SimpleMessageAdapterRegistry()

    // 注册适配器
    let adapter: MessageAdapter<String, Int64> = { s => Int64(s.size) }
    registry.register(adapter, "String", "Int64")

    // 验证注册
    @Expect(registry.adapterCount(), 1)

    // 获取注册信息
    let reg = registry.getAdapter("String")
    match (reg) {
        case Some(r) => @Expect(r.targetManifest, "Int64")
        case None => @Expect(false, true)
    }
}

// === Edge Cases ===

@Test
func testSimpleMessageAdapterRegistry_duplicateRegistration() {
    let registry = SimpleMessageAdapterRegistry()
    let adapter1: MessageAdapter<String, Int64> = { s => Int64(s.size) }
    let adapter2: MessageAdapter<String, Int64> = { s => Int64(s.size * 2) }

    registry.register(adapter1, "String", "Int64")
    registry.register(adapter2, "String", "Int64")  // 添加另一个

    // 两个适配器都应该被注册
    @Expect(registry.adapterCount(), 2)
}

@Test
func testTypedMessage_withDifferentTypes() {
    // 测试不同类型的消息包装
    let stringMsg = TypedMessage<String>("hello", "String")
    @Expect(stringMsg.messageType(), "String")
    @Expect(stringMsg.getPayload(), "hello")

    let intMsg = TypedMessage<Int64>(42, "Int64")
    @Expect(intMsg.messageType(), "Int64")
    @Expect(intMsg.getPayload(), 42)
}

@Test
func testTypedMessage_withCustomMessage() {
    // 测试使用自定义消息
    let event = UserCreatedEvent("user-001", "Bob")
    let typedMsg = TypedMessage<UserCreatedEvent>(event, "UserCreatedEvent")

    @Expect(typedMsg.messageType(), "UserCreatedEvent")
    let payload = typedMsg.getPayload()
    @Expect(payload.userId, "user-001")
    @Expect(payload.name, "Bob")
}
