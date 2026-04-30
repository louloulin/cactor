/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - RemoteTransport 单元测试
 */
package cactor.distribution.remote

import std.time.*
import cactor.core.message.Message

// === Test Messages ===

class TestMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestMessage"
    }
}

// === Helper function to extract message content ===

func getMessageString(msg: Message): String {
    match (msg) {
        case m: TestMessage => m.content
        case _ => ""
    }
}

// === Address Tests ===

@Test
func testAddress_creation() {
    let addr = Address("cactor", "testSystem", "localhost", 2552)

    @Expect(addr.protocol, "cactor")
    @Expect(addr.system, "testSystem")
    @Expect(addr.host, "localhost")
    @Expect(addr.port, 2552)
}

@Test
func testAddress_toString() {
    let addr = Address("cactor", "sys", "node1.local", 2552)
    let str = addr.toString()

    let hasProtocol = str.contains("cactor://")
    let hasHost = str.contains("node1.local")
    let hasPort = str.contains("2552")
    @Expect(hasProtocol, true)
    @Expect(hasHost, true)
    @Expect(hasPort, true)
}

@Test
func testAddress_hasHost() {
    let addr1 = Address("cactor", "sys", "localhost", 2552)
    let addr2 = Address("cactor", "sys", "", 2552)

    @Expect(addr1.hasHost(), true)
    @Expect(addr2.hasHost(), false)
}

@Test
func testAddress_withDifferentPorts() {
    let addr1 = Address("cactor", "sys", "node1", 2552)
    let addr2 = Address("cactor", "sys", "node1", 2553)

    let portsDifferent = addr1.port != addr2.port
    @Expect(portsDifferent, true)
}

// === ActorPath Tests ===

@Test
func testActorPath_creation() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user", "actor1"]
    let path = ActorPath(addr, elements)

    @Expect(path.address.protocol, "cactor")
    let pathSize = path.elements.size
    @Expect(pathSize, 2)
}

@Test
func testActorPath_toString() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user", "actor1"]
    let path = ActorPath(addr, elements)
    let str = path.toString()

    let hasCactor = str.contains("cactor://")
    let hasUser = str.contains("user")
    let hasActor = str.contains("actor1")
    @Expect(hasCactor, true)
    @Expect(hasUser, true)
    @Expect(hasActor, true)
}

@Test
func testActorPath_parse() {
    let path = ActorPath.parse("/user/actor1")
    // parse creates a default path, verify it exists
    let str = path.toString()
    let hasContent = str.size > 0
    @Expect(hasContent, true)
}

@Test
func testActorPath_parent() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user", "actor1"]
    let path = ActorPath(addr, elements)
    let parent = path.parent()

    let parentSize = parent.elements.size
    @Expect(parentSize, 1)
}

@Test
func testActorPath_parentWithSingleElement() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user"]
    let path = ActorPath(addr, elements)
    let parent = path.parent()

    let parentSize = parent.elements.size
    @Expect(parentSize, 0)
}

@Test
func testActorPath_child() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user"]
    let path = ActorPath(addr, elements)
    let child = path.child("actor1")

    let childSize = child.elements.size
    @Expect(childSize, 2)
}

@Test
func testActorPath_name() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user", "actor1"]
    let path = ActorPath(addr, elements)

    @Expect(path.name(), "actor1")
}

@Test
func testActorPath_nameEmpty() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = Array<String>()
    let path = ActorPath(addr, elements)

    let name = path.name()
    let isEmpty = name.size == 0
    @Expect(isEmpty, true)
}

// === RemoteEnvelope Tests ===

@Test
func testRemoteEnvelope_creation() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let elements = ["user", "actor1"]
    let recipient = ActorPath(addr, elements)
    let msg = TestMessage("hello")
    let sender = ActorPath(addr, ["user", "sender"])
    let envelope = RemoteEnvelope(recipient, msg, Some(sender), 1, Some("TestMessage"))

    @Expect(envelope.serializerId, 1)
    let content = getMessageString(envelope.message)
    @Expect(content, "hello")

    let hasManifest = match (envelope.manifest) {
        case Some(m) => m == "TestMessage"
        case _ => false
    }
    @Expect(hasManifest, true)
}

@Test
func testRemoteEnvelope_create() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let recipient = ActorPath(addr, ["user", "actor1"])
    let msg = TestMessage("test")
    let envelope = RemoteEnvelope.create(recipient, msg, None)

    @Expect(envelope.serializerId, 0)

    let hasManifest = match (envelope.manifest) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasManifest, false)
}

@Test
func testRemoteEnvelope_toString() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let recipient = ActorPath(addr, ["user", "actor1"])
    let msg = TestMessage("test")
    let sender = ActorPath(addr, ["user", "sender"])
    let envelope = RemoteEnvelope(recipient, msg, Some(sender), 0, None)
    let str = envelope.toString()

    let hasEnvelope = str.contains("RemoteEnvelope")
    let hasActor = str.contains("actor1")
    @Expect(hasEnvelope, true)
    @Expect(hasActor, true)
}

// === SimpleRemoteMessageStream Tests ===

@Test
func testSimpleRemoteMessageStream_creation() {
    let stream = SimpleRemoteMessageStream()
    // Basic creation - just verify no exception thrown
    @Expect(true, true)
}

