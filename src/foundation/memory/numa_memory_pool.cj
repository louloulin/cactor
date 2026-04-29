/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - NUMA感知内存池系统
 * 高性能、NUMA感知的内存分配和管理
 */
package cactor.foundation.memory

import std.sync.*
import std.collection.*
import std.time.*

// 内存池接口
public interface MemoryPool {
    func allocate(size: UInt64): Option<MemoryBlock>
    func deallocate(block: MemoryBlock): Unit
    func getStats(): MemoryPoolStats
    func reset(): Unit
    func getUtilization(): Float64
    func getTotalAllocated(): UInt64
    func getTotalUsed(): UInt64
}

// 内存块结构
public struct MemoryBlock {
    public let size: UInt64
    public let numaNode: Int32
    public let allocatedTime: Int64
    
    public init(size: UInt64, numaNode: Int32) {
        this.size = size
        this.numaNode = numaNode
        this.allocatedTime = getCurrentTimeMillis()
    }
}

// NUMA感知内存池
public class NumaAwareMemoryPool <: MemoryPool {
    private let nodeCount: Int32
    private let localPools: Array<LocalMemoryPool>
    private let globalPool: GlobalMemoryPool
    private let stats: MemoryPoolStats
    private let mutex: ReentrantMutex
    
    public init() {
        this.nodeCount = getNumaNodeCount()
        this.localPools = Array<LocalMemoryPool>(Int64(nodeCount), { i => LocalMemoryPool(Int32(i)) })
        this.globalPool = GlobalMemoryPool()
        this.stats = MemoryPoolStats()
        this.mutex = ReentrantMutex()

        // 为每个NUMA节点创建本地内存池
        for (i in 0..Int64(nodeCount)) {
            localPools[i] = LocalMemoryPool(Int32(i))
        }
    }

    // 添加带参数的构造函数以支持测试
    public init(nodeCount: Int32, poolSize: UInt64) {
        this.nodeCount = nodeCount
        this.localPools = Array<LocalMemoryPool>(Int64(nodeCount), { i => LocalMemoryPool(Int32(i), poolSize) })
        this.globalPool = GlobalMemoryPool()
        this.stats = MemoryPoolStats()
        this.mutex = ReentrantMutex()

        // 为每个NUMA节点创建本地内存池
        for (i in 0..Int64(nodeCount)) {
            localPools[i] = LocalMemoryPool(Int32(i), poolSize)
        }
    }

    // 添加简化的构造函数（只有poolSize参数）
    public init(poolSize: UInt64) {
        this.nodeCount = getNumaNodeCount()
        this.localPools = Array<LocalMemoryPool>(Int64(nodeCount), { i => LocalMemoryPool(Int32(i), poolSize) })
        this.globalPool = GlobalMemoryPool()
        this.stats = MemoryPoolStats()
        this.mutex = ReentrantMutex()

        // 为每个NUMA节点创建本地内存池
        for (i in 0..Int64(nodeCount)) {
            localPools[i] = LocalMemoryPool(Int32(i), poolSize)
        }
    }
    
    public func allocate(size: UInt64): Option<MemoryBlock> {
        let currentNode = getCurrentNumaNode()

        // 优先从本地NUMA节点分配
        match (localPools[Int64(currentNode)].tryAllocate(size)) {
            case Some(block) =>
                stats.recordLocalAllocation(size)
                return Some(block)
            case None =>
                ()  // 继续尝试其他节点
        }

        // 本地分配失败，尝试其他NUMA节点
        for (i in 0..Int64(nodeCount)) {
            if (i != Int64(currentNode)) {
                match (localPools[i].tryAllocate(size)) {
                    case Some(block) =>
                        stats.recordRemoteAllocation(size)
                        return Some(block)
                    case None =>
                        ()  // 继续尝试下一个节点
                }
            }
        }

        // 所有本地池都失败，使用全局池
        match (globalPool.allocate(size)) {
            case Some(block) =>
                stats.recordGlobalAllocation(size)
                return Some(block)
            case None =>
                return None<MemoryBlock>
        }
    }
    
    public func deallocate(block: MemoryBlock): Unit {
        let numaNode = block.numaNode
        
        if (numaNode >= 0 && numaNode < nodeCount) {
            localPools[Int64(numaNode)].deallocate(block)
        } else {
            globalPool.deallocate(block)
        }
        
        stats.recordDeallocation(block.size)
    }
    
    public func getStats(): MemoryPoolStats {
        stats
    }
    
