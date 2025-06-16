/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级调度器工厂系统
 * 基于plan3.md Phase 3设计，支持多种调度器类型的创建和管理
 */
package cactor.runtime.dispatcher.factory

import std.time.*
import std.collection.*
import cactor.runtime.dispatcher.advanced.{
    AdvancedMessageDispatcher,
    AdvancedWorkStealingDispatcher,
    UltraHighPerformanceDispatcher,
    ThreadPoolDispatcher,
    PinnedDispatcher,
    CallingThreadDispatcher
}
import cactor.core.config.{DispatcherConfig, DispatcherType}

/**
 * 高级调度器工厂接口
 * 支持基于配置创建不同类型的调度器
 */
public interface AdvancedDispatcherFactory {
    /**
     * 根据配置创建调度器
     */
    func createDispatcher(config: DispatcherConfig): AdvancedMessageDispatcher
    
    /**
     * 创建优化的调度器（根据性能需求自动选择）
     */
    func createOptimizedDispatcher(config: DispatcherConfig, performanceProfile: PerformanceProfile): AdvancedMessageDispatcher
    
    /**
     * 获取支持的调度器类型
     */
    func getSupportedTypes(): Array<DispatcherType>
    
    /**
     * 验证配置是否有效
     */
    func validateConfig(config: DispatcherConfig): Bool
    
    /**
     * 获取创建统计信息
     */
    func getCreationStats(): String
}

/**
 * 性能配置文件枚举
 * 用于自动选择最优的调度器实现
 */
public enum PerformanceProfile {
    | UltraHighThroughput      // 超高吞吐量
    | UltraLowLatency          // 超低延迟
    | Balanced                 // 平衡性能
    | MemoryOptimized          // 内存优化
    | CpuOptimized             // CPU优化
    | CriticalMission          // 关键任务
}

/**
 * 默认高级调度器工厂实现
 * 基于现有高性能调度器组件的工厂
 */
public class DefaultAdvancedDispatcherFactory <: AdvancedDispatcherFactory {
    private let supportedTypes: Array<DispatcherType>
    private let creationStats: HashMap<String, Int64>
    
    public init() {
        this.supportedTypes = [
            DispatcherType.ThreadPool,
            DispatcherType.WorkStealing,
            DispatcherType.PinnedDispatcher,
            DispatcherType.CallingThread,
            DispatcherType.Custom
        ]
        this.creationStats = HashMap<String, Int64>()
    }
    
    public func createDispatcher(config: DispatcherConfig): AdvancedMessageDispatcher {
        // 验证配置
        if (!validateConfig(config)) {
            throw Exception("Invalid dispatcher configuration: ${config.name}")
        }
        
        // 记录创建统计
        recordCreation(config.dispatcherType)
        
        // 根据类型创建调度器
        match (config.dispatcherType) {
            case DispatcherType.ThreadPool =>
                ThreadPoolDispatcher(config)
            case DispatcherType.WorkStealing =>
                AdvancedWorkStealingDispatcher(config)
            case DispatcherType.PinnedDispatcher =>
                PinnedDispatcher(config)
            case DispatcherType.CallingThread =>
                CallingThreadDispatcher(config)
            case DispatcherType.Custom =>
                createCustomDispatcher(config)
        }
    }
    
    public func createOptimizedDispatcher(config: DispatcherConfig, performanceProfile: PerformanceProfile): AdvancedMessageDispatcher {
        // 根据性能配置文件选择最优的调度器实现
        let optimizedConfig = optimizeConfig(config, performanceProfile)
        
        match (performanceProfile) {
            case PerformanceProfile.UltraHighThroughput =>
                UltraHighPerformanceDispatcher(optimizedConfig)
            case PerformanceProfile.UltraLowLatency =>
                PinnedDispatcher(optimizedConfig)
            case PerformanceProfile.CriticalMission =>
                PinnedDispatcher(optimizedConfig)
            case PerformanceProfile.MemoryOptimized =>
                CallingThreadDispatcher(optimizedConfig)
            case PerformanceProfile.CpuOptimized =>
                AdvancedWorkStealingDispatcher(optimizedConfig)
            case PerformanceProfile.Balanced =>
                createBalancedDispatcher(optimizedConfig)
        }
    }
    
    public func getSupportedTypes(): Array<DispatcherType> {
        supportedTypes
    }
    
    public func validateConfig(config: DispatcherConfig): Bool {
        // 验证基本配置
        if (config.name.isEmpty()) {
            return false
        }
        
        // 验证吞吐量配置
        if (config.throughput <= 0) {
            return false
        }
        
        // 验证执行器配置
        match (config.dispatcherType) {
            case DispatcherType.ThreadPool =>
                if (config.executorConfig.corePoolSize <= 0) {
                    return false
                }
            case DispatcherType.WorkStealing =>
                if (config.executorConfig.corePoolSize <= 0) {
                    return false
                }
            case _ => // 其他类型暂时不验证
        }
        
        // 验证超时配置
        if (config.throughputDeadlineTime.toNanoseconds() <= 0) {
            return false
        }
        
        return true
    }
    
