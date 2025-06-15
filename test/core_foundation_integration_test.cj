/*
 * Copyright (c) 2024. All rights reserved.
 * Core层与Foundation层集成测试
 * 验证Core层正确使用Foundation层组件
 */
package test

import std.unittest.*
import cactor.foundation.queue.{Queue, LockFreeQueue}
import cactor.foundation.serialization.SerializationManager
import cactor.foundation.network.{NetworkAddress, TcpTransport}
import cactor.foundation.memory.{StringPool, ByteArrayPool}
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
import cactor.core.message.{MessageSerializer, MessageSerializationManager}
import cactor.core.message.{NetworkMessage, NetworkMessageSerializer, NetworkMessageTransport}

/**
 * Core层消息序列化测试
 */
@Test
class CoreMessageSerializationTest {
    @Test
    func testMessageSerializer(): Unit {
        let serializer = MessageSerializer()
        
        // 测试StringMessage序列化
        let stringMsg = StringMessage("Hello Core Foundation")
        let serialized = serializer.serialize(stringMsg)
        let deserialized = serializer.deserialize(serialized)
        
        @Assert(deserialized.messageType() == "StringMessage")
        match (deserialized as StringMessage) {
            case Some(msg) => @Assert(msg.getContent() == "Hello Core Foundation")
            case None => @Assert(false, "反序列化失败")
        }
    }
    
    @Test
    func testPingPongSerialization(): Unit {
        let serializer = MessageSerializer()
        
        // 测试PingMessage
        let pingMsg = PingMessage(12345)
        let pingSerialized = serializer.serialize(pingMsg)
        let pingDeserialized = serializer.deserialize(pingSerialized)
        
        @Assert(pingDeserialized.messageType() == "PingMessage")
        match (pingDeserialized as PingMessage) {
            case Some(msg) => @Assert(msg.getId() == 12345)
            case None => @Assert(false, "PingMessage反序列化失败")
        }
        
        // 测试PongMessage
        let pongMsg = PongMessage(54321)
        let pongSerialized = serializer.serialize(pongMsg)
        let pongDeserialized = serializer.deserialize(pongSerialized)
        
        @Assert(pongDeserialized.messageType() == "PongMessage")
        match (pongDeserialized as PongMessage) {
            case Some(msg) => @Assert(msg.getOriginalId() == 54321)
            case None => @Assert(false, "PongMessage反序列化失败")
        }
    }
    
    @Test
    func testMessageSerializationManager(): Unit {
        let manager = MessageSerializationManager()
        
        let message = StringMessage("Manager Test")
        let serialized = manager.serialize(message)
        let deserialized = manager.deserialize(serialized)
        
        @Assert(deserialized.messageType() == "StringMessage")
        @Assert(manager.getSerializerName() == "MessageSerializer")
    }
}

/**
 * Core层网络消息测试
 */
@Test
class CoreNetworkMessageTest {
    @Test
    func testNetworkMessage(): Unit {
        let message = StringMessage("Network Test")
        let networkMsg = NetworkMessage("testActor", message, Some("senderActor"))
        
        @Assert(networkMsg.targetActor == "testActor")
        @Assert(networkMsg.message.messageType() == "StringMessage")
        match (networkMsg.sender) {
            case Some(sender) => @Assert(sender == "senderActor")
            case None => @Assert(false, "发送者应该存在")
        }
        @Assert(networkMsg.messageId.startsWith("msg_"))
        @Assert(networkMsg.timestamp > 0)
    }
    
    @Test
    func testNetworkMessageSerializer(): Unit {
        let serializer = NetworkMessageSerializer()
        let message = StringMessage("Network Serialization Test")
        let networkMsg = NetworkMessage("remoteActor", message, Some("localActor"))
        
        let serialized = serializer.serialize(networkMsg)
        let deserialized = serializer.deserialize(serialized)
        
        @Assert(deserialized.targetActor == "remoteActor")
        @Assert(deserialized.message.messageType() == "StringMessage")
        match (deserialized.sender) {
            case Some(sender) => @Assert(sender == "localActor")
            case None => @Assert(false, "发送者信息丢失")
        }
    }
    
    @Test
    func testNetworkMessageTransport(): Unit {
        let address = NetworkAddress("127.0.0.1", 9090)
        let tcpTransport = TcpTransport(address)
        let messageTransport = NetworkMessageTransport(tcpTransport)
        
        @Assert(!messageTransport.isActive())
        @Assert(messageTransport.getLocalAddress().host == "127.0.0.1")
        @Assert(messageTransport.getLocalAddress().port == 9090)
        
        // 设置消息处理器
        var receivedMessage: Option<NetworkMessage> = None
        messageTransport.setMessageHandler({ msg => receivedMessage = Some(msg) })
        
        // 启动和停止测试
        messageTransport.start()
        @Assert(messageTransport.isActive())
        
        messageTransport.stop()
        @Assert(!messageTransport.isActive())
    }
}

