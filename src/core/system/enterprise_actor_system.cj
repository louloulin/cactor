/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Core - 企业级ActorSystem接口
 * 扩展基础ActorSystem，添加企业级特性
 */
package cactor.core.system

import std.time.*
import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message}

/**
 * 企业级ActorSystem接口
 * 扩展基础ActorSystem，添加配置、扩展、监控等企业级特性
 */
public interface EnterpriseActorSystem <: ActorSystem {
    /**
     * 获取系统配置
     * @return Actor系统配置
     */
    func getConfig(): ActorSystemConfig
    
    /**
     * 更新系统配置
     * @param config 新的配置
     */
    func updateConfig(config: ActorSystemConfig): Unit
    
    /**
     * 注册扩展
     * @param extension 要注册的扩展
     */
    func registerExtension(extension: ActorSystemExtension): Unit

    /**
     * 获取扩展
     * @param extensionName 扩展名称
     * @return 扩展实例
     */
    func getExtension(extensionName: String): Option<ActorSystemExtension>
    
    /**
     * 获取系统指标
     * @return 系统指标
     */
    func getMetrics(): ActorSystemMetrics
    
    /**
     * 获取事件总线
     * @return 事件总线
     */
    func getEventBus(): EventBus
    
    /**
     * 获取系统终止Future
     * @return 终止Future
     */
    func whenTerminated(): SimpleFuture<Unit>
    
    /**
     * 带超时的终止
     * @param timeout 超时时间
     * @return 终止Future
     */
    func terminate(timeout: Duration): SimpleFuture<Unit>
    
    /**
     * 获取系统Guardian
     * @return 系统Guardian引用
     */
    func getSystemGuardian(): ActorRef
    
    /**
     * 获取用户Guardian
     * @return 用户Guardian引用
     */
    func getUserGuardian(): ActorRef
    
    /**
     * 获取系统启动时间
     * @return 启动时间戳
     */
    func getStartTime(): DateTime
    
    /**
     * 获取系统运行时长
     * @return 运行时长
     */
    func getUptime(): Duration
}

/**
 * Actor系统配置
 */
public struct ActorSystemConfig {
    public let dispatchers: DispatcherConfig
    public let mailboxes: MailboxConfig
    public let supervision: SupervisionConfig
    public let monitoring: MonitoringConfig
    public let clustering: ClusterConfig
    
    public init(
        dispatchers: DispatcherConfig,
        mailboxes: MailboxConfig,
        supervision: SupervisionConfig,
        monitoring: MonitoringConfig,
        clustering: ClusterConfig
    ) {
        this.dispatchers = dispatchers
        this.mailboxes = mailboxes
        this.supervision = supervision
        this.monitoring = monitoring
        this.clustering = clustering
    }
    
    /**
     * 创建默认配置
     */
    public static func default(): ActorSystemConfig {
        ActorSystemConfig(
            DispatcherConfig.default(),
            MailboxConfig.default(),
            SupervisionConfig.default(),
            MonitoringConfig.default(),
            ClusterConfig.default()
        )
    }
}

/**
 * 调度器配置
 */
public struct DispatcherConfig {
    public let defaultDispatcher: String
    public let parallelism: Int32
    public let throughput: Int32
    public let dispatcherTypes: HashMap<String, String>
    
    public init(defaultDispatcher: String, parallelism: Int32, throughput: Int32, dispatcherTypes: HashMap<String, String>) {
        this.defaultDispatcher = defaultDispatcher
        this.parallelism = parallelism
        this.throughput = throughput
        this.dispatcherTypes = dispatcherTypes
    }
    
    public static func default(): DispatcherConfig {
        let types = HashMap<String, String>()
        types.add("default", "work-stealing")
        types.add("blocking-io", "pinned")
        types.add("high-throughput", "fork-join")
        
        DispatcherConfig("default", 8, 100, types)
    }
}

/**
 * 邮箱配置
 */
public struct MailboxConfig {
    public let defaultMailbox: String
    public let mailboxTypes: HashMap<String, String>
    public let capacities: HashMap<String, Int64>
    
    public init(defaultMailbox: String, mailboxTypes: HashMap<String, String>, capacities: HashMap<String, Int64>) {
        this.defaultMailbox = defaultMailbox
        this.mailboxTypes = mailboxTypes
        this.capacities = capacities
    }
    
