/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 核心Actor接口
 * 基于仓颉语言特性的高性能Actor系统
 * 对标 Akka Typed Actor
 */
package cactor.core.actor

import std.time.*
import cactor.core.message.*

// 前向声明 ActorSystem 接口
public interface ActorSystem {}

// 前向声明：ActorContext接口，避免循环依赖
// 完整实现在 cactor.core.context 包中
public interface ActorContext {
    func sender(): ActorRef
    func self(): ActorRef
    func parent(): ActorRef
    func children(): Array<ActorRef>
    func child(name: String): Option<ActorRef>
    func actorOf(props: Props<Actor>, name: String): ActorRef
    func actorOf(props: Props<Actor>): ActorRef
    func watch(actorRef: ActorRef): Unit
    func unwatch(actorRef: ActorRef): Unit
    func getActorSystem(): ActorSystem
    func setReceiveTimeout(timeout: Duration): Unit
    func receiveTimeout(): Duration
    func stop(): Unit
    func stop(actorRef: ActorRef): Unit
}

/**
 * Actor生命周期状态
 * 对标 Akka: ActorCell.LifecycleState
 */
public enum ActorLifecycleState {
    | Created      // 已创建，未启动
    | Starting     // 启动中
    | Running      // 运行中
    | Stopping     // 停止中
    | Stopped      // 已停止
    | Failed       // 失败状态
    | Restarting   // 重启中

    public func toInt64(): Int64 {
        match (this) {
            case Created => 0
            case Starting => 1
            case Running => 2
            case Stopping => 3
            case Stopped => 4
            case Failed => 5
            case Restarting => 6
        }
    }

    public static func fromInt64(value: Int64): ActorLifecycleState {
        match (value) {
            case 0 => Created
            case 1 => Starting
            case 2 => Running
            case 3 => Stopping
            case 4 => Stopped
            case 5 => Failed
            case 6 => Restarting
            case _ => Stopped
        }
    }

    /**
     * 检查状态是否为活跃状态
     */
    public func isActive(): Bool {
        match (this) {
            case Running => true
            case _ => false
        }
    }
}

/**
 * Actor基础接口
 * 定义Actor的核心行为和生命周期
 * 对标 Akka Typed Behavior
 *
 * Akka 参考:
 * - Akka Actor: receive() 方法处理消息
 * - Akka Typed: Behavior[Command] 定义行为
 * - 生命周期钩子: preStart, postStop, preRestart, postRestart
 */
public interface Actor {
    /**
     * Actor的唯一名称
     */
    prop name: String

    /**
     * Actor的功能描述
     */
    prop description: String

    /**
     * 处理接收到的消息
     * 对标 Akka: receive(Message)
     * @param message 接收到的消息
     * @param context Actor上下文
     * @return 消息处理结果
     */
    func receive(message: Message, context: ActorContext): MessageResult {
        // 默认实现：未处理消息
        MessageResult.Unhandled
    }

    /**
     * Actor启动前的初始化操作
     * 在Actor开始处理消息之前调用
     * 对标 Akka: preStart()
     */
    func preStart(): Unit {
        // 默认空实现
    }

    /**
     * Actor启动后的操作
     * 在Actor开始处理消息后调用
     * 对标 Akka: postStart()
     */
    func postStart(): Unit {
        // 默认空实现
    }

    /**
     * Actor停止前的清理操作
     * 在Actor停止处理消息前调用
     * 对标 Akka: preStop()
     */
    func preStop(): Unit {
        // 默认空实现
    }

    /**
     * Actor停止后的清理操作
     * 在Actor完全停止后调用
     * 对标 Akka: postStop()
     */
    func postStop(): Unit {
        // 默认空实现
    }

    /**
     * Actor重启前的操作
     * 当Actor因异常需要重启时调用
     * 对标 Akka: preRestart(reason)
     */
    func preRestart(reason: Exception): Unit {
        preStop()
    }

    /**
     * Actor重启后的操作
     * 当Actor重启完成后调用
     * 对标 Akka: postRestart(reason)
     */
    func postRestart(reason: Exception): Unit {
        postStart()
    }

    /**
     * 处理接收超时的消息
     * 当设置接收超时后，在指定时间内没有收到消息时调用
     * 对标 Akka: ReceiveTimeout
     */
    func receiveTimeout(): Unit {
        // 默认空实现
    }
}

