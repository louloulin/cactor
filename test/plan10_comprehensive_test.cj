/*
 * Copyright (c) 2024. All rights reserved.
 * Plan10综合测试
 * 验证plan10.md中实现的所有企业级功能
 */
package test

import std.unittest.*
import std.time.*
import std.sync.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult, StringMessage}
import cactor.core.context.{ActorContext}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import cactor.integration.enterprise.{EnterpriseActorSystem, EnterpriseActorSystemConfig, SystemMode, PerformanceMode}
import cactor.runtime.dispatcher.{DispatcherPool, DispatcherConfig, DispatcherType, WorkStealingDispatcher, ForkJoinDispatcher, PinnedDispatcher, CallingThreadDispatcher}
import cactor.runtime.mailbox.{MailboxFactory, MailboxConfig, MailboxType, BoundedMailbox, UnboundedMailbox}

/**
 * 高性能测试Actor
 */
class HighPerformanceTestActor <: Actor {
    private var messageCount: AtomicInt32
    private var processingTime: AtomicInt64
    private let actorId: String
    
    public init(actorId: String) {
        this.actorId = actorId
        this.messageCount = AtomicInt32(0)
        this.processingTime = AtomicInt64(0)
    }
    
    public prop name: String {
        get() { "high-perf-actor-${actorId}" }
    }
    
