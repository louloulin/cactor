/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 4: 对象池化系统
 * 高性能对象重用，减少GC压力和内存分配开销
 */
package cactor.core.lightweight

import std.sync.*
import std.collection.*
import std.time.*

/**
 * 通用对象池接口
 */
public interface ObjectPool<T> {
    func acquire(): T
    func release(obj: T): Unit
    func size(): Int64
    func clear(): Unit
}

/**
 * 高性能上下文池
 * 使用无锁栈结构实现快速获取和释放
 */
public class ContextPool <: ObjectPool<PooledContext> {
    private let pool: Array<PooledContext>
    private let head: AtomicInt64
    private let capacity: Int64
    private let totalCreated: AtomicInt64
    private let totalAcquired: AtomicInt64
    private let totalReleased: AtomicInt64
    
    public init(capacity: Int64) {
        this.capacity = capacity
        this.pool = Array<PooledContext>(capacity, { i => PooledContext() })
        this.head = AtomicInt64(capacity - 1)
        this.totalCreated = AtomicInt64(capacity)
        this.totalAcquired = AtomicInt64(0)
        this.totalReleased = AtomicInt64(0)
    }
    
    public func acquire(): PooledContext {
        totalAcquired.fetchAdd(1)
        
        let currentHead = head.load()
        if (currentHead >= 0) {
            // 尝试从池中获取
            if (head.compareAndSwap(currentHead, currentHead - 1)) {
                return pool[currentHead]
            }
        }
        
        // 池为空，创建新对象
        totalCreated.fetchAdd(1)
        return PooledContext()
    }
    
    public func release(context: PooledContext): Unit {
        if (!context.isAvailable()) {
            context.reset()
        }
        
        totalReleased.fetchAdd(1)
        
        let currentHead = head.load()
        if (currentHead < capacity - 1) {
            // 尝试放回池中
            if (head.compareAndSwap(currentHead, currentHead + 1)) {
                pool[currentHead + 1] = context
                return
            }
        }
        
        // 池已满，丢弃对象（让GC回收）
    }
    
    public func size(): Int64 {
        let currentHead = head.load()
        return if (currentHead >= 0) { currentHead + 1 } else { 0 }
    }
    
    public func clear(): Unit {
        head.store(-1)
    }
    
    public func getStats(): PoolStats {
        PoolStats(
            capacity,
            size(),
            totalCreated.load(),
            totalAcquired.load(),
            totalReleased.load()
        )
    }
}

/**
 * 内存对齐的缓冲区池
 * 针对消息缓冲区优化，支持不同大小的缓冲区
 */
public class AlignedBufferPool <: ObjectPool<AlignedBuffer> {
    private let pools: Array<SizeClassPool>
    private let sizeClasses: Array<Int64>
    private let alignment: Int64
    
    public init(alignment: Int64) {
        this.alignment = alignment
        this.sizeClasses = [64, 128, 256, 512, 1024, 2048, 4096]  // 7个大小类别
        this.pools = Array<SizeClassPool>(Int64(sizeClasses.size), { i =>
            SizeClassPool(sizeClasses[i], alignment, 100)  // 每个大小类别100个对象
        })
    }
    
    public func acquire(): AlignedBuffer {
        acquireWithSize(256)  // 默认大小
    }
    
    public func acquireWithSize(size: Int64): AlignedBuffer {
        let poolIndex = findSizeClassIndex(size)
        return pools[poolIndex].acquire()
    }
    
    public func release(buffer: AlignedBuffer): Unit {
        let poolIndex = findSizeClassIndex(buffer.getSize())
        pools[poolIndex].release(buffer)
    }
    
    private func findSizeClassIndex(size: Int64): Int64 {
        for (i in 0..Int64(sizeClasses.size)) {
            if (size <= sizeClasses[i]) {
                return i
            }
        }
        return Int64(sizeClasses.size) - 1  // 最大大小类别
    }
    
    public func size(): Int64 {
        var total: Int64 = 0
        for (pool in pools) {
            total += pool.size()
        }
        return total
    }
    
    public func clear(): Unit {
        for (pool in pools) {
            pool.clear()
        }
    }
    
    public func getAllStats(): Array<PoolStats> {
        let stats = Array<PoolStats>(Int64(pools.size), { i =>
            pools[i].getStats()
        })
        return stats
    }
}

/**
 * 大小类别池
 */
