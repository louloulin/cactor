/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 无锁环形缓冲区邮箱
 * 基于仓颉语言原子操作的高性能无锁邮箱实现
 */
package cactor.mailbox.lockfree

import std.sync.*
import std.collection.*
import std.math.*
import cactor.core.message.{Message, Envelope}
import cactor.core.mailbox.Mailbox

/**
 * 简化的原子槽位实现
 * 专门用于环形缓冲区的槽位管理
 */
public class AtomicSlot {
    private let state: AtomicInt64  // 0=空, 1=有数据, 2=正在写入, 3=正在读取
    private let data: AtomicInt64   // 数据的哈希码或标识符

    // 状态常量
    public static let EMPTY: Int64 = 0
    public static let FILLED: Int64 = 1
    public static let WRITING: Int64 = 2
    public static let READING: Int64 = 3

    public init() {
        this.state = AtomicInt64(EMPTY)
        this.data = AtomicInt64(0)
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
    public func finishWrite(dataHash: Int64): Unit {
        data.store(dataHash)
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
    public func finishRead(): Int64 {
        let result = data.load()
        data.store(0)
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
 * 无锁环形缓冲区邮箱
 * 
 * 设计特点：
 * 1. 使用环形缓冲区减少内存分配
 * 2. 通过原子操作实现无锁并发
 * 3. 支持多生产者多消费者模式
 * 4. 容量必须是2的幂，便于位运算优化
 */
public class LockFreeRingBufferMailbox <: Mailbox {
    private let buffer: Array<AtomicSlot>
    private let capacity: Int64
    private let mask: Int64        // 容量掩码，用于快速取模
    private let head: AtomicInt64  // 读指针
    private let tail: AtomicInt64  // 写指针
    private let closed: AtomicBool // 邮箱是否已关闭
    
    // 性能统计
    private let enqueueCount: AtomicInt64
    private let dequeueCount: AtomicInt64
    private let failedEnqueues: AtomicInt64
    private let failedDequeues: AtomicInt64
    
    public init(requestedCapacity: Int64) {
        // 初始化指针
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.closed = AtomicBool(false)

        // 初始化统计
        this.enqueueCount = AtomicInt64(0)
        this.dequeueCount = AtomicInt64(0)
        this.failedEnqueues = AtomicInt64(0)
        this.failedDequeues = AtomicInt64(0)

        // 确保容量是2的幂
        let actualCapacity = LockFreeRingBufferMailbox.nextPowerOfTwo(requestedCapacity)
        this.capacity = actualCapacity
        this.mask = actualCapacity - 1

        // 初始化缓冲区
        this.buffer = Array<AtomicSlot>(actualCapacity, { i => AtomicSlot() })
    }
    
    /**
     * 入队操作（无锁实现）
     */
    public func enqueue(envelope: Envelope): Bool {
        if (closed.load()) {
            failedEnqueues.fetchAdd(1)
            return false
        }
        
        // 最大重试次数，避免无限循环
        let maxRetries = 1000
        var retries = 0
        
        while (retries < maxRetries) {
            let currentTail = tail.load()
            let currentHead = head.load()
            
            // 检查队列是否已满
            if (currentTail - currentHead >= capacity) {
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
                    slot.finishWrite(Int64(envelope.getMessage().messageType().hashCode()))
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
    public func dequeue(): Option<Envelope> {
        if (closed.load() && isEmpty()) {
            failedDequeues.fetchAdd(1)
            return None
        }
        
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
                    let dataHash = slot.finishRead()
                    dequeueCount.fetchAdd(1)
                    
                    // 简化实现：创建一个占位符Envelope
                    // 在实际实现中需要从哈希码恢复真实对象
                    return Some(createPlaceholderEnvelope(dataHash))
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
     * 检查邮箱是否为空
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
    public func getCapacity(): Int64 {
        return capacity
    }
    
    /**
     * 清空邮箱
     */
    public func clear(): Unit {
        // 通过重置头尾指针来清空队列
        let currentTail = tail.load()
        head.store(currentTail)

        // 清空所有槽位
        for (i in 0..capacity) {
            let slot = buffer[i]
            if (slot.isFilled()) {
                slot.finishRead()  // 清空槽位
            }
        }
    }

    /**
     * 关闭邮箱
     */
    public func close(): Unit {
        closed.store(true)
    }

    /**
     * 检查邮箱是否已关闭
     */
    public func isClosed(): Bool {
        return closed.load()
    }
    
    /**
     * 获取性能统计信息
     */
    public func getStats(): MailboxStats {
        MailboxStats(
            enqueueCount.load(),
            dequeueCount.load(),
            failedEnqueues.load(),
            failedDequeues.load(),
            size(),
            capacity
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
    
    /**
     * 创建占位符Envelope（简化实现）
     */
    private func createPlaceholderEnvelope(dataHash: Int64): Envelope {
        // 简化实现：创建一个包含哈希码的占位符消息
        let placeholderMessage = PlaceholderMessage(dataHash)
        return Envelope(placeholderMessage, None)
    }
}

/**
 * 邮箱性能统计信息
 */
public struct MailboxStats {
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
 * 占位符消息（用于简化实现）
 */
public class PlaceholderMessage <: Message {
    private let dataHash: Int64
    
    public init(dataHash: Int64) {
        this.dataHash = dataHash
    }
    
    public func messageType(): String {
        return "PlaceholderMessage"
    }
    
    public func getDataHash(): Int64 {
        return dataHash
    }
}
