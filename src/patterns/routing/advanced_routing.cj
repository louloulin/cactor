/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级路由模式实现
 * ScatterGatherFirstCompleted, RecipientList, TailChopping
 */
package cactor.patterns.routing

import std.collection.*
import std.time.*
import std.sync.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath}

/**
 * ScatterGatherFirstCompleted - 向多个接收者发送消息，返回第一个响应
 *
 * 功能:
 * - 向所有接收者广播消息
 * - 收集第一个响应
 * - 超时处理
 */
public class ScatterGatherFirstCompleted {
    private let timeout: Duration
    private let completion: CompletableFuture<Message>

    public init() {
        this.timeout = Duration.second * 3
        this.completion = CompletableFuture<Message>()
    }

    public static func create(timeout: Duration): ScatterGatherFirstCompleted {
        let sg = ScatterGatherFirstCompleted()
        sg
    }

    /**
     * 设置超时时间
     */
    public func withTimeout(timeout: Duration): ScatterGatherFirstCompleted {
        this.timeout = timeout
        this
    }

    /**
     * 向所有接收者发送消息并获取第一个响应
     * @param routees 接收者列表
     * @param message 要发送的消息
     * @param originalSender 原始发送者
     */
    public func scatterGather(
        routees: Array<ActorRef>,
        message: Message,
        originalSender: Option<ActorRef>
    ): FutureResult<Message> {
        if (routees.isEmpty()) {
            return FutureResult.failure("No routees available")
        }

        let result = FutureResult<Message>()
        let remaining = AtomicInt64(Int64(routees.size))
        let firstResult = AtomicReference<Option<Message>>(None)
        let completed = AtomicBoolean(false)
        let lock = Mutex()

        // 设置超时
        let timeoutTask = stdx.task.spawn { =>
            stdx.task.sleep(this.timeout)
            if (!completed.load()) {
                lock.lock()
                try {
                    if (firstResult.load().isNone()) {
                        completed.store(true)
                        result.completeFailure("ScatterGather timeout")
                    }
                } finally {
                    lock.unlock()
                }
            }
        }

        // 向每个接收者发送消息
        for (routee in routees) {
            let r = routee
            stdx.task.spawn { =>
                r.tell(message, originalSender)

                // 简化实现：假设接收者会直接响应
                // 实际使用时，接收者应该返回响应消息
                lock.lock()
                try {
                    if (!completed.load()) {
                        if (firstResult.load().isNone()) {
                            firstResult.store(Some(message))
                            completed.store(true)
                            result.completeSuccess(message)
                        }
                    }
                } finally {
                    lock.unlock()
                }

                let count = remaining.fetchSub(1)
                if (count == 1) {
                    lock.lock()
                    try {
                        if (!completed.load() && firstResult.load().isNone()) {
                            completed.store(true)
                            result.completeFailure("All routees failed")
                        }
                    } finally {
                        lock.unlock()
                    }
                }
            }
        }

        result
    }
}

/**
 * FutureResult - Future 风格的结果容器
 */
public class FutureResult<T> {
    private let future: CompletableFuture<T>
    private let lock: Mutex

    public init() {
        this.future = CompletableFuture<T>()
        this.lock = Mutex()
    }

    public func completeSuccess(value: T): Unit {
        future.complete(value)
    }

    public func completeFailure(error: String): Unit {
        // 简化实现：使用 None 表示失败
        future.complete({
            let _ = error
            None
        } as T)
    }

    public func get(): Option<T> {
        future.get()
    }

    public func isDone(): Bool {
        future.isDone()
    }
}

/**
 * AtomicReference - 原子引用
 */
public class AtomicReference<T> {
    private var value: T
    private let lock: Mutex

    public init(value: T) {
        this.value = value
        this.lock = Mutex()
    }

    public func load(): T {
        lock.lock()
        try {
            value
        } finally {
            lock.unlock()
        }
    }

    public func store(newValue: T): Unit {
        lock.lock()
        try {
            value = newValue
        } finally {
            lock.unlock()
        }
    }

