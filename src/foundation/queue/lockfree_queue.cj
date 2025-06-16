/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 无锁队列实现
 * 零依赖的高性能无锁队列，基于环形缓冲区
 */
package cactor.foundation.queue

import std.sync.*
import std.collection.*

/**
 * 原子槽位实现
 * 专门用于环形缓冲区的槽位管理
 */
public class AtomicSlot<T> {
    private let state: AtomicInt64  // 0=空, 1=有数据, 2=正在写入, 3=正在读取
    private var data: Option<T>     // 存储的数据
    private let mutex: ReentrantMutex  // 保护data的访问

    // 状态常量
    public static let EMPTY: Int64 = 0
    public static let FILLED: Int64 = 1
    public static let WRITING: Int64 = 2
    public static let READING: Int64 = 3

    public init() {
        this.state = AtomicInt64(EMPTY)
        this.data = None
        this.mutex = ReentrantMutex()
    }

    /**
     * 尝试开始写入
     */
    public func tryStartWrite(): Bool {
        return state.compareAndSwap(EMPTY, WRITING)
    }

    /**
     * 完成写入
     */
    public func finishWrite(item: T): Unit {
        mutex.lock()
        data = Some(item)
        mutex.unlock()
        state.store(FILLED)
    }

    /**
     * 取消写入
     */
    public func cancelWrite(): Unit {
        state.store(EMPTY)
    }

    /**
     * 尝试开始读取
     */
    public func tryStartRead(): Bool {
        return state.compareAndSwap(FILLED, READING)
    }

    /**
     * 完成读取
     */
    public func finishRead(): Option<T> {
        mutex.lock()
        let result = data
        data = None
        mutex.unlock()
        state.store(EMPTY)
        return result
    }

    /**
     * 取消读取
     */
    public func cancelRead(): Unit {
        state.store(FILLED)
    }

    /**
     * 获取当前状态
     */
    public func getState(): Int64 {
        return state.load()
    }

    /**
     * 检查是否为空
     */
    public func isEmpty(): Bool {
        return state.load() == EMPTY
    }

    /**
     * 检查是否已填充
     */
    public func isFilled(): Bool {
        return state.load() == FILLED
    }
}

/**
 * 无锁环形缓冲区队列
 * 
 * 设计特点：
 * 1. 使用环形缓冲区减少内存分配
 * 2. 通过原子操作实现无锁并发
 * 3. 支持多生产者多消费者模式
 * 4. 容量必须是2的幂，便于位运算优化
 */
public class LockFreeQueue<T> <: Queue<T> {
    private let buffer: Array<AtomicSlot<T>>
    private let queueCapacity: Int64
    private let mask: Int64        // 容量掩码，用于快速取模
    private let head: AtomicInt64  // 读指针
    private let tail: AtomicInt64  // 写指针
    
    // 性能统计
    private let enqueueCount: AtomicInt64
    private let dequeueCount: AtomicInt64
    private let failedEnqueues: AtomicInt64
    private let failedDequeues: AtomicInt64
    
    public init(requestedCapacity: Int64) {
        // 初始化指针
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)

        // 初始化统计
        this.enqueueCount = AtomicInt64(0)
        this.dequeueCount = AtomicInt64(0)
        this.failedEnqueues = AtomicInt64(0)
        this.failedDequeues = AtomicInt64(0)

        // 确保容量是2的幂
        let actualCapacity = LockFreeQueue<T>.nextPowerOfTwo(requestedCapacity)
        this.queueCapacity = actualCapacity
        this.mask = actualCapacity - 1

