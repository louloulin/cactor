/*
 * Copyright (c) 2024. All rights reserved.
 * Runtime层与Foundation层集成测试
 * 验证Runtime层正确使用Foundation层组件
 */
package test

import std.unittest.*
import cactor.foundation.queue.{Queue, LockFreeQueue, SimpleQueue}
import cactor.core.message.{Message, StringMessage, PingMessage, Envelope}
import cactor.runtime.mailbox.{Mailbox, FoundationMailbox, FoundationMailboxFactory}

/**
 * Foundation邮箱基础功能测试
 */
@Test
class FoundationMailboxTest {
    @Test
    func testFoundationMailboxBasicOperations(): Unit {
        let mailbox = FoundationMailbox(16)
        
        @Assert(mailbox.isEmpty())
        @Assert(mailbox.size() == 0)
        @Assert(mailbox.capacity() == 16)
        @Assert(!mailbox.isClosed())
        
        // 创建测试消息
        let message = StringMessage("Foundation Mailbox Test")
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
                    case Some(msg) => @Assert(msg.getContent() == "Foundation Mailbox Test")
                    case None => @Assert(false, "消息类型转换失败")
                }
            case None => @Assert(false, "邮箱不应该为空")
        }
        
        @Assert(mailbox.isEmpty())
        @Assert(mailbox.size() == 0)
    }
    
    @Test
    func testFoundationMailboxHighPerformance(): Unit {
        let highPerfMailbox = FoundationMailbox(32, true)
        let standardMailbox = FoundationMailbox(32, false)
        
        @Assert(highPerfMailbox.getMailboxType() == "LockFree")
        @Assert(standardMailbox.getMailboxType() == "Simple")
        
        // 测试批量操作
        let messages = ArrayList<Envelope>()
        for (i in 0..10) {
            let message = PingMessage(i)
            let envelope = Envelope(message, Some("sender${i}"))
            messages.append(envelope)
        }
        
        // 高性能邮箱批量入队
        for (envelope in messages) {
            @Assert(highPerfMailbox.enqueue(envelope))
        }
        
        @Assert(highPerfMailbox.size() == 10)
        
        // 批量出队验证
        var dequeueCount = 0
        while (!highPerfMailbox.isEmpty()) {
            match (highPerfMailbox.dequeue()) {
                case Some(envelope) =>
                    @Assert(envelope.getMessage().messageType() == "PingMessage")
                    dequeueCount += 1
                case None => break
            }
        }
        
        @Assert(dequeueCount == 10)
        @Assert(highPerfMailbox.isEmpty())
    }
    
    @Test
    func testFoundationMailboxStats(): Unit {
        let mailbox = FoundationMailbox(8)
        
        // 创建测试消息
        let message1 = StringMessage("Stats Test 1")
        let message2 = StringMessage("Stats Test 2")
        let envelope1 = Envelope(message1, None)
        let envelope2 = Envelope(message2, None)
        
        // 测试统计信息
        @Assert(mailbox.enqueue(envelope1))
        @Assert(mailbox.enqueue(envelope2))
        
        let stats = mailbox.getStats()
        @Assert(stats.getEnqueued() == 2)
        @Assert(stats.getDequeued() == 0)
        @Assert(stats.getDropped() == 0)
        
        // 出队一个消息
        mailbox.dequeue()
        
        let updatedStats = mailbox.getStats()
        @Assert(updatedStats.getEnqueued() == 2)
        @Assert(updatedStats.getDequeued() == 1)
        
        // 测试性能指标
        let metrics = mailbox.getPerformanceMetrics()
        @Assert(metrics.isHighPerformance())
        @Assert(metrics.getUtilization() > 0.0)
        @Assert(metrics.getOverallThroughput() >= 0.0)
    }
    
    @Test
    func testFoundationMailboxClosure(): Unit {
        let mailbox = FoundationMailbox(4)
        
        let message = StringMessage("Closure Test")
        let envelope = Envelope(message, None)
        
        // 正常操作
        @Assert(mailbox.enqueue(envelope))
        @Assert(!mailbox.isClosed())
        
        // 关闭邮箱
        mailbox.close()
        @Assert(mailbox.isClosed())
        
        // 关闭后不能入队
        @Assert(!mailbox.enqueue(envelope))
        
        // 但可以清空
        mailbox.clear()
        @Assert(mailbox.isEmpty())
    }
}

/**
 * Foundation邮箱工厂测试
 */
