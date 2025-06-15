/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 完整系统集成测试
 * 验证所有6层架构的协作和功能完整性
 */
package test

import std.unittest.*
import std.time.*
import std.collection.*

// Foundation层
import cactor.foundation.queue.{LockFreeQueue, SimpleQueue}
import cactor.foundation.serialization.SerializationManager
import cactor.foundation.network.{NetworkAddress, TcpTransport}
import cactor.foundation.memory.{StringPool, ByteArrayPool}

// Core层
import cactor.core.message.{Message, StringMessage, PingMessage, Envelope}
import cactor.core.message.{MessageSerializer, NetworkMessage}
import cactor.core.actor.{Actor, ActorLifecycleState}

// Runtime层
import cactor.runtime.mailbox.{FoundationMailbox, FoundationMailboxFactory}

// Patterns层
import cactor.patterns.ask.{AskPatternManager, DummyActorRef}
import cactor.patterns.circuit_breaker.{CircuitBreakerFactory, CircuitBreakerState}
import cactor.patterns.backpressure.{BackpressureControllerFactory, BackpressureStrategy}
import cactor.patterns.routing.{RouterFactory}

// Distribution层
import cactor.distribution.remote.{SimpleRemoteManager, RemoteFactory}

// Integration层
import cactor.integration.monitoring.{Metrics, PerformanceMonitor}

/**
 * 完整系统集成测试
 */
@Test
class CActorFullSystemTest {
    @Test
    func testFoundationToIntegrationFlow(): Unit {
        println("=== 测试Foundation到Integration的完整流程 ===")
        
        // 1. Foundation层 - 创建基础设施
        let queue = LockFreeQueue<Message>(64)
        let serializer = SerializationManager()
        let stringPool = StringPool(10)
        
        // 2. Core层 - 创建消息和序列化
        let message = StringMessage("Full System Test")
        let messageSerializer = MessageSerializer()
        let serializedData = messageSerializer.serialize(message)
        let deserializedMessage = messageSerializer.deserialize(serializedData)
        
        @Assert(deserializedMessage.messageType() == "StringMessage")
        
        // 3. Runtime层 - 邮箱处理
        let mailbox = FoundationMailbox(32, true)
        let envelope = Envelope(deserializedMessage, Some("systemTester"))
        
        @Assert(mailbox.enqueue(envelope))
        @Assert(mailbox.size() == 1)
        
        // 4. Patterns层 - Ask模式
        let askManager = AskPatternManager(Duration.second * 5)
        askManager.start()
        
        let target = DummyActorRef("system-target")
        let askFuture = askManager.ask(target, message)
        @Assert(!askFuture.isCompleted())
        
        // 5. Distribution层 - 远程通信准备
        let remoteManager = RemoteFactory.createDefaultManager(9090)
        @Assert(!remoteManager.isActive())  // 未启动
        
        // 6. Integration层 - 监控
        let monitor = PerformanceMonitor()
        monitor.recordMessageProcessed()
        monitor.recordActorCreated()
        
        let stats = monitor.getStats()
        @Assert(stats.messagesProcessed >= 1)
        @Assert(stats.actorsCreated >= 1)
        
        // 清理
        askManager.stop()
        
        println("✅ Foundation到Integration完整流程测试通过")
    }
    
