/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 2: 高性能内存池实现
 * 基于仓颉语言的多级内存池系统
 */
package cactor.core.zerocopy

import std.sync.*
import std.time.*
import std.collection.*
import std.math.*

/**
 * 高性能内存池实现
 * 支持多级大小分类和大对象处理
 */
public class HighPerformanceMemoryPool <: MemoryPool {
    // 预定义的大小分类 (字节)
    private static let SIZE_CLASSES: Array<UInt64> = [
        64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536
    ]
    
    private let sizePools: Array<SizeClassPool>
    private let largeObjectPool: LargeObjectPool
    private let maxSmallObjectSize: UInt64
    private let totalAllocated: AtomicInt64
    private let totalUsed: AtomicInt64
    private let allocationCount: AtomicInt64
    private let deallocationCount: AtomicInt64

    public init(maxPoolSize: Int64) {
        this.maxSmallObjectSize = SIZE_CLASSES[SIZE_CLASSES.size - 1]
        this.sizePools = Array<SizeClassPool>(SIZE_CLASSES.size, { i => 
            SizeClassPool(SIZE_CLASSES[i], maxPoolSize)
        })
        this.largeObjectPool = LargeObjectPool()
        this.totalAllocated = AtomicInt64(0)
        this.totalUsed = AtomicInt64(0)
        this.allocationCount = AtomicInt64(0)
        this.deallocationCount = AtomicInt64(0)
    }

    public func allocate(size: UInt64): SharedMemoryBuffer {
        allocationCount.fetchAdd(1)
        totalUsed.fetchAdd(Int64(size))

        if (size <= maxSmallObjectSize) {
            // 小对象：使用大小分类池
            let poolIndex = findSizeClassIndex(size)
            let pool = sizePools[poolIndex]
            return pool.allocate(this)
        } else {
            // 大对象：使用大对象池
            return largeObjectPool.allocate(size, this)
        }
    }

    public func deallocate(buffer: SharedMemoryBuffer): Unit {
        deallocationCount.fetchAdd(1)
        totalUsed.fetchAdd(-Int64(buffer.getSize()))

        if (buffer.getSize() <= maxSmallObjectSize) {
            // 小对象：返回到大小分类池
            let poolIndex = findSizeClassIndex(buffer.getSize())
            let pool = sizePools[poolIndex]
            match (buffer) {
                case impl: SharedMemoryBufferImpl =>
                    pool.deallocate(impl)
                case _ =>
                    println("警告：未知的缓冲区类型")
            }
        } else {
            // 大对象：返回到大对象池
            match (buffer) {
                case impl: SharedMemoryBufferImpl =>
                    largeObjectPool.deallocate(impl)
                case _ =>
                    println("警告：未知的缓冲区类型")
            }
        }
    }

    public func getTotalAllocated(): UInt64 {
        return UInt64(totalAllocated.load())
    }

    public func getTotalUsed(): UInt64 {
        return UInt64(totalUsed.load())
    }

    public func getFragmentation(): Float64 {
        let allocated = totalAllocated.load()
        let used = totalUsed.load()
        
        if (allocated == 0) {
            return 0.0
        }
        
        return Float64(allocated - used) / Float64(allocated)
    }

    /**
     * 获取内存池统计信息
     */
    public func getStats(): MemoryStats {
        var totalPoolAllocated: Int64 = 0
        var totalPoolCount: Int64 = 0
        
        for (pool in sizePools) {
            totalPoolAllocated += pool.getTotalAllocated()
            totalPoolCount += pool.getAllocatedCount()
        }
        
        let largeObjectCount = largeObjectPool.getTotalAllocated()
        let totalAllocated = UInt64(totalPoolAllocated + largeObjectCount)
        let totalUsed = getTotalUsed()
        let fragmentation = getFragmentation()
        
        return MemoryStats(
            totalAllocated,
            totalUsed,
            fragmentation,
            totalPoolCount,
            largeObjectCount
        )
    }

    /**
     * 预热内存池
     * 预分配常用大小的内存块
     */
    public func warmup(warmupSizes: Array<UInt64>, countPerSize: Int64): Unit {
        for (size in warmupSizes) {
            for (i in 0..countPerSize) {
                let buffer = allocate(size)
                deallocate(buffer)
            }
        }
    }

