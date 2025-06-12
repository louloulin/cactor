/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - 消息系统定义
 */
package cactor.core.message

/**
 * 消息基础接口
 * 所有在Actor系统中传递的消息都必须实现此接口
 */
public interface Message {
    /**
     * 获取消息类型标识
     * @return 消息类型字符串
     */
    func messageType(): String

    /**
     * 获取消息优先级
     * 数值越大优先级越高
     * @return 优先级数值
     */
    func priority(): Int32 {
        0  // 默认优先级
    }

    /**
     * 获取消息的唯一标识
     * @return 消息ID
     */
    func messageId(): String {
        ""  // 默认空ID
    }

    /**
     * 获取消息创建时间戳
     * @return 时间戳
     */
    func timestamp(): Int64 {
        0  // 默认时间戳
    }
}

/**
 * 系统消息接口
 * 用于Actor系统内部控制的消息
 */
public interface SystemMessage <: Message {
    /**
     * 系统消息默认具有高优先级
     */
    func priority(): Int32 {
        1000
    }
}

/**
 * 用户消息接口
 * 用于业务逻辑的消息
 */
public interface UserMessage <: Message {
    /**
     * 用户消息默认具有普通优先级
     */
    func priority(): Int32 {
        0
    }
}

/**
 * 停止消息
 * 用于请求Actor停止
 */
public struct StopMessage <: SystemMessage {
    private let reason: String

    public init(reason: String = "Normal stop") {
        this.reason = reason
    }

    public func messageType(): String {
        "StopMessage"
    }

    public func getReason(): String {
        reason
    }
}

/**
 * 重启消息
 * 用于请求Actor重启
 */
public struct RestartMessage <: SystemMessage {
    private let cause: Exception

    public init(cause: Exception) {
        this.cause = cause
    }

    public func messageType(): String {
        "RestartMessage"
    }

    public func getCause(): Exception {
        cause
    }
}

/**
 * 暂停消息
 * 用于请求Actor暂停处理消息
 */
public struct SuspendMessage <: SystemMessage {
    public init() {}

    public func messageType(): String {
        "SuspendMessage"
    }
}

/**
 * 恢复消息
 * 用于请求Actor恢复处理消息
 */
public struct ResumeMessage <: SystemMessage {
    public init() {}

    public func messageType(): String {
        "ResumeMessage"
    }
}

/**
 * 监视消息
 * 用于请求监视另一个Actor
 */
public struct WatchMessage <: SystemMessage {
    private let target: String  // Actor路径

    public init(target: String) {
        this.target = target
    }

    public func messageType(): String {
        "WatchMessage"
    }

    public func getTarget(): String {
        target
    }
}

/**
 * 取消监视消息
 * 用于取消对另一个Actor的监视
 */
public struct UnwatchMessage <: SystemMessage {
    private let target: String  // Actor路径

    public init(target: String) {
        this.target = target
    }

    public func messageType(): String {
        "UnwatchMessage"
    }

    public func getTarget(): String {
        target
    }
}

/**
 * 终止消息
 * 当被监视的Actor终止时发送
 */
public struct TerminatedMessage <: SystemMessage {
    private let actor: String   // 终止的Actor路径
    private let reason: String  // 终止原因

    public init(actor: String, reason: String) {
        this.actor = actor
        this.reason = reason
    }

    public func messageType(): String {
        "TerminatedMessage"
    }

    public func getActor(): String {
        actor
    }

    public func getReason(): String {
        reason
    }
}

/**
 * Ping消息
 * 用于测试Actor是否响应
 */
public struct PingMessage <: UserMessage {
    private let id: Int64

    public init(id: Int64) {
        this.id = id
    }

    public func messageType(): String {
        "PingMessage"
    }

    public func getId(): Int64 {
        id
    }
}

/**
 * Pong消息
 * 对Ping消息的响应
 */
public struct PongMessage <: UserMessage {
    private let originalId: Int64

    public init(originalId: Int64) {
        this.originalId = originalId
    }

    public func messageType(): String {
        "PongMessage"
    }

    public func getOriginalId(): Int64 {
        originalId
    }
}

/**
 * 死信消息
 * 包装发送给已停止Actor的消息
 */
public struct DeadLetter <: SystemMessage {
    private let message: Message
    private let sender: String
    private let recipient: String

    public init(message: Message, sender: String, recipient: String) {
        this.message = message
        this.sender = sender
        this.recipient = recipient
    }

    public func messageType(): String {
        "DeadLetter"
    }

    public func getMessage(): Message {
        message
    }

    public func getSender(): String {
        sender
    }

    public func getRecipient(): String {
        recipient
    }
}
