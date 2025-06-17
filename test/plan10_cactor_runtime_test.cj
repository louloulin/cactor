/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10 CActorRuntime测试
 * 验证plan10.md中实现的企业级Actor系统功能
 */
package test

import std.unittest.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}
import cactor.core.context.{ActorContext}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.runtime.lifecycle.{ActorLifecycleManager, ActorLifecycleState}
import cactor.runtime.registry.{SimpleActorRegistry}
import cactor.runtime.supervision.{SupervisionManager}
import cactor.runtime.monitoring.{ActorSystemMetrics}
import cactor.runtime.events.{SimpleActorEventBus}

/**
 * 测试用的简单Actor
 */
class Plan10TestActor <: Actor {
    private var messageCount: Int32
    private var lastMessage: String
    
    public init() {
        this.messageCount = 0
        this.lastMessage = ""
    }
    
    public prop name: String {
        get() { "plan10-test-actor" }
    }
    
    public prop description: String {
        get() { "Plan10 Test Actor for enterprise features" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        messageCount += 1
        match (message) {
            case msg: StringMessage =>
                lastMessage = msg.getContent()
                println("Plan10TestActor received: ${msg.getContent()}")
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
    }
    
    public func getMessageCount(): Int32 {
        messageCount
    }
    
    public func getLastMessage(): String {
        lastMessage
    }
}

/**
 * Plan10 CActorRuntime测试类
 */
@Test
class Plan10CActorRuntimeTest {
    
    /**
     * 测试CActorRuntime的企业级组件初始化
     */
    @Test
    public func testEnterpriseComponentsInitialization(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("plan10-test-system", config)
        
        // 验证企业级组件是否正确初始化
        let lifecycleManager = runtime.getLifecycleManager()
        let actorRegistry = runtime.getActorRegistry()
        let supervisionManager = runtime.getSupervisionManager()
        let systemMetrics = runtime.getSystemMetrics()
        let eventBus = runtime.getEventBus()
        
        @Assert.NotNull(lifecycleManager)
        @Assert.NotNull(actorRegistry)
        @Assert.NotNull(supervisionManager)
        @Assert.NotNull(systemMetrics)
        @Assert.NotNull(eventBus)
        
        println("✅ 企业级组件初始化测试通过")
    }
    
    /**
     * 测试统一Actor创建流程
     */
    @Test
    public func testUnifiedActorCreation(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("unified-creation-test", config)
        
        runtime.start()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor() })
        let props = Props<Actor>(factory)
        let actorRef = runtime.actorOf(props, "test-actor-1")
        
        @Assert.NotNull(actorRef)
        @Assert.Equal("/user/test-actor-1", actorRef.path.toString())
        
        // 验证Actor已注册到注册表
        let registry = runtime.getActorRegistry()
        @Assert.True(registry.isRegistered(actorRef))
        
        // 验证Actor已注册到生命周期管理器
        let lifecycleManager = runtime.getLifecycleManager()
        let lifecycleInfo = lifecycleManager.getActorState(actorRef)
        @Assert.NotNull(lifecycleInfo)
        
        match (lifecycleInfo) {
            case Some(info) =>
                @Assert.Equal(ActorLifecycleState.Running, info.state)
            case None =>
                @Assert.Fail("Actor生命周期信息不应为空")
        }
        
        // 验证系统指标已更新
        let metrics = runtime.getSystemMetrics()
        @Assert.Equal(1, metrics.getBasicStats().get("activeActors"))
        
        runtime.shutdown()
        println("✅ 统一Actor创建流程测试通过")
    }
    
