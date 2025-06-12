/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 消息系统
 * 高性能消息传递机制
 */
package cactor.core.message

import std.time.*

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
     * @return 时间戳（纳秒）
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
 * 消息处理结果枚举
 */
public enum MessageResult {
    | Handled        // 消息已成功处理
    | Unhandled      // 消息未被处理
    | Stop           // 请求停止Actor
    | Restart        // 请求重启Actor
    | Escalate       // 向监督者报告问题
}

/**
 * 停止消息
 * 用于请求Actor停止
 */
public struct StopMessage <: SystemMessage {
    private let reason: String

    public init(reason: String) {
        this.reason = reason
    }

    public init() {
        this.reason = "Normal stop"
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
    private let ts: Int64

    public init(id: Int64) {
        this.id = id
        this.ts = getCurrentTimeNanos()
    }

    public func messageType(): String {
        "PingMessage"
    }

    public func getId(): Int64 {
        id
    }

    public func timestamp(): Int64 {
        ts
    }
}

/**
 * Pong消息
 * 对Ping消息的响应
 */
public struct PongMessage <: UserMessage {
    private let originalId: Int64
    private let ts: Int64

    public init(originalId: Int64) {
        this.originalId = originalId
        this.ts = getCurrentTimeNanos()
    }

    public func messageType(): String {
        "PongMessage"
    }

    public func getOriginalId(): Int64 {
        originalId
    }

    public func timestamp(): Int64 {
        ts
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

/**
 * 消息信封
 * 包装消息和发送者信息
 */
public struct Envelope {
    private let message: Message
    private let sender: Option<String>  // 发送者路径
    private let timestamp: Int64

    public init(message: Message, sender: Option<String>) {
        this.message = message
        this.sender = sender
        this.timestamp = getCurrentTimeNanos()
    }

    public func getMessage(): Message {
        message
    }

    public func getSender(): Option<String> {
        sender
    }

    public func getTimestamp(): Int64 {
        timestamp
    }
}

/**
 * 获取当前时间戳（纳秒）
 * 简化实现，实际应该使用仓颉的时间API
 */
func getCurrentTimeNanos(): Int64 {
    // 简化实现，返回毫秒级时间戳
    let now = DateTime.now()
    now.toUnixTimeStamp().toMilliseconds() * 1000000
}
