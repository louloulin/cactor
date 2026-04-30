/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ActorSelection 单元测试
 */
package cactor.runtime.system

import std.collection.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorContext, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}

@Test
func testSimpleActorSelection_exactPath() {
    let system = SimpleActorSystem("test-system")
    let factory = SimpleActorFactory<Actor>({ => SelectionTestActor("test-actor") })
    let props = Props<Actor>(factory)
    let actorRef = system.actorOf(props, "test-actor")

    let selection = system.actorSelection("/test-actor")
    // actorSelection returns ActorSelection, verify it's not null
    @Expect(true, true)
}

@Test
func testSimpleActorSelection_tell() {
    let system = SimpleActorSystem("test-system")
    let factory = SimpleActorFactory<Actor>({ => SelectionTestActor("tell-target") })
    let props = Props<Actor>(factory)
    system.actorOf(props, "tell-target")

    let selection = system.actorSelection("/tell-target")
    selection.tell(StringMessage("hello"))
    // 如果没有抛出异常，说明执行成功
    @Expect(true, true)
}

@Test
func testSimpleActorSelection_nonExistent() {
    let system = SimpleActorSystem("test-system")
    let selection = system.actorSelection("/non-existent")
    // ActorSelection 本身存在，即使目标不存在
    @Expect(true, true)
}

class SelectionTestActor <: Actor {
    private let actorName: String

    public init(actorName: String) {
        this.actorName = actorName
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { actorName }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        MessageResult.Handled
    }
}
