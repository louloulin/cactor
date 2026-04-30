/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 基础队列接口
 * 零依赖的通用队列数据结构，不包含任何业务概念
 */
package cactor.foundation.queue

import std.sync.*
import std.collection.*

/**
 * 通用队列接口 - 零依赖
 * 提供基础的队列操作，不依赖任何业务概念
 */
public interface Queue<T> {
    /**
     * 将元素加入队列
     */
    func enqueue(item: T): Bool
    
    /**
     * 从队列取出元素
     */
    func dequeue(): Option<T>
    
    /**
     * 检查队列是否为空
     */
    func isEmpty(): Bool
    
    /**
     * 获取队列中元素数量
     */
    func size(): Int64
    
    /**
     * 清空队列
     */
    func clear(): Unit
    
    /**
     * 获取队列容量（如果有限制）
     */
    func capacity(): Int64
}

/**
 * 队列统计信息
 */
public struct QueueStats {
    public let enqueueCount: Int64
    public let dequeueCount: Int64
    public let failedEnqueues: Int64
    public let failedDequeues: Int64
    public let currentSize: Int64
    public let capacity: Int64

    public init(enqueueCount: Int64, dequeueCount: Int64, failedEnqueues: Int64,
                failedDequeues: Int64, currentSize: Int64, capacity: Int64) {
        this.enqueueCount = enqueueCount
        this.dequeueCount = dequeueCount
        this.failedEnqueues = failedEnqueues
        this.failedDequeues = failedDequeues
        this.currentSize = currentSize
        this.capacity = capacity
    }
    
    public func getSuccessRate(): Float64 {
        let totalOps = enqueueCount + dequeueCount
        let failedOps = failedEnqueues + failedDequeues
        if (totalOps == 0) { return 1.0 }
        return Float64(totalOps - failedOps) / Float64(totalOps)
    }

    public func getUtilization(): Float64 {
        if (capacity == 0) { return 0.0 }
        return Float64(currentSize) / Float64(capacity)
    }
}

/**
 * 简单的基于ArrayList的队列实现
 * 用于基础功能验证
 */
public class SimpleQueue<T> <: Queue<T> {
    private let items: ArrayList<T>
    private let mutex: Mutex
    private let maxCapacity: Int64
    
    public init(capacity: Int64) {
        this.items = ArrayList<T>()
        this.mutex = Mutex()
        this.maxCapacity = capacity
    }
    
    public func enqueue(item: T): Bool {
        mutex.lock()
        if (items.size >= maxCapacity) {
            mutex.unlock()
            return false
        }
        items.add(item)
        mutex.unlock()
        return true
    }
    
    public func dequeue(): Option<T> {
        mutex.lock()
        if (items.isEmpty()) {
            mutex.unlock()
            return None
        }

        // 简化实现：创建新的ArrayList，跳过第一个元素
        let item = items[0]
        let newItems = ArrayList<T>()
        for (i in 1..items.size) {
            newItems.add(items[i])
        }
        items.clear()
        for (newItem in newItems) {
            items.add(newItem)
        }

        mutex.unlock()
        return Some(item)
    }
    
    public func isEmpty(): Bool {
        mutex.lock()
        let result = items.isEmpty()
        mutex.unlock()
        return result
    }
    
    public func size(): Int64 {
        mutex.lock()
        let result = items.size
        mutex.unlock()
        return result
    }
    
    public func clear(): Unit {
        mutex.lock()
        items.clear()
        mutex.unlock()
    }
    
    public func capacity(): Int64 {
        return maxCapacity
    }
}
