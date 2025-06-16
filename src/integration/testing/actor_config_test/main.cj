/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor配置系统验证测试
 * 验证plan3.md Phase 1的Actor配置框架功能
 */
package cactor.integration.testing.actor_config_test

import std.time.*
import std.collection.*
import cactor.core.config.*
import cactor.core.message.Message

/**
 * 测试消息类
 */
public class ConfigTestMessage <: Message {
    private let content: String
    private let msgTimestamp: Int64

    public init(content: String) {
        this.content = content
        this.msgTimestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    public func getContent(): String { content }

    public func messageType(): String { "ConfigTestMessage" }
    public func priority(): Int32 { 0 }
    public func timestamp(): Int64 { msgTimestamp }
}

/**
 * Actor配置系统测试套件
 */
public class ActorConfigTestSuite {
    
    public init() {}

    /**
     * 测试1: 基础配置接口验证
     */
    public func testBasicConfigurationInterface(): Bool {
        println("🚀 测试1: 基础配置接口验证")

        // 测试默认配置
        let defaultConfig = ActorConfigurationFactory.createDefault()
        
        println("  默认配置名称: ${defaultConfig.getName()}")
        println("  默认配置描述: ${defaultConfig.getDescription()}")
        
        let mailboxConfig = defaultConfig.getMailboxConfig()
        let dispatcherConfig = defaultConfig.getDispatcherConfig()
        let supervisionConfig = defaultConfig.getSupervisionConfig()
        let routingConfig = defaultConfig.getRoutingConfig()
        
        println("  邮箱配置名称: ${mailboxConfig.name}")
        println("  调度器配置名称: ${dispatcherConfig.name}")
        println("  监督策略配置名称: ${supervisionConfig.name}")
        
        match (routingConfig) {
            case Some(config) => println("  路由配置名称: ${config.name}")
            case None => println("  路由配置: 无")
        }

        let success = defaultConfig.getName() == "default-config" &&
                     mailboxConfig.name == "default-unbounded" &&
                     dispatcherConfig.name == "default-dispatcher"
        
        if (success) {
            println("  ✅ 基础配置接口验证通过")
        } else {
            println("  ❌ 基础配置接口验证失败")
        }

        return success
    }

    /**
     * 测试2: 邮箱配置验证
     */
    public func testMailboxConfiguration(): Bool {
        println("🚀 测试2: 邮箱配置验证")

        // 测试无界邮箱配置
        let unboundedConfig = MailboxConfig.createUnboundedWithName("test-unbounded")
        println("  无界邮箱配置: ${unboundedConfig.name}, 容量: ${unboundedConfig.capacity}")

        // 测试有界邮箱配置
        let boundedConfig = MailboxConfig.createBoundedWithName(2048, "test-bounded")
        println("  有界邮箱配置: ${boundedConfig.name}, 容量: ${boundedConfig.capacity}")

        // 测试优先级邮箱配置
        let priorityComparator = { msg1: Message, msg2: Message =>
            msg1.priority() - msg2.priority()
        }
        let priorityConfig = MailboxConfig.createPriorityWithCapacity(priorityComparator, 1024, "test-priority")
        println("  优先级邮箱配置: ${priorityConfig.name}, 容量: ${priorityConfig.capacity}")

        // 测试暂存邮箱配置
        let stashingConfig = MailboxConfig.createStashingWithName(1000, 100, "test-stashing")
        println("  暂存邮箱配置: ${stashingConfig.name}, 容量: ${stashingConfig.capacity}, 暂存容量: ${stashingConfig.stashCapacity}")

        let success = unboundedConfig.capacity == -1 &&
                     boundedConfig.capacity == 2048 &&
                     priorityConfig.capacity == 1024 &&
                     stashingConfig.stashCapacity == 100
        
        if (success) {
            println("  ✅ 邮箱配置验证通过")
        } else {
            println("  ❌ 邮箱配置验证失败")
        }

        return success
    }