@Test
class FoundationMailboxFactoryTest {
    @Test
    func testMailboxFactory(): Unit {
        // 测试高性能邮箱创建
        let highPerfMailbox = FoundationMailboxFactory.createHighPerformanceMailbox(16)
        @Assert(highPerfMailbox.getMailboxType() == "LockFree")
        @Assert(highPerfMailbox.capacity() == 16)
        
        // 测试标准邮箱创建
        let standardMailbox = FoundationMailboxFactory.createStandardMailbox(8)
        @Assert(standardMailbox.getMailboxType() == "Simple")
        @Assert(standardMailbox.capacity() == 8)
        
        // 测试自动选择邮箱
        let lowThroughputMailbox = FoundationMailboxFactory.createOptimalMailbox(16, 5000)
        let highThroughputMailbox = FoundationMailboxFactory.createOptimalMailbox(16, 50000)
        
        @Assert(lowThroughputMailbox.getMailboxType() == "Simple")
        @Assert(highThroughputMailbox.getMailboxType() == "LockFree")
        
        // 测试批量邮箱
        let bulkMailbox = FoundationMailboxFactory.createBulkMailbox(100)
        @Assert(bulkMailbox.capacity() >= 1024)  // 确保容量足够大
        @Assert(bulkMailbox.getMailboxType() == "LockFree")
    }
}

/**
 * Runtime层与Foundation层集成性能测试
 */
@Test
class RuntimeFoundationPerformanceTest {
    @Test
    func testMailboxThroughput(): Unit {
        let mailbox = FoundationMailbox(1024)
        let iterations = 100
        
        // 批量创建消息
        let messages = ArrayList<Envelope>()
        for (i in 0..iterations) {
            let message = StringMessage("Performance Test ${i}")
            let envelope = Envelope(message, Some("perfSender"))
            messages.append(envelope)
        }
        
        // 测试入队性能
        var enqueueSuccess = 0
        for (envelope in messages) {
            if (mailbox.enqueue(envelope)) {
                enqueueSuccess += 1
            }
        }
        
        @Assert(enqueueSuccess == iterations)
        @Assert(mailbox.size() == iterations)
        
        // 测试出队性能
        var dequeueSuccess = 0
        while (!mailbox.isEmpty()) {
            match (mailbox.dequeue()) {
                case Some(_) => dequeueSuccess += 1
                case None => break
            }
        }
        
        @Assert(dequeueSuccess == iterations)
        @Assert(mailbox.isEmpty())
        
        // 验证统计信息
        let stats = mailbox.getStats()
        @Assert(stats.getEnqueued() == iterations)
        @Assert(stats.getDequeued() == iterations)
        @Assert(stats.getSuccessRate() == 100.0)
    }
    
    @Test
    func testFoundationQueueIntegration(): Unit {
        let mailbox = FoundationMailbox(64, true)  // 使用LockFreeQueue
        
        // 获取Foundation队列统计
        match (mailbox.getFoundationQueueStats()) {
            case Some(queueStats) =>
                @Assert(queueStats.capacity == 64)
                @Assert(queueStats.currentSize == 0)
                @Assert(queueStats.enqueueCount == 0)
                @Assert(queueStats.dequeueCount == 0)
            case None => @Assert(false, "应该能获取LockFreeQueue统计信息")
        }
        
        // 添加一些消息
        for (i in 0..5) {
            let message = PingMessage(i)
            let envelope = Envelope(message, None)
            @Assert(mailbox.enqueue(envelope))
        }
        
        // 再次检查统计
        match (mailbox.getFoundationQueueStats()) {
            case Some(queueStats) =>
                @Assert(queueStats.currentSize == 5)
                @Assert(queueStats.enqueueCount == 5)
                @Assert(queueStats.getSuccessRate() == 100.0)
                @Assert(queueStats.getUtilization() > 0.0)
            case None => @Assert(false, "统计信息获取失败")
        }
    }
    
    @Test
    func testMailboxCapacityManagement(): Unit {
        let smallMailbox = FoundationMailbox(4)  // 小容量邮箱
        
        // 填满邮箱
        var successCount = 0
        for (i in 0..10) {  // 尝试超过容量
            let message = StringMessage("Capacity Test ${i}")
            let envelope = Envelope(message, None)
            if (smallMailbox.enqueue(envelope)) {
                successCount += 1
            }
        }
        
        // 验证容量限制
        @Assert(successCount == 4)  // 只能入队4个
        @Assert(smallMailbox.size() == 4)
        @Assert(smallMailbox.capacity() == 4)
        
        let stats = smallMailbox.getStats()
        @Assert(stats.getEnqueued() == 4)
        @Assert(stats.getDropped() == 6)  // 6个被丢弃
        @Assert(stats.getSuccessRate() < 100.0)  // 成功率小于100%
    }
}
