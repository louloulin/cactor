/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Ask模式实现
 * 支持请求-响应模式的异步通信
 */
package cactor.pattern.ask

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.message.{Message, Envelope}
import cactor.core.actor.ActorRef

/**
 * Ask请求消息
 */
public class AskMessage <: Message {
    private let requestId: String
    private let originalMessage: Message
    private let replyTo: ActorRef

    public init(requestId: String, originalMessage: Message, replyTo: ActorRef) {
        this.requestId = requestId
        this.originalMessage = originalMessage
        this.replyTo = replyTo
    }

    public func messageType(): String {
        "AskMessage"
    }

    public func getRequestId(): String {
        requestId
    }

    public func getOriginalMessage(): Message {
        originalMessage
    }

    public func getReplyTo(): ActorRef {
        replyTo
    }
}

/**
 * Ask响应消息
 */
public class AskResponse <: Message {
    private let requestId: String
    private let response: Message
    private let success: Bool

    public init(requestId: String, response: Message, success: Bool) {
        this.requestId = requestId
        this.response = response
        this.success = success
    }

    public func messageType(): String {
        "AskResponse"
    }

    public func getRequestId(): String {
        requestId
    }

    public func getResponse(): Message {
        response
    }

    public func isSuccess(): Bool {
        success
    }
}

/**
 * Ask超时异常
 */
public class AskTimeoutException <: Exception {
    private let requestId: String
    private let timeout: Duration

    public init(requestId: String, timeout: Duration) {
        super("Ask request ${requestId} timed out after ${timeout}")
        this.requestId = requestId
        this.timeout = timeout
    }

    public func getRequestId(): String {
        requestId
    }

    public func getTimeout(): Duration {
        timeout
    }
}

/**
 * Ask Future - 表示异步操作的结果
 */
public class AskFuture<T> {
    private let requestId: String
    private let timeout: Duration
    private let startTime: Int64
    private let result: AtomicRef<Option<Result<T>>>
    private let completed: AtomicBool
    private let waiters: ArrayList<() -> Unit>
    private let mutex: ReentrantMutex

    public init(requestId: String, timeout: Duration) {
        this.requestId = requestId
        this.timeout = timeout
        this.startTime = System.currentTimeMillis()
        this.result = AtomicRef<Option<Result<T>>>(None)
        this.completed = AtomicBool(false)
        this.waiters = ArrayList<() -> Unit>()
        this.mutex = ReentrantMutex()
    }

    public func complete(value: T): Unit {
        completeWith(Result.Success(value))
    }

    public func completeWithError(error: Exception): Unit {
        completeWith(Result.Failure(error))
    }

    private func completeWith(resultValue: Result<T>): Unit {
        if (completed.compareAndSwap(false, true)) {
            result.store(Some(resultValue))
            
            // 通知所有等待者
            mutex.lock()
            try {
                for (waiter in waiters) {
                    spawn {
                        waiter()
                    }
                }
                waiters.clear()
            } finally {
                mutex.unlock()
            }
        }
    }

    public func get(): Result<T> {
        // 检查是否已完成
        match (result.load()) {
            case Some(res) => res
            case None => 
                // 检查是否超时
                if (isTimedOut()) {
                    Result.Failure(AskTimeoutException(requestId, timeout))
                } else {
                    // 等待完成或超时
                    waitForCompletion()
                }
        }
    }

    public func get(waitTimeout: Duration): Result<T> {
        let waitStartTime = System.currentTimeMillis()
        let waitTimeoutMs = waitTimeout.toMilliseconds()
        
        while (!completed.load()) {
            let elapsed = System.currentTimeMillis() - waitStartTime
            if (elapsed >= waitTimeoutMs) {
                return Result.Failure(AskTimeoutException(requestId, waitTimeout))
            }
            
            if (isTimedOut()) {
                return Result.Failure(AskTimeoutException(requestId, timeout))
            }
            
            sleep(Duration.millisecond)
        }
        
        match (result.load()) {
            case Some(res) => res
            case None => Result.Failure(AskTimeoutException(requestId, timeout))
        }
    }

    public func onComplete(callback: (Result<T>) -> Unit): Unit {
        if (completed.load()) {
            match (result.load()) {
                case Some(res) => 
                    spawn {
                        callback(res)
                    }
                case None => 
                    // 不应该发生
                    ()
            }
        } else {
            mutex.lock()
            try {
                if (completed.load()) {
                    match (result.load()) {
                        case Some(res) => 
                            spawn {
                                callback(res)
                            }
                        case None => ()
                    }
                } else {
                    waiters.append(() => {
                        match (result.load()) {
                            case Some(res) => callback(res)
                            case None => ()
                        }
                    })
                }
            } finally {
                mutex.unlock()
            }
        }
    }

