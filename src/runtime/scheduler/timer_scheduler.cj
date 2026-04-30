/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 定时器调度器
 * 对标 Akka Scheduler - 提供定时任务调度
 */
package cactor.runtime.scheduler

import std.time.*
import std.collection.*
import cactor.core.actor.*
import cactor.core.message.*

/**
 * 定时任务接口
 * 对标 Akka TimerScheduler
 */
public interface TimerScheduler {
    /**
     * 启动一个定时一次性任务
     * @param key 任务唯一标识
     * @param msg 到期时发送的消息
     * @param interval 延迟时间
     */
    func startSingleTimer(key: String, msg: Message, interval: Duration): Unit

    /**
     * 启动一个定时重复任务
     * @param key 任务唯一标识
     * @param msg 每次到期时发送的消息
     * @param interval 重复间隔
     */
    func startPeriodicTimer(key: String, msg: Message, interval: Duration): Unit

    /**
     * 取消定时任务
     * @param key 任务标识
     * @return 是否取消成功
     */
    func cancelTimer(key: String): Bool

    /**
     * 取消所有定时任务
     */
    func cancelAll(): Unit

    /**
     * 检查任务是否存在
     * @param key 任务标识
     */
    func isTimerActive(key: String): Bool
}

/**
 * 定时任务项
 */
public class TimerTask {
    public let key: String
    public let msg: Message
    public let intervalMs: Int64
    public let isPeriodic: Bool
    public let nextExecutionTime: Int64  // 使用毫秒时间戳

    public init(key: String, msg: Message, intervalMs: Int64, isPeriodic: Bool, startTimeMs: Int64) {
        this.key = key
        this.msg = msg
        this.intervalMs = intervalMs
        this.isPeriodic = isPeriodic
        this.nextExecutionTime = startTimeMs + intervalMs
    }
}

/**
 * 定时器Actor - 内部使用
 */
public class TimerActor <: Actor {
    private let actorName: String
    private var timers: HashMap<String, TimerTask>
    private var lastTickTime: Int64
    private let tickInterval: Duration
    private var isRunning: Bool

    public init(name: String, tickInterval: Duration) {
        this.actorName = name
        this.timers = HashMap<String, TimerTask>()
        this.lastTickTime = getCurrentTimeMs()
        this.tickInterval = tickInterval
        this.isRunning = true
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Timer actor: ${actorName}" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case tick: TimerTick =>
                processTick()
                MessageResult.Handled
            case startSingle: StartSingleTimer =>
                addTimer(startSingle.key, startSingle.msg, startSingle.interval, false)
                MessageResult.Handled
            case startPeriodic: StartPeriodicTimer =>
                addTimer(startPeriodic.key, startPeriodic.msg, startPeriodic.interval, true)
                MessageResult.Handled
            case cancel: CancelTimer =>
                let removed = timers.remove(cancel.key)
                MessageResult.Handled
            case cancelAll: CancelAllTimers =>
                timers.clear()
                MessageResult.Handled
            case isActive: IsTimerActive =>
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }

    private func processTick(): Unit {
        let currentMs = getCurrentTimeMs()
        let expiredKeys = ArrayList<String>()

        for ((key, task) in timers) {
            if (currentMs >= task.nextExecutionTime) {
                expiredKeys.add(key)
            }
        }

        // 处理到期的任务
        for (key in expiredKeys) {
            match (timers.get(key)) {
                case Some(task) =>
                    // 通知定时器到期
                    if (task.isPeriodic) {
                        // 更新下次执行时间
                        let newTask = TimerTask(
                            task.key,
                            task.msg,
                            task.intervalMs,
                            task.isPeriodic,
                            currentMs
                        )
                        timers.add(key, newTask)
                    } else {
                        // 单次任务完成后移除
                        timers.remove(key)
                    }
                case None => ()
            }
        }
    }

    private func addTimer(key: String, msg: Message, interval: Duration, isPeriodic: Bool): Unit {
        let currentMs = getCurrentTimeMs()
        let intervalMs = interval.toMilliseconds()
        let task = TimerTask(key, msg, intervalMs, isPeriodic, currentMs)
        timers.add(key, task)
    }
}

/**
 * 获取当前时间（毫秒）
 */
