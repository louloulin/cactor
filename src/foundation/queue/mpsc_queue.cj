/*
 * MPSC (Multi Producer Single Consumer) 无锁队列
 * 基于现有LockFreeQueue优化，专门针对多生产者单消费者场景
 * 性能优化：
 * 1. 生产者使用CAS竞争，消费者无锁
 * 2. 缓存行填充避免false sharing
 * 3. 批量操作减少竞争
 * 4. 适应性退避策略
 */
package cactor.foundation.queue

import std.sync.*
import std.collection.*

/**
 * MPSC无锁队列 - 针对多生产者单消费者优化
 * 基于JCTools设计原理，结合现有LockFreeQueue的优势
 */
public class MPSCQueue<T> {
    // 缓存行填充1 - 避免false sharing
    private let pad1_1: Int64 = 0
    private let pad1_2: Int64 = 0
    private let pad1_3: Int64 = 0
    private let pad1_4: Int64 = 0
    private let pad1_5: Int64 = 0
    private let pad1_6: Int64 = 0
    private let pad1_7: Int64 = 0
    private let pad1_8: Int64 = 0
    
    // 生产者字段 - 多个生产者线程竞争
    private let producerIndex: AtomicInt64 = AtomicInt64(0)
    private let producerLimit: AtomicInt64 = AtomicInt64(0)
    private var producerMask: Int64 = 0
    private var producerBuffer: Array<Option<T>>
    
    // 缓存行填充2 - 分离生产者和消费者
    private let pad2_1: Int64 = 0
    private let pad2_2: Int64 = 0
    private let pad2_3: Int64 = 0
    private let pad2_4: Int64 = 0
    private let pad2_5: Int64 = 0
    private let pad2_6: Int64 = 0
    private let pad2_7: Int64 = 0
    private let pad2_8: Int64 = 0
    
    // 消费者字段 - 单个消费者线程，无需原子操作
    private var consumerIndex: Int64 = 0
    private var consumerMask: Int64 = 0
    private var consumerBuffer: Array<Option<T>>
    
    // 缓存行填充3 - 最终填充
    private let pad3_1: Int64 = 0
    private let pad3_2: Int64 = 0
    private let pad3_3: Int64 = 0
    private let pad3_4: Int64 = 0
    private let pad3_5: Int64 = 0
    private let pad3_6: Int64 = 0
    private let pad3_7: Int64 = 0
    private let pad3_8: Int64 = 0
    
    // 共享的消费者索引 - 供生产者读取
    private let sharedConsumerIndex: AtomicInt64 = AtomicInt64(0)
    
    // 容量和统计
    private let initialCapacity: Int64
    private let maxCapacity: Int64 = 16777216  // 16M最大容量
    private let enqueueCount: AtomicInt64 = AtomicInt64(0)
    private let dequeueCount: AtomicInt64 = AtomicInt64(0)
    private let expansionCount: AtomicInt64 = AtomicInt64(0)
    
    // 适应性退避
    private let maxRetries: Int32 = 1000
    private let backoffThreshold: Int32 = 100
    
    public init(capacity: Int32) {
        // 确保容量是2的幂
        var actualCapacity: Int64 = 1
        let targetCapacity = Int64(capacity)
        while (actualCapacity < targetCapacity) {
            actualCapacity = actualCapacity << 1
        }
        
        this.initialCapacity = actualCapacity
        this.producerMask = actualCapacity - 1
        this.consumerMask = actualCapacity - 1
        
        // 初始化缓冲区
        this.producerBuffer = Array<Option<T>>(actualCapacity, { _ => None<T> })
        this.consumerBuffer = this.producerBuffer
        
        // 设置初始限制
        this.producerLimit.store(actualCapacity - 1)
    }
    
    /**
     * 多生产者入队 - 使用CAS竞争
     */
    public func offer(item: T): Bool {
        var retries: Int32 = 0
        
        while (retries < this.maxRetries) {
            let currentProducerIndex = this.producerIndex.load()
            let currentProducerLimit = this.producerLimit.load()
            
            // 检查是否需要扩容
            if (currentProducerIndex >= currentProducerLimit) {
                if (this.tryExpansion()) {
                    continue  // 扩容后重试
                } else {
                    return false  // 扩容失败
                }
            }
            
            // 尝试CAS获取槽位
            if (this.producerIndex.compareAndSwap(currentProducerIndex, currentProducerIndex + 1)) {
                let index = currentProducerIndex & this.producerMask
                
                // 写入数据
                this.producerBuffer[index] = Some(item)
                
                this.enqueueCount.fetchAdd(1)
                return true
            }
            
            retries += 1
            
            // 适应性退避
            if (retries > this.backoffThreshold) {
                // 简单的退避策略
                var backoff: Int32 = 0
                let backoffLimit = retries - this.backoffThreshold
                while (backoff < backoffLimit && backoff < 100) {
                    backoff += 1
                }
            }
        }
        
        return false
    }
    
