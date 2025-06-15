/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 2: 零拷贝消息优化测试套件
 * 验证共享内存缓冲区、高性能内存池和增强消息传递系统
 */
package cactor.integration.testing.zerocopy_phase2_test

import std.sync.*
import std.time.*
import std.collection.*
// import cactor.core.zerocopy.*

// 辅助函数
func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    return now.toUnixTimeStamp().toMilliseconds() * 1000000  // 转换为纳秒
}

func sleep(duration: Duration): Unit {
    // 简化的sleep实现
    let startTime = getCurrentTimeNanos()
    let sleepNanos = duration.toNanoseconds()
    while (getCurrentTimeNanos() - startTime < sleepNanos) {
        // 忙等待
    }
}

/**
 * 测试统计信息
 */
struct TestStats {
    public let totalMessages: Int64
    public let successfulMessages: Int64
    public let failedMessages: Int64
    public let avgLatency: Float64
    public let maxLatency: Int64
    public let minLatency: Int64
    public let throughput: Float64
    public let memoryEfficiency: Float64
    public let zeroCopyRatio: Float64
    
    public init(totalMessages: Int64, successfulMessages: Int64, failedMessages: Int64,
                avgLatency: Float64, maxLatency: Int64, minLatency: Int64,
                throughput: Float64, memoryEfficiency: Float64, zeroCopyRatio: Float64) {
        this.totalMessages = totalMessages
        this.successfulMessages = successfulMessages
        this.failedMessages = failedMessages
        this.avgLatency = avgLatency
        this.maxLatency = maxLatency
        this.minLatency = minLatency
        this.throughput = throughput
        this.memoryEfficiency = memoryEfficiency
        this.zeroCopyRatio = zeroCopyRatio
    }
    
    public func getSuccessRate(): Float64 {
        if (totalMessages > 0) {
            return Float64(successfulMessages) / Float64(totalMessages)
        }
        return 0.0
    }
}

/**
 * 共享内存缓冲区基础功能测试
 */
func testSharedMemoryBuffer(): Bool {
    println("=== 测试共享内存缓冲区 ===")
    
    let memoryPool = MemoryPoolFactory.createPool(1000)
    let bufferSize: UInt64 = 1024
    
    // 测试缓冲区分配
    let buffer = memoryPool.allocate(bufferSize)
    
    if (buffer.getSize() != bufferSize) {
        println("✗ 缓冲区大小不正确，期望${bufferSize}，实际${buffer.getSize()}")
        return false
    }
    
    if (!buffer.isValid()) {
        println("✗ 缓冲区应该有效")
        return false
    }
    
    if (buffer.getRefCount() != 1) {
        println("✗ 初始引用计数应该为1，实际${buffer.getRefCount()}")
        return false
    }
    
    // 测试引用计数
    buffer.retain()
    if (buffer.getRefCount() != 2) {
        println("✗ retain后引用计数应该为2，实际${buffer.getRefCount()}")
        return false
    }
    
    buffer.release()
    if (buffer.getRefCount() != 1) {
        println("✗ release后引用计数应该为1，实际${buffer.getRefCount()}")
        return false
    }
    
    // 测试数据访问
    let data = buffer.getData()
    if (data.size != Int64(bufferSize)) {
        println("✗ 数据数组大小不正确")
        return false
    }
    
    // 写入测试数据
    for (i in 0..data.size) {
        data[i] = UInt8(i % 256)
    }
    
    // 验证数据
    for (i in 0..data.size) {
        if (data[i] != UInt8(i % 256)) {
            println("✗ 数据验证失败，位置${i}")
            return false
        }
    }
    
    buffer.release()
    println("✓ 共享内存缓冲区测试通过")
    return true
}

/**
 * 高性能内存池测试
 */
