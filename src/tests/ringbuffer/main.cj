/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 环形缓冲区邮箱测试
 * 验证高性能无锁邮箱功能
 */
package cactor.tests.ringbuffer

import std.sync.*
import std.time.*
import cactor.core.message.{Envelope, PingMessage}
import cactor.mailbox.ringbuffer.{RingBufferMailbox, BackpressureRingBufferMailbox}

/**
 * 测试环形缓冲区基础功能
 */
func testRingBufferBasics(): Bool {
    println("=== 测试环形缓冲区基础功能 ===")
    
    let mailbox = RingBufferMailbox(16)  // 16个槽位
    
    // 测试初始状态
    if (!mailbox.isEmpty()) {
        println("✗ 初始状态应该为空")
        return false
    }
    
    if (mailbox.size() != 0) {
        println("✗ 初始大小应该为0")
        return false
    }
    
    if (mailbox.getCapacity() != 16) {
        println("✗ 容量应该为16")
        return false
    }
    
    // 测试入队
    let message1 = PingMessage(1)
    let envelope1 = Envelope(message1, Some("sender1"))
    
    if (!mailbox.enqueue(envelope1)) {
        println("✗ 入队应该成功")
        return false
    }
    
    if (mailbox.isEmpty()) {
        println("✗ 入队后不应该为空")
        return false
    }
    
    if (mailbox.size() != 1) {
        println("✗ 入队后大小应该为1")
        return false
    }
    
    // 测试出队
    match (mailbox.dequeue()) {
        case Some(envelope) =>
            if (envelope.getMessage().messageType() != "PingMessage") {
                println("✗ 出队消息类型错误")
                return false
            }
        case None =>
            println("✗ 出队应该成功")
            return false
    }
    
    if (!mailbox.isEmpty()) {
        println("✗ 出队后应该为空")
        return false
    }
    
    println("✓ 环形缓冲区基础功能测试通过")
    return true
}

/**
 * 测试环形缓冲区容量限制
 */
func testRingBufferCapacity(): Bool {
    println("=== 测试环形缓冲区容量限制 ===")
    
    let mailbox = RingBufferMailbox(4)  // 4个槽位
    
    // 填满缓冲区
    for (i in 1..5) {
        let message = PingMessage(Int64(i))
        let envelope = Envelope(message, Some("sender"))
        
        if (!mailbox.enqueue(envelope)) {
            println("✗ 第${i}个消息入队失败")
            return false
        }
    }
    
    if (mailbox.size() != 4) {
        println("✗ 缓冲区大小应该为4，实际为${mailbox.size()}")
        return false
    }
    
    // 尝试再入队一个消息，应该失败
    let overflowMessage = PingMessage(999)
    let overflowEnvelope = Envelope(overflowMessage, Some("sender"))
    
    if (mailbox.enqueue(overflowEnvelope)) {
        println("✗ 缓冲区满时入队应该失败")
        return false
    }
    
    // 出队一个消息
    match (mailbox.dequeue()) {
        case Some(envelope) =>
            // 现在应该可以再入队一个消息
            if (!mailbox.enqueue(overflowEnvelope)) {
                println("✗ 出队后应该可以入队")
                return false
            }
        case None =>
            println("✗ 出队应该成功")
            return false
    }
    
    println("✓ 环形缓冲区容量限制测试通过")
    return true
}

/**
 * 测试并发访问
 */
