/*
 * Copyright (c) 2024. All rights reserved.
 * CActorRuntime测试
 * 验证统一运行时管理器的功能
 */
package test

import std.unittest.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}
import cactor.core.context.{ActorContext}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.runtime.system.{HighPerformanceActorSystemConfig}

/**
 * 测试用的简单Actor
 */
class TestActor <: Actor {
    private var messageCount: Int32
    
    public init() {
        this.messageCount = 0
    }
    
    public prop name: String {
        get() { "test-actor" }
    }
    
    public prop description: String {
        get() { "Test Actor for CActorRuntime" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        messageCount += 1
        match (message) {
            case msg: StringMessage =>
                println("TestActor received: ${msg.getContent()}")
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
    }
    
    public func getMessageCount(): Int32 {
        messageCount
    }
}

/**
 * CActorRuntime测试类
 */
@Test
class CActorRuntimeTest {
    
    /**
     * 测试CActorRuntime的基本功能
     */
    @Test
    public func testCActorRuntimeBasics(): Unit {
        // 创建默认配置
        let config = CActorRuntimeConfig.createDefault()
        @Assert.NotNull(config)
        @Assert.True(config.enableMonitoring)
        @Assert.False(config.enablePersistence)
        
        // 创建Runtime
        let runtime = CActorRuntime("test-system", config)
        @Assert.NotNull(runtime)
        
        println("✅ CActorRuntime基础功能测试通过")
    }
    
    /**
     * 测试Runtime启动和停止
     */
    @Test
    public func testRuntimeLifecycle(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("lifecycle-test", config)
        
        // 启动Runtime
        runtime.start()
        let stats = runtime.getRuntimeStats()
        @Assert.True(stats.isRunning)
        @Assert.Equal("lifecycle-test", stats.systemName)
        
        // 停止Runtime
        runtime.shutdown()
        let finalStats = runtime.getRuntimeStats()
        @Assert.False(finalStats.isRunning)
        
        println("✅ Runtime生命周期测试通过")
    }
    
    /**
     * 测试Actor创建
     */
    @Test
    public func testActorCreation(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("actor-creation-test", config)
        
        runtime.start()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => TestActor() })
        let props = Props<Actor>(factory)
        let actorRef = runtime.actorOf(props, "test-actor-1")
        
        @Assert.NotNull(actorRef)
        @Assert.Equal("/user/test-actor-1", actorRef.path.toString())
        
        // 检查统计信息
        let stats = runtime.getRuntimeStats()
        @Assert.Equal(1, stats.actorCount)
        
        runtime.shutdown()
        println("✅ Actor创建测试通过")
    }
    
    /**
     * 测试Actor消息发送
     */
    @Test
    public func testActorMessaging(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("messaging-test", config)
        
        runtime.start()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => TestActor() })
        let props = Props<Actor>(factory)
        let actorRef = runtime.actorOf(props, "test-actor-2")
        
        // 发送消息
        let message = StringMessage("Hello from CActorRuntime!")
        actorRef.tell(message)
        
        // 等待消息处理
        Thread.sleep(Duration.millisecond * 100)
        
        runtime.shutdown()
        println("✅ Actor消息发送测试通过")
    }
    
    /**
     * 测试Guardian系统
     */
    @Test
    public func testGuardianSystem(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("guardian-test", config)
        
        runtime.start()
        
        // 获取Guardian
        let systemGuardian = runtime.getSystemGuardian()
        let userGuardian = runtime.getUserGuardian()
        
        @Assert.NotNull(systemGuardian)
        @Assert.NotNull(userGuardian)
        
        // 检查Guardian统计
        let systemStats = systemGuardian.getStats()
        let userStats = userGuardian.getStats()
        
        @Assert.NotNull(systemStats)
        @Assert.NotNull(userStats)
        
        runtime.shutdown()
        println("✅ Guardian系统测试通过")
    }
    
    /**
     * 测试高性能系统集成
     */
    @Test
    public func testHighPerformanceIntegration(): Unit {
        let config = CActorRuntimeConfig.createProduction()
        let runtime = CActorRuntime("high-perf-test", config)
        
        runtime.start()
        
        // 获取高性能系统
        let highPerfSystem = runtime.getHighPerformanceSystem()
        @Assert.NotNull(highPerfSystem)
        
        let systemStats = highPerfSystem.getSystemStats()
        @Assert.True(systemStats.isRunning)
        
        runtime.shutdown()
        println("✅ 高性能系统集成测试通过")
    }
    
    /**
     * 测试配置系统
     */
    @Test
    public func testConfigurationSystem(): Unit {
        // 测试默认配置
        let defaultConfig = CActorRuntimeConfig.createDefault()
        @Assert.True(defaultConfig.enableMonitoring)
        @Assert.False(defaultConfig.enablePersistence)
        
        // 测试生产级配置
        let prodConfig = CActorRuntimeConfig.createProduction()
        @Assert.True(prodConfig.enableMonitoring)
        @Assert.True(prodConfig.enablePersistence)
        
        // 测试配置描述
        let description = defaultConfig.getDescription()
        @Assert.NotNull(description)
        @Assert.True(description.contains("monitoring"))
        
        println("✅ 配置系统测试通过")
    }
    
    /**
     * 测试工厂组件
     */
    @Test
    public func testFactoryComponents(): Unit {
        let config = CActorRuntimeConfig.createDefault()
        let runtime = CActorRuntime("factory-test", config)
        
        runtime.start()
        
        // 测试邮箱工厂
        let mailboxFactory = runtime.getMailboxFactory()
        @Assert.NotNull(mailboxFactory)
        
        // 测试调度器工厂
        let dispatcherFactory = runtime.getDispatcherFactory()
        @Assert.NotNull(dispatcherFactory)
        
        // 测试Actor系统
        let actorSystem = runtime.getActorSystem()
        @Assert.NotNull(actorSystem)
        @Assert.Equal("factory-test", actorSystem.name)
        
        runtime.shutdown()
        println("✅ 工厂组件测试通过")
    }
}
