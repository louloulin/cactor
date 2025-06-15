/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 工作窃取调度器测试
 * 验证工作窃取功能
 */
package cactor.tests

import std.sync.*
import std.time.*
import cactor.dispatcher.work_stealing.*
import cactor.core.message.{Envelope, PingMessage, Message}
import cactor.core.actor.ActorRef

/**
 * 工作窃取调度器测试
 */

/**
 * 测试工作窃取队列基础功能
 */
func testWorkStealingQueueBasics(): Bool {
    let queue = WorkStealingQueue<Int32>(10)

    // 测试初始状态
    if (!queue.isEmpty()) {
        println("✗ 队列初始状态应该为空")
        return false
    }

    if (queue.getSize() != 0) {
        println("✗ 队列初始大小应该为0")
        return false
    }

    // 测试推入
    if (!queue.push(1) || !queue.push(2) || !queue.push(3)) {
        println("✗ 推入操作应该成功")
        return false
    }

    if (queue.isEmpty()) {
        println("✗ 推入后队列不应该为空")
        return false
    }

    if (queue.getSize() != 3) {
        println("✗ 推入3个元素后大小应该为3")
        return false
    }

    // 测试弹出 (LIFO)
    match (queue.pop()) {
        case Some(value) =>
            if (value != 3) {
                println("✗ 弹出的值应该是3（LIFO），实际是${value}")
                return false
            }
        case None =>
            println("✗ 应该能弹出元素")
            return false
    }

    if (queue.getSize() != 2) {
        println("✗ 弹出后大小应该为2")
        return false
    }

    // 测试窃取 (FIFO)
    match (queue.steal()) {
        case Some(value) =>
            if (value != 1) {
                println("✗ 窃取的值应该是1（FIFO），实际是${value}")
                return false
            }
        case None =>
            println("✗ 应该能窃取元素")
            return false
    }

    if (queue.getSize() != 1) {
        println("✗ 窃取后大小应该为1")
        return false
    }

    println("✓ 工作窃取队列基础功能测试通过")
    return true
}
/**
 * 测试工作窃取队列容量限制
 */
func testWorkStealingQueueCapacity(): Bool {
    let queue = WorkStealingQueue<Int32>(3)

    // 填满队列
    if (!queue.push(1) || !queue.push(2) || !queue.push(3)) {
        println("✗ 填满队列失败")
        return false
    }

    // 尝试超出容量
    if (queue.push(4)) {
        println("✗ 超出容量时推入应该失败")
        return false
    }

    if (queue.getSize() != 3) {
        println("✗ 队列大小应该为3")
        return false
    }

    // 弹出一个元素后应该可以再推入
    queue.pop()
    if (!queue.push(4)) {
        println("✗ 弹出后应该可以推入")
        return false
    }

    if (queue.getSize() != 3) {
        println("✗ 推入后队列大小应该为3")
        return false
    }

    println("✓ 工作窃取队列容量限制测试通过")
    return true
}
/**
 * 测试工作窃取调度器创建
 */
func testWorkStealingDispatcherCreation(): Bool {
    let dispatcher = WorkStealingDispatcher(4)

    if (dispatcher.getWorkerCount() != 4) {
        println("✗ 工作线程数应该为4")
        return false
    }

    if (dispatcher.getTotalTasksSubmitted() != 0) {
        println("✗ 初始提交任务数应该为0")
        return false
    }

    if (dispatcher.getTotalTasksProcessed() != 0) {
        println("✗ 初始处理任务数应该为0")
        return false
    }

    if (dispatcher.getGlobalQueueSize() != 0) {
        println("✗ 初始全局队列大小应该为0")
        return false
    }

    println("✓ 工作窃取调度器创建测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 工作窃取调度器测试 ===")

    var allPassed = true

    // 运行所有测试
    allPassed = allPassed && testWorkStealingQueueBasics()
    allPassed = allPassed && testWorkStealingQueueCapacity()
    allPassed = allPassed && testWorkStealingDispatcherCreation()

    if (allPassed) {
        println("\n🎉 所有工作窃取调度器测试通过！")
        println("✓ 工作窃取队列基础功能正常")
        println("✓ 容量限制正确")
        println("✓ 调度器创建成功")
        println("\n这验证了CActor的工作窃取调度器实现！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
