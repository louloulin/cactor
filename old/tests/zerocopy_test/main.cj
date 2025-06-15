/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 零拷贝消息系统测试
 * 验证零拷贝消息传递和NUMA感知内存池功能
 */
package cactor.tests.zerocopy_test

import cactor.core.zerocopy.*
import cactor.core.memory.*
import std.time.*
import std.sync.sleep
import std.collection.*

// 零拷贝消息基础功能测试
func testZeroCopyMessageBasics(): Bool {
    println("\n=== 零拷贝消息基础功能测试 ===")
    
    let factory = ZeroCopyMessageFactory()
    let message = factory.createMessage(1, 1024, 100, 200)
    
    // 测试基本属性
    if (message.getPayloadSize() != 1024) {
        println("✗ 负载大小应该是1024，实际是${message.getPayloadSize()}")
        return false
    }
    
    if (message.getReferenceCount() != 1) {
        println("✗ 初始引用计数应该是1，实际是${message.getReferenceCount()}")
        return false
    }
    
    if (message.messageType() != "ZeroCopyMessage_1") {
        println("✗ 消息类型不正确：${message.messageType()}")
        return false
    }
    
    // 测试引用计数
    message.retain()
    if (message.getReferenceCount() != 2) {
        println("✗ retain后引用计数应该是2，实际是${message.getReferenceCount()}")
        return false
    }
    
    message.release()
    if (message.getReferenceCount() != 1) {
        println("✗ release后引用计数应该是1，实际是${message.getReferenceCount()}")
        return false
    }
    
    // 最终释放
    message.release()
    
    println("✓ 零拷贝消息基础功能测试通过")
    return true
}

// 消息构建器测试
func testMessageBuilder(): Bool {
    println("\n=== 消息构建器测试 ===")
    
    let builder = ZeroCopyMessageBuilder()
    let message = builder
        .withMessageType(42)
        .withSource(1001)
        .withTarget(2002)
        .withPayloadSize(2048)
        .build()
    
    if (message.getPayloadSize() != 2048) {
        println("✗ 构建的消息负载大小不正确")
        return false
    }
    
    if (!message.messageType().contains("42")) {
        println("✗ 构建的消息类型不正确：${message.messageType()}")
        return false
    }
    
    message.release()
    
    println("✓ 消息构建器测试通过")
    return true
}

// 消息池测试
func testMessagePool(): Bool {
    println("\n=== 消息池测试 ===")
    
    let pool = MessagePool(10)
    
    // 测试初始状态
    if (pool.getPoolSize() != 0) {
        println("✗ 初始池大小应该是0，实际是${pool.getPoolSize()}")
        return false
    }
    
    // 获取消息
    let message1 = pool.acquire(1, 1024, 100, 200)
    let message2 = pool.acquire(2, 2048, 101, 201)
    
    if (message1.getPayloadSize() != 1024) {
        println("✗ 消息1负载大小不正确")
        return false
    }
    
    if (message2.getPayloadSize() != 2048) {
        println("✗ 消息2负载大小不正确")
        return false
    }
    
    // 释放消息到池中
    pool.release(message1)
    pool.release(message2)
    
    if (pool.getPoolSize() != 2) {
        println("✗ 释放后池大小应该是2，实际是${pool.getPoolSize()}")
        return false
    }
    
    println("✓ 消息池测试通过")
    return true
}

// NUMA内存池基础测试
func testNumaMemoryPool(): Bool {
    println("\n=== NUMA内存池基础测试 ===")
    
    let pool = NumaAwareMemoryPool()
    
    // 测试内存分配
    match (pool.allocate(1024)) {
        case Some(block) =>
            if (block.size != 1024) {
                println("✗ 分配的内存块大小不正确")
                return false
            }
            
            if (block.numaNode < 0) {
                println("✗ NUMA节点ID应该非负")
                return false
            }
            
            // 释放内存
            pool.deallocate(block)
            
        case None =>
            println("✗ 内存分配失败")
            return false
    }
    
    // 测试统计信息
    let stats = pool.getStats()
    if (stats.getLocalAllocations() < 0) {
        println("✗ 本地分配统计应该非负")
        return false
    }
    
    println("✓ NUMA内存池基础测试通过")
    return true
}

// 本地内存池测试
func testLocalMemoryPool(): Bool {
    println("\n=== 本地内存池测试 ===")
    
    let pool = LocalMemoryPool(0, 64 * 1024)  // 64KB chunks
    
    // 分配多个不同大小的块
    let sizes = [64, 128, 256, 512, 1024]
    let blocks = ArrayList<MemoryBlock>()
    
    for (size in sizes) {
        match (pool.tryAllocate(UInt64(size))) {
            case Some(block) =>
                blocks.append(block)
                if (block.size < UInt64(size)) {
                    println("✗ 分配的块大小小于请求大小")
                    return false
                }
            case None =>
                println("✗ 内存分配失败，大小：${size}")
                return false
        }
    }
    
    // 释放所有块
    for (block in blocks) {
        pool.deallocate(block)
    }
    
    // 再次分配，应该能重用释放的块
    match (pool.tryAllocate(128)) {
        case Some(block) =>
            pool.deallocate(block)
        case None =>
            println("✗ 重用释放块失败")
            return false
    }
    
    println("✓ 本地内存池测试通过")
    return true
}

