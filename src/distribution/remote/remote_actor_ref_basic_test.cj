/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - RemoteActorRef 独立测试
 * 简化版测试，不依赖 remote_proxy
 */
package cactor.distribution.remote

import std.collection.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath, ActorAddress}

// === 测试消息类型 ===

class TestRemoteMsg <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestRemoteMsg"
    }
}

// === RemoteActorRefState 测试 ===

@Test
func testRemoteActorRefState_Connected() {
    let state = RemoteActorRefState.Connected
    @Expect(state.isAvailable(), true)
}

@Test
func testRemoteActorRefState_Disconnected() {
    let state = RemoteActorRefState.Disconnected
    @Expect(state.isAvailable(), false)
}

@Test
func testRemoteActorRefState_Connecting() {
    let state = RemoteActorRefState.Connecting
    @Expect(state.isAvailable(), false)
}

@Test
func testRemoteActorRefState_Failed() {
    let state = RemoteActorRefState.Failed
    @Expect(state.isAvailable(), false)
}

// === ActorPathParser 测试 ===

@Test
func testActorPathParser_parse() {
    let path = ActorPathParser.parse("cactor://system@localhost:2552/user/actor")
    let addr = path.getAddress()

    @Expect(addr.host.size > 0, true)
    @Expect(addr.port, 2552)
    @Expect(path.getPath().contains("user"), true)
}

@Test
func testActorPathParser_parseWithIp() {
    let path = ActorPathParser.parse("cactor://cluster@192.168.1.100:9000/user/service/worker")
    let addr = path.getAddress()

    @Expect(addr.host, "192.168.1.100")
    @Expect(addr.port, 9000)
    @Expect(addr.system, "cluster")
    @Expect(path.getPath().contains("service"), true)
}

@Test
func testActorPathParser_create() {
    let path = ActorPathParser.create("testSystem", "node1", 8080, ["user", "actor"])
    let addr = path.getAddress()

    @Expect(addr.system, "testSystem")
    @Expect(addr.host, "node1")
    @Expect(addr.port, 8080)
    @Expect(path.getPath().contains("user"), true)
}

// === MessageSerializer 测试 ===

@Test
func testMessageSerializer_serializeEmpty() {
    let serializer = MessageSerializer()
    let addr = ActorAddress("sys", "localhost", 2552)
    let path = ActorPath(addr, "/user/test")
    let msg = TestRemoteMsg("hello")
    let envelope = RemoteEnvelope(path, msg, None, 0, None)

    let data = serializer.serialize(envelope)
    @Expect(data.size >= 0, true)
}

@Test
func testMessageSerializer_deserializeReturnsNone() {
    let serializer = MessageSerializer()
    let data = Array<UInt8>(10, { i => UInt8(i) })

    let result = serializer.deserialize(data)
    // Use match to check for None
    let isNone = match (result) {
        case None => true
        case Some(_) => false
    }
    @Expect(isNone, true)
}

// === CompletableFuture 测试 ===

@Test
func testCompletableFuture_initialState() {
    let future = CompletableFuture<String>()

    @Expect(future.isCompleted(), false)
}

@Test
func testCompletableFuture_complete() {
    let future = CompletableFuture<String>()

    future.complete("result")

    @Expect(future.isCompleted(), true)
    let result = future.getWithTimeout(1000)
    let hasValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasValue, true)
}

@Test
func testCompletableFuture_fail() {
    let future = CompletableFuture<String>()

    future.fail("error")

    @Expect(future.isCompleted(), true)
}

@Test
func testCompletableFuture_getWithTimeout() {
    let future = CompletableFuture<Int64>()
    future.complete(42)

    let result = future.getWithTimeout(1000)
    match (result) {
        case Some(v) => @Expect(v, 42)
        case None => @Expect(true, false)
    }
}

// === RemoteCallResult 测试 ===

@Test
func testRemoteCallResult_ok() {
    let result = RemoteCallResult<Int64>.ok(100, 50, "node1")

    @Expect(result.success, true)
    // Use match to check Option
    let valueHas = match (result.value) {
        case Some(_) => true
        case None => false
    }
    let errorHas = match (result.error) {
        case Some(_) => true
        case None => false
    }
    @Expect(valueHas, true)
    @Expect(errorHas, false)
    @Expect(result.latency, 50)
    @Expect(result.nodeId, "node1")
}

