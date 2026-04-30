/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级邮箱工厂系统
 * 基于plan3.md Phase 2设计，支持多种邮箱类型的创建和管理
 */
package cactor.runtime.mailbox.factory

import std.time.*
import std.collection.*
import cactor.core.message.{Message, Envelope}
import cactor.runtime.mailbox.Mailbox
import cactor.runtime.mailbox.advanced.{
    FoundationUnboundedMailbox,
    FoundationBoundedMailbox,
    SPSCMailbox,
    MPSCMailbox,
    FoundationPriorityMailbox,
    FoundationStashingMailbox
}
import cactor.core.config.{MailboxConfig, MailboxType}

/**
 * 高级邮箱工厂接口
 * 支持基于配置创建不同类型的邮箱
 */
public interface AdvancedMailboxFactory {
    /**
     * 根据配置创建邮箱
     */
    func createMailbox(config: MailboxConfig): Mailbox
    
    /**
     * 创建优化的邮箱（根据使用模式自动选择）
     */
    func createOptimizedMailbox(config: MailboxConfig, usagePattern: UsagePattern): Mailbox
    
    /**
     * 获取支持的邮箱类型
     */
    func getSupportedTypes(): Array<MailboxType>
    
    /**
     * 验证配置是否有效
     */
    func validateConfig(config: MailboxConfig): Bool
}

/**
 * 邮箱使用模式枚举
 * 用于自动选择最优的邮箱实现
 */
public enum UsagePattern {
    | SingleProducerSingleConsumer    // 单生产者单消费者
    | MultiProducerSingleConsumer     // 多生产者单消费者
    | SingleProducerMultiConsumer     // 单生产者多消费者
    | MultiProducerMultiConsumer      // 多生产者多消费者
    | HighThroughput                  // 高吞吐量场景
    | LowLatency                      // 低延迟场景
    | Balanced                        // 平衡场景
}

/**
 * 默认高级邮箱工厂实现
 * 基于Foundation队列的高性能邮箱工厂
 */
public class DefaultAdvancedMailboxFactory <: AdvancedMailboxFactory {
    private let supportedTypes: Array<MailboxType>
    private let creationStats: HashMap<String, Int64>
    
    public init() {
        this.supportedTypes = [
            MailboxType.Unbounded,
            MailboxType.Bounded,
            MailboxType.Priority,
            MailboxType.Stashing,
            MailboxType.Custom
        ]
        this.creationStats = HashMap<String, Int64>()
    }
    
    public func createMailbox(config: MailboxConfig): Mailbox {
        // 验证配置
        if (!validateConfig(config)) {
            throw Exception("Invalid mailbox configuration: ${config.name}")
        }
        
        // 记录创建统计
        recordCreation(config.mailboxType)
        
        // 根据类型创建邮箱
        match (config.mailboxType) {
            case MailboxType.Unbounded =>
                FoundationUnboundedMailbox(config)
            case MailboxType.Bounded =>
                FoundationBoundedMailbox(config)
            case MailboxType.Priority =>
                createPriorityMailbox(config)
            case MailboxType.Stashing =>
                createStashingMailbox(config)
            case MailboxType.Custom =>
                createCustomMailbox(config)
        }
    }
    
    public func createOptimizedMailbox(config: MailboxConfig, usagePattern: UsagePattern): Mailbox {
        // 根据使用模式选择最优的邮箱实现
        let optimizedConfig = optimizeConfig(config, usagePattern)
        
        match (usagePattern) {
            case UsagePattern.SingleProducerSingleConsumer =>
                SPSCMailbox(optimizedConfig)
            case UsagePattern.MultiProducerSingleConsumer =>
                MPSCMailbox(optimizedConfig)
            case UsagePattern.HighThroughput =>
                createHighThroughputMailbox(optimizedConfig)
            case UsagePattern.LowLatency =>
                createLowLatencyMailbox(optimizedConfig)
            case _ =>
                createMailbox(optimizedConfig)
        }
    }
    
    public func getSupportedTypes(): Array<MailboxType> {
        supportedTypes
    }
    
    public func validateConfig(config: MailboxConfig): Bool {
        // 验证基本配置
        if (config.name.isEmpty()) {
            return false
        }
        
        // 验证容量配置
        match (config.mailboxType) {
            case MailboxType.Bounded =>
                if (config.capacity <= 0) {
                    return false
                }
            case MailboxType.Stashing =>
                if (config.capacity <= 0 || config.stashCapacity < 0) {
                    return false
                }
            case _ => () // 其他类型暂时不验证
        }
        
        // 验证超时配置
        if (config.pushTimeout.toNanoseconds() < 0) {
            return false
        }
        
        return true
    }
    
