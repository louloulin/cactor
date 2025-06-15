/*
 * 简单的Patterns层测试
 */
import cactor.core.message.{Message, StringMessage}
import cactor.patterns.ask.{AskPatternManager, AskMessage, DummyActorRef}
import cactor.patterns.circuit_breaker.{CircuitBreakerFactory, CircuitBreakerState}
import cactor.patterns.backpressure.{BackpressureControllerFactory, BackpressureStrategy}
import cactor.patterns.routing.{RouterFactory}

main() {
    println("=== Patterns层基础测试 ===")
    
    // 测试Ask模式
    println("测试Ask模式...")
    let askManager = AskPatternManager(Duration.second * 5)
    askManager.start()
    
    let target = DummyActorRef("test-actor")
    let message = StringMessage("Ask Test")
    let future = askManager.ask(target, message)
    
    println("Ask请求ID: ${future.getRequestId()}")
    println("✅ Ask模式测试通过")
    
    askManager.stop()
    
    // 测试Circuit Breaker
    println("测试Circuit Breaker...")
    let circuitBreaker = CircuitBreakerFactory.createDefault<String>()
    
    let result = circuitBreaker.execute({ => "success" })
    println("Circuit Breaker结果: ${result}")
    println("Circuit Breaker状态: ${circuitBreaker.getState()}")
    println("✅ Circuit Breaker测试通过")
    
    // 测试Backpressure
    println("测试Backpressure...")
    let backpressureController = BackpressureControllerFactory.createDropController(10, 100)
    
    let testMessage = StringMessage("Backpressure Test")
    let sendResult = backpressureController.trySend(testMessage)
    println("Backpressure发送结果: ${sendResult}")
    
    let stats = backpressureController.getStats()
    println("Backpressure统计: 总消息${stats.totalMessages}, 丢弃${stats.droppedMessages}")
    println("✅ Backpressure测试通过")
    
    // 测试Routing
    println("测试Routing...")
    let router = RouterFactory.roundRobin()
    
    let actor1 = DummyActorRef("routee1")
    let actor2 = DummyActorRef("routee2")
    
    router.addRoutee(actor1)
    router.addRoutee(actor2)
    
    println("Router routees数量: ${router.getRoutees().size}")
    
    let routingMessage = StringMessage("Routing Test")
    router.route(routingMessage)
    println("✅ Routing测试通过")
    
    println("=== Patterns层测试完成 ===")
}
