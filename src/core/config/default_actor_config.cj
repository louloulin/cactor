/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 默认Actor配置实现
 * 提供开箱即用的Actor配置实现
 */
package cactor.core.config

import std.time.*
import std.collection.*
import cactor.core.message.Message

/**
 * 默认Actor配置实现
 * 提供标准的Actor配置，适用于大多数使用场景
 */
public class DefaultActorConfiguration <: ActorConfiguration {
    private let mailboxConfig: MailboxConfig
    private let dispatcherConfig: DispatcherConfig
    private let supervisionConfig: SupervisionConfig
    private let routingConfig: Option<RoutingConfig>
    private let name: String
    private let description: String
    
    public init(mailboxConfig: MailboxConfig, dispatcherConfig: DispatcherConfig,
                supervisionConfig: SupervisionConfig, routingConfig: Option<RoutingConfig>,
                name: String, description: String) {
        this.mailboxConfig = mailboxConfig
        this.dispatcherConfig = dispatcherConfig
        this.supervisionConfig = supervisionConfig
        this.routingConfig = routingConfig
        this.name = name
        this.description = description
    }
    
    public func getMailboxConfig(): MailboxConfig {
        mailboxConfig
    }
    
    public func getDispatcherConfig(): DispatcherConfig {
        dispatcherConfig
    }
    
    public func getSupervisionConfig(): SupervisionConfig {
        supervisionConfig
    }
    
    public func getRoutingConfig(): Option<RoutingConfig> {
        routingConfig
    }
    
    public func getName(): String {
        name
    }
    
    public func getDescription(): String {
        description
    }
}

/**
 * Actor配置工厂类
 * 提供预定义的Actor配置模板，参考Akka配置模式
 */
public class ActorConfigurationFactory {
    
    /**
     * 创建默认配置
     * 适用于一般用途的Actor
     */
    public static func createDefault(): ActorConfiguration {
        DefaultActorConfiguration(
            MailboxConfig.createUnboundedWithName("default-unbounded"),
            DispatcherConfig.createThreadPoolWithName("default-dispatcher"),
            SupervisionConfig.createDefaultWithName("default-supervision"),
            None<RoutingConfig>,
            "default-config",
            "默认Actor配置，适用于一般用途"
        )
    }
    
    /**
     * 创建高性能配置
     * 适用于高吞吐量、低延迟的Actor
     */
    public static func createHighPerformance(): ActorConfiguration {
        DefaultActorConfiguration(
            MailboxConfig.createBoundedWithName(8192, "high-perf-bounded"),
            DispatcherConfig.createWorkStealingWithName("high-perf-work-stealing"),
            SupervisionConfig.createDefaultWithName("high-perf-supervision"),
            None<RoutingConfig>,
            "high-performance-config",
            "高性能Actor配置，适用于高吞吐量场景"
        )
    }

    /**
     * 创建批处理配置
     * 适用于批量处理消息的Actor
     */
    public static func createBatching(): ActorConfiguration {
        DefaultActorConfiguration(
            MailboxConfig.createBoundedWithName(4096, "batching-bounded"),
            DispatcherConfig.createThreadPoolWithName("batching-dispatcher"),
            SupervisionConfig.createDefaultWithName("batching-supervision"),
            None<RoutingConfig>,
            "batching-config",
            "批处理Actor配置，适用于批量消息处理"
        )
    }

    /**
     * 创建关键任务配置
     * 适用于关键任务的Actor，使用专用线程
     */
    public static func createCritical(): ActorConfiguration {
        DefaultActorConfiguration(
            MailboxConfig.createBoundedWithName(1024, "critical-bounded"),
            DispatcherConfig.createPinnedWithName("critical-pinned"),
            SupervisionConfig(
                1,  // 最大重试1次
                Duration.second * 30,
                SupervisionStrategyType.OneForOne,
                "critical-supervision"
            ),
            None<RoutingConfig>,
            "critical-config",
            "关键任务Actor配置，使用专用线程和严格监督"
        )
    }
    
    /**
     * 创建优先级配置
     * 适用于需要消息优先级处理的Actor
     */
    public static func createPriority(comparator: (Message, Message) -> Int32): ActorConfiguration {
        DefaultActorConfiguration(
            MailboxConfig.createPriorityWithCapacity(comparator, 2048, "priority-mailbox"),
            DispatcherConfig.createThreadPoolWithName("priority-dispatcher"),
            SupervisionConfig.createDefaultWithName("priority-supervision"),
            None<RoutingConfig>,
            "priority-config",
            "优先级Actor配置，支持消息优先级处理"
        )
    }

    /**
     * 创建暂存配置
     * 适用于需要消息暂存功能的Actor
     */
    public static func createStashing(capacity: Int64, stashCapacity: Int64): ActorConfiguration {
        DefaultActorConfiguration(
            MailboxConfig.createStashingWithName(capacity, stashCapacity, "stashing-mailbox"),
            DispatcherConfig.createThreadPoolWithName("stashing-dispatcher"),
            SupervisionConfig.createDefaultWithName("stashing-supervision"),
            None<RoutingConfig>,
            "stashing-config",
            "暂存Actor配置，支持消息暂存功能"
        )
    }

    /**
     * 创建路由配置
     * 适用于需要负载均衡的Actor
     */
    public static func createRouted(routerType: RouterType, routeeCount: Int32): ActorConfiguration {
        let routingConfig = RoutingConfig(routerType, routeeCount, "default-routing")

        DefaultActorConfiguration(
            MailboxConfig.createUnboundedWithName("routed-unbounded"),
            DispatcherConfig.createWorkStealingWithName("routed-work-stealing"),
            SupervisionConfig.createDefaultWithName("routed-supervision"),
            Some(routingConfig),
            "routed-config",
            "路由Actor配置，支持负载均衡"
        )
    }
    