func testHighPerformanceMemoryPool(): Bool {
    println("=== 测试高性能内存池 ===")
    
    let pool = MemoryPoolFactory.createHighThroughputPool()
    let testSizes: Array<UInt64> = [64, 128, 256, 512, 1024, 2048, 4096]
    let allocationsPerSize = 100
    
    var totalAllocations = 0
    let buffers = ArrayList<SharedMemoryBuffer>()
    
    // 测试不同大小的分配
    for (size in testSizes) {
        for (i in 0..allocationsPerSize) {
            let buffer = pool.allocate(size)
            
            if (buffer.getSize() < size) {
                println("✗ 分配的缓冲区大小不足，期望≥${size}，实际${buffer.getSize()}")
                return false
            }
            
            if (!buffer.isValid()) {
                println("✗ 分配的缓冲区无效")
                return false
            }
            
            buffers.append(buffer)
            totalAllocations += 1
        }
    }
    
    // 获取内存池统计
    let stats = pool.getStats()
    
    if (stats.totalAllocated == 0) {
        println("✗ 内存池统计显示没有分配")
        return false
    }
    
    if (stats.fragmentation > 0.5) {
        println("✗ 内存碎片率过高: ${stats.fragmentation * 100.0}%")
        return false
    }
    
    // 释放所有缓冲区
    for (buffer in buffers) {
        buffer.release()
    }
    
    println("✓ 高性能内存池测试通过")
    println("  - 总分配: ${totalAllocations}")
    println("  - 内存效率: ${(1.0 - stats.fragmentation) * 100.0}%")
    return true
}

/**
 * 增强零拷贝消息测试
 */
func testEnhancedZeroCopyMessage(): Bool {
    println("=== 测试增强零拷贝消息 ===")
    
    let memoryPool = MemoryPoolFactory.createLowLatencyPool()
    let factory = EnhancedMessageFactory(memoryPool)
    
    let messageType: UInt16 = 1001
    let sourceActor: UInt64 = 12345
    let targetActor: UInt64 = 67890
    let testData = "Hello, Zero-Copy World!".toArray()
    
    // 创建消息
    let message = factory.createMessageWithData(messageType, testData, sourceActor, targetActor)
    
    // 验证基本属性
    if (message.getSourceActor() != sourceActor) {
        println("✗ 源Actor ID不正确")
        return false
    }
    
    if (message.getTargetActor() != targetActor) {
        println("✗ 目标Actor ID不正确")
        return false
    }
    
    if (message.getPayloadSize() != UInt64(testData.size)) {
        println("✗ 负载大小不正确")
        return false
    }
    
    // 验证共享缓冲区
    let sharedBuffer = message.getSharedBuffer()
    if (!sharedBuffer.isValid()) {
        println("✗ 共享缓冲区无效")
        return false
    }
    
    // 验证数据内容
    let bufferData = sharedBuffer.getData()
    for (i in 0..testData.size) {
        if (bufferData[i] != testData[i]) {
            println("✗ 数据内容不匹配，位置${i}")
            return false
        }
    }
    
    // 测试引用计数
    let initialRefCount = message.getReferenceCount()
    message.retain()
    
    if (message.getReferenceCount() != initialRefCount + 1) {
        println("✗ 消息引用计数不正确")
        return false
    }
    
    // 测试时间戳和跳数
    let sendTime = getCurrentTimeNanos()
    message.setSendTimestamp(sendTime)
    
    if (message.getSendTimestamp() != sendTime) {
        println("✗ 发送时间戳不正确")
        return false
    }
    
    if (message.getHopCount() != 0) {
        println("✗ 初始跳数应该为0")
        return false
    }
    
    message.incrementHopCount()
    if (message.getHopCount() != 1) {
        println("✗ 跳数增加后应该为1")
        return false
    }
    
    message.release()
    message.release()  // 释放之前retain的引用
    
    println("✓ 增强零拷贝消息测试通过")
    return true
}

/**
 * 高性能消息传递测试
 */