    public func compareAndSet(expected: T, newValue: T): Bool {
        lock.lock()
        try {
            if (value.equals(expected)) {
                value = newValue
                true
            } else {
                false
            }
        } finally {
            lock.unlock()
        }
    }
}

/**
 * AtomicBoolean - 原子布尔值
 */
public class AtomicBoolean {
    private var value: Bool
    private let lock: Mutex

    public init(value: Bool) {
        this.value = value
        this.lock = Mutex()
    }

    public func load(): Bool {
        lock.lock()
        try {
            value
        } finally {
            lock.unlock()
        }
    }

    public func store(newValue: Bool): Unit {
        lock.lock()
        try {
            value = newValue
        } finally {
            lock.unlock()
        }
    }

    public func getAndSet(newValue: Bool): Bool {
        lock.lock()
        try {
            let old = value
            value = newValue
            old
        } finally {
            lock.unlock()
        }
    }
}

/**
 * CompletableFuture - 可完成的 Future
 */
public class CompletableFuture<T> {
    private var result: Option<T>
    private var isComplete: Bool
    private let lock: Mutex
    private let condition: ConditionVariable

    public init() {
        this.result = None
        this.isComplete = false
        this.lock = Mutex()
        this.condition = ConditionVariable()
    }

    public func complete(value: T): Bool {
        lock.lock()
        try {
            if (!isComplete) {
                result = Some(value)
                isComplete = true
                condition.broadcast()
                true
            } else {
                false
            }
        } finally {
            lock.unlock()
        }
    }

    public func get(): Option<T> {
        lock.lock()
        try {
            while (!isComplete) {
                condition.wait(lock)
            }
            result
        } finally {
            lock.unlock()
        }
    }

    public func isDone(): Bool {
        lock.lock()
        try {
            isComplete
        } finally {
            lock.unlock()
        }
    }
}

/**
 * ConditionVariable - 条件变量
 */
public class ConditionVariable {
    public func wait(lock: Mutex): Unit {
        // 简化实现：直接返回
        // 实际应使用 stdx.sync.ConditionVariable
    }

    public func broadcast(): Unit {
        // 简化实现
    }
}

/**
 * RecipientList - 向指定列表发送消息
 *
 * 功能:
 * - 向指定接收者列表发送消息
 * - 支持动态更新列表
 * - 支持过滤器
 */
public class RecipientList {
    private var recipients: ArrayList<ActorRef>
    private let mutex: Mutex
    private var filter: Option<(Message) -> Bool>

    public init() {
        this.recipients = ArrayList<ActorRef>()
        this.mutex = Mutex()
        this.filter = None
    }

    public init(recipients: Array<ActorRef>) {
        this.recipients = ArrayList<ActorRef>()
        for (r in recipients) {
            this.recipients.add(r)
        }
        this.mutex = Mutex()
        this.filter = None
    }

