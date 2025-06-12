/*
 * 仓颉Actor系统 - 单元测试
 * 测试Actor系统的核心功能
 */
package cangjie_actor.tests.actor_tests

import cangjie_actor.*
import std.unittest.*
import std.time.*

// 测试用的简单Actor
class TestActor <: Actor {
    private let actorName: String
    private var messageReceived: Bool = false
    private var lastMessage: String = ""
    
    public init(name: String) {
        this.actorName = name
    }
    
    public prop name: String {
        get() { actorName }
    }
    
    public prop description: String {
        get() { "Test Actor: ${actorName}" }
    }
    
    public func started(): Unit {
        // 测试启动
    }
    
    public func stopped(): Unit {
        // 测试停止
    }
    
    public func hasReceivedMessage(): Bool {
        messageReceived
    }
    
    public func getLastMessage(): String {
        lastMessage
    }
    
    public func processTestMessage(message: String): Unit {
        messageReceived = true
        lastMessage = message
    }
}

// 测试消息
struct TestMessage <: Message {
    public let content: String
    
    public init(content: String) {
        this.content = content
    }
    
    public func messageType(): String {
        "TestMessage"
    }
}

@Test
func testActorCreation(): Unit {
    let actor = TestActor("test-actor")
    @Assert(actor.name == "test-actor")
    @Assert(actor.description.contains("Test Actor"))
}

@Test
func testActorContext(): Unit {
    let context = ActorContext("test-context")
    @Assert(context.getName() == "test-context")
    @Assert(context.getState() == ActorState.Starting)
    @Assert(!context.isStopped())
    
    // 测试状态变更
    context.setState(ActorState.Running)
    @Assert(context.getState() == ActorState.Running)
    
    // 测试停止
    context.stop()
    @Assert(context.isStopped())
    @Assert(context.getState() == ActorState.Stopping)
}

@Test
func testMessageQueue(): Unit {
    let context = ActorContext("message-test")
    let message = TestMessage("Hello")
    
    // 测试发送消息
    let sent = context.sendMessage(message)
    @Assert(sent)
    
    // 测试接收消息
    match (context.receiveMessage()) {
        case Some(receivedMsg) => {
            @Assert(receivedMsg.messageType() == "TestMessage")
        }
        case None => {
            @Assert(false, "Should have received a message")
        }
    }
}

@Test
func testActorRuntime(): Unit {
    let runtime = ActorRuntime()
    
    try {
        // 测试初始状态
        @Assert(runtime.getActorCount() == 0)
        
        // 创建并启动Actor
        let actor = TestActor("runtime-test")
        let actorRef = runtime.spawnActor(actor, "runtime-test-actor")
        
        // 等待Actor启动
        sleep(Duration.millisecond * 50)
        
        @Assert(runtime.getActorCount() == 1)
        @Assert(actorRef.getName() == "runtime-test-actor")
        
        // 测试查找Actor
        match (runtime.find("runtime-test-actor")) {
            case Some(foundRef) => {
                @Assert(foundRef.getName() == "runtime-test-actor")
            }
            case None => {
                @Assert(false, "Should have found the actor")
            }
        }
        
        // 停止Actor
        actorRef.stop()
        
        // 等待Actor停止
        sleep(Duration.millisecond * 100)
        
        @Assert(runtime.getActorCount() == 0)
        
    } finally {
        runtime.shutdown()
    }
}

@Test
func testMessageTypes(): Unit {
    // 测试PingMessage
    let pingMsg = PingMessage(123)
    @Assert(pingMsg.messageType() == "PingMessage")
    @Assert(pingMsg.id == 123)
    @Assert(pingMsg.priority() == 0)
    
    // 测试PongMessage
    let pongMsg = PongMessage(456)
    @Assert(pongMsg.messageType() == "PongMessage")
    @Assert(pongMsg.originalId == 456)
    
    // 测试StopMessage
    let stopMsg = StopMessage()
    @Assert(stopMsg.messageType() == "StopMessage")
    @Assert(stopMsg.priority() == 1000)
}

@Test
func testActorStates(): Unit {
    // 测试状态枚举
    @Assert(ActorState.Starting.hashCode() == 0)
    @Assert(ActorState.Running.hashCode() == 1)
    @Assert(ActorState.Stopping.hashCode() == 2)
    @Assert(ActorState.Stopped.hashCode() == 3)
    
    // 测试状态转换
    @Assert(ActorState.fromHashCode(0) == ActorState.Starting)
    @Assert(ActorState.fromHashCode(1) == ActorState.Running)
    @Assert(ActorState.fromHashCode(2) == ActorState.Stopping)
    @Assert(ActorState.fromHashCode(3) == ActorState.Stopped)
    @Assert(ActorState.fromHashCode(999) == ActorState.Stopped)  // 默认值
}

@Test
func testConcurrentActors(): Unit {
    let runtime = ActorRuntime()
    
    try {
        let actorRefs = ArrayList<ActorRef>()
        
        // 创建多个Actor
        for (i in 0..5) {
            let actor = TestActor("concurrent-${i}")
            let actorRef = runtime.spawnActor(actor, "concurrent-actor-${i}")
            actorRefs.append(actorRef)
        }
        
        // 等待所有Actor启动
        sleep(Duration.millisecond * 100)
        
        @Assert(runtime.getActorCount() == 5)
        
        // 向所有Actor发送消息
        for ((index, actorRef) in actorRefs.withIndex()) {
            let message = TestMessage("Message to actor ${index}")
            actorRef.send(message)
        }
        
        // 等待消息处理
        sleep(Duration.millisecond * 200)
        
        // 停止所有Actor
        for (actorRef in actorRefs) {
            actorRef.stop()
        }
        
        // 等待所有Actor停止
        sleep(Duration.millisecond * 200)
        
        @Assert(runtime.getActorCount() == 0)
        
    } finally {
        runtime.shutdown()
    }
}

// 主测试函数
func main(): Unit {
    println("=== 仓颉Actor系统单元测试 ===")
    
    let testSuite = TestSuite("Actor System Tests")
    
    testSuite.addTest(TestCase("Actor Creation", testActorCreation))
    testSuite.addTest(TestCase("Actor Context", testActorContext))
    testSuite.addTest(TestCase("Message Queue", testMessageQueue))
    testSuite.addTest(TestCase("Actor Runtime", testActorRuntime))
    testSuite.addTest(TestCase("Message Types", testMessageTypes))
    testSuite.addTest(TestCase("Actor States", testActorStates))
    testSuite.addTest(TestCase("Concurrent Actors", testConcurrentActors))
    
    let result = testSuite.run()
    
    if (result.isSuccess()) {
        println("✅ 所有测试通过!")
    } else {
        println("❌ 测试失败:")
        for (failure in result.getFailures()) {
            println("  - ${failure}")
        }
    }
    
    println("=== 测试完成 ===")
}
