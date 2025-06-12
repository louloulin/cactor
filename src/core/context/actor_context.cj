/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Actor上下文
 * 提供Actor运行时的环境和服务
 */
package cactor.core.context

import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorSelection, Props}
import cactor.core.message.{Message, MessageResult}

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
     * @return 发送者的路径，如果没有则为None
     */
    func sender(): Option<String>

    /**
     * 获取Actor系统引用
     * @return ActorSystem实例
     */
    func system(): ActorSystem

    /**
     * 获取父Actor引用
     * @return 父Actor的ActorRef
     */
    func parent(): Option<ActorRef>

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
