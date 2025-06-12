/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 路由器测试
 * 验证消息路由和负载均衡功能
 */
package cactor.tests.routing_test

import std.sync.*
import std.time.*
import std.collection.*
import cactor.routing.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.Message

/**
 * 测试消息类
 */
class TestMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestMessage"
    }
}

/**
 * 测试ActorRef实现
 */
class TestActorRef <: ActorRef {
    private let id: String
    private let receivedMessages: ArrayList<Message>
    private let mutex: ReentrantMutex

    public init(id: String) {
        this.id = id
        this.receivedMessages = ArrayList<Message>()
        this.mutex = ReentrantMutex()
    }

    public prop path: ActorPath {
        get() {
            ActorPath("test", id)
        }
    }

    public func tell(message: Message): Unit {
        mutex.lock()
        try {
            receivedMessages.append(message)
            println("TestActorRef[${id}] 收到消息: ${message.messageType()}")
        } finally {
            mutex.unlock()
        }
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        tell(message)
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case ref: TestActorRef => this.id == ref.id
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(id.hashCode())
    }

    public func getReceivedCount(): Int32 {
        mutex.lock()
        try {
            Int32(receivedMessages.size)
        } finally {
            mutex.unlock()
        }
    }

    public func clearMessages(): Unit {
        mutex.lock()
        try {
            receivedMessages.clear()
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 测试轮询路由策略
 */
func testRoundRobinRouting(): Bool {
    let strategy = RoundRobinRoutingStrategy()
    let actor1 = TestActorRef("actor1")
    let actor2 = TestActorRef("actor2")
    let actor3 = TestActorRef("actor3")
    let routees: Array<ActorRef> = [actor1, actor2, actor3]
    
    let message = TestMessage("test")
    
    // 测试轮询选择
    let selected1 = strategy.selectRoutee(routees, message)
    let selected2 = strategy.selectRoutee(routees, message)
    let selected3 = strategy.selectRoutee(routees, message)
    let selected4 = strategy.selectRoutee(routees, message)  // 应该回到第一个
    
    // 检查选择结果
    match (selected1) {
        case Some(s1) =>
            if (!s1.equals(actor1)) {
                println("✗ 第一次选择应该是actor1")
                return false
            }
        case None =>
            println("✗ 第一次选择失败")
            return false
    }

    match (selected2) {
        case Some(s2) =>
            if (!s2.equals(actor2)) {
                println("✗ 第二次选择应该是actor2")
                return false
            }
        case None =>
            println("✗ 第二次选择失败")
            return false
    }

    match (selected3) {
        case Some(s3) =>
            if (!s3.equals(actor3)) {
                println("✗ 第三次选择应该是actor3")
                return false
            }
        case None =>
            println("✗ 第三次选择失败")
            return false
    }

    match (selected4) {
        case Some(s4) =>
            if (!s4.equals(actor1)) {
                println("✗ 第四次选择应该回到actor1")
                return false
            }
        case None =>
            println("✗ 第四次选择失败")
            return false
    }
    
    println("✓ 轮询路由策略测试通过")
    return true
}

/**
 * 测试随机路由策略
 */
func testRandomRouting(): Bool {
    let strategy = RandomRoutingStrategy()
    let actor1 = TestActorRef("actor1")
    let actor2 = TestActorRef("actor2")
    let routees: Array<ActorRef> = [actor1, actor2]
    
    let message = TestMessage("test")
    
    // 测试多次选择，应该都有结果
    var successCount = 0
    for (i in 0..10) {
        match (strategy.selectRoutee(routees, message)) {
            case Some(_) => successCount += 1
            case None => ()
        }
    }
    
    if (successCount != 10) {
        println("✗ 随机路由选择失败")
        return false
    }
    
    println("✓ 随机路由策略测试通过")
    return true
}

/**
 * 测试广播路由策略
 */
func testBroadcastRouting(): Bool {
    let strategy = BroadcastRoutingStrategy()
    let actor1 = TestActorRef("actor1")
    let actor2 = TestActorRef("actor2")
    let actor3 = TestActorRef("actor3")
    let routees: Array<ActorRef> = [actor1, actor2, actor3]
    
    let message = TestMessage("broadcast")
    
    // 广播消息
    strategy.broadcast(routees, message)
    
    // 检查所有Actor都收到了消息
    if (actor1.getReceivedCount() != 1 || 
        actor2.getReceivedCount() != 1 || 
        actor3.getReceivedCount() != 1) {
        println("✗ 广播路由失败，不是所有Actor都收到消息")
        return false
    }
    
    println("✓ 广播路由策略测试通过")
    return true
}

/**
 * 测试一致性哈希路由策略
 */
func testConsistentHashRouting(): Bool {
    let strategy = ConsistentHashRoutingStrategy()
    let actor1 = TestActorRef("actor1")
    let actor2 = TestActorRef("actor2")
    let routees: Array<ActorRef> = [actor1, actor2]
    
    let message1 = TestMessage("message1")
    let message2 = TestMessage("message1")  // 相同内容
    
    // 相同消息应该路由到相同Actor
    let selected1 = strategy.selectRoutee(routees, message1)
    let selected2 = strategy.selectRoutee(routees, message2)
    
    // 检查两次选择的结果
    match (selected1) {
        case Some(s1) =>
            match (selected2) {
                case Some(s2) =>
                    if (!s1.equals(s2)) {
                        println("✗ 一致性哈希路由不一致")
                        return false
                    }
                case None =>
                    println("✗ 第二次一致性哈希路由选择失败")
                    return false
            }
        case None =>
            println("✗ 第一次一致性哈希路由选择失败")
            return false
    }
    
    println("✓ 一致性哈希路由策略测试通过")
    return true
}

/**
 * 测试基础路由器
 */
func testBasicRouter(): Bool {
    let router = RouterFactory.roundRobin()
    let actor1 = TestActorRef("router-actor1")
    let actor2 = TestActorRef("router-actor2")
    
    // 添加路由目标
    router.addRoutee(actor1)
    router.addRoutee(actor2)
    
    if (router.getRoutees().size != 2) {
        println("✗ 路由器添加目标失败")
        return false
    }
    
    // 路由消息
    let message1 = TestMessage("msg1")
    let message2 = TestMessage("msg2")
    
    router.route(message1)
    router.route(message2)
    
    // 检查消息分发
    let total = actor1.getReceivedCount() + actor2.getReceivedCount()
    if (total != 2) {
        println("✗ 路由器消息分发失败")
        return false
    }
    
    // 移除路由目标
    router.removeRoutee(actor1)
    if (router.getRoutees().size != 1) {
        println("✗ 路由器移除目标失败")
        return false
    }
    
    println("✓ 基础路由器测试通过")
    return true
}

/**
 * 测试路由器工厂
 */
func testRouterFactory(): Bool {
    let roundRobinRouter = RouterFactory.roundRobin()
    let randomRouter = RouterFactory.random()
    let broadcastRouter = RouterFactory.broadcast()
    let hashRouter = RouterFactory.consistentHash()
    
    // 检查策略类型
    match (roundRobinRouter.getStrategy()) {
        case _: RoundRobinRoutingStrategy => ()
        case _ => 
            println("✗ 轮询路由器工厂创建失败")
            return false
    }
    
    match (randomRouter.getStrategy()) {
        case _: RandomRoutingStrategy => ()
        case _ => 
            println("✗ 随机路由器工厂创建失败")
            return false
    }
    
    match (broadcastRouter.getStrategy()) {
        case _: BroadcastRoutingStrategy => ()
        case _ => 
            println("✗ 广播路由器工厂创建失败")
            return false
    }
    
    match (hashRouter.getStrategy()) {
        case _: ConsistentHashRoutingStrategy => ()
        case _ => 
            println("✗ 一致性哈希路由器工厂创建失败")
            return false
    }
    
    println("✓ 路由器工厂测试通过")
    return true
}

/**
 * 测试路由器ActorRef包装器
 */
func testRouterActorRef(): Bool {
    let router = RouterFactory.roundRobin()
    let actor1 = TestActorRef("wrapper-actor1")
    let actor2 = TestActorRef("wrapper-actor2")
    
    router.addRoutee(actor1)
    router.addRoutee(actor2)
    
    let routerRef = RouterActorRef(router, "test-router")
    
    // 测试路径
    let actualPath = routerRef.path.toString()
    let expectedPath = "cactor://router/test-router"
    if (actualPath != expectedPath) {
        println("✗ 路由器ActorRef路径不正确，期望: ${expectedPath}，实际: ${actualPath}")
        return false
    }
    
    // 测试消息路由
    let message = TestMessage("wrapper-test")
    routerRef.tell(message)
    
    let total = actor1.getReceivedCount() + actor2.getReceivedCount()
    if (total != 1) {
        println("✗ 路由器ActorRef消息路由失败")
        return false
    }
    
    println("✓ 路由器ActorRef包装器测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 路由器测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testRoundRobinRouting()
    allPassed = allPassed && testRandomRouting()
    allPassed = allPassed && testBroadcastRouting()
    allPassed = allPassed && testConsistentHashRouting()
    allPassed = allPassed && testBasicRouter()
    allPassed = allPassed && testRouterFactory()
    allPassed = allPassed && testRouterActorRef()
    
    if (allPassed) {
        println("\n🎉 所有路由器测试通过！")
        println("✓ 轮询路由策略正确")
        println("✓ 随机路由策略正确")
        println("✓ 广播路由策略正确")
        println("✓ 一致性哈希路由策略正确")
        println("✓ 基础路由器功能正常")
        println("✓ 路由器工厂正常")
        println("✓ 路由器ActorRef包装器正常")
        println("\n这验证了CActor的路由器实现！")
        println("🚀 Phase 3: 路由器功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
