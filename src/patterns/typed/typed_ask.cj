/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Typed Ask Pattern 实现
 * 对标 Akka Typed Ask Pattern
 */
package cactor.patterns.typed

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorContext}
import cactor.core.message.{Message, MessageResult}
import cactor.core.system.{ActorSystem}

/**
 * SimpleConditionVariable - 简化的条件变量
 */
class SimpleConditionVariable {
    public func wait(lock: Mutex): Unit {
        // 简化实现
    }

    public func signal(): Unit {
        // 简化实现
    }

    public func broadcast(): Unit {
        // 简化实现
    }
}

/**
 * AskPattern - Typed Ask Pattern 实现
 * 提供类型安全的 ask 请求模式
 */
public class AskPattern<Request, Response> {
    private let ref: ActorRef
    private let timeout: Duration

    public init(ref: ActorRef, timeout: Duration) {
        this.ref = ref
        this.timeout = timeout
    }

    /**
     * 发送 ask 请求并返回 Future
     */
    public func ask(request: Request): AskFuture<Response> {
        AskFuture<Response>(ref, request, timeout)
    }

    /**
     * 发送 ask 请求，带自定义超时
     */
    public func askWithTimeout(request: Request, timeout: Duration): AskFuture<Response> {
        AskFuture<Response>(ref, request, timeout)
    }
}

/**
 * AskFuture - Ask 操作的 Future 实现
 */
public class AskFuture<Response> {
    private let ref: ActorRef
    private let request: Any
    private let timeout: Duration
    private var completed: Bool
    private var result: Option<Response>
    private let lock: Mutex
    private let condition: SimpleConditionVariable

    public init(ref: ActorRef, request: Any, timeout: Duration) {
        this.ref = ref
        this.request = request
        this.timeout = timeout
        this.completed = false
        this.result = None
        this.lock = Mutex()
        this.condition = SimpleConditionVariable()
    }

    /**
     * 发送请求
     */
    public func execute(): Unit {
        // 创建 AskEnvelope 包装请求
        let envelope = AskEnvelope(ref, request)
        ref.tell(envelope)
    }

    /**
     * 等待结果
     */
    public func await(): Response {
        lock.lock()
        try {
            while (!completed) {
                condition.wait(lock)
            }
            match (result) {
                case Some(r) => r
                case None => throw Exception("Ask timeout or failed")
            }
        } finally {
            lock.unlock()
        }
    }

    /**
     * 检查是否完成
     */
    public func isDone(): Bool {
        lock.lock()
        try {
            completed
        } finally {
            lock.unlock()
        }
    }

    /**
     * 获取结果（如果完成）
     */
    public func value(): Option<Response> {
        lock.lock()
        try {
            result
        } finally {
            lock.unlock()
        }
    }

    /**
     * 内部方法：设置结果
     */
    public func complete(response: Response): Unit {
        lock.lock()
        try {
            if (!completed) {
                result = Some(response)
                completed = true
                condition.broadcast()
            }
        } finally {
            lock.unlock()
        }
    }
}

/**
 * AskEnvelope - Ask 请求包装器
 */
class AskEnvelope <: Message {
    private let originalRef: ActorRef
    private let request: Any

    public init(originalRef: ActorRef, request: Any) {
        this.originalRef = originalRef
        this.request = request
    }

    public func messageType(): String {
        "AskEnvelope"
    }

    public func getOriginalRef(): ActorRef {
        originalRef
    }

    public func getRequest(): Any {
        request
    }
}

/**
 * AskResponse - Ask 响应消息
 */
class AskResponse<Response> <: Message {
    private let response: Response
    private let originalEnvelope: Option<AskEnvelope>

    public init(response: Response, originalEnvelope: Option<AskEnvelope>) {
        this.response = response
        this.originalEnvelope = originalEnvelope
    }

    public func messageType(): String {
        "AskResponse"
    }

    public func getResponse(): Response {
        response
    }

    public func getOriginalEnvelope(): Option<AskEnvelope> {
        originalEnvelope
    }
}

/**
 * TypedAskSupport - Typed Actor Ask 支持接口
 */
public interface TypedAskSupport<Command, Response> {
    /**
     * Ask 请求
     */
    func ask(request: Command): AskFuture<Response>

    /**
     * 带超时的 Ask 请求
     */
    func askWithTimeout(request: Command, timeout: Duration): AskFuture<Response>
}

/**
 * AskPatternCompanion - Ask Pattern 伴随对象
 * 提供静态方法创建 AskPattern
 */
public class AskPatternCompanion {
    /**
     * 为 ActorRef 创建 AskPattern
     */
    public static func apply<Request, Response>(
        ref: ActorRef,
        timeout: Duration
    ): AskPattern<Request, Response> {
        AskPattern<Request, Response>(ref, timeout)
    }

    /**
     * 默认超时（5秒）
     */
    public static func defaultTimeout(): Duration {
        Duration.second * 5
    }
}

/**
 * WithAskPattern - 为 TypedActorRef 添加 Ask 能力
 */
public interface WithAskPattern<Command, Response> {
    /**
     * Ask 请求，返回 AskFuture
     */
    func ask(request: Command): AskFuture<Response>

    /**
     * 带超时的 Ask 请求
     */
    func askWithTimeout(request: Command, timeout: Duration): AskFuture<Response>
}

/**
 * AskResult - Ask 操作的结果
 */
public class AskResult<T> {
    private let value: Option<T>
    private let error: Option<String>

    public init(value: T) {
        this.value = Some(value)
        this.error = None
    }

    public init(error: String) {
        this.value = None
        this.error = Some(error)
    }

    /**
     * 检查是否成功
     */
    public func isSuccess(): Bool {
        value.isSome()
    }

    /**
     * 获取值
     */
    public func get(): T {
        match (value) {
            case Some(v) => v
            case None => throw Exception("Unknown error")
        }
    }

    /**
     * 获取值或默认值
     */
    public func getOrDefault(defaultValue: T): T {
        match (value) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    /**
     * 映射结果
     */
    public func map<U>(f: (T) -> U): AskResult<U> {
        match (value) {
            case Some(v) => AskResult<U>(f(v))
            case None => AskResult<U>("Unknown error")
        }
    }

    /**
     * 扁平映射结果
     */
    public func flatMap<U>(f: (T) -> AskResult<U>): AskResult<U> {
        match (value) {
            case Some(v) => f(v)
            case None => AskResult<U>("Unknown error")
        }
    }
}

/**
 * AskContext - Ask 操作的上下文
 */
public class AskContext {
    public let request: Any
    public let sender: ActorPath
    public let timestamp: Int64

    public init(request: Any, sender: ActorPath) {
        this.request = request
        this.sender = sender
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * AskTimeoutException - Ask 超时异常
 */
public class AskTimeoutException <: Exception {
    public let timeout: Duration

    public init(timeout: Duration) {
        super("Ask operation timed out after ${timeout}")
        this.timeout = timeout
    }
}

/**
 * AskCancelledException - Ask 取消异常
 */
public class AskCancelledException <: Exception {
    public init() {
        super()
    }

    public func getMessage(): String {
        "Ask operation was cancelled"
    }
}