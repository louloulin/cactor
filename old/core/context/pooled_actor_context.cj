/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 池化Actor上下文
 * 高性能对象池化上下文实现
 */
package cactor.core.context

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.message.*
import cactor.memory.object_pool.*

// 前向声明避免循环依赖 - 使用不同的名称
public interface ContextActorRef {
    prop path: ContextActorPath
    func tell(message: Message): Unit
    func tell(message: Message, sender: Option<String>): Unit
    func equals(other: ContextActorRef): Bool
    func hashCode(): Int32
}

public interface ContextActorPath {
    func toString(): String
}

// 简化时间函数
func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    now.toUnixTimeStamp().toMilliseconds() * 1000000
}

/**
 * 池化Actor上下文 - 简化版本
 * 可重用的上下文对象，减少内存分配
 */
public class PooledActorContext {
    // 当前Actor引用 (可重置)
    private var currentSelf: Option<ContextActorRef>

    // 当前发送者 (可重置)
    private var currentSender: Option<ContextActorRef>

    // 重置计数器
    private var resetCount: Int64

    // 池化标记
    private var isPooled: Bool

    public init() {
        this.currentSelf = None
        this.currentSender = None
        this.resetCount = 0
        this.isPooled = true
    }
    
    /**
     * 重置上下文状态 - 用于对象池重用
     */
    public func reset(): Unit {
        currentSelf = None
        currentSender = None
        resetCount += 1
    }
    
    /**
     * 设置当前Actor引用
     */
    public func setSelf(self: ContextActorRef): Unit {
        currentSelf = Some(self)
    }

    /**
     * 设置当前发送者
     */
    public func setSender(sender: Option<ContextActorRef>): Unit {
        currentSender = sender
    }
    
    /**
     * 获取当前Actor引用
     */
    public func getSelf(): ContextActorRef {
        match (currentSelf) {
            case Some(self) => self
            case None => DeadLetterContextActorRef()
        }
    }

    /**
     * 获取消息发送者
     */
    public func getSender(): Option<ContextActorRef> {
        currentSender
    }

    /**
     * 获取父Actor引用
     */
    public func getParent(): ContextActorRef {
        // 简化实现，返回系统Actor
        SystemContextActorRef()
    }
    
    /**
     * 获取上下文统计信息
     */
    public func getContextStats(): PooledContextStats {
        PooledContextStats(
            resetCount,
            0,  // childrenCount
            0,  // watchedActorsCount
            0,  // createdAt
            isPooled
        )
    }
}

/**
 * 池化上下文统计信息
 */
public struct PooledContextStats {
    public let resetCount: Int64
    public let childrenCount: Int64
    public let watchedActorsCount: Int64
    public let createdAt: Int64
    public let isPooled: Bool
    
    public init(resetCount: Int64, childrenCount: Int64, watchedActorsCount: Int64, createdAt: Int64, isPooled: Bool) {
        this.resetCount = resetCount
        this.childrenCount = childrenCount
        this.watchedActorsCount = watchedActorsCount
        this.createdAt = createdAt
        this.isPooled = isPooled
    }
    
    public func getAgeInSeconds(): Float64 {
        Float64(getCurrentTimeNanos() - createdAt) / 1000000000.0
    }
    
    public func getReuseRate(): Float64 {
        if (resetCount == 0) {
            return 0.0
        }
        return Float64(resetCount) / getAgeInSeconds()
    }
}

/**
 * 池化上下文工厂
 * 实现对象池模式
 */
public class PooledActorContextPool <: ObjectPool<PooledActorContext> {
    private let pool: Array<PooledActorContext>
    private let available: AtomicInt64
    private let capacity: Int64
    private let head: AtomicInt64
    private let tail: AtomicInt64
    private let createdCount: AtomicInt64
    private let acquiredCount: AtomicInt64
    private let releasedCount: AtomicInt64
    