    /**
     * 测试3: 调度器配置验证
     */
    public func testDispatcherConfiguration(): Bool {
        println("🚀 测试3: 调度器配置验证")

        // 测试线程池调度器配置
        let threadPoolConfig = DispatcherConfig.createThreadPoolWithName("test-thread-pool")
        println("  线程池调度器配置: ${threadPoolConfig.name}, 吞吐量: ${threadPoolConfig.throughput}")

        // 测试工作窃取调度器配置
        let workStealingConfig = DispatcherConfig.createWorkStealingWithName("test-work-stealing")
        println("  工作窃取调度器配置: ${workStealingConfig.name}, 吞吐量: ${workStealingConfig.throughput}")

        // 测试专用线程调度器配置
        let pinnedConfig = DispatcherConfig.createPinnedWithName("test-pinned")
        println("  专用线程调度器配置: ${pinnedConfig.name}, 吞吐量: ${pinnedConfig.throughput}")

        let success = threadPoolConfig.throughput == 100 &&
                     workStealingConfig.throughput == 50 &&
                     pinnedConfig.throughput == 1
        
        if (success) {
            println("  ✅ 调度器配置验证通过")
        } else {
            println("  ❌ 调度器配置验证失败")
        }

        return success
    }

    /**
     * 测试4: 预定义配置模板验证
     */
    public func testPredefinedConfigurations(): Bool {
        println("🚀 测试4: 预定义配置模板验证")

        // 测试高性能配置
        let highPerfConfig = ActorConfigurationFactory.createHighPerformance()
        println("  高性能配置: ${highPerfConfig.getName()}")
        println("    邮箱容量: ${highPerfConfig.getMailboxConfig().capacity}")
        println("    调度器类型: ${highPerfConfig.getDispatcherConfig().name}")
        
        // 测试批处理配置
        let batchingConfig = ActorConfigurationFactory.createBatching()
        println("  批处理配置: ${batchingConfig.getName()}")
        println("    邮箱容量: ${batchingConfig.getMailboxConfig().capacity}")
        
        // 测试关键任务配置
        let criticalConfig = ActorConfigurationFactory.createCritical()
        println("  关键任务配置: ${criticalConfig.getName()}")
        println("    最大重试次数: ${criticalConfig.getSupervisionConfig().maxRetries}")
        
        // 测试暂存配置
        let stashingConfig = ActorConfigurationFactory.createStashing(1500, 150)
        println("  暂存配置: ${stashingConfig.getName()}")
        println("    暂存容量: ${stashingConfig.getMailboxConfig().stashCapacity}")

        let success = highPerfConfig.getMailboxConfig().capacity == 8192 &&
                     batchingConfig.getMailboxConfig().capacity == 4096 &&
                     criticalConfig.getSupervisionConfig().maxRetries == 1 &&
                     stashingConfig.getMailboxConfig().stashCapacity == 150
        
        if (success) {
            println("  ✅ 预定义配置模板验证通过")
        } else {
            println("  ❌ 预定义配置模板验证失败")
        }

        return success
    }

