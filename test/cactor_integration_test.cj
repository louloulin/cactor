/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 7.0 集成测试
 * 验证各层间协作正常，确保架构重构成功
 */
package test

import std.unittest.*
import std.collection.*
import cactor.foundation.queue.{Queue, LockFreeQueue}
import cactor.foundation.serialization.SerializationManager
import cactor.foundation.network.{NetworkAddress, TcpTransport}
import cactor.foundation.memory.{StringPool, ByteArrayPool}
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage, Envelope}
import cactor.core.message.{MessageSerializer, NetworkMessage, NetworkMessageTransport}
import cactor.core.actor.{Actor, ActorLifecycleState}
import cactor.runtime.mailbox.{Mailbox, FoundationMailbox, FoundationMailboxFactory}

/**
 * Foundation-Core层集成测试
 */
@Test
class FoundationCoreIntegrationTest {
    @Test
    func testQueueMessageIntegration(): Unit {
        // 测试Foundation队列与Core消息的无缝集成
        let queue = LockFreeQueue<Message>(16)
        
        // 创建不同类型的Core消息
        let stringMsg = StringMessage("Foundation-Core Integration")
        let pingMsg = PingMessage(12345)
        let pongMsg = PongMessage(54321)
        
        // 入队Core消息到Foundation队列
        @Assert(queue.enqueue(stringMsg))
        @Assert(queue.enqueue(pingMsg))
        @Assert(queue.enqueue(pongMsg))
        @Assert(queue.size() == 3)
        
        // 出队并验证消息类型
        let expectedTypes = ["StringMessage", "PingMessage", "PongMessage"]
        var index = 0
        
        while (!queue.isEmpty() && index < expectedTypes.size) {
            match (queue.dequeue()) {
                case Some(message) =>
                    @Assert(message.messageType() == expectedTypes[index])
                    index += 1
                case None => break
            }
        }
        
        @Assert(index == 3)
        @Assert(queue.isEmpty())
    }
    
    @Test
    func testSerializationMessageIntegration(): Unit {
        // 测试Foundation序列化与Core消息序列化的协作
        let foundationManager = SerializationManager()
        let coreSerializer = MessageSerializer()
        
        // Core消息序列化
        let message = StringMessage("Serialization Integration Test")
        let coreSerializedData = coreSerializer.serialize(message)
        
        // Foundation层处理序列化数据
        let foundationProcessedData = foundationManager.serializeBytes(coreSerializedData)
        let recoveredData = foundationManager.deserializeBytes(foundationProcessedData)
        
        // Core层反序列化
        let recoveredMessage = coreSerializer.deserialize(recoveredData)
        
        @Assert(recoveredMessage.messageType() == "StringMessage")
        match (recoveredMessage as StringMessage) {
            case Some(msg) => @Assert(msg.getContent() == "Serialization Integration Test")
            case None => @Assert(false, "Foundation-Core序列化集成失败")
        }
    }
    
    @Test
    func testMemoryPoolMessageIntegration(): Unit {
        // 测试Foundation内存池与Core消息的集成
        let stringPool = StringPool(5)
        let byteArrayPool = ByteArrayPool(3)
        
        // 从池中获取资源
        let pooledString = stringPool.acquire()
        let pooledByteArray = byteArrayPool.acquire()
        
        // 创建Core消息并序列化
        let message = StringMessage("Memory Pool Integration")
        let serializer = MessageSerializer()
        let serializedData = serializer.serialize(message)
        
        @Assert(serializedData.size > 0)
        @Assert(pooledString.size >= 0)
        @Assert(pooledByteArray.size >= 0)
        
        // 归还资源
        stringPool.release(pooledString)
        byteArrayPool.release(pooledByteArray)
        
        // 验证池统计
        let stringStats = stringPool.getStatistics()
        let byteArrayStats = byteArrayPool.getStatistics()
        
        @Assert(stringStats.totalAcquired >= 1)
        @Assert(stringStats.totalReleased >= 1)
        @Assert(byteArrayStats.totalAcquired >= 1)
        @Assert(byteArrayStats.totalReleased >= 1)
    }
}

/**
 * Core-Runtime层集成测试
 */
