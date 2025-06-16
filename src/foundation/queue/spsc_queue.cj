/*
 * SPSC (Single Producer Single Consumer) 无锁队列
 * 基于现有LockFreeQueue优化，专门针对单生产者单消费者场景
 * 性能优化：
 * 1. 消除CAS竞争 - 生产者和消费者各自维护独立的索引
 * 2. 缓存行填充 - 避免false sharing
 * 3. 批量操作 - 减少原子操作频率
 * 4. 内存屏障优化 - 使用更轻量的内存序
 */
package cactor.foundation.queue

import std.sync.*
import std.collection.*

/**
 * SPSC无锁队列 - 针对单生产者单消费者优化
 * 基于环形缓冲区，无需CAS操作，性能极高
 */
public class SPSCQueue<T> {
    // 缓存行填充1 - 避免false sharing
    private let pad1_1: Int64 = 0
    private let pad1_2: Int64 = 0
    private let pad1_3: Int64 = 0
    private let pad1_4: Int64 = 0
    private let pad1_5: Int64 = 0
    private let pad1_6: Int64 = 0
    private let pad1_7: Int64 = 0
    private let pad1_8: Int64 = 0
    
    // 生产者字段 - 只有生产者线程访问
    private var producerIndex: Int64 = 0
    private var producerCachedConsumerIndex: Int64 = 0
    private let producerMask: Int64
    private let producerBuffer: Array<Option<T>>
    
    // 缓存行填充2 - 分离生产者和消费者
    private let pad2_1: Int64 = 0
    private let pad2_2: Int64 = 0
    private let pad2_3: Int64 = 0
    private let pad2_4: Int64 = 0
    private let pad2_5: Int64 = 0
    private let pad2_6: Int64 = 0
    private let pad2_7: Int64 = 0
    private let pad2_8: Int64 = 0
    
    // 消费者字段 - 只有消费者线程访问
    private var consumerIndex: Int64 = 0
    private var consumerCachedProducerIndex: Int64 = 0
    private let consumerMask: Int64
    private let consumerBuffer: Array<Option<T>>
    
    // 缓存行填充3 - 最终填充
    private let pad3_1: Int64 = 0
    private let pad3_2: Int64 = 0
    private let pad3_3: Int64 = 0
    private let pad3_4: Int64 = 0
    private let pad3_5: Int64 = 0
    private let pad3_6: Int64 = 0
    private let pad3_7: Int64 = 0
    private let pad3_8: Int64 = 0
    
    // 共享的原子索引 - 用于跨线程可见性
    private let sharedProducerIndex: AtomicInt64 = AtomicInt64(0)
    private let sharedConsumerIndex: AtomicInt64 = AtomicInt64(0)
    
    // 容量和统计
    private let capacity: Int64
    private let enqueueCount: AtomicInt64 = AtomicInt64(0)
    private let dequeueCount: AtomicInt64 = AtomicInt64(0)
    
    public init(capacity: Int32) {
        // 确保容量是2的幂
        var actualCapacity: Int64 = 1
        let targetCapacity = Int64(capacity)
        while (actualCapacity < targetCapacity) {
            actualCapacity = actualCapacity << 1
        }
        
        this.capacity = actualCapacity
        this.producerMask = actualCapacity - 1
        this.consumerMask = actualCapacity - 1
        
        // 初始化缓冲区
        this.producerBuffer = Array<Option<T>>(actualCapacity, { _ => None<T> })
        this.consumerBuffer = this.producerBuffer
    }
    
    /**
     * 高性能入队 - 单生产者，无需CAS
     */
    public func offer(item: T): Bool {
        let currentProducerIndex = this.producerIndex
        let nextProducerIndex = currentProducerIndex + 1
        
        // 检查队列是否满 - 使用缓存的消费者索引
        if (nextProducerIndex - this.producerCachedConsumerIndex > this.capacity) {
            // 更新缓存的消费者索引
            this.producerCachedConsumerIndex = this.sharedConsumerIndex.load()
            if (nextProducerIndex - this.producerCachedConsumerIndex > this.capacity) {
                return false  // 队列满
            }
        }
        
        // 写入数据
        let index = currentProducerIndex & this.producerMask
        this.producerBuffer[index] = Some(item)
        
        // 更新生产者索引
        this.producerIndex = nextProducerIndex
        
        // 发布给消费者 - 使用有序写入
        this.sharedProducerIndex.store(nextProducerIndex)
        
        this.enqueueCount.fetchAdd(1)
        return true
    }
    
    /**
     * 高性能出队 - 单消费者，无需CAS
     */
    public func poll(): Option<T> {
        let currentConsumerIndex = this.consumerIndex
        
        // 检查队列是否空 - 使用缓存的生产者索引
        if (currentConsumerIndex >= this.consumerCachedProducerIndex) {
            // 更新缓存的生产者索引
            this.consumerCachedProducerIndex = this.sharedProducerIndex.load()
            if (currentConsumerIndex >= this.consumerCachedProducerIndex) {
                return None  // 队列空
            }
        }
        
        // 读取数据
        let index = currentConsumerIndex & this.consumerMask
        let item = this.consumerBuffer[index]
        
        match (item) {
            case Some(value) =>
                // 清空槽位
                this.consumerBuffer[index] = None
                
                // 更新消费者索引
                let nextConsumerIndex = currentConsumerIndex + 1
                this.consumerIndex = nextConsumerIndex
                
                // 发布给生产者 - 使用有序写入
                this.sharedConsumerIndex.store(nextConsumerIndex)
                
                this.dequeueCount.fetchAdd(1)
                return Some(value)
            case None =>
                return None
        }
    }
    