    /**
     * 单消费者出队 - 无需CAS
     */
    public func poll(): Option<T> {
        let currentConsumerIndex = this.consumerIndex
        let currentProducerIndex = this.producerIndex.load()
        
        // 队列为空
        if (currentConsumerIndex >= currentProducerIndex) {
            return None
        }
        
        let index = currentConsumerIndex & this.consumerMask
        let item = this.consumerBuffer[index]
        
        match (item) {
            case Some(value) =>
                // 清空槽位
                this.consumerBuffer[index] = None
                
                // 更新消费者索引
                this.consumerIndex = currentConsumerIndex + 1
                
                // 更新共享的消费者索引供生产者读取
                this.sharedConsumerIndex.store(currentConsumerIndex + 1)
                
                this.dequeueCount.fetchAdd(1)
                return Some(value)
            case None =>
                // 可能生产者还没写入，短暂自旋
                var spinCount: Int32 = 0
                while (spinCount < 10) {
                    match (this.consumerBuffer[index]) {
                        case Some(value) =>
                            this.consumerBuffer[index] = None
                            this.consumerIndex = currentConsumerIndex + 1
                            this.sharedConsumerIndex.store(currentConsumerIndex + 1)
                            this.dequeueCount.fetchAdd(1)
                            return Some(value)
                        case None => spinCount += 1
                    }
                }
                return None
        }
    }
    
    /**
     * 批量入队 - 多生产者优化
     */
    public func offerBatch(items: Array<T>): Int32 {
        let batchSize = Int32(items.size)
        if (batchSize == 0) { return 0 }
        
        // 尝试一次性预留多个槽位
        var retries: Int32 = 0
        while (retries < this.maxRetries) {
            let currentProducerIndex = this.producerIndex.load()
            let currentProducerLimit = this.producerLimit.load()
            
            let availableSpace = currentProducerLimit - currentProducerIndex
            let actualBatchSize = if (Int64(batchSize) <= availableSpace) { 
                batchSize 
            } else { 
                Int32(availableSpace) 
            }
            
            if (actualBatchSize <= 0) {
                if (this.tryExpansion()) {
                    continue
                } else {
                    return 0
                }
            }
            
            // 一次性CAS预留多个槽位
            if (this.producerIndex.compareAndSwap(currentProducerIndex, currentProducerIndex + Int64(actualBatchSize))) {
                // 批量写入
                for (i in 0..actualBatchSize) {
                    let index = (currentProducerIndex + Int64(i)) & this.producerMask
                    this.producerBuffer[index] = Some(items[Int64(i)])
                }
                
                this.enqueueCount.fetchAdd(Int64(actualBatchSize))
                return actualBatchSize
            }
            
            retries += 1
        }
        
        return 0
    }
    
    /**
     * 批量出队 - 单消费者优化
     */
    public func pollBatch(maxCount: Int32): Array<T> {
        let results = ArrayList<T>()
        var count: Int32 = 0
        
        while (count < maxCount) {
            match (this.poll()) {
                case Some(item) =>
                    results.append(item)
                    count += 1
                case None => break
            }
        }
        
        return results.toArray()
    }
    
    /**
     * 尝试扩容 - 动态增长避免队列满
     */
    private func tryExpansion(): Bool {
        let currentCapacity = this.producerMask + 1
        if (currentCapacity >= this.maxCapacity) {
            return false  // 已达最大容量
        }
        
        let newCapacity = currentCapacity * 2
        let newBuffer = Array<Option<T>>(newCapacity, { _ => None<T> })
        
        // 复制现有数据到新缓冲区
        let currentConsumerIndex = this.sharedConsumerIndex.load()
        let currentProducerIndex = this.producerIndex.load()
        
        for (i in currentConsumerIndex..currentProducerIndex) {
            let oldIndex = i & this.producerMask
            let newIndex = i & (newCapacity - 1)
            newBuffer[newIndex] = this.producerBuffer[oldIndex]
        }
        
        // 更新缓冲区和掩码
        this.producerBuffer = newBuffer
        this.consumerBuffer = newBuffer
        this.producerMask = newCapacity - 1
        this.consumerMask = newCapacity - 1
        
        // 更新生产者限制
        let newLimit = currentConsumerIndex + Int64(Float64(newCapacity) * 0.75)
        this.producerLimit.store(newLimit)
        
        this.expansionCount.fetchAdd(1)
        return true
    }
    
    /**
     * 获取队列大小
     */
    public func size(): Int64 {
        return this.producerIndex.load() - this.sharedConsumerIndex.load()
    }
    
    /**
     * 检查队列是否为空
     */
    public func isEmpty(): Bool {
        return size() == 0
    }
    
    /**
     * 获取当前容量
     */
    public func getCapacity(): Int64 {
        return this.producerMask + 1
    }
    
    /**
     * 获取性能统计
     */
    public func getPerformanceStats(): MPSCPerformanceStats {
        MPSCPerformanceStats(
            this.enqueueCount.load(),
            this.dequeueCount.load(),
            this.expansionCount.load(),
            getCapacity(),
            size()
        )
    }
}

/**
 * MPSC队列性能统计
 */
public struct MPSCPerformanceStats {
    public let totalEnqueues: Int64
    public let totalDequeues: Int64
    public let expansionCount: Int64
    public let currentCapacity: Int64
    public let currentSize: Int64
    
    public init(totalEnqueues: Int64, totalDequeues: Int64, expansionCount: Int64, 
               currentCapacity: Int64, currentSize: Int64) {
        this.totalEnqueues = totalEnqueues
        this.totalDequeues = totalDequeues
        this.expansionCount = expansionCount
        this.currentCapacity = currentCapacity
        this.currentSize = currentSize
    }
    
    public func getThroughput(durationSeconds: Float64): Float64 {
        return Float64(totalEnqueues + totalDequeues) / durationSeconds
    }
    
    public func getUtilization(): Float64 {
        return if (currentCapacity > 0) { Float64(currentSize) / Float64(currentCapacity) } else { 0.0 }
    }
    
    public func getExpansionRate(): Float64 {
        return Float64(currentCapacity) / Float64(1024)  // 相对于初始1K容量的扩展倍数
    }
}
