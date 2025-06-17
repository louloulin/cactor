/*
 * Copyright (c) 2024. All rights reserved.
 * ActorEventBus - Actor事件总线
 * 基于plan10.md设计，提供高性能的事件发布和订阅服务
 */
package cactor.runtime.events

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef}

/**
 * Actor生命周期事件基类
 */
public interface ActorLifecycleEvent {
    prop actorRef: ActorRef
    prop timestamp: Int64
    prop eventType: String
}

/**
 * Actor创建事件
 */
public struct ActorCreatedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    
    public init(actorRef: ActorRef, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
    }
    
    public prop eventType: String {
        get() { "ActorCreated" }
    }
}

/**
 * Actor启动事件
 */
public struct ActorStartedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    
    public init(actorRef: ActorRef, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
    }
    
    public prop eventType: String {
        get() { "ActorStarted" }
    }
}

/**
 * Actor停止事件
 */
public struct ActorStoppedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    
    public init(actorRef: ActorRef, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
    }
    
    public prop eventType: String {
        get() { "ActorStopped" }
    }
}

/**
 * Actor重启事件
 */
public struct ActorRestartedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    public let reason: Exception
    
    public init(actorRef: ActorRef, reason: Exception, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
        this.reason = reason
    }
    
    public prop eventType: String {
        get() { "ActorRestarted" }
    }
}

/**
 * Actor注册事件
 */
public struct ActorRegisteredEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    
    public init(actorRef: ActorRef, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
    }
    
    public prop eventType: String {
        get() { "ActorRegistered" }
    }
}

/**
 * Actor注销事件
 */
public struct ActorUnregisteredEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    
    public init(actorRef: ActorRef, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
    }
    
    public prop eventType: String {
        get() { "ActorUnregistered" }
    }
}

/**
 * Actor启动失败事件
 */
public struct ActorStartFailedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    public let error: Exception
    
    public init(actorRef: ActorRef, error: Exception, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
        this.error = error
    }
    
    public prop eventType: String {
        get() { "ActorStartFailed" }
    }
}

/**
 * Actor停止失败事件
 */
public struct ActorStopFailedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    public let error: Exception
    
    public init(actorRef: ActorRef, error: Exception, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
        this.error = error
    }
    
    public prop eventType: String {
        get() { "ActorStopFailed" }
    }
}

/**
 * Actor重启失败事件
 */
public struct ActorRestartFailedEvent <: ActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    public let error: Exception
    
    public init(actorRef: ActorRef, error: Exception, timestamp: Int64) {
        this.actorRef = actorRef
        this.timestamp = timestamp
        this.error = error
    }
    
    public prop eventType: String {
        get() { "ActorRestartFailed" }
    }
}

/**
 * 事件监听器接口
 */
public interface ActorEventListener {
    func onEvent(event: ActorLifecycleEvent): Unit
}

/**
 * 事件订阅信息
 */
public struct EventSubscription {
    public let listener: ActorEventListener
    public let eventTypes: HashSet<String>
    public let subscribedAt: Int64
    
    public init(listener: ActorEventListener, eventTypes: HashSet<String>) {
        this.listener = listener
        this.eventTypes = eventTypes
        this.subscribedAt = getCurrentTimeNanos()
    }
    
    public func matches(eventType: String): Bool {
        eventTypes.isEmpty() || eventTypes.contains(eventType)
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }
}

/**
 * Actor事件总线
 * 
 * 职责：
 * 1. 提供高性能的事件发布和订阅服务
 * 2. 支持事件类型过滤
 * 3. 异步事件处理
 * 4. 事件统计和监控
 */
public class ActorEventBus {
    private let subscribers: Array<EventSubscription>
    private let eventCount: AtomicInt64
    private let subscriberCount: AtomicInt32
    private let isRunning: AtomicBool
    private let busLock: RwLock
    
    public init() {
        this.subscribers = Array<EventSubscription>()
        this.eventCount = AtomicInt64(0)
        this.subscriberCount = AtomicInt32(0)
        this.isRunning = AtomicBool(true)
        this.busLock = RwLock()
    }
    
    /**
     * 发布事件
     */
    public func publish(event: ActorLifecycleEvent): Unit {
        if (!isRunning.load()) {
            return
        }
        
        busLock.lockRead()
        try {
            // 遍历所有订阅者
            for (subscription in subscribers) {
                if (subscription.matches(event.eventType)) {
                    try {
                        // 异步调用监听器
                        subscription.listener.onEvent(event)
                    } catch (e: Exception) {
                        // 监听器异常不应该影响其他监听器
                        println("事件监听器异常: ${e.message}")
                    }
                }
            }
            
            // 更新事件计数
            eventCount.fetchAdd(1)
            
        } finally {
            busLock.unlockRead()
        }
    }
    
    /**
     * 订阅所有事件
     */
    public func subscribe(listener: ActorEventListener): Unit {
        let eventTypes = HashSet<String>()  // 空集合表示订阅所有事件
        subscribe(listener, eventTypes)
    }
    
    /**
     * 订阅特定类型的事件
     */
    public func subscribe(listener: ActorEventListener, eventTypes: HashSet<String>): Unit {
        busLock.lockWrite()
        try {
            let subscription = EventSubscription(listener, eventTypes)
            subscribers.append(subscription)
            subscriberCount.fetchAdd(1)
        } finally {
            busLock.unlockWrite()
        }
    }
    
    /**
     * 取消订阅
     */
    public func unsubscribe(listener: ActorEventListener): Unit {
        busLock.lockWrite()
        try {
            var i: Int64 = 0
            while (i < subscribers.size()) {
                if (subscribers[i].listener == listener) {
                    subscribers.removeAt(i)
                    subscriberCount.fetchAdd(-1)
                    break
                }
                i += 1
            }
        } finally {
            busLock.unlockWrite()
        }
    }
    
    /**
     * 获取事件统计
     */
    public func getEventCount(): Int64 {
        eventCount.load()
    }
    
    /**
     * 获取订阅者数量
     */
    public func getSubscriberCount(): Int32 {
        subscriberCount.load()
    }
    
    /**
     * 检查是否有订阅者
     */
    public func hasSubscribers(): Bool {
        subscriberCount.load() > 0
    }
    
    /**
     * 清空所有订阅者
     */
    public func clearSubscribers(): Unit {
        busLock.lockWrite()
        try {
            subscribers.clear()
            subscriberCount.store(0)
        } finally {
            busLock.unlockWrite()
        }
    }
    
    /**
     * 关闭事件总线
     */
    public func shutdown(): Unit {
        isRunning.store(false)
        clearSubscribers()
    }
    
    /**
     * 打印事件总线统计信息
     */
    public func printStats(): Unit {
        println("=== ActorEventBus统计信息 ===")
        println("事件总数: ${getEventCount()}")
        println("订阅者数量: ${getSubscriberCount()}")
        println("运行状态: ${if (isRunning.load()) { "运行中" } else { "已停止" }}")
    }
}