@Test
class CoreRuntimeIntegrationTest {
    @Test
    func testMessageMailboxIntegration(): Unit {
        // 测试Core消息与Runtime邮箱的集成
        let mailbox = FoundationMailbox(8, true)  // 高性能邮箱
        
        // 创建Core消息
        let messages = ArrayList<Message>()
        messages.append(StringMessage("Core-Runtime Integration 1"))
        messages.append(PingMessage(999))
        messages.append(PongMessage(888))
        messages.append(StringMessage("Core-Runtime Integration 2"))
        
        // 包装成信封并入队到Runtime邮箱
        for (message in messages) {
            let envelope = Envelope(message, Some("coreRuntimeSender"))
            @Assert(mailbox.enqueue(envelope))
        }
        
        @Assert(mailbox.size() == 4)
        
        // 从Runtime邮箱出队并验证Core消息
        let expectedTypes = ["StringMessage", "PingMessage", "PongMessage", "StringMessage"]
        var index = 0
        
        while (!mailbox.isEmpty() && index < expectedTypes.size) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    @Assert(envelope.getMessage().messageType() == expectedTypes[index])
                    match (envelope.getSender()) {
                        case Some(sender) => @Assert(sender == "coreRuntimeSender")
                        case None => @Assert(false, "发送者信息丢失")
                    }
                    index += 1
                case None => break
            }
        }
        
        @Assert(index == 4)
        @Assert(mailbox.isEmpty())
    }
    
    @Test
    func testMailboxFactoryMessageIntegration(): Unit {
        // 测试Runtime邮箱工厂与Core消息的集成
        let highPerfMailbox = FoundationMailboxFactory.createHighPerformanceMailbox(16)
        let standardMailbox = FoundationMailboxFactory.createStandardMailbox(8)
        let bulkMailbox = FoundationMailboxFactory.createBulkMailbox(32)
        
        @Assert(highPerfMailbox.getMailboxType() == "LockFree")
        @Assert(standardMailbox.getMailboxType() == "Simple")
        @Assert(bulkMailbox.getMailboxType() == "LockFree")
        
        // 测试不同邮箱处理Core消息
        let testMessage = StringMessage("Mailbox Factory Integration")
        let testEnvelope = Envelope(testMessage, Some("factoryTester"))
        
        @Assert(highPerfMailbox.enqueue(testEnvelope))
        @Assert(standardMailbox.enqueue(testEnvelope))
        @Assert(bulkMailbox.enqueue(testEnvelope))
        
        // 验证所有邮箱都能正确处理消息
        let mailboxes = [highPerfMailbox, standardMailbox, bulkMailbox]
        for (mailbox in mailboxes) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    @Assert(envelope.getMessage().messageType() == "StringMessage")
                    match (envelope.getMessage() as StringMessage) {
                        case Some(msg) => @Assert(msg.getContent() == "Mailbox Factory Integration")
                        case None => @Assert(false, "消息类型转换失败")
                    }
                case None => @Assert(false, "邮箱应该包含消息")
            }
        }
    }
}

/**
 * Foundation-Runtime层集成测试
 */
@Test
class FoundationRuntimeIntegrationTest {
    @Test
    func testFoundationQueueRuntimeMailboxIntegration(): Unit {
        // 测试Foundation队列与Runtime邮箱的底层集成
        let mailbox = FoundationMailbox(32, true)  // 使用LockFreeQueue
        
        // 验证邮箱使用Foundation队列
        @Assert(mailbox.getMailboxType() == "LockFree")
        @Assert(mailbox.capacity() == 32)
        
        // 获取Foundation队列统计
        match (mailbox.getFoundationQueueStats()) {
            case Some(queueStats) =>
                @Assert(queueStats.capacity == 32)
                @Assert(queueStats.currentSize == 0)
                @Assert(queueStats.enqueueCount == 0)
                @Assert(queueStats.dequeueCount == 0)
            case None => @Assert(false, "应该能获取Foundation队列统计")
        }
        
        // 添加消息并验证统计更新
        for (i in 0..5) {
            let message = PingMessage(i)
            let envelope = Envelope(message, None)
            @Assert(mailbox.enqueue(envelope))
        }
        
        match (mailbox.getFoundationQueueStats()) {
            case Some(queueStats) =>
                @Assert(queueStats.currentSize == 5)
                @Assert(queueStats.enqueueCount == 5)
                @Assert(queueStats.getSuccessRate() == 100.0)
            case None => @Assert(false, "统计信息获取失败")
        }
    }
    
    @Test
    func testFoundationMemoryRuntimeMailboxIntegration(): Unit {
        // 测试Foundation内存管理与Runtime邮箱的集成
        let stringPool = StringPool(10)
        let mailbox = FoundationMailbox(16)
        
        // 从内存池获取资源
        let pooledStrings = ArrayList<String>()
        for (i in 0..5) {
            pooledStrings.append(stringPool.acquire())
        }
        
        // 创建消息并使用邮箱
        for (i in 0..5) {
            let message = StringMessage("Memory-Mailbox Integration ${i}")
            let envelope = Envelope(message, Some("memoryTester"))
            @Assert(mailbox.enqueue(envelope))
        }
        
        @Assert(mailbox.size() == 5)
        
        // 处理消息并归还内存池资源
        var processedCount = 0
        while (!mailbox.isEmpty() && processedCount < pooledStrings.size) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    @Assert(envelope.getMessage().messageType() == "StringMessage")
                    stringPool.release(pooledStrings[processedCount])
                    processedCount += 1
                case None => break
            }
        }
        
        @Assert(processedCount == 5)
        @Assert(mailbox.isEmpty())
        
        // 验证内存池统计
        let stats = stringPool.getStatistics()
        @Assert(stats.totalAcquired >= 5)
        @Assert(stats.totalReleased >= 5)
    }
}

