/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - TypedActor 单元测试
 */
package cactor.patterns.typed

import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef, ActorPath, Actor, ActorContext, Props, SimpleActorFactory, ActorSystem}
import cactor.core.message.{Message, Envelope, MessageResult}

/*
 * Test message types
 */
public class EchoCommand <: Message {
    private let text: String

    public init(text: String) {
        this.text = text
    }

    public func messageType(): String { "EchoCommand" }
    public func getText(): String { text }
}

public class CountCommand <: Message {
    public init() {}

    public func messageType(): String { "CountCommand" }
}

/*
 * Test behavior handler
 */
class TestBehaviorHandler <: ActorBehaviorHandler {
    private let messages: ArrayList<Message>
    private var state: String

    public init() {
        this.messages = ArrayList<Message>()
        this.state = "initial"
    }

    public func handleMessage(message: Message): Unit {
        messages.add(message)
    }

    public func currentState(): String { state }

    public func getMessages(): Array<Message> { messages.toArray() }
}

/*
 * Mock ActorContext
 */
class TestActorContext <: ActorContext {
    private let selfRef: ActorRef

    public init() {
        this.selfRef = TestActorRef("/test/self")
    }

    public func sender(): ActorRef { TestActorRef("/test/sender") }
    public func self(): ActorRef { selfRef }
    public func parent(): ActorRef { TestActorRef("/test/parent") }
    public func children(): Array<ActorRef> {
        let list = ArrayList<ActorRef>()
        list.toArray()
    }
    public func child(name: String): Option<ActorRef> { None }
    public func actorOf(props: Props<Actor>, name: String): ActorRef { TestActorRef("/test/${name}") }
    public func actorOf(props: Props<Actor>): ActorRef { TestActorRef("/test/auto") }
    public func watch(actorRef: ActorRef): Unit {}
    public func unwatch(actorRef: ActorRef): Unit {}
    public func getActorSystem(): ActorSystem { throw Exception("not implemented") }
    public func setReceiveTimeout(timeout: Duration): Unit {}
    public func receiveTimeout(): Duration { Duration.second * 0 }
    public func stop(): Unit {}
    public func stop(actorRef: ActorRef): Unit {}
}

class TestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(pathStr: String) {
        this.pathValue = ActorPath("test", pathStr)
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, sender: Option<String>): Unit {}

    public func equals(other: ActorRef): Bool {
        pathValue.toString() == other.path.toString()
    }

    public func hashCode(): Int32 { 0 }
}

// === Tests ===

@Test
func testTypedEnvelope_creation() {
    let cmd = EchoCommand("hello")
    let envelope = TypedEnvelope(cmd, "EchoProtocol")
    @Expect(envelope.getMessage().messageType(), "EchoCommand")
    @Expect(envelope.getProtocolType(), "EchoProtocol")
}

@Test
func testTypedEnvelope_messageType() {
    let cmd = CountCommand()
    let envelope = TypedEnvelope(cmd, "CountProtocol")
    let result = envelope.messageType()
    @Expect(result.size > 0, true)
}

@Test
func testTypedActorRefImpl_creation() {
    let actorRef = TestActorRef("/test/actor")
    let typedRef = TypedActorRefImpl<Message>(actorRef, "TestProtocol")
    @Expect(typedRef.path().toString().size > 0, true)
}

@Test
func testTypedActorRefImpl_underlyingRef() {
    let actorRef = TestActorRef("/test/actor")
    let typedRef = TypedActorRefImpl<Message>(actorRef, "TestProtocol")
    let underlying = typedRef.underlyingRef()
    @Expect(underlying.equals(actorRef), true)
}

@Test
func testActorBehaviorHandler_handle() {
    let handler = TestBehaviorHandler()
    let cmd = EchoCommand("test message")
    handler.handleMessage(cmd)
    let msgs = handler.getMessages()
    @Expect(msgs.size, 1)
}

@Test
func testActorBehaviorHandler_currentState() {
    let handler = TestBehaviorHandler()
    let state = handler.currentState()
    @Expect(state, "initial")
}

@Test
func testActorProtocol_protocolName() {
    let handler = TestBehaviorHandler()
    let actor = TypedActorImpl<Message>("test", handler, "TestProtocol")
    @Expect(actor.protocolName(), "TestProtocol")
}

@Test
func testTypedActorImpl_receive_withTypedEnvelope() {
    let handler = TestBehaviorHandler()
    let actor = TypedActorImpl<Message>("test", handler, "TestProtocol")
    let ctx = TestActorContext()

    let cmd = EchoCommand("hello world")
    let envelope = TypedEnvelope(cmd, "TestProtocol")
    let result = actor.receive(envelope, ctx)
    messageResultEquals(result, MessageResult.Handled)
    @Expect(actor.getMessageCount(), 1)
}

@Test
func testTypedActorImpl_receive_withNonTypedEnvelope() {
    let handler = TestBehaviorHandler()
    let actor = TypedActorImpl<Message>("test", handler, "TestProtocol")
    let ctx = TestActorContext()

    let result = actor.receive(EchoCommand("regular"), ctx)
    messageResultEquals(result, MessageResult.Unhandled)
    @Expect(actor.getMessageCount(), 0)
}

@Test
func testTypedActorImpl_nameAndDescription() {
    let handler = TestBehaviorHandler()
    let actor = TypedActorImpl<Message>("myActor", handler, "EchoProtocol")
    @Expect(actor.name, "myActor")
    @Expect(actor.description.size > 0, true)
}

@Test
func testTypedActorImpl_messageCount() {
    let handler = TestBehaviorHandler()
    let actor = TypedActorImpl<Message>("test", handler, "TestProtocol")
    let ctx = TestActorContext()

    @Expect(actor.getMessageCount(), 0)

    // First message - TypedEnvelope wrapping EchoCommand
    let env1 = TypedEnvelope(EchoCommand("msg1"), "TestProtocol")
    actor.receive(env1, ctx)
    @Expect(actor.getMessageCount(), 1)

    // Second message
    let env2 = TypedEnvelope(EchoCommand("msg2"), "TestProtocol")
    actor.receive(env2, ctx)
    @Expect(actor.getMessageCount(), 2)
}

/*
 * Helper function for MessageResult comparison
 */
func messageResultEquals(a: MessageResult, b: MessageResult): Bool {
    match (a) {
        case MessageResult.Handled =>
            match (b) {
                case MessageResult.Handled => true
                case _ => false
            }
        case MessageResult.Unhandled =>
            match (b) {
                case MessageResult.Unhandled => true
                case _ => false
            }
        case MessageResult.Stop =>
            match (b) {
                case MessageResult.Stop => true
                case _ => false
            }
        case MessageResult.Restart =>
            match (b) {
                case MessageResult.Restart => true
                case _ => false
            }
        case MessageResult.Escalate =>
            match (b) {
                case MessageResult.Escalate => true
                case _ => false
            }
    }
}
