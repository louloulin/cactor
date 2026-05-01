/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - RemoteActorRef 单元测试
 */
package cactor.distribution.remote

import std.collection.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath, ActorAddress}

// === 测试消息类型 ===

class TestRemoteMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestRemoteMessage"
    }
}

// === Mock RemoteActorProxy ===

class MockRemoteActorProxy <: RemoteActorProxy {
    public var lastPath: Option<ActorPath> = None
    public var lastMessage: Option<Message> = None
    public var tellCount: Int64 = 0

    public init() {}

    public func tell(path: ActorPath, message: Message): Unit {
        lastPath = Some(path)
        lastMessage = Some(message)
        tellCount += 1
    }

    public func ask(path: ActorPath, message: Message, config!: RemoteCallConfig): RemoteCallResult<Message> {
        lastPath = Some(path)
        lastMessage = Some(message)
        RemoteCallResult(false, None, Some("mock failure"), 10, "mock-node")
    }

    public func select(pathPattern: String): ActorSelection {
        ActorSelection(this, pathPattern)
    }

    public func getNodeId(): String {
        "mock-node"
    }
}

// === RemoteActorRefState 测试 ===

@Test
func testRemoteActorRefState_values() {
    let connected = RemoteActorRefState.Connected
    let disconnected = RemoteActorRefState.Disconnected
    let connecting = RemoteActorRefState.Connecting
    let failed = RemoteActorRefState.Failed

    @Expect(connected.isAvailable(), true)
    @Expect(disconnected.isAvailable(), false)
    @Expect(connecting.isAvailable(), false)
    @Expect(failed.isAvailable(), false)
}

// === RemoteActorRef 测试 ===

@Test
func testRemoteActorRef_creation() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("testSystem", host, port)
    let path = ActorPath(addr, "/user/actor1")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    @Expect(ref.path.toString().contains("cactor://"), true)
    // Just verify state getter works
    let state = ref.getState()
    @Expect(state.isAvailable(), false)
}

@Test
func testRemoteActorRef_path() {
    let host = "node1"
    let port: Int32 = 8080
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/service/worker")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    let pathStr = ref.path.toString()
    @Expect(pathStr.contains("node1"), true)
    @Expect(pathStr.contains("8080"), true)
}

@Test
func testRemoteActorRef_tell() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/test")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    ref.setState(RemoteActorRefState.Connected)
    let msg = TestRemoteMessage("hello")

    ref.tell(msg)

    let hasPath = match (proxy.lastPath) {
        case Some(_) => true
        case None => false
    }
    let hasMsg = match (proxy.lastMessage) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasPath, true)
    @Expect(hasMsg, true)
    @Expect(proxy.tellCount, 1)
}

@Test
func testRemoteActorRef_tell_whenDisconnected() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/test")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    // 不设置 Connected 状态
    let msg = TestRemoteMessage("hello")
    ref.tell(msg)

    @Expect(proxy.tellCount, 0)  // 不应发送
}

@Test
func testRemoteActorRef_messageCount() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/counter")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    ref.setState(RemoteActorRefState.Connected)

    ref.tell(TestRemoteMessage("msg1"))
    ref.tell(TestRemoteMessage("msg2"))
    ref.tell(TestRemoteMessage("msg3"))

    @Expect(ref.getMessageCount(), 3)
}

@Test
func testRemoteActorRef_lastMessageTime() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/time")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    ref.setState(RemoteActorRefState.Connected)
    let beforeTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

    ref.tell(TestRemoteMessage("time test"))

    let lastTime = ref.getLastMessageTime()
    @Expect(lastTime >= beforeTime, true)
}

@Test
func testRemoteActorRef_equals() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/same")
    let proxy1 = MockRemoteActorProxy()
    let proxy2 = MockRemoteActorProxy()

    let ref1 = RemoteActorRef(host, port, path, proxy1)
    let ref2 = RemoteActorRef(host, port, path, proxy2)

    @Expect(ref1.equals(ref2), true)
}

@Test
func testRemoteActorRef_equalsDifferentPaths() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path1 = ActorPath(addr, "/user/actor1")
    let path2 = ActorPath(addr, "/user/actor2")
    let proxy = MockRemoteActorProxy()

    let ref1 = RemoteActorRef(host, port, path1, proxy)
    let ref2 = RemoteActorRef(host, port, path2, proxy)

    @Expect(ref1.equals(ref2), false)
}

