/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Actor核心包
 * 包含Actor接口、ActorRef和相关类型定义
 */
package cactor.core.actor

import std.time.*
import cactor.core.message.{Message, Envelope}

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
 * Actor引用接口
 * 提供与Actor交互的统一接口
 */
public interface ActorRef {
    /**
     * Actor的路径
     */
    prop path: ActorPath

    /**
     * 发送消息给Actor (tell模式)
     * 这是异步的，不等待响应
     * @param message 要发送的消息
     */
    func tell(message: Message): Unit

    /**
     * 发送消息给Actor，指定发送者 (tell模式)
     * @param message 要发送的消息
     * @param sender 发送者的路径
     */
    func tell(message: Message, sender: Option<String>): Unit

    /**
     * 比较两个ActorRef是否相等
     * @param other 另一个ActorRef
     * @return 是否相等
     */
    func equals(other: ActorRef): Bool

    /**
     * 获取哈希码
     * @return 哈希码
     */
    func hashCode(): Int32
}

/**
 * 本地Actor引用接口
 * 表示在同一进程中的Actor
 */
public interface LocalActorRef <: ActorRef {
    /**
     * 获取底层的Actor实例
     * @return Actor实例
     */
    func getActor(): Actor

    /**
     * 暂停Actor的消息处理
     */
    func suspend(): Unit

    /**
     * 恢复Actor的消息处理
     */
    func resume(): Unit

    /**
     * 重启Actor
     * @param cause 重启原因
     */
    func restart(cause: Exception): Unit

    /**
     * 停止Actor
     */
    func stop(): Unit

    /**
     * 获取Actor当前状态
     * @return Actor状态
     */
    func getState(): ActorLifecycleState
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
