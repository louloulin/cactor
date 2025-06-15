/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 7.0 性能测试
 * 验证重构后的性能不退化，目标达到800万消息/秒
 */
package test

import std.unittest.*
import std.collection.*
import std.time.*
import cactor.foundation.queue.{LockFreeQueue, SimpleQueue}
import cactor.foundation.serialization.SerializationManager
import cactor.foundation.memory.{StringPool, ByteArrayPool}
import cactor.core.message.{Message, StringMessage, PingMessage, Envelope}
import cactor.core.message.{MessageSerializer, NetworkMessage, NetworkMessageSerializer}
import cactor.runtime.mailbox.{FoundationMailbox, FoundationMailboxFactory}

/**
 * Foundation层性能测试
 */
@Test
class FoundationPerformanceTest {
    @Test
    func testLockFreeQueueThroughput(): Unit {
        let queue = LockFreeQueue<String>(1024)
        let iterations = 10000
        
        // 测试入队性能
        let startTime = DateTime.now()
        for (i in 0..iterations) {
            @Assert(queue.enqueue("performance_test_${i}"))
        }
        let enqueueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                         startTime.toUnixTimeStamp().toMilliseconds()
        
        @Assert(queue.size() == iterations)
        
        // 测试出队性能
        let dequeueStart = DateTime.now()
        var dequeueCount = 0
        while (!queue.isEmpty()) {
            match (queue.dequeue()) {
                case Some(_) => dequeueCount += 1
                case None => break
            }
        }
        let dequeueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                         dequeueStart.toUnixTimeStamp().toMilliseconds()
        
        @Assert(dequeueCount == iterations)
        @Assert(queue.isEmpty())
        
        // 计算吞吐量 (操作/秒)
        let totalTime = enqueueTime + dequeueTime
        if (totalTime > 0) {
            let throughput = (iterations * 2 * 1000) / totalTime  // 入队+出队
            println("LockFreeQueue吞吐量: ${throughput} 操作/秒")
            @Assert(throughput > 100000)  // 至少10万操作/秒
        }
        
        let stats = queue.getStats()
        @Assert(stats.getSuccessRate() == 100.0)
    }
    