    /**
     * 创建自定义配置
     * 允许完全自定义所有配置参数
     */
    public static func createCustom(mailboxConfig: MailboxConfig,
                                   dispatcherConfig: DispatcherConfig,
                                   supervisionConfig: SupervisionConfig,
                                   routingConfig: Option<RoutingConfig>,
                                   name: String,
                                   description: String): ActorConfiguration {
        DefaultActorConfiguration(
            mailboxConfig,
            dispatcherConfig,
            supervisionConfig,
            routingConfig,
            name,
            description
        )
    }
}

/**
 * 配置管理器
 * 管理和缓存Actor配置
 */
public class ConfigurationManager {
    private let configurations: HashMap<String, ActorConfiguration>
    private let defaultConfig: ActorConfiguration
    
    public init() {
        this.configurations = HashMap<String, ActorConfiguration>()
        this.defaultConfig = ActorConfigurationFactory.createDefault()
        
        // 注册预定义配置
        registerPredefinedConfigurations()
    }
    
    /**
     * 注册预定义配置
     */
    private func registerPredefinedConfigurations(): Unit {
        registerConfiguration("default", ActorConfigurationFactory.createDefault())
        registerConfiguration("high-performance", ActorConfigurationFactory.createHighPerformance())
        registerConfiguration("batching", ActorConfigurationFactory.createBatching())
        registerConfiguration("critical", ActorConfigurationFactory.createCritical())
        registerConfiguration("stashing", ActorConfigurationFactory.createStashing())
    }
    
    /**
     * 注册配置
     */
    public func registerConfiguration(name: String, config: ActorConfiguration): Unit {
        configurations.put(name, config)
    }
    
    /**
     * 获取配置
     */
    public func getConfiguration(name: String): ActorConfiguration {
        match (configurations.get(name)) {
            case Some(config) => config
            case None => defaultConfig
        }
    }
    
    /**
     * 获取默认配置
     */
    public func getDefaultConfiguration(): ActorConfiguration {
        defaultConfig
    }
    
    /**
     * 检查配置是否存在
     */
    public func hasConfiguration(name: String): Bool {
        configurations.containsKey(name)
    }
    
    /**
     * 获取所有配置名称
     */
    public func getConfigurationNames(): Array<String> {
        let names = ArrayList<String>()
        for ((name, _) in configurations) {
            names.append(name)
        }
        Array<String>(Int64(names.size), { i => names[i] })
    }
    
    /**
     * 移除配置
     */
    public func removeConfiguration(name: String): Bool {
        match (configurations.remove(name)) {
            case Some(_) => true
            case None => false
        }
    }
    
    /**
     * 清空所有配置（保留默认配置）
     */
    public func clearConfigurations(): Unit {
        configurations.clear()
        registerPredefinedConfigurations()
    }
}

/**
 * 配置构建器
 * 提供流式API构建Actor配置
 */
public class ActorConfigurationBuilder {
    private var mailboxConfig: Option<MailboxConfig>
    private var dispatcherConfig: Option<DispatcherConfig>
    private var supervisionConfig: Option<SupervisionConfig>
    private var routingConfig: Option<RoutingConfig>
    private var name: String
    private var description: String
    
    public init() {
        this.mailboxConfig = None<MailboxConfig>
        this.dispatcherConfig = None<DispatcherConfig>
        this.supervisionConfig = None<SupervisionConfig>
        this.routingConfig = None<RoutingConfig>
        this.name = "custom-config"
        this.description = "自定义Actor配置"
    }
    
    /**
     * 设置邮箱配置
     */
    public func withMailbox(config: MailboxConfig): ActorConfigurationBuilder {
        this.mailboxConfig = Some(config)
        return this
    }
    
    /**
     * 设置调度器配置
     */
    public func withDispatcher(config: DispatcherConfig): ActorConfigurationBuilder {
        this.dispatcherConfig = Some(config)
        return this
    }
    
    /**
     * 设置监督策略配置
     */
    public func withSupervision(config: SupervisionConfig): ActorConfigurationBuilder {
        this.supervisionConfig = Some(config)
        return this
    }
    
    /**
     * 设置路由配置
     */
    public func withRouting(config: RoutingConfig): ActorConfigurationBuilder {
        this.routingConfig = Some(config)
        return this
    }
    
    /**
     * 设置名称
     */
    public func withName(name: String): ActorConfigurationBuilder {
        this.name = name
        return this
    }
    
    /**
     * 设置描述
     */
    public func withDescription(description: String): ActorConfigurationBuilder {
        this.description = description
        return this
    }
    
    /**
     * 构建配置
     */
    public func build(): ActorConfiguration {
        let finalMailboxConfig = match (mailboxConfig) {
            case Some(config) => config
            case None => MailboxConfig.createUnbounded()
        }
        
        let finalDispatcherConfig = match (dispatcherConfig) {
            case Some(config) => config
            case None => DispatcherConfig.createThreadPool()
        }
        
        let finalSupervisionConfig = match (supervisionConfig) {
            case Some(config) => config
            case None => SupervisionConfig.createDefault()
        }
        
        DefaultActorConfiguration(
            finalMailboxConfig,
            finalDispatcherConfig,
            finalSupervisionConfig,
            routingConfig,
            name,
            description
        )
    }
}
