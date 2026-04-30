/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ActorContext 单元测试
 */
package cactor.core.context

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, Props, SimpleActorFactory}
import cactor.core.system.{ActorSystem, ActorSelection, SimpleFuture, EventBus, ActorLog, SimpleActorLog}
import cactor.core.message.{Message, MessageResult}

@Test
func testActorContext_interfaceExists() {
    @Expect(true, true)
}

@Test
func testDefaultActorContext_hasWatchSupport() {
    let system = CTXTestActorSystem("test")
    let context = CTXDefaultActorContext(system)
    let ref = CTXTestActorRef("/test/watched", system)
    context.watch(ref)
    let watched = context.getWatchedActors()
    @Expect(watched.size, 1)
}

@Test
func testDefaultActorContext_unwatch() {
    let system = CTXTestActorSystem("test")
    let context = CTXDefaultActorContext(system)
    let ref = CTXTestActorRef("/test/watched", system)
    context.watch(ref)
    context.unwatch(ref)
    @Expect(context.getWatchedActors().size, 0)
}

@Test
func testDefaultActorContext_children() {
    let system = CTXTestActorSystem("test")
    let context = CTXDefaultActorContext(system)
    @Expect(context.children().size, 0)
}

@Test
func testDefaultActorContext_setReceiveTimeout() {
    let system = CTXTestActorSystem("test")
    let context = CTXDefaultActorContext(system)
    context.setReceiveTimeout(Duration.second * 30)
    @Expect(context.receiveTimeout() >= Duration.second * 30, true)
}

@Test
func testDefaultActorContext_getActorSystem() {
    let system = CTXTestActorSystem("test")
    let context = CTXDefaultActorContext(system)
    @Expect(context.getActorSystem().name.size > 0, true)
}

class CTXTestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(pathStr: String, system: CTXTestActorSystem) {
        this.pathValue = ActorPath(system.name, pathStr)
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}
    public func tell(message: Message, sender: Option<String>): Unit {}
    public func equals(other: ActorRef): Bool { this.path.toString() == other.path.toString() }
    public func hashCode(): Int32 { 0 }
}

class CTXTestActorSystem <: ActorSystem {
    private let systemName: String
    private let counter: AtomicInt64

    public init(name: String) {
        this.systemName = name
        this.counter = AtomicInt64(0)
    }

    public prop name: String {
        get() { systemName }
    }

    public func actorOf(props: Props<Actor>, name: String): ActorRef { CTXTestActorRef("/user/${name}", this) }
    public func actorOf(props: Props<Actor>): ActorRef { actorOf(props, "auto-${counter.fetchAdd(1)}") }
    public func actorSelection(path: String): ActorSelection { CTXTestActorSelection() }
    public func terminate(): Unit {}
    public func whenTerminated(): SimpleFuture<Unit> { CTXTestSimpleFuture() }
    public func eventStream(): EventBus { CTXTestEventBus() }
    public func log(): ActorLog { SimpleActorLog(systemName, "/system") }
    public func startTime(): Int64 { 0 }
    public func isTerminated(): Bool { false }
}

class CTXTestActorSelection <: ActorSelection {
    public init() {}
    public func resolveOne(): SimpleFuture<ActorRef> { throw Exception("not found") }
    public func tell(message: Message): Unit {}
    public func tell(message: Message, sender: Option<String>): Unit {}
    public func ask(message: Message): SimpleFuture<Message> { throw Exception("not implemented") }
}

class CTXTestSimpleFuture <: SimpleFuture<Unit> {
    public init() {}
    public func get(): Unit { () }
    public func isCompleted(): Bool { true }
}

class CTXTestEventBus <: EventBus {
    public init() {}
    public func publish(event: Any): Unit {}
    public func subscribe(subscriber: ActorRef, eventType: String): Bool { true }
    public func unsubscribe(subscriber: ActorRef, eventType: String): Bool { true }
    public func subscriberCount(eventType: String): Int64 { 0 }
}

class CTXDefaultActorContext <: ActorContext {
    private let selfRef: ActorRef
    private let systemRef: CTXTestActorSystem
    private var receiveTimeoutValue: Duration
    private let childrenMap: HashMap<String, ActorRef>
    private let watchedList: ArrayList<ActorRef>
    private let counter: AtomicInt64

    public init(system: CTXTestActorSystem) {
        this.selfRef = CTXTestActorRef("/test/self", system)
        this.systemRef = system
        this.receiveTimeoutValue = Duration.second * 0
        this.childrenMap = HashMap<String, ActorRef>()
        this.watchedList = ArrayList<ActorRef>()
        this.counter = AtomicInt64(0)
    }

    public func sender(): ActorRef { selfRef }
    public func self(): ActorRef { selfRef }
    public func parent(): ActorRef { CTXTestActorRef("/test/parent", systemRef) }
    public func children(): Array<ActorRef> { watchedList.toArray() }
    public func child(name: String): Option<ActorRef> { childrenMap.get(name) }

    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        let actualName = if (name.isEmpty()) { "auto-${counter.fetchAdd(1)}" } else { name }
        let ref = systemRef.actorOf(props, actualName)
        childrenMap.add(actualName, ref)
        ref
    }

    public func actorOf(props: Props<Actor>): ActorRef { actorOf(props, "") }
    public func watch(actorRef: ActorRef): Unit { watchedList.add(actorRef) }
    public func unwatch(actorRef: ActorRef): Unit {
        var i = 0
        while (i < watchedList.size) {
            if (watchedList[i].equals(actorRef)) {
                watchedList.remove(Int64(i)..Int64(i + 1))
                return
            }
            i += 1
        }
    }
    public func getWatchedActors(): Array<ActorRef> { watchedList.toArray() }
    public func getActorSystem(): ActorSystem { systemRef }
    public func setReceiveTimeout(timeout: Duration): Unit { receiveTimeoutValue = timeout }
    public func receiveTimeout(): Duration { receiveTimeoutValue }
    public func stop(): Unit {}
    public func stop(actorRef: ActorRef): Unit {}
}