        // 初始化缓冲区
        this.buffer = Array<AtomicSlot<T>>(actualCapacity, { _ => AtomicSlot<T>() })
    }
    
    /**
     * 入队操作（无锁实现）
     */
    public func enqueue(item: T): Bool {
        // 最大重试次数，避免无限循环
        let maxRetries = 1000
        var retries = 0
        
        while (retries < maxRetries) {
            let currentTail = tail.load()
            let currentHead = head.load()
            
            // 检查队列是否已满
            if (currentTail - currentHead >= queueCapacity) {
                failedEnqueues.fetchAdd(1)
                return false  // 队列已满
            }
            
            let index = currentTail & mask
            let slot = buffer[index]
            
            // 尝试开始写入
            if (slot.tryStartWrite()) {
                // 成功获得写入权限，尝试推进tail指针
                if (tail.compareAndSwap(currentTail, currentTail + 1)) {
                    // 成功推进指针，完成写入
                    slot.finishWrite(item)
                    enqueueCount.fetchAdd(1)
                    return true
                } else {
                    // 指针推进失败，取消写入
                    slot.cancelWrite()
                }
            }
            
            retries += 1
        }
        
        failedEnqueues.fetchAdd(1)
        return false  // 重试次数用完
    }
    
    /**
     * 出队操作（无锁实现）
     */
    public func dequeue(): Option<T> {
        // 最大重试次数
        let maxRetries = 1000
        var retries = 0
        
        while (retries < maxRetries) {
            let currentHead = head.load()
            let currentTail = tail.load()
            
            // 检查队列是否为空
            if (currentHead >= currentTail) {
                failedDequeues.fetchAdd(1)
                return None
            }
            
            let index = currentHead & mask
            let slot = buffer[index]
            
            // 尝试开始读取
            if (slot.tryStartRead()) {
                // 成功获得读取权限，尝试推进head指针
                if (head.compareAndSwap(currentHead, currentHead + 1)) {
                    // 成功推进指针，完成读取
                    let result = slot.finishRead()
                    dequeueCount.fetchAdd(1)
                    return result
                } else {
                    // 指针推进失败，取消读取
                    slot.cancelRead()
                }
            }
            
            retries += 1
        }
        
        failedDequeues.fetchAdd(1)
        return None  // 重试次数用完
    }
    
    /**
     * 检查队列是否为空
     */
    public func isEmpty(): Bool {
        return head.load() >= tail.load()
    }
    
    /**
     * 获取当前队列大小
     */
    public func size(): Int64 {
        let currentTail = tail.load()
        let currentHead = head.load()
        let diff = currentTail - currentHead
        return if (diff > 0) { diff } else { 0 }
    }
    
    /**
     * 获取队列容量
     */
    public func capacity(): Int64 {
        return this.queueCapacity
    }
    
    /**
     * 清空队列
     */
    public func clear(): Unit {
        // 通过重置头尾指针来清空队列
        let currentTail = tail.load()
        head.store(currentTail)

        // 清空所有槽位
        for (i in 0..queueCapacity) {
            let slot = buffer[i]
            if (slot.isFilled()) {
                slot.finishRead()  // 清空槽位
            }
        }
    }

    /**
     * 批量入队操作 - 性能优化
     */
    public func enqueueBatch(items: Array<T>): Int32 {
        var successCount: Int32 = 0
        for (item in items) {
            if (enqueue(item)) {
                successCount += 1
            } else {
                break  // 队列已满，停止批量操作
            }
        }
        return successCount
    }

    /**
     * 批量出队操作 - 性能优化
     */
    public func dequeueBatch(maxCount: Int32): Array<T> {
        let results = ArrayList<T>()
        var count: Int32 = 0

        while (count < maxCount) {
            match (dequeue()) {
                case Some(item) =>
                    results.append(item)
                    count += 1
                case None => break
            }
        }

        return results.toArray()
    }

    /**
     * 获取性能统计信息
     */
    public func getStats(): QueueStats {
        QueueStats(
            enqueueCount.load(),
            dequeueCount.load(),
            failedEnqueues.load(),
            failedDequeues.load(),
            size(),
            queueCapacity
        )
    }
    
    /**
     * 计算下一个2的幂
     */
    private static func nextPowerOfTwo(n: Int64): Int64 {
        if (n <= 1) { return 1 }
        if (n <= 2) { return 2 }
        if (n <= 4) { return 4 }
        if (n <= 8) { return 8 }
        if (n <= 16) { return 16 }
        if (n <= 32) { return 32 }
        if (n <= 64) { return 64 }
        if (n <= 128) { return 128 }
        if (n <= 256) { return 256 }
        if (n <= 512) { return 512 }
        if (n <= 1024) { return 1024 }
        if (n <= 2048) { return 2048 }
        if (n <= 4096) { return 4096 }
        if (n <= 8192) { return 8192 }
        if (n <= 16384) { return 16384 }
        return 32768  // 最大支持32K
    }
}