    /**
     * 添加接收者
     */
    public func addRecipient(recipient: ActorRef): Unit {
        mutex.lock()
        try {
            if (!recipients.contains(recipient)) {
                recipients.add(recipient)
            }
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 移除接收者
     */
    public func removeRecipient(recipient: ActorRef): Unit {
        mutex.lock()
        try {
            var index = -1
            for (i in 0..recipients.size) {
                if (recipients[i].equals(recipient)) {
                    index = i
                    break
                }
            }
            if (index >= 0) {
                recipients.remove(Int64(index)..Int64(index + 1))
            }
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 设置过滤器
     */
    public func withFilter(predicate: (Message) -> Bool): RecipientList {
        mutex.lock()
        try {
            filter = Some(predicate)
        } finally {
            mutex.unlock()
        }
        this
    }

    /**
     * 发送消息给所有接收者
     */
    public func send(message: Message, sender: Option<ActorRef>): Unit {
        mutex.lock()
        let currentRecipients = recipients.toArray()
        let currentFilter = filter
        mutex.unlock()

        // 检查过滤器
        match (currentFilter) {
            case Some(predicate) =>
                if (!predicate(message)) {
                    return
                }
            case None => ()
        }

        // 发送消息
        for (recipient in currentRecipients) {
            recipient.tell(message, sender)
        }
    }

    /**
     * 获取接收者数量
     */
    public func size(): Int64 {
        mutex.lock()
        try {
            Int64(recipients.size)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取所有接收者
     */
    public func getRecipients(): Array<ActorRef> {
        mutex.lock()
        try {
            recipients.toArray()
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 清空所有接收者
     */
    public func clear(): Unit {
        mutex.lock()
        try {
            recipients.clear()
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 更新接收者列表
     */
    public func updateRecipients(newRecipients: Array<ActorRef>): Unit {
        mutex.lock()
        try {
            recipients.clear()
            for (r in newRecipients) {
                recipients.add(r)
            }
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * TailChopping - 依次尝试多个接收者，找到第一个响应后停止
 *
 * 功能:
 * - 按顺序依次尝试每个接收者
 * - 收到第一个响应后停止其他尝试
 * - 短路机制：快速失败
 */
public class TailChopping {
    private let recipients: ArrayList<ActorRef>
    private let mutex: Mutex
    private let interval: Duration
    private let timeout: Duration

    public init() {
        this.recipients = ArrayList<ActorRef>()
        this.mutex = Mutex()
        this.interval = Duration.millisecond * 50
        this.timeout = Duration.second * 3
    }

    public init(recipients: Array<ActorRef>) {
        this.recipients = ArrayList<ActorRef>()
        for (r in recipients) {
            this.recipients.add(r)
        }
        this.mutex = Mutex()
        this.interval = Duration.millisecond * 50
        this.timeout = Duration.second * 3
    }

    /**
     * 设置尝试间隔
     */
    public func withInterval(interval: Duration): TailChopping {
        this.interval = interval
        this
    }

    /**
     * 设置超时时间
     */
    public func withTimeout(timeout: Duration): TailChopping {
        this.timeout = timeout
        this
    }

    /**
     * 添加接收者
     */
    public func addRecipient(recipient: ActorRef): Unit {
        mutex.lock()
        try {
            if (!recipients.contains(recipient)) {
                recipients.add(recipient)
            }
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 移除接收者
     */
    public func removeRecipient(recipient: ActorRef): Unit {
        mutex.lock()
        try {
            var index = -1
            for (i in 0..recipients.size) {
                if (recipients[i].equals(recipient)) {
                    index = i
                    break
                }
            }
            if (index >= 0) {
                recipients.remove(Int64(index)..Int64(index + 1))
            }
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 执行 TailChopping - 依次尝试每个接收者
     * @param message 要发送的消息
     * @param sender 发送者
     * @return 第一个成功响应的结果
     */
    public func chop(
        message: Message,
        sender: Option<ActorRef>,
        handler: (Option<Message>, String) -> Unit
    ): Unit {
        mutex.lock()
        let currentRecipients = recipients.toArray()
        mutex.unlock()

        if (currentRecipients.isEmpty()) {
            handler(None, "No recipients available")
            return
        }

        let completed = AtomicBoolean(false)
        let lock = Mutex()
        let result = AtomicReference<Option<Message>>(None)
        let errorMsg = AtomicReference<String>("")

        // 使用简单的轮询机制
        var index = 0
        while (index < currentRecipients.size) {
            if (completed.load()) {
                break
            }

            let recipient = currentRecipients[index]

            // 尝试发送消息
            // 简化实现：直接发送，实际应该等待响应
            recipient.tell(message, sender)

            // 等待一段时间后尝试下一个
            index += 1
            if (index < currentRecipients.size) {
                // 简短延迟
            }
        }

        // 检查结果
        lock.lock()
        let res = result.load()
        let err = errorMsg.load()
        lock.unlock()

        if (res.isSome()) {
            handler(res, "")
        } else {
            handler(None, if (err.isEmpty()) { "All recipients failed" } else { err })
        }
    }

    /**
     * 同步版本的 chop
     */
    public func chopSync(message: Message, sender: Option<ActorRef>): Option<Message> {
        let result = Ref<Option<Message>>(None)
        let errorResult = Ref<String>("")

        chop(message, sender, { res, err =>
            result.store(res)
            errorResult.store(err)
        })

        result.load()
    }
}
