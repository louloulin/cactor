/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 基于仓颉ConcurrentLinkedQueue的邮箱
 * 利用仓颉标准库的高性能并发队列实现
 */
package cactor.runtime.mailbox.queue

import std.collection.concurrent.*
import std.sync.*
import cactor.runtime.mailbox.Mailbox
import cactor.core.message.Envelope

/**
 * 基于仓颉ConcurrentLinkedQueue的邮箱
 * 利用仓颉标准库的线程安全队列实现高性能邮箱
 */
public class QueueMailbox <: Mailbox {
    private let queue: ConcurrentLinkedQueue<Envelope>
    private let closed: AtomicBool

    public init() {
        this.queue = ConcurrentLinkedQueue<Envelope>()
        this.closed = AtomicBool(false)
    }

    public func enqueue(envelope: Envelope): Bool {
        if (closed.load()) {
            return false  // 邮箱已关闭，拒绝新消息
        }
        
        // ConcurrentLinkedQueue的enqueue总是返回true（根据文档）
        return queue.enqueue(envelope)
    }

    public func dequeue(): Option<Envelope> {
        queue.dequeue()
    }

    public func isEmpty(): Bool {
        queue.size == 0
    }

    public func size(): Int64 {
        queue.size
    }

    public func clear(): Unit {
        // ConcurrentLinkedQueue没有clear方法，我们通过dequeue清空
        while (!isEmpty()) {
            queue.dequeue()
        }
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
    }
}

/**
 * 有界队列邮箱
 * 基于QueueMailbox，添加容量限制和背压控制
 */
public class BoundedQueueMailbox <: Mailbox {
    private let innerMailbox: QueueMailbox
    private let maxCapacity: Int64
    private let currentSize: AtomicInt64
    private let rejectedCount: AtomicInt64

    public init(maxCapacity: Int64) {
        this.innerMailbox = QueueMailbox()
        this.maxCapacity = maxCapacity
        this.currentSize = AtomicInt64(0)
        this.rejectedCount = AtomicInt64(0)
    }

    public func enqueue(envelope: Envelope): Bool {
        if (innerMailbox.isClosed()) {
            return false
        }

        // 检查容量限制
        if (currentSize.load() >= maxCapacity) {
            rejectedCount.fetchAdd(1)
            return false  // 队列满，拒绝消息
        }

        // 尝试入队
        if (innerMailbox.enqueue(envelope)) {
            currentSize.fetchAdd(1)
            return true
        }
        
        return false
    }

    public func dequeue(): Option<Envelope> {
        match (innerMailbox.dequeue()) {
            case Some(envelope) => 
                currentSize.fetchAdd(-1)
                Some(envelope)
            case None => 
                None
        }
    }

    public func isEmpty(): Bool {
        currentSize.load() == 0
    }

    public func size(): Int64 {
        currentSize.load()
    }

    public func clear(): Unit {
        innerMailbox.clear()
        currentSize.store(0)
    }

    public func isClosed(): Bool {
        innerMailbox.isClosed()
    }

    public func close(): Unit {
        innerMailbox.close()
    }

    public func getMaxCapacity(): Int64 {
        maxCapacity
    }

    public func getRejectedCount(): Int64 {
        rejectedCount.load()
    }

    public func getLoadRatio(): Float64 {
        Float64(currentSize.load()) / Float64(maxCapacity)
    }
}

/**
 * 优先级队列邮箱
 * 支持消息优先级处理
 */
public class PriorityQueueMailbox <: Mailbox {
    private let highPriorityQueue: QueueMailbox
    private let normalPriorityQueue: QueueMailbox
    private let lowPriorityQueue: QueueMailbox
    private let closed: AtomicBool

    public init() {
        this.highPriorityQueue = QueueMailbox()
        this.normalPriorityQueue = QueueMailbox()
        this.lowPriorityQueue = QueueMailbox()
        this.closed = AtomicBool(false)
    }

    public func enqueue(envelope: Envelope): Bool {
        if (closed.load()) {
            return false
        }

        // 根据消息类型确定优先级
        let messageType = envelope.getMessage().messageType()

        if (messageType.contains("Stop") || messageType.contains("Restart") ||
            messageType.contains("Suspend") || messageType.contains("Resume") ||
            messageType.contains("Terminated") || messageType.contains("DeadLetter")) {
            return highPriorityQueue.enqueue(envelope)
        } else if (messageType.contains("Low")) {
            return lowPriorityQueue.enqueue(envelope)
        } else {
            return normalPriorityQueue.enqueue(envelope)
        }
    }

    public func dequeue(): Option<Envelope> {
        // 按优先级顺序处理：高 -> 普通 -> 低
        match (highPriorityQueue.dequeue()) {
            case Some(envelope) => Some(envelope)
            case None => 
                match (normalPriorityQueue.dequeue()) {
                    case Some(envelope) => Some(envelope)
                    case None => lowPriorityQueue.dequeue()
                }
        }
    }

    public func isEmpty(): Bool {
        highPriorityQueue.isEmpty() && 
        normalPriorityQueue.isEmpty() && 
        lowPriorityQueue.isEmpty()
    }

    public func size(): Int64 {
        highPriorityQueue.size() + 
        normalPriorityQueue.size() + 
        lowPriorityQueue.size()
    }

    public func clear(): Unit {
        highPriorityQueue.clear()
        normalPriorityQueue.clear()
        lowPriorityQueue.clear()
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
        highPriorityQueue.close()
        normalPriorityQueue.close()
        lowPriorityQueue.close()
    }

    public func getHighPrioritySize(): Int64 {
        highPriorityQueue.size()
    }

    public func getNormalPrioritySize(): Int64 {
        normalPriorityQueue.size()
    }

    public func getLowPrioritySize(): Int64 {
        lowPriorityQueue.size()
    }
}
