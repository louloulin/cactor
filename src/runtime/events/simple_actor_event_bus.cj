/*
 * Copyright (c) 2024. All rights reserved.
 * SimpleActorEventBus - 简化的Actor事件总线
 * 基于plan10.md设计，提供基本的事件发布和订阅功能
 */
package cactor.runtime.events

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef}

/**
 * 简化的Actor生命周期事件
 */
public struct SimpleActorLifecycleEvent {
    public let actorRef: ActorRef
    public let timestamp: Int64
    public let eventType: String
    public let message: String
    
    public init(actorRef: ActorRef, eventType: String, message: String) {
        this.actorRef = actorRef
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
        this.eventType = eventType
        this.message = message
    }
}

/**
 * 事件监听器接口
 */
public interface SimpleEventListener {
    func onEvent(event: SimpleActorLifecycleEvent): Unit
}

/**
 * 简化的Actor事件总线
 * 
 * 职责：
 * 1. 发布Actor生命周期事件
 * 2. 管理事件订阅者
 * 3. 提供基本的事件统计
 */
public class SimpleActorEventBus {
    private let listeners: Array<SimpleEventListener>
    private let eventCount: AtomicInt64
    private let isRunning: AtomicBool
    
    public init() {
        this.listeners = Array<SimpleEventListener>()
        this.eventCount = AtomicInt64(0)
        this.isRunning = AtomicBool(true)
    }
    
    /**
     * 发布事件
     */
    public func publish(event: SimpleActorLifecycleEvent): Unit {
        if (!isRunning.load()) {
            return
        }
        
        eventCount.fetchAdd(1)
        
        // 通知所有监听器
        for (listener in listeners) {
            try {
                listener.onEvent(event)
            } catch (e: Exception) {
                // 忽略监听器错误，避免影响系统运行
                println("事件监听器错误: ${e.message}")
            }
        }
    }
    
    /**
     * 添加事件监听器
     */
    public func subscribe(listener: SimpleEventListener): Unit {
        listeners.append(listener)
    }
    
    /**
     * 移除事件监听器
     */
    public func unsubscribe(listener: SimpleEventListener): Unit {
        // 简化实现：创建新数组排除指定监听器
        let newListeners = Array<SimpleEventListener>()
        for (l in listeners) {
            if (l != listener) {
                newListeners.append(l)
            }
        }
        listeners.clear()
        for (l in newListeners) {
            listeners.append(l)
        }
    }
    
    /**
     * 获取事件总数
     */
    public func getEventCount(): Int64 {
        eventCount.load()
    }
    
    /**
     * 获取订阅者数量
     */
    public func getSubscriberCount(): Int32 {
        Int32(listeners.size())
    }
    
    /**
     * 检查是否有订阅者
     */
    public func hasSubscribers(): Bool {
        listeners.size() > 0
    }
    
    /**
     * 停止事件总线
     */
    public func stop(): Unit {
        isRunning.store(false)
    }
    
    /**
     * 启动事件总线
     */
    public func start(): Unit {
        isRunning.store(true)
    }
    
    /**
     * 检查是否正在运行
     */
    public func isActive(): Bool {
        isRunning.load()
    }

    /**
     * 发布Actor创建事件 - Plan10.md要求
     */
    public func publishActorCreated(actorRef: ActorRef): Unit {
        let event = SimpleActorLifecycleEvent(actorRef, "CREATED", "Actor已创建")
        publish(event)
    }

    /**
     * 发布Actor停止事件 - Plan10.md要求
     */
    public func publishActorStopped(actorRef: ActorRef): Unit {
        let event = SimpleActorLifecycleEvent(actorRef, "STOPPED", "Actor已停止")
        publish(event)
    }

    /**
     * 发布Actor重启事件 - Plan10.md要求
     */
    public func publishActorRestarted(actorRef: ActorRef, reason: Exception): Unit {
        let event = SimpleActorLifecycleEvent(actorRef, "RESTARTED", "Actor已重启: ${reason.message}")
        publish(event)
    }

    /**
     * 关闭事件总线 - Plan10.md要求
     */
    public func shutdown(): Unit {
        stop()
    }
    
    /**
     * 清空所有监听器
     */
    public func clear(): Unit {
        listeners.clear()
    }
    
    /**
     * 打印事件总线统计信息
     */
    public func printStats(): Unit {
        println("=== SimpleActorEventBus统计信息 ===")
        println("事件总数: ${getEventCount()}")
        println("订阅者数量: ${getSubscriberCount()}")
        println("运行状态: ${if (isActive()) { "运行中" } else { "已停止" }}")
    }
}

/**
 * 便利方法：创建Actor启动事件
 */
public func createActorStartedEvent(actorRef: ActorRef): SimpleActorLifecycleEvent {
    SimpleActorLifecycleEvent(actorRef, "STARTED", "Actor已启动")
}

/**
 * 便利方法：创建Actor停止事件
 */
public func createActorStoppedEvent(actorRef: ActorRef): SimpleActorLifecycleEvent {
    SimpleActorLifecycleEvent(actorRef, "STOPPED", "Actor已停止")
}

/**
 * 便利方法：创建Actor重启事件
 */
public func createActorRestartedEvent(actorRef: ActorRef): SimpleActorLifecycleEvent {
    SimpleActorLifecycleEvent(actorRef, "RESTARTED", "Actor已重启")
}

/**
 * 便利方法：创建Actor注册事件
 */
public func createActorRegisteredEvent(actorRef: ActorRef): SimpleActorLifecycleEvent {
    SimpleActorLifecycleEvent(actorRef, "REGISTERED", "Actor已注册")
}

/**
 * 便利方法：创建Actor注销事件
 */
public func createActorUnregisteredEvent(actorRef: ActorRef): SimpleActorLifecycleEvent {
    SimpleActorLifecycleEvent(actorRef, "UNREGISTERED", "Actor已注销")
}

/**
 * 便利方法：创建Actor失败事件
 */
public func createActorFailedEvent(actorRef: ActorRef, error: String): SimpleActorLifecycleEvent {
    SimpleActorLifecycleEvent(actorRef, "FAILED", "Actor失败: ${error}")
}

/**
 * 简单的控制台事件监听器
 */
public class ConsoleEventListener <: SimpleEventListener {
    private let prefix: String
    
    public init(prefix: String) {
        this.prefix = prefix
    }
    
    public func onEvent(event: SimpleActorLifecycleEvent): Unit {
        let timeStr = DateTime.fromUnixTimeStamp(UnixTimeStamp.fromMilliseconds(event.timestamp / 1000000)).toString()
        println("${prefix} ${timeStr} ${event.eventType}: ${event.actorRef.path.toString()} - ${event.message}")
    }
}

/**
 * 统计事件监听器
 */
public class StatsEventListener <: SimpleEventListener {
    private let eventCounts: HashMap<String, AtomicInt32>
    
    public init() {
        this.eventCounts = HashMap<String, AtomicInt32>()
    }
    
    public func onEvent(event: SimpleActorLifecycleEvent): Unit {
        match (eventCounts.get(event.eventType)) {
            case Some(counter) =>
                counter.fetchAdd(1)
            case None =>
                let newCounter = AtomicInt32(1)
                eventCounts.put(event.eventType, newCounter)
        }
    }
    
    public func getEventCount(eventType: String): Int32 {
        match (eventCounts.get(eventType)) {
            case Some(counter) =>
                counter.load()
            case None =>
                0
        }
    }
    
    public func printStats(): Unit {
        println("=== 事件统计 ===")
        for ((eventType, counter) in eventCounts) {
            println("${eventType}: ${counter.load()}")
        }
    }
}
