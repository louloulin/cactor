/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 7.0 功能完整性测试
 * 验证重构后的CActor系统功能完整性
 */
package test

import std.unittest.*
import std.collection.*
import cactor.foundation.queue.{Queue, LockFreeQueue, SimpleQueue}
import cactor.foundation.serialization.SerializationManager
import cactor.foundation.network.{NetworkAddress, TcpTransport}
import cactor.foundation.memory.{StringPool, ByteArrayPool}
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage, Envelope}
import cactor.core.message.{MessageSerializer, NetworkMessage, NetworkMessageSerializer}
import cactor.core.actor.{Actor, ActorLifecycleState}
import cactor.runtime.mailbox.{Mailbox, FoundationMailbox}

/**
 * Foundation层功能测试
 */
@Test
class FoundationFunctionalityTest {
    @Test
    func testQueueFunctionality(): Unit {
        // 测试LockFreeQueue
        let lockFreeQueue = LockFreeQueue<String>(8)
        @Assert(lockFreeQueue.isEmpty())
        @Assert(lockFreeQueue.capacity() == 8)
        
        @Assert(lockFreeQueue.enqueue("test1"))
        @Assert(lockFreeQueue.enqueue("test2"))
        @Assert(lockFreeQueue.size() == 2)
        @Assert(!lockFreeQueue.isEmpty())
        
        match (lockFreeQueue.dequeue()) {
            case Some(item) => @Assert(item == "test1")
            case None => @Assert(false, "队列不应该为空")
        }
        
        // 测试SimpleQueue
        let simpleQueue = SimpleQueue<Int64>(4)
        @Assert(simpleQueue.enqueue(100))
        @Assert(simpleQueue.enqueue(200))
        
        match (simpleQueue.dequeue()) {
            case Some(value) => @Assert(value == 100)
            case None => @Assert(false, "队列不应该为空")
        }
    }
    
    @Test
    func testSerializationFunctionality(): Unit {
        let manager = SerializationManager()
        
        // 测试字符串序列化
        let testString = "Foundation Serialization Test"
        let serializedString = manager.serializeString(testString)
        let deserializedString = manager.deserializeString(serializedString)
        @Assert(deserializedString == testString)
        
        // 测试整数序列化
        let testInt: Int64 = 12345
        let serializedInt = manager.serializeInt(testInt)
        let deserializedInt = manager.deserializeInt(serializedInt)
        @Assert(deserializedInt == testInt)
        
        // 测试字节数组序列化
        let testBytes = Array<UInt8>([1, 2, 3, 4, 5])
        let serializedBytes = manager.serializeBytes(testBytes)
        let deserializedBytes = manager.deserializeBytes(serializedBytes)
        @Assert(deserializedBytes.size == testBytes.size)
    }
    
    @Test
    func testNetworkFunctionality(): Unit {
        let address = NetworkAddress("127.0.0.1", 8080)
        @Assert(address.host == "127.0.0.1")
        @Assert(address.port == 8080)
        
        let transport = TcpTransport(address)
        @Assert(!transport.isActive())
        @Assert(transport.getLocalAddress().host == "127.0.0.1")
        @Assert(transport.getLocalAddress().port == 8080)
    }
    
    @Test
    func testMemoryPoolFunctionality(): Unit {
        let stringPool = StringPool(3)
        let byteArrayPool = ByteArrayPool(2)
        
        // 测试字符串池
        let pooledString1 = stringPool.acquire()
        let pooledString2 = stringPool.acquire()
        @Assert(pooledString1.size >= 0)
        @Assert(pooledString2.size >= 0)
        
        stringPool.release(pooledString1)
        stringPool.release(pooledString2)
        
        let stats = stringPool.getStatistics()
        @Assert(stats.totalAcquired >= 2)
        @Assert(stats.totalReleased >= 2)
        
        // 测试字节数组池
        let pooledArray1 = byteArrayPool.acquire()
        let pooledArray2 = byteArrayPool.acquire()
        @Assert(pooledArray1.size >= 0)
        @Assert(pooledArray2.size >= 0)
        
        byteArrayPool.release(pooledArray1)
        byteArrayPool.release(pooledArray2)
    }
}

/**
 * Core层功能测试
 */