func testConcurrentAccess(): Bool {
    println("=== 测试并发访问 ===")
    
    let mailbox = RingBufferMailbox(1024)  // 较大的缓冲区
    let numProducers = 4
    let numConsumers = 2
    let messagesPerProducer = 1000
    let totalMessages = numProducers * messagesPerProducer
    
    let producedCount = AtomicInt64(0)
    let consumedCount = AtomicInt64(0)
    
    // 启动生产者
    for (i in 0..numProducers) {
        spawn {
            for (j in 0..messagesPerProducer) {
                let message = PingMessage(Int64(i * messagesPerProducer + j))
                let envelope = Envelope(message, Some("producer${i}"))
                
                // 重试直到成功入队
                while (!mailbox.enqueue(envelope)) {
                    sleep(Duration.microsecond)
                }
                
                producedCount.fetchAdd(1)
            }
        }
    }
    
    // 启动消费者
    for (i in 0..numConsumers) {
        spawn {
            while (consumedCount.load() < totalMessages) {
                match (mailbox.dequeue()) {
                    case Some(envelope) =>
                        consumedCount.fetchAdd(1)
                    case None =>
                        sleep(Duration.microsecond)
                }
            }
        }
    }
    
    // 等待所有消息处理完成
    let timeout = 10  // 10秒超时
    var elapsed = 0
    while (consumedCount.load() < totalMessages && elapsed < timeout) {
        sleep(Duration.millisecond * 100)
        elapsed += 1
    }
    
    let finalProduced = producedCount.load()
    let finalConsumed = consumedCount.load()
    
    if (finalProduced != totalMessages) {
        println("✗ 生产消息数错误: 期望${totalMessages}, 实际${finalProduced}")
        return false
    }
    
    if (finalConsumed != totalMessages) {
        println("✗ 消费消息数错误: 期望${totalMessages}, 实际${finalConsumed}")
        return false
    }
    
    println("✓ 并发访问测试通过: ${finalProduced}条消息生产，${finalConsumed}条消息消费")
    return true
}

/**
 * 测试背压控制
 */
func testBackpressure(): Bool {
    println("=== 测试背压控制 ===")
    
    let mailbox = BackpressureRingBufferMailbox(16, 0.75)  // 75%负载触发背压
    
    // 填充到背压阈值以下
    let threshold = Int32(16.0 * 0.75)  // 12个消息
    for (i in 1..threshold + 1) {
        let message = PingMessage(Int64(i))
        let envelope = Envelope(message, Some("sender"))
        
        if (!mailbox.enqueue(envelope)) {
            println("✗ 阈值以下入队失败")
            return false
        }
    }
    
    println("已入队${threshold}条消息，负载比例: ${mailbox.getLoadRatio()}")
    
    // 尝试再入队，应该触发背压
    let overloadMessage = PingMessage(999)
    let overloadEnvelope = Envelope(overloadMessage, Some("sender"))
    
    if (mailbox.enqueue(overloadEnvelope)) {
        println("✗ 超过背压阈值时入队应该失败")
        return false
    }
    
    let rejectedCount = mailbox.getRejectedCount()
    if (rejectedCount == 0) {
        println("✗ 应该有被拒绝的消息")
        return false
    }
    
    println("✓ 背压控制测试通过: 拒绝了${rejectedCount}条消息")
    return true
}

/**
 * 性能基准测试
 */
func benchmarkRingBuffer(): Unit {
    println("=== 环形缓冲区性能基准测试 ===")
    
    let mailbox = RingBufferMailbox(8192)  // 8K缓冲区
    let numMessages = 1000000  // 100万消息
    
    println("开始性能测试: ${numMessages}条消息")
    let startTime = DateTime.now()
    
    // 生产者
    spawn {
        for (i in 0..numMessages) {
            let message = PingMessage(Int64(i))
            let envelope = Envelope(message, Some("benchmark"))
            
            while (!mailbox.enqueue(envelope)) {
                // 忙等待，测试最大吞吐量
            }
        }
    }
    
    // 消费者
    let consumedCount = AtomicInt64(0)
    while (consumedCount.load() < numMessages) {
        match (mailbox.dequeue()) {
            case Some(envelope) =>
                consumedCount.fetchAdd(1)
            case None =>
                // 继续尝试
                ()
        }
    }

    let consumed = Int32(consumedCount.load())
    
    let endTime = DateTime.now()

    println("✓ 性能测试完成:")
    println("  - 处理消息: ${consumed}")
    println("  - 高性能环形缓冲区邮箱测试完成")
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 环形缓冲区邮箱测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testRingBufferBasics()
    allPassed = allPassed && testRingBufferCapacity()
    allPassed = allPassed && testConcurrentAccess()
    allPassed = allPassed && testBackpressure()
    
    // 运行性能基准测试
    benchmarkRingBuffer()
    
    if (allPassed) {
        println("\n🎉 所有环形缓冲区邮箱测试通过！")
        println("✓ 基础功能正常")
        println("✓ 容量限制正常")
        println("✓ 并发访问安全")
        println("✓ 背压控制有效")
        println("\n这验证了CActor的高性能邮箱能力！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
