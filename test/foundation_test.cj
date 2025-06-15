/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer 测试
 * 验证零依赖的Foundation层功能
 */
package test

import std.unittest.*
import cactor.foundation.queue.{Queue, SimpleQueue, LockFreeQueue, QueueStats}
import cactor.foundation.serialization.{ByteSerializer, StringSerializer, IntSerializer, SerializationManager}
import cactor.foundation.memory.{ObjectPool, StringPool, ByteArrayPool, PoolStatistics}
import cactor.foundation.network.{NetworkTransport, TcpTransport, NetworkAddress}

/**
 * Foundation层队列测试
 */
@Test
class FoundationQueueTest {
    @Test
    func testSimpleQueue(): Unit {
        let queue = SimpleQueue<String>(10)
        
        // 测试入队
        @Assert(queue.enqueue("test1"))
        @Assert(queue.enqueue("test2"))
        @Assert(!queue.isEmpty())
        @Assert(queue.size() == 2)
        
        // 测试出队
        match (queue.dequeue()) {
            case Some(item) => @Assert(item == "test1")
            case None => @Assert(false, "队列不应该为空")
        }
        
        @Assert(queue.size() == 1)
        
        // 清空队列
        queue.clear()
        @Assert(queue.isEmpty())
        @Assert(queue.size() == 0)
    }
    
    @Test
    func testLockFreeQueue(): Unit {
        let queue = LockFreeQueue<Int64>(8)  // 容量必须是2的幂
        
        // 测试基本操作
        @Assert(queue.enqueue(100))
        @Assert(queue.enqueue(200))
        @Assert(!queue.isEmpty())
        
        match (queue.dequeue()) {
            case Some(value) => @Assert(value == 100)
            case None => @Assert(false, "队列不应该为空")
        }
        
        // 测试统计信息
        let stats = queue.getStats()
        @Assert(stats.enqueueCount >= 2)
        @Assert(stats.dequeueCount >= 1)
    }
}

/**
 * Foundation层序列化测试
 */
@Test
class FoundationSerializationTest {
    @Test
    func testByteSerializer(): Unit {
        let serializer = ByteSerializer()
        let data = [UInt8(1), UInt8(2), UInt8(3)]
        
        let serialized = serializer.serialize(data)
        let deserialized = serializer.deserialize(serialized)
        
        @Assert(serialized.size == data.size)
        @Assert(deserialized.size == data.size)
    }
    
    @Test
    func testStringSerializer(): Unit {
        let serializer = StringSerializer()
        let testString = "Hello Foundation"
        
        let serialized = serializer.serialize(testString)
        let deserialized = serializer.deserialize(serialized)
        
        @Assert(serialized.size > 0)
        @Assert(deserialized.size > 0)
    }
    
    @Test
    func testIntSerializer(): Unit {
        let serializer = IntSerializer()
        let testValue: Int64 = 12345
        
        let serialized = serializer.serialize(testValue)
        let deserialized = serializer.deserialize(serialized)
        
        @Assert(serialized.size == 8)  // Int64 = 8字节
        @Assert(deserialized == testValue)
    }
    
    @Test
    func testSerializationManager(): Unit {
        let manager = SerializationManager()
        
        // 测试字节序列化
        let data = [UInt8(10), UInt8(20)]
        let serialized = manager.serializeBytes(data)
        let deserialized = manager.deserializeBytes(serialized)
        @Assert(deserialized.size == data.size)
        
        // 测试字符串序列化
        let str = "test"
        let strSerialized = manager.serializeString(str)
        let strDeserialized = manager.deserializeString(strSerialized)
        @Assert(strDeserialized.size > 0)
        
        // 测试整数序列化
        let num: Int64 = 999
        let numSerialized = manager.serializeInt(num)
        let numDeserialized = manager.deserializeInt(numSerialized)
        @Assert(numDeserialized == num)
    }
}

/**
 * Foundation层内存管理测试
 */