    /**
     * 创建优先级邮箱
     */
    private func createPriorityMailbox(config: MailboxConfig): Mailbox {
        // 使用默认的优先级比较器
        let defaultComparator = { msg1: Message, msg2: Message =>
            msg1.priority() - msg2.priority()
        }
        
        // 基于Foundation队列创建优先级邮箱
        FoundationPriorityMailbox(config, defaultComparator)
    }
    
    /**
     * 创建暂存邮箱
     */
    private func createStashingMailbox(config: MailboxConfig): Mailbox {
        // 基于Foundation队列创建暂存邮箱
        FoundationStashingMailbox(config)
    }
    
    /**
     * 创建自定义邮箱
     */
    private func createCustomMailbox(config: MailboxConfig): Mailbox {
        // 默认回退到无界邮箱
        FoundationUnboundedMailbox(config)
    }
    
    /**
     * 创建高吞吐量优化邮箱
     */
    private func createHighThroughputMailbox(config: MailboxConfig): Mailbox {
        // 使用MPSC队列，优化批量操作
        let optimizedConfig = MailboxConfig(
            MailboxType.Bounded,
            config.capacity * 2,  // 增大容量
            config.pushTimeout,
            config.stashCapacity,
            "${config.name}-high-throughput"
        )
        MPSCMailbox(optimizedConfig)
    }
    
    /**
     * 创建低延迟优化邮箱
     */
    private func createLowLatencyMailbox(config: MailboxConfig): Mailbox {
        // 使用SPSC队列，最小化延迟
        let optimizedConfig = MailboxConfig(
            MailboxType.Bounded,
            if (config.capacity <= 0) { 256 } else { config.capacity },  // 较小容量
            Duration.microsecond * 100,  // 更短超时
            config.stashCapacity,
            "${config.name}-low-latency"
        )
        SPSCMailbox(optimizedConfig)
    }
    
    /**
     * 根据使用模式优化配置
     */
    private func optimizeConfig(config: MailboxConfig, usagePattern: UsagePattern): MailboxConfig {
        match (usagePattern) {
            case UsagePattern.HighThroughput =>
                MailboxConfig(
                    config.mailboxType,
                    config.capacity * 2,
                    config.pushTimeout,
                    config.stashCapacity,
                    "${config.name}-optimized"
                )
            case UsagePattern.LowLatency =>
                MailboxConfig(
                    config.mailboxType,
                    if (config.capacity <= 0) { 256 } else { config.capacity / 2 },
                    Duration.microsecond * 100,
                    config.stashCapacity,
                    "${config.name}-optimized"
                )
            case _ =>
                config
        }
    }
    
    /**
     * 记录创建统计
     */
    private func recordCreation(mailboxType: MailboxType): Unit {
        let typeName = match (mailboxType) {
            case MailboxType.Unbounded => "unbounded"
            case MailboxType.Bounded => "bounded"
            case MailboxType.Priority => "priority"
            case MailboxType.Stashing => "stashing"
            case MailboxType.Custom => "custom"
        }
        
        let currentCount = match (creationStats.get(typeName)) {
            case Some(count) => count
            case None => 0
        }
        creationStats.add(typeName, currentCount + 1)
    }
    
    /**
     * 获取创建统计信息
     */
    public func getCreationStats(): String {
        let stats = ArrayList<String>()
        for ((typeName, count) in creationStats) {
            stats.add("${typeName}: ${count}")
        }
        
        if (stats.isEmpty()) {
            return "No mailboxes created yet"
        }
        
        let result = StringBuilder()
        result.append("Mailbox Creation Stats: ")
        for (i in 0..stats.size) {
            if (i > 0) {
                result.append(", ")
            }
            result.append(stats[i])
        }
        result.toString()
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
        parts.add(str)
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
 * 邮箱工厂注册表
 * 管理多个邮箱工厂实例
 */
public class MailboxFactoryRegistry {
    private let factories: HashMap<String, AdvancedMailboxFactory>
    private let defaultFactory: AdvancedMailboxFactory
    
    public init() {
        this.factories = HashMap<String, AdvancedMailboxFactory>()
        this.defaultFactory = DefaultAdvancedMailboxFactory()
        
        // 注册默认工厂
        registerFactory("default", defaultFactory)
    }
    
    /**
     * 注册邮箱工厂
     */
    public func registerFactory(name: String, factory: AdvancedMailboxFactory): Unit {
        factories.add(name, factory)
    }
    
    /**
     * 获取邮箱工厂
     */
    public func getFactory(name: String): AdvancedMailboxFactory {
        match (factories.get(name)) {
            case Some(factory) => factory
            case None => defaultFactory
        }
    }
    
    /**
     * 获取默认工厂
     */
    public func getDefaultFactory(): AdvancedMailboxFactory {
        defaultFactory
    }
}