/**
 * 基于行为的Actor
 * 支持动态行为切换
 * 对标 Akka: BecomeBehavior
 */
public interface BehaviorActor <: Actor {
    /**
     * 获取当前行为
     */
    func currentBehavior(): ActorBehavior

    /**
     * 切换到新行为
     * 对标 Akka: context.become(newBehavior)
     * @param newBehavior 新行为
     */
    func become(newBehavior: ActorBehavior): Unit

    /**
     * 恢复到之前的行为
     * 对标 Akka: context.unbecome()
     */
    func unbecome(): Unit
}

/**
 * Actor行为定义
 */
public interface ActorBehavior {
    func receive(message: Message, context: ActorContext): MessageResult
}

/**
 * Actor工厂接口
 * 用于创建Actor实例
 */
public interface ActorFactory<T> where T <: Actor {
    /**
     * 创建Actor实例
     * @return 新的Actor实例
     */
    func create(): T
}

/**
 * 简单Actor工厂实现
 */
public class SimpleActorFactory<T> <: ActorFactory<T> where T <: Actor {
    private let creator: () -> T

    public init(creator: () -> T) {
        this.creator = creator
    }

    public func create(): T {
        creator()
    }
}



/**
 * Actor路径
 * 唯一标识Actor在系统中的位置
 * 对标 Akka: ActorPath
 *
 * Akka 格式: akka://system/user/actor/path
 * CActor 格式: cactor://system/user/actor/path
 */
public struct ActorPath {
    private let address: ActorAddress
    private let elements: Array<String>

    public init(address: ActorAddress, path: String) {
        this.address = address
        this.elements = Array<String>(0, { i => "" })
    }

    public init(system: String, path: String) {
        this.address = ActorAddress(system, "")
        this.elements = Array<String>(0, { i => "" })
    }

    public func getSystem(): String {
        address.system
    }

    public func getAddress(): ActorAddress {
        address
    }

    public func getPath(): String {
        let sb = StringBuilder()
        sb.append("/")
        for (elem in elements) {
            sb.append(elem)
            sb.append("/")
        }
        sb.toString()
    }

    public func toString(): String {
        "cactor://${address.system}${getPath()}"
    }

    // 获取父路径
    public func parent(): Option<ActorPath> {
        if (elements.size <= 1) {
            return None
        }
        let parentElements = Array<String>(Int64(elements.size - 1), { i => elements[i] })
        // 返回简化实现
        None
    }

    // 创建子路径
    public func child(name: String): ActorPath {
        let newElements = Array<String>(Int64(elements.size + 1), { i =>
            if (i < elements.size) {
                elements[i]
            } else {
                name
            }
        })
        ActorPath(address, "/${name}")
    }

    // 获取路径元素数量
    public func length(): Int64 {
        Int64(elements.size)
    }

    // 获取最后一个元素
    public func name(): String {
        if (elements.size == 0) {
            return ""
        }
        elements[elements.size - 1]
    }

    public func equals(other: ActorPath): Bool {
        address.equals(other.address) && getPath() == other.getPath()
    }

    public func hashCode(): Int32 {
        Int32(toString().hashCode())
    }
}

/**
 * Actor地址
 */
public struct ActorAddress {
    public let system: String
    public let host: String
    public let port: Int32

    public init(system: String, host: String, port: Int32) {
        this.system = system
        this.host = host
        this.port = port
    }

    public init(system: String, path: String) {
        this.system = system
        this.host = ""
        this.port = 0
    }

    public func toString(): String {
        if (host.size > 0) {
            "cactor://${host}:${port}/${system}"
        } else {
            "cactor://${system}"
        }
    }

    public func equals(other: ActorAddress): Bool {
        system == other.system && host == other.host && port == other.port
    }
}

/**
 * Props - Actor创建配置
 * 对标 Akka Props
 *
 * Akka Props 是不可变的配置对象，用于创建Actor实例
 * 支持配置调度器、邮箱、监督策略等
 */
public struct Props<T> where T <: Actor {
    private let factory: ActorFactory<T>
    private let dispatcher: DispatcherSelector
    private let mailbox: MailboxSelector
    private let supervision: SupervisorStrategy

    public init(factory: ActorFactory<T>) {
        this.factory = factory
        this.dispatcher = DispatcherSelector.defaultDispatcher()
        this.mailbox = MailboxSelector.defaultMailbox()
        this.supervision = DefaultSupervisorStrategy(3, Duration.second * 60)
    }