    public func reset(): Unit {
        mutex.lock()

        for (pool in localPools) {
            pool.reset()
        }
        globalPool.reset()
        stats.reset()

        mutex.unlock()
    }

    public func getUtilization(): Float64 {
        let totalAllocated = getTotalAllocated()
        let totalUsed = getTotalUsed()
        if (totalAllocated == 0) {
            return 0.0
        }
        return Float64(totalUsed) / Float64(totalAllocated)
    }

    public func getTotalAllocated(): UInt64 {
        var total: UInt64 = 0
        for (pool in localPools) {
            total += pool.getTotalAllocated()
        }
        total += globalPool.getTotalAllocated()
        return total
    }

    public func getTotalUsed(): UInt64 {
        var total: UInt64 = 0
        for (pool in localPools) {
            total += pool.getTotalUsed()
        }
        total += globalPool.getTotalUsed()
        return total
    }


}

// 本地内存池（单个NUMA节点）
public class LocalMemoryPool {
    private let numaNode: Int32
    private let freeBlocks: HashMap<UInt64, ArrayList<MemoryBlock>>
    private let mutex: ReentrantMutex
    private let chunkSize: UInt64
    private var totalAllocated: UInt64
    private var totalUsed: UInt64
    
    public init(numaNode: Int32, chunkSize: UInt64) {
        this.numaNode = numaNode
        this.freeBlocks = HashMap<UInt64, ArrayList<MemoryBlock>>()
        this.mutex = ReentrantMutex()
        this.chunkSize = chunkSize
        this.totalAllocated = 0
        this.totalUsed = 0
    }
    
    public init(numaNode: Int32) {
        this.numaNode = numaNode
        this.freeBlocks = HashMap<UInt64, ArrayList<MemoryBlock>>()
        this.mutex = ReentrantMutex()
        this.chunkSize = 64 * 1024 * 1024  // 64MB chunks
        this.totalAllocated = 0
        this.totalUsed = 0
    }
    
    public func tryAllocate(size: UInt64): Option<MemoryBlock> {
        mutex.lock()

        let alignedSize = alignSize(size)

        // 查找合适的空闲块
        match (findFreeBlock(alignedSize)) {
            case Some(block) =>
                totalUsed += alignedSize
                mutex.unlock()
                return Some(block)
            case None =>
                ()  // 继续分配新块
        }

        // 没有合适的空闲块，分配新的块
        let newBlock = MemoryBlock(alignedSize, numaNode)
        totalAllocated += alignedSize
        totalUsed += alignedSize

        mutex.unlock()
        return Some(newBlock)
    }
    
    public func deallocate(block: MemoryBlock): Unit {
        mutex.lock()

        // 添加到空闲块列表
        addFreeBlock(block)
        totalUsed -= block.size

        mutex.unlock()
    }

    public func reset(): Unit {
        mutex.lock()

        freeBlocks.clear()
        totalAllocated = 0
        totalUsed = 0

        mutex.unlock()
    }
    
    private func findFreeBlock(size: UInt64): Option<MemoryBlock> {
        // 简化实现：总是返回None，强制分配新块
        return None<MemoryBlock>
    }

    private func addFreeBlock(block: MemoryBlock): Unit {
        // 简化实现：获取或创建块列表
        match (freeBlocks.get(block.size)) {
            case Some(blockList) =>
                blockList.add(block)
            case None =>
                let newList = ArrayList<MemoryBlock>()
                newList.add(block)
                freeBlocks.add(block.size, newList)
        }
    }

    private func removeFreeBlock(block: MemoryBlock): Unit {
        // 简化实现：清空对应大小的块列表
        match (freeBlocks.get(block.size)) {
            case Some(blockList) =>
                blockList.clear()
                freeBlocks.remove(block.size)
            case None =>
                ()  // 什么都不做
        }
    }
    
    private func alignSize(size: UInt64): UInt64 {
        let alignment: UInt64 = 64 // 64字节对齐
        // 简化对齐实现
        let remainder = size % alignment
        if (remainder == 0) {
            return size
        } else {
            return size + (alignment - remainder)
        }
    }

    public func getTotalAllocated(): UInt64 {
        mutex.lock()
        let allocated = totalAllocated
        mutex.unlock()
        return allocated
    }

    public func getTotalUsed(): UInt64 {
        mutex.lock()
        let used = totalUsed
        mutex.unlock()
        return used
    }
}

// 全局内存池（后备分配器）
public class GlobalMemoryPool <: MemoryPool {
    private let mutex: ReentrantMutex
    private var totalAllocated: UInt64
    
