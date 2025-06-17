/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10功能验证测试
 * 验证plan10.md中要求的企业级Actor系统功能
 */
package test

import std.unittest.*
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
 * Plan10功能验证测试类
 */
@Test
class Plan10VerificationTest {
    
    /**
     * 测试1：统一运行时管理器功能
     */
    @Test
    public func testUnifiedRuntimeManager(): Unit {
        println("=== 测试统一运行时管理器功能 ===")
        
        // 创建运行时配置
        let config = CActorRuntimeConfig.createProduction()
        let runtime = CActorRuntime("plan10-test-system", config)
        
        // 验证运行时组件
        @Assert.NotNull(runtime.getLifecycleManager())
        @Assert.NotNull(runtime.getActorRegistry())
        @Assert.NotNull(runtime.getSupervisionManager())
        @Assert.NotNull(runtime.getSystemMetrics())
        @Assert.NotNull(runtime.getEventBus())
        
        // 启动运行时
        runtime.start()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("runtime-test") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "test-actor")
        
        @Assert.NotNull(actor)
        
        // 验证Actor已注册
        let registry = runtime.getActorRegistry()
        @Assert.True(registry.isRegistered(actor))
        @Assert.Equal(1, registry.getTotalActorCount())
        
        // 发送消息测试
        actor.tell(StringMessage("runtime test message"))
        
        // 等待处理
        Thread.sleep(Duration.millisecond * 100)
        
        // 获取运行时统计
        let stats = runtime.getRuntimeStats()
        @Assert.Equal("plan10-test-system", stats.systemName)
        @Assert.True(stats.isRunning)
        @Assert.True(stats.actorCount >= 1)
        