@Test
func testSimpleRemoteMessageStream_enqueue() {
    let stream = SimpleRemoteMessageStream()
    let addr = Address("cactor", "sys", "localhost", 2552)
    let recipient = ActorPath(addr, ["user", "actor1"])
    let msg = TestMessage("test")
    let envelope = RemoteEnvelope(recipient, msg, None, 0, None)

    // Enqueue should not throw
    stream.enqueue(envelope)
    @Expect(true, true)
}

@Test
func testSimpleRemoteMessageStream_next() {
    let stream = SimpleRemoteMessageStream()
    let addr = Address("cactor", "sys", "localhost", 2552)
    let recipient = ActorPath(addr, ["user", "actor1"])
    let msg = TestMessage("test1")
    let envelope = RemoteEnvelope(recipient, msg, None, 0, None)

    stream.enqueue(envelope)
    let result = stream.next()

    // Check we got something
    let gotValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(gotValue, true)

    // Check content
    match (result) {
        case Some(e) => @Expect(getMessageString(e.message), "test1")
        case None => @Expect(false, true)
    }
}

@Test
func testSimpleRemoteMessageStream_nextEmpty() {
    let stream = SimpleRemoteMessageStream()
    let result = stream.next()

    let isEmpty = match (result) {
        case Some(_) => false
        case None => true
    }
    @Expect(isEmpty, true)
}

@Test
func testSimpleRemoteMessageStream_multipleEnqueue() {
    let stream = SimpleRemoteMessageStream()
    let addr = Address("cactor", "sys", "localhost", 2552)

    // Enqueue 3 items and verify we can retrieve them all
    for (i in 0..3) {
        let recipient = ActorPath(addr, ["user", "actor${i}"])
        let msg = TestMessage("test${i}")
        let envelope = RemoteEnvelope(recipient, msg, None, 0, None)
        stream.enqueue(envelope)
    }

    // Count items retrieved
    var count = 0
    while (true) {
        let result = stream.next()
        let hasMore = match (result) {
            case Some(_) => true
            case None => false
        }
        if (!hasMore) {
            break
        }
        count += 1
    }

    @Expect(count, 3)
}

@Test
func testSimpleRemoteMessageStream_close() {
    let stream = SimpleRemoteMessageStream()
    // close() should not throw
    stream.close()
    @Expect(true, true)
}

// === RemoteMessageStream Interface Tests ===

@Test
func testRemoteMessageStream_nextWithContent() {
    let stream = SimpleRemoteMessageStream()
    let addr = Address("cactor", "sys", "localhost", 2552)
    let recipient = ActorPath(addr, ["user", "actor1"])
    let msg = TestMessage("test")
    let envelope = RemoteEnvelope(recipient, msg, None, 0, None)

    stream.enqueue(envelope)
    let result = stream.next()

    // Check we got something
    let gotValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(gotValue, true)

    // Check content
    match (result) {
        case Some(e) => @Expect(getMessageString(e.message), "test")
        case None => @Expect(false, true)
    }
}

// === Integration Tests ===

@Test
func testAddressPathEnvelope_integration() {
    // Create address
    let addr = Address("cactor", "testSystem", "192.168.1.100", 8080)
    @Expect(addr.protocol, "cactor")
    @Expect(addr.port, 8080)

    // Create actor path
    let path = ActorPath(addr, ["user", "service", "worker"])
    let pathStr = path.toString()
    let hasIp = pathStr.contains("192.168.1.100")
    @Expect(hasIp, true)

    // Create and send envelope
    let msg = TestMessage("integration test")
    let envelope = RemoteEnvelope.create(path, msg, None)
    @Expect(envelope.serializerId, 0)

    // Verify envelope in stream
    let stream = SimpleRemoteMessageStream()
    stream.enqueue(envelope)

    // Retrieve and verify
    let result = stream.next()
    let gotValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(gotValue, true)

    match (result) {
        case Some(e) => @Expect(getMessageString(e.message), "integration test")
        case None => @Expect(false, true)
    }
}

@Test
func testRemoteEnvelope_withSender() {
    let addr = Address("cactor", "sys", "localhost", 2552)
    let recipient = ActorPath(addr, ["user", "receiver"])
    let sender = ActorPath(addr, ["user", "sender"])
    let msg = TestMessage("message with sender")
    let envelope = RemoteEnvelope(recipient, msg, Some(sender), 1, Some("TestMessage"))

    let str = envelope.toString()
    let hasSender = str.contains("sender")
    @Expect(hasSender, true)
}

@Test
func testRemoteStream_multipleRetrieve() {
    let stream = SimpleRemoteMessageStream()
    let addr = Address("cactor", "sys", "localhost", 2552)

    // Enqueue two messages
    let msg1 = TestMessage("first")
    let msg2 = TestMessage("second")
    stream.enqueue(RemoteEnvelope.create(ActorPath(addr, ["a"]), msg1, None))
    stream.enqueue(RemoteEnvelope.create(ActorPath(addr, ["b"]), msg2, None))

    // Retrieve first
    let r1 = stream.next()
    let firstMatch = match (r1) {
        case Some(e) => getMessageString(e.message) == "first"
        case None => false
    }

    // Retrieve second
    let r2 = stream.next()
    let secondMatch = match (r2) {
        case Some(e) => getMessageString(e.message) == "second"
        case None => false
    }

    // Verify empty
    let r3 = stream.next()
    let isEmpty = match (r3) {
        case Some(_) => false
        case None => true
    }

    @Expect(firstMatch, true)
    @Expect(secondMatch, true)
    @Expect(isEmpty, true)
}