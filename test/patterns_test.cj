/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Patterns层测试
 * 验证Ask、Circuit Breaker、Backpressure、Routing模式功能
 */
package test

import std.unittest.*
import std.time.*
import std.collection.*
import cactor.core.message.{Message, StringMessage, PingMessage}
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.patterns.ask.{AskPatternManager, AskMessage, AskResponse, AskFuture, DummyActorRef}
import cactor.patterns.circuit_breaker.{CircuitBreaker, BasicCircuitBreaker, CircuitBreakerConfig, CircuitBreakerState, CircuitBreakerFactory}
import cactor.patterns.backpressure.{BackpressureController, BasicBackpressureController, BackpressureStrategy, BackpressureConfig, BackpressureControllerFactory}
import cactor.patterns.routing.{Router, BasicRouter, RouterFactory, RoundRobinRoutingStrategy, RandomRoutingStrategy, BroadcastRoutingStrategy}

/**
 * Ask模式测试
 */
@Test
class AskPatternTest {
    @Test
    func testAskMessage(): Unit {
        let originalMessage = StringMessage("Ask Test")
        let replyTo = DummyActorRef("reply-actor")
        let askMessage = AskMessage("req-123", originalMessage, replyTo)
        
        @Assert(askMessage.messageType() == "AskMessage")
        @Assert(askMessage.getRequestId() == "req-123")
        @Assert(askMessage.getOriginalMessage().messageType() == "StringMessage")
        @Assert(askMessage.getReplyTo().equals(replyTo))
    }
    
    @Test
    func testAskResponse(): Unit {
        let response = StringMessage("Response")
        let askResponse = AskResponse("req-123", response, true)
        
        @Assert(askResponse.messageType() == "AskResponse")
        @Assert(askResponse.getRequestId() == "req-123")
        @Assert(askResponse.getResponse().messageType() == "StringMessage")
        @Assert(askResponse.isSuccess())
    }
    
    @Test
    func testAskFuture(): Unit {
        let timeout = Duration.second * 5
        let future = AskFuture<String>("req-123", timeout)
        
        @Assert(future.getRequestId() == "req-123")
        @Assert(!future.isCompleted())
        @Assert(!future.isTimedOut())
        
        // 测试完成
        future.complete("test result")
        @Assert(future.isCompleted())
        
        let result = future.get()
        @Assert(result.isSuccess())
        @Assert(result.get() == "test result")
    }
    
    @Test
    func testAskPatternManager(): Unit {
        let manager = AskPatternManager(Duration.second * 10)
        manager.start()
        
        @Assert(manager.getPendingRequestCount() == 0)
        @Assert(manager.getDefaultTimeout().toMilliseconds() == 10000)
        
        // 测试Ask请求
        let target = DummyActorRef("target-actor")
        let message = StringMessage("Ask Manager Test")
        let future = manager.ask(target, message)
        
        @Assert(manager.getPendingRequestCount() == 1)
        @Assert(!future.isCompleted())
        
        // 模拟响应
        let response = AskResponse(future.getRequestId(), StringMessage("Response"), true)
        manager.handleResponse(response)
        
        @Assert(manager.getPendingRequestCount() == 0)
        @Assert(future.isCompleted())
        
        manager.stop()
    }
}

/**
 * Circuit Breaker模式测试
 */
@Test
class CircuitBreakerTest {
    @Test
    func testCircuitBreakerConfig(): Unit {
        let config = CircuitBreakerConfig(5, 3, Duration.second * 5, Duration.second * 30)
        
        @Assert(config.failureThreshold == 5)
        @Assert(config.successThreshold == 3)
        @Assert(config.timeout.toMilliseconds() == 5000)
        @Assert(config.resetTimeout.toMilliseconds() == 30000)
    }
    
    @Test
    func testBasicCircuitBreaker(): Unit {
        let config = CircuitBreakerConfig(3, 2, Duration.second * 5, Duration.second * 10)
        let circuitBreaker = BasicCircuitBreaker<String>(config)
        
        @Assert(circuitBreaker.getState() == CircuitBreakerState.Closed)
        
        // 测试成功操作
        let result1 = circuitBreaker.execute({ => "success" })
        @Assert(result1 == "success")
        @Assert(circuitBreaker.getState() == CircuitBreakerState.Closed)
        
        // 测试失败操作
        var failureCount = 0
        for (i in 0..3) {
            try {
                circuitBreaker.execute({ => throw Exception("test failure") })
            } catch (e: Exception) {
                failureCount += 1
            }
        }
        
        @Assert(failureCount == 3)
        @Assert(circuitBreaker.getState() == CircuitBreakerState.Open)
        
        // 测试开启状态下的快速失败
        try {
            circuitBreaker.execute({ => "should fail" })
            @Assert(false, "应该抛出CircuitBreakerOpenException")
        } catch (e: Exception) {
            @Assert(e.message.contains("断路器处于开启状态"))
        }
    }
    
