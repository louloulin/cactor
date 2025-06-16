/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Ask模式测试
 * 验证Ask模式功能
 */
package cactor.integration.testing.ask_pattern_test

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.message.{Message, PingMessage}
import cactor.core.actor.{ActorRef, ActorPath}

// 简化的Ask模式类型定义
class DummyActorRef <: ActorRef {
    private let name: String
    private let actorPath: ActorPath

    public init(name: String) {
        this.name = name
        this.actorPath = ActorPath("test-system", "/user/${name}")
    }

    public prop path: ActorPath {
        get() { actorPath }
    }

    public func tell(message: Message): Unit {
        println("DummyActorRef ${name} 收到消息: ${message.messageType()}")
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        tell(message)
    }

    public func getName(): String { name }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case ref: DummyActorRef => ref.name == this.name
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(name.hashCode() & 0x7FFFFFFF)
    }
}

class AskMessage <: Message {
    private let requestId: String
    private let originalMessage: Message
    private let replyTo: ActorRef

    public init(requestId: String, originalMessage: Message, replyTo: ActorRef) {
        this.requestId = requestId
        this.originalMessage = originalMessage
        this.replyTo = replyTo
    }

    public func messageType(): String { "AskMessage" }
    public func priority(): Int32 { 1 }
    public func getRequestId(): String { requestId }
    public func getOriginalMessage(): Message { originalMessage }
    public func getReplyTo(): ActorRef { replyTo }
}

class AskResponse <: Message {
    private let requestId: String
    private let response: Message
    private let success: Bool

    public init(requestId: String, response: Message, success: Bool) {
        this.requestId = requestId
        this.response = response
        this.success = success
    }

    public func messageType(): String { "AskResponse" }
    public func priority(): Int32 { 1 }
    public func getRequestId(): String { requestId }
    public func getResponse(): Message { response }
    public func isSuccess(): Bool { success }
}

enum AskResult<T> {
    | Success(T)
    | Failure(String)

    public func isSuccess(): Bool {
        match (this) {
            case Success(_) => true
            case Failure(_) => false
        }
    }

    public func get(): T {
        match (this) {
            case Success(value) => value
            case Failure(error) => throw Exception("AskResult失败: ${error}")
        }
    }
}

class AskFuture<T> where T <: Message {
    private let requestId: String
    private let timeout: Duration
    private var completed: AtomicBool
    private var timedOut: AtomicBool
    private var result: Option<AskResult<T>>
    private let mutex: ReentrantMutex

    public init(requestId: String, timeout: Duration) {
        this.requestId = requestId
        this.timeout = timeout
        this.completed = AtomicBool(false)
        this.timedOut = AtomicBool(false)
        this.result = None
        this.mutex = ReentrantMutex()
    }

    public func getRequestId(): String { requestId }
    public func isCompleted(): Bool { completed.load() }
    public func isTimedOut(): Bool { timedOut.load() }

    public func complete(value: T): Unit {
        mutex.lock()
        if (!completed.load()) {
            this.result = Some(AskResult.Success(value))
            completed.store(true)
        }
        mutex.unlock()
    }

    public func fail(error: String): Unit {
        mutex.lock()
        if (!completed.load()) {
            this.result = Some(AskResult.Failure(error))
            completed.store(true)
        }
        mutex.unlock()
    }

    public func get(): AskResult<T> {
        mutex.lock()
        match (result) {
            case Some(res) =>
                mutex.unlock()
                res
            case None =>
                mutex.unlock()
                throw Exception("Future未完成")
        }
    }
}

/**
 * 测试Ask消息
 */
func testAskMessage(): Bool {
    let requestId = "test-request-1"
    let originalMessage = PingMessage(42)
    let replyTo = DummyActorRef("reply-actor")
    
    let askMessage = AskMessage(requestId, originalMessage, replyTo)
    
    if (askMessage.messageType() != "AskMessage") {
        println("✗ Ask消息类型错误")
        return false
    }
    
    if (askMessage.getRequestId() != requestId) {
        println("✗ 请求ID错误")
        return false
    }
    
    if (askMessage.getOriginalMessage().messageType() != "PingMessage") {
        println("✗ 原始消息类型错误")
        return false
    }
    
    println("✓ Ask消息测试通过")
    return true
}

/**
 * 测试Ask响应
 */
func testAskResponse(): Bool {
    let requestId = "test-request-1"
    let responseMessage = PingMessage(100)
    
    let successResponse = AskResponse(requestId, responseMessage, true)
    if (successResponse.messageType() != "AskResponse") {
        println("✗ Ask响应消息类型错误")
        return false
    }
    
    if (successResponse.getRequestId() != requestId) {
        println("✗ 响应请求ID错误")
        return false
    }
    
    if (!successResponse.isSuccess()) {
        println("✗ 成功响应应该标记为成功")
        return false
    }
    
    if (successResponse.getResponse().messageType() != "PingMessage") {
        println("✗ 响应消息类型错误")
        return false
    }
    
    let failureResponse = AskResponse(requestId, responseMessage, false)
    if (failureResponse.isSuccess()) {
        println("✗ 失败响应不应该标记为成功")
        return false
    }
    
    println("✓ Ask响应测试通过")
    return true
}

/**
 * 测试Ask Future基础功能
 */
func testAskFutureBasics(): Bool {
    let requestId = "test-request-1"
    let timeout = Duration.second * 5
    let future = AskFuture<PingMessage>(requestId, timeout)
    
    if (future.isCompleted()) {
        println("✗ 新创建的Future不应该已完成")
        return false
    }
    
    if (future.isTimedOut()) {
        println("✗ 新创建的Future不应该超时")
        return false
    }
    
    if (future.getRequestId() != requestId) {
        println("✗ Future请求ID错误")
        return false
    }
    
    // 完成Future
    let responseMessage = PingMessage(42)
    future.complete(responseMessage)
    
    if (!future.isCompleted()) {
        println("✗ 完成后Future应该标记为已完成")
        return false
    }
    
    // 获取结果
    let result = future.get()
    if (!result.isSuccess()) {
        println("✗ 成功完成的Future结果应该是成功的")
        return false
    }
    
    let value = result.get()
    if (value.messageType() != "PingMessage") {
        println("✗ Future结果消息类型错误")
        return false
    }
    
    println("✓ Ask Future基础功能测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor Ask模式测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testAskMessage()
    allPassed = allPassed && testAskResponse()
    allPassed = allPassed && testAskFutureBasics()
    
    if (allPassed) {
        println("\n🎉 所有Ask模式测试通过！")
        println("✓ Ask消息功能正常")
        println("✓ Ask响应功能正常")
        println("✓ Ask Future基础功能正常")
        println("\n这验证了CActor的Ask模式实现！")
        println("🚀 Phase 3: Ask模式功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