@Test
class CoreFunctionalityTest {
    @Test
    func testMessageFunctionality(): Unit {
        // 测试StringMessage
        let stringMsg = StringMessage("Core Test Message")
        @Assert(stringMsg.messageType() == "StringMessage")
        @Assert(stringMsg.getContent() == "Core Test Message")
        @Assert(stringMsg.priority() == 0)  // 用户消息默认优先级
        
        // 测试PingMessage
        let pingMsg = PingMessage(999)
        @Assert(pingMsg.messageType() == "PingMessage")
        @Assert(pingMsg.getId() == 999)
        @Assert(pingMsg.timestamp() > 0)
        
        // 测试PongMessage
        let pongMsg = PongMessage(888)
        @Assert(pongMsg.messageType() == "PongMessage")
        @Assert(pongMsg.getOriginalId() == 888)
        
        // 测试Envelope
        let envelope = Envelope(stringMsg, Some("testSender"))
        @Assert(envelope.getMessage().messageType() == "StringMessage")
        match (envelope.getSender()) {
            case Some(sender) => @Assert(sender == "testSender")
            case None => @Assert(false, "发送者应该存在")
        }
        @Assert(envelope.getTimestamp() > 0)
    }
    
    @Test
    func testMessageSerializationFunctionality(): Unit {
        let serializer = MessageSerializer()
        
        // 测试StringMessage序列化
        let stringMsg = StringMessage("Serialization Test")
        let serialized = serializer.serialize(stringMsg)
        let deserialized = serializer.deserialize(serialized)
        
        @Assert(deserialized.messageType() == "StringMessage")
        match (deserialized as StringMessage) {
            case Some(msg) => @Assert(msg.getContent() == "Serialization Test")
            case None => @Assert(false, "反序列化失败")
        }
        
        // 测试PingMessage序列化
        let pingMsg = PingMessage(777)
        let pingSerialized = serializer.serialize(pingMsg)
        let pingDeserialized = serializer.deserialize(pingSerialized)
        
        @Assert(pingDeserialized.messageType() == "PingMessage")
        match (pingDeserialized as PingMessage) {
            case Some(msg) => @Assert(msg.getId() == 777)
            case None => @Assert(false, "PingMessage反序列化失败")
        }
    }
    
    @Test
    func testNetworkMessageFunctionality(): Unit {
        let message = StringMessage("Network Test")
        let networkMsg = NetworkMessage("targetActor", message, Some("senderActor"))
        
        @Assert(networkMsg.targetActor == "targetActor")
        @Assert(networkMsg.message.messageType() == "StringMessage")
        match (networkMsg.sender) {
            case Some(sender) => @Assert(sender == "senderActor")
            case None => @Assert(false, "发送者应该存在")
        }
        @Assert(networkMsg.messageId.startsWith("msg_"))
        
        // 测试网络消息序列化
        let networkSerializer = NetworkMessageSerializer()
        let serialized = networkSerializer.serialize(networkMsg)
        let deserialized = networkSerializer.deserialize(serialized)
        
        @Assert(deserialized.targetActor == "targetActor")
        @Assert(deserialized.message.messageType() == "StringMessage")
    }
    
    @Test
    func testActorLifecycleFunctionality(): Unit {
        // 测试Actor生命周期状态
        let created = ActorLifecycleState.Created
        let running = ActorLifecycleState.Running
        let stopped = ActorLifecycleState.Stopped
        
        @Assert(created.toInt64() == 0)
        @Assert(running.toInt64() == 2)
        @Assert(stopped.toInt64() == 4)
        
        @Assert(ActorLifecycleState.fromInt64(0) == ActorLifecycleState.Created)
        @Assert(ActorLifecycleState.fromInt64(2) == ActorLifecycleState.Running)
        @Assert(ActorLifecycleState.fromInt64(4) == ActorLifecycleState.Stopped)
    }
}

/**
 * Runtime层功能测试
 */
@Test
class RuntimeFunctionalityTest {
    @Test
    func testMailboxFunctionality(): Unit {
        let mailbox = FoundationMailbox(16)
        
        @Assert(mailbox.isEmpty())
        @Assert(mailbox.size() == 0)
        @Assert(mailbox.capacity() == 16)
        @Assert(!mailbox.isClosed())
        
        // 创建测试消息
        let message = StringMessage("Mailbox Test")
        let envelope = Envelope(message, Some("testSender"))
        
        // 测试入队
        @Assert(mailbox.enqueue(envelope))
        @Assert(!mailbox.isEmpty())
        @Assert(mailbox.size() == 1)
        
        // 测试出队
        match (mailbox.dequeue()) {
            case Some(dequeued) =>
                @Assert(dequeued.getMessage().messageType() == "StringMessage")
                match (dequeued.getMessage() as StringMessage) {
                    case Some(msg) => @Assert(msg.getContent() == "Mailbox Test")
                    case None => @Assert(false, "消息类型转换失败")
                }
            case None => @Assert(false, "邮箱不应该为空")
        }
        
        @Assert(mailbox.isEmpty())
        @Assert(mailbox.size() == 0)
        
        // 测试关闭功能
        mailbox.close()
        @Assert(mailbox.isClosed())
        @Assert(!mailbox.enqueue(envelope))  // 关闭后不能入队
    }
    
