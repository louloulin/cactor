/*
 * Copyright (c) 2024. All rights reserved.
 * MailboxFactory - 企业级邮箱工厂
 * 基于plan10.md设计，提供多种邮箱类型的统一创建和管理
 */
package cactor.runtime.mailbox

import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, Envelope}
// 移除循环依赖 - 不直接导入ActorSystemConfig
import cactor.foundation.queue.{LockFreeQueue}

/**
 * 邮箱类型枚举
 */
public enum MailboxType {
    | Unbounded      // 无界邮箱
    | Bounded        // 有界邮箱
    | Priority       // 优先级邮箱
    | Stashing       // 暂存邮箱
    | ZeroCopy       // 零拷贝邮箱
    | SingleConsumer // 单消费者邮箱
}

/**
 * 邮箱配置
 */
public struct MailboxConfig {
    public let mailboxType: MailboxType
    public let capacity: Int32
    public let enableBatching: Bool
    public let batchSize: Int32
    public let enableMetrics: Bool
    public let pushTimeOut: Int64  // 推送超时时间（纳秒）
    public let popTimeOut: Int64   // 弹出超时时间（纳秒）
    
    public init(
        mailboxType: MailboxType,
        capacity: Int32,
        enableBatching: Bool,
        batchSize: Int32,
        enableMetrics: Bool,
        pushTimeOut: Int64,
        popTimeOut: Int64
    ) {
        this.mailboxType = mailboxType
        this.capacity = capacity
        this.enableBatching = enableBatching
        this.batchSize = batchSize
        this.enableMetrics = enableMetrics
        this.pushTimeOut = pushTimeOut
        this.popTimeOut = popTimeOut
    }
    
    /**
     * 创建默认配置
     */
    public static func createDefault(): MailboxConfig {
        MailboxConfig(
            MailboxType.Unbounded,
            10000,  // 默认容量
            true,   // 启用批处理
            32,     // 批处理大小
            true,   // 启用指标
            1000000,  // 1ms推送超时
            5000000   // 5ms弹出超时
        )
    }
    
    /**
     * 创建高性能配置
     */
    public static func createHighPerformance(): MailboxConfig {
        MailboxConfig(
            MailboxType.ZeroCopy,
            50000,  // 大容量
            true,   // 启用批处理
            64,     // 大批处理
            true,   // 启用指标
            500000,   // 0.5ms推送超时
            2000000   // 2ms弹出超时
        )
    }
    
    /**
     * 创建有界配置
     */
    public static func createBounded(capacity: Int32): MailboxConfig {
        MailboxConfig(
            MailboxType.Bounded,
            capacity,
            true,   // 启用批处理
            16,     // 小批处理
            true,   // 启用指标
            2000000,  // 2ms推送超时
            10000000  // 10ms弹出超时
        )
    }
}

// 使用已存在的Mailbox接口，不重复定义

/**
 * 邮箱统计信息
 */
public struct MailboxStats {
    public let mailboxType: MailboxType
    public let capacity: Int32
    public let currentSize: Int32
    public let totalEnqueued: Int64
    public let totalDequeued: Int64
    public let totalDropped: Int64
    public let averageEnqueueTime: Float64
    public let averageDequeueTime: Float64
    
    public init(
        mailboxType: MailboxType,
        capacity: Int32,
        currentSize: Int32,
        totalEnqueued: Int64,
        totalDequeued: Int64,
        totalDropped: Int64,
        averageEnqueueTime: Float64,
        averageDequeueTime: Float64
    ) {
        this.mailboxType = mailboxType
        this.capacity = capacity
        this.currentSize = currentSize
        this.totalEnqueued = totalEnqueued
        this.totalDequeued = totalDequeued
        this.totalDropped = totalDropped
        this.averageEnqueueTime = averageEnqueueTime
        this.averageDequeueTime = averageDequeueTime
    }
    
    /**
     * 打印统计报告
     */
    public func printReport(): Unit {
        println("=== 邮箱统计报告 ===")
        println("邮箱类型: ${mailboxType}")
        println("容量: ${capacity}")
        println("当前大小: ${currentSize}")
        println("总入队: ${totalEnqueued}")
        println("总出队: ${totalDequeued}")
        println("总丢弃: ${totalDropped}")
        println("平均入队时间: ${averageEnqueueTime}μs")
        println("平均出队时间: ${averageDequeueTime}μs")
        
        let utilizationRate = if (capacity > 0) {
            Float64(currentSize) / Float64(capacity) * 100.0
        } else {
            0.0
        }
        println("利用率: ${utilizationRate}%")
        
        let dropRate = if (totalEnqueued > 0) {
            Float64(totalDropped) / Float64(totalEnqueued) * 100.0
        } else {
            0.0
        }
        println("丢弃率: ${dropRate}%")
        println("==================")
    }
}

