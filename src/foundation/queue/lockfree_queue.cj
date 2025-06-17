/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 无锁队列实现
 * 零依赖的高性能无锁队列，基于环形缓冲区
 *
 * 优化版本 - 整合SPSC和MPSC设计优势：
 * 1. 缓存行填充避免false sharing
 * 2. 适应性模式切换（SPSC/MPSC）
 * 3. 批量操作优化
 * 4. 减少原子操作竞争
 */
package cactor.foundation.queue

import std.sync.*
import std.collection.*
import std.time.*

/**
 * 队列运行模式枚举
 */
public enum QueueMode {
    | SPSC  // 单生产者单消费者
    | MPSC  // 多生产者单消费者
    | SPMC  // 单生产者多消费者
    | MPMC  // 多生产者多消费者
}

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
 * 无锁环形缓冲区队列 - 优化版本
 *
 * 设计特点：
 * 1. 使用环形缓冲区减少内存分配
 * 2. 通过原子操作实现无锁并发
 * 3. 支持多生产者多消费者模式
 * 4. 容量必须是2的幂，便于位运算优化
 * 5. 缓存行填充避免false sharing
 * 6. 适应性模式切换优化
 */
public class LockFreeQueue<T> <: Queue<T> {
    // 缓存行填充1 - 避免false sharing
    private let pad1_1: Int64 = 0
    private let pad1_2: Int64 = 0
    private let pad1_3: Int64 = 0
    private let pad1_4: Int64 = 0
    private let pad1_5: Int64 = 0
    private let pad1_6: Int64 = 0
    private let pad1_7: Int64 = 0
    private let pad1_8: Int64 = 0

    private let buffer: Array<AtomicSlot<T>>
    private let queueCapacity: Int64
    private let mask: Int64        // 容量掩码，用于快速取模
    private let head: AtomicInt64  // 读指针
    private let tail: AtomicInt64  // 写指针

    // 缓存行填充2 - 分离热点数据
    private let pad2_1: Int64 = 0
    private let pad2_2: Int64 = 0
    private let pad2_3: Int64 = 0
    private let pad2_4: Int64 = 0
    private let pad2_5: Int64 = 0
    private let pad2_6: Int64 = 0
    private let pad2_7: Int64 = 0
    private let pad2_8: Int64 = 0

    // 性能统计
    private let enqueueCount: AtomicInt64
    private let dequeueCount: AtomicInt64
    private let failedEnqueues: AtomicInt64
    private let failedDequeues: AtomicInt64

    // 适应性优化
    private let producerThreadCount: AtomicInt32 = AtomicInt32(0)
    private let consumerThreadCount: AtomicInt32 = AtomicInt32(0)
    private let lastModeCheck: AtomicInt64 = AtomicInt64(0)
    private var currentMode: QueueMode = QueueMode.MPMC  // 默认多生产者多消费者

    // 缓存行填充3 - 最终填充
    private let pad3_1: Int64 = 0
    private let pad3_2: Int64 = 0
    private let pad3_3: Int64 = 0
    private let pad3_4: Int64 = 0
    private let pad3_5: Int64 = 0
    private let pad3_6: Int64 = 0
    private let pad3_7: Int64 = 0
    private let pad3_8: Int64 = 0
    
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
     * 适应性模式检测和更新
     */
    private func updateModeIfNeeded(): Unit {
        let currentTime = getCurrentTimeMillis()
        let lastCheck = this.lastModeCheck.load()

        // 每1000ms检查一次模式
        if (currentTime - lastCheck > 1000) {
            if (this.lastModeCheck.compareAndSwap(lastCheck, currentTime)) {
                let producers = this.producerThreadCount.load()
                let consumers = this.consumerThreadCount.load()

                // 根据线程数量决定模式
                if (producers == 1 && consumers == 1) {
                    this.currentMode = QueueMode.SPSC
                } else if (producers > 1 && consumers == 1) {
                    this.currentMode = QueueMode.MPSC
                } else if (producers == 1 && consumers > 1) {
                    this.currentMode = QueueMode.SPMC
                } else {
                    this.currentMode = QueueMode.MPMC
                }
            }
        }
    }