@Test
func testRemoteActorRef_hashCode() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/hash")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    let hash = ref.hashCode()
    @Expect(hash != 0, true)
}

@Test
func testRemoteActorRef_toString() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/tostring")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    let str = ref.toString()
    @Expect(str.contains("RemoteActorRef"), true)
    @Expect(str.contains("tostring"), true)
}

@Test
func testRemoteActorRef_getRemoteAddress() {
    let host = "192.168.1.100"
    let port: Int32 = 9000
    let addr = ActorAddress("mySystem", host, port)
    let path = ActorPath(addr, "/user/remote")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    let (retHost, retPort) = ref.getRemoteAddress()
    @Expect(retHost, "192.168.1.100")
    @Expect(retPort, 9000)
}

@Test
func testRemoteActorRef_isAvailable() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/available")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    @Expect(ref.isAvailable(), false)

    ref.setState(RemoteActorRefState.Connected)
    @Expect(ref.isAvailable(), true)

    ref.setState(RemoteActorRefState.Disconnected)
    @Expect(ref.isAvailable(), false)
}

@Test
func testRemoteActorRef_stateTransitions() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/state")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    // Initial state should not be available
    @Expect(ref.isAvailable(), false)

    ref.setState(RemoteActorRefState.Connecting)
    @Expect(ref.isAvailable(), false)

    ref.setState(RemoteActorRefState.Connected)
    @Expect(ref.isAvailable(), true)

    ref.setState(RemoteActorRefState.Failed)
    @Expect(ref.isAvailable(), false)
}

// === RemoteActorRefFactory 测试 ===

@Test
func testRemoteActorRefFactory_creation() {
    let proxy = MockRemoteActorProxy()
    let factory = RemoteActorRefFactory(proxy)

    let host = "node1"
    let port: Int32 = 8080
    let addr = ActorAddress("factory", host, port)
    let path = ActorPath(addr, "/user/factory")

    let ref = factory.create(path)

    @Expect(ref.path.toString() == path.toString(), true)
}

@Test
func testRemoteActorRefFactory_createFromString() {
    let proxy = MockRemoteActorProxy()
    let factory = RemoteActorRefFactory(proxy)

    let ref = factory.createFromString("cactor://system@host:9000/user/actor")

    // createFromString returns RemoteActorRef directly
    @Expect(ref.path.toString().contains("user"), true)
}

@Test
func testRemoteActorRefFactory_createBatch() {
    let proxy = MockRemoteActorProxy()
    let factory = RemoteActorRefFactory(proxy)

    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("batch", host, port)
    let paths = Array<ActorPath>(3, { i =>
        match (i) {
            case 0 => ActorPath(addr, "/user/actor1")
            case 1 => ActorPath(addr, "/user/actor2")
            case _ => ActorPath(addr, "/user/actor3")
        }
    })

    let refs = factory.createBatch(paths)

    @Expect(refs.size, 3)
}

// === RemoteActorProxyManager 测试 ===

@Test
func testRemoteActorProxyManager_registerProxy() {
    let manager = RemoteActorProxyManager()
    let proxy = MockRemoteActorProxy()

    manager.registerProxy("node1:8080", proxy)

    @Expect(manager.getProxyCount(), 1)
}

@Test
func testRemoteActorProxyManager_getProxy() {
    let manager = RemoteActorProxyManager()
    let proxy = MockRemoteActorProxy()

    manager.registerProxy("node1:8080", proxy)

    let retrieved = manager.getProxy("node1:8080")
    match (retrieved) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, false)
    }
}

