/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 高性能Actor系统配置
 * 基于plan2.md的性能优化要求
 */
package cactor.runtime.dispatcher

import std.collection.*

/**
 * 高性能Actor系统配置
 * 实现plan2.md中的性能优化策略
 */
public struct HighPerformanceActorSystemConfig {
    public let messageBatching: Bool
    public let zeroCopyMessaging: Bool
    public let objectPooling: Bool
    public let gcOptimization: Bool
    public let memoryCompaction: Bool
    public let lazyLoading: Bool
    public let directMemoryAccess: Bool
    public let jitOptimization: Bool
    public let bulkProcessing: Bool
    public let pipelineOptimization: Bool
    
    public init(
        messageBatching: Bool,
        zeroCopyMessaging: Bool,
        objectPooling: Bool,
        gcOptimization: Bool,
        memoryCompaction: Bool,
        lazyLoading: Bool,
        directMemoryAccess: Bool,
        jitOptimization: Bool,
        bulkProcessing: Bool,
        pipelineOptimization: Bool
    ) {
        this.messageBatching = messageBatching
        this.zeroCopyMessaging = zeroCopyMessaging
        this.objectPooling = objectPooling
        this.gcOptimization = gcOptimization
        this.memoryCompaction = memoryCompaction
        this.lazyLoading = lazyLoading
        this.directMemoryAccess = directMemoryAccess
        this.jitOptimization = jitOptimization
        this.bulkProcessing = bulkProcessing
        this.pipelineOptimization = pipelineOptimization
    }
    
    /**
     * 创建默认配置
     */
    public static func createDefault(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            false, false, false, false, false, false, false, false, false, false
        )
    }

    /**
     * 创建极限性能配置
     * 基于plan2.md的优化目标：1M msg/s
     */
    public static func createExtreme(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            true,   // messageBatching
            true,   // zeroCopyMessaging
            true,   // objectPooling
            true,   // gcOptimization
            false,  // memoryCompaction - 与GC优化冲突
            false,  // lazyLoading - 极限性能模式预加载
            true,   // directMemoryAccess
            true,   // jitOptimization
            true,   // bulkProcessing
            true    // pipelineOptimization
        )
    }

    /**
     * 创建内存优化配置
     * 目标：<1KB/Actor
     */
    public static func createMemoryOptimized(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            false,  // messageBatching - 减少内存使用
            true,   // zeroCopyMessaging
            true,   // objectPooling
            false,  // gcOptimization - 与内存压缩冲突
            true,   // memoryCompaction
            true,   // lazyLoading
            false,  // directMemoryAccess
            false,  // jitOptimization
            false,  // bulkProcessing
            false   // pipelineOptimization
        )
    }

    /**
     * 创建低延迟配置
     * 目标：P99 < 100μs
     */
    public static func createLowLatency(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            false,  // messageBatching - 批处理增加延迟
            true,   // zeroCopyMessaging
            true,   // objectPooling
            true,   // gcOptimization
            false,  // memoryCompaction
            false,  // lazyLoading - 预加载减少延迟
            true,   // directMemoryAccess
            true,   // jitOptimization
            false,  // bulkProcessing
            true    // pipelineOptimization
        )
    }

    /**
     * 创建高吞吐量配置
     * 目标：50M msg/s
     */
    public static func createHighThroughput(): HighPerformanceActorSystemConfig {
        HighPerformanceActorSystemConfig(
            true,   // messageBatching
            true,   // zeroCopyMessaging
            true,   // objectPooling
            true,   // gcOptimization
            false,  // memoryCompaction
            false,  // lazyLoading
            true,   // directMemoryAccess
            true,   // jitOptimization
            true,   // bulkProcessing
            true    // pipelineOptimization
        )
    }
    
    /**
     * 配置描述
     */
    public func getDescription(): String {
        let features = ArrayList<String>()
        
        if (messageBatching) { features.append("消息批处理") }
        if (zeroCopyMessaging) { features.append("零拷贝消息") }
        if (objectPooling) { features.append("对象池") }
        if (gcOptimization) { features.append("GC优化") }
        if (memoryCompaction) { features.append("内存压缩") }
        if (lazyLoading) { features.append("懒加载") }
        if (directMemoryAccess) { features.append("直接内存访问") }
        if (jitOptimization) { features.append("JIT优化") }
        if (bulkProcessing) { features.append("批量处理") }
        if (pipelineOptimization) { features.append("流水线优化") }
        
        if (features.isEmpty()) {
            return "标准配置"
        } else {
            return "高性能配置: ${features.toString()}"
        }
    }
    
    /**
     * 验证配置兼容性
     */
    public func validate(): Array<String> {
        let warnings = ArrayList<String>()
        
        // 检查冲突配置
        if (gcOptimization && memoryCompaction) {
            warnings.append("GC优化与内存压缩可能冲突")
        }
        
        if (messageBatching && directMemoryAccess) {
            warnings.append("消息批处理与直接内存访问需要仔细调优")
        }
        
        if (lazyLoading && (messageBatching || bulkProcessing)) {
            warnings.append("懒加载可能影响批处理性能")
        }
        
        return warnings.toArray()
    }
    
    /**
     * 获取性能等级
     */
    public func getPerformanceLevel(): String {
        let score = calculatePerformanceScore()
        
        if (score >= 8) {
            return "极限性能"
        } else if (score >= 6) {
            return "高性能"
        } else if (score >= 4) {
            return "标准性能"
        } else {
            return "基础性能"
        }
    }
    
    /**
     * 计算性能分数
     */
    private func calculatePerformanceScore(): Int32 {
        var score: Int32 = 0

        if (messageBatching) { score += 1 }
        if (zeroCopyMessaging) { score += 1 }
        if (objectPooling) { score += 1 }
        if (gcOptimization) { score += 1 }
        if (directMemoryAccess) { score += 1 }
        if (jitOptimization) { score += 1 }
        if (bulkProcessing) { score += 1 }
        if (pipelineOptimization) { score += 1 }

        // 懒加载和内存压缩在某些场景下可能降低性能
        if (lazyLoading) { score -= 1 }
        if (memoryCompaction) { score -= 1 }

        return score
    }
}