    /**
     * 获取当前时间毫秒
     */
    private func getCurrentTimeMillis(): Int64 {
        return DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /**
     * 入队操作（无锁实现）- 适应性优化版本
     */
    public func enqueue(item: T): Bool {
        // 注册生产者线程
        this.producerThreadCount.fetchAdd(1)

        // 适应性模式检测
        this.updateModeIfNeeded()

        let result = match (this.currentMode) {
            case QueueMode.SPSC => this.spscEnqueue(item)
            case QueueMode.MPSC => this.mpscEnqueue(item)
            case _ => this.mpmcEnqueue(item)  // SPMC和MPMC使用通用实现
        }

        // 注销生产者线程
        this.producerThreadCount.fetchSub(1)
        return result
    }

    /**
     * SPSC模式入队 - 无CAS竞争
     */
    private func spscEnqueue(item: T): Bool {
        let currentTail = tail.load()
        let currentHead = head.load()

        // 检查队列是否已满
        if (currentTail - currentHead >= queueCapacity) {
            failedEnqueues.fetchAdd(1)
            return false
        }

        let index = currentTail & mask
        let slot = buffer[index]

        // SPSC模式下，直接写入无需CAS
        if (slot.tryStartWrite()) {
            tail.store(currentTail + 1)  // 直接设置，无需CAS
            slot.finishWrite(item)
            enqueueCount.fetchAdd(1)
            return true
        }

        failedEnqueues.fetchAdd(1)
        return false
    }

    /**
     * MPSC模式入队 - 优化的CAS策略
     */
    private func mpscEnqueue(item: T): Bool {
        // 减少重试次数，使用适应性退避
        let maxRetries = 100
        var retries = 0

        while (retries < maxRetries) {
            let currentTail = tail.load()
            let currentHead = head.load()

            // 检查队列是否已满
            if (currentTail - currentHead >= queueCapacity) {
                failedEnqueues.fetchAdd(1)
                return false
            }

            let index = currentTail & mask
            let slot = buffer[index]

            // 尝试开始写入
            if (slot.tryStartWrite()) {
                // 成功获得写入权限，尝试推进tail指针
                if (tail.compareAndSwap(currentTail, currentTail + 1)) {
                    slot.finishWrite(item)
                    enqueueCount.fetchAdd(1)
                    return true
                } else {
                    slot.cancelWrite()
                }
            }

            retries += 1

            // 适应性退避
            if (retries > 50) {
                var backoff = 0
                while (backoff < (retries - 50) && backoff < 10) {
                    backoff += 1
                }
            }
        }

        failedEnqueues.fetchAdd(1)
        return false
    }

    /**
     * MPMC模式入队 - 通用实现
     */
    private func mpmcEnqueue(item: T): Bool {
        // 减少重试次数，提高性能
        let maxRetries = 200
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
     * 出队操作（无锁实现）- 适应性优化版本
     */
    public func dequeue(): Option<T> {
        // 注册消费者线程
        this.consumerThreadCount.fetchAdd(1)

        let result = match (this.currentMode) {
            case QueueMode.SPSC => this.spscDequeue()
            case QueueMode.SPMC => this.spmcDequeue()
            case _ => this.mpmcDequeue()  // MPSC和MPMC使用通用实现
        }

        // 注销消费者线程
        this.consumerThreadCount.fetchSub(1)
        return result
    }

    /**
     * SPSC模式出队 - 无CAS竞争
     */
    private func spscDequeue(): Option<T> {
        let currentHead = head.load()
        let currentTail = tail.load()

        // 检查队列是否为空
        if (currentHead >= currentTail) {
            failedDequeues.fetchAdd(1)
            return None
        }

        let index = currentHead & mask
        let slot = buffer[index]

        // SPSC模式下，直接读取无需CAS
        if (slot.tryStartRead()) {
            head.store(currentHead + 1)  // 直接设置，无需CAS
            let result = slot.finishRead()
            dequeueCount.fetchAdd(1)
            return result
        }

        failedDequeues.fetchAdd(1)
        return None
    }

    /**
     * SPMC模式出队 - 优化的CAS策略
     */
    private func spmcDequeue(): Option<T> {
        let maxRetries = 100
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
                if (head.compareAndSwap(currentHead, currentHead + 1)) {
                    let result = slot.finishRead()
                    dequeueCount.fetchAdd(1)
                    return result
                } else {
                    slot.cancelRead()
                }
            }

            retries += 1

            // 适应性退避
            if (retries > 50) {
                var backoff = 0
                while (backoff < (retries - 50) && backoff < 10) {
                    backoff += 1
                }
            }
        }

        failedDequeues.fetchAdd(1)
        return None
    }

