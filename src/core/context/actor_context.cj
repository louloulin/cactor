/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - Actor上下文定义
 */
package cactor.core.context

import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorSelection, Behavior}
import cactor.core.message.Message
import cactor.core.system.ActorSystem

/**
 * Actor上下文接口
 * 提供Actor运行时的环境和服务
 */
public interface ActorContext {
    /**
     * 获取当前Actor的引用
     * @return 当前Actor的ActorRef
     */
    func self(): ActorRef

    /**
     * 获取当前消息的发送者
     * @return 发送者的ActorRef，如果没有则为None
     */
    func sender(): Option<ActorRef>

    /**
     * 获取Actor系统引用
     * @return ActorSystem实例
     */
    func system(): ActorSystem

    /**
     * 获取父Actor引用
     * @return 父Actor的ActorRef
     */
    func parent(): ActorRef

    /**
     * 创建子Actor
     * @param props Actor创建属性
     * @param name 子Actor名称
     * @return 子Actor的引用
     */
    func actorOf<T>(props: Props<T>, name: String): ActorRef where T <: Actor

    /**
     * 选择Actor
     * @param path Actor路径字符串
     * @return ActorSelection实例
     */
    func actorSelection(path: String): ActorSelection

    /**
     * 停止指定的Actor
     * @param actor 要停止的Actor引用
     */
    func stop(actor: ActorRef): Unit

    /**
     * 监视指定的Actor
     * 当被监视的Actor终止时，会收到TerminatedMessage
     * @param actor 要监视的Actor引用
     */
    func watch(actor: ActorRef): Unit

    /**
     * 取消监视指定的Actor
     * @param actor 要取消监视的Actor引用
     */
    func unwatch(actor: ActorRef): Unit

    /**
     * 切换Actor行为
     * @param behavior 新的行为
     */
    func become(behavior: Behavior<Message>): Unit

    /**
     * 恢复到之前的行为
     */
    func unbecome(): Unit

    /**
     * 调度一次性任务
     * @param delay 延迟时间
     * @param message 要发送的消息
     * @param target 目标Actor
     */
    func scheduleOnce(delay: Duration, message: Message, target: ActorRef): Unit

    /**
     * 调度周期性任务
     * @param initialDelay 初始延迟
     * @param interval 间隔时间
     * @param message 要发送的消息
     * @param target 目标Actor
     */
    func schedule(initialDelay: Duration, interval: Duration, message: Message, target: ActorRef): Unit
}

/**
 * Props类
 * 用于配置Actor的创建参数
 */
public struct Props<T> where T <: Actor {
    private let factory: ActorFactory<T>
    private let dispatcher: String
    private let mailboxType: String
    private let supervisionStrategy: String

    public init(factory: ActorFactory<T>) {
        this.factory = factory
        this.dispatcher = "default"
        this.mailboxType = "unbounded"
        this.supervisionStrategy = "default"
    }

    /**
     * 设置调度器
     * @param dispatcher 调度器名称
     * @return 新的Props实例
     */
    func withDispatcher(dispatcher: String): Props<T> {
        Props<T>(factory, dispatcher, mailboxType, supervisionStrategy)
    }

    /**
     * 设置邮箱类型
     * @param mailboxType 邮箱类型
     * @return 新的Props实例
     */
    func withMailbox(mailboxType: String): Props<T> {
        Props<T>(factory, this.dispatcher, mailboxType, supervisionStrategy)
    }

    /**
     * 设置监督策略
     * @param strategy 监督策略
     * @return 新的Props实例
     */
    func withSupervisionStrategy(strategy: String): Props<T> {
        Props<T>(factory, dispatcher, mailboxType, strategy)
    }

    /**
     * 创建Actor实例
     * @return Actor实例
     */
    func create(): T {
        factory.create()
    }

    /**
     * 获取调度器名称
     * @return 调度器名称
     */
    func getDispatcher(): String {
        dispatcher
    }

    /**
     * 获取邮箱类型
     * @return 邮箱类型
     */
    func getMailboxType(): String {
        mailboxType
    }

    /**
     * 获取监督策略
     * @return 监督策略
     */
    func getSupervisionStrategy(): String {
        supervisionStrategy
    }

    // 私有构造函数，用于创建新实例
    private init(factory: ActorFactory<T>, dispatcher: String, mailboxType: String, supervisionStrategy: String) {
        this.factory = factory
        this.dispatcher = dispatcher
        this.mailboxType = mailboxType
        this.supervisionStrategy = supervisionStrategy
    }
}

/**
 * 监督策略接口
 * 定义当子Actor失败时的处理策略
 */
public interface SupervisionStrategy {
    /**
     * 决定如何处理失败的子Actor
     * @param cause 失败原因
     * @param child 失败的子Actor
     * @return 监督决策
     */
    func decide(cause: Exception, child: ActorRef): SupervisionDirective
}

/**
 * 监督指令枚举
 * 定义对失败Actor的处理方式
 */
public enum SupervisionDirective {
    | Resume      // 恢复Actor，忽略失败
    | Restart     // 重启Actor
    | Stop        // 停止Actor
    | Escalate    // 向上级监督者报告
}

/**
 * 默认监督策略
 * 对所有异常都执行重启
 */
public struct DefaultSupervisionStrategy <: SupervisionStrategy {
    public init() {}

    public func decide(cause: Exception, child: ActorRef): SupervisionDirective {
        SupervisionDirective.Restart
    }
}

/**
 * 一对一监督策略
 * 只影响失败的单个Actor
 */
public struct OneForOneStrategy <: SupervisionStrategy {
    private let maxRetries: Int32
    private let withinTimeRange: Duration

    public init(maxRetries: Int32, withinTimeRange: Duration) {
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
    }

    public func decide(cause: Exception, child: ActorRef): SupervisionDirective {
        // 简化实现，实际应该跟踪重试次数和时间
        if (maxRetries > 0) {
            SupervisionDirective.Restart
        } else {
            SupervisionDirective.Stop
        }
    }
}

/**
 * 全部监督策略
 * 当一个Actor失败时，重启所有子Actor
 */
public struct AllForOneStrategy <: SupervisionStrategy {
    private let maxRetries: Int32
    private let withinTimeRange: Duration

    public init(maxRetries: Int32, withinTimeRange: Duration) {
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
    }

    public func decide(cause: Exception, child: ActorRef): SupervisionDirective {
        // 简化实现
        SupervisionDirective.Restart
    }
}
