/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API 2.0 - 配置API
 * 提供简化的配置接口
 */
package cactor.api

import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}
import std.time.*

/**
 * Actor配置组合类
 * 将邮箱、调度器、监督策略组合为一个配置对象
 */
public struct ActorConfig {
    public let mailbox: MailboxConfig
    public let dispatcher: DispatcherConfig
    public let supervision: SupervisionConfig
    
    public init(mailbox: MailboxConfig, dispatcher: DispatcherConfig, supervision: SupervisionConfig) {
        this.mailbox = mailbox
        this.dispatcher = dispatcher
        this.supervision = supervision
    }
    
    /**
     * 默认配置
     * @return 默认Actor配置
     */
    public static func default(): ActorConfig {
        ActorConfig(
            MailboxConfig.unbounded(),
            DispatcherConfig.threadPoolDefault(),
            SupervisionConfig.restartDefault()
        )
    }
    
    /**
     * 高性能配置
     * @return 高性能Actor配置
     */
    public static func highPerformance(): ActorConfig {
        ActorConfig(
            MailboxConfig.bounded(10000),
            DispatcherConfig.workStealing(8),
            SupervisionConfig.restart(5, Duration.second * 2)
        )
    }
    
    /**
     * 低延迟配置
     * @return 低延迟Actor配置
     */
    public static func lowLatency(): ActorConfig {
        ActorConfig(
            MailboxConfig.unbounded(),
            DispatcherConfig.workStealing(4),
            SupervisionConfig.restart(1, Duration.millisecond * 100)
        )
    }
    
    /**
     * 批处理配置
     * @return 批处理Actor配置
     */
    public static func batching(): ActorConfig {
        ActorConfig(
            MailboxConfig.bounded(50000),
            DispatcherConfig.threadPool(16),
            SupervisionConfig.restart(10, Duration.second * 5)
        )
    }
}

/**
 * 简化的邮箱配置API
 */
public struct Mailbox {
    /**
     * 无界邮箱
     * @return 无界邮箱配置
     */
    public static func unbounded(): MailboxConfig {
        MailboxConfig.unbounded()
    }
    
    /**
     * 有界邮箱
     * @param capacity 邮箱容量
     * @return 有界邮箱配置
     */
    public static func bounded(capacity: Int32): MailboxConfig {
        MailboxConfig.bounded(capacity)
    }
    
    /**
     * 优先级邮箱
     * @return 优先级邮箱配置
     */
    public static func priority(): MailboxConfig {
        MailboxConfig.priority()
    }
}

/**
 * 简化的调度器配置API
 */
public struct Dispatcher {
    /**
     * 默认调度器
     * @return 默认调度器配置
     */
    public static func default(): DispatcherConfig {
        DispatcherConfig.threadPoolDefault()
    }
    
    /**
     * 工作窃取调度器（默认并行度）
     * @return 工作窃取调度器配置
     */
    public static func workStealing(): DispatcherConfig {
        DispatcherConfig.workStealingDefault()
    }
    
    /**
     * 工作窃取调度器（指定并行度）
     * @param parallelism 并行度
     * @return 工作窃取调度器配置
     */
    public static func workStealing(parallelism: Int32): DispatcherConfig {
        DispatcherConfig.workStealing(parallelism)
    }
    
    /**
     * 线程池调度器（默认大小）
     * @return 线程池调度器配置
     */
    public static func threadPool(): DispatcherConfig {
        DispatcherConfig.threadPoolDefault()
    }
    
    /**
     * 线程池调度器（指定大小）
     * @param size 线程池大小
     * @return 线程池调度器配置
     */
    public static func threadPool(size: Int32): DispatcherConfig {
        DispatcherConfig.threadPool(size)
    }
}

/**
 * 简化的监督策略配置API
 */
public struct Supervision {
    /**
     * 重启策略（默认重试次数）
     * @return 重启监督策略配置
     */
    public static func restart(): SupervisionConfig {
        SupervisionConfig.restartDefault()
    }
    
    /**
     * 重启策略（指定重试次数）
     * @param maxRetries 最大重试次数
     * @return 重启监督策略配置
     */
    public static func restart(maxRetries: Int32): SupervisionConfig {
        SupervisionConfig.restart(maxRetries, Duration.second * 1)
    }
    
    /**
     * 停止策略
     * @return 停止监督策略配置
     */
    public static func stop(): SupervisionConfig {
        SupervisionConfig.stop()
    }
    
    /**
     * 升级策略
     * @return 升级监督策略配置
     */
    public static func escalate(): SupervisionConfig {
        SupervisionConfig.escalate()
    }
}