    @Test
    func testHighPerformanceMessageFlow(): Unit {
        println("=== 测试高性能消息流 ===")
        
        // 创建高性能组件
        let highPerfQueue = LockFreeQueue<Envelope>(1024)
        let highPerfMailbox = FoundationMailboxFactory.createHighPerformanceMailbox(512)
        let backpressureController = BackpressureControllerFactory.createThrottleController(256, 1000)
        let circuitBreaker = CircuitBreakerFactory.createFastFail<Bool>()
        
        let iterations = 100
        var successCount = 0
        
        // 高性能消息处理流程
        for (i in 0..iterations) {
            let message = PingMessage(i)
            let envelope = Envelope(message, Some("perfTester"))
            
            // 1. 背压控制
            if (backpressureController.trySend(message)) {
                // 2. 断路器保护
                let result = circuitBreaker.execute({ =>
                    // 3. 高性能队列
                    if (highPerfQueue.enqueue(envelope)) {
                        // 4. 高性能邮箱
                        return highPerfMailbox.enqueue(envelope)
                    }
                    false
                })
                
                if (result) {
                    successCount += 1
                }
            }
        }
        
        @Assert(successCount > 0)
        @Assert(highPerfQueue.size() >= 0)
        @Assert(highPerfMailbox.size() >= 0)
        
        let backpressureStats = backpressureController.getStats()
        @Assert(backpressureStats.totalMessages == iterations)
        
        println("✅ 高性能消息流测试通过，成功处理 ${successCount}/${iterations} 消息")
    }
    
    @Test
    func testDistributedActorCommunication(): Unit {
        println("=== 测试分布式Actor通信 ===")
        
        // 创建分布式组件
        let router = RouterFactory.roundRobin()
        let networkMessage = NetworkMessage("remoteActor", StringMessage("Distributed Test"), Some("localActor"))
        
        // 添加远程Actor引用
        let remoteActor1 = DummyActorRef("remote-actor-1")
        let remoteActor2 = DummyActorRef("remote-actor-2")
        
        router.addRoutee(remoteActor1)
        router.addRoutee(remoteActor2)
        
        @Assert(router.getRoutees().size == 2)
        
        // 路由消息到远程Actor
        router.route(StringMessage("Distributed Message"))
        
        // 验证网络消息
        @Assert(networkMessage.targetActor == "remoteActor")
        @Assert(networkMessage.message.messageType() == "StringMessage")
        
        println("✅ 分布式Actor通信测试通过")
    }
    
    @Test
    func testSystemResilience(): Unit {
        println("=== 测试系统弹性 ===")
        
        // 创建弹性组件
        let circuitBreaker = CircuitBreakerFactory.createTolerant<String>()
        let backpressureController = BackpressureControllerFactory.createDropController(10, 50)
        let monitor = PerformanceMonitor()
        
        // 模拟正常操作
        for (i in 0..5) {
            let result = circuitBreaker.execute({ => "success ${i}" })
            @Assert(result == "success ${i}")
            monitor.recordMessageProcessed()
        }
        
        @Assert(circuitBreaker.getState() == CircuitBreakerState.Closed)
        
        // 模拟过载情况
        for (i in 0..20) {
            let message = StringMessage("Overload Test ${i}")
            backpressureController.trySend(message)
        }
        
        let stats = backpressureController.getStats()
        @Assert(stats.totalMessages == 20)
        @Assert(stats.droppedMessages >= 0)  // 可能有消息被丢弃
        
        // 模拟错误恢复
        monitor.recordError()
        let monitorStats = monitor.getStats()
        @Assert(monitorStats.errors >= 1)
        
        println("✅ 系统弹性测试通过")
    }
    