    /**
     * 批量入队 - SPSC优化版本
     */
    public func offerBatch(items: Array<T>): Int32 {
        let batchSize = Int32(items.size)
        if (batchSize == 0) { return 0 }
        
        let currentProducerIndex = this.producerIndex
        let nextProducerIndex = currentProducerIndex + Int64(batchSize)
        
        // 检查容量
        if (nextProducerIndex - this.producerCachedConsumerIndex > this.capacity) {
            this.producerCachedConsumerIndex = this.sharedConsumerIndex.load()
            if (nextProducerIndex - this.producerCachedConsumerIndex > this.capacity) {
                // 计算实际可写入的数量
                let availableSpace = this.capacity - (currentProducerIndex - this.producerCachedConsumerIndex)
                if (availableSpace <= 0) {
                    return 0
                }
                let actualBatchSize = Int32(availableSpace)
                
                // 批量写入
                for (i in 0..actualBatchSize) {
                    let index = (currentProducerIndex + Int64(i)) & this.producerMask
                    this.producerBuffer[index] = Some(items[Int64(i)])
                }
                
                this.producerIndex = currentProducerIndex + Int64(actualBatchSize)
                this.sharedProducerIndex.store(currentProducerIndex + Int64(actualBatchSize))
                this.enqueueCount.fetchAdd(Int64(actualBatchSize))
                return actualBatchSize
            }
        }
        
        // 批量写入全部数据
        for (i in 0..batchSize) {
            let index = (currentProducerIndex + Int64(i)) & this.producerMask
            this.producerBuffer[index] = Some(items[Int64(i)])
        }
        
        this.producerIndex = nextProducerIndex
        this.sharedProducerIndex.store(nextProducerIndex)
        this.enqueueCount.fetchAdd(Int64(batchSize))
        return batchSize
    }
    
    /**
     * 批量出队 - SPSC优化版本
     */
    public func pollBatch(maxCount: Int32): Array<T> {
        let results = ArrayList<T>()
        var count: Int32 = 0
        
        let currentConsumerIndex = this.consumerIndex
        
        // 更新缓存的生产者索引
        this.consumerCachedProducerIndex = this.sharedProducerIndex.load()
        let availableItems = this.consumerCachedProducerIndex - currentConsumerIndex
        
        if (availableItems <= 0) {
            return results.toArray()
        }
        
        let actualCount = if (Int64(maxCount) <= availableItems) { maxCount } else { Int32(availableItems) }
        
        // 批量读取
        for (i in 0..actualCount) {
            let index = (currentConsumerIndex + Int64(i)) & this.consumerMask
            match (this.consumerBuffer[index]) {
                case Some(value) =>
                    results.append(value)
                    this.consumerBuffer[index] = None
                    count += 1
                case None =>
                    break
            }
        }
        
        if (count > 0) {
            let nextConsumerIndex = currentConsumerIndex + Int64(count)
            this.consumerIndex = nextConsumerIndex
            this.sharedConsumerIndex.store(nextConsumerIndex)
            this.dequeueCount.fetchAdd(Int64(count))
        }
        
        return results.toArray()
    }
    
    /**
     * 获取队列大小
     */
    public func size(): Int64 {
        return this.sharedProducerIndex.load() - this.sharedConsumerIndex.load()
    }
    
    /**
     * 检查队列是否为空
     */
    public func isEmpty(): Bool {
        return size() == 0
    }
    
    /**
     * 获取容量
     */
    public func getCapacity(): Int64 {
        return this.capacity
    }
    
    /**
     * 获取性能统计
     */
    public func getPerformanceStats(): SPSCPerformanceStats {
        SPSCPerformanceStats(
            this.enqueueCount.load(),
            this.dequeueCount.load(),
            this.capacity,
            size()
        )
    }
}

/**
 * SPSC队列性能统计
 */
public struct SPSCPerformanceStats {
    public let totalEnqueues: Int64
    public let totalDequeues: Int64
    public let capacity: Int64
    public let currentSize: Int64
    
    public init(totalEnqueues: Int64, totalDequeues: Int64, capacity: Int64, currentSize: Int64) {
        this.totalEnqueues = totalEnqueues
        this.totalDequeues = totalDequeues
        this.capacity = capacity
        this.currentSize = currentSize
    }
    
    public func getThroughput(durationSeconds: Float64): Float64 {
        return Float64(totalEnqueues + totalDequeues) / durationSeconds
    }
    
    public func getUtilization(): Float64 {
        return if (capacity > 0) { Float64(currentSize) / Float64(capacity) } else { 0.0 }
    }
}