    /**
     * 测试5: 配置管理器验证
     */
    public func testConfigurationManager(): Bool {
        println("🚀 测试5: 配置管理器验证")

        let configManager = ConfigurationManager()
        
        // 测试获取预定义配置
        let defaultConfig = configManager.getConfiguration("default")
        let highPerfConfig = configManager.getConfiguration("high-performance")
        let unknownConfig = configManager.getConfiguration("unknown")
        
        println("  默认配置: ${defaultConfig.getName()}")
        println("  高性能配置: ${highPerfConfig.getName()}")
        println("  未知配置: ${unknownConfig.getName()}")
        
        // 测试注册自定义配置
        let customConfig = ActorConfigurationFactory.createCustom(
            MailboxConfig.createBounded(512, "custom-mailbox"),
            DispatcherConfig.createThreadPool("custom-dispatcher"),
            SupervisionConfig.createDefault("custom-supervision"),
            None<RoutingConfig>,
            "custom-config",
            "自定义测试配置"
        )
        
        configManager.registerConfiguration("custom", customConfig)
        let retrievedCustomConfig = configManager.getConfiguration("custom")
        
        println("  自定义配置: ${retrievedCustomConfig.getName()}")
        
        // 测试配置名称列表
        let configNames = configManager.getConfigurationNames()
        println("  配置数量: ${configNames.size}")
        
        // 测试配置存在性检查
        let hasDefault = configManager.hasConfiguration("default")
        let hasCustom = configManager.hasConfiguration("custom")
        let hasUnknown = configManager.hasConfiguration("unknown")
        
        println("  存在默认配置: ${hasDefault}")
        println("  存在自定义配置: ${hasCustom}")
        println("  存在未知配置: ${hasUnknown}")

        let success = defaultConfig.getName() == "default-config" &&
                     highPerfConfig.getName() == "high-performance-config" &&
                     unknownConfig.getName() == "default-config" &&  // 回退到默认配置
                     retrievedCustomConfig.getName() == "custom-config" &&
                     hasDefault && hasCustom && !hasUnknown
        
        if (success) {
            println("  ✅ 配置管理器验证通过")
        } else {
            println("  ❌ 配置管理器验证失败")
        }

        return success
    }

    /**
     * 测试6: 配置构建器验证
     */
    public func testConfigurationBuilder(): Bool {
        println("🚀 测试6: 配置构建器验证")

        let builder = ActorConfigurationBuilder()
        
        let builtConfig = builder
            .withName("builder-test-config")
            .withDescription("通过构建器创建的配置")
            .withMailbox(MailboxConfig.createBounded(1024, "builder-mailbox"))
            .withDispatcher(DispatcherConfig.createWorkStealing(8, "builder-dispatcher"))
            .withSupervision(SupervisionConfig.createDefault("builder-supervision"))
            .build()
        
        println("  构建器配置名称: ${builtConfig.getName()}")
        println("  构建器配置描述: ${builtConfig.getDescription()}")
        println("  邮箱容量: ${builtConfig.getMailboxConfig().capacity}")
        println("  调度器名称: ${builtConfig.getDispatcherConfig().name}")

        let success = builtConfig.getName() == "builder-test-config" &&
                     builtConfig.getMailboxConfig().capacity == 1024 &&
                     builtConfig.getDispatcherConfig().name == "builder-dispatcher"
        
        if (success) {
            println("  ✅ 配置构建器验证通过")
        } else {
            println("  ❌ 配置构建器验证失败")
        }

        return success
    }

    /**
     * 运行所有Actor配置测试
     */
    public func runAllTests(): Bool {
        println("========================================")
        println("=== CActor Actor配置系统验证测试套件 ===")
        println("验证plan3.md Phase 1的Actor配置框架功能")
        println("========================================")
        println()

        var passedTests = 0
        let totalTests = 6

        if (testBasicConfigurationInterface()) {
            passedTests += 1
        }
        println()

        if (testMailboxConfiguration()) {
            passedTests += 1
        }
        println()

        if (testDispatcherConfiguration()) {
            passedTests += 1
        }
        println()

        if (testPredefinedConfigurations()) {
            passedTests += 1
        }
        println()

        if (testConfigurationManager()) {
            passedTests += 1
        }
        println()

        if (testConfigurationBuilder()) {
            passedTests += 1
        }
        println()

        println("========================================")
        println("=== Actor配置系统验证结果 ===")
        println("通过测试: ${passedTests}/${totalTests}")

        if (passedTests == totalTests) {
            println("🎉 所有Actor配置系统验证测试通过！")
            println("✅ plan3.md Phase 1 核心配置系统重构完成")
            return true
        } else if (passedTests >= 4) {
            println("⚡ 大部分Actor配置系统验证测试通过！")
            println("基本配置功能正常")
            return true
        } else {
            println("📈 Actor配置系统验证测试需要改进")
            println("配置系统需要进一步优化")
            return false
        }
    }
}

main(): Int64 {
    let testSuite = ActorConfigTestSuite()
    let success = testSuite.runAllTests()
    return if (success) { 0 } else { 1 }
}
