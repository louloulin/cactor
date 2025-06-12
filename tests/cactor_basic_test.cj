/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 基础功能测试
 * 验证核心Actor系统的基本功能
 */
package cactor.tests.basic

import std.time.*
import std.sync.*

/**
 * 简单的测试Actor
 */
public class TestActor <: Actor {
    private let actorName: String
    private let messageCount: AtomicInt64

    public init(name: String) {
        this.actorName = name
        this.messageCount = AtomicInt64(0)
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Test Actor: ${actorName}" }
    }

    public func preStart(): Unit {
        println("${actorName} starting...")
    }

    public func postStart(): Unit {
        println("${actorName} started!")
    }

    public func preStop(): Unit {
        println("${actorName} stopping...")
    }

    public func postStop(): Unit {
        println("${actorName} stopped!")
    }

    public func incrementMessageCount(): Int64 {
        messageCount.fetchAdd(1) + 1
    }

    public func getMessageCount(): Int64 {
        messageCount.load()
    }
}

/**
 * 测试消息
 */
public struct TestMessage <: UserMessage {
    private let content: String
    private let id: Int64

    public init(content: String, id: Int64) {
        this.content = content
        this.id = id
    }

    public func messageType(): String {
        "TestMessage"
    }

    public func getContent(): String {
        content
    }

    public func getId(): Int64 {
        id
    }
}

/**
 * 测试Actor路径功能
 */
func testActorPath(): Bool {
    println("=== 测试Actor路径功能 ===")
    
    let path1 = ActorPath("test-system", "/user/actor1")
    let path2 = ActorPath("test-system", "/user/actor1")
    let path3 = ActorPath("test-system", "/user/actor2")
    
    // 测试相等性
    if (!path1.equals(path2)) {
        println("✗ Actor路径相等性测试失败")
        return false
    }
    
    if (path1.equals(path3)) {
        println("✗ Actor路径不等性测试失败")
        return false
    }
    
    // 测试字符串表示
    let pathStr = path1.toString()
    if (pathStr != "cactor://test-system/user/actor1") {
        println("✗ Actor路径字符串表示测试失败: ${pathStr}")
        return false
    }
    
    // 测试子路径
    let childPath = path1.child("child")
    let expectedChild = "cactor://test-system/user/actor1/child"
    if (childPath.toString() != expectedChild) {
        println("✗ Actor子路径测试失败: ${childPath.toString()}")
        return false
    }
    
    println("✓ Actor路径功能测试通过")
    return true
}

/**
 * 测试Props功能
 */
func testProps(): Bool {
    println("=== 测试Props功能 ===")
    
    let factory = SimpleActorFactory<TestActor>({ => TestActor("test") })
    let props = Props<TestActor>(factory)
    
    // 测试Actor创建
    let actor = props.create()
    if (actor.name != "test") {
        println("✗ Props Actor创建测试失败")
        return false
    }
    
    // 测试配置
    let propsWithDispatcher = props.withDispatcher("custom-dispatcher")
    if (propsWithDispatcher.getDispatcher() != "custom-dispatcher") {
        println("✗ Props调度器配置测试失败")
        return false
    }
    
    let propsWithMailbox = props.withMailbox("bounded")
    if (propsWithMailbox.getMailboxType() != "bounded") {
        println("✗ Props邮箱配置测试失败")
        return false
    }
    
    println("✓ Props功能测试通过")
    return true
}

/**
 * 测试邮箱功能
 */
func testMailbox(): Bool {
    println("=== 测试邮箱功能 ===")
    
    // 测试无界邮箱
    let unboundedMailbox = UnboundedMailbox()
    let message1 = TestMessage("Hello", 1)
    let envelope1 = Envelope(message1, Some("sender1"))
    
    if (!unboundedMailbox.enqueue(envelope1)) {
        println("✗ 无界邮箱入队测试失败")
        return false
    }
    
    if (unboundedMailbox.isEmpty()) {
        println("✗ 无界邮箱非空测试失败")
        return false
    }
    
    if (unboundedMailbox.size() != 1) {
        println("✗ 无界邮箱大小测试失败")
        return false
    }
    
    match (unboundedMailbox.dequeue()) {
        case Some(envelope) => {
            if (envelope.getMessage().messageType() != "TestMessage") {
                println("✗ 无界邮箱出队消息类型测试失败")
                return false
            }
        }
        case None => {
            println("✗ 无界邮箱出队测试失败")
            return false
        }
    }
    
    if (!unboundedMailbox.isEmpty()) {
        println("✗ 无界邮箱空测试失败")
        return false
    }
    
    // 测试有界邮箱
    let boundedMailbox = BoundedMailbox(2)
    let message2 = TestMessage("World", 2)
    let message3 = TestMessage("!", 3)
    let message4 = TestMessage("Overflow", 4)
    
    let envelope2 = Envelope(message2, Some("sender2"))
    let envelope3 = Envelope(message3, Some("sender3"))
    let envelope4 = Envelope(message4, Some("sender4"))
    
    if (!boundedMailbox.enqueue(envelope2) || !boundedMailbox.enqueue(envelope3)) {
        println("✗ 有界邮箱入队测试失败")
        return false
    }
    
    // 第三个消息应该被拒绝
    if (boundedMailbox.enqueue(envelope4)) {
        println("✗ 有界邮箱容量限制测试失败")
        return false
    }
    
    if (boundedMailbox.size() != 2) {
        println("✗ 有界邮箱大小测试失败")
        return false
    }
    
    println("✓ 邮箱功能测试通过")
    return true
}

/**
 * 测试消息功能
 */
func testMessage(): Bool {
    println("=== 测试消息功能 ===")
    
    // 测试用户消息
    let userMsg = TestMessage("test content", 123)
    if (userMsg.messageType() != "TestMessage") {
        println("✗ 用户消息类型测试失败")
        return false
    }
    
    if (userMsg.priority() != 0) {
        println("✗ 用户消息优先级测试失败")
        return false
    }
    
    // 测试系统消息
    let stopMsg = StopMessage("test stop")
    if (stopMsg.messageType() != "StopMessage") {
        println("✗ 系统消息类型测试失败")
        return false
    }
    
    if (stopMsg.priority() != 1000) {
        println("✗ 系统消息优先级测试失败")
        return false
    }
    
    // 测试Ping/Pong消息
    let pingMsg = PingMessage(456)
    if (pingMsg.messageType() != "PingMessage") {
        println("✗ Ping消息类型测试失败")
        return false
    }
    
    let pongMsg = PongMessage(456)
    if (pongMsg.messageType() != "PongMessage") {
        println("✗ Pong消息类型测试失败")
        return false
    }
    
    if (pongMsg.getOriginalId() != 456) {
        println("✗ Pong消息ID测试失败")
        return false
    }
    
    println("✓ 消息功能测试通过")
    return true
}

/**
 * 主测试函数
 */
main(): Int64 {
    println("=== CACtor 2.0 基础功能测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testActorPath()
    allPassed = allPassed && testProps()
    allPassed = allPassed && testMailbox()
    allPassed = allPassed && testMessage()
    
    if (allPassed) {
        println("\n🎉 所有基础功能测试通过！")
        println("✓ Actor路径系统正常")
        println("✓ Props配置系统正常")
        println("✓ 邮箱系统正常")
        println("✓ 消息系统正常")
        return 0
    } else {
        println("\n❌ 部分测试失败")
        return 1
    }
}
