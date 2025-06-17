/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10简化功能验证
 * 验证plan10.md中要求的企业级Actor系统功能
 */
package cactor.integration.testing.plan10_simple_verification

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
 * Plan10测试Actor
 */
class Plan10TestActor <: Actor {
    private var messageCount: AtomicInt32
    private var lastMessage: String
    private let actorId: String
    
    public init(actorId: String) {
        this.actorId = actorId
        this.messageCount = AtomicInt32(0)
        this.lastMessage = ""
    }
    
    public prop name: String {
        get() { "plan10-test-actor-${actorId}" }
    }
    
    public prop description: String {
        get() { "Plan10 Test Actor for enterprise features validation" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        messageCount.fetchAdd(1)
        match (message) {
            case msg: StringMessage =>
                lastMessage = msg.getContent()
                println("Plan10TestActor[${actorId}] received: ${msg.getContent()}")
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
    }
    
    public func getMessageCount(): Int32 {
        messageCount.load()
    }
    
    public func getLastMessage(): String {
        lastMessage
    }
}

/**
 * 测试统一运行时管理器功能
 */
func testUnifiedRuntimeManager(): Bool {
    println("=== 测试统一运行时管理器功能 ===")
    
    // 创建运行时配置
    let config = CActorRuntimeConfig.createProduction()
    let runtime = CActorRuntime("plan10-test-system", config)
    
    // 验证运行时组件
    let lifecycleManager = runtime.getLifecycleManager()
    let actorRegistry = runtime.getActorRegistry()
    let supervisionManager = runtime.getSupervisionManager()
    let systemMetrics = runtime.getSystemMetrics()
    let eventBus = runtime.getEventBus()
    
    if (lifecycleManager == null || actorRegistry == null || 
        supervisionManager == null || systemMetrics == null || eventBus == null) {
        println("❌ 运行时组件初始化失败")
        return false
    }
    
    // 启动运行时
    runtime.start()
    
    // 创建Actor
    let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("runtime-test") })
    let props = Props<Actor>(factory)
    let actor = runtime.actorOf(props, "test-actor")
    
    if (actor == null) {
        println("❌ Actor创建失败")
        runtime.shutdown()
        return false
    }
    
    // 验证Actor已注册
    if (!actorRegistry.isRegistered(actor)) {
        println("❌ Actor注册失败")
        runtime.shutdown()
        return false
    }
    
    if (actorRegistry.getTotalActorCount() != 1) {
        println("❌ Actor计数错误")
        runtime.shutdown()
        return false
    }
    
    // 发送消息测试
    actor.tell(StringMessage("runtime test message"))
    
    // 等待处理
    Thread.sleep(Duration.millisecond * 100)
    
    // 获取运行时统计
    let stats = runtime.getRuntimeStats()
    if (stats.systemName != "plan10-test-system") {
        println("❌ 系统名称错误")
        runtime.shutdown()
        return false
    }
    
    if (!stats.isRunning) {
        println("❌ 系统状态错误")
        runtime.shutdown()
        return false
    }
    
    if (stats.actorCount < 1) {
        println("❌ Actor数量错误")
        runtime.shutdown()
        return false
    }
    
    runtime.shutdown()
    println("✅ 统一运行时管理器功能测试通过")
    return true
}

/**
 * 测试企业级生命周期管理
 */
func testEnterpriseLifecycleManagement(): Bool {
    println("=== 测试企业级生命周期管理 ===")
    
    let config = CActorRuntimeConfig.createDefault()
    let runtime = CActorRuntime("lifecycle-test-system", config)
    
    runtime.start()
    
    let lifecycleManager = runtime.getLifecycleManager()
    
    // 创建Actor
    let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("lifecycle-test") })
    let props = Props<Actor>(factory)
    let actor = runtime.actorOf(props, "lifecycle-actor")
    
    // 验证生命周期状态
    let actorState = lifecycleManager.getActorState(actor)
    
    match (actorState) {
        case Some(info) =>
            if (info.state != ActorLifecycleState.Running) {
                println("❌ Actor生命周期状态错误")
                runtime.shutdown()
                return false
            }
        case None =>
            println("❌ Actor生命周期状态不应为空")
            runtime.shutdown()
            return false
    }
    
    runtime.shutdown()
    println("✅ 企业级生命周期管理测试通过")
    return true
}

/**
 * 测试企业级监控和指标收集
 */
