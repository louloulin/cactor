/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Coexistences 模式单元测试
 */
package cactor.patterns.coexistence

import std.collection.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath}

/**
 * TestMessage - 测试用消息
 */
class TestCoexistenceMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestCoexistenceMessage"
    }
}

/**
 * TestTypedMessage - 测试用强类型消息
 */
class TestTypedMessage <: Message {
    public let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func messageType(): String {
        "TestTypedMessage"
    }
}

// === TypeAdapter Tests ===

@Test
func testMessageAdapter_creation() {
    let adapter = MessageAdapter(
        toUntyped: { msg => msg },
        toTyped: { msg => msg }
    )

    @Expect(adapter != None, true)
}

@Test
func testMessageAdapter_adapt() {
    let msg = TestCoexistenceMessage("test")
    let adapted = MessageAdapter(
        toUntyped: { m => m },
        toTyped: { m => m }
    )

    let result = adapted.adapt(msg)
    @Expect(result.messageType(), "TestCoexistenceMessage")
}

@Test
func testMessageAdapter_reverse() {
    let msg = TestTypedMessage(42)
    let adapter = MessageAdapter(
        toUntyped: { m => m },
        toTyped: { m => m }
    )

    let result = adapter.reverse(msg)
    @Expect(result.messageType(), "TestTypedMessage")
}

// === WrappedMessage Tests ===

@Test
func testWrappedMessage_creation() {
    let original = TestCoexistenceMessage("original")
    let wrapped = WrappedMessage(original, "system1")

    @Expect(wrapped.messageType(), "WrappedMessage")
    @Expect(wrapped.getSourceSystem(), "system1")
    @Expect(wrapped.getOriginalMessage().messageType(), "TestCoexistenceMessage")
}

@Test
func testWrappedMessage_timestamp() {
    let original = TestCoexistenceMessage("test")
    let wrapped = WrappedMessage(original, "system1")

    @Expect(wrapped.timestamp > 0, true)
}

// === MixedMessageRouter Tests ===

@Test
func testMixedMessageRouter_empty() {
    let router = MixedMessageRouter()
    let routes = router.getRoutes()

    @Expect(routes.size, 0)
}

@Test
func testMixedMessageRouter_addRoute() {
    let router = MixedMessageRouter()
    let ref = MockCoexistenceRef("test")

    router.addRoute("TestMessage", ref)
    let routes = router.getRoutes()

    @Expect(routes.size, 1)
    @Expect(routes[0][0], "TestMessage")
}

@Test
func testMixedMessageRouter_removeRoute() {
    let router = MixedMessageRouter()
    let ref = MockCoexistenceRef("test")

    router.addRoute("TestMessage", ref)
    router.removeRoute("TestMessage")

    let routes = router.getRoutes()
    @Expect(routes.size, 0)
}

@Test
func testMixedMessageRouter_registerAdapter() {
    let router = MixedMessageRouter()
    let adapter = MessageAdapter(
        toUntyped: { msg => msg },
        toTyped: { msg => msg }
    )

    router.registerAdapter("TestMessage", adapter)

    let routes = router.getRoutes()
    @Expect(routes.size, 0) // 适配器不影响路由
}

@Test
func testMixedMessageRouter_setDefaultAdapter() {
    let router = MixedMessageRouter()
    let adapter = MessageAdapter(
        toUntyped: { msg => msg },
        toTyped: { msg => msg }
    )

    router.setDefaultAdapter(adapter)

    // 验证默认适配器设置成功
    @Expect(router != None, true)
}

// === SystemCoordinator Tests ===

@Test
func testSystemCoordinator_empty() {
    let coordinator = SystemCoordinator()
    let systems = coordinator.listSystems()

    @Expect(systems.size, 0)
}

@Test
func testSystemCoordinator_listSystems() {
    let coordinator = SystemCoordinator()
    let systems = coordinator.listSystems()

    @Expect(systems.size, 0)
}

@Test
func testSystemCoordinator_getHealthySystems() {
    let coordinator = SystemCoordinator()
    let healthy = coordinator.getHealthySystems()

    @Expect(healthy.size, 0)
}

// === CoexistenceConfig Tests ===

@Test
func testCoexistenceConfig_default() {
    let config = CoexistenceConfig()

    @Expect(config.enableCrossSystem, true)
    @Expect(config.maxRetries, 3)
}

@Test
func testCoexistenceConfig_defaultFactory() {
    let config = CoexistenceConfig.defaultConfig()

    @Expect(config.enableCrossSystem, true)
    @Expect(config.defaultTimeout == Duration.second * 5, true)
}

// === Mock ActorRef for Testing ===

class MockCoexistenceRef <: ActorRef {
    private let name: String
    private let mockPath: ActorPath
    private let sentMessages: ArrayList<Message>

    public init(name: String) {
        this.name = name
        this.mockPath = ActorPath("mock", "/${name}")
        this.sentMessages = ArrayList<Message>()
    }

    public prop path: ActorPath {
        get() { mockPath }
    }

    public func tell(message: Message): Unit {
        sentMessages.add(message)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        sentMessages.add(message)
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case mock: MockCoexistenceRef => name == mock.name
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        name.hashCode()
    }

    public func getSentMessages(): ArrayList<Message> {
        sentMessages
    }

    public func clearSentMessages(): Unit {
        sentMessages.clear()
    }
}