/**
 * Core层与Foundation层集成测试
 */
@Test
class CoreFoundationIntegrationTest {
    @Test
    func testMessageWithFoundationQueue(): Unit {
        let queue = LockFreeQueue<Message>(16)
        
        // 创建不同类型的消息
        let stringMsg = StringMessage("Queue Test")
        let pingMsg = PingMessage(999)
        let pongMsg = PongMessage(888)
        
        // 入队消息
        @Assert(queue.enqueue(stringMsg))
        @Assert(queue.enqueue(pingMsg))
        @Assert(queue.enqueue(pongMsg))
        
        @Assert(queue.size() == 3)
        
        // 出队并验证
        match (queue.dequeue()) {
            case Some(msg) => @Assert(msg.messageType() == "StringMessage")
            case None => @Assert(false, "队列不应该为空")
        }
        
        match (queue.dequeue()) {
            case Some(msg) => @Assert(msg.messageType() == "PingMessage")
            case None => @Assert(false, "队列不应该为空")
        }
        
        match (queue.dequeue()) {
            case Some(msg) => @Assert(msg.messageType() == "PongMessage")
            case None => @Assert(false, "队列不应该为空")
        }
        
        @Assert(queue.isEmpty())
    }
    
    @Test
    func testSerializationWithFoundationComponents(): Unit {
        let serializationManager = SerializationManager()
        let messageSerializer = MessageSerializer()
        
        // 测试消息序列化与Foundation序列化的配合
        let message = StringMessage("Foundation Integration")
        let messageBytes = messageSerializer.serialize(message)
        
        // 使用Foundation序列化管理器处理字节数据
        let processedBytes = serializationManager.serializeBytes(messageBytes)
        let recoveredBytes = serializationManager.deserializeBytes(processedBytes)
        
        // 反序列化消息
        let recoveredMessage = messageSerializer.deserialize(recoveredBytes)
        @Assert(recoveredMessage.messageType() == "StringMessage")
        
        match (recoveredMessage as StringMessage) {
            case Some(msg) => @Assert(msg.getContent() == "Foundation Integration")
            case None => @Assert(false, "消息恢复失败")
        }
    }
    
    @Test
    func testMemoryPoolWithMessages(): Unit {
        let stringPool = StringPool(5)
        let byteArrayPool = ByteArrayPool(3)
        
        // 从池中获取资源
        let pooledString = stringPool.acquire()
        let pooledByteArray = byteArrayPool.acquire()
        
        @Assert(pooledString.size >= 0)
        @Assert(pooledByteArray.size >= 0)
        
        // 创建消息并序列化
        let message = StringMessage("Pool Test")
        let serializer = MessageSerializer()
        let serializedData = serializer.serialize(message)
        
        @Assert(serializedData.size > 0)
        
        // 归还资源到池
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
 * Core层性能集成测试
 */
@Test
class CoreFoundationPerformanceTest {
    @Test
    func testMessageThroughputWithFoundation(): Unit {
        let queue = LockFreeQueue<Message>(1024)
        let serializer = MessageSerializer()
        let iterations = 100
        
        // 批量创建和处理消息
        let messages = ArrayList<Message>()
        for (i in 0..iterations) {
            messages.append(StringMessage("Message ${i}"))
        }
        
        // 测试入队性能
        for (message in messages) {
            @Assert(queue.enqueue(message))
        }
        
        @Assert(queue.size() == iterations)
        
        // 测试序列化性能
        var serializedCount = 0
        while (!queue.isEmpty()) {
            match (queue.dequeue()) {
                case Some(message) =>
                    let serialized = serializer.serialize(message)
                    @Assert(serialized.size > 0)
                    serializedCount += 1
                case None => break
            }
        }
        
        @Assert(serializedCount == iterations)
        @Assert(queue.isEmpty())
        
        let stats = queue.getStats()
        @Assert(stats.enqueueCount >= iterations)
        @Assert(stats.dequeueCount >= iterations)
        @Assert(stats.getSuccessRate() > 0.9)
    }
    
    @Test
    func testNetworkMessagePerformance(): Unit {
        let serializer = NetworkMessageSerializer()
        let iterations = 50
        
        // 批量创建网络消息
        let networkMessages = ArrayList<NetworkMessage>()
        for (i in 0..iterations) {
            let message = StringMessage("Network Performance Test ${i}")
            let networkMsg = NetworkMessage("actor${i}", message, Some("sender${i}"))
            networkMessages.append(networkMsg)
        }
        
        // 测试序列化性能
        var processedCount = 0
        for (networkMsg in networkMessages) {
            let serialized = serializer.serialize(networkMsg)
            let deserialized = serializer.deserialize(serialized)
            
            @Assert(deserialized.targetActor == networkMsg.targetActor)
            @Assert(deserialized.message.messageType() == networkMsg.message.messageType())
            processedCount += 1
        }
        
        @Assert(processedCount == iterations)
    }
}