    public static func default(): MailboxConfig {
        let types = HashMap<String, String>()
        types.add("default", "unbounded")
        types.add("bounded", "bounded")
        types.add("priority", "priority")
        
        let capacities = HashMap<String, Int64>()
        capacities.add("bounded", 10000)
        capacities.add("priority", 5000)
        
        MailboxConfig("default", types, capacities)
    }
}

/**
 * 监督配置
 */
public struct SupervisionConfig {
    public let defaultStrategy: String
    public let maxRetries: Int32
    public let withinTimeRange: Duration
    
    public init(defaultStrategy: String, maxRetries: Int32, withinTimeRange: Duration) {
        this.defaultStrategy = defaultStrategy
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
    }
    
    public static func default(): SupervisionConfig {
        SupervisionConfig("one-for-one", 3, Duration.minute)
    }
}

/**
 * 监控配置
 */
public struct MonitoringConfig {
    public let enabled: Bool
    public let metricsInterval: Duration
    public let prometheusEnabled: Bool
    public let prometheusPort: Int32
    
    public init(enabled: Bool, metricsInterval: Duration, prometheusEnabled: Bool, prometheusPort: Int32) {
        this.enabled = enabled
        this.metricsInterval = metricsInterval
        this.prometheusEnabled = prometheusEnabled
        this.prometheusPort = prometheusPort
    }
    
    public static func default(): MonitoringConfig {
        MonitoringConfig(true, Duration.second * 10, false, 9090)
    }
}

/**
 * 集群配置
 */
public struct ClusterConfig {
    public let enabled: Bool
    public let seedNodes: Array<String>
    public let port: Int32
    
    public init(enabled: Bool, seedNodes: Array<String>, port: Int32) {
        this.enabled = enabled
        this.seedNodes = seedNodes
        this.port = port
    }
    
    public static func default(): ClusterConfig {
        ClusterConfig(false, Array<String>(), 2551)
    }
}

/**
 * Actor系统扩展接口
 */
public interface ActorSystemExtension {
    /**
     * 初始化扩展
     * @param system Actor系统
     */
    func initialize(system: ActorSystem): Unit
    
    /**
     * 关闭扩展
     */
    func shutdown(): Unit
    
    /**
     * 获取扩展名称
     * @return 扩展名称
     */
    func getName(): String
    
    /**
     * 获取扩展版本
     * @return 扩展版本
     */
    func getVersion(): String
}

/**
 * Actor系统指标接口
 */
public interface ActorSystemMetrics {
    /**
     * 获取Actor数量
     * @return Actor总数
     */
    func getActorCount(): Int64
    
    /**
     * 获取消息吞吐量
     * @return 每秒消息数
     */
    func getMessageThroughput(): Float64
    
    /**
     * 获取平均消息延迟
     * @return 平均延迟
     */
    func getAverageMessageLatency(): Duration
    
    /**
     * 获取邮箱大小统计
     * @return 邮箱大小映射
     */
    func getMailboxSizes(): HashMap<String, Int64>
    
    /**
     * 获取调度器利用率
     * @return 调度器利用率映射
     */
    func getDispatcherUtilization(): HashMap<String, Float64>
    
    /**
     * 获取系统内存使用
     * @return 内存使用字节数
     */
    func getMemoryUsage(): Int64
    
    /**
     * 获取错误计数
     * @return 错误总数
     */
    func getErrorCount(): Int64
}

/**
 * 事件总线接口
 */
public interface EventBus {
    /**
     * 发布事件
     * @param event 要发布的事件
     */
    func publish(event: Event): Unit
    
    /**
     * 订阅主题
     * @param subscriber 订阅者
     * @param topic 主题
     */
    func subscribe(subscriber: ActorRef, topic: String): Unit
    
    /**
     * 取消订阅
     * @param subscriber 订阅者
     * @param topic 主题
     */
    func unsubscribe(subscriber: ActorRef, topic: String): Unit
    
    /**
     * 获取订阅者数量
     * @param topic 主题
     * @return 订阅者数量
     */
    func getSubscriberCount(topic: String): Int64
}

/**
 * 事件基础接口
 */
public interface Event {
    /**
     * 获取事件类型
     * @return 事件类型
     */
    func getEventType(): String
    
    /**
     * 获取事件时间戳
     * @return 时间戳
     */
    func getTimestamp(): DateTime
    
    /**
     * 获取事件数据
     * @return 事件数据
     */
    func getEventData(): String
}