func testHighPerformanceMessagePassing(): Bool {
    println("=== 测试高性能消息传递 ===")
    
    let memoryPool = MemoryPoolFactory.createHighThroughputPool()
    let messagePassing = HighPerformanceMessagePassing(10000, memoryPool)
    let factory = EnhancedMessageFactory(memoryPool)
    
    let messageCount = 5000
    let messageSize = 512
    let testData = Array<UInt8>(messageSize, { i => UInt8(i % 256) })
    
    let startTime = getCurrentTimeNanos()
    
    // 发送消息
    var sentCount = 0
    for (i in 0..messageCount) {
        let message = factory.createMessageWithData(1, testData, 1, 2)
        if (messagePassing.sendMessage(message, 2)) {
            sentCount += 1
        }
    }
    
    // 接收消息
    var receivedCount = 0
    var totalLatency: Int64 = 0
    var maxLatency: Int64 = 0
    var minLatency: Int64 = 9223372036854775807  // Int64最大值
    
    while (receivedCount < sentCount) {
        match (messagePassing.receiveMessage()) {
            case Some(message) =>
                let latency = getCurrentTimeNanos() - message.getSendTimestamp()
                totalLatency += latency
                if (latency > maxLatency) {
                    maxLatency = latency
                }
                if (latency < minLatency) {
                    minLatency = latency
                }
                receivedCount += 1
                message.release()
            case None =>
                sleep(Duration.microsecond)
        }
    }
    
    let endTime = getCurrentTimeNanos()
    let elapsedTime = endTime - startTime
    let throughput = Float64(messageCount) / (Float64(elapsedTime) / 1_000_000_000.0)
    let avgLatency = Float64(totalLatency) / Float64(receivedCount)
    
    // 获取统计信息
    let latencyStats = messagePassing.getLatencyStats()
    let memoryStats = messagePassing.getMemoryUsage()
    let zeroCopyRatio = messagePassing.getZeroCopyRatio()
    
    println("  - 发送消息: ${sentCount}")
    println("  - 接收消息: ${receivedCount}")
    println("  - 吞吐量: ${throughput} msg/s")
    println("  - 平均延迟: ${avgLatency / 1000.0}μs")
    println("  - 最大延迟: ${Float64(maxLatency) / 1000.0}μs")
    println("  - 最小延迟: ${Float64(minLatency) / 1000.0}μs")
    println("  - 零拷贝比率: ${zeroCopyRatio * 100.0}%")
    println("  - 内存效率: ${memoryStats.poolEfficiency * 100.0}%")
    
    // 验证性能目标
    if (throughput < 10000.0) {
        println("✗ 吞吐量应该超过10K msg/s，实际${throughput}")
        return false
    }
    
    if (avgLatency / 1000.0 > 100.0) {
        println("✗ 平均延迟应该小于100μs，实际${avgLatency / 1000.0}μs")
        return false
    }
    
    if (zeroCopyRatio < 0.8) {
        println("✗ 零拷贝比率应该超过80%，实际${zeroCopyRatio * 100.0}%")
        return false
    }
    
    if (memoryStats.poolEfficiency < 0.7) {
        println("✗ 内存效率应该超过70%，实际${memoryStats.poolEfficiency * 100.0}%")
        return false
    }
    
    println("✓ 高性能消息传递测试通过")
    return true
}

/**
 * 内存池性能基准测试
 */
func testMemoryPoolPerformance(): Bool {
    println("=== 测试内存池性能基准 ===")

    let pool = MemoryPoolFactory.createHighThroughputPool()
    let allocationCount = 10000
    let testSizes: Array<UInt64> = [64, 256, 1024, 4096]

    for (size in testSizes) {
        let buffers = ArrayList<SharedMemoryBuffer>()

        // 分配性能测试
        let allocStartTime = getCurrentTimeNanos()
        for (i in 0..allocationCount) {
            let buffer = pool.allocate(size)
            buffers.append(buffer)
        }
        let allocEndTime = getCurrentTimeNanos()

        // 释放性能测试
        let deallocStartTime = getCurrentTimeNanos()
        for (buffer in buffers) {
            buffer.release()
        }
        let deallocEndTime = getCurrentTimeNanos()

        let allocTime = allocEndTime - allocStartTime
        let deallocTime = deallocEndTime - deallocStartTime
        let allocThroughput = Float64(allocationCount) / (Float64(allocTime) / 1_000_000_000.0)
        let deallocThroughput = Float64(allocationCount) / (Float64(deallocTime) / 1_000_000_000.0)

        println("  大小${size}字节:")
        println("    - 分配吞吐量: ${allocThroughput} ops/s")
        println("    - 释放吞吐量: ${deallocThroughput} ops/s")

        // 验证性能目标
        if (allocThroughput < 100000.0) {
            println("✗ 分配吞吐量应该超过100K ops/s")
            return false
        }

        if (deallocThroughput < 100000.0) {
            println("✗ 释放吞吐量应该超过100K ops/s")
            return false
        }
    }

    println("✓ 内存池性能基准测试通过")
    return true
}

/**
 * 并发安全测试
 */