    /**
     * 测试Actor注册表功能
     */
    @Test
    public func testActorRegistry(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("registry-test", config)
        
        runtime.start()
        
        let registry = runtime.getActorRegistry()
        
        // 创建多个Actor
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor() })
        let props = Props<Actor>(factory)
        
        let actor1 = runtime.actorOf(props, "actor-1")
        let actor2 = runtime.actorOf(props, "actor-2")
        let actor3 = runtime.actorOf(props, "actor-3")
        
        // 测试路径查找
        let foundActor1 = registry.findByPath("/user/actor-1")
        @Assert.NotNull(foundActor1)
        match (foundActor1) {
            case Some(ref) =>
                @Assert.Equal(actor1.path.toString(), ref.path.toString())
            case None =>
                @Assert.Fail("应该能找到actor-1")
        }
        
        // 测试名称查找
        let foundActor2 = registry.findByName("actor-2")
        @Assert.NotNull(foundActor2)
        
        // 测试统计信息
        @Assert.Equal(3, registry.getTotalActorCount())
        @Assert.Equal(3, registry.getRegistrationCount())
        
        // 测试注销
        registry.unregister(actor3)
        @Assert.Equal(2, registry.getTotalActorCount())
        @Assert.False(registry.isRegistered(actor3))
        
        runtime.shutdown()
        println("✅ Actor注册表功能测试通过")
    }
    
    /**
     * 测试生命周期管理
     */
    @Test
    public func testLifecycleManagement(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("lifecycle-test", config)
        
        runtime.start()
        
        let lifecycleManager = runtime.getLifecycleManager()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor() })
        let props = Props<Actor>(factory)
        let actorRef = runtime.actorOf(props, "lifecycle-actor")
        
        // 验证初始状态
        let initialState = lifecycleManager.getActorState(actorRef)
        @Assert.NotNull(initialState)
        
        match (initialState) {
            case Some(info) =>
                @Assert.Equal(ActorLifecycleState.Running, info.state)
                @Assert.Equal(0, info.restartCount)
            case None =>
                @Assert.Fail("生命周期信息不应为空")
        }
        
        // 测试停止Actor
        lifecycleManager.stopActor(actorRef)
        
        // 等待状态更新
        Thread.sleep(Duration.millisecond * 50)
        
        let stoppedState = lifecycleManager.getActorState(actorRef)
        match (stoppedState) {
            case Some(info) =>
                @Assert.Equal(ActorLifecycleState.Stopped, info.state)
            case None =>
                // Actor已被清理，这是正常的
                ()
        }
        
        runtime.shutdown()
        println("✅ 生命周期管理测试通过")
    }
    
    /**
     * 测试系统指标收集
     */
    @Test
    public func testSystemMetrics(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("metrics-test", config)
        
        runtime.start()
        
        let metrics = runtime.getSystemMetrics()
        
        // 测试基础指标
        let initialStats = metrics.getBasicStats()
        @Assert.Equal(0, initialStats.get("activeActors"))
        @Assert.Equal(0, initialStats.get("totalMessages"))
        
        // 创建Actor并发送消息
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor() })
        let props = Props<Actor>(factory)
        let actorRef = runtime.actorOf(props, "metrics-actor")
        
        // 发送消息
        let message = StringMessage("test message")
        actorRef.tell(message)
        
        // 等待消息处理
        Thread.sleep(Duration.millisecond * 100)
        
        // 验证指标更新
        let updatedStats = metrics.getBasicStats()
        @Assert.Equal(1, updatedStats.get("activeActors"))
        
        // 测试自定义指标
        metrics.incrementCustomCounter("test_counter", 5)
        metrics.setCustomGauge("test_gauge", 3.14)
        
        let customMetrics = metrics.getCustomMetrics()
        let customGauges = metrics.getCustomGauges()
        
        @Assert.Equal(5, customMetrics.get("test_counter"))
        @Assert.Equal(3.14, customGauges.get("test_gauge"))
        
        // 测试性能指标
        let perfMetrics = metrics.getPerformanceMetrics()
        @Assert.NotNull(perfMetrics)
        @Assert.True(perfMetrics.messagesThroughput >= 0.0)
        
        runtime.shutdown()
        println("✅ 系统指标收集测试通过")
    }
    
    /**
     * 测试事件总线
     */
    @Test
    public func testEventBus(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("eventbus-test", config)
        
        runtime.start()
        
        let eventBus = runtime.getEventBus()
        
        // 验证初始状态
        @Assert.Equal(0, eventBus.getEventCount())
        @Assert.Equal(0, eventBus.getSubscriberCount())
        @Assert.False(eventBus.hasSubscribers())
        
        // 创建Actor会触发事件
        let factory = SimpleActorFactory<Actor>({ => Plan10TestActor() })
        let props = Props<Actor>(factory)
        let actorRef = runtime.actorOf(props, "eventbus-actor")
        
        // 等待事件处理
        Thread.sleep(Duration.millisecond * 50)
        
        // 验证事件已发布
        @Assert.True(eventBus.getEventCount() > 0)
        
        runtime.shutdown()
        println("✅ 事件总线测试通过")
    }
    
    /**
     * 测试生产级配置
     */
    @Test
    public func testProductionConfiguration(): Unit {
        let prodConfig = CActorRuntimeConfig.createProduction()
        let runtime = CActorRuntime("production-test", prodConfig)
        
        @Assert.True(prodConfig.enableMonitoring)
        @Assert.True(prodConfig.enablePersistence)
        
        runtime.start()
        
        // 验证生产级配置下的系统运行
        let stats = runtime.getRuntimeStats()
        @Assert.True(stats.isRunning)
        @Assert.Equal("production-test", stats.systemName)
        
        runtime.shutdown()
        println("✅ 生产级配置测试通过")
    }
    
    /**
     * 测试系统健康检查
     */
    @Test
    public func testSystemHealthCheck(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("health-test", config)
        
        runtime.start()
        
        let metrics = runtime.getSystemMetrics()
        let healthInfo = metrics.getSystemHealth()
        
        @Assert.NotNull(healthInfo)
        @Assert.NotNull(healthInfo.message)
        @Assert.NotNull(healthInfo.details)
        
        // 健康的系统应该有正常状态
        @Assert.True(healthInfo.details.size() > 0)
        
        runtime.shutdown()
        println("✅ 系统健康检查测试通过")
    }
}
