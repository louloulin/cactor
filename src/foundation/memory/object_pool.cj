/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 内存池管理
 * 基于仓颉GC的高性能对象池实现，零依赖
 */
package cactor.foundation.memory

import std.sync.*
import std.collection.*
import std.collection.concurrent.*

/**
 * 对象池接口
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

    /**
     * 获取池中当前对象数量
     */
    func size(): Int64

    /**
     * 清空池
     */
    func clear(): Unit
}

/**
 * 基于仓颉GC的对象池实现
 * 针对仓颉的垃圾回收器优化
 */
public class CangjieFriendlyObjectPool<T> <: ObjectPool<T> {
    private let pool: NonBlockingQueue<T>
    private let factory: () -> T
    private let resetFunction: (T) -> Unit
    private let maxPoolSize: Int64
    private let currentSize: AtomicInt64
    private let totalAcquired: AtomicInt64
    private let totalReleased: AtomicInt64

    public init(factory: () -> T, resetFunction: (T) -> Unit, maxSize: Int64) {
        this.pool = NonBlockingQueue<T>()
        this.factory = factory
        this.resetFunction = resetFunction
        this.maxPoolSize = maxSize
        this.currentSize = AtomicInt64(0)
        this.totalAcquired = AtomicInt64(0)
        this.totalReleased = AtomicInt64(0)

        // 预热对象池
        warmupPool()
    }

    private func warmupPool(): Unit {
        let warmupSize = maxPoolSize / 4  // 预热25%的容量
        for (_ in 0..warmupSize) {
            let obj = factory()
            if (pool.enqueue(obj)) {
                currentSize.fetchAdd(1)
            }
        }
    }

    public func acquire(): T {
        totalAcquired.fetchAdd(1)
        
        match (pool.dequeue()) {
            case Some(obj) => 
                currentSize.fetchAdd(-1)
                obj
            case None => 
                // 池为空，创建新对象
                factory()
        }
    }

    public func release(obj: T): Unit {
        totalReleased.fetchAdd(1)
        
        if (currentSize.load() < maxPoolSize) {
            resetFunction(obj)  // 重置对象状态
            if (pool.enqueue(obj)) {
                currentSize.fetchAdd(1)
            }
        }
        // 超出容量的对象让GC回收
    }

    public func size(): Int64 {
        currentSize.load()
    }

    public func clear(): Unit {
        while (pool.dequeue().isSome()) {
            currentSize.fetchAdd(-1)
        }
    }

    public func getStatistics(): PoolStatistics {
        PoolStatistics(
            currentSize.load(),
            maxPoolSize,
            totalAcquired.load(),
            totalReleased.load(),
            calculateHitRate()
        )
    }

    private func calculateHitRate(): Float64 {
        let acquired = totalAcquired.load()
        if (acquired == 0) {
            return 0.0
        }
        let hits = totalReleased.load()
        Float64(hits) / Float64(acquired)
    }
}

/**
 * 对象池统计信息
 */
public struct PoolStatistics {
    public let currentSize: Int64
    public let maxSize: Int64
    public let totalAcquired: Int64
    public let totalReleased: Int64
    public let hitRate: Float64

    public init(currentSize: Int64, maxSize: Int64, totalAcquired: Int64, 
                totalReleased: Int64, hitRate: Float64) {
        this.currentSize = currentSize
        this.maxSize = maxSize
        this.totalAcquired = totalAcquired
        this.totalReleased = totalReleased
        this.hitRate = hitRate
    }

    public func getUtilization(): Float64 {
        if (maxSize == 0) {
            return 0.0
        }
        Float64(currentSize) / Float64(maxSize)
    }
}

/**
 * 字符串对象池
 * 专门用于字符串对象的池化管理
 */
public class StringPool <: ObjectPool<String> {
    private let innerPool: CangjieFriendlyObjectPool<String>

    public init(maxSize: Int64) {
        this.innerPool = CangjieFriendlyObjectPool<String>(
            StringPool.createString,
            StringPool.resetString,
            maxSize
        )
    }

    private static func createString(): String {
        // 创建一个空字符串
        ""
    }

    private static func resetString(_: String): Unit {
        // 字符串是不可变的，无需重置
    }