/**
 * 三层集成测试
 */
@Test
class ThreeLayerIntegrationTest {
    @Test
    func testFoundationCoreRuntimeIntegration(): Unit {
        // 测试Foundation-Core-Runtime三层集成
        let foundationManager = SerializationManager()
        let coreSerializer = MessageSerializer()
        let runtimeMailbox = FoundationMailbox(64, true)
        
        // 1. 创建Core消息
        let originalMessage = StringMessage("Three Layer Integration Test")
        
        // 2. Core层序列化
        let coreSerializedData = coreSerializer.serialize(originalMessage)
        
        // 3. Foundation层处理
        let foundationProcessedData = foundationManager.serializeBytes(coreSerializedData)
        let recoveredData = foundationManager.deserializeBytes(foundationProcessedData)
        
        // 4. Core层反序列化
        let recoveredMessage = coreSerializer.deserialize(recoveredData)
        
        // 5. Runtime层处理
        let envelope = Envelope(recoveredMessage, Some("threeLayerTester"))
        @Assert(runtimeMailbox.enqueue(envelope))
        
        // 6. 完整流程验证
        match (runtimeMailbox.dequeue()) {
            case Some(processedEnvelope) =>
                @Assert(processedEnvelope.getMessage().messageType() == "StringMessage")
                match (processedEnvelope.getMessage() as StringMessage) {
                    case Some(msg) => @Assert(msg.getContent() == "Three Layer Integration Test")
                    case None => @Assert(false, "三层集成失败")
                }
                match (processedEnvelope.getSender()) {
                    case Some(sender) => @Assert(sender == "threeLayerTester")
                    case None => @Assert(false, "发送者信息丢失")
                }
            case None => @Assert(false, "Runtime邮箱应该包含消息")
        }
        
        @Assert(runtimeMailbox.isEmpty())
    }
    
    @Test
    func testHighVolumeThreeLayerIntegration(): Unit {
        // 高容量三层集成测试
        let foundationQueue = LockFreeQueue<Envelope>(512)
        let coreSerializer = MessageSerializer()
        let runtimeMailbox = FoundationMailbox(256, true)
        let iterations = 100
        
        // 批量创建和处理消息
        for (i in 0..iterations) {
            // 1. Core层创建消息
            let message = if (i % 2 == 0) {
                StringMessage("High volume integration ${i}")
            } else {
                PingMessage(i)
            }
            
            // 2. Core层序列化/反序列化
            let serialized = coreSerializer.serialize(message)
            let deserialized = coreSerializer.deserialize(serialized)
            
            // 3. Runtime层处理
            let envelope = Envelope(deserialized, Some("hvTester"))
            
            // 4. Foundation层存储
            @Assert(foundationQueue.enqueue(envelope))
            
            // 5. 从Foundation队列转移到Runtime邮箱
            match (foundationQueue.dequeue()) {
                case Some(queuedEnvelope) =>
                    @Assert(runtimeMailbox.enqueue(queuedEnvelope))
                case None => @Assert(false, "Foundation队列操作失败")
            }
            
            // 6. Runtime邮箱处理
            match (runtimeMailbox.dequeue()) {
                case Some(mailboxEnvelope) =>
                    let messageType = mailboxEnvelope.getMessage().messageType()
                    @Assert(messageType == "StringMessage" || messageType == "PingMessage")
                case None => @Assert(false, "Runtime邮箱操作失败")
            }
        }
        
        @Assert(foundationQueue.isEmpty())
        @Assert(runtimeMailbox.isEmpty())
        
        // 验证统计信息
        let queueStats = foundationQueue.getStats()
        let mailboxStats = runtimeMailbox.getStats()
        
        @Assert(queueStats.enqueueCount == iterations)
        @Assert(queueStats.dequeueCount == iterations)
        @Assert(queueStats.getSuccessRate() == 100.0)
        
        @Assert(mailboxStats.getEnqueued() == iterations)
        @Assert(mailboxStats.getDequeued() == iterations)
        @Assert(mailboxStats.getSuccessRate() == 100.0)
    }
}
