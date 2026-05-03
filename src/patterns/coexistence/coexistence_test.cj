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

/**
 * TestMockActorRef - Mock ActorRef for testing
 */
class TestMockActorRef <: ActorRef {
    private let mockPath: ActorPath
    private let sentMessages: ArrayList<Message>

    public init(name: String) {
        this.mockPath = ActorPath("test", "/${name}")
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
            case mock: TestMockActorRef => true
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        0
    }
}

// === TypeAdapter Tests ===

@Test
func testMessageAdapter_creation() {
    let adapter = MessageAdapter(
        { msg => msg },
        { msg => msg }
    )
    // Verify the adapter was created by calling adapt
    let msg = TestCoexistenceMessage("test")
    let resultType = adapter.adapt(msg).messageType()
    @Expect(resultType, "TestCoexistenceMessage")
}

@Test
func testMessageAdapter_adapt() {
    let msg = TestCoexistenceMessage("test")
    let adapted = MessageAdapter(
        { m => m },
        { m => m }
    )

    let resultType = adapted.adapt(msg).messageType()
    @Expect(resultType, "TestCoexistenceMessage")
}

@Test
func testMessageAdapter_reverse() {
    let msg = TestTypedMessage(42)
    let adapter = MessageAdapter(
        { m => m },
        { m => m }
    )

    let resultType = adapter.reverse(msg).messageType()
    @Expect(resultType, "TestTypedMessage")
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

// === MixedMessageRouter Tests ===

@Test
func testMixedMessageRouter_creation() {
    let router = MixedMessageRouter()
    // Verify router was created by calling addRoute
    let mockRef = TestMockActorRef("test")
    router.addRoute("TestMessage", mockRef)
    let routes = router.getRoutes()
    @Expect(routes.size, 1)
}

@Test
func testMixedMessageRouter_addRoute() {
    let router = MixedMessageRouter()
    let mockRef = TestMockActorRef("target1")
    router.addRoute("TestMessage", mockRef)
    let routes = router.getRoutes()
    @Expect(routes.size, 1)
}

@Test
func testMixedMessageRouter_removeRoute() {
    let router = MixedMessageRouter()
    let mockRef = TestMockActorRef("target1")
    router.addRoute("TestMessage", mockRef)
    router.removeRoute("TestMessage")
    let routes = router.getRoutes()
    @Expect(routes.size, 0)
}

@Test
func testMixedMessageRouter_registerAdapter() {
    let router = MixedMessageRouter()
    let adapter = MessageAdapter(
        { msg => msg },
        { msg => msg }
    )
    router.registerAdapter("TestMessage", adapter)
    let routes = router.getRoutes()
    @Expect(routes.size, 0)
}

@Test
func testMixedMessageRouter_setDefaultAdapter() {
    let router = MixedMessageRouter()
    let adapter = MessageAdapter(
        { msg => msg },
        { msg => msg }
    )
    router.setDefaultAdapter(adapter)
    let routes = router.getRoutes()
    @Expect(routes.size, 0)
}

// === SystemCoordinator Tests ===

@Test
func testSystemCoordinator_creation() {
    let coordinator = SystemCoordinator()
    // Verify coordinator was created by calling listSystems
    let systems = coordinator.listSystems()
    @Expect(systems.size, 0)
}

@Test
func testSystemCoordinator_listSystems() {
    let coordinator = SystemCoordinator()
    let systems = coordinator.listSystems()
    @Expect(systems.size, 0)
}

// === CoexistenceConfig Tests ===

@Test
func testCoexistenceConfig_default() {
    let config = CoexistenceConfig.defaultConfig()
    @Expect(config.enableCrossSystem, true)
    @Expect(config.maxRetries, 3)
}
