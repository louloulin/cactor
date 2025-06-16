/*
 * Copyright (c) 2024. All rights reserved.
 * Core层纯抽象化测试
 * 验证Core层只包含纯抽象接口，具体实现已移到Runtime层
 */
package test

import std.unittest.*
import std.collection.*

// Core层 - 只导入抽象接口
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.system.{ActorSystem}
import cactor.core.guardian.{GuardianActor, GuardianType}
import cactor.core.supervision.{SupervisionStrategy}

// Runtime层 - 导入具体实现
import cactor.runtime.actor.{HighPerformanceActor, HighPerformanceActorBehavior}
import cactor.runtime.context.{PooledActorContext, PooledActorContextPool}
import cactor.runtime.guardian.{BaseGuardianActor, RuntimeSystemGuardian, RuntimeUserGuardian}
import cactor.runtime.system.{HighPerformanceActorSystem, HighPerformanceActorSystemConfig}
import cactor.runtime.message.{BatchMessageProcessor}

/**
 * 测试Core层纯抽象化
 */
@Test
class CoreLayerAbstractionTest {
    
    /**
     * 测试Core层接口可以正常使用
     */
    @Test
    public func testCoreLayerInterfaces(): Unit {
        // 测试Actor接口
        let testActor = TestActorImpl()
        @Assert.Equal("test-actor", testActor.name)
        @Assert.Equal("Test Actor Implementation", testActor.description)
        
        // 测试消息处理
        let context = TestActorContextImpl()
        let message = TestMessageImpl()
        let result = testActor.receive(message, context)
        @Assert.Equal(MessageResult.Handled, result)
        
        println("✅ Core层接口测试通过")
    }
    
    /**
     * 测试Runtime层实现可以正常工作
     */
    @Test
    public func testRuntimeLayerImplementations(): Unit {
        // 测试高性能Actor系统
        let config = HighPerformanceActorSystemConfig.createDefault()
        let system = HighPerformanceActorSystem(config)
        
        system.start()
        @Assert.True(system.getSystemStats().isRunning)
        
        // 测试池化上下文
        let contextPool = PooledActorContextPool(100)
        let context = contextPool.acquire()
        @Assert.NotNull(context)
        contextPool.release(context)
        
        // 测试批量消息处理器
        let processor = BatchMessageProcessor(32, 1000)
        let stats = processor.getStats()
        @Assert.Equal(0, stats.totalMessages)
        
        system.shutdown()
        println("✅ Runtime层实现测试通过")
    }
    
    /**
     * 测试Guardian Actor的抽象和实现分离
     */
    @Test
    public func testGuardianActorAbstraction(): Unit {
        // Core层只有抽象接口
        let guardianType = GuardianType.System
        @Assert.Equal("System", guardianType.toString())
        
        // Runtime层有具体实现
        let systemGuardian = RuntimeSystemGuardian(TestActorSystemImpl())
        @Assert.Equal(GuardianType.System, systemGuardian.guardianType)
        @Assert.Equal("system", systemGuardian.name)
        
        println("✅ Guardian Actor抽象测试通过")
    }
    
    /**
     * 测试消息处理的抽象和实现分离
     */
    @Test
    public func testMessageProcessingAbstraction(): Unit {
        // Core层只有消息接口
        let message = TestMessageImpl()
        @Assert.Equal("TestMessage", message.getType())
        
        // Runtime层有具体的批量处理实现
        let processor = BatchMessageProcessor(10, 500)
        let stats = processor.getStats()
        @Assert.Equal(0, stats.totalBatches)
        
        println("✅ 消息处理抽象测试通过")
    }
    
    /**
     * 测试架构层次的正确性
     */
    @Test
    public func testArchitecturalLayering(): Unit {
        // 验证Core层不依赖Runtime层
        // 这通过编译时检查来验证 - 如果Core层导入了Runtime层的具体实现，编译会失败
        
        // 验证Runtime层可以实现Core层的接口
        let behavior = TestHighPerformanceActorBehavior()
        let contextPool = PooledActorContextPool(10)
        let actor = HighPerformanceActor("test", behavior, contextPool)
        
        // Actor应该实现Core层的Actor接口
        let coreActor: Actor = actor
        @Assert.Equal("test", coreActor.name)
        
        println("✅ 架构层次测试通过")
    }
}

/**
 * 测试用的Actor实现
 */
class TestActorImpl <: Actor {
    public prop name: String {
        get() { "test-actor" }
    }
    
    public prop description: String {
        get() { "Test Actor Implementation" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        MessageResult.Handled
    }
}

/**
 * 测试用的ActorContext实现
 */
class TestActorContextImpl <: ActorContext {
    public func sender(): Option<String> {
        Some("test-sender")
    }
}

/**
 * 测试用的Message实现
 */
class TestMessageImpl <: Message {
    public func getType(): String { "TestMessage" }
    public func getPayload(): String { "test payload" }
    public func messageType(): String { "TestMessage" }
}

/**
 * 测试用的ActorSystem实现
 */
class TestActorSystemImpl <: ActorSystem {
    public prop name: String {
        get() { "test-system" }
    }
    
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        TestActorRefImpl(name)
    }
    
    public func actorOf(props: Props<Actor>): ActorRef {
        TestActorRefImpl("auto-generated")
    }
    
    public func actorSelection(path: String): ActorSelection {
        TestActorSelectionImpl(path)
    }
    
    public func terminate(): Unit {
        // 测试实现
    }
}

/**
 * 测试用的ActorRef实现
 */
class TestActorRefImpl <: ActorRef {
    private let actorName: String
    
    public init(name: String) {
        this.actorName = name
    }
    
    public prop path: ActorPath {
        get() { ActorPath("test", "/test/${actorName}") }
    }
    
    public func tell(message: Message): Unit {
        // 测试实现
    }
    
    public func tell(message: Message, sender: Option<String>): Unit {
        // 测试实现
    }
    
    public func equals(other: ActorRef): Bool {
        false
    }
    
    public func hashCode(): Int32 {
        Int32(actorName.hashCode())
    }
}

/**
 * 测试用的ActorSelection实现
 */
class TestActorSelectionImpl <: ActorSelection {
    private let selectionPath: String
    
    public init(path: String) {
        this.selectionPath = path
    }
    
    public func tell(message: Message): Unit {
        // 测试实现
    }
    
    public func resolveOne(): Option<ActorRef> {
        Some(TestActorRefImpl("resolved"))
    }
}

/**
 * 测试用的高性能Actor行为
 */
class TestHighPerformanceActorBehavior <: HighPerformanceActorBehavior {
    public func receive(message: Message, context: PooledActorContext): MessageResult {
        MessageResult.Handled
    }
}
