/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - 配置工厂
 * 基于现有runtime包装，提供简洁的配置API
 */
package cactor.api.config

import cactor.runtime.mailbox.*
import cactor.runtime.dispatcher.*
import cactor.core.supervision.*
import std.time.*
import std.collection.*

/**
 * 邮箱配置工厂
 * 基于现有runtime.mailbox包装
 */
public struct MailboxConfig {
    private let mailboxType: String
    private let capacity: Int32
    private let options: HashMap<String, String>

    private init(mailboxType: String, capacity: Int32, options: HashMap<String, String>) {
        this.mailboxType = mailboxType
        this.capacity = capacity
        this.options = options
    }

    /**
     * 创建无界邮箱配置
     */
    public static func unbounded(): MailboxConfig {
        MailboxConfig("unbounded", -1, HashMap<String, String>())
    }

    /**
     * 创建有界邮箱配置
     */
    public static func bounded(capacity: Int32): MailboxConfig {
        MailboxConfig("bounded", capacity, HashMap<String, String>())
    }

    /**
     * 创建优先级邮箱配置
     */
    public static func priority(): MailboxConfig {
        MailboxConfig("priority", -1, HashMap<String, String>())
    }

    /**
     * 创建环形缓冲区邮箱配置
     */
    public static func ringBuffer(capacity: Int32): MailboxConfig {
        MailboxConfig("ring-buffer", capacity, HashMap<String, String>())
    }

    /**
     * 创建批处理邮箱配置
     */
    public static func batching(batchSize: Int32): MailboxConfig {
        let options = HashMap<String, String>()
        options.add("batchSize", batchSize.toString())
        MailboxConfig("batching", -1, options)
    }

    /**
     * 获取邮箱类型
     */
    public func getMailboxType(): String {
        mailboxType
    }

    /**
     * 获取容量
     */
    public func getCapacity(): Int32 {
        capacity
    }

    /**
     * 获取选项
     */
    public func getOptions(): HashMap<String, String> {
        options
    }
}

/**
 * 调度器配置工厂
 * 基于现有runtime.dispatcher包装
 */
public struct DispatcherConfig {
    private let dispatcherType: String
    private let parallelism: Int32
    private let throughput: Int32
    private let options: HashMap<String, String>

    private init(dispatcherType: String, parallelism: Int32, throughput: Int32, options: HashMap<String, String>) {
        this.dispatcherType = dispatcherType
        this.parallelism = parallelism
        this.throughput = throughput
        this.options = options
    }

    /**
     * 创建线程池调度器配置
     */
    public static func threadPool(size: Int32): DispatcherConfig {
        DispatcherConfig("thread-pool", size, 100, HashMap<String, String>())
    }

    /**
     * 创建默认线程池调度器配置
     */
    public static func threadPoolDefault(): DispatcherConfig {
        threadPool(4)
    }

    /**
     * 创建工作窃取调度器配置
     */
    public static func workStealing(parallelism: Int32): DispatcherConfig {
        DispatcherConfig("work-stealing", parallelism, 100, HashMap<String, String>())
    }

    /**
     * 创建默认工作窃取调度器配置
     */
    public static func workStealingDefault(): DispatcherConfig {
        workStealing(8)
    }

    /**
     * 创建固定线程调度器配置
     */
    public static func pinned(): DispatcherConfig {
        DispatcherConfig("pinned", 1, 100, HashMap<String, String>())
    }

    /**
     * 创建调用线程调度器配置
     */
    public static func callingThread(): DispatcherConfig {
        DispatcherConfig("calling-thread", 1, 100, HashMap<String, String>())
    }

    /**
     * 获取调度器类型
     */
    public func getDispatcherType(): String {
        dispatcherType
    }

    /**
     * 获取并行度
     */
    public func getParallelism(): Int32 {
        parallelism
    }

    /**
     * 获取吞吐量
     */
    public func getThroughput(): Int32 {
        throughput
    }

    /**
     * 获取选项
     */
    public func getOptions(): HashMap<String, String> {
        options
    }
}

/**
 * 监督策略配置工厂
 * 基于现有core.supervision包装
 */
public struct SupervisionConfig {
    private let strategyType: String
    private let maxRetries: Int32
    private let backoffDuration: Duration
    private let options: HashMap<String, String>

    private init(strategyType: String, maxRetries: Int32, backoffDuration: Duration, options: HashMap<String, String>) {
        this.strategyType = strategyType
        this.maxRetries = maxRetries
        this.backoffDuration = backoffDuration
        this.options = options
    }

    /**
     * 创建重启策略配置
     */
    public static func restart(maxRetries: Int32, backoff: Duration): SupervisionConfig {
        SupervisionConfig("restart", maxRetries, backoff, HashMap<String, String>())
    }

    /**
     * 创建默认重启策略配置
     */
    public static func restartDefault(): SupervisionConfig {
        restart(3, Duration.second)
    }

    /**
     * 创建停止策略配置
     */
    public static func stop(): SupervisionConfig {
        SupervisionConfig("stop", 0, Duration.second, HashMap<String, String>())
    }

    /**
     * 创建升级策略配置
     */
    public static func escalate(): SupervisionConfig {
        SupervisionConfig("escalate", 0, Duration.second, HashMap<String, String>())
    }

    /**
     * 创建恢复策略配置
     */
    public static func resume(): SupervisionConfig {
        SupervisionConfig("resume", 0, Duration.second, HashMap<String, String>())
    }

    /**
     * 获取策略类型
     */
    public func getStrategyType(): String {
        strategyType
    }

    /**
     * 获取最大重试次数
     */
    public func getMaxRetries(): Int32 {
        maxRetries
    }

    /**
     * 获取退避时间
     */
    public func getBackoffDuration(): Duration {
        backoffDuration
    }

    /**
     * 获取选项
     */
    public func getOptions(): HashMap<String, String> {
        options
    }
}