    @Test
    func testMailboxStatsFunctionality(): Unit {
        let mailbox = FoundationMailbox(8, true)  // 高性能邮箱
        @Assert(mailbox.getMailboxType() == "LockFree")
        
        // 添加一些消息
        for (i in 0..3) {
            let message = PingMessage(i)
            let envelope = Envelope(message, None)
            @Assert(mailbox.enqueue(envelope))
        }
        
        let stats = mailbox.getStats()
        @Assert(stats.getEnqueued() == 3)
        @Assert(stats.getDequeued() == 0)
        @Assert(stats.getDropped() == 0)
        
        // 出队一个消息
        mailbox.dequeue()
        
        let updatedStats = mailbox.getStats()
        @Assert(updatedStats.getEnqueued() == 3)
        @Assert(updatedStats.getDequeued() == 1)
        
        // 测试性能指标
        let metrics = mailbox.getPerformanceMetrics()
        @Assert(metrics.isHighPerformance())
        @Assert(metrics.getUtilization() > 0.0)
    }
}

/**
 * 集成功能测试
 */
@Test
class IntegrationFunctionalityTest {
    @Test
    func testFoundationCoreIntegration(): Unit {
        // 测试Foundation队列与Core消息的集成
        let queue = LockFreeQueue<Message>(8)
        
        let stringMsg = StringMessage("Integration Test")
        let pingMsg = PingMessage(123)
        
        @Assert(queue.enqueue(stringMsg))
        @Assert(queue.enqueue(pingMsg))
        @Assert(queue.size() == 2)
        
        match (queue.dequeue()) {
            case Some(msg) => @Assert(msg.messageType() == "StringMessage")
            case None => @Assert(false, "队列不应该为空")
        }
        
        match (queue.dequeue()) {
            case Some(msg) => @Assert(msg.messageType() == "PingMessage")
            case None => @Assert(false, "队列不应该为空")
        }
    }
    
    @Test
    func testCoreRuntimeIntegration(): Unit {
        // 测试Core消息与Runtime邮箱的集成
        let mailbox = FoundationMailbox(4)
        
        let messages = ArrayList<Message>()
        messages.append(StringMessage("Message 1"))
        messages.append(PingMessage(100))
        messages.append(PongMessage(200))
        
        // 将消息包装成信封并入队
        for (message in messages) {
            let envelope = Envelope(message, Some("integrationSender"))
            @Assert(mailbox.enqueue(envelope))
        }
        
        @Assert(mailbox.size() == 3)
        
        // 验证出队的消息类型
        let expectedTypes = ["StringMessage", "PingMessage", "PongMessage"]
        var index = 0
        
        while (!mailbox.isEmpty() && index < expectedTypes.size) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    @Assert(envelope.getMessage().messageType() == expectedTypes[index])
                    index += 1
                case None => break
            }
        }
        
        @Assert(index == 3)  // 确保所有消息都被处理
    }
    
    @Test
    func testEndToEndMessageFlow(): Unit {
        // 端到端消息流测试
        let serializer = MessageSerializer()
        let mailbox = FoundationMailbox(16)
        
        // 1. 创建消息
        let originalMessage = StringMessage("End-to-End Test")
        
        // 2. 序列化消息
        let serializedData = serializer.serialize(originalMessage)
        
        // 3. 反序列化消息
        let deserializedMessage = serializer.deserialize(serializedData)
        
        // 4. 包装成信封
        let envelope = Envelope(deserializedMessage, Some("e2eSender"))
        
        // 5. 入队到邮箱
        @Assert(mailbox.enqueue(envelope))
        
        // 6. 从邮箱出队
        match (mailbox.dequeue()) {
            case Some(processedEnvelope) =>
                @Assert(processedEnvelope.getMessage().messageType() == "StringMessage")
                match (processedEnvelope.getMessage() as StringMessage) {
                    case Some(msg) => @Assert(msg.getContent() == "End-to-End Test")
                    case None => @Assert(false, "端到端消息流失败")
                }
                match (processedEnvelope.getSender()) {
                    case Some(sender) => @Assert(sender == "e2eSender")
                    case None => @Assert(false, "发送者信息丢失")
                }
            case None => @Assert(false, "邮箱不应该为空")
        }
        
        @Assert(mailbox.isEmpty())
    }
}