    /**
     * MPMC模式出队 - 通用实现
     */
    private func mpmcDequeue(): Option<T> {
        // 减少重试次数，提高性能
        let maxRetries = 200
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
     * 高性能批量入队操作 - 减少原子操作
     */
    public func enqueueBatch(items: Array<T>): Int32 {
        let batchSize = Int32(items.size)
        if (batchSize == 0) { return 0 }

        // 一次性预留空间，减少原子操作
        let currentTail = tail.load()
        let currentHead = head.load()
        let availableSpace = queueCapacity - (currentTail - currentHead)

        if (availableSpace <= 0) {
            failedEnqueues.fetchAdd(Int64(batchSize))
            return 0
        }

        let actualBatchSize = if (Int64(batchSize) <= availableSpace) {
            batchSize
        } else {
            Int32(availableSpace)
        }

        // 尝试一次性推进tail指针
        if (!tail.compareAndSwap(currentTail, currentTail + Int64(actualBatchSize))) {
            // 如果失败，回退到单个操作
            var successCount: Int32 = 0
            for (i in 0..actualBatchSize) {
                if (enqueue(items[Int64(i)])) {
                    successCount += 1
                } else {
                    break
                }
            }
            return successCount
        }

        // 批量写入数据
        for (i in 0..actualBatchSize) {
            let index = (currentTail + Int64(i)) & mask
            let slot = buffer[index]

            // 等待槽位可用并写入
            var retries = 0
            while (retries < 100) {  // 减少重试次数
                if (slot.tryStartWrite()) {
                    slot.finishWrite(items[Int64(i)])
                    break
                }
                retries += 1
            }
        }

        enqueueCount.fetchAdd(Int64(actualBatchSize))
        return actualBatchSize
    }

    /**
     * 高性能批量出队操作 - 减少原子操作
     */
    public func dequeueBatch(maxCount: Int32): Array<T> {
        let results = ArrayList<T>()
        if (maxCount <= 0) {
            return results.toArray()
        }

        let currentHead = head.load()
        let currentTail = tail.load()
        let availableItems = currentTail - currentHead

        if (availableItems <= 0) {
            return results.toArray()
        }

        let actualBatchSize = if (Int64(maxCount) <= availableItems) {
            maxCount
        } else {
            Int32(availableItems)
        }

        // 批量读取数据 - 使用更高效的方式
        var successCount: Int32 = 0
        for (i in 0..Int64(actualBatchSize)) {
            let index = (currentHead + i) & mask
            let slot = buffer[index]

            // 尝试读取槽位
            var retries = 0
            var success = false
            while (retries < 50 && !success) {  // 减少重试次数
                if (slot.tryStartRead()) {
                    match (slot.finishRead()) {
                        case Some(item) =>
                            results.append(item)
                            successCount += 1
                            success = true
                        case None => break
                    }
                }
                retries += 1
            }

            if (!success) {
                break  // 如果读取失败，停止批量操作
            }
        }

        // 更新统计
        if (successCount > 0) {
            // 尝试推进head指针
            head.compareAndSwap(currentHead, currentHead + Int64(successCount))
            dequeueCount.fetchAdd(Int64(successCount))
        }

        return results.toArray()
    }

    /**
     * 快速入队 - 无重试版本，适用于高性能场景
     */
    public func fastEnqueue(item: T): Bool {
        let currentTail = tail.load()
        let currentHead = head.load()

        // 快速检查是否有空间
        if (currentTail - currentHead >= queueCapacity) {
            failedEnqueues.fetchAdd(1)
            return false
        }

        let index = currentTail & mask
        let slot = buffer[index]

        // 只尝试一次，不重试
        if (slot.tryStartWrite()) {
            if (tail.compareAndSwap(currentTail, currentTail + 1)) {
                slot.finishWrite(item)
                enqueueCount.fetchAdd(1)
                return true
            } else {
                slot.cancelWrite()
            }
        }

        failedEnqueues.fetchAdd(1)
        return false
    }

    /**
     * 快速出队 - 无重试版本，适用于高性能场景
     */
    public func fastDequeue(): Option<T> {
        let currentHead = head.load()
        let currentTail = tail.load()

        // 快速检查是否有数据
        if (currentHead >= currentTail) {
            failedDequeues.fetchAdd(1)
            return None
        }

        let index = currentHead & mask
        let slot = buffer[index]

        // 只尝试一次，不重试
        if (slot.tryStartRead()) {
            if (head.compareAndSwap(currentHead, currentHead + 1)) {
                let result = slot.finishRead()
                dequeueCount.fetchAdd(1)
                return result
            } else {
                slot.cancelRead()
            }
        }

        failedDequeues.fetchAdd(1)
        return None
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
