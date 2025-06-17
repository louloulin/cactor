/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10快速功能验证
 * 验证plan10.md中要求的企业级Actor系统核心功能
 */
package cactor.integration.testing.plan10_quick_verification

import std.time.*
import std.sync.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}
import cactor.core.context.{ActorContext}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.runtime.lifecycle.{ActorLifecycleManager, ActorLifecycleState}
import cactor.runtime.registry.{SimpleActorRegistry}
import cactor.runtime.supervision.{SupervisionManager}
import cactor.runtime.monitoring.{ActorSystemMetrics}
import cactor.runtime.events.{SimpleActorEventBus, ConsoleEventListener}

/**
 * 简单测试Actor
 */
class QuickTestActor <: Actor {
    private var messageCount: AtomicInt32
    private let actorId: String
    
    public init(actorId: String) {
        this.actorId = actorId
        this.messageCount = AtomicInt32(0)
    }
    
    public prop name: String {
        get() { "quick-test-actor-${actorId}" }
    }
    
    public prop description: String {
        get() { "Quick Test Actor for Plan10 verification" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        messageCount.fetchAdd(1)
        match (message) {
            case msg: StringMessage =>
                println("QuickTestActor[${actorId}] received: ${msg.getContent()}")
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
    }
    
    public func getMessageCount(): Int32 {
        messageCount.load()
    }
}

/**
 * 验证CActorRuntime统一运行时管理器
 */
func verifyUnifiedRuntimeManager(): Bool {
    println("🔍 验证CActorRuntime统一运行时管理器...")
    
    try {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("plan10-quick-test", config)
        
        // 验证核心组件
        let lifecycleManager = runtime.getLifecycleManager()
        let actorRegistry = runtime.getActorRegistry()
        let supervisionManager = runtime.getSupervisionManager()
        let systemMetrics = runtime.getSystemMetrics()
        let eventBus = runtime.getEventBus()
        
        if (lifecycleManager == null || actorRegistry == null || 
            supervisionManager == null || systemMetrics == null || eventBus == null) {
            println("❌ 核心组件初始化失败")
            return false
        }
        
        // 启动运行时
        runtime.start()
        
        // 创建测试Actor
        let factory = SimpleActorFactory<Actor>({ => QuickTestActor("test1") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "test-actor")
        
        if (actor == null) {
            println("❌ Actor创建失败")
            runtime.shutdown()
            return false
        }
        
        // 发送测试消息
        actor.tell(StringMessage("test message"))
        Thread.sleep(Duration.millisecond * 50)
        
        // 验证Actor注册
        if (!actorRegistry.isRegistered(actor)) {
            println("❌ Actor注册失败")
            runtime.shutdown()
            return false
        }
        
        runtime.shutdown()
        println("✅ CActorRuntime统一运行时管理器验证通过")
        return true
        
    } catch (e: Exception) {
        println("❌ CActorRuntime验证失败: ${e.message}")
        return false
    }
}

/**
 * 验证企业级生命周期管理
 */
func verifyEnterpriseLifecycleManagement(): Bool {
    println("🔍 验证企业级生命周期管理...")
    
    try {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("lifecycle-test", config)
        runtime.start()
        
        let lifecycleManager = runtime.getLifecycleManager()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => QuickTestActor("lifecycle") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "lifecycle-actor")
        
        // 验证生命周期状态
        let actorState = lifecycleManager.getActorState(actor)
        
        match (actorState) {
            case Some(info) =>
                if (info.state != ActorLifecycleState.Running) {
                    println("❌ Actor生命周期状态错误: ${info.state}")
                    runtime.shutdown()
                    return false
                }
            case None =>
                println("❌ Actor生命周期状态为空")
                runtime.shutdown()
                return false
        }
        
        runtime.shutdown()
        println("✅ 企业级生命周期管理验证通过")
        return true
        
    } catch (e: Exception) {
        println("❌ 生命周期管理验证失败: ${e.message}")
        return false
    }
}

/**
 * 验证企业级监控和指标收集
 */
func verifyEnterpriseMonitoringAndMetrics(): Bool {
    println("🔍 验证企业级监控和指标收集...")
    
    try {
        let config = CActorRuntimeConfig.createProduction()
        let runtime = CActorRuntime("monitoring-test", config)
        runtime.start()
        
        let metrics = runtime.getSystemMetrics()
        
        // 创建Actor并发送消息
        let factory = SimpleActorFactory<Actor>({ => QuickTestActor("monitoring") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "monitoring-actor")
        
        // 发送消息
        for (i in 0..5) {
            actor.tell(StringMessage("monitoring test ${i}"))
        }
        
        Thread.sleep(Duration.millisecond * 100)
        
        // 验证基础指标
        let basicStats = metrics.getBasicStats()
        if (basicStats.get("totalMessages") <= 0) {
            println("❌ 总消息数指标错误")
            runtime.shutdown()
            return false
        }
        
        if (basicStats.get("activeActors") <= 0) {
            println("❌ 活跃Actor数指标错误")
            runtime.shutdown()
            return false
        }
        
        // 测试自定义指标
        metrics.incrementCustomCounter("test_counter", 3)
        metrics.setCustomGauge("test_gauge", 42.0)
        
        let customMetrics = metrics.getCustomMetrics()
        let customGauges = metrics.getCustomGauges()
        
        if (customMetrics.get("test_counter") != 3) {
            println("❌ 自定义计数器指标错误")
            runtime.shutdown()
            return false
        }
        
        if (customGauges.get("test_gauge") != 42.0) {
            println("❌ 自定义仪表指标错误")
            runtime.shutdown()
            return false
        }
        
        runtime.shutdown()
        println("✅ 企业级监控和指标收集验证通过")
        return true
        
    } catch (e: Exception) {
        println("❌ 监控和指标验证失败: ${e.message}")
        return false
    }
}

/**
 * 验证企业级事件总线系统
 */
func verifyEnterpriseEventBusSystem(): Bool {
    println("🔍 验证企业级事件总线系统...")
    
    try {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("eventbus-test", config)
        runtime.start()
        
        let eventBus = runtime.getEventBus()
        
        // 添加事件监听器
        let listener = ConsoleEventListener("[QUICK-TEST]")
        eventBus.subscribe(listener)
        
        if (eventBus.getSubscriberCount() != 1) {
            println("❌ 事件监听器订阅失败")
            runtime.shutdown()
            return false
        }
        
        // 创建Actor会触发事件
        let factory = SimpleActorFactory<Actor>({ => QuickTestActor("eventbus") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "eventbus-actor")
        
        actor.tell(StringMessage("eventbus test"))
        Thread.sleep(Duration.millisecond * 50)
        
        // 验证事件已发布
        if (eventBus.getEventCount() <= 0) {
            println("❌ 事件发布失败")
            runtime.shutdown()
            return false
        }
        
        runtime.shutdown()
        println("✅ 企业级事件总线系统验证通过")
        return true
        
    } catch (e: Exception) {
        println("❌ 事件总线验证失败: ${e.message}")
        return false
    }
}

/**
 * 验证企业级配置管理
 */
func verifyEnterpriseConfigurationManagement(): Bool {
    println("🔍 验证企业级配置管理...")
    
    try {
        // 测试默认配置
        let defaultConfig = CActorRuntimeConfig.createDefault()
        if (defaultConfig.systemName != "default-system") {
            println("❌ 默认配置系统名称错误")
            return false
        }
        
        if (!defaultConfig.enableMetrics || !defaultConfig.enableSupervision || 
            !defaultConfig.enableLifecycleManagement || !defaultConfig.enableEventBus) {
            println("❌ 默认配置功能启用错误")
            return false
        }
        
        // 测试生产配置
        let prodConfig = CActorRuntimeConfig.createProduction()
        if (prodConfig.systemName != "production-system") {
            println("❌ 生产配置系统名称错误")
            return false
        }
        
        if (prodConfig.maxActors != 1_000_000 || prodConfig.defaultMailboxSize != 50_000) {
            println("❌ 生产配置参数错误")
            return false
        }
        
        println("✅ 企业级配置管理验证通过")
        return true
        
    } catch (e: Exception) {
        println("❌ 配置管理验证失败: ${e.message}")
        return false
    }
}

/**
 * 主验证函数
 */
main(): Int64 {
    println("========================================")
    println("🚀 Plan10 CActor企业级功能快速验证")
    println("========================================")
    
    var passedTests = 0
    var totalTests = 0
    
    // 运行验证测试
    totalTests += 1
    if (verifyUnifiedRuntimeManager()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (verifyEnterpriseLifecycleManagement()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (verifyEnterpriseMonitoringAndMetrics()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (verifyEnterpriseEventBusSystem()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (verifyEnterpriseConfigurationManagement()) {
        passedTests += 1
    }
    
    println("========================================")
    println("📊 验证结果: ${passedTests}/${totalTests} 通过")
    
    if (passedTests == totalTests) {
        println("🎉 所有Plan10企业级功能验证通过！")
        println("✅ Plan10.md中的企业级Actor系统功能已成功实现")
        println("✅ CActorRuntime统一运行时管理器正常工作")
        println("✅ 企业级生命周期管理正常工作")
        println("✅ 企业级监控和指标收集正常工作")
        println("✅ 企业级事件总线系统正常工作")
        println("✅ 企业级配置管理正常工作")
        return 0
    } else {
        println("❌ 部分验证失败，需要进一步检查")
        return 1
    }
}