@Test
func testRemoteActorProxyManager_getProxyNotFound() {
    let manager = RemoteActorProxyManager()

    let retrieved = manager.getProxy("nonexistent")
    match (retrieved) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testRemoteActorProxyManager_removeProxy() {
    let manager = RemoteActorProxyManager()
    let proxy = MockRemoteActorProxy()

    manager.registerProxy("node1:8080", proxy)
    @Expect(manager.getProxyCount(), 1)

    let removed = manager.removeProxy("node1:8080")
    @Expect(removed, true)
    @Expect(manager.getProxyCount(), 0)
}

@Test
func testRemoteActorProxyManager_removeProxyNotFound() {
    let manager = RemoteActorProxyManager()

    let removed = manager.removeProxy("nonexistent")
    @Expect(removed, false)
}

@Test
func testRemoteActorProxyManager_clear() {
    let manager = RemoteActorProxyManager()
    let proxy1 = MockRemoteActorProxy()
    let proxy2 = MockRemoteActorProxy()

    manager.registerProxy("node1:8080", proxy1)
    manager.registerProxy("node2:8080", proxy2)
    @Expect(manager.getProxyCount(), 2)

    manager.clear()
    @Expect(manager.getProxyCount(), 0)
}

@Test
func testRemoteActorProxyManager_createRemoteRef() {
    let manager = RemoteActorProxyManager()
    let proxy = MockRemoteActorProxy()
    manager.registerProxy("localhost:2552", proxy)

    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/ref")

    let ref = manager.createRemoteRef(path)
    match (ref) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, false)
    }
}

@Test
func testRemoteActorProxyManager_createRemoteRefNoProxy() {
    let manager = RemoteActorProxyManager()

    let host = "unknown"
    let port: Int32 = 9999
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/ref")

    let ref = manager.createRemoteRef(path)
    match (ref) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

// === 集成测试 ===

@Test
func testRemoteActorCommunication_integration() {
    // 模拟完整的远程通信流程
    let manager = RemoteActorProxyManager()
    let proxy = MockRemoteActorProxy()
    manager.registerProxy("192.168.1.100:9000", proxy)

    // 创建远程引用
    let host = "192.168.1.100"
    let port: Int32 = 9000
    let addr = ActorAddress("remoteSystem", host, port)
    let path = ActorPath(addr, "/user/service/endpoint")
    let refOpt = manager.createRemoteRef(path)

    // 验证引用创建成功
    match (refOpt) {
        case Some(actorRef) =>
            // 设置为已连接
            actorRef.setState(RemoteActorRefState.Connected)

            // 发送消息
            let msg = TestRemoteMessage("integration test")
            actorRef.tell(msg)

            // 验证消息发送
            @Expect(proxy.tellCount, 1)
            let hasMsg = match (proxy.lastMessage) {
                case Some(_) => true
                case None => false
            }
            @Expect(hasMsg, true)
            @Expect(actorRef.getMessageCount(), 1)
        case None =>
            @Expect(true, false)  // 应该不执行到这里
    }
}

@Test
func testRemoteActorStateManagement() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/stateMgmt")
    let proxy = MockRemoteActorProxy()
    let ref = RemoteActorRef(host, port, path, proxy)

    // 初始状态
    @Expect(ref.isAvailable(), false)

    // 变为连接中
    ref.setState(RemoteActorRefState.Connecting)
    @Expect(ref.isAvailable(), false)

    // 连接成功
    ref.setState(RemoteActorRefState.Connected)
    @Expect(ref.isAvailable(), true)

    // 发送消息
    ref.tell(TestRemoteMessage("state test"))
    @Expect(proxy.tellCount, 1)
    @Expect(ref.getMessageCount(), 1)

    // 连接失败
    ref.setState(RemoteActorRefState.Failed)
    @Expect(ref.isAvailable(), false)

    // 消息不再发送
    ref.tell(TestRemoteMessage("should not send"))
    @Expect(proxy.tellCount, 1)  // 仍然是 1
}

@Test
func testRemoteActorRef_equalityWithDifferentStates() {
    let host = "localhost"
    let port: Int32 = 2552
    let addr = ActorAddress("system", host, port)
    let path = ActorPath(addr, "/user/equal")
    let proxy1 = MockRemoteActorProxy()
    let proxy2 = MockRemoteActorProxy()

    let ref1 = RemoteActorRef(host, port, path, proxy1)
    let ref2 = RemoteActorRef(host, port, path, proxy2)

    // 即使状态不同，只要路径相同就相等
    ref1.setState(RemoteActorRefState.Connected)
    ref2.setState(RemoteActorRefState.Disconnected)

    @Expect(ref1.equals(ref2), true)
    @Expect(ref1.hashCode() == ref2.hashCode(), true)
}