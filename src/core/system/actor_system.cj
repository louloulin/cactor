/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor系统接口
 * 管理整个Actor系统的生命周期和配置
 */
package cactor.core.system

import std.time.*
import std.sync.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message}
import cactor.pattern.ask.{AskFuture}


/**
 * 简化的Actor系统接口
 * 管理整个Actor系统的生命周期和配置
 */
public interface ActorSystem {
    /**
     * 系统名称
     */
    prop name: String

    /**
     * 创建Actor - 类似Akka的actorOf方法
     * @param props Actor属性配置
     * @param name Actor名称
     * @return Actor引用
     */
    func actorOf(props: Props<Actor>, name: String): ActorRef

    /**
     * 创建Actor - 自动生成名称
     * @param props Actor属性配置
     * @return Actor引用
     */
    func actorOf(props: Props<Actor>): ActorRef

    /**
     * Actor选择 - 根据路径查找Actor
     * @param path Actor路径
     * @return Actor选择器
     */
    func actorSelection(path: String): ActorSelection

    /**
     * 终止Actor系统
     * 这将停止所有Actor并释放资源
     */
    func terminate(): Unit
}

/**
 * Actor选择器接口
 * 用于根据路径查找和操作Actor
 */
public interface ActorSelection {
    /**
     * 解析为单个ActorRef
     * @return AskFuture包装的ActorRef
     */
    func resolveOne(): AskFuture<ActorRef>

    /**
     * 向选中的Actor发送消息
     * @param message 要发送的消息
     */
    func tell(message: Message): Unit

    /**
     * Ask模式发送消息
     * @param message 要发送的消息
     * @return AskFuture包装的响应
     */
    func ask(message: Message): AskFuture<Message>
}

/**
 * 简化的调度器接口
 * 提供定时任务调度功能
 */
public interface Scheduler {
    /**
     * 停止调度器
     */
    func shutdown(): Unit
}

/**
 * 可取消的任务接口
 */
public interface Cancellable {
    /**
     * 取消任务
     * @return 是否成功取消
     */
    func cancel(): Bool

    /**
     * 检查任务是否已取消
     * @return 是否已取消
     */
    func isCancelled(): Bool
}

/**
 * 简化的Cancellable实现
 */
public class SimpleCancellable <: Cancellable {
    private let cancelled: AtomicBool

    public init() {
        this.cancelled = AtomicBool(false)
    }

    public func cancel(): Bool {
        cancelled.compareAndSwap(false, true)
    }

    public func isCancelled(): Bool {
        cancelled.load()
    }
}