func testEnterpriseMonitoringAndMetrics(): Bool {
    println("=== 测试企业级监控和指标收集 ===")
    
    let config = CActorRuntimeConfig.createProduction()
    let runtime = CActorRuntime("monitoring-test-system", config)
    
    runtime.start()
    
    let metrics = runtime.getSystemMetrics()
    
    // 创建Actor并发送消息
    let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("monitoring-test") })
    let props = Props<Actor>(factory)
    let actor = runtime.actorOf(props, "monitoring-actor")
    
    // 发送多条消息
    for (i in 0..10) {
        actor.tell(StringMessage("monitoring test message ${i}"))
    }
    
    // 等待处理
    Thread.sleep(Duration.millisecond * 200)
    
    // 验证基础指标
    let basicStats = metrics.getBasicStats()
    if (basicStats.get("totalMessages") <= 0) {
        println("❌ 总消息数指标错误")
        runtime.shutdown()
        return false
    }
    
    if (basicStats.get("processedMessages") <= 0) {
        println("❌ 处理消息数指标错误")
        runtime.shutdown()
        return false
    }
    
    if (basicStats.get("activeActors") <= 0) {
        println("❌ 活跃Actor数指标错误")
        runtime.shutdown()
        return false
    }
    
    // 验证性能指标
    let perfMetrics = metrics.getPerformanceMetrics()
    if (perfMetrics.messagesThroughput < 0.0) {
        println("❌ 消息吞吐量指标错误")
        runtime.shutdown()
        return false
    }
    
    if (perfMetrics.averageLatency < 0.0) {
        println("❌ 平均延迟指标错误")
        runtime.shutdown()
        return false
    }
    
    if (perfMetrics.errorRate < 0.0) {
        println("❌ 错误率指标错误")
        runtime.shutdown()
        return false
    }
    
    // 测试自定义指标
    metrics.incrementCustomCounter("plan10_test_counter", 5)
    metrics.setCustomGauge("plan10_test_gauge", 42.5)
    
    let customMetrics = metrics.getCustomMetrics()
    let customGauges = metrics.getCustomGauges()
    
    if (customMetrics.get("plan10_test_counter") != 5) {
        println("❌ 自定义计数器指标错误")
        runtime.shutdown()
        return false
    }
    
    if (customGauges.get("plan10_test_gauge") != 42.5) {
        println("❌ 自定义仪表指标错误")
        runtime.shutdown()
        return false
    }
    
    runtime.shutdown()
    println("✅ 企业级监控和指标收集测试通过")
    return true
}

/**
 * 测试企业级事件总线系统
 */
func testEnterpriseEventBusSystem(): Bool {
    println("=== 测试企业级事件总线系统 ===")
    
    let config = CActorRuntimeConfig.createDefault()
    let runtime = CActorRuntime("eventbus-test-system", config)
    
    runtime.start()
    
    let eventBus = runtime.getEventBus()
    
    // 添加事件监听器
    let listener = ConsoleEventListener("[PLAN10]")
    eventBus.subscribe(listener)
    
    if (eventBus.getSubscriberCount() != 1) {
        println("❌ 事件监听器订阅失败")
        runtime.shutdown()
        return false
    }
    
    if (!eventBus.hasSubscribers()) {
        println("❌ 事件总线订阅者检查失败")
        runtime.shutdown()
        return false
    }
    
    // 创建Actor会触发事件
    let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("eventbus-test") })
    let props = Props<Actor>(factory)
    let actor = runtime.actorOf(props, "eventbus-actor")
    
    // 发送消息
    actor.tell(StringMessage("eventbus test message"))
    
    // 等待事件处理
    Thread.sleep(Duration.millisecond * 100)
    
    // 验证事件已发布
    if (eventBus.getEventCount() <= 0) {
        println("❌ 事件发布失败")
        runtime.shutdown()
        return false
    }
    
    runtime.shutdown()
    println("✅ 企业级事件总线系统测试通过")
    return true
}

/**
 * 测试企业级配置管理
 */
func testEnterpriseConfigurationManagement(): Bool {
    println("=== 测试企业级配置管理 ===")
    
    // 测试默认配置
    let defaultConfig = CActorRuntimeConfig.createDefault()
    if (defaultConfig.systemName != "default-system") {
        println("❌ 默认配置系统名称错误")
        return false
    }
    
    if (!defaultConfig.enableMetrics) {
        println("❌ 默认配置指标启用错误")
        return false
    }
    
    if (!defaultConfig.enableSupervision) {
        println("❌ 默认配置监督启用错误")
        return false
    }
    
    if (!defaultConfig.enableLifecycleManagement) {
        println("❌ 默认配置生命周期管理启用错误")
        return false
    }
    
    if (!defaultConfig.enableEventBus) {
        println("❌ 默认配置事件总线启用错误")
        return false
    }
    
    if (defaultConfig.maxActors != 100_000) {
        println("❌ 默认配置最大Actor数错误")
        return false
    }
    
    if (defaultConfig.defaultMailboxSize != 10_000) {
        println("❌ 默认配置邮箱大小错误")
        return false
    }
    
    // 测试生产配置
    let prodConfig = CActorRuntimeConfig.createProduction()
    if (prodConfig.systemName != "production-system") {
        println("❌ 生产配置系统名称错误")
        return false
    }
    
    if (prodConfig.maxActors != 1_000_000) {
        println("❌ 生产配置最大Actor数错误")
        return false
    }
    
    if (prodConfig.defaultMailboxSize != 50_000) {
        println("❌ 生产配置邮箱大小错误")
        return false
    }
    
    println("✅ 企业级配置管理测试通过")
    return true
}

/**
 * 主测试函数
 */
main(): Int64 {
    println("========================================")
    println("Plan10 CActor企业级功能验证测试")
    println("========================================")
    
    var passedTests = 0
    var totalTests = 0
    
    // 运行所有测试
    totalTests += 1
    if (testUnifiedRuntimeManager()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testEnterpriseLifecycleManagement()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testEnterpriseMonitoringAndMetrics()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testEnterpriseEventBusSystem()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testEnterpriseConfigurationManagement()) {
        passedTests += 1
    }
    
    println("========================================")
    println("测试结果: ${passedTests}/${totalTests} 通过")
    
    if (passedTests == totalTests) {
        println("🎉 所有Plan10企业级功能测试通过！")
        println("✅ Plan10.md中的企业级Actor系统功能已成功实现")
        return 0
    } else {
        println("❌ 部分测试失败")
        return 1
    }
}
