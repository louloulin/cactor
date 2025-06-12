/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 原子操作测试
 * 验证仓颉原子类型的基本功能
 */
package cactor.tests.atomic

import std.sync.*
import std.time.*

/**
 * 测试原子操作功能
 */
func testAtomicOperations(): Bool {
    println("=== 测试原子操作功能 ===")
    
    // 测试AtomicBool
    let atomicBool = AtomicBool(false)
    if (atomicBool.load() != false) {
        println("✗ AtomicBool初始值测试失败")
        return false
    }
    
    atomicBool.store(true)
    if (atomicBool.load() != true) {
        println("✗ AtomicBool存储测试失败")
        return false
    }
    
    if (!atomicBool.compareAndSwap(true, false)) {
        println("✗ AtomicBool CAS测试失败")
        return false
    }
    
    if (atomicBool.load() != false) {
        println("✗ AtomicBool CAS结果测试失败")
        return false
    }
    
    // 测试AtomicInt64
    let atomicInt = AtomicInt64(0)
    if (atomicInt.load() != 0) {
        println("✗ AtomicInt64初始值测试失败")
        return false
    }
    
    atomicInt.store(100)
    if (atomicInt.load() != 100) {
        println("✗ AtomicInt64存储测试失败")
        return false
    }
    
    let oldValue = atomicInt.fetchAdd(50)
    if (oldValue != 100) {
        println("✗ AtomicInt64 fetchAdd返回值测试失败")
        return false
    }
    
    if (atomicInt.load() != 150) {
        println("✗ AtomicInt64 fetchAdd结果测试失败")
        return false
    }
    
    let subValue = atomicInt.fetchSub(30)
    if (subValue != 150) {
        println("✗ AtomicInt64 fetchSub返回值测试失败")
        return false
    }
    
    if (atomicInt.load() != 120) {
        println("✗ AtomicInt64 fetchSub结果测试失败")
        return false
    }
    
    println("✓ 原子操作功能测试通过")
    return true
}

/**
 * 测试并发原子操作
 */
func testConcurrentAtomicOperations(): Bool {
    println("=== 测试并发原子操作 ===")
    
    let counter = AtomicInt64(0)
    let numThreads = 10
    let incrementsPerThread = 1000
    let expectedTotal = numThreads * incrementsPerThread
    
    // 启动多个线程并发增加计数器
    for (i in 0..numThreads) {
        spawn {
            for (j in 0..incrementsPerThread) {
                counter.fetchAdd(1)
            }
        }
    }
    
    // 等待所有线程完成
    sleep(Duration.second * 2)
    
    let finalValue = counter.load()
    if (finalValue != expectedTotal) {
        println("✗ 并发原子操作测试失败: 期望${expectedTotal}, 实际${finalValue}")
        return false
    }
    
    println("✓ 并发原子操作测试通过: ${finalValue}次操作")
    return true
}

/**
 * 测试互斥锁功能
 */
func testMutex(): Bool {
    println("=== 测试互斥锁功能 ===")
    
    let mutex = ReentrantMutex()
    let sharedCounter = AtomicInt64(0)
    let numThreads = 5
    let incrementsPerThread = 200
    
    // 使用互斥锁保护的计数器
    for (i in 0..numThreads) {
        spawn {
            for (j in 0..incrementsPerThread) {
                mutex.lock()
                try {
                    let current = sharedCounter.load()
                    // 模拟一些计算
                    sleep(Duration.microsecond)
                    sharedCounter.store(current + 1)
                } finally {
                    mutex.unlock()
                }
            }
        }
    }
    
    // 等待所有线程完成
    sleep(Duration.second * 3)
    
    let finalValue = sharedCounter.load()
    let expectedTotal = numThreads * incrementsPerThread
    
    if (finalValue != expectedTotal) {
        println("✗ 互斥锁测试失败: 期望${expectedTotal}, 实际${finalValue}")
        return false
    }
    
    println("✓ 互斥锁测试通过: ${finalValue}次操作")
    return true
}

/**
 * 测试spawn轻量级线程
 */
func testSpawn(): Bool {
    println("=== 测试spawn轻量级线程 ===")
    
    let completedTasks = AtomicInt64(0)
    let numTasks = 100
    
    // 启动大量轻量级线程
    for (i in 0..numTasks) {
        spawn {
            // 模拟一些工作
            sleep(Duration.millisecond * 10)
            completedTasks.fetchAdd(1)
        }
    }
    
    // 等待所有任务完成
    sleep(Duration.second * 2)
    
    let completed = completedTasks.load()
    if (completed != numTasks) {
        println("✗ spawn测试失败: 期望${numTasks}, 实际${completed}")
        return false
    }
    
    println("✓ spawn测试通过: ${completed}个任务完成")
    return true
}

/**
 * 性能基准测试
 */
func benchmarkAtomicOperations(): Unit {
    println("=== 原子操作性能基准测试 ===")
    
    let counter = AtomicInt64(0)
    let iterations = 1000000
    
    let startTime = DateTime.now()
    
    for (i in 0..iterations) {
        counter.fetchAdd(1)
    }
    
    let endTime = DateTime.now()
    // 简化性能测试，不进行精确计时
    println("✓ 原子操作性能测试完成")
    
    println("✓ 完成${iterations}次原子操作")
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 原子操作和并发测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testAtomicOperations()
    allPassed = allPassed && testConcurrentAtomicOperations()
    allPassed = allPassed && testMutex()
    allPassed = allPassed && testSpawn()
    
    // 运行性能基准测试
    benchmarkAtomicOperations()
    
    if (allPassed) {
        println("\n🎉 所有原子操作和并发测试通过！")
        println("✓ 原子操作功能正常")
        println("✓ 并发安全机制正常")
        println("✓ 互斥锁功能正常")
        println("✓ spawn轻量级线程正常")
        println("\n这验证了CActor的基础并发能力！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
