/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - Actor核心接口定义
 */
package cactor.core.actor

import cactor.core.context.ActorContext
import cactor.core.message.Message

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
 * 类型化Actor接口
 * 处理特定类型消息的Actor
 */
public interface TypedActor<M> <: Actor where M <: Message {
    /**
     * 处理接收到的消息
     * @param message 接收到的消息
     * @param context Actor上下文
     * @return 消息处理结果
     */
    func receive(message: M, context: ActorContext): MessageResult
}

/**
 * 无类型Actor接口
 * 可以处理任意类型消息的Actor
 */
public interface UntypedActor <: Actor {
    /**
     * 处理接收到的消息
     * @param message 接收到的消息
     * @param context Actor上下文
     * @return 消息处理结果
     */
    func receive(message: Message, context: ActorContext): MessageResult
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
 * Actor行为接口
 * 定义可切换的消息处理行为
 */
public interface Behavior<M> where M <: Message {
    /**
     * 应用行为处理消息
     * @param message 接收到的消息
     * @param context Actor上下文
     * @return 行为处理结果
     */
    func apply(message: M, context: ActorContext): BehaviorResult<M>
}

/**
 * 行为处理结果枚举
 */
public enum BehaviorResult<M> where M <: Message {
    | Same                    // 保持当前行为
    | Become(Behavior<M>)     // 切换到新行为
    | Stop                    // 停止Actor
    | Restart                 // 重启Actor
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
 * Actor生命周期状态枚举
 */
public enum ActorState {
    | Created        // 已创建，未启动
    | Starting       // 启动中
    | Running        // 运行中
    | Stopping       // 停止中
    | Stopped        // 已停止
    | Failed         // 失败状态
    | Restarting     // 重启中
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
        let lastSlash = path.lastIndexOf("/")
        if (lastSlash > 0) {
            Some(ActorPath(system, path.substring(0, lastSlash)))
        } else {
            None
        }
    }

    public func child(name: String): ActorPath {
        ActorPath(system, "${path}/${name}")
    }

    public func equals(other: ActorPath): Bool {
        system == other.system && path == other.path
    }

    public func hashCode(): Int32 {
        system.hashCode() ^ path.hashCode()
    }
}
