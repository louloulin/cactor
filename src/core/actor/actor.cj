/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 核心Actor接口
 * 基于仓颉语言特性的高性能Actor系统
 */
package cactor.core.actor

import std.time.*
import cactor.core.message.*
import cactor.core.context.*

/**
 * Actor生命周期状态
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
}

/**
 * Actor基础接口
 * 定义Actor的核心行为和生命周期
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
     * @param message 接收到的消息
     * @param context Actor上下文
     * @return 消息处理结果
     */
    func receive(message: Message, context: ActorContext): MessageResult

    /**
     * Actor启动前的初始化操作
     * 在Actor开始处理消息之前调用
     */
    func preStart(): Unit {
        // 默认空实现
    }

    /**
     * Actor启动后的操作
     * 在Actor开始处理消息后调用
     */
    func postStart(): Unit {
        // 默认空实现
    }

    /**
     * Actor停止前的清理操作
     * 在Actor停止处理消息前调用
     */
    func preStop(): Unit {
        // 默认空实现
    }

    /**
     * Actor停止后的清理操作
     * 在Actor完全停止后调用
     */
    func postStop(): Unit {
        // 默认空实现
    }

    /**
     * Actor重启前的操作
     * 当Actor因异常需要重启时调用
     */
    func preRestart(reason: Exception): Unit {
        preStop()
    }

    /**
     * Actor重启后的操作
     * 当Actor重启完成后调用
     */
    func postRestart(reason: Exception): Unit {
        postStart()
    }
}



/**
 * Actor路径
 * 唯一标识Actor在系统中的位置
 */
public struct ActorPath {
    private let system: String
    private let path: String

    public init(system: String, path: String) {
        this.system = system
        this.path = path
    }

    public func getSystem(): String {
        system
    }

    public func getPath(): String {
        path
    }

    public func toString(): String {
        "cactor://${system}${path}"
    }

    public func parent(): Option<ActorPath> {
        // 简化实现，暂时返回None
        // 实际实现需要字符串处理功能
        None
    }

    public func child(name: String): ActorPath {
        ActorPath(system, "${path}/${name}")
    }

    public func equals(other: ActorPath): Bool {
        system == other.system && path == other.path
    }

    public func hashCode(): Int32 {
        // 简化的哈希计算，截取低32位
        Int32(system.hashCode() & 0x7FFFFFFF)
    }
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
 * Props - Actor创建配置
 * 参考Akka的Props设计
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

    private init(factory: ActorFactory<T>, dispatcher: String, mailboxType: String, supervisionStrategy: String) {
        this.factory = factory
        this.dispatcher = dispatcher
        this.mailboxType = mailboxType
        this.supervisionStrategy = supervisionStrategy
    }

    public func withDispatcher(dispatcher: String): Props<T> {
        Props<T>(factory, dispatcher, mailboxType, supervisionStrategy)
    }

    public func withMailbox(mailboxType: String): Props<T> {
        Props<T>(factory, this.dispatcher, mailboxType, supervisionStrategy)
    }

    public func withSupervisionStrategy(strategy: String): Props<T> {
        Props<T>(factory, dispatcher, mailboxType, strategy)
    }

    public func create(): T {
        factory.create()
    }

    public func getDispatcher(): String {
        dispatcher
    }

    public func getMailboxType(): String {
        mailboxType
    }

    public func getSupervisionStrategy(): String {
        supervisionStrategy
    }
}

/**
 * Props工厂方法
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
        Props<T>(SimpleActorFactory<T>(creator)).withDispatcher(dispatcher)
    }
}