    @Test
    func testCircuitBreakerFactory(): Unit {
        let defaultBreaker = CircuitBreakerFactory.createDefault<String>()
        let fastFailBreaker = CircuitBreakerFactory.createFastFail<String>()
        let tolerantBreaker = CircuitBreakerFactory.createTolerant<String>()
        
        @Assert(defaultBreaker.getState() == CircuitBreakerState.Closed)
        @Assert(fastFailBreaker.getState() == CircuitBreakerState.Closed)
        @Assert(tolerantBreaker.getState() == CircuitBreakerState.Closed)
        
        // 测试不同配置的行为
        let result = defaultBreaker.execute({ => "test" })
        @Assert(result == "test")
    }
    
    @Test
    func testCircuitBreakerStats(): Unit {
        let config = CircuitBreakerConfig(2, 1, Duration.second * 5, Duration.second * 10)
        let circuitBreaker = BasicCircuitBreaker<String>(config)
        
        // 执行一些操作
        circuitBreaker.execute({ => "success1" })
        circuitBreaker.execute({ => "success2" })
        
        let stats = circuitBreaker.getStats()
        @Assert(stats.state == CircuitBreakerState.Closed)
        @Assert(stats.successCount == 2)
        @Assert(stats.totalRequests == 2)
        @Assert(stats.getSuccessRate() == 1.0)
    }
}

/**
 * Backpressure模式测试
 */
@Test
class BackpressureTest {
    @Test
    func testBackpressureConfig(): Unit {
        let config = BackpressureConfig(
            BackpressureStrategy.Drop,
            1000,
            500,
            Duration.second,
            0.8,
            Duration.second * 5
        )
        
        @Assert(config.strategy == BackpressureStrategy.Drop)
        @Assert(config.maxBufferSize == 1000)
        @Assert(config.maxThroughput == 500)
        @Assert(config.dropThreshold == 0.8)
    }
    
    @Test
    func testBasicBackpressureController(): Unit {
        let controller = BackpressureControllerFactory.createDropController(10, 100)
        
        @Assert(!controller.isOverloaded())
        
        // 测试正常发送
        let message1 = StringMessage("Backpressure Test 1")
        @Assert(controller.trySend(message1))
        
        let stats = controller.getStats()
        @Assert(stats.totalMessages == 1)
        @Assert(stats.droppedMessages == 0)
        
        // 测试缓冲区填满
        for (i in 0..15) {
            let message = StringMessage("Test ${i}")
            controller.trySend(message)
        }
        
        let finalStats = controller.getStats()
        @Assert(finalStats.totalMessages > 1)
        @Assert(finalStats.bufferUtilization >= 0.0)
    }
    
    @Test
    func testBackpressureStrategies(): Unit {
        let dropController = BackpressureControllerFactory.createDropController(5, 50)
        let blockController = BackpressureControllerFactory.createBlockController(5, 50)
        let throttleController = BackpressureControllerFactory.createThrottleController(5, 50)
        
        let message = StringMessage("Strategy Test")
        
        @Assert(dropController.trySend(message))
        @Assert(blockController.trySend(message))
        @Assert(throttleController.trySend(message))
        
        // 验证统计信息
        @Assert(dropController.getStats().totalMessages >= 1)
        @Assert(blockController.getStats().totalMessages >= 1)
        @Assert(throttleController.getStats().totalMessages >= 1)
    }
}

/**
 * Routing模式测试
 */
@Test
class RoutingTest {
    @Test
    func testRoundRobinRouting(): Unit {
        let strategy = RoundRobinRoutingStrategy()
        let routees = [
            DummyActorRef("actor1"),
            DummyActorRef("actor2"),
            DummyActorRef("actor3")
        ]
        
        let message = StringMessage("Round Robin Test")
        
        // 测试轮询选择
        let selected1 = strategy.selectRoutee(routees, message)
        let selected2 = strategy.selectRoutee(routees, message)
        let selected3 = strategy.selectRoutee(routees, message)
        let selected4 = strategy.selectRoutee(routees, message)
        
        @Assert(selected1.isSome())
        @Assert(selected2.isSome())
        @Assert(selected3.isSome())
        @Assert(selected4.isSome())
        
        // 第4个应该回到第1个
        @Assert(selected1.getOrThrow().equals(selected4.getOrThrow()))
    }
    
