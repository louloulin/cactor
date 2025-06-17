/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor配置框架
 * 基于仓颉语言特性的Actor配置系统，参考Akka配置模式
 */
package cactor.core.config

import std.time.*
import std.collection.*
import cactor.core.message.Message
// 移除循环依赖 - 使用前向声明

/**
 * Actor配置接口
 * 定义Actor的完整配置信息，包括Mailbox、Dispatcher、监督策略等
 */
public interface ActorConfiguration {
    /**
     * 获取邮箱配置
     */
    func getMailboxConfig(): MailboxConfig
    
    /**
     * 获取调度器配置
     */
    func getDispatcherConfig(): DispatcherConfig
    
    /**
     * 获取监督策略配置
     */
    func getSupervisionConfig(): SupervisionConfig
    
    /**
     * 获取路由配置（可选）
     */
    func getRoutingConfig(): Option<RoutingConfig>
    
    /**
     * 获取配置名称
     */
    func getName(): String
    
    /**
     * 获取配置描述
     */
    func getDescription(): String
}

/**
 * 邮箱类型枚举
 * 支持多种邮箱类型，参考Akka邮箱设计
 */
public enum MailboxType {
    | Unbounded                                    // 无界邮箱
    | Bounded                                      // 有界邮箱
    | Priority                                     // 优先级邮箱
    | Stashing                                     // 支持暂存的邮箱
    | Custom                                       // 自定义邮箱
}

/**
 * 邮箱配置类
 * 包含邮箱的所有配置参数
 */
public class MailboxConfig {
    public let mailboxType: MailboxType
    public let capacity: Int64
    public let pushTimeout: Duration
    public let stashCapacity: Int64
    public let name: String
    
    public init(mailboxType: MailboxType, capacity: Int64, pushTimeout: Duration, 
                stashCapacity: Int64, name: String) {
        this.mailboxType = mailboxType
        this.capacity = capacity
        this.pushTimeout = pushTimeout
        this.stashCapacity = stashCapacity
        this.name = name
    }
    
    /**
     * 创建默认无界邮箱配置
     */
    public static func createUnbounded(): MailboxConfig {
        MailboxConfig.createUnboundedWithName("unbounded")
    }

    /**
     * 创建命名无界邮箱配置
     */
    public static func createUnboundedWithName(name: String): MailboxConfig {
        MailboxConfig(
            MailboxType.Unbounded,
            -1,  // 无界
            Duration.second * 10,
            0,
            name
        )
    }

    /**
     * 创建有界邮箱配置
     */
    public static func createBounded(capacity: Int64): MailboxConfig {
        MailboxConfig.createBoundedWithName(capacity, "bounded")
    }

    /**
     * 创建命名有界邮箱配置
     */
    public static func createBoundedWithName(capacity: Int64, name: String): MailboxConfig {
        MailboxConfig(
            MailboxType.Bounded,
            capacity,
            Duration.second * 10,
            0,
            name
        )
    }

    /**
     * 创建优先级邮箱配置
     */
    public static func createPriority(comparator: (Message, Message) -> Int32): MailboxConfig {
        MailboxConfig.createPriorityWithCapacity(comparator, 1000, "priority")
    }

    /**
     * 创建带容量的优先级邮箱配置
     */
    public static func createPriorityWithCapacity(comparator: (Message, Message) -> Int32,
                                                 capacity: Int64,
                                                 name: String): MailboxConfig {
        MailboxConfig(
            MailboxType.Priority,
            capacity,
            Duration.second * 10,
            0,
            name
        )
    }

    /**
     * 创建支持暂存的邮箱配置
     */
    public static func createStashing(capacity: Int64, stashCapacity: Int64): MailboxConfig {
        MailboxConfig.createStashingWithName(capacity, stashCapacity, "stashing")
    }

    /**
     * 创建命名暂存邮箱配置
     */
    public static func createStashingWithName(capacity: Int64, stashCapacity: Int64,
                                             name: String): MailboxConfig {
        MailboxConfig(
            MailboxType.Stashing,
            capacity,
            Duration.second * 10,
            stashCapacity,
            name
        )
    }
}

/**
 * 调度器类型枚举
 * 支持多种调度器类型，参考Akka调度器设计
 */
public enum DispatcherType {
    | ThreadPool                                           // 线程池调度器
    | WorkStealing                                         // 工作窃取调度器
    | PinnedDispatcher                                     // 专用线程调度器
    | CallingThread                                        // 调用线程调度器
    | Custom                                               // 自定义调度器
}

/**
 * 执行器配置类
 * 配置底层执行器的参数
 */
public class ExecutorConfig {
    public let corePoolSize: Int32
    public let maxPoolSize: Int32
    public let keepAliveTime: Duration
    public let queueCapacity: Int32
    
    public init(corePoolSize: Int32, maxPoolSize: Int32, 
                keepAliveTime: Duration, queueCapacity: Int32) {
        this.corePoolSize = corePoolSize
        this.maxPoolSize = maxPoolSize
        this.keepAliveTime = keepAliveTime
        this.queueCapacity = queueCapacity
    }
    