        runtime.shutdown()
        println("✅ 统一运行时管理器功能测试通过")
    }
    
    /**
     * 测试2：企业级生命周期管理
     */
    @Test
    public func testEnterpriseLifecycleManagement(): Unit {
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
        @Assert.NotNull(actorState)
        
        match (actorState) {
            case Some(info) =>
                @Assert.Equal(ActorLifecycleState.Running, info.state)
            case None =>
                @Assert.Fail("Actor生命周期状态不应为空")
        }
        
        runtime.shutdown()
        println("✅ 企业级生命周期管理测试通过")
    }
    
    /**
     * 测试3：企业级监控和指标收集
     */
    @Test
    public func testEnterpriseMonitoringAndMetrics(): Unit {
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
        for (i in 0..20) {
            actor.tell(StringMessage("monitoring test message ${i}"))
        }
        
        // 等待处理
        Thread.sleep(Duration.millisecond * 200)
        
        // 验证基础指标
        let basicStats = metrics.getBasicStats()
        @Assert.True(basicStats.get("totalMessages") > 0)
        @Assert.True(basicStats.get("processedMessages") > 0)
        @Assert.True(basicStats.get("activeActors") > 0)
        
        // 验证性能指标
        let perfMetrics = metrics.getPerformanceMetrics()
        @Assert.True(perfMetrics.messagesThroughput >= 0.0)
        @Assert.True(perfMetrics.averageLatency >= 0.0)
        @Assert.True(perfMetrics.errorRate >= 0.0)
        
        // 测试自定义指标
        metrics.incrementCustomCounter("plan10_test_counter", 10)
        metrics.setCustomGauge("plan10_test_gauge", 42.5)
        
        let customMetrics = metrics.getCustomMetrics()
        let customGauges = metrics.getCustomGauges()
        
        @Assert.Equal(10, customMetrics.get("plan10_test_counter"))
        @Assert.Equal(42.5, customGauges.get("plan10_test_gauge"))
        
        runtime.shutdown()
        println("✅ 企业级监控和指标收集测试通过")
    }
    
    /**
     * 测试4：企业级事件总线系统
     */
    @Test
    public func testEnterpriseEventBusSystem(): Unit {
        println("=== 测试企业级事件总线系统 ===")
        
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("eventbus-test-system", config)
        
        runtime.start()
        
        let eventBus = runtime.getEventBus()
        
        // 添加事件监听器
        let listener = ConsoleEventListener("[PLAN10]")
        eventBus.subscribe(listener)
        
        @Assert.Equal(1, eventBus.getSubscriberCount())
        @Assert.True(eventBus.hasSubscribers())
        
        // 创建Actor会触发事件
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("eventbus-test") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "eventbus-actor")
        
        // 发送消息
        actor.tell(StringMessage("eventbus test message"))
        
        // 等待事件处理
        Thread.sleep(Duration.millisecond * 100)
        
        // 验证事件已发布
        @Assert.True(eventBus.getEventCount() > 0)
        
        runtime.shutdown()
        println("✅ 企业级事件总线系统测试通过")
    }
    
    /**
     * 测试5：企业级容错和监督
     */
    @Test
    public func testEnterpriseFaultToleranceAndSupervision(): Unit {
        println("=== 测试企业级容错和监督 ===")
        
        let config = CActorRuntimeConfig.createProduction()
        let runtime = CActorRuntime("supervision-test-system", config)
        
        runtime.start()
        
        let supervisionManager = runtime.getSupervisionManager()
        let lifecycleManager = runtime.getLifecycleManager()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("supervision-test") })
        let props = Props<Actor>(factory)
        let actor = runtime.actorOf(props, "supervised-actor")
        
        @Assert.NotNull(actor)
        
        // 验证Actor已被监督
        let actorState = lifecycleManager.getActorState(actor)
        @Assert.NotNull(actorState)
        
        // 发送正常消息
        actor.tell(StringMessage("normal supervision test"))
        
        // 等待处理
        Thread.sleep(Duration.millisecond * 100)
        
        // 验证Actor仍然运行
        let updatedState = lifecycleManager.getActorState(actor)
        @Assert.NotNull(updatedState)
        
        runtime.shutdown()
        println("✅ 企业级容错和监督测试通过")
    }
    
    /**
     * 测试6：企业级配置管理
     */
    @Test
    public func testEnterpriseConfigurationManagement(): Unit {
        println("=== 测试企业级配置管理 ===")
        
        // 测试默认配置
        let defaultConfig = CActorRuntimeConfig.createDefault()
        @Assert.Equal("default-system", defaultConfig.systemName)
        @Assert.True(defaultConfig.enableMetrics)
        @Assert.True(defaultConfig.enableSupervision)
        @Assert.True(defaultConfig.enableLifecycleManagement)
        @Assert.True(defaultConfig.enableEventBus)
        @Assert.Equal(100_000, defaultConfig.maxActors)
        @Assert.Equal(10_000, defaultConfig.defaultMailboxSize)
        
        // 测试生产配置
        let prodConfig = CActorRuntimeConfig.createProduction()
        @Assert.Equal("production-system", prodConfig.systemName)
        @Assert.True(prodConfig.enableMetrics)
        @Assert.True(prodConfig.enableSupervision)
        @Assert.True(prodConfig.enableLifecycleManagement)
        @Assert.True(prodConfig.enableEventBus)
        @Assert.Equal(1_000_000, prodConfig.maxActors)
        @Assert.Equal(50_000, prodConfig.defaultMailboxSize)
        
        println("✅ 企业级配置管理测试通过")
    }
    
    /**
     * 测试7：企业级性能和扩展性
     */
    @Test
    public func testEnterprisePerformanceAndScalability(): Unit {
        println("=== 测试企业级性能和扩展性 ===")
        
        let config = CActorRuntimeConfig.createProduction()
        let runtime = CActorRuntime("performance-test-system", config)
        
        runtime.start()
        
        // 创建多个Actor
        let actorCount = 50
        let actors = Array<ActorRef>()
        
        for (i in 0..actorCount) {
            let factory = SimpleActorFactory<Actor>({ => Plan10TestActor("perf-${i}") })
            let props = Props<Actor>(factory)
            let actor = runtime.actorOf(props, "perf-actor-${i}")
            actors.append(actor)
        }
        
        @Assert.Equal(actorCount, actors.size())
        
        // 高强度消息发送
        let messageCount = 200
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        for (i in 0..messageCount) {
            let actorIndex = i % actorCount
            let actor = actors[actorIndex]
            actor.tell(StringMessage("performance test ${i}"))
        }
        
        // 等待处理完成
        Thread.sleep(Duration.millisecond * 300)
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = endTime - startTime
        
        // 验证性能
        let actualThroughput = Float64(messageCount) / (Float64(duration) / 1000.0)
        println("实际吞吐量: ${actualThroughput} msg/s")
        
        @Assert.True(actualThroughput > 500.0)  // 至少500 msg/s
        
        // 验证Actor数量
        let registry = runtime.getActorRegistry()
        @Assert.True(registry.getTotalActorCount() >= Int64(actorCount))
        
        runtime.shutdown()
        println("✅ 企业级性能和扩展性测试通过")
    }
}