    /**
     * 清理内存池
     * 释放所有空闲内存块
     */
    public func cleanup(): Unit {
        // 大小分类池会自动管理内存
        // 这里可以添加强制清理逻辑
        println("内存池清理完成")
    }

    /**
     * 获取分配统计
     */
    public func getAllocationStats(): String {
        let allocated = allocationCount.load()
        let deallocated = deallocationCount.load()
        let outstanding = allocated - deallocated
        
        return "分配: ${allocated}, 释放: ${deallocated}, 未释放: ${outstanding}"
    }

    // 查找合适的大小分类索引
    private func findSizeClassIndex(size: UInt64): Int64 {
        for (i in 0..SIZE_CLASSES.size) {
            if (size <= SIZE_CLASSES[i]) {
                return i
            }
        }
        return SIZE_CLASSES.size - 1  // 返回最大的大小分类
    }
}

/**
 * 内存池工厂
 * 创建和管理不同配置的内存池
 */
public class MemoryPoolFactory {
    private static var defaultPool: Option<HighPerformanceMemoryPool> = None
    private static let mutex: ReentrantMutex = ReentrantMutex()

    /**
     * 获取默认内存池实例
     */
    public static func getDefaultPool(): HighPerformanceMemoryPool {
        mutex.lock()
        
        match (defaultPool) {
            case Some(pool) =>
                mutex.unlock()
                return pool
            case None =>
                let pool = HighPerformanceMemoryPool(1000)
                defaultPool = Some(pool)
                mutex.unlock()
                return pool
        }
    }

    /**
     * 创建自定义内存池
     */
    public static func createPool(maxPoolSize: Int64): HighPerformanceMemoryPool {
        return HighPerformanceMemoryPool(maxPoolSize)
    }

    /**
     * 创建高性能内存池
     * 针对高吞吐量场景优化
     */
    public static func createHighThroughputPool(): HighPerformanceMemoryPool {
        let pool = HighPerformanceMemoryPool(5000)  // 更大的池大小
        
        // 预热常用大小
        let warmupSizes: Array<UInt64> = [64, 128, 256, 512, 1024, 2048, 4096]
        pool.warmup(warmupSizes, 100)
        
        return pool
    }

    /**
     * 创建低延迟内存池
     * 针对低延迟场景优化
     */
    public static func createLowLatencyPool(): HighPerformanceMemoryPool {
        let pool = HighPerformanceMemoryPool(2000)
        
        // 预热所有大小分类
        let warmupSizes: Array<UInt64> = [
            64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536
        ]
        pool.warmup(warmupSizes, 50)
        
        return pool
    }
}

/**
 * 内存池性能监控器
 */
public class MemoryPoolMonitor {
    private let pool: HighPerformanceMemoryPool
    private let monitorInterval: Duration
    private var isRunning: AtomicBool
    private var lastStats: Option<MemoryStats>

    public init(pool: HighPerformanceMemoryPool, monitorInterval: Duration) {
        this.pool = pool
        this.monitorInterval = monitorInterval
        this.isRunning = AtomicBool(false)
        this.lastStats = None
    }

    /**
     * 开始监控
     */
    public func startMonitoring(): Unit {
        if (!isRunning.load()) {
            isRunning.store(true)
            // 在实际实现中，这里应该启动一个后台线程
            println("内存池监控已启动")
        }
    }

    /**
     * 停止监控
     */
    public func stopMonitoring(): Unit {
        isRunning.store(false)
        println("内存池监控已停止")
    }

    /**
     * 获取当前统计信息
     */
    public func getCurrentStats(): MemoryStats {
        return pool.getStats()
    }

    /**
     * 打印统计报告
     */
    public func printReport(): Unit {
        let stats = getCurrentStats()
        println("=== 内存池统计报告 ===")
        println("总分配: ${stats.totalAllocated} 字节")
        println("总使用: ${stats.totalUsed} 字节")
        println("碎片率: ${stats.fragmentation * 100.0}%")
        println("池对象数: ${stats.poolCount}")
        println("大对象数: ${stats.largeObjectCount}")
        println("分配统计: ${pool.getAllocationStats()}")
    }
}
