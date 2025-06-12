/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - 邮箱系统定义
 */
package cactor.core.mailbox

import std.sync.*
import std.collection.*
import cactor.core.message.Message
import cactor.core.actor.ActorRef

/**
 * 邮箱接口
 * 负责存储和管理Actor的消息队列
 */
public interface Mailbox {
    /**
     * 将消息入队
     * @param message 要入队的消息
     * @param sender 发送者引用
     */
    func enqueue(message: Message, sender: Option<ActorRef>): Unit

    /**
     * 从队列中取出消息
     * @return 消息和发送者的组合，如果队列为空则返回None
     */
    func dequeue(): Option<Envelope>

    /**
     * 检查邮箱是否为空
     * @return 是否为空
     */
    func isEmpty(): Bool

    /**
     * 获取邮箱中消息的数量
     * @return 消息数量
     */
    func size(): Int64

    /**
     * 清空邮箱
     */
    func clear(): Unit

    /**
     * 检查邮箱是否已关闭
     * @return 是否已关闭
     */
    func isClosed(): Bool

    /**
     * 关闭邮箱
     */
    func close(): Unit
}

/**
 * 消息信封
 * 包装消息和发送者信息
 */
public struct Envelope {
    private let message: Message
    private let sender: Option<ActorRef>

    public init(message: Message, sender: Option<ActorRef>) {
        this.message = message
        this.sender = sender
    }

    public func getMessage(): Message {
        message
    }

    public func getSender(): Option<ActorRef> {
        sender
    }
}

/**
 * 无界邮箱
 * 可以无限制地存储消息
 */
public class UnboundedMailbox <: Mailbox {
    private let queue: ArrayList<Envelope>
    private let mutex: ReentrantMutex
    private let closed: AtomicBool

    public init() {
        this.queue = ArrayList<Envelope>()
        this.mutex = ReentrantMutex()
        this.closed = AtomicBool(false)
    }

    public func enqueue(message: Message, sender: Option<ActorRef>): Unit {
        if (closed.load()) {
            return  // 邮箱已关闭，丢弃消息
        }

        let envelope = Envelope(message, sender)
        mutex.lock()
        try {
            queue.append(envelope)
        } finally {
            mutex.unlock()
        }
    }

    public func dequeue(): Option<Envelope> {
        if (closed.load()) {
            return None
        }

        mutex.lock()
        try {
            if (queue.isEmpty()) {
                return None
            } else {
                let envelope = queue[0]
                queue.remove(0)
                return Some(envelope)
            }
        } finally {
            mutex.unlock()
        }
    }

    public func isEmpty(): Bool {
        mutex.lock()
        try {
            return queue.isEmpty()
        } finally {
            mutex.unlock()
        }
    }

    public func size(): Int64 {
        mutex.lock()
        try {
            return queue.size
        } finally {
            mutex.unlock()
        }
    }

    public func clear(): Unit {
        mutex.lock()
        try {
            queue.clear()
        } finally {
            mutex.unlock()
        }
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
        clear()
    }
}

/**
 * 有界邮箱
 * 限制消息队列的最大长度
 */
public class BoundedMailbox <: Mailbox {
    private let queue: ArrayList<Envelope>
    private let mutex: ReentrantMutex
    private let closed: AtomicBool
    private let capacity: Int64

    public init(capacity: Int64) {
        this.queue = ArrayList<Envelope>()
        this.mutex = ReentrantMutex()
        this.closed = AtomicBool(false)
        this.capacity = capacity
    }

    public func enqueue(message: Message, sender: Option<ActorRef>): Unit {
        if (closed.load()) {
            return  // 邮箱已关闭，丢弃消息
        }

        let envelope = Envelope(message, sender)
        mutex.lock()
        try {
            if (queue.size < capacity) {
                queue.append(envelope)
            } else {
                // 队列已满，可以选择丢弃消息或者替换最旧的消息
                // 这里选择丢弃新消息
                // 实际实现中可能需要更复杂的策略
            }
        } finally {
            mutex.unlock()
        }
    }

    public func dequeue(): Option<Envelope> {
        if (closed.load()) {
            return None
        }

        mutex.lock()
        try {
            if (queue.isEmpty()) {
                return None
            } else {
                let envelope = queue[0]
                queue.remove(0)
                return Some(envelope)
            }
        } finally {
            mutex.unlock()
        }
    }

    public func isEmpty(): Bool {
        mutex.lock()
        try {
            return queue.isEmpty()
        } finally {
            mutex.unlock()
        }
    }

    public func size(): Int64 {
        mutex.lock()
        try {
            return queue.size
        } finally {
            mutex.unlock()
        }
    }

    public func clear(): Unit {
        mutex.lock()
        try {
            queue.clear()
        } finally {
            mutex.unlock()
        }
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
        clear()
    }

    public func getCapacity(): Int64 {
        capacity
    }
}

/**
 * 优先级邮箱
 * 根据消息优先级排序
 */
public class PriorityMailbox <: Mailbox {
    private let queue: ArrayList<Envelope>
    private let mutex: ReentrantMutex
    private let closed: AtomicBool

    public init() {
        this.queue = ArrayList<Envelope>()
        this.mutex = ReentrantMutex()
        this.closed = AtomicBool(false)
    }

    public func enqueue(message: Message, sender: Option<ActorRef>): Unit {
        if (closed.load()) {
            return  // 邮箱已关闭，丢弃消息
        }

        let envelope = Envelope(message, sender)
        mutex.lock()
        try {
            // 简化的优先级插入，实际应该使用优先队列
            insertByPriority(envelope)
        } finally {
            mutex.unlock()
        }
    }

    private func insertByPriority(envelope: Envelope): Unit {
        let priority = envelope.getMessage().priority()
        var inserted = false
        
        for (i in 0..queue.size) {
            if (queue[i].getMessage().priority() < priority) {
                queue.insert(i, envelope)
                inserted = true
                break
            }
        }
        
        if (!inserted) {
            queue.append(envelope)
        }
    }

    public func dequeue(): Option<Envelope> {
        if (closed.load()) {
            return None
        }

        mutex.lock()
        try {
            if (queue.isEmpty()) {
                return None
            } else {
                let envelope = queue[0]
                queue.remove(0)
                return Some(envelope)
            }
        } finally {
            mutex.unlock()
        }
    }

    public func isEmpty(): Bool {
        mutex.lock()
        try {
            return queue.isEmpty()
        } finally {
            mutex.unlock()
        }
    }

    public func size(): Int64 {
        mutex.lock()
        try {
            return queue.size
        } finally {
            mutex.unlock()
        }
    }

    public func clear(): Unit {
        mutex.lock()
        try {
            queue.clear()
        } finally {
            mutex.unlock()
        }
    }

    public func isClosed(): Bool {
        closed.load()
    }

    public func close(): Unit {
        closed.store(true)
        clear()
    }
}