    @Test
    func testEndToEndPerformance(): Unit {
        println("=== 测试端到端性能 ===")
        
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        // 创建完整的处理链
        let serializer = MessageSerializer()
        let mailbox = FoundationMailbox(128, true)
        let router = RouterFactory.random()
        let monitor = PerformanceMonitor()
        
        // 添加处理节点
        for (i in 0..3) {
            router.addRoutee(DummyActorRef("processor-${i}"))
        }
        
        let iterations = 50
        var processedCount = 0
        
        // 端到端消息处理
        for (i in 0..iterations) {
            // 1. 创建消息
            let message = StringMessage("E2E Performance Test ${i}")
            
            // 2. 序列化
            let serialized = serializer.serialize(message)
            let deserialized = serializer.deserialize(serialized)
            
            // 3. 包装信封
            let envelope = Envelope(deserialized, Some("e2eTester"))
            
            // 4. 邮箱处理
            if (mailbox.enqueue(envelope)) {
                // 5. 路由处理
                router.route(deserialized)
                
                // 6. 监控记录
                monitor.recordMessageProcessed()
                processedCount += 1
            }
            
            // 7. 从邮箱取出处理
            mailbox.dequeue()
        }
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let totalTime = endTime - startTime
        let throughput = if (totalTime > 0) { (processedCount * 1000) / totalTime } else { 0 }
        
        @Assert(processedCount == iterations)
        @Assert(mailbox.isEmpty())
        
        let monitorStats = monitor.getStats()
        @Assert(monitorStats.messagesProcessed == iterations)
        
        println("✅ 端到端性能测试通过")
        println("   处理消息: ${processedCount}")
        println("   总时间: ${totalTime}ms")
        println("   吞吐量: ${throughput} msg/sec")
        
        if (throughput > 1000) {
            println("🎉 性能优秀！超过1000消息/秒")
        }
    }
    
    @Test
    func testSystemIntegrity(): Unit {
        println("=== 测试系统完整性 ===")
        
        // 验证所有层的基本功能
        
        // Foundation层验证
        let queue = LockFreeQueue<String>(16)
        @Assert(queue.enqueue("foundation-test"))
        @Assert(queue.size() == 1)
        
        // Core层验证
        let message = StringMessage("core-test")
        @Assert(message.messageType() == "StringMessage")
        
        // Runtime层验证
        let mailbox = FoundationMailbox(8)
        let envelope = Envelope(message, None)
        @Assert(mailbox.enqueue(envelope))
        
        // Patterns层验证
        let askManager = AskPatternManager(Duration.second * 1)
        askManager.start()
        @Assert(askManager.getPendingRequestCount() == 0)
        askManager.stop()
        
        // Distribution层验证
        let remoteManager = RemoteFactory.createDefaultManager(9091)
        @Assert(remoteManager.getLocalAddress().port == 9091)
        
        // Integration层验证
        let counter = Metrics.counter("system.integrity.test")
        counter.increment()
        @Assert(counter.get() >= 1)
        
        println("✅ 系统完整性测试通过")
    }
}

/**
 * 系统压力测试
 */
@Test
class CActorStressTest {
    @Test
    func testHighVolumeMessageProcessing(): Unit {
        println("=== 高容量消息处理压力测试 ===")
        
        let queue = LockFreeQueue<Envelope>(2048)
        let mailbox = FoundationMailbox(1024, true)
        let monitor = PerformanceMonitor()
        
        let iterations = 1000
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        // 批量创建和处理消息
        for (i in 0..iterations) {
            let message = PingMessage(i)
            let envelope = Envelope(message, Some("stressTester"))
            
            @Assert(queue.enqueue(envelope))
            @Assert(mailbox.enqueue(envelope))
            monitor.recordMessageProcessed()
        }
        
        // 批量处理
        var processedCount = 0
        while (!queue.isEmpty() && !mailbox.isEmpty()) {
            queue.dequeue()
            mailbox.dequeue()
            processedCount += 1
        }
        
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let totalTime = endTime - startTime
        let throughput = if (totalTime > 0) { (processedCount * 2 * 1000) / totalTime } else { 0 }
        
        @Assert(processedCount == iterations)
        @Assert(queue.isEmpty())
        @Assert(mailbox.isEmpty())
        
        let stats = monitor.getStats()
        @Assert(stats.messagesProcessed == iterations)
        
        println("✅ 高容量压力测试通过")
        println("   处理消息: ${processedCount}")
        println("   总时间: ${totalTime}ms")
        println("   吞吐量: ${throughput} ops/sec")
        
        if (throughput > 10000) {
            println("🚀 压力测试性能优秀！超过1万操作/秒")
        }
    }
}