    @Test
    func testRandomRouting(): Unit {
        let strategy = RandomRoutingStrategy()
        let routees = [
            DummyActorRef("actor1"),
            DummyActorRef("actor2"),
            DummyActorRef("actor3")
        ]
        
        let message = StringMessage("Random Test")
        
        // 测试随机选择
        var selections = ArrayList<ActorRef>()
        for (i in 0..10) {
            match (strategy.selectRoutee(routees, message)) {
                case Some(actor) => selections.append(actor)
                case None => @Assert(false, "应该选择到Actor")
            }
        }
        
        @Assert(selections.size == 10)
    }
    
    @Test
    func testBasicRouter(): Unit {
        let router = RouterFactory.roundRobin()
        
        let actor1 = DummyActorRef("routee1")
        let actor2 = DummyActorRef("routee2")
        
        router.addRoutee(actor1)
        router.addRoutee(actor2)
        
        let routees = router.getRoutees()
        @Assert(routees.size == 2)
        
        // 测试路由消息
        let message = StringMessage("Router Test")
        router.route(message)  // 应该成功路由
        
        // 测试移除routee
        router.removeRoutee(actor1)
        let remainingRoutees = router.getRoutees()
        @Assert(remainingRoutees.size == 1)
    }
    
    @Test
    func testBroadcastRouting(): Unit {
        let router = RouterFactory.broadcast()
        
        let actor1 = DummyActorRef("broadcast1")
        let actor2 = DummyActorRef("broadcast2")
        let actor3 = DummyActorRef("broadcast3")
        
        router.addRoutee(actor1)
        router.addRoutee(actor2)
        router.addRoutee(actor3)
        
        let message = StringMessage("Broadcast Test")
        router.route(message)  // 应该广播给所有Actor
        
        @Assert(router.getRoutees().size == 3)
    }
    
    @Test
    func testRouterFactory(): Unit {
        let roundRobinRouter = RouterFactory.roundRobin()
        let randomRouter = RouterFactory.random()
        let smallestMailboxRouter = RouterFactory.smallestMailbox()
        let broadcastRouter = RouterFactory.broadcast()
        let consistentHashRouter = RouterFactory.consistentHash()
        
        @Assert(roundRobinRouter.getRoutees().size == 0)
        @Assert(randomRouter.getRoutees().size == 0)
        @Assert(smallestMailboxRouter.getRoutees().size == 0)
        @Assert(broadcastRouter.getRoutees().size == 0)
        @Assert(consistentHashRouter.getRoutees().size == 0)
    }
}

/**
 * Patterns集成测试
 */
@Test
class PatternsIntegrationTest {
    @Test
    func testAskWithCircuitBreaker(): Unit {
        // 结合Ask模式和Circuit Breaker
        let circuitBreaker = CircuitBreakerFactory.createDefault<String>()
        let askManager = AskPatternManager(Duration.second * 5)
        askManager.start()
        
        let target = DummyActorRef("cb-target")
        
        // 通过断路器执行Ask操作
        let result = circuitBreaker.execute({ =>
            let future = askManager.ask(target, StringMessage("CB Ask Test"))
            future.getRequestId()
        })
        
        @Assert(result.startsWith("ask-"))
        @Assert(circuitBreaker.getState() == CircuitBreakerState.Closed)
        
        askManager.stop()
    }
    
    @Test
    func testRoutingWithBackpressure(): Unit {
        // 结合Routing和Backpressure
        let router = RouterFactory.roundRobin()
        let backpressureController = BackpressureControllerFactory.createThrottleController(20, 100)
        
        let actor1 = DummyActorRef("bp-actor1")
        let actor2 = DummyActorRef("bp-actor2")
        
        router.addRoutee(actor1)
        router.addRoutee(actor2)
        
        // 通过背压控制发送消息
        for (i in 0..10) {
            let message = StringMessage("BP Routing Test ${i}")
            if (backpressureController.trySend(message)) {
                router.route(message)
            }
        }
        
        let stats = backpressureController.getStats()
        @Assert(stats.totalMessages == 10)
        @Assert(router.getRoutees().size == 2)
    }
}
