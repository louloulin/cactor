/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 对象池接口和实现
 */
package cactor.foundation.memory.object_pool

import std.sync.*

/**
 * 对象池接口
 * 用于高性能对象重用
 */
public interface ObjectPool<T> {
    /**
     * 从池中获取对象
     */
    func acquire(): T
    
    /**
     * 将对象归还到池中
     */
    func release(obj: T): Unit
}

/**
 * 简单对象池实现
 * 使用环形缓冲区和原子操作
 */
public class SimpleObjectPool<T> <: ObjectPool<T> {
    private let pool: Array<Option<T>>
    private let capacity: Int64
    private let head: AtomicInt64
    private let tail: AtomicInt64
    private let size: AtomicInt64
    private let factory: () -> T
    
    public init(capacity: Int64, factory: () -> T) {
        this.capacity = capacity
        this.factory = factory
        this.pool = Array<Option<T>>(capacity, { i => None })
        this.head = AtomicInt64(0)
        this.tail = AtomicInt64(0)
        this.size = AtomicInt64(0)
        
        // 预填充池
        for (i in 0..capacity) {
            pool[i] = Some(factory())
            size.fetchAdd(1)
        }
    }
    
    public func acquire(): T {
        if (size.load() > 0) {
            let currentHead = head.fetchAdd(1)
            let index = currentHead % capacity
            
            match (pool[index]) {
                case Some(obj) =>
                    pool[index] = None
                    size.fetchAdd(-1)
                    return obj
                case None =>
                    // 池中没有对象，创建新的
                    return factory()
            }
        } else {
            // 池为空，创建新对象
            return factory()
        }
    }
    
    public func release(obj: T): Unit {
        if (size.load() < capacity) {
            let currentTail = tail.fetchAdd(1)
            let index = currentTail % capacity
            
            pool[index] = Some(obj)
            size.fetchAdd(1)
        }
        // 如果池已满，直接丢弃对象
    }
    
    public func getCurrentSize(): Int64 {
        size.load()
    }
    
    public func getCapacity(): Int64 {
        capacity
    }
}

/**
 * 线程本地对象池
 * 每个线程维护自己的对象池，避免竞争
 */
public class ThreadLocalObjectPool<T> <: ObjectPool<T> {
    private let globalPool: SimpleObjectPool<T>
    private let localPools: Array<SimpleObjectPool<T>>
    private let poolCount: Int32
    
    public init(poolCount: Int32, poolCapacity: Int64, factory: () -> T) {
        this.poolCount = poolCount
        this.globalPool = SimpleObjectPool<T>(poolCapacity * Int64(poolCount), factory)
        this.localPools = Array<SimpleObjectPool<T>>(Int64(poolCount), { i =>
            SimpleObjectPool<T>(poolCapacity, factory)
        })
    }
    
    public func acquire(): T {
        // 简化实现：使用线程ID模拟
        let threadId = getCurrentThreadId() % Int64(poolCount)
        let localPool = localPools[threadId]
        
        // 先尝试从本地池获取
        if (localPool.getCurrentSize() > 0) {
            return localPool.acquire()
        } else {
            // 本地池为空，从全局池获取
            return globalPool.acquire()
        }
    }
    
    public func release(obj: T): Unit {
        let threadId = getCurrentThreadId() % Int64(poolCount)
        let localPool = localPools[threadId]
        
        // 优先归还到本地池
        if (localPool.getCurrentSize() < localPool.getCapacity()) {
            localPool.release(obj)
        } else {
            // 本地池已满，归还到全局池
            globalPool.release(obj)
        }
    }
    
    public func getTotalSize(): Int64 {
        var total: Int64 = 0
        for (pool in localPools) {
            total += pool.getCurrentSize()
        }
        return total + globalPool.getCurrentSize()
    }
}

/**
 * 获取当前线程ID的简化实现
 */
func getCurrentThreadId(): Int64 {
    // 简化实现，实际应该使用系统调用
    return 0
}