func testConcurrentSafety(): Bool {
    println("=== 测试并发安全性 ===")

    let memoryPool = MemoryPoolFactory.createHighThroughputPool()
    let messagePassing = HighPerformanceMessagePassing(20000, memoryPool)
    let factory = EnhancedMessageFactory(memoryPool)

    let threadCount = 4
    let messagesPerThread = 1000
    let messageSize = 256

    let successCount = AtomicInt64(0)
    let errorCount = AtomicInt64(0)
    let testData = Array<UInt8>(messageSize, { i => UInt8(i % 256) })

    let startTime = getCurrentTimeNanos()

    // 启动多个生产者线程
    for (threadId in 0..threadCount) {
        spawn {
            for (i in 0..messagesPerThread) {
                try {
                    let message = factory.createMessageWithData(
                        UInt16(threadId),
                        testData,
                        UInt64(threadId),
                        UInt64(threadId + 1000)
                    )

                    if (messagePassing.sendMessage(message, UInt64(threadId + 1000))) {
                        successCount.fetchAdd(1)
                    } else {
                        errorCount.fetchAdd(1)
                    }
                } catch (e: Exception) {
                    errorCount.fetchAdd(1)
                    println("生产者线程${threadId}异常: ${e}")
                }
            }
        }
    }

    // 启动多个消费者线程
    let receivedCount = AtomicInt64(0)
    for (threadId in 0..threadCount) {
        spawn {
            while (receivedCount.load() < Int64(threadCount * messagesPerThread)) {
                match (messagePassing.receiveMessage()) {
                    case Some(message) =>
                        receivedCount.fetchAdd(1)
                        message.release()
                    case None =>
                        sleep(Duration.microsecond)
                }
            }
        }
    }

    // 等待所有线程完成
    while (receivedCount.load() < Int64(threadCount * messagesPerThread)) {
        sleep(Duration.millisecond * 10)
    }

    let endTime = getCurrentTimeNanos()
    let elapsedTime = endTime - startTime
    let totalMessages = threadCount * messagesPerThread
    let throughput = Float64(totalMessages) / (Float64(elapsedTime) / 1_000_000_000.0)

    println("  - 线程数: ${threadCount}")
    println("  - 每线程消息数: ${messagesPerThread}")
    println("  - 总消息数: ${totalMessages}")
    println("  - 成功消息: ${successCount.load()}")
    println("  - 失败消息: ${errorCount.load()}")
    println("  - 接收消息: ${receivedCount.load()}")
    println("  - 并发吞吐量: ${throughput} msg/s")

    // 验证并发安全性
    if (errorCount.load() > 0) {
        println("✗ 存在错误，并发安全性测试失败")
        return false
    }

    if (receivedCount.load() != Int64(totalMessages)) {
        println("✗ 接收消息数不匹配，期望${totalMessages}，实际${receivedCount.load()}")
        return false
    }

    if (throughput < 50000.0) {
        println("✗ 并发吞吐量应该超过50K msg/s，实际${throughput}")
        return false
    }

    println("✓ 并发安全测试通过")
    return true
}

/**
 * 主测试函数
 */
main(): Int64 {
    println("=== CActor Phase 2: 零拷贝消息优化测试套件 ===")

    var allPassed = true

    try {
        allPassed = allPassed && testSharedMemoryBuffer()
        allPassed = allPassed && testHighPerformanceMemoryPool()
        allPassed = allPassed && testEnhancedZeroCopyMessage()
        allPassed = allPassed && testHighPerformanceMessagePassing()
        allPassed = allPassed && testMemoryPoolPerformance()
        allPassed = allPassed && testConcurrentSafety()

        if (allPassed) {
            println("\n🎉 所有Phase 2零拷贝优化测试通过！")
            println("✓ 共享内存缓冲区功能正常")
            println("✓ 高性能内存池运行良好")
            println("✓ 增强零拷贝消息系统可靠")
            println("✓ 消息传递性能达标")
            println("✓ 内存池性能优异")
            println("✓ 并发安全性验证通过")
            println("\n这验证了Phase 2零拷贝消息优化的高性能和可靠性！")
            println("🚀 准备进入Phase 3: 高性能调度器优化")
            return 0
        } else {
            println("\n❌ 部分Phase 2测试失败")
            return 1
        }

    } catch (e: Exception) {
        println("❌ Phase 2测试失败: ${e}")
        return 1
    }
}