    private init(
        factory: ActorFactory<T>,
        dispatcher: DispatcherSelector,
        mailbox: MailboxSelector,
        supervision: SupervisorStrategy
    ) {
        this.factory = factory
        this.dispatcher = dispatcher
        this.mailbox = mailbox
        this.supervision = supervision
    }

    // 配置调度器
    public func withDispatcher(dispatcher: DispatcherSelector): Props<T> {
        Props<T>(factory, dispatcher, mailbox, supervision)
    }

    // 配置邮箱
    public func withMailbox(mailbox: MailboxSelector): Props<T> {
        Props<T>(factory, this.dispatcher, mailbox, supervision)
    }

    // 配置监督策略
    public func withSupervisorStrategy(strategy: SupervisorStrategy): Props<T> {
        Props<T>(factory, dispatcher, this.mailbox, strategy)
    }

    // 创建Actor实例
    public func create(): T {
        factory.create()
    }

    // 获取配置
    public func getDispatcher(): DispatcherSelector {
        dispatcher
    }

    public func getDispatcherName(): String {
        match (dispatcher) {
            case DefaultDispatcher => "default"
            case FromConfig(path) => path
            case PinnedDispatcher => "pinned"
            case CallingThreadDispatcher => "calling-thread"
        }
    }

    public func getMailbox(): MailboxSelector {
        mailbox
    }

    public func getSupervisorStrategy(): SupervisorStrategy {
        supervision
    }
}

/**
 * 调度器选择器
 * 对标 Akka DispatcherSelector
 */
public enum DispatcherSelector {
    | DefaultDispatcher
    | FromConfig(String)
    | PinnedDispatcher
    | CallingThreadDispatcher

    public static func defaultDispatcher(): DispatcherSelector {
        DefaultDispatcher
    }

    public static func fromConfig(path: String): DispatcherSelector {
        FromConfig(path)
    }
}

/**
 * 邮箱选择器
 * 对标 Akka MailboxSelector
 */
public enum MailboxSelector {
    | DefaultMailbox
    | Bounded(Int64, Duration)
    | Unbounded
    | Priority(String)
    | FromConfig(String)

    public static func defaultMailbox(): MailboxSelector {
        DefaultMailbox
    }

    public static func bounded(capacity: Int64): MailboxSelector {
        Bounded(capacity, Duration.second * 5)
    }
}

/**
 * 监督策略
 * 对标 Akka SupervisorStrategy
 */
public interface SupervisorStrategy {
    func decide(failure: ActorFailure): SupervisionDirective
}

public enum SupervisionDirective {
    | Resume      // 恢复Actor
    | Restart     // 重启Actor
    | Stop        // 停止Actor
    | Escalate    // 上报父监督者
}

public struct ActorFailure {
    public let actor: ActorRef
    public let cause: Exception
    public let timestamp: Int64

    public init(actor: ActorRef, cause: Exception, timestamp: Int64) {
        this.actor = actor
        this.cause = cause
        this.timestamp = timestamp
    }
}

/**
 * 默认监督策略
 */
public class DefaultSupervisorStrategy <: SupervisorStrategy {
    private let maxRetries: Int32
    private let withinTimeRange: Duration

    public init(maxRetries: Int32, withinTimeRange: Duration) {
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
    }

    public func decide(failure: ActorFailure): SupervisionDirective {
        // 默认策略：重启Actor
        SupervisionDirective.Restart
    }
}

/**
 * Props工厂方法
 * 对标 Akka Props.apply()
 */
public struct PropsFactory {
    /**
     * 创建Props
     */
    public static func create<T>(creator: () -> T): Props<T> where T <: Actor {
        Props<T>(SimpleActorFactory<T>(creator))
    }

    /**
     * 创建带调度器的Props
     */
    public static func createWithDispatcher<T>(creator: () -> T, dispatcher: String): Props<T> where T <: Actor {
        Props<T>(SimpleActorFactory<T>(creator)).withDispatcher(DispatcherSelector.fromConfig(dispatcher))
    }

    /**
     * 创建带邮箱的Props
     */
    public static func createWithMailbox<T>(creator: () -> T, mailbox: MailboxSelector): Props<T> where T <: Actor {
        Props<T>(SimpleActorFactory<T>(creator)).withMailbox(mailbox)
    }
}
