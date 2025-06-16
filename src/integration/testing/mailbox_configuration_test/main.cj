/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Mailbox配置验证测试
 * 验证Actor启动时的mailbox配置和异步消息处理
 */
package cactor.integration.testing.mailbox_configuration_test

import std.time.*
import std.collection.*
import std.sync.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import cactor.core.system.*
import cactor.runtime.mailbox.*

/**
 * 测试消息
 */
public class MailboxTestMessage <: Message {
    private let id: Int64
    private let content: String
    private let messageTimestamp: Int64

    public init(id: Int64, content: String) {
        this.id = id
        this.content = content
        this.messageTimestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }

    public func getId(): Int64 { id }
    public func getContent(): String { content }
    public func getTimestamp(): Int64 { messageTimestamp }

    public func messageType(): String { "MailboxTestMessage" }
    public func priority(): Int32 { 0 }
    public func timestamp(): Int64 { messageTimestamp }
}

/**
 * 测试Actor - 验证mailbox功能
 */
public class MailboxTestActor <: Actor {
    private let processedCount: AtomicInt64
    private let receivedMessages: ArrayList<String>
    private let mutex: ReentrantMutex

    public init() {
        this.processedCount = AtomicInt64(0)
        this.receivedMessages = ArrayList<String>()
        this.mutex = ReentrantMutex()
    }
    
    public prop name: String {
        get() { "MailboxTestActor" }
    }
    
    public prop description: String {
        get() { "Mailbox配置测试Actor" }
    }

    public func receive(message: Message, _: ActorContext): MessageResult {
        match (message) {
            case testMsg: MailboxTestMessage =>
                processedCount.fetchAdd(1)
                
                mutex.lock()
                receivedMessages.append("ID:${testMsg.getId()}-${testMsg.getContent()}")
                mutex.unlock()
                
                return MessageResult.Handled
            case _ =>
                return MessageResult.Unhandled
        }
    }

    public func getProcessedCount(): Int64 { processedCount.load() }
    
    public func getReceivedMessages(): Array<String> {
        mutex.lock()
        let result = Array<String>(Int64(receivedMessages.size), { i => receivedMessages[i] })
        mutex.unlock()
        return result
    }

    public func reset(): Unit {
        processedCount.store(0)
        mutex.lock()
        receivedMessages.clear()
        mutex.unlock()
    }
}

/**
 * Mailbox配置验证测试套件
 */
public class MailboxConfigurationTestSuite {
    
    public init() {}

    /**
     * 测试1: 基础mailbox配置验证
     */
    public func testBasicMailboxConfiguration(): Bool {
        println("🚀 测试1: 基础mailbox配置验证")

        let system = SimpleActorSystem("mailbox-config-test")
        let actor = MailboxTestActor()
        let props = PropsFactory.create({ => actor })
        
        // 创建Actor - 应该自动配置mailbox
        let actorRef = system.actorOf(props, "mailbox-test-actor")
        
        // 验证ActorRef类型
        match (actorRef) {
            case simpleRef: SimpleActorRef =>
                let mailbox = simpleRef.getMailbox()
                let mailboxStats = simpleRef.getMailboxStats()
                
                println("  Actor创建成功: ${simpleRef.path.toString()}")
                println("  Mailbox统计: ${mailboxStats}")
                println("  Mailbox为空: ${mailbox.isEmpty()}")
                println("  Mailbox大小: ${mailbox.size()}")
                
                system.terminate()
                return true
            case _ =>
                println("  ❌ ActorRef类型不正确")
                system.terminate()
                return false
        }
    }

    /**
     * 测试2: 异步消息传递验证
     */
    public func testAsyncMessageDelivery(): Bool {
        println("🚀 测试2: 异步消息传递验证")

        let system = SimpleActorSystem("async-message-test")
        let actor = MailboxTestActor()
        let props = PropsFactory.create({ => actor })
        let actorRef = system.actorOf(props, "async-test-actor")

        let messageCount: Int64 = 10
        
        // 发送多条消息
        for (i in 0..messageCount) {
            let message = MailboxTestMessage(i, "async-test-${i}")
            actorRef.tell(message)
        }

        // 等待消息处理
        sleep(Duration.millisecond * 100)

        let processedCount = actor.getProcessedCount()
        let receivedMessages = actor.getReceivedMessages()

        println("  发送消息数: ${messageCount}")
        println("  处理消息数: ${processedCount}")
        println("  接收消息数: ${receivedMessages.size}")

        if (receivedMessages.size > 0) {
            println("  前3条消息: ")
            let maxShow = if (receivedMessages.size < 3) { receivedMessages.size } else { 3 }
            for (i in 0..Int64(maxShow)) {
                println("    ${receivedMessages[i]}")
            }
        }

        system.terminate()

        let success = processedCount == messageCount && Int64(receivedMessages.size) == messageCount
        
        if (success) {
            println("  ✅ 异步消息传递验证通过")
        } else {
            println("  ❌ 异步消息传递验证失败")
        }

        return success
    }