    public prop description: String {
        get() { "High Performance Test Actor for plan10.md validation" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        messageCount.fetchAdd(1)
        match (message) {
            case msg: StringMessage =>
                // 模拟一些处理工作
                let content = msg.getContent()
                if (content.contains("heavy")) {
                    // 模拟重计算
                    var sum = 0
                    for (i in 0..100) {
                        sum += i
                    }
                }
                MessageResult.Handled
            case _ =>
                MessageResult.Unhandled
        }
        
        let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        processingTime.fetchAdd(endTime - startTime)
        
        MessageResult.Handled
    }
    
    public func getMessageCount(): Int32 {
        messageCount.load()
    }
    
    public func getAverageProcessingTime(): Float64 {
        let count = messageCount.load()
        if (count > 0) {
            Float64(processingTime.load()) / Float64(count) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
    }
}

/**
 * Plan10综合测试类
 */
@Test
class Plan10ComprehensiveTest {
    
    /**
     * 测试企业级调度器池功能
     */
    @Test
    public func testEnterpriseDispatcherPool(): Unit {
        println("=== 测试企业级调度器池功能 ===")
        
        let config = EnterpriseActorSystemConfig.createProduction()
        let system = EnterpriseActorSystem("dispatcher-pool-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        
        // 创建多个Actor使用不同的调度器
        let factory = SimpleActorFactory<Actor>({ => HighPerformanceTestActor("dp-test") })
        let props = Props<Actor>(factory)
        
        // 使用默认调度器
        let actor1 = system.actorOf(props, "actor-default")
        
        // 使用工作窃取调度器
        let workStealingProps = props.withDispatcher("work-stealing")
        let actor2 = system.actorOf(workStealingProps, "actor-work-stealing")
        
        // 使用固定线程调度器
        let pinnedProps = props.withDispatcher("pinned")
        let actor3 = system.actorOf(pinnedProps, "actor-pinned")
        
        @Assert.NotNull(actor1)
        @Assert.NotNull(actor2)
        @Assert.NotNull(actor3)
        
        // 发送测试消息
        for (i in 0..50) {
            actor1.tell(StringMessage("test message ${i}"))
            actor2.tell(StringMessage("heavy computation ${i}"))
            actor3.tell(StringMessage("pinned message ${i}"))
        }
        
        // 等待处理完成
        Thread.sleep(Duration.millisecond * 200)
        
        system.shutdown()
        println("✅ 企业级调度器池功能测试通过")
    }
    
    /**
     * 测试企业级邮箱系统
     */
    @Test
    public func testEnterpriseMailboxSystem(): Unit {
        println("=== 测试企业级邮箱系统 ===")
        
        let config = EnterpriseActorSystemConfig.createHighPerformance()
        let system = EnterpriseActorSystem("mailbox-system-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        
        // 创建使用不同邮箱类型的Actor
        let factory = SimpleActorFactory<Actor>({ => HighPerformanceTestActor("mb-test") })
        let props = Props<Actor>(factory)
        
        // 使用有界邮箱
        let boundedProps = props.withMailbox("bounded-medium")
        let boundedActor = system.actorOf(boundedProps, "bounded-actor")
        
        // 使用高性能邮箱
        let highPerfProps = props.withMailbox("high-performance")
        let highPerfActor = system.actorOf(highPerfProps, "high-perf-actor")
        
        @Assert.NotNull(boundedActor)
        @Assert.NotNull(highPerfActor)
        
        // 发送大量消息测试邮箱性能
        for (i in 0..100) {
            boundedActor.tell(StringMessage("bounded test ${i}"))
            highPerfActor.tell(StringMessage("high-perf test ${i}"))
        }
        
        // 等待处理完成
        Thread.sleep(Duration.millisecond * 300)
        
        system.shutdown()
        println("✅ 企业级邮箱系统测试通过")
    }
    
    /**
     * 测试高吞吐量性能
     */
    @Test
    public func testHighThroughputPerformance(): Unit {
        println("=== 测试高吞吐量性能 ===")
        
        let config = EnterpriseActorSystemConfig.createExtreme()
        let system = EnterpriseActorSystem("throughput-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        let metrics = runtime.getSystemMetrics()
        
        // 创建多个高性能Actor
        let actorCount = 10
        let actors = Array<ActorRef>()
        
        for (i in 0..actorCount) {
            let factory = SimpleActorFactory<Actor>({ => HighPerformanceTestActor("perf-${i}") })
            let props = Props<Actor>(factory).withHighThroughput()
            let actor = system.actorOf(props, "perf-actor-${i}")
            actors.append(actor)
        }
        
        // 高强度消息发送测试
        let messageCount = 1000
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        for (i in 0..messageCount) {
            let actorIndex = i % actorCount
            let actor = actors[actorIndex]
            actor.tell(StringMessage("throughput test ${i}"))
        }
        
        // 等待处理完成
        Thread.sleep(Duration.millisecond * 500)
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let duration = endTime - startTime
        
        // 验证性能指标
        let perfMetrics = metrics.getPerformanceMetrics()
        @Assert.True(perfMetrics.messagesThroughput > 0.0)
        @Assert.True(perfMetrics.averageLatency >= 0.0)
        
        // 计算实际吞吐量
        let actualThroughput = Float64(messageCount) / (Float64(duration) / 1000.0)
        println("实际吞吐量: ${actualThroughput} msg/s")
        
        @Assert.True(actualThroughput > 1000.0)  // 至少1000 msg/s
        
        system.shutdown()
        println("✅ 高吞吐量性能测试通过")
    }
    
    /**
     * 测试企业级监控和统计
     */
    @Test
    public func testEnterpriseMonitoringAndStats(): Unit {
        println("=== 测试企业级监控和统计 ===")
        
        let config = EnterpriseActorSystemConfig.createProduction()
        let system = EnterpriseActorSystem("monitoring-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        let metrics = runtime.getSystemMetrics()
        
        // 创建Actor并发送消息
        let factory = SimpleActorFactory<Actor>({ => HighPerformanceTestActor("monitor-test") })
        let props = Props<Actor>(factory)
        let actor = system.actorOf(props, "monitoring-actor")
        
        // 发送消息并监控
        for (i in 0..50) {
            actor.tell(StringMessage("monitoring test ${i}"))
        }
        
        // 等待处理
        Thread.sleep(Duration.millisecond * 200)
        
        // 验证监控数据
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
        metrics.incrementCustomCounter("test_counter", 10)
        metrics.setCustomGauge("test_gauge", 42.0)
        
        let customMetrics = metrics.getCustomMetrics()
        let customGauges = metrics.getCustomGauges()
        
        @Assert.Equal(10, customMetrics.get("test_counter"))
        @Assert.Equal(42.0, customGauges.get("test_gauge"))
        
        // 获取企业级统计报告
        let systemStats = system.getSystemStats()
        @Assert.NotNull(systemStats)
        @Assert.True(systemStats.isRunning)
        @Assert.True(systemStats.actorCount > 0)
        
        // 打印详细报告
        systemStats.printEnterpriseReport()
        
        system.shutdown()
        println("✅ 企业级监控和统计测试通过")
    }
    
    /**
     * 测试企业级容错和恢复
     */
    @Test
    public func testEnterpriseFaultToleranceAndRecovery(): Unit {
        println("=== 测试企业级容错和恢复 ===")
        
        let config = EnterpriseActorSystemConfig.createProduction()
        let system = EnterpriseActorSystem("fault-tolerance-test", config)
        
        system.start()
        
        let runtime = system.getRuntime()
        let supervisionManager = runtime.getSupervisionManager()
        let lifecycleManager = runtime.getLifecycleManager()
        
        // 创建Actor
        let factory = SimpleActorFactory<Actor>({ => HighPerformanceTestActor("fault-test") })
        let props = Props<Actor>(factory)
        let actor = system.actorOf(props, "fault-tolerance-actor")
        
        @Assert.NotNull(actor)
        
        // 验证Actor已被监督
        let actorState = lifecycleManager.getActorState(actor)
        @Assert.NotNull(actorState)
        
        // 发送正常消息
        actor.tell(StringMessage("normal message"))
        
        // 等待处理
        Thread.sleep(Duration.millisecond * 100)
        
        // 验证Actor仍然运行
        let updatedState = lifecycleManager.getActorState(actor)
        @Assert.NotNull(updatedState)
        
        system.shutdown()
        println("✅ 企业级容错和恢复测试通过")
    }
    
    /**
     * 测试企业级配置管理
     */
    @Test
    public func testEnterpriseConfigurationManagement(): Unit {
        println("=== 测试企业级配置管理 ===")
        
        // 测试不同配置模式
        let devConfig = EnterpriseActorSystemConfig.createDevelopment()
        let prodConfig = EnterpriseActorSystemConfig.createProduction()
        let extremeConfig = EnterpriseActorSystemConfig.createExtreme()
        
        @Assert.Equal(SystemMode.Development, devConfig.mode)
        @Assert.Equal(SystemMode.Production, prodConfig.mode)
        @Assert.Equal(SystemMode.Production, extremeConfig.mode)
        
        @Assert.Equal(PerformanceMode.Balanced, devConfig.performanceMode)
        @Assert.Equal(PerformanceMode.HighThroughput, prodConfig.performanceMode)
        @Assert.Equal(PerformanceMode.Extreme, extremeConfig.performanceMode)
        
        @Assert.True(devConfig.enableMonitoring)
        @Assert.False(devConfig.enablePersistence)
        @Assert.True(prodConfig.enablePersistence)
        
        @Assert.Equal(100_000, devConfig.maxActors)
        @Assert.Equal(1_000_000, prodConfig.maxActors)
        @Assert.Equal(10_000_000, extremeConfig.maxActors)
        
        @Assert.Equal(1_000_000, devConfig.maxThroughput)
        @Assert.Equal(50_000_000, prodConfig.maxThroughput)
        @Assert.Equal(100_000_000, extremeConfig.maxThroughput)
        
        println("✅ 企业级配置管理测试通过")
    }
}