public func getCurrentTimeMs(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

/**
 * TimerTick 消息 - 内部使用
 */
public class TimerTick <: Message {
    public init() {}

    public func getType(): String { "TimerTick" }
    public func getPayload(): String { "TimerTick()" }
    public func messageType(): String { "TimerTick" }
}

/**
 * 启动单次定时器消息
 */
public class StartSingleTimer <: Message {
    public let key: String
    public let msg: Message
    public let interval: Duration

    public init(key: String, msg: Message, interval: Duration) {
        this.key = key
        this.msg = msg
        this.interval = interval
    }

    public func getType(): String { "StartSingleTimer" }
    public func getPayload(): String { "StartSingleTimer(${key})" }
    public func messageType(): String { "StartSingleTimer" }
}

/**
 * 启动周期定时器消息
 */
public class StartPeriodicTimer <: Message {
    public let key: String
    public let msg: Message
    public let interval: Duration

    public init(key: String, msg: Message, interval: Duration) {
        this.key = key
        this.msg = msg
        this.interval = interval
    }

    public func getType(): String { "StartPeriodicTimer" }
    public func getPayload(): String { "StartPeriodicTimer(${key})" }
    public func messageType(): String { "StartPeriodicTimer" }
}

/**
 * 取消定时器消息
 */
public class CancelTimer <: Message {
    public let key: String

    public init(key: String) {
        this.key = key
    }

    public func getType(): String { "CancelTimer" }
    public func getPayload(): String { "CancelTimer(${key})" }
    public func messageType(): String { "CancelTimer" }
}

/**
 * 取消所有定时器消息
 */
public class CancelAllTimers <: Message {
    public init() {}

    public func getType(): String { "CancelAllTimers" }
    public func getPayload(): String { "CancelAllTimers()" }
    public func messageType(): String { "CancelAllTimers" }
}

/**
 * 查询定时器状态消息
 */
public class IsTimerActive <: Message {
    public let key: String

    public init(key: String) {
        this.key = key
    }

    public func getType(): String { "IsTimerActive" }
    public func getPayload(): String { "IsTimerActive(${key})" }
    public func messageType(): String { "IsTimerActive" }
}

/**
 * ReceiveTimeout 消息 - 当没有收到消息超过指定时间时触发
 */
public class ReceiveTimeoutMessage <: Message {
    public init() {}

    public func getType(): String { "ReceiveTimeout" }
    public func getPayload(): String { "ReceiveTimeout()" }
    public func messageType(): String { "ReceiveTimeout" }
}

/**
 * 简化的定时器调度器实现
 * 使用内部定时器检查
 */
public class SimpleTimerScheduler <: TimerScheduler {
    private var timers: HashMap<String, TimerTask>
    private let tickInterval: Duration

    public init(tickInterval: Duration) {
        this.timers = HashMap<String, TimerTask>()
        this.tickInterval = tickInterval
    }

    public func startSingleTimer(key: String, msg: Message, interval: Duration): Unit {
        let currentMs = getCurrentTimeMs()
        let intervalMs = interval.toMilliseconds()
        let task = TimerTask(key, msg, intervalMs, false, currentMs)
        timers.add(key, task)
    }

    public func startPeriodicTimer(key: String, msg: Message, interval: Duration): Unit {
        let currentMs = getCurrentTimeMs()
        let intervalMs = interval.toMilliseconds()
        let task = TimerTask(key, msg, intervalMs, true, currentMs)
        timers.add(key, task)
    }

    public func cancelTimer(key: String): Bool {
        match (timers.remove(key)) {
            case Some(_) => true
            case None => false
        }
    }

    public func cancelAll(): Unit {
        timers.clear()
    }

    public func isTimerActive(key: String): Bool {
        timers.contains(key)
    }

    /**
     * 检查并触发到期的定时器
     * @return 到期的消息列表
     */
    public func checkAndFire(): ArrayList<Message> {
        let currentMs = getCurrentTimeMs()
        let fired = ArrayList<Message>()
        let toRemove = ArrayList<String>()

        for ((key, task) in timers) {
            if (currentMs >= task.nextExecutionTime) {
                fired.add(task.msg)
                if (task.isPeriodic) {
                    // 更新下次执行时间
                    let newTask = TimerTask(
                        task.key,
                        task.msg,
                        task.intervalMs,
                        task.isPeriodic,
                        currentMs
                    )
                    timers.add(key, newTask)
                } else {
                    toRemove.add(key)
                }
            }
        }

        for (key in toRemove) {
            timers.remove(key)
        }

        fired
    }
}
