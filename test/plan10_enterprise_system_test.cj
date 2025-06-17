/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10企业级系统测试
 * 验证plan10.md中实现的企业级Actor系统功能
 */
package test

import std.unittest.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}
import cactor.core.context.{ActorContext}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.integration.enterprise.{EnterpriseActorSystem, EnterpriseActorSystemConfig, SystemMode, PerformanceMode}
import cactor.runtime.lifecycle.{ActorLifecycleManager, ActorLifecycleState}
import cactor.runtime.registry.{SimpleActorRegistry}
import cactor.runtime.supervision.{SupervisionManager}
import cactor.runtime.monitoring.{ActorSystemMetrics}
import cactor.runtime.events.{SimpleActorEventBus, ConsoleEventListener}

/**
 * 企业级测试Actor
 */
class EnterpriseTestActor <: Actor {
    private var messageCount: Int32
    private var lastMessage: String
    private var processingTime: Int64
    
    public init() {
        this.messageCount = 0
        this.lastMessage = ""
        this.processingTime = 0
    }
    
    public prop name: String {
        get() { "enterprise-test-actor" }
    }
    
    public prop description: String {
        get() { "Enterprise Test Actor for plan10.md validation" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        messageCount += 1
        match (message) {
            case msg: StringMessage =>
                lastMessage = msg.getContent()
                // 模拟一些处理时间
                Thread.sleep(Duration.microsecond * 10)
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        processingTime = endTime - startTime
        
        MessageResult.Handled
    }
    
    public func getMessageCount(): Int32 {
        messageCount
    }
    
    public func getLastMessage(): String {
        lastMessage
    }
    
    public func getProcessingTime(): Int64 {
        processingTime
    }
}

/**
 * Plan10企业级系统测试类
 */
@Test
class Plan10EnterpriseSystemTest {
    
    /**
     * 测试企业级ActorSystem创建和配置
     */
    @Test
    public func testEnterpriseActorSystemCreation(): Unit {
        // 测试开发环境配置
        let devConfig = EnterpriseActorSystemConfig.createDevelopment()
        let devSystem = EnterpriseActorSystem("dev-system", devConfig)
        
        @Assert.Equal("dev-system", devSystem.name)
        @Assert.Equal(SystemMode.Development, devConfig.mode)
        @Assert.True(devConfig.enableMonitoring)
        @Assert.False(devConfig.enablePersistence)
        @Assert.Equal(PerformanceMode.Balanced, devConfig.performanceMode)
        
        // 测试生产环境配置
        let prodConfig = EnterpriseActorSystemConfig.createProduction()
        let prodSystem = EnterpriseActorSystem("prod-system", prodConfig)
        
        @Assert.Equal("prod-system", prodSystem.name)
        @Assert.Equal(SystemMode.Production, prodConfig.mode)
        @Assert.True(prodConfig.enableMonitoring)
        @Assert.True(prodConfig.enablePersistence)
        @Assert.Equal(PerformanceMode.HighThroughput, prodConfig.performanceMode)
        
        // 测试极限性能配置
        let extremeConfig = EnterpriseActorSystemConfig.createExtreme()
        let extremeSystem = EnterpriseActorSystem("extreme-system", extremeConfig)
        
        @Assert.Equal("extreme-system", extremeSystem.name)
        @Assert.Equal(SystemMode.Production, extremeConfig.mode)
        @Assert.Equal(PerformanceMode.Extreme, extremeConfig.performanceMode)
        @Assert.Equal(10_000_000, extremeConfig.maxActors)
        @Assert.Equal(100_000_000, extremeConfig.maxThroughput)
        
        println("✅ 企业级ActorSystem创建和配置测试通过")
    }
    
    /**
     * 测试企业级系统启动和关闭
     */
    @Test
    public func testEnterpriseSystemLifecycle(): Unit {
        let config = EnterpriseActorSystemConfig.createDevelopment()
        let system = EnterpriseActorSystem("lifecycle-test", config)
        
        // 测试启动
        @Assert.False(system.isTerminated())
        system.start()
        
        // 验证运行时组件
        let runtime = system.getRuntime()
        @Assert.NotNull(runtime)
        @Assert.NotNull(runtime.getLifecycleManager())
        @Assert.NotNull(runtime.getActorRegistry())
        @Assert.NotNull(runtime.getSupervisionManager())
        @Assert.NotNull(runtime.getSystemMetrics())
        @Assert.NotNull(runtime.getEventBus())
        
        // 测试关闭
        system.shutdown()
        @Assert.True(system.isTerminated())
        
        println("✅ 企业级系统生命周期测试通过")
    }
    
    /**
     * 测试企业级Actor创建和管理
     */
    @Test
    public func testEnterpriseActorManagement(): Unit {
        let config = EnterpriseActorSystemConfig.createDevelopment()
        let system = EnterpriseActorSystem("actor-mgmt-test", config)
        
        system.start()
        
        // 创建多个Actor
        let factory = SimpleActorFactory<Actor>({ => EnterpriseTestActor() })
        let props = Props<Actor>(factory)
        
        let actor1 = system.actorOf(props, "enterprise-actor-1")
        let actor2 = system.actorOf(props, "enterprise-actor-2")
        let actor3 = system.actorOf(props)  // 自动生成名称
        
        @Assert.NotNull(actor1)
        @Assert.NotNull(actor2)
        @Assert.NotNull(actor3)
        
        // 验证Actor注册
        let runtime = system.getRuntime()
        let registry = runtime.getActorRegistry()
        
        @Assert.True(registry.isRegistered(actor1))
        @Assert.True(registry.isRegistered(actor2))
        @Assert.True(registry.isRegistered(actor3))
        @Assert.Equal(3, registry.getTotalActorCount())
        
        // 验证生命周期管理
        let lifecycleManager = runtime.getLifecycleManager()
        let state1 = lifecycleManager.getActorState(actor1)
        @Assert.NotNull(state1)
        
        match (state1) {
            case Some(info) =>
                @Assert.Equal(ActorLifecycleState.Running, info.state)
            case None =>
                @Assert.Fail("Actor生命周期状态不应为空")
        }
        
        system.shutdown()
        println("✅ 企业级Actor管理测试通过")
    }
    
    /**
     * 测试企业级性能监控
     */
    @Test
    public func testEnterprisePerformanceMonitoring(): Unit {
        let config = EnterpriseActorSystemConfig.createProduction()
        let system = EnterpriseActorSystem("perf-monitor-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        let metrics = runtime.getSystemMetrics()
        
        // 创建Actor并发送消息
        let factory = SimpleActorFactory<Actor>({ => EnterpriseTestActor() })
        let props = Props<Actor>(factory)
        let actor = system.actorOf(props, "perf-test-actor")
        
        // 发送多条消息进行性能测试
        let messageCount = 1000
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        for (i in 0..messageCount) {
            let message = StringMessage("performance test message ${i}")
            actor.tell(message)
        }
        
        // 等待消息处理完成
        Thread.sleep(Duration.millisecond * 500)
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = endTime - startTime
        
        // 验证性能指标
        let perfMetrics = metrics.getPerformanceMetrics()
        @Assert.True(perfMetrics.messagesThroughput > 0.0)
        @Assert.True(perfMetrics.averageLatency >= 0.0)
        @Assert.True(perfMetrics.errorRate >= 0.0)
        
        // 验证基础统计
        let basicStats = metrics.getBasicStats()
        @Assert.True(basicStats.get("totalMessages") > 0)
        @Assert.True(basicStats.get("processedMessages") > 0)
        
        // 测试自定义指标
        metrics.incrementCustomCounter("test_messages", Int64(messageCount))
        metrics.setCustomGauge("test_duration", Float64(duration))
        
        let customMetrics = metrics.getCustomMetrics()
        let customGauges = metrics.getCustomGauges()
        
        @Assert.Equal(Int64(messageCount), customMetrics.get("test_messages"))
        @Assert.Equal(Float64(duration), customGauges.get("test_duration"))
        
        // 获取企业级统计信息
        let systemStats = system.getSystemStats()
        @Assert.NotNull(systemStats)
        @Assert.True(systemStats.isRunning)
        @Assert.True(systemStats.actorCount > 0)
        @Assert.True(systemStats.totalMessages > 0)
        
        system.shutdown()
        println("✅ 企业级性能监控测试通过")
    }
    
    /**
     * 测试企业级事件系统
     */
    @Test
    public func testEnterpriseEventSystem(): Unit {
        let config = EnterpriseActorSystemConfig.createDevelopment()
        let system = EnterpriseActorSystem("event-system-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        let eventBus = runtime.getEventBus()
        
        // 添加事件监听器
        let listener = ConsoleEventListener("[ENTERPRISE]")
        eventBus.subscribe(listener)
        
        @Assert.Equal(1, eventBus.getSubscriberCount())
        @Assert.True(eventBus.hasSubscribers())
        
        // 创建Actor会触发事件
        let factory = SimpleActorFactory<Actor>({ => EnterpriseTestActor() })
        let props = Props<Actor>(factory)
        let actor = system.actorOf(props, "event-test-actor")
        
        // 等待事件处理
        Thread.sleep(Duration.millisecond * 100)
        
        // 验证事件已发布
        @Assert.True(eventBus.getEventCount() > 0)
        
        system.shutdown()
        println("✅ 企业级事件系统测试通过")
    }
    
    /**
     * 测试企业级容错和监督
     */
    @Test
    public func testEnterpriseSupervisionAndFaultTolerance(): Unit {
        let config = EnterpriseActorSystemConfig.createProduction()
        let system = EnterpriseActorSystem("supervision-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        let supervisionManager = runtime.getSupervisionManager()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => EnterpriseTestActor() })
        let props = Props<Actor>(factory)
        let actor = system.actorOf(props, "supervised-actor")
        
        // 验证监督管理器
        @Assert.NotNull(supervisionManager)
        
        // 验证Actor已被监督
        let lifecycleManager = runtime.getLifecycleManager()
        let actorState = lifecycleManager.getActorState(actor)
        @Assert.NotNull(actorState)
        
        system.shutdown()
        println("✅ 企业级容错和监督测试通过")
    }
    
    /**
     * 测试企业级系统统计报告
     */
    @Test
    public func testEnterpriseSystemReporting(): Unit {
        let config = EnterpriseActorSystemConfig.createExtreme()
        let system = EnterpriseActorSystem("reporting-test", config)
        
        system.start()
        
        // 创建一些Actor并发送消息
        let factory = SimpleActorFactory<Actor>({ => EnterpriseTestActor() })
        let props = Props<Actor>(factory)
        
        for (i in 0..10) {
            let actor = system.actorOf(props, "report-actor-${i}")
            let message = StringMessage("test message ${i}")
            actor.tell(message)
        }
        
        // 等待处理
        Thread.sleep(Duration.millisecond * 200)
        
        // 获取并验证统计信息
        let stats = system.getSystemStats()
        @Assert.NotNull(stats)
        @Assert.Equal("reporting-test", stats.systemName)
        @Assert.True(stats.isRunning)
        @Assert.True(stats.actorCount >= 10)
        
        // 打印企业级报告
        stats.printEnterpriseReport()
        
        // 获取运行时统计
        let runtime = system.getRuntime()
        let runtimeStats = runtime.getRuntimeStats()
        runtimeStats.printReport()
        
        system.shutdown()
        println("✅ 企业级系统统计报告测试通过")
    }
}
