/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ActorContext 单元测试
 */
package cactor.core.context

import std.collection.*
import std.time.*
import cactor.core.actor.*
import cactor.core.system.*
import cactor.core.message.*

@Test
func testDefaultActorContext_initialization() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    @Expect(context.self() === selfRef, true)
    @Expect(context.parent() === parentRef, true)
    @Expect(context.getActorSystem() === system, true)
    @Expect(context.children().size, 0)
}

@Test
func testDefaultActorContext_children() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    @Expect(context.children().size, 0)

    let childRef = MockActorRef("/test/child1")
    context.actorOf(MockProps(childRef), "child1")
    @Expect(context.children().size, 1)

    let child2Ref = MockActorRef("/test/child2")
    context.actorOf(MockProps(child2Ref), "child2")
    @Expect(context.children().size, 2)
}

@Test
func testDefaultActorContext_childLookup() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    let childRef = MockActorRef("/test/child")
    context.actorOf(MockProps(childRef), "my-child")

    let found = context.child("my-child")
    @Expect(found !== None, true)
    match (found) {
        case Some(ref) =>
            @Expect(ref === childRef, true)
        case None => ()
    }

    let notFound = context.child("non-existent")
    @Expect(notFound === None, true)
}

@Test
func testDefaultActorContext_watch() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    let watchedRef = MockActorRef("/test/watched")
    context.watch(watchedRef)

    let watchedActors = context.getWatchedActors()
    @Expect(watchedActors.size, 1)
    @Expect(watchedActors[0] === watchedRef, true)
}

@Test
func testDefaultActorContext_unwatch() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    let watchedRef = MockActorRef("/test/watched")
    context.watch(watchedRef)
    @Expect(context.getWatchedActors().size, 1)

    context.unwatch(watchedRef)
    @Expect(context.getWatchedActors().size, 0)
}

@Test
func testDefaultActorContext_receiveTimeout() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    @Expect(context.receiveTimeout() === Duration.second * 0, true)

    context.setReceiveTimeout(Duration.second * 30)
    @Expect(context.receiveTimeout() === Duration.second * 30, true)

    context.setReceiveTimeout(Duration.second * 60)
    @Expect(context.receiveTimeout() === Duration.second * 60, true)
}

@Test
func testDefaultActorContext_sender() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    // 默认sender为自身
    @Expect(context.sender() === selfRef, true)

    // 设置新的sender
    let otherRef = MockActorRef("/test/other")
    context.setCurrentSender(otherRef)
    @Expect(context.sender() === otherRef, true)
}

@Test
func testDefaultActorContext_autoNaming() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    // 创建两个自动命名的Actor
    let ref1 = context.actorOf(MockProps(MockActorRef("/auto1")), "")
    let ref2 = context.actorOf(MockProps(MockActorRef("/auto2")), "")

    @Expect(context.children().size >= 2, true)
}

@Test
func testDefaultActorContext_stop() {
    let selfRef = MockActorRef("/test/self")
    let parentRef = MockActorRef("/test/parent")
    let system = MockActorSystem("test-system")
    let context = DefaultActorContext(selfRef, parentRef, system)

    let childRef = MockActorRef("/test/child-to-stop")
    context.actorOf(MockProps(childRef), "child-to-stop")
    @Expect(context.children().size, 1)

    context.stop(childRef)
    @Expect(context.children().size, 0)
}

/*
 * Mock 实现
 */

class MockActorRef <: ActorRef {
    private let actorPath: String

    public init(path: String) {
        this.actorPath = path
    }

    public func path(): ActorPath {
        MockActorPath(actorPath)
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, senderOption: ActorRef): Unit {}

    public func equals(other: ActorRef): Bool {
        this.path().toString() == other.path().toString()
    }

    public func hashCode(): Int32 {
        0
    }
}

class MockActorPath <: ActorPath {
    private let pathString: String

    public init(path: String) {
        this.pathString = path
    }

    public func toString(): String {
        pathString
    }

    public func parent(): ActorPath {
        MockActorPath("/parent")
    }

    public func name(): String {
        "mock"
    }
}

class MockActorSystem <: ActorSystem {
    private let systemName: String

    public init(name: String) {
        this.systemName = name
    }

    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        MockActorRef("/${name}")
    }

    public func actorOf(props: Props<Actor>): ActorRef {
        MockActorRef("/anonymous")
    }

    public func actorSelection(path: String): ActorSelection {
        MockActorSelection()
    }

    public func terminate(): Unit {}

    public func whenTerminated(): SimpleFuture<Unit> {
        MockSimpleFuture()
    }

    public func eventStream(): EventBus {
        MockEventBus()
    }

    public func log(): ActorLog {
        MockActorLog()
    }

    public func startTime(): Int64 {
        0
    }

    public func isTerminated(): Bool {
        false
    }

    public func name(): String {
        systemName
    }
}

class MockProps<T> <: Props<T> {
    private let ref: ActorRef

    public init(ref: ActorRef) {
        this.ref = ref
    }

    public func create(): T {
        throw Exception("MockProps cannot create instances")
    }
}

class MockActorSelection <: ActorSelection {
    public init() {}

    public func resolveOne(timeout: Duration): Option<ActorRef> {
        None
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, senderOption: Option<String>): Unit {}
}

class MockSimpleFuture <: SimpleFuture<Unit> {
    public init() {}

    public func get(timeout: Duration): Option<Unit> {
        Some(Unit)
    }

    public func isDone(): Bool {
        true
    }
}

class MockEventBus <: EventBus {
    public init() {}

    public func publish(event: Any): Unit {}

    public func subscribe(subscriber: ActorRef, eventType: String): Bool {
        false
    }

    public func unsubscribe(subscriber: ActorRef, eventType: String): Bool {
        false
    }

    public func subscriberCount(eventType: String): Int64 {
        0
    }
}

class MockActorLog <: ActorLog {
    public init() {}

    public func debug(message: String): Unit {}

    public func info(message: String): Unit {}

    public func warning(message: String): Unit {}

    public func error(message: String): Unit {}

    public func error(cause: Exception, message: String): Unit {}
}
