/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 行为Actor实现
 * 支持动态行为切换 (Become/Unbecome)
 * 对标 Akka BecomeBehavior
 */
package cactor.core.actor

import std.collection.*
import cactor.core.message.*

/**
 * 基于行为的Actor实现
 * 支持动态行为切换
 * 对标 Akka BecomeBehavior
 */
public class BehaviorActorImpl <: BehaviorActor & Actor {
    private let actorName: String
    private var behaviorStack: ArrayList<ActorBehavior>
    private var activeBehavior: ActorBehavior
    private var receivedCount: Int64 = 0

    public init(name: String, initialBehavior: ActorBehavior) {
        this.actorName = name
        this.behaviorStack = ArrayList<ActorBehavior>()
        this.activeBehavior = initialBehavior
        this.receivedCount = 0
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Behavior actor: ${actorName}" }
    }

    /**
     * 获取当前行为
     */
    public func currentBehavior(): ActorBehavior {
        activeBehavior
    }

    /**
     * 切换到新行为
     * 对标 Akka: context.become(newBehavior)
     * @param newBehavior 新行为
     */
    public func become(newBehavior: ActorBehavior): Unit {
        behaviorStack.add(activeBehavior)
        activeBehavior = newBehavior
    }

    /**
     * 恢复到之前的行为
     * 对标 Akka: context.unbecome()
     */
    public func unbecome(): Unit {
        if (behaviorStack.isEmpty()) {
            return
        }
        let idx = behaviorStack.size - 1
        let prevBehavior = behaviorStack[idx]
        behaviorStack.remove(Int64(idx)..Int64(idx + 1))
        activeBehavior = prevBehavior
    }

    /**
     * 处理接收到的消息
     * 根据当前行为处理消息
     */
    public func receive(message: Message, context: ActorContext): MessageResult {
        receivedCount += 1
        activeBehavior.receive(message, context)
    }

    /**
     * 获取行为栈大小
     */
    public func getBehaviorStackSize(): Int64 {
        behaviorStack.size
    }

    /**
     * 获取接收消息计数
     */
    public func getReceivedCount(): Int64 {
        receivedCount
    }

    public func preStart(): Unit {}

    public func postStart(): Unit {}

    public func preStop(): Unit {}

    public func postStop(): Unit {}

    public func preRestart(reason: Exception): Unit {
        preStop()
    }

    public func postRestart(reason: Exception): Unit {
        postStart()
    }

    public func receiveTimeout(): Unit {}
}

/**
 * 函数式行为
 * 使用函数作为行为定义
 */
public class FunctionalBehavior <: ActorBehavior {
    private let handler: (Message, ActorContext) -> MessageResult

    public init(handler: (Message, ActorContext) -> MessageResult) {
        this.handler = handler
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        handler(message, context)
    }
}

/**
 * 行为切换帮助类
 */
public class BehaviorSupport {
    /**
     * 创建接收所有消息的行为
     */
    public static func receiveAll(handler: (Message, ActorContext) -> MessageResult): FunctionalBehavior {
        FunctionalBehavior(handler)
    }

    /**
     * 组合多个行为
     */
    public static func anyOf(behaviors: ArrayList<ActorBehavior>): FunctionalBehavior {
        FunctionalBehavior({ msg, ctx =>
            for (behavior in behaviors) {
                let result = behavior.receive(msg, ctx)
                match (result) {
                    case MessageResult.Handled => return MessageResult.Handled
                    case _ => ()
                }
            }
            MessageResult.Unhandled
        })
    }
}

/**
 * Stash 支持接口
 * 用于暂存消息稍后处理
 */
public interface StashSupport {
    /**
     * 暂存消息
     * @param message 要暂存的消息
     */
    func stash(message: Message): Unit

    /**
     * 取出并处理暂存的消息
     */
    func unstash(): Unit

    /**
     * 获取暂存的消息数量
     */
    func stashSize(): Int64
}

/**
 * 带 Stash 支持的 Actor
 */
public class StashingActor <: Actor & StashSupport {
    private let actorName: String
    private var stashedMessages: ArrayList<Message>
    private var isStashing: Bool

    public init(name: String) {
        this.actorName = name
        this.stashedMessages = ArrayList<Message>()
        this.isStashing = false
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Stashing actor: ${actorName}" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        MessageResult.Unhandled
    }

    public func stash(message: Message): Unit {
        stashedMessages.add(message)
    }

    public func unstash(): Unit {
        isStashing = true
    }

    public func unstashAll(): ArrayList<Message> {
        let messages = stashedMessages
        stashedMessages = ArrayList<Message>()
        isStashing = false
        messages
    }

    public func stashSize(): Int64 {
        stashedMessages.size
    }

    public func isUnstashing(): Bool {
        isStashing
    }
}

/**
 * ReceiveTimeout 配置
 */
public struct ReceiveTimeoutConfig {
    public let enabled: Bool
    public let timeout: Duration
    public let repeatTimeout: Bool

    public init(enabled: Bool, timeout: Duration, repeatTimeout: Bool) {
        this.enabled = enabled
        this.timeout = timeout
        this.repeatTimeout = repeatTimeout
    }

    public static func disabled(): ReceiveTimeoutConfig {
        ReceiveTimeoutConfig(false, Duration.second * 0, false)
    }

    public static func withTimeout(timeout: Duration): ReceiveTimeoutConfig {
        ReceiveTimeoutConfig(true, timeout, true)
    }

    public static func withTimeoutOnce(timeout: Duration): ReceiveTimeoutConfig {
        ReceiveTimeoutConfig(true, timeout, false)
    }
}