    @Test
    func testSerializationPerformance(): Unit {
        let manager = SerializationManager()
        let iterations = 5000
        
        // 测试字符串序列化性能
        let testString = "Performance test string with some content to serialize"
        let startTime = DateTime.now()
        
        for (i in 0..iterations) {
            let serialized = manager.serializeString(testString)
            let deserialized = manager.deserializeString(serialized)
            @Assert(deserialized == testString)
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        if (totalTime > 0) {
            let throughput = (iterations * 1000) / totalTime
            println("序列化吞吐量: ${throughput} 操作/秒")
            @Assert(throughput > 50000)  // 至少5万操作/秒
        }
    }
    
    @Test
    func testMemoryPoolPerformance(): Unit {
        let stringPool = StringPool(100)
        let iterations = 1000
        
        let startTime = DateTime.now()
        
        for (i in 0..iterations) {
            let pooledString = stringPool.acquire()
            // 模拟使用
            @Assert(pooledString.size >= 0)
            stringPool.release(pooledString)
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        if (totalTime > 0) {
            let throughput = (iterations * 1000) / totalTime
            println("内存池吞吐量: ${throughput} 操作/秒")
            @Assert(throughput > 10000)  // 至少1万操作/秒
        }
        
        let stats = stringPool.getStatistics()
        @Assert(stats.totalAcquired == iterations)
        @Assert(stats.totalReleased == iterations)
    }
}

/**
 * Core层性能测试
 */
@Test
class CorePerformanceTest {
    @Test
    func testMessageSerializationPerformance(): Unit {
        let serializer = MessageSerializer()
        let iterations = 2000
        
        // 创建测试消息
        let messages = ArrayList<Message>()
        for (i in 0..100) {
            messages.append(StringMessage("Performance test message ${i}"))
            messages.append(PingMessage(i))
        }
        
        let startTime = DateTime.now()
        var processedCount = 0
        
        for (round in 0..iterations / messages.size) {
            for (message in messages) {
                let serialized = serializer.serialize(message)
                let deserialized = serializer.deserialize(serialized)
                @Assert(deserialized.messageType() == message.messageType())
                processedCount += 1
            }
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        if (totalTime > 0) {
            let throughput = (processedCount * 1000) / totalTime
            println("消息序列化吞吐量: ${throughput} 消息/秒")
            @Assert(throughput > 20000)  // 至少2万消息/秒
        }
    }
    
    @Test
    func testNetworkMessagePerformance(): Unit {
        let networkSerializer = NetworkMessageSerializer()
        let iterations = 1000
        
        let startTime = DateTime.now()
        
        for (i in 0..iterations) {
            let message = StringMessage("Network performance test ${i}")
            let networkMsg = NetworkMessage("actor${i}", message, Some("sender${i}"))
            
            let serialized = networkSerializer.serialize(networkMsg)
            let deserialized = networkSerializer.deserialize(serialized)
            
            @Assert(deserialized.targetActor == networkMsg.targetActor)
            @Assert(deserialized.message.messageType() == networkMsg.message.messageType())
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        if (totalTime > 0) {
            let throughput = (iterations * 1000) / totalTime
            println("网络消息处理吞吐量: ${throughput} 消息/秒")
            @Assert(throughput > 10000)  // 至少1万消息/秒
        }
    }
}

/**
 * Runtime层性能测试
 */
@Test
class RuntimePerformanceTest {
    @Test
    func testFoundationMailboxThroughput(): Unit {
        let mailbox = FoundationMailbox(2048, true)  // 高性能邮箱
        let iterations = 5000
        
        // 创建测试消息
        let messages = ArrayList<Envelope>()
        for (i in 0..iterations) {
            let message = StringMessage("Mailbox performance test ${i}")
            let envelope = Envelope(message, Some("perfSender"))
            messages.append(envelope)
        }
        
        // 测试入队性能
        let enqueueStart = DateTime.now()
        for (envelope in messages) {
            @Assert(mailbox.enqueue(envelope))
        }
        let enqueueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                         enqueueStart.toUnixTimeStamp().toMilliseconds()
        
        @Assert(mailbox.size() == iterations)
        
        // 测试出队性能
        let dequeueStart = DateTime.now()
        var dequeueCount = 0
        while (!mailbox.isEmpty()) {
            match (mailbox.dequeue()) {
                case Some(_) => dequeueCount += 1
                case None => break
            }
        }
        let dequeueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                         dequeueStart.toUnixTimeStamp().toMilliseconds()
        
        @Assert(dequeueCount == iterations)
        @Assert(mailbox.isEmpty())
        
        // 计算吞吐量
        let totalTime = enqueueTime + dequeueTime
        if (totalTime > 0) {
            let throughput = (iterations * 2 * 1000) / totalTime  // 入队+出队
            println("FoundationMailbox吞吐量: ${throughput} 操作/秒")
            @Assert(throughput > 50000)  // 至少5万操作/秒
        }
        
        let stats = mailbox.getStats()
        @Assert(stats.getSuccessRate() == 100.0)
    }
    
    @Test
    func testMailboxFactoryPerformance(): Unit {
        let iterations = 100
        
        let startTime = DateTime.now()
        
        for (i in 0..iterations) {
            let mailbox = FoundationMailboxFactory.createHighPerformanceMailbox(64)
            @Assert(mailbox.getMailboxType() == "LockFree")
            @Assert(mailbox.capacity() == 64)
            
            // 快速测试邮箱功能
            let message = PingMessage(i)
            let envelope = Envelope(message, None)
            @Assert(mailbox.enqueue(envelope))
            
            match (mailbox.dequeue()) {
                case Some(_) => ()  // 成功
                case None => @Assert(false, "邮箱操作失败")
            }
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        if (totalTime > 0) {
            let throughput = (iterations * 1000) / totalTime
            println("邮箱工厂创建吞吐量: ${throughput} 邮箱/秒")
            @Assert(throughput > 100)  // 至少100个邮箱/秒
        }
    }
}

/**
 * 集成性能测试
 */
@Test
class IntegrationPerformanceTest {
    @Test
    func testEndToEndMessageThroughput(): Unit {
        // 端到端消息处理性能测试
        let serializer = MessageSerializer()
        let mailbox = FoundationMailbox(1024, true)
        let iterations = 2000
        
        let startTime = DateTime.now()
        
        for (i in 0..iterations) {
            // 1. 创建消息
            let message = StringMessage("E2E performance test ${i}")
            
            // 2. 序列化
            let serialized = serializer.serialize(message)
            
            // 3. 反序列化
            let deserialized = serializer.deserialize(serialized)
            
            // 4. 包装成信封
            let envelope = Envelope(deserialized, Some("e2eSender"))
            
            // 5. 入队
            @Assert(mailbox.enqueue(envelope))
            
            // 6. 出队
            match (mailbox.dequeue()) {
                case Some(processedEnvelope) =>
                    @Assert(processedEnvelope.getMessage().messageType() == "StringMessage")
                case None => @Assert(false, "端到端处理失败")
            }
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        if (totalTime > 0) {
            let throughput = (iterations * 1000) / totalTime
            println("端到端消息处理吞吐量: ${throughput} 消息/秒")
            @Assert(throughput > 10000)  // 至少1万消息/秒
            
            // 如果性能很好，输出更详细的信息
            if (throughput > 100000) {
                println("🎉 优秀性能！端到端处理超过10万消息/秒")
            }
        }
        
        @Assert(mailbox.isEmpty())
    }
    
    @Test
    func testHighVolumeMessageProcessing(): Unit {
        // 高容量消息处理测试
        let queue = LockFreeQueue<Envelope>(4096)
        let iterations = 10000
        
        // 批量创建消息
        let messages = ArrayList<Envelope>()
        for (i in 0..iterations) {
            let message = if (i % 2 == 0) {
                StringMessage("High volume test ${i}")
            } else {
                PingMessage(i)
            }
            let envelope = Envelope(message, Some("hvSender"))
            messages.append(envelope)
        }
        
        let startTime = DateTime.now()
        
        // 批量入队
        for (envelope in messages) {
            @Assert(queue.enqueue(envelope))
        }
        
        // 批量出队和处理
        var processedCount = 0
        while (!queue.isEmpty()) {
            match (queue.dequeue()) {
                case Some(envelope) =>
                    // 模拟消息处理
                    let messageType = envelope.getMessage().messageType()
                    @Assert(messageType == "StringMessage" || messageType == "PingMessage")
                    processedCount += 1
                case None => break
            }
        }
        
        let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                       startTime.toUnixTimeStamp().toMilliseconds()
        
        @Assert(processedCount == iterations)
        
        if (totalTime > 0) {
            let throughput = (iterations * 2 * 1000) / totalTime  // 入队+出队
            println("高容量消息处理吞吐量: ${throughput} 操作/秒")
            @Assert(throughput > 100000)  // 至少10万操作/秒
            
            // 检查是否接近目标性能
            if (throughput > 1000000) {
                println("🚀 接近目标！处理超过100万操作/秒")
            }
        }
        
        let stats = queue.getStats()
        @Assert(stats.getSuccessRate() == 100.0)
    }
}