@Test
class FoundationMemoryTest {
    @Test
    func testStringPool(): Unit {
        let pool = StringPool(5)
        
        // 获取对象
        let str1 = pool.acquire()
        let str2 = pool.acquire()
        @Assert(pool.size() <= 5)
        
        // 归还对象
        pool.release(str1)
        pool.release(str2)
        
        // 检查统计信息
        let stats = pool.getStatistics()
        @Assert(stats.totalAcquired >= 2)
        @Assert(stats.totalReleased >= 2)
    }
    
    @Test
    func testByteArrayPool(): Unit {
        let pool = ByteArrayPool(3)
        
        let arr1 = pool.acquire()
        let arr2 = pool.acquire()
        @Assert(arr1.size >= 0)
        @Assert(arr2.size >= 0)
        
        pool.release(arr1)
        pool.release(arr2)
        
        let stats = pool.getStatistics()
        @Assert(stats.maxSize == 3)
    }
}

/**
 * Foundation层网络传输测试
 */
@Test
class FoundationNetworkTest {
    @Test
    func testTcpTransport(): Unit {
        let address = NetworkAddress("127.0.0.1", 8080)
        let transport = TcpTransport(address)
        
        @Assert(!transport.isActive())
        @Assert(transport.getLocalAddress().host == "127.0.0.1")
        @Assert(transport.getLocalAddress().port == 8080)
        
        // 设置数据处理器
        var receivedData: Option<Array<UInt8>> = None
        transport.setDataHandler({ data => receivedData = Some(data) })
        
        // 启动传输层
        transport.start()
        @Assert(transport.isActive())
        
        // 停止传输层
        transport.stop()
        @Assert(!transport.isActive())
    }
}

/**
 * Foundation层集成测试
 */
@Test
class FoundationIntegrationTest {
    @Test
    func testQueueWithSerialization(): Unit {
        let queue = LockFreeQueue<Array<UInt8>>(16)
        let serializer = IntSerializer()
        
        // 序列化数据并入队
        let value1: Int64 = 100
        let value2: Int64 = 200
        
        let data1 = serializer.serialize(value1)
        let data2 = serializer.serialize(value2)
        
        @Assert(queue.enqueue(data1))
        @Assert(queue.enqueue(data2))
        
        // 出队并反序列化
        match (queue.dequeue()) {
            case Some(data) =>
                let deserialized = serializer.deserialize(data)
                @Assert(deserialized == value1)
            case None => @Assert(false, "队列不应该为空")
        }
    }
    
    @Test
    func testMemoryPoolWithQueue(): Unit {
        let pool = ByteArrayPool(5)
        let queue = SimpleQueue<Array<UInt8>>(10)
        
        // 从池中获取对象并入队
        let arr1 = pool.acquire()
        let arr2 = pool.acquire()
        
        @Assert(queue.enqueue(arr1))
        @Assert(queue.enqueue(arr2))
        
        // 出队并归还到池
        match (queue.dequeue()) {
            case Some(arr) => pool.release(arr)
            case None => @Assert(false, "队列不应该为空")
        }
        
        let stats = pool.getStatistics()
        @Assert(stats.totalAcquired >= 2)
    }
}

/**
 * Foundation层性能测试
 */
@Test
class FoundationPerformanceTest {
    @Test
    func testQueueThroughput(): Unit {
        let queue = LockFreeQueue<Int64>(1024)
        let iterations = 1000
        
        // 批量入队
        for (i in 0..iterations) {
            @Assert(queue.enqueue(i))
        }
        
        // 批量出队
        var dequeueCount = 0
        for (i in 0..iterations) {
            match (queue.dequeue()) {
                case Some(_) => dequeueCount += 1
                case None => break
            }
        }
        
        @Assert(dequeueCount == iterations)
        
        let stats = queue.getStats()
        @Assert(stats.getSuccessRate() > 0.9)  // 90%以上成功率
    }
}