    public init() {
        this.mutex = ReentrantMutex()
        this.totalAllocated = 0
    }
    
    public func allocate(size: UInt64): Option<MemoryBlock> {
        mutex.lock()

        let block = MemoryBlock(size, -1)  // -1表示全局池
        totalAllocated += size

        mutex.unlock()
        return Some(block)
    }

    public func deallocate(block: MemoryBlock): Unit {
        mutex.lock()

        totalAllocated -= block.size

        mutex.unlock()
    }

    public func getStats(): MemoryPoolStats {
        MemoryPoolStats()
    }

    public func reset(): Unit {
        mutex.lock()

        totalAllocated = 0

        mutex.unlock()
    }

    public func getUtilization(): Float64 {
        // 全局池的利用率简化为1.0（假设全部使用）
        return 1.0
    }

    public func getTotalAllocated(): UInt64 {
        mutex.lock()
        let allocated = totalAllocated
        mutex.unlock()
        return allocated
    }

    public func getTotalUsed(): UInt64 {
        // 简化实现：假设全局池的分配即使用
        return getTotalAllocated()
    }
}

// 内存池统计信息
public class MemoryPoolStats {
    private var localAllocations: AtomicInt64
    private var remoteAllocations: AtomicInt64
    private var globalAllocations: AtomicInt64
    private var deallocations: AtomicInt64
    private var localBytes: AtomicInt64
    private var remoteBytes: AtomicInt64
    private var globalBytes: AtomicInt64
    
    public init() {
        this.localAllocations = AtomicInt64(0)
        this.remoteAllocations = AtomicInt64(0)
        this.globalAllocations = AtomicInt64(0)
        this.deallocations = AtomicInt64(0)
        this.localBytes = AtomicInt64(0)
        this.remoteBytes = AtomicInt64(0)
        this.globalBytes = AtomicInt64(0)
    }
    
    public func recordLocalAllocation(size: UInt64): Unit {
        localAllocations.fetchAdd(1)
        localBytes.fetchAdd(Int64(size))
    }
    
    public func recordRemoteAllocation(size: UInt64): Unit {
        remoteAllocations.fetchAdd(1)
        remoteBytes.fetchAdd(Int64(size))
    }
    
    public func recordGlobalAllocation(size: UInt64): Unit {
        globalAllocations.fetchAdd(1)
        globalBytes.fetchAdd(Int64(size))
    }
    
    public func recordDeallocation(size: UInt64): Unit {
        deallocations.fetchAdd(1)
    }
    
    public func getLocalAllocations(): Int64 { localAllocations.load() }
    public func getRemoteAllocations(): Int64 { remoteAllocations.load() }
    public func getGlobalAllocations(): Int64 { globalAllocations.load() }
    public func getDeallocations(): Int64 { deallocations.load() }
    public func getLocalBytes(): Int64 { localBytes.load() }
    public func getRemoteBytes(): Int64 { remoteBytes.load() }
    public func getGlobalBytes(): Int64 { globalBytes.load() }
    
    public func reset(): Unit {
        localAllocations.store(0)
        remoteAllocations.store(0)
        globalAllocations.store(0)
        deallocations.store(0)
        localBytes.store(0)
        remoteBytes.store(0)
        globalBytes.store(0)
    }
    
    public func getNumaEfficiency(): Float64 {
        let total = localAllocations.load() + remoteAllocations.load() + globalAllocations.load()
        if (total == 0) {
            return 1.0
        }
        return Float64(localAllocations.load()) / Float64(total)
    }

    public func getTotalAllocations(): Int64 {
        return localAllocations.load() + remoteAllocations.load() + globalAllocations.load()
    }
}

// NUMA相关的系统调用封装
func getNumaNodeCount(): Int32 {
    // 简化实现，实际需要调用系统API
    return 2
}

func getCurrentNumaNode(): Int32 {
    // 简化实现，实际需要调用系统API获取当前线程的NUMA节点
    return 0
}

func getCurrentTimeMillis(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

/**
 * 内存池工厂
 */
public struct MemoryPoolFactory {
    /**
     * 创建基础内存池
     */
    public static func createPool(maxSize: UInt64): MemoryPool {
        GlobalMemoryPool()
    }

    /**
     * 创建高吞吐量内存池
     */
    public static func createHighThroughputPool(): MemoryPool {
        NumaAwareMemoryPool()
    }

    /**
     * 创建低延迟内存池
     */
    public static func createLowLatencyPool(): MemoryPool {
        NumaAwareMemoryPool()
    }
}
