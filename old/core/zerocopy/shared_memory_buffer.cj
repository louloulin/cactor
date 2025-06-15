/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 2: 共享内存缓冲区实现
 * 基于仓颉语言的高性能零拷贝共享内存系统
 */
package cactor.core.zerocopy

import std.sync.*
import std.time.*
import std.collection.*
import cactor.memory.*

/**
 * 共享内存缓冲区接口
 * 支持引用计数和自动内存管理
 */
public interface SharedMemoryBuffer {
    func getData(): Array<UInt8>
    func getSize(): UInt64
    func retain(): Unit
    func release(): Unit
    func getRefCount(): Int32
    func isValid(): Bool
    func getAlignment(): UInt64
}

/**
 * 内存池接口
 * 支持高性能内存分配和回收
 */
public interface MemoryPool {
    func allocate(size: UInt64): SharedMemoryBuffer
    func deallocate(buffer: SharedMemoryBuffer): Unit
    func getTotalAllocated(): UInt64
    func getTotalUsed(): UInt64
    func getFragmentation(): Float64
}

/**
 * 共享内存缓冲区实现
 * 使用原子引用计数确保线程安全
 */
public class SharedMemoryBufferImpl <: SharedMemoryBuffer {
    private let data: Array<UInt8>
    private let size: UInt64
    private let refCount: AtomicInt32
    private let pool: MemoryPool
    private let alignment: UInt64
    private var isReleased: AtomicBool

    public init(size: UInt64, pool: MemoryPool, alignment: UInt64) {
        this.size = size
        this.pool = pool
        this.alignment = alignment
        this.refCount = AtomicInt32(1)
        this.isReleased = AtomicBool(false)

        // 分配对齐的内存
        let alignedSize = ((size + alignment - 1) / alignment) * alignment
        this.data = Array<UInt8>(Int64(alignedSize), { i => UInt8(0) })
    }

    public func getData(): Array<UInt8> {
        if (isReleased.load()) {
            throw Exception("尝试访问已释放的共享内存缓冲区")
        }
        return data
    }

    public func getSize(): UInt64 {
        return size
    }

    public func getAlignment(): UInt64 {
        return alignment
    }

    public func retain(): Unit {
        if (isReleased.load()) {
            throw Exception("尝试保留已释放的共享内存缓冲区")
        }
        refCount.fetchAdd(1)
    }

    public func release(): Unit {
        if (isReleased.load()) {
            return  // 已经释放过了
        }
        
        let newCount = refCount.fetchAdd(-1)
        if (newCount == 1) {
            // 引用计数为0，释放内存
            isReleased.store(true)
            pool.deallocate(this)
        }
    }

    public func getRefCount(): Int32 {
        return refCount.load()
    }

    public func isValid(): Bool {
        return !isReleased.load() && refCount.load() > 0
    }

    // 内存对齐辅助函数
    private func alignSize(size: UInt64, alignment: UInt64): UInt64 {
        return ((size + alignment - 1) / alignment) * alignment
    }
}

/**
 * 大小分类内存池
 * 按固定大小分类管理内存块
 */
public class SizeClassPool {
    private let blockSize: UInt64
    private let maxBlocks: Int64
    private let freeBlocks: ArrayList<SharedMemoryBufferImpl>
    private let mutex: ReentrantMutex
    private let allocatedCount: AtomicInt64
    private let totalAllocated: AtomicInt64

    public init(blockSize: UInt64, maxBlocks: Int64) {
        this.blockSize = blockSize
        this.maxBlocks = maxBlocks
        this.freeBlocks = ArrayList<SharedMemoryBufferImpl>()
        this.mutex = ReentrantMutex()
        this.allocatedCount = AtomicInt64(0)
        this.totalAllocated = AtomicInt64(0)
    }

    public func allocate(pool: MemoryPool): SharedMemoryBufferImpl {
        mutex.lock()

        var buffer: SharedMemoryBufferImpl
        if (!freeBlocks.isEmpty()) {
            // 从空闲列表中获取
            buffer = freeBlocks[freeBlocks.size - 1]
            freeBlocks.clear()  // 简化实现：清空列表
            mutex.unlock()
        } else {
            mutex.unlock()

            // 创建新的缓冲区
            buffer = SharedMemoryBufferImpl(blockSize, pool, 64)
            totalAllocated.fetchAdd(1)
        }

        allocatedCount.fetchAdd(1)
        return buffer
    }

    public func deallocate(buffer: SharedMemoryBufferImpl): Unit {
        allocatedCount.fetchAdd(-1)
        
        mutex.lock()
        
        if (freeBlocks.size < maxBlocks) {
            freeBlocks.append(buffer)
        }
        // 如果池满了，让缓冲区自然释放
        
        mutex.unlock()
    }

    public func getBlockSize(): UInt64 {
        return blockSize
    }

    public func getAllocatedCount(): Int64 {
        return allocatedCount.load()
    }

    public func getTotalAllocated(): Int64 {
        return totalAllocated.load()
    }

    public func getFreeCount(): Int64 {
        mutex.lock()
        let count = freeBlocks.size
        mutex.unlock()
        return count
    }
}

/**
 * 大对象内存池
 * 处理超过最大小对象大小的内存分配
 */
public class LargeObjectPool {
    private let allocatedBuffers: HashMap<UInt64, SharedMemoryBufferImpl>
    private let mutex: ReentrantMutex
    private let totalAllocated: AtomicInt64
    private let totalSize: AtomicInt64

    public init() {
        this.allocatedBuffers = HashMap<UInt64, SharedMemoryBufferImpl>()
        this.mutex = ReentrantMutex()
        this.totalAllocated = AtomicInt64(0)
        this.totalSize = AtomicInt64(0)
    }

    public func allocate(size: UInt64, pool: MemoryPool): SharedMemoryBufferImpl {
        let buffer = SharedMemoryBufferImpl(size, pool, 64)
        let bufferId = UInt64(buffer.getData().size)  // 使用数组大小作为ID
        
        mutex.lock()
        allocatedBuffers.put(bufferId, buffer)
        mutex.unlock()
        
        totalAllocated.fetchAdd(1)
        totalSize.fetchAdd(Int64(size))
        
        return buffer
    }

    public func deallocate(buffer: SharedMemoryBufferImpl): Unit {
        let bufferId = UInt64(buffer.getData().size)
        
        mutex.lock()
        allocatedBuffers.remove(bufferId)
        mutex.unlock()
        
        totalAllocated.fetchAdd(-1)
        totalSize.fetchAdd(-Int64(buffer.getSize()))
    }

    public func getTotalAllocated(): Int64 {
        return totalAllocated.load()
    }

    public func getTotalSize(): Int64 {
        return totalSize.load()
    }
}

/**
 * 内存统计信息
 */
public struct MemoryStats {
    public let totalAllocated: UInt64
    public let totalUsed: UInt64
    public let fragmentation: Float64
    public let poolCount: Int64
    public let largeObjectCount: Int64

    public init(totalAllocated: UInt64, totalUsed: UInt64, fragmentation: Float64, poolCount: Int64, largeObjectCount: Int64) {
        this.totalAllocated = totalAllocated
        this.totalUsed = totalUsed
        this.fragmentation = fragmentation
        this.poolCount = poolCount
        this.largeObjectCount = largeObjectCount
    }
}