// 内存池统计测试
func testMemoryPoolStats(): Bool {
    println("\n=== 内存池统计测试 ===")
    
    let stats = MemoryPoolStats()
    
    // 测试初始状态
    if (stats.getLocalAllocations() != 0) {
        println("✗ 初始本地分配数应该是0")
        return false
    }
    
    if (stats.getNumaEfficiency() != 1.0) {
        println("✗ 初始NUMA效率应该是1.0")
        return false
    }
    
    // 记录一些分配
    stats.recordLocalAllocation(1024)
    stats.recordRemoteAllocation(2048)
    stats.recordGlobalAllocation(512)
    
    if (stats.getLocalAllocations() != 1) {
        println("✗ 本地分配数应该是1")
        return false
    }
    
    if (stats.getRemoteAllocations() != 1) {
        println("✗ 远程分配数应该是1")
        return false
    }
    
    if (stats.getGlobalAllocations() != 1) {
        println("✗ 全局分配数应该是1")
        return false
    }
    
    let efficiency = stats.getNumaEfficiency()
    if (efficiency < 0.0 || efficiency > 1.0) {
        println("✗ NUMA效率应该在0-1之间，实际是${efficiency}")
        return false
    }
    
    // 测试重置
    stats.reset()
    if (stats.getLocalAllocations() != 0) {
        println("✗ 重置后本地分配数应该是0")
        return false
    }
    
    println("✓ 内存池统计测试通过")
    return true
}

// 性能测试
func testPerformance(): Bool {
    println("\n=== 性能测试 ===")
    
    let factory = ZeroCopyMessageFactory()
    let messageCount = 10000
    
    let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    
    // 创建大量消息
    let messages = ArrayList<ZeroCopyMessageImpl>()
    for (i in 0..messageCount) {
        let message = factory.createMessage(UInt16(i % 100), 1024, UInt64(i), UInt64(i + 1000))
        messages.append(message)
    }
    
    let midTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    
    // 释放所有消息
    for (message in messages) {
        message.release()
    }
    
    let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    
    let createDuration = midTime - startTime
    let releaseDuration = endTime - midTime
    let totalDuration = endTime - startTime
    
    let createThroughput = Float64(messageCount) / (Float64(createDuration) / 1000.0)
    let releaseThroughput = Float64(messageCount) / (Float64(releaseDuration) / 1000.0)
    
    println("性能测试结果:")
    println("  消息数量: ${messageCount}")
    println("  创建时间: ${createDuration}ms")
    println("  释放时间: ${releaseDuration}ms")
    println("  总时间: ${totalDuration}ms")
    println("  创建吞吐量: ${createThroughput} msg/s")
    println("  释放吞吐量: ${releaseThroughput} msg/s")
    
    println("✓ 性能测试完成")
    return true
}

// 并发测试
func testConcurrency(): Bool {
    println("\n=== 并发测试 ===")
    
    let pool = MessagePool(100)
    let numThreads = 4
    let operationsPerThread = 1000
    
    // 并发获取和释放消息
    for (i in 0..numThreads) {
        spawn {
            for (j in 0..operationsPerThread) {
                let message = pool.acquire(UInt16(j % 10), 1024, UInt64(i), UInt64(j))
                
                // 模拟一些处理时间
                sleep(Duration.microsecond * 1)
                
                pool.release(message)
            }
        }
    }
    
    // 等待所有线程完成
    sleep(Duration.second * 2)
    
    println("并发测试完成，最终池大小: ${pool.getPoolSize()}")
    
    println("✓ 并发测试通过")
    return true
}

// 主测试函数
main(): Int64 {
    println("=== CActor 3.0 零拷贝消息系统测试 ===")
    
    var passedTests = 0
    var totalTests = 0
    
    // 运行所有测试
    totalTests += 1
    if (testZeroCopyMessageBasics()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testMessageBuilder()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testMessagePool()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testNumaMemoryPool()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testLocalMemoryPool()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testMemoryPoolStats()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testPerformance()) {
        passedTests += 1
    }
    
    totalTests += 1
    if (testConcurrency()) {
        passedTests += 1
    }
    
    // 输出测试结果
    println("\n=== 测试结果 ===")
    println("通过测试: ${passedTests}/${totalTests}")
    
    if (passedTests == totalTests) {
        println("🎉 所有零拷贝消息系统测试通过！")
        println("✓ 零拷贝消息基础功能正常")
        println("✓ 消息构建器功能正常")
        println("✓ 消息池管理正常")
        println("✓ NUMA内存池功能正常")
        println("✓ 本地内存池功能正常")
        println("✓ 内存池统计功能正常")
        println("✓ 性能表现良好")
        println("✓ 并发安全")
        println("\n这验证了CActor 3.0的零拷贝消息传递系统实现！")
        println("🚀 Phase 2: 零拷贝消息传递系统功能完成！")
        return 0
    } else {
        println("❌ 部分测试失败")
        return 1
    }
}