    /**
     * 创建默认执行器配置
     */
    public static func createDefault(): ExecutorConfig {
        ExecutorConfig(
            8,   // 核心线程数
            16,  // 最大线程数
            Duration.second * 60,  // 保活时间
            1000  // 队列容量
        )
    }
}

/**
 * 调度器配置类
 * 包含调度器的所有配置参数
 */
public class DispatcherConfig {
    public let dispatcherType: DispatcherType
    public let throughput: Int32
    public let throughputDeadlineTime: Duration
    public let executorConfig: ExecutorConfig
    public let name: String
    
    public init(dispatcherType: DispatcherType, throughput: Int32, 
                throughputDeadlineTime: Duration, executorConfig: ExecutorConfig, 
                name: String) {
        this.dispatcherType = dispatcherType
        this.throughput = throughput
        this.throughputDeadlineTime = throughputDeadlineTime
        this.executorConfig = executorConfig
        this.name = name
    }
    
    /**
     * 创建默认线程池调度器配置
     */
    public static func createThreadPool(): DispatcherConfig {
        DispatcherConfig.createThreadPoolWithName("default-thread-pool")
    }

    /**
     * 创建命名线程池调度器配置
     */
    public static func createThreadPoolWithName(name: String): DispatcherConfig {
        DispatcherConfig(
            DispatcherType.ThreadPool,
            100,  // 吞吐量
            Duration.millisecond * 100,  // 吞吐量截止时间
            ExecutorConfig.createDefault(),
            name
        )
    }

    /**
     * 创建工作窃取调度器配置
     */
    public static func createWorkStealing(): DispatcherConfig {
        DispatcherConfig.createWorkStealingWithName("work-stealing")
    }

    /**
     * 创建命名工作窃取调度器配置
     */
    public static func createWorkStealingWithName(name: String): DispatcherConfig {
        DispatcherConfig(
            DispatcherType.WorkStealing,
            50,  // 工作窃取调度器通常使用较低的吞吐量
            Duration.millisecond * 50,
            ExecutorConfig.createDefault(),
            name
        )
    }

    /**
     * 创建专用线程调度器配置
     */
    public static func createPinned(): DispatcherConfig {
        DispatcherConfig.createPinnedWithName("pinned")
    }

    /**
     * 创建命名专用线程调度器配置
     */
    public static func createPinnedWithName(name: String): DispatcherConfig {
        DispatcherConfig(
            DispatcherType.PinnedDispatcher,
            1,  // 专用线程每次只处理一个消息
            Duration.millisecond * 10,
            ExecutorConfig.createDefault(),
            name
        )
    }
}

/**
 * 监督指令枚举
 * 定义监督者对失败Actor的处理策略
 */
public enum SupervisionDirective {
    | Resume          // 恢复Actor，忽略异常
    | Restart         // 重启Actor
    | Stop            // 停止Actor
    | Escalate        // 向上级监督者报告
}

/**
 * 监督策略配置类
 * 配置Actor的监督策略
 */
public class SupervisionConfig {
    public let maxRetries: Int32
    public let withinTimeRange: Duration
    public let strategy: SupervisionStrategyType
    public let name: String
    
    public init(maxRetries: Int32, withinTimeRange: Duration, 
                strategy: SupervisionStrategyType, name: String) {
        this.maxRetries = maxRetries
        this.withinTimeRange = withinTimeRange
        this.strategy = strategy
        this.name = name
    }
    
    /**
     * 创建默认监督策略配置
     */
    public static func createDefault(): SupervisionConfig {
        SupervisionConfig.createDefaultWithName("default-supervision")
    }

    /**
     * 创建命名默认监督策略配置
     */
    public static func createDefaultWithName(name: String): SupervisionConfig {
        SupervisionConfig(
            3,  // 最大重试次数
            Duration.minute,  // 时间范围
            SupervisionStrategyType.OneForOne,
            name
        )
    }
}

/**
 * 监督策略类型枚举
 */
public enum SupervisionStrategyType {
    | OneForOne       // 一对一策略
    | AllForOne       // 全部策略
    | Custom          // 自定义策略
}

/**
 * 路由配置类
 * 配置Actor的路由策略（可选）
 */
public class RoutingConfig {
    public let routerType: RouterType
    public let routeeCount: Int32
    public let name: String
    
    public init(routerType: RouterType, routeeCount: Int32, name: String) {
        this.routerType = routerType
        this.routeeCount = routeeCount
        this.name = name
    }
}

/**
 * 路由器类型枚举
 */
public enum RouterType {
    | RoundRobin      // 轮询路由
    | Random          // 随机路由
    | ConsistentHashing  // 一致性哈希路由
    | Broadcast       // 广播路由
    | Custom          // 自定义路由
}

// 前向声明，避免循环依赖
public interface MessageDispatcher {
    // 前向声明，具体实现在其他文件中
}

public interface Router {
    // 前向声明，具体实现在其他文件中
}

public interface Mailbox {
    // 前向声明，具体实现在runtime.mailbox中
}