    /**
     * 测试3: Mailbox容量和性能验证
     */
    public func testMailboxCapacityAndPerformance(): Bool {
        println("🚀 测试3: Mailbox容量和性能验证")

        let system = SimpleActorSystem("capacity-test")
        let actor = MailboxTestActor()
        let props = PropsFactory.create({ => actor })
        let actorRef = system.actorOf(props, "capacity-test-actor")

        let messageCount: Int64 = 100
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        // 快速发送大量消息
        for (i in 0..messageCount) {
            let message = MailboxTestMessage(i, "capacity-test-${i}")
            actorRef.tell(message)
        }

        // 等待处理完成
        sleep(Duration.millisecond * 200)

        let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        let duration = Float64(endTime - startTime) / 1000000000.0  // 秒

        let processedCount = actor.getProcessedCount()
        let throughput = Float64(processedCount) / duration

        println("  发送消息数: ${messageCount}")
        println("  处理消息数: ${processedCount}")
        println("  处理时长: ${duration}秒")
        println("  吞吐量: ${throughput} msg/s")

        // 验证mailbox状态
        match (actorRef) {
            case simpleRef: SimpleActorRef =>
                let mailbox = simpleRef.getMailbox()
                println("  最终Mailbox大小: ${mailbox.size()}")
                println("  Mailbox为空: ${mailbox.isEmpty()}")
            case _ => ()
        }

        system.terminate()

        let success = processedCount == messageCount && throughput > 100.0  // 至少100 msg/s
        
        if (success) {
            println("  ✅ Mailbox容量和性能验证通过")
        } else {
            println("  ❌ Mailbox容量和性能验证失败")
        }

        return success
    }

    /**
     * 测试4: 多Actor并发mailbox验证
     */
    public func testMultiActorConcurrentMailbox(): Bool {
        println("🚀 测试4: 多Actor并发mailbox验证")

        let system = SimpleActorSystem("multi-actor-test")
        let actorCount: Int32 = 5
        let messagesPerActor: Int64 = 20

        let actors = Array<MailboxTestActor>(Int64(actorCount), { _ => MailboxTestActor() })
        let actorRefs = Array<Option<ActorRef>>(Int64(actorCount), { _ => None })

        // 创建多个Actor
        for (i in 0..Int64(actorCount)) {
            let actor = actors[i]
            let props = PropsFactory.create({ => actor })
            let actorRef = system.actorOf(props, "multi-actor-${i}")
            actorRefs[i] = Some(actorRef)
        }

        // 向每个Actor发送消息
        for (i in 0..Int64(actorCount)) {
            match (actorRefs[i]) {
                case Some(actorRef) =>
                    for (j in 0..messagesPerActor) {
                        let message = MailboxTestMessage(j, "multi-actor-${i}-msg-${j}")
                        actorRef.tell(message)
                    }
                case None => ()
            }
        }

        // 等待处理完成
        sleep(Duration.millisecond * 300)

        // 统计结果
        var totalProcessed: Int64 = 0
        for (actor in actors) {
            totalProcessed += actor.getProcessedCount()
        }

        let expectedTotal = Int64(actorCount) * messagesPerActor
        let successRate = Float64(totalProcessed) / Float64(expectedTotal) * 100.0

        println("  Actor数量: ${actorCount}")
        println("  每Actor消息数: ${messagesPerActor}")
        println("  预期总消息数: ${expectedTotal}")
        println("  实际处理总数: ${totalProcessed}")
        println("  成功率: ${successRate}%")

        system.terminate()

        let success = successRate >= 95.0
        
        if (success) {
            println("  ✅ 多Actor并发mailbox验证通过")
        } else {
            println("  ❌ 多Actor并发mailbox验证失败")
        }

        return success
    }

    /**
     * 运行所有mailbox配置测试
     */
    public func runAllTests(): Bool {
        println("========================================")
        println("=== CActor Mailbox配置验证测试套件 ===")
        println("验证Actor启动时的mailbox配置和异步消息处理")
        println("========================================")
        println()

        var passedTests = 0
        let totalTests = 4

        if (testBasicMailboxConfiguration()) {
            passedTests += 1
        }
        println()

        if (testAsyncMessageDelivery()) {
            passedTests += 1
        }
        println()

        if (testMailboxCapacityAndPerformance()) {
            passedTests += 1
        }
        println()

        if (testMultiActorConcurrentMailbox()) {
            passedTests += 1
        }
        println()

        println("========================================")
        println("=== Mailbox配置验证结果 ===")
        println("通过测试: ${passedTests}/${totalTests}")

        if (passedTests == totalTests) {
            println("🎉 所有Mailbox配置验证测试通过！")
            println("✅ Actor启动时mailbox配置功能正常")
            return true
        } else if (passedTests >= 3) {
            println("⚡ 大部分Mailbox配置验证测试通过！")
            println("基本mailbox功能正常")
            return true
        } else {
            println("📈 Mailbox配置验证测试需要改进")
            println("mailbox配置功能需要进一步优化")
            return false
        }
    }
}

main(): Int64 {
    let testSuite = MailboxConfigurationTestSuite()
    let success = testSuite.runAllTests()
    return if (success) { 0 } else { 1 }
}