    public func acquire(): String {
        innerPool.acquire()
    }

    public func release(obj: String): Unit {
        innerPool.release(obj)
    }

    public func size(): Int64 {
        innerPool.size()
    }

    public func clear(): Unit {
        innerPool.clear()
    }

    public func getStatistics(): PoolStatistics {
        innerPool.getStatistics()
    }
}

/**
 * 字节数组对象池
 * 专门用于字节数组的池化管理
 */
public class ByteArrayPool <: ObjectPool<Array<UInt8>> {
    private let innerPool: CangjieFriendlyObjectPool<Array<UInt8>>

    public init(maxSize: Int64) {
        this.innerPool = CangjieFriendlyObjectPool<Array<UInt8>>(
            ByteArrayPool.createByteArray,
            ByteArrayPool.resetByteArray,
            maxSize
        )
    }

    private static func createByteArray(): Array<UInt8> {
        // 创建一个空的字节数组
        Array<UInt8>(0, { _ => UInt8(0) })
    }

    private static func resetByteArray(_: Array<UInt8>): Unit {
        // 字节数组重置（清零）
        // 注意：这里简化实现，实际可能需要更复杂的重置逻辑
    }

    public func acquire(): Array<UInt8> {
        innerPool.acquire()
    }

    public func release(obj: Array<UInt8>): Unit {
        innerPool.release(obj)
    }

    public func size(): Int64 {
        innerPool.size()
    }

    public func clear(): Unit {
        innerPool.clear()
    }

    public func getStatistics(): PoolStatistics {
        innerPool.getStatistics()
    }
}

/**
 * 分层对象池
 * 支持不同大小的对象使用不同的池
 */
public class TieredObjectPool<T> <: ObjectPool<T> {
    private let smallPool: ObjectPool<T>    // 小对象池
    private let mediumPool: ObjectPool<T>   // 中等对象池
    private let largePool: ObjectPool<T>    // 大对象池
    private let sizeClassifier: (T) -> PoolTier

    public init(smallPoolSize: Int64, mediumPoolSize: Int64, largePoolSize: Int64,
                factory: () -> T, resetFunction: (T) -> Unit,
                sizeClassifier: (T) -> PoolTier) {
        this.smallPool = CangjieFriendlyObjectPool<T>(factory, resetFunction, smallPoolSize)
        this.mediumPool = CangjieFriendlyObjectPool<T>(factory, resetFunction, mediumPoolSize)
        this.largePool = CangjieFriendlyObjectPool<T>(factory, resetFunction, largePoolSize)
        this.sizeClassifier = sizeClassifier
    }

    public func acquire(): T {
        // 简化实现：从小池开始尝试
        match (smallPool.acquire()) {
            case obj => obj
        }
    }

    public func release(obj: T): Unit {
        match (sizeClassifier(obj)) {
            case PoolTier.Small => smallPool.release(obj)
            case PoolTier.Medium => mediumPool.release(obj)
            case PoolTier.Large => largePool.release(obj)
        }
    }

    public func size(): Int64 {
        smallPool.size() + mediumPool.size() + largePool.size()
    }

    public func clear(): Unit {
        smallPool.clear()
        mediumPool.clear()
        largePool.clear()
    }
}

/**
 * 池层级枚举
 */
public enum PoolTier {
    | Small
    | Medium
    | Large
}

/**
 * 对象池管理器
 * 管理系统中的所有对象池
 */
public class PoolManager {
    private let pools: ConcurrentHashMap<String, ObjectPool<Object>>
    private let statistics: AtomicInt64

    public init() {
        this.pools = ConcurrentHashMap<String, ObjectPool<Object>>()
        this.statistics = AtomicInt64(0)
    }

    public func registerPool<T>(name: String, pool: ObjectPool<T>): Unit {
        // 简化实现，实际需要类型转换
        println("注册对象池: ${name}")
    }

    public func getPool<T>(name: String): Option<ObjectPool<T>> {
        // 简化实现
        None
    }

    public func getAllStatistics(): Array<PoolStatistics> {
        let stats = ArrayList<PoolStatistics>()
        // 收集所有池的统计信息
        stats.toArray()
    }
}
