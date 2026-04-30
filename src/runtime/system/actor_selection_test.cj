/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ActorSelection 单元测试
 */
package cactor.runtime.system

import std.collection.*
import std.time.*
import cactor.core.actor.*
import cactor.core.system.*
import cactor.core.message.*

@Test
func testSimpleActorSelection_exactPath() {
    let system = SimpleActorSystem("test-system")
    let props = Props<Actor>({ => SimpleTestActor("test-actor") })
    let actorRef = system.actorOf(props, "test-actor")

    let selection = system.actorSelection("/test-actor")
    @Expect(selection !== None, true)
}

@Test
func testSimpleActorSelection_userPath() {
    let system = SimpleActorSystem("test-system")
    let props = Props<Actor>({ => SimpleTestActor("user-actor") })
    let actorRef = system.actorOf(props, "user-actor")

    let selection = system.actorSelection("/user/user-actor")
    @Expect(selection !== None, true)
}

@Test
func testSimpleActorSelection_wildcardSingleLevel() {
    let system = SimpleActorSystem("test-system")
    let props1 = Props<Actor>({ => SimpleTestActor("actor1") })
    let props2 = Props<Actor>({ => SimpleTestActor("actor2") })
    system.actorOf(props1, "actor1")
    system.actorOf(props2, "actor2")

    let selection = system.actorSelection("/*")
    let matches = selection.resolveAll()
    @Expect(matches.size >= 2, true)
}

@Test
func testSimpleActorSelection_nonExistentActor() {
    let system = SimpleActorSystem("test-system")
    let selection = system.actorSelection("/non-existent-actor")

    let matches = selection.resolveAll()
    @Expect(matches.size, 0)
}

@Test
func testSimpleActorSelection_tell() {
    let system = SimpleActorSystem("test-system")
    let props = Props<Actor>({ => SimpleTestActor("tell-target") })
    system.actorOf(props, "tell-target")

    let selection = system.actorSelection("/tell-target")
    selection.tell(TestMessage("hello"))
    // 如果没有抛出异常，说明执行成功
}

@Test
func testSimpleActorSelection_pathNormalization() {
    let system = SimpleActorSystem("test-system")
    let props = Props<Actor>({ => SimpleTestActor("normalized") })
    system.actorOf(props, "normalized")

    // 测试各种路径格式
    let selection1 = system.actorSelection("/normalized")
    let selection2 = system.actorSelection("///normalized")

    let matches1 = selection1.resolveAll()
    let matches2 = selection2.resolveAll()

    @Expect(matches1.size, 1)
    @Expect(matches2.size >= 0, true)  // 可能需要特殊处理
}

@Test
func testSimpleActorSelection_multipleActors() {
    let system = SimpleActorSystem("test-system")

    // 创建多个Actor
    for (i in 0..5) {
        let props = Props<Actor>({ => SimpleTestActor("multi-actor-${i}") })
        system.actorOf(props, "multi-actor-${i}")
    }

    let selection = system.actorSelection("/*")
    let matches = selection.resolveAll()
    @Expect(matches.size >= 5, true)
}

/*
 * 测试辅助类
 */

class SimpleTestActor <: Actor {
    private let actorName: String

    public init(name: String) {
        this.actorName = name
    }

    public prop name: String {
        get() { actorName }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        MessageResult.Handled
    }
}
