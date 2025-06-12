/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - Actor系统定义
 */
package cactor.core.system

import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorSelection}
import cactor.core.context.Props
import cactor.core.message.Message

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
     * 获取事件流
     * @return 事件流实例
     */
    func eventStream(): EventStream

    /**
     * 获取死信处理器
     * @return 死信Actor引用
     */
    func deadLetters(): ActorRef

    /**
     * 获取系统配置
     * @return 配置实例
     */
    func settings(): ActorSystemSettings
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

    /**
     * 调度周期性任务（使用Runnable）
     * @param initialDelay 初始延迟
     * @param interval 间隔时间
     * @param runnable 要执行的任务
     * @return 可取消的任务
     */
    func scheduleWithFixedDelay(initialDelay: Duration, interval: Duration, runnable: () -> Unit): Cancellable
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
 * 事件流接口
 * 提供发布-订阅功能
 */
public interface EventStream {
    /**
     * 订阅事件
     * @param subscriber 订阅者Actor
     * @param eventType 事件类型
     */
    func subscribe(subscriber: ActorRef, eventType: String): Unit

    /**
     * 取消订阅
     * @param subscriber 订阅者Actor
     * @param eventType 事件类型
     */
    func unsubscribe(subscriber: ActorRef, eventType: String): Unit

    /**
     * 发布事件
     * @param event 要发布的事件
     */
    func publish(event: Message): Unit
}

/**
 * Actor系统设置
 * 包含系统配置参数
 */
public interface ActorSystemSettings {
    /**
     * 获取配置值
     * @param key 配置键
     * @return 配置值
     */
    func getString(key: String): Option<String>

    /**
     * 获取整数配置值
     * @param key 配置键
     * @return 配置值
     */
    func getInt(key: String): Option<Int32>

    /**
     * 获取布尔配置值
     * @param key 配置键
     * @return 配置值
     */
    func getBool(key: String): Option<Bool>

    /**
     * 获取时间配置值
     * @param key 配置键
     * @return 配置值
     */
    func getDuration(key: String): Option<Duration>
}

/**
 * 扩展接口
 * 用于扩展Actor系统功能
 */
public interface Extension {
    /**
     * 扩展ID
     */
    prop extensionId: String
}

/**
 * 扩展ID接口
 * 用于标识扩展
 */
public interface ExtensionId<T> where T <: Extension {
    /**
     * 创建扩展实例
     * @param system Actor系统
     * @return 扩展实例
     */
    func createExtension(system: ActorSystem): T
}

/**
 * 可扩展的Actor系统接口
 */
public interface ExtendedActorSystem <: ActorSystem {
    /**
     * 注册扩展
     * @param extensionId 扩展ID
     * @return 扩展实例
     */
    func registerExtension<T>(extensionId: ExtensionId<T>): T where T <: Extension

    /**
     * 获取扩展
     * @param extensionId 扩展ID
     * @return 扩展实例
     */
    func extension<T>(extensionId: ExtensionId<T>): T where T <: Extension

    /**
     * 检查是否有扩展
     * @param extensionId 扩展ID
     * @return 是否存在
     */
    func hasExtension<T>(extensionId: ExtensionId<T>): Bool where T <: Extension
}