public class SizeClassPool <: ObjectPool<AlignedBuffer> {
    private let bufferSize: Int64
    private let alignment: Int64
    private let pool: Array<AlignedBuffer>
    private let head: AtomicInt64
    private let capacity: Int64
    private let totalCreated: AtomicInt64
    private let totalAcquired: AtomicInt64
    private let totalReleased: AtomicInt64
    
    public init(bufferSize: Int64, alignment: Int64, capacity: Int64) {
        this.bufferSize = bufferSize
        this.alignment = alignment
        this.capacity = capacity
        this.pool = Array<AlignedBuffer>(capacity, { i => 
            AlignedBuffer(bufferSize, alignment)
        })
        this.head = AtomicInt64(capacity - 1)
        this.totalCreated = AtomicInt64(capacity)
        this.totalAcquired = AtomicInt64(0)
        this.totalReleased = AtomicInt64(0)
    }
    
    public func acquire(): AlignedBuffer {
        totalAcquired.fetchAdd(1)
        
        let currentHead = head.load()
        if (currentHead >= 0) {
            if (head.compareAndSwap(currentHead, currentHead - 1)) {
                let buffer = pool[currentHead]
                buffer.reset()
                return buffer
            }
        }
        
        // 池为空，创建新缓冲区
        totalCreated.fetchAdd(1)
        return AlignedBuffer(bufferSize, alignment)
    }
    
    public func release(buffer: AlignedBuffer): Unit {
        if (buffer.getSize() != bufferSize) {
            return  // 大小不匹配，不放回池中
        }
        
        totalReleased.fetchAdd(1)
        
        let currentHead = head.load()
        if (currentHead < capacity - 1) {
            if (head.compareAndSwap(currentHead, currentHead + 1)) {
                pool[currentHead + 1] = buffer
                return
            }
        }
    }
    
    public func size(): Int64 {
        let currentHead = head.load()
        return if (currentHead >= 0) { currentHead + 1 } else { 0 }
    }
    
    public func clear(): Unit {
        head.store(-1)
    }
    
    public func getStats(): PoolStats {
        PoolStats(
            capacity,
            size(),
            totalCreated.load(),
            totalAcquired.load(),
            totalReleased.load()
        )
    }
}

/**
 * 内存对齐的缓冲区
 */
public class AlignedBuffer {
    private let data: Array<UInt8>
    private let size: Int64
    private let alignment: Int64
    private var position: Int64
    
    public init(size: Int64, alignment: Int64) {
        this.size = size
        this.alignment = alignment
        this.position = 0
        
        // 创建对齐的缓冲区
        let alignedSize = ((size + alignment - 1) / alignment) * alignment
        this.data = Array<UInt8>(alignedSize, { i => UInt8(0) })
    }
    
    public func reset(): Unit {
        position = 0
        // 清零缓冲区（可选，根据需要）
        for (i in 0..size) {
            data[i] = UInt8(0)
        }
    }
    
    public func write(bytes: Array<UInt8>): Bool {
        if (position + Int64(bytes.size) > size) {
            return false  // 缓冲区不足
        }
        
        for (i in 0..Int64(bytes.size)) {
            data[position + i] = bytes[i]
        }
        position += Int64(bytes.size)
        return true
    }
    
    public func read(length: Int64): Array<UInt8> {
        if (position + length > size) {
            return Array<UInt8>()  // 空数组
        }
        
        let result = Array<UInt8>(length, { i => data[position + i] })
        position += length
        return result
    }
    
    public func getSize(): Int64 {
        size
    }
    
    public func getAlignment(): Int64 {
        alignment
    }
    
    public func getPosition(): Int64 {
        position
    }
    
    public func remaining(): Int64 {
        size - position
    }
}

/**
 * 池统计信息
 */
public struct PoolStats {
    public let capacity: Int64
    public let currentSize: Int64
    public let totalCreated: Int64
    public let totalAcquired: Int64
    public let totalReleased: Int64
    
    public init(capacity: Int64, currentSize: Int64, totalCreated: Int64, 
                totalAcquired: Int64, totalReleased: Int64) {
        this.capacity = capacity
        this.currentSize = currentSize
        this.totalCreated = totalCreated
        this.totalAcquired = totalAcquired
        this.totalReleased = totalReleased
    }
    
    public func getHitRate(): Float64 {
        if (totalAcquired == 0) {
            return 0.0
        }
        return Float64(totalAcquired - totalCreated + capacity) / Float64(totalAcquired)
    }
    
    public func getUtilization(): Float64 {
        if (capacity == 0) {
            return 0.0
        }
        return Float64(capacity - currentSize) / Float64(capacity)
    }
}