    public func getCreationStats(): String {
        let stats = ArrayList<String>()
        for ((typeName, count) in creationStats) {
            stats.append("${typeName}: ${count}")
        }
        
        if (stats.isEmpty()) {
            return "No dispatchers created yet"
        }
        
        let result = StringBuilder()
        result.append("Dispatcher Creation Stats: ")
        for (i in 0..stats.size) {
            if (i > 0) {
                result.append(", ")
            }
            result.append(stats[i])
        }
        result.toString()
    }
    
    /**
     * 创建自定义调度器
     */
    private func createCustomDispatcher(config: DispatcherConfig): AdvancedMessageDispatcher {
        // 默认回退到工作窃取调度器
        AdvancedWorkStealingDispatcher(config)
    }
    
    /**
     * 创建平衡性能调度器
     */
    private func createBalancedDispatcher(config: DispatcherConfig): AdvancedMessageDispatcher {
        // 根据核心数选择合适的调度器
        let coreCount = config.executorConfig.corePoolSize
        
        if (coreCount <= 2) {
            // 少核心使用线程池
            ThreadPoolDispatcher(config)
        } else if (coreCount <= 8) {
            // 中等核心使用工作窃取
            AdvancedWorkStealingDispatcher(config)
        } else {
            // 多核心使用超高性能调度器
            UltraHighPerformanceDispatcher(config)
        }
    }
    
    /**
     * 根据性能配置文件优化配置
     */
    private func optimizeConfig(config: DispatcherConfig, performanceProfile: PerformanceProfile): DispatcherConfig {
        match (performanceProfile) {
            case PerformanceProfile.UltraHighThroughput =>
                DispatcherConfig(
                    config.dispatcherType,
                    config.throughput * 2,  // 增加吞吐量
                    config.throughputDeadlineTime,
                    config.executorConfig,
                    "${config.name}-ultra-throughput"
                )
            case PerformanceProfile.UltraLowLatency =>
                DispatcherConfig(
                    DispatcherType.PinnedDispatcher,  // 强制使用专用线程
                    config.throughput,
                    Duration.microsecond * 10,  // 极短超时
                    config.executorConfig,
                    "${config.name}-ultra-latency"
                )
            case PerformanceProfile.CriticalMission =>
                DispatcherConfig(
                    DispatcherType.PinnedDispatcher,  // 专用线程保证可靠性
                    config.throughput,
                    Duration.microsecond * 50,
                    config.executorConfig,
                    "${config.name}-critical"
                )
            case _ =>
                config
        }
    }
    
    /**
     * 记录创建统计
     */
    private func recordCreation(dispatcherType: DispatcherType): Unit {
        let typeName = match (dispatcherType) {
            case DispatcherType.ThreadPool => "threadpool"
            case DispatcherType.WorkStealing => "workstealing"
            case DispatcherType.PinnedDispatcher => "pinned"
            case DispatcherType.CallingThread => "callingthread"
            case DispatcherType.Custom => "custom"
        }
        
        let currentCount = match (creationStats.get(typeName)) {
            case Some(count) => count
            case None => 0
        }
        creationStats.put(typeName, currentCount + 1)
    }
}

/**
 * 简化的StringBuilder实现
 */
public class StringBuilder {
    private let parts: ArrayList<String>
    
    public init() {
        this.parts = ArrayList<String>()
    }
    
    public func append(str: String): Unit {
        parts.append(str)
    }
    
    public func toString(): String {
        if (parts.isEmpty()) {
            return ""
        }
        
        var result = parts[0]
        for (i in 1..parts.size) {
            result = result + parts[i]
        }
        result
    }
}

/**
 * 调度器工厂注册表
 * 管理多个调度器工厂实例
 */
public class DispatcherFactoryRegistry {
    private let factories: HashMap<String, AdvancedDispatcherFactory>
    private let defaultFactory: AdvancedDispatcherFactory
    
    public init() {
        this.factories = HashMap<String, AdvancedDispatcherFactory>()
        this.defaultFactory = DefaultAdvancedDispatcherFactory()
        
        // 注册默认工厂
        registerFactory("default", defaultFactory)
    }
    
    /**
     * 注册调度器工厂
     */
    public func registerFactory(name: String, factory: AdvancedDispatcherFactory): Unit {
        factories.put(name, factory)
    }
    
    /**
     * 获取调度器工厂
     */
    public func getFactory(name: String): AdvancedDispatcherFactory {
        match (factories.get(name)) {
            case Some(factory) => factory
            case None => defaultFactory
        }
    }
    
    /**
     * 获取默认工厂
     */
    public func getDefaultFactory(): AdvancedDispatcherFactory {
        defaultFactory
    }
    
    /**
     * 获取所有注册的工厂名称
     */
    public func getFactoryNames(): Array<String> {
        let names = ArrayList<String>()
        for ((name, _) in factories) {
            names.append(name)
        }
        Array<String>(Int64(names.size), { i => names[i] })
    }
}
