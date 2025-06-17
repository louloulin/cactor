/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 环形缓冲区邮箱
 * 高性能无锁消息队列实现
 */
package cactor.runtime.mailbox.ringbuffer

import std.sync.*
import cactor.runtime.mailbox.Mailbox
import cactor.core.message.Envelope

/**
 * 环形缓冲区邮箱
 * 基于无锁环形缓冲区的高性能邮箱实现
 * 参考Disruptor模式设计
 */
public class RingBufferMailbox <: Mailbox {
    private let buffer: Array<Option<Envelope>>
    private let capacity: Int64
    private let readIndex: AtomicInt64
    private let writeIndex: AtomicInt64
    private let mask: Int64
    private let closed: AtomicBool

    public init(capacity: Int64) {
        // 确保容量是2的幂，便于位运算优化
        let actualCapacity = RingBufferMailbox.nextPowerOfTwo(capacity)
        this.capacity = actualCapacity
        this.buffer = Array<Option<Envelope>>(actualCapacity, { i => None })
        this.readIndex = AtomicInt64(0)
        this.writeIndex = AtomicInt64(0)
        this.mask = actualCapacity - 1
        this.closed = AtomicBool(false)
    }

    public func enqueue(envelope: Envelope): Bool {
        if (closed.load()) {
            return false  // 邮箱已关闭，拒绝新消息
        }

        // 使用CAS循环确保并发安全
        var attempts = 0
        while (attempts < 1000) {  // 限制重试次数避免无限循环
            let currentWrite = writeIndex.load()
            let nextWrite = currentWrite + 1

            // 检查是否有空间（避免覆盖未读数据）
            if (nextWrite - readIndex.load() > capacity) {
                return false  // 队列满
            }

            // 尝试原子更新写索引
            if (writeIndex.compareAndSwap(currentWrite, nextWrite)) {
                // 成功获取写位置，现在可以安全写入
                let index = currentWrite & mask
                buffer[index] = Some(envelope)
                return true
            }
            // CAS失败，重试
            attempts += 1
        }
        return false  // 重试次数过多，失败
    }

    public func dequeue(): Option<Envelope> {
        if (closed.load() && isEmpty()) {
            return None
        }

        // 使用CAS循环确保并发安全
        var attempts = 0
        while (attempts < 1000) {  // 限制重试次数避免无限循环
            let currentRead = readIndex.load()

            // 检查是否有数据
            if (currentRead >= writeIndex.load()) {
                return None  // 队列空
            }

            // 尝试原子更新读索引
            if (readIndex.compareAndSwap(currentRead, currentRead + 1)) {
                // 成功获取读位置，现在可以安全读取
                let index = currentRead & mask
                let envelope = buffer[index]

                // 清空槽位
                buffer[index] = None
                return envelope
            }
            // CAS失败，重试
            attempts += 1
        }
        return None  // 重试次数过多，失败
    }

    public func isEmpty(): Bool {
        readIndex.load() >= writeIndex.load()
    }

    public func size(): Int64 {
        let write = writeIndex.load()
        let read = readIndex.load()
        return write - read
    }

    public func clear(): Unit {
        // 清空所有槽位
        for (i in 0..capacity) {
            buffer[i] = None
        }
        
        // 重置索引
        readIndex.store(0)
        writeIndex.store(0)
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
    }

    public func getCapacity(): Int64 {
        capacity
    }

    /**
     * 获取当前负载比例
     * @return 负载比例 (0.0 - 1.0)
     */
    public func getLoadRatio(): Float64 {
        let currentSize = size()
        Float64(currentSize) / Float64(capacity)
    }

    /**
     * 计算下一个2的幂
     * 确保容量是2的幂，便于位运算优化
     */
    private static func nextPowerOfTwo(n: Int64): Int64 {
        if (n <= 1) {
            return 1
        }

        var power = 1
        while (power < n) {
            power = power << 1
        }
        return power
    }
}

/**
 * 背压控制的环形缓冲区邮箱
 * 当负载过高时触发背压机制
 */
public class BackpressureRingBufferMailbox <: Mailbox {
    private let innerMailbox: RingBufferMailbox
    private let backpressureThreshold: Float64
    private let rejectedCount: AtomicInt64

    public init(capacity: Int64, backpressureThreshold: Float64) {
        this.innerMailbox = RingBufferMailbox(capacity)
        this.backpressureThreshold = backpressureThreshold
        this.rejectedCount = AtomicInt64(0)
    }

    public func enqueue(envelope: Envelope): Bool {
        let loadRatio = innerMailbox.getLoadRatio()
        
        if (loadRatio > backpressureThreshold) {
            // 触发背压，拒绝消息
            rejectedCount.fetchAdd(1)
            return false
        }
        
        return innerMailbox.enqueue(envelope)
    }

    public func dequeue(): Option<Envelope> {
        innerMailbox.dequeue()
    }

    public func isEmpty(): Bool {
        innerMailbox.isEmpty()
    }

    public func size(): Int64 {
        innerMailbox.size()
    }

    public func clear(): Unit {
        innerMailbox.clear()
        rejectedCount.store(0)
    }

    public func isClosed(): Bool {
        innerMailbox.isClosed()
    }

    public func close(): Unit {
        innerMailbox.close()
    }

    public func getRejectedCount(): Int64 {
        rejectedCount.load()
    }

    public func getLoadRatio(): Float64 {
        innerMailbox.getLoadRatio()
    }

    public func getBackpressureThreshold(): Float64 {
        backpressureThreshold
    }
}
