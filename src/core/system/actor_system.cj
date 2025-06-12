/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Actor系统接口
 * 管理整个Actor系统的生命周期和配置
 */
package cactor.core.system

import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorSelection, Props, Future}
import cactor.core.message.Message
import cactor.core.context.{Cancellable}

/**
 * Actor系统接口
 * 管理整个Actor系统的生命周期和配置
 */
public interface ActorSystem {
    /**
     * 系统名称
     */
    prop name: String

    /**
     * 创建顶级Actor
     * @param props Actor创建属性
     * @param name Actor名称
     * @return Actor引用
     */
    func actorOf<T>(props: Props<T>, name: String): ActorRef where T <: Actor

    /**
     * 选择Actor
     * @param path Actor路径
     * @return ActorSelection实例
     */
    func actorSelection(path: String): ActorSelection

    /**
     * 停止指定的Actor
     * @param actor 要停止的Actor引用
     */
    func stop(actor: ActorRef): Unit

    /**
     * 终止Actor系统
     * 这将停止所有Actor并释放资源
     */
    func terminate(): Unit

    /**
     * 等待系统终止完成
     * @return Future，在系统完全终止时完成
     */
    func whenTerminated(): Future<Unit>

    /**
     * 获取调度器
     * @return 调度器实例
     */
    func scheduler(): Scheduler

    /**
     * 获取死信处理器
     * @return 死信Actor引用
     */
    func deadLetters(): ActorRef
}

/**
 * 调度器接口
 * 提供定时任务调度功能
 */
public interface Scheduler {
    /**
     * 调度周期性任务
     * @param initialDelay 初始延迟
     * @param interval 间隔时间
     * @param receiver 接收消息的Actor
     * @param message 要发送的消息
     * @return 可取消的任务
     */
    func schedule(initialDelay: Duration, interval: Duration, receiver: ActorRef, message: Message): Cancellable

    /**
     * 调度一次性任务
     * @param delay 延迟时间
     * @param receiver 接收消息的Actor
     * @param message 要发送的消息
     * @return 可取消的任务
     */
    func scheduleOnce(delay: Duration, receiver: ActorRef, message: Message): Cancellable
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