/**
 * 邮箱工厂
 */
public class MailboxFactory {
    private let defaultConfig: MailboxConfig
    private let configMap: HashMap<String, MailboxConfig>
    private let createdMailboxes: AtomicInt64
    
    public init() {
        this.defaultConfig = MailboxConfig.createDefault()
        this.configMap = HashMap<String, MailboxConfig>()
        this.createdMailboxes = AtomicInt64(0)

        initializeConfigurations()
    }
    
    /**
     * 为Actor创建邮箱
     */
    public func createMailbox(actor: Actor, props: Props<Actor>): Mailbox {
        let config = selectMailboxConfig(actor, props)
        let mailbox = createMailboxByType(config)
        
        createdMailboxes.fetchAdd(1)
        return mailbox
    }
    
    /**
     * 根据配置创建邮箱
     */
    public func createMailboxWithConfig(config: MailboxConfig): Mailbox {
        let mailbox = createMailboxByType(config)
        createdMailboxes.fetchAdd(1)
        return mailbox
    }
    
    /**
     * 注册邮箱配置
     */
    public func registerConfig(name: String, config: MailboxConfig): Unit {
        configMap.put(name, config)
    }
    
    /**
     * 获取邮箱配置
     */
    public func getConfig(name: String): Option<MailboxConfig> {
        configMap.get(name)
    }
    
    /**
     * 获取工厂统计信息
     */
    public func getFactoryStats(): MailboxFactoryStats {
        MailboxFactoryStats(
            createdMailboxes.load(),
            configMap.size(),
            defaultConfig
        )
    }
    
    /**
     * 选择邮箱配置
     */
    private func selectMailboxConfig(actor: Actor, props: Props<Actor>): MailboxConfig {
        // 简化实现，使用默认配置
        defaultConfig
    }
    
    /**
     * 根据类型创建邮箱
     */
    private func createMailboxByType(config: MailboxConfig): Mailbox {
        match (config.mailboxType) {
            case MailboxType.Unbounded =>
                UnboundedMailbox(config)
            case MailboxType.Bounded =>
                BoundedMailbox(config)
            case _ =>
                // 其他类型暂时使用无界邮箱
                UnboundedMailbox(config)
        }
    }
    
    /**
     * 初始化配置
     */
    private func initializeConfigurations(): Unit {
        // 注册预定义配置
        registerConfig("default", MailboxConfig.createDefault())
        registerConfig("high-performance", MailboxConfig.createHighPerformance())
        registerConfig("bounded-small", MailboxConfig.createBounded(100))
        registerConfig("bounded-medium", MailboxConfig.createBounded(1000))
        registerConfig("bounded-large", MailboxConfig.createBounded(10000))
        
        // 注册优先级邮箱配置
        let priorityConfig = MailboxConfig(
            MailboxType.Priority,
            5000,
            true,
            16,
            true,
            1000000,
            5000000
        )
        registerConfig("priority", priorityConfig)
        
        // 注册暂存邮箱配置
        let stashingConfig = MailboxConfig(
            MailboxType.Stashing,
            2000,
            false,  // 暂存邮箱不使用批处理
            1,
            true,
            2000000,
            10000000
        )
        registerConfig("stashing", stashingConfig)
    }
}

/**
 * 邮箱工厂统计信息
 */
public struct MailboxFactoryStats {
    public let createdMailboxes: Int64
    public let registeredConfigs: Int32
    public let defaultConfig: MailboxConfig
    
    public init(createdMailboxes: Int64, registeredConfigs: Int32, defaultConfig: MailboxConfig) {
        this.createdMailboxes = createdMailboxes
        this.registeredConfigs = registeredConfigs
        this.defaultConfig = defaultConfig
    }
    
    /**
     * 打印工厂统计报告
     */
    public func printReport(): Unit {
        println("=== 邮箱工厂统计报告 ===")
        println("已创建邮箱数: ${createdMailboxes}")
        println("注册配置数: ${registeredConfigs}")
        println("默认邮箱类型: ${defaultConfig.mailboxType}")
        println("默认容量: ${defaultConfig.capacity}")
        println("======================")
    }
}