    public init(capacity: Int64) {
        this.capacity = capacity
        this.pool = Array<PooledActorContext>(capacity, { i => PooledActorContext() })
        this.available = AtomicInt64(capacity)
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.createdCount = AtomicInt64(capacity)
        this.acquiredCount = AtomicInt64(0)
        this.releasedCount = AtomicInt64(0)
    }
    
    /**
     * 获取池化上下文
     */
    public func acquire(): PooledActorContext {
        acquiredCount.fetchAdd(1)
        
        if (available.load() > 0) {
            let currentHead = head.fetchAdd(1)
            let index = currentHead % capacity
            let context = pool[index]
            available.fetchAdd(-1)
            return context
        } else {
            // 池已空，创建新的上下文
            createdCount.fetchAdd(1)
            return PooledActorContext()
        }
    }
    
    /**
     * 释放池化上下文
     */
    public func release(context: PooledActorContext): Unit {
        releasedCount.fetchAdd(1)
        
        // 重置上下文状态
        context.reset()
        
        if (available.load() < capacity) {
            let currentTail = tail.fetchAdd(1)
            let index = currentTail % capacity
            pool[index] = context
            available.fetchAdd(1)
        }
        // 如果池已满，直接丢弃上下文（让GC回收）
    }
    
    /**
     * 获取池统计信息
     */
    public func getPoolStats(): PoolStats {
        PoolStats(
            capacity,
            available.load(),
            createdCount.load(),
            acquiredCount.load(),
            releasedCount.load()
        )
    }
    
    /**
     * 预热池 - 创建所有对象
     */
    public func warmup(): Unit {
        // 所有对象在初始化时已创建
        println("PooledActorContextPool 预热完成，容量: ${capacity}")
    }
}

/**
 * 对象池统计信息
 */
public struct PoolStats {
    public let capacity: Int64
    public let available: Int64
    public let createdCount: Int64
    public let acquiredCount: Int64
    public let releasedCount: Int64
    
    public init(capacity: Int64, available: Int64, createdCount: Int64, acquiredCount: Int64, releasedCount: Int64) {
        this.capacity = capacity
        this.available = available
        this.createdCount = createdCount
        this.acquiredCount = acquiredCount
        this.releasedCount = releasedCount
    }
    
    public func getUtilization(): Float64 {
        Float64(capacity - available) / Float64(capacity) * 100.0
    }
    
    public func getHitRate(): Float64 {
        if (acquiredCount == 0) {
            return 0.0
        }
        let hits = acquiredCount - (createdCount - capacity)
        return Float64(hits) / Float64(acquiredCount) * 100.0
    }
    
    public func getLeakRate(): Float64 {
        if (releasedCount == 0) {
            return 0.0
        }
        return Float64(acquiredCount - releasedCount) / Float64(acquiredCount) * 100.0
    }
}

/**
 * 简化的死信Actor引用
 */
public class DeadLetterContextActorRef <: ContextActorRef {
    public prop path: ContextActorPath {
        get() { SimpleContextActorPath("/deadLetters") }
    }

    public func tell(message: Message): Unit {
        // 死信处理
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        // 死信处理
    }

    public func equals(other: ContextActorRef): Bool {
        match (other) {
            case _: DeadLetterContextActorRef => true
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32("/deadLetters".hashCode())
    }
}

/**
 * 简化的系统Actor引用
 */
public class SystemContextActorRef <: ContextActorRef {
    public prop path: ContextActorPath {
        get() { SimpleContextActorPath("/system") }
    }

    public func tell(message: Message): Unit {
        // 系统消息处理
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        // 系统消息处理
    }

    public func equals(other: ContextActorRef): Bool {
        match (other) {
            case _: SystemContextActorRef => true
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32("/system".hashCode())
    }
}

/**
 * 简化的Actor路径实现
 */
public struct SimpleContextActorPath <: ContextActorPath {
    private let pathString: String

    public init(path: String) {
        this.pathString = path
    }

    public func toString(): String {
        pathString
    }
}