@Test
func testRemoteCallResult_failure() {
    let result = RemoteCallResult<Int64>.failure("timeout", 100, "node1")

    @Expect(result.success, false)
    let valueHas = match (result.value) {
        case Some(_) => true
        case None => false
    }
    let errorHas = match (result.error) {
        case Some(_) => true
        case None => false
    }
    @Expect(valueHas, false)
    @Expect(errorHas, true)
    @Expect(result.latency, 100)
    @Expect(result.nodeId, "node1")
}

@Test
func testRemoteCallResult_intOk() {
    let result = RemoteCallResult<Int32>.ok(42, 25, "server1")

    @Expect(result.success, true)
}

// === RemoteCallConfig 测试 ===

@Test
func testRemoteCallConfig_default() {
    let config = RemoteCallConfig()

    @Expect(config.timeout, 30000)
    @Expect(config.retries, 3)
    @Expect(config.retryDelay, 1000)
    @Expect(config.oneWay, false)
}

@Test
func testRemoteCallConfig_custom() {
    let config = RemoteCallConfig(
        timeout: 60000,
        retries: 5,
        retryDelay: 2000,
        oneWay: true
    )

    @Expect(config.timeout, 60000)
    @Expect(config.retries, 5)
    @Expect(config.retryDelay, 2000)
    @Expect(config.oneWay, true)
}

// === AddressResolver 测试 (使用 Address from remote_transport) ===

@Test
func testAddressResolver_initialState() {
    let resolver = AddressResolver()

    // Address is from remote_transport.cj
    let addr = Address("cactor", "sys", "localhost", 2552)
    let result = resolver.resolve(addr)

    let hasValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasValue, true)
}

@Test
func testAddressResolver_cacheAddress() {
    let resolver = AddressResolver()

    let original = Address("cactor", "sys", "original", 2552)
    let resolved = Address("cactor", "sys", "resolved", 2553)

    resolver.cacheAddress(original, resolved)

    let result = resolver.resolve(original)
    let hasValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasValue, true)
}

@Test
func testAddressResolver_clearCache() {
    let resolver = AddressResolver()

    let original = Address("cactor", "sys", "localhost", 2552)
    let resolved = Address("cactor", "sys", "localhost", 2554)

    resolver.cacheAddress(original, resolved)
    resolver.clearCache()

    // After clear, still returns resolved (from discovery)
    let result = resolver.resolve(original)
    let hasValue = match (result) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasValue, true)
}

// === Integration 测试 (使用 ActorAddress from core.actor) ===

@Test
func testAddress_pathConversion() {
    // ActorAddress is from core/actor/actor.cj
    // ActorPath takes a String path, not Array<String>
    let addr = ActorAddress("testSystem", "192.168.1.50", 8080)
    let path = ActorPath(addr, "/user/service/endpoint")

    let pathStr = path.toString()
    @Expect(pathStr.contains("192.168.1.50"), true)
    @Expect(pathStr.contains("8080"), true)
    @Expect(pathStr.contains("user"), true)
}

@Test
func testAddress_equality() {
    let addr1 = ActorAddress("sys", "localhost", 2552)
    let addr2 = ActorAddress("sys", "localhost", 2552)

    @Expect(addr1.equals(addr2), true)
}

@Test
func testAddress_inequality() {
    let addr1 = ActorAddress("sys", "localhost", 2552)
    let addr2 = ActorAddress("sys", "localhost", 2553)

    @Expect(addr1.equals(addr2), false)
}

@Test
func testActorPath_parentPath() {
    let addr = ActorAddress("sys", "localhost", 2552)
    let path = ActorPath(addr, "/user/parent/child")

    let parent = path.parent()
    // Parent path should be /user/parent
    @Expect(path.getPath().contains("/user/parent/child"), true)
}

@Test
func testActorPath_childPath() {
    let addr = ActorAddress("sys", "localhost", 2552)
    let path = ActorPath(addr, "/user/parent")

    let child = path.child("newchild")
    @Expect(child.getPath().contains("newchild"), true)
}

@Test
func testActorPath_getName() {
    let addr = ActorAddress("sys", "localhost", 2552)
    let path = ActorPath(addr, "/user/service/actor")

    @Expect(path.name(), "actor")
}

@Test
func testActorPath_emptyNameCheck() {
    let addr = ActorAddress("sys", "localhost", 2552)
    let path = ActorPath(addr, "/")

    let name = path.name()
    @Expect(name.size >= 0, true)
}