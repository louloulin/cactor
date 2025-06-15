/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 内存池测试
 * 验证对象池功能
 */
package cactor.integration.testing.memory_pool_test

import std.sync.*
import std.time.*
import cactor.foundation.memory.*
import cactor.core.message.{Envelope, PingMessage}

/**
 * 测试对象池基础功能
 */
func testObjectPoolBasics(): Bool {
    let createdCount = AtomicInt64(0)
    let resetCount = AtomicInt64(0)

    let pool = CangjieFriendlyObjectPool<String>(
        { =>
            let count = createdCount.fetchAdd(1) + 1
            "object-${count}"
        },
        { obj =>
            resetCount.fetchAdd(1)
        },
        5
    )
    
    // 测试获取对象
    let obj1 = pool.acquire()
    if (obj1 != "object-1") {
        println("✗ 第一个对象应该是object-1")
        return false
    }
    
    let obj2 = pool.acquire()
    if (obj2 != "object-2") {
        println("✗ 第二个对象应该是object-2")
        return false
    }
    
    // 测试归还对象
    pool.release(obj1)
    if (resetCount.load() != 1) {
        println("✗ 归还对象后重置函数应该被调用")
        return false
    }
    
    // 测试重用对象
    let obj3 = pool.acquire()
    if (obj3 != obj1) {
        println("✗ 应该重用已归还的对象")
        return false
    }
    
    // 测试池大小
    if (pool.size() != 0) {
        println("✗ 池中应该没有对象")
        return false
    }
    
    println("✓ 对象池基础功能测试通过")
    return true
}

/**
 * 测试对象池容量限制
 */
func testObjectPoolCapacity(): Bool {
    let pool = CangjieFriendlyObjectPool<Int32>(
        { => 42 },
        { obj => },
        2
    )
    
    // 获取对象
    let obj1 = pool.acquire()
    let obj2 = pool.acquire()
    let obj3 = pool.acquire()
    
    // 归还对象
    pool.release(obj1)
    pool.release(obj2)
    pool.release(obj3)  // 这个应该被丢弃，因为超出容量
    
    if (pool.size() != 2) {
        println("✗ 池大小应该限制在2")
        return false
    }
    
    println("✓ 对象池容量限制测试通过")
    return true
}

/**
 * 测试对象池统计信息
 */
func testObjectPoolStatistics(): Bool {
    let pool = CangjieFriendlyObjectPool<Int32>(
        { => 100 },
        { obj => },
        10
    )
    
    // 执行一些操作
    let obj1 = pool.acquire()
    let obj2 = pool.acquire()
    pool.release(obj1)
    let obj3 = pool.acquire()  // 应该重用obj1
    
    let stats = pool.getStatistics()
    
    if (stats.totalAcquired != 3) {
        println("✗ 总获取次数应该是3")
        return false
    }
    
    if (stats.totalReleased != 1) {
        println("✗ 总归还次数应该是1")
        return false
    }
    
    if (stats.maxSize != 10) {
        println("✗ 最大大小应该是10")
        return false
    }
    
    println("✓ 对象池统计信息测试通过")
    return true
}

/**
 * 测试并发访问
 */
func testConcurrentAccess(): Bool {
    let pool = CangjieFriendlyObjectPool<Int64>(
        { => DateTime.now().toUnixTimeStamp().toMilliseconds() },
        { obj => },
        100
    )
    
    let acquiredCount = AtomicInt64(0)
    let releasedCount = AtomicInt64(0)
    let threadCount = 4
    let operationsPerThread = 100
    
    // 启动多个线程进行并发操作
    for (i in 0..threadCount) {
        spawn {
            for (j in 0..operationsPerThread) {
                let obj = pool.acquire()
                acquiredCount.fetchAdd(1)
                
                // 模拟一些工作
                sleep(Duration.microsecond)
                
                pool.release(obj)
                releasedCount.fetchAdd(1)
            }
        }
    }
    
    // 等待所有操作完成
    let timeout = 5000  // 5秒超时
    var elapsed = 0
    let expectedOps = Int64(threadCount * operationsPerThread)
    
    while (releasedCount.load() < expectedOps && elapsed < timeout) {
        sleep(Duration.millisecond * 10)
        elapsed += 10
    }
    
    if (acquiredCount.load() != expectedOps) {
        println("✗ 获取操作数不正确: ${acquiredCount.load()} != ${expectedOps}")
        return false
    }
    
    if (releasedCount.load() != expectedOps) {
        println("✗ 归还操作数不正确: ${releasedCount.load()} != ${expectedOps}")
        return false
    }
    
    println("✓ 并发访问测试通过")
    return true
}

/**
 * 测试消息信封对象池
 */
func testEnvelopePool(): Bool {
    let pool = EnvelopePool(10)
    
    // 测试获取和归还
    let envelope1 = pool.acquire()
    let envelope2 = pool.acquire()
    
    pool.release(envelope1)
    pool.release(envelope2)
    
    if (pool.size() != 2) {
        println("✗ 信封池大小应该是2")
        return false
    }
    
    // 测试重用
    let envelope3 = pool.acquire()
    if (pool.size() != 1) {
        println("✗ 获取后池大小应该减少")
        return false
    }
    
    println("✓ 消息信封对象池测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 内存池管理测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testObjectPoolBasics()
    allPassed = allPassed && testObjectPoolCapacity()
    allPassed = allPassed && testObjectPoolStatistics()
    allPassed = allPassed && testConcurrentAccess()
    allPassed = allPassed && testEnvelopePool()
    
    if (allPassed) {
        println("\n🎉 所有内存池管理测试通过！")
        println("✓ 对象池基础功能正常")
        println("✓ 容量限制正确")
        println("✓ 统计信息准确")
        println("✓ 并发访问安全")
        println("✓ 消息信封池功能正常")
        println("\n这验证了CActor的内存池管理实现！")
        println("🚀 Phase 2: 内存池管理功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
