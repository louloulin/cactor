/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Pipe Pattern 实现
 * 将 Future 的结果传递给 Actor
 */
package cactor.patterns.pipe

import std.collection.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath}

/**
 * PipeMessage - Pipe 操作的消息类型
 */
public class PipeMessage <: Message {
    public let isSuccess: Bool
    public let value: String
    public let error: String
    public let originalMessage: Option<Message>

    public init(isSuccess: Bool, value: String, error: String, originalMessage: Option<Message>) {
        this.isSuccess = isSuccess
        this.value = value
        this.error = error
        this.originalMessage = originalMessage
    }

    public func messageType(): String {
        "PipeMessage"
    }

    public static func success(value: String): PipeMessage {
        PipeMessage(true, value, "", None)
    }

    public static func failure(error: String): PipeMessage {
        PipeMessage(false, "", error, None)
    }
}

/**
 * PipeTarget - Pipe 消息的目标
 */
public interface PipeTarget {
    func pipeSuccess(value: String, originalMessage: Option<Message>): Unit
    func pipeFailure(reason: String, originalMessage: Option<Message>): Unit
}

/**
 * Pipe - 用于将结果传递给 Actor
 */
public class Pipe {
    /**
     * 将成功结果 pipe 到目标
     */
    public static func success(value: String, target: PipeTarget, originalMessage: Option<Message>): Unit {
        target.pipeSuccess(value, originalMessage)
    }

    /**
     * 将失败结果 pipe 到目标
     */
    public static func failure(reason: String, target: PipeTarget, originalMessage: Option<Message>): Unit {
        target.pipeFailure(reason, originalMessage)
    }

    /**
     * 将结果 pipe 到 ActorRef
     */
    public static func to(actorRef: ActorRef, successMsg: String, failureMsg: String, isSuccess: Bool): Unit {
        if (isSuccess) {
            actorRef.tell(PipeMessage.success(successMsg))
        } else {
            actorRef.tell(PipeMessage.failure(failureMsg))
        }
    }
}

/**
 * FuturePipe - 用于 Future 的 Pipe
 */
public class FuturePipe {
    private let timeout: Duration

    public init() {
        this.timeout = Duration.second * 5
    }

    public static func create(timeout: Duration): FuturePipe {
        let pipe = FuturePipe()
        pipe
    }

    /**
     * 将成功结果 pipe 到目标
     */
    public func pipeSuccess(value: String, target: PipeTarget, originalMessage: Option<Message>): Unit {
        Pipe.success(value, target, originalMessage)
    }

    /**
     * 将失败结果 pipe 到目标
     */
    public func pipeFailure(reason: String, target: PipeTarget, originalMessage: Option<Message>): Unit {
        Pipe.failure(reason, target, originalMessage)
    }

    /**
     * 将结果 pipe 到 ActorRef
     */
    public func pipeTo(actorRef: ActorRef, successMsg: String, failureMsg: String, isSuccess: Bool): Unit {
        Pipe.to(actorRef, successMsg, failureMsg, isSuccess)
    }
}

/**
 * PipeContext - Pipe 操作的上下文
 */
public class PipeContext {
    public let originalMessage: Option<Message>
    public let sender: Option<ActorRef>
    public let timestamp: Int64

    public init() {
        this.originalMessage = None
        this.sender = None
        this.timestamp = 0
    }

    public static func withMessage(msg: Message): PipeContext {
        let ctx = PipeContext()
        ctx
    }
}

/**
 * PipedActor - 支持 Pipe 模式的 Actor 基类
 */
public interface PipedActor <: PipeTarget {
    func handlePipeSuccess(value: String, context: PipeContext): Unit
    func handlePipeFailure(reason: String, context: PipeContext): Unit
}

/**
 * PipeBuilder - 构建 Pipe 操作
 */
public class PipeBuilder {
    private var successHandler: Option<(String, PipeContext) -> Unit> = None
    private var failureHandler: Option<(String, PipeContext) -> Unit> = None
    private var timeout: Duration = Duration.second * 5
    private var context: PipeContext = PipeContext()

    public init() {}

    /**
     * 设置成功处理器
     */
    public func onSuccess(handler: (String, PipeContext) -> Unit): PipeBuilder {
        this.successHandler = Some(handler)
        this
    }

    /**
     * 设置失败处理器
     */
    public func onFailure(handler: (String, PipeContext) -> Unit): PipeBuilder {
        this.failureHandler = Some(handler)
        this
    }

    /**
     * 设置超时时间
     */
    public func withTimeout(timeout: Duration): PipeBuilder {
        this.timeout = timeout
        this
    }

    /**
     * 设置上下文
     */
    public func withContext(context: PipeContext): PipeBuilder {
        this.context = context
        this
    }

    /**
     * 设置原始消息
     */
    public func withOriginalMessage(msg: Message): PipeBuilder {
        let ctx = PipeContext()
        this.context = ctx
        this
    }

    /**
     * 执行 Pipe 操作 - 成功
     */
    public func executeSuccess(value: String): Unit {
        match (successHandler) {
            case Some(handler) => handler(value, context)
            case None => ()
        }
    }

    /**
     * 执行 Pipe 操作 - 失败
     */
    public func executeFailure(reason: String): Unit {
        match (failureHandler) {
            case Some(handler) => handler(reason, context)
            case None => ()
        }
    }
}

/**
 * SuccessMessage - 成功结果消息
 */
public class SuccessMessage <: Message {
    public let value: String
    public let context: Option<PipeContext>

    public init(value: String) {
        this.value = value
        this.context = None
    }

    public func messageType(): String {
        "SuccessMessage"
    }
}

/**
 * FailureMessage - 失败结果消息
 */
public class FailureMessage <: Message {
    public let reason: String
    public let context: Option<PipeContext>

    public init(reason: String) {
        this.reason = reason
        this.context = None
    }

    public func messageType(): String {
        "FailureMessage"
    }
}