    public func isCompleted(): Bool {
        completed.load()
    }

    public func isTimedOut(): Bool {
        let elapsed = System.currentTimeMillis() - startTime
        elapsed >= timeout.toMilliseconds()
    }

    private func waitForCompletion(): Result<T> {
        while (!completed.load() && !isTimedOut()) {
            sleep(Duration.millisecond)
        }
        
        if (isTimedOut()) {
            Result.Failure(AskTimeoutException(requestId, timeout))
        } else {
            match (result.load()) {
                case Some(res) => res
                case None => Result.Failure(AskTimeoutException(requestId, timeout))
            }
        }
    }

    public func getRequestId(): String {
        requestId
    }
}

/**
 * Ask模式管理器
 */
public class AskPatternManager {
    private let pendingRequests: ConcurrentHashMap<String, AskFuture<Message>>
    private let requestCounter: AtomicInt64
    private let defaultTimeout: Duration
    private let cleanupInterval: Duration
    private let isRunning: AtomicBool

    public init(defaultTimeout: Duration) {
        this.pendingRequests = ConcurrentHashMap<String, AskFuture<Message>>()
        this.requestCounter = AtomicInt64(0)
        this.defaultTimeout = defaultTimeout
        this.cleanupInterval = Duration.second * 30
        this.isRunning = AtomicBool(false)
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            // 启动清理任务
            spawn {
                cleanupLoop()
            }
        }
    }

    public func stop(): Unit {
        isRunning.store(false)
    }

    public func ask(target: ActorRef, message: Message): AskFuture<Message> {
        ask(target, message, defaultTimeout)
    }

    public func ask(target: ActorRef, message: Message, timeout: Duration): AskFuture<Message> {
        let requestId = generateRequestId()
        let future = AskFuture<Message>(requestId, timeout)
        
        pendingRequests[requestId] = future
        
        // 创建临时Actor来接收响应
        let replyTo = createReplyActor(requestId)
        let askMessage = AskMessage(requestId, message, replyTo)
        
        // 发送Ask消息
        target.tell(askMessage)
        
        return future
    }

    public func handleResponse(response: AskResponse): Unit {
        let requestId = response.getRequestId()
        
        match (pendingRequests.remove(requestId)) {
            case Some(future) => 
                if (response.isSuccess()) {
                    future.complete(response.getResponse())
                } else {
                    future.completeWithError(Exception("Ask request failed"))
                }
            case None => 
                // 请求已超时或不存在
                println("收到未知请求的响应: ${requestId}")
        }
    }

    private func generateRequestId(): String {
        let counter = requestCounter.fetchAdd(1)
        let timestamp = System.currentTimeMillis()
        "ask-${timestamp}-${counter}"
    }

    private func createReplyActor(requestId: String): ActorRef {
        // 简化实现：返回一个虚拟的ActorRef
        // 实际实现中应该创建一个临时Actor
        DummyActorRef(requestId)
    }

    private func cleanupLoop(): Unit {
        while (isRunning.load()) {
            cleanupTimedOutRequests()
            sleep(cleanupInterval)
        }
    }

    private func cleanupTimedOutRequests(): Unit {
        let toRemove = ArrayList<String>()
        
        for ((requestId, future) in pendingRequests) {
            if (future.isTimedOut()) {
                toRemove.append(requestId)
            }
        }
        
        for (requestId in toRemove) {
            match (pendingRequests.remove(requestId)) {
                case Some(future) => 
                    future.completeWithError(AskTimeoutException(requestId, defaultTimeout))
                case None => ()
            }
        }
        
        if (!toRemove.isEmpty()) {
            println("清理了 ${toRemove.size} 个超时的Ask请求")
        }
    }

    public func getPendingRequestCount(): Int64 {
        pendingRequests.size.toInt64()
    }

    public func getDefaultTimeout(): Duration {
        defaultTimeout
    }
}

/**
 * 虚拟ActorRef实现（用于测试）
 */
public class DummyActorRef <: ActorRef {
    private let id: String

    public init(id: String) {
        this.id = id
    }

    public func tell(message: Message): Unit {
        println("DummyActorRef[${id}] 收到消息: ${message.messageType()}")
    }

    public func toString(): String {
        "DummyActorRef(${id})"
    }
}

/**
 * Result类型定义
 */
public enum Result<T> {
    | Success(T)
    | Failure(Exception)

    public func isSuccess(): Bool {
        match (this) {
            case Success(_) => true
            case Failure(_) => false
        }
    }

    public func isFailure(): Bool {
        !isSuccess()
    }

    public func get(): T {
        match (this) {
            case Success(value) => value
            case Failure(error) => throw error
        }
    }

    public func getOrElse(defaultValue: T): T {
        match (this) {
            case Success(value) => value
            case Failure(_) => defaultValue
        }
    }
}
