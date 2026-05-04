/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - AtLeastOnceDelivery 示例程序
 * 展示可靠消息投递机制的使用
 */
package cactor.examples.delivery_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示投递事件处理器
 */
public class DemoDeliveryHandler <: DeliveryEventHandler {
    public let sentEvents = ArrayList<String>()
    public let confirmedEvents = ArrayList<String>()
    public let maxRetryEvents = ArrayList<String>()

    public func onMessageSent(messageId: Int64, destination: String, payload: String): Unit {
        let event = "msg-${messageId} -> ${destination}"
        sentEvents.add(event)
        println("  [SENT] ${event}: ${payload}")
    }

    public func onMessageConfirmed(messageId: Int64): Unit {
        let event = "msg-${messageId}"
        confirmedEvents.add(event)
        println("  [CONFIRMED] ${event}")
    }

    public func onMessageTimeout(messageId: Int64, destination: String): Unit {
        println("  [TIMEOUT] msg-${messageId} to ${destination}")
    }

    public func onMessageMaxRetries(messageId: Int64, destination: String, reason: String): Unit {
        let event = "msg-${messageId}"
        maxRetryEvents.add(event)
        println("  [MAX RETRY] ${event} at ${destination}: ${reason}")
    }

    public func onMessageStale(messageId: Int64): Unit {
        println("  [STALE] msg-${messageId}")
    }
}

/**
 * 运行基本投递演示
 */
public func runBasicDeliveryDemo(): Unit {
    println("=== Basic AtLeastOnceDelivery Demo ===")
    let delivery = createAtLeastOnceDelivery("/user/worker")
    let handler = DemoDeliveryHandler()
    delivery.setEventHandler(handler)

    println("Sending messages with at-least-once guarantee...")
    let msgId1 = delivery.deliver("Task 1: Process data")
    let msgId2 = delivery.deliver("Task 2: Generate report")
    let msgId3 = delivery.deliver("Task 3: Send notification")

    println()
    println("Current state:")
    println("  Pending: ${delivery.pendingCount()}")
    println("  Total sent: ${delivery.totalSent()}")
    println()

    // 模拟确认
    println("Simulating confirmations...")
    delivery.confirm(msgId1)
    delivery.confirm(msgId3)

    println()
    println("After confirmation:")
    println("  Pending: ${delivery.pendingCount()}")
    println("  Confirmed: ${delivery.confirmedCount()}")
    println("  Confirmation rate: ${(delivery.confirmationRate() * 100).toInt64()}%")
    println()
}

/**
 * 运行批量投递演示
 */
public func runBatchDeliveryDemo(): Unit {
    println("=== Batch Delivery Demo ===")
    let delivery = createAtLeastOnceDelivery("/user/batch-processor")
    let handler = DemoDeliveryHandler()
    delivery.setEventHandler(handler)

    println("Creating batch of messages...")
    let payloads = ArrayList<String>()
    for (i in 1..11) {
        payloads.append("Batch item ${i}")
    }

    println("Sending batch of ${payloads.size} messages...")
    let messageIds = delivery.deliverBatch(payloads)

    println()
    println("Batch sent. Message IDs: ${messageIds.size}")
    println("  First ID: ${messageIds[0]}, Last ID: ${messageIds[messageIds.size - 1]}")
    println("  Pending count: ${delivery.pendingCount()}")
    println()

    // 模拟部分确认
    println("Simulating partial confirmations...")
    for (i in 0..5) {
        delivery.confirm(messageIds[i])
    }

    println()
    println("After partial confirmations:")
    println("  Pending: ${delivery.pendingCount()}")
    println("  Confirmed: ${delivery.confirmedCount()}")
    println("  Confirmation rate: ${(delivery.confirmationRate() * 100).toInt64()}%")
    println()
}

/**
 * 运行投递追踪演示
 */
public func runTrackingDemo(): Unit {
    println("=== Delivery Tracking Demo ===")
    let delivery = createAtLeastOnceDelivery("/user/tracked-processor")
    let handler = DemoDeliveryHandler()
    delivery.setEventHandler(handler)

    println("Sending messages with tracking...")
    let msgId1 = delivery.deliver("Important task 1")
    let msgId2 = delivery.deliver("Important task 2")
    let msgId3 = delivery.deliver("Important task 3")

    println()
    println("Message states:")
    for (id in [msgId1, msgId2, msgId3]) {
        let state = delivery.getDeliveryState(id)
        match (state) {
            case Some(s) => println("  msg-${id}: ${s}")
            case None => println("  msg-${id}: unknown")
        }
    }

    println()
    println("Marking message 2 as sent...")
    delivery.markSent(msgId2)

    println("After marking sent:")
    match (delivery.getDeliveryState(msgId2)) {
        case Some(s) => println("  msg-${msgId2}: ${s}")
        case None => ()
    }

    println()
    println("Getting all pending deliveries...")
    let pending = delivery.getPendingDeliveries()
    for (track in pending) {
        println("  ID: ${track.messageId}, Dest: ${track.destination}, Payload: ${track.payload}")
    }
    println()
}

/**
 * 运行确认机制演示
 */
public func runConfirmationDemo(): Unit {
    println("=== Confirmation Mechanism Demo ===")
    let delivery = createAtLeastOnceDelivery("/user/confirmation-service")
    let handler = DemoDeliveryHandler()
    delivery.setEventHandler(handler)

    println("Sending messages that require confirmation...")
    let id1 = delivery.deliver("Critical data 1")
    let id2 = delivery.deliver("Critical data 2")
    let id3 = delivery.deliver("Critical data 3")

    println()
    println("Pending deliveries: ${delivery.pendingCount()}")

    // 模拟传输层标记发送
    println()
    println("Transport layer marks messages as sent...")
    delivery.markSent(id1)
    delivery.markSent(id2)

    // 模拟接收方确认
    println()
    println("Receivers sending confirmations...")
    delivery.confirm(id1)
    delivery.confirm(id2)
    delivery.confirm(id3)

    println()
    println("Final state:")
    println("  Pending: ${delivery.pendingCount()}")
    println("  Confirmed: ${delivery.confirmedCount()}")
    println("  Total sent: ${delivery.totalSent()}")
    println("  Confirmation rate: ${(delivery.confirmationRate() * 100).toInt64()}%")
    println()
}

/**
 * 运行重试机制演示
 */
public func runRetryDemo(): Unit {
    println("=== Retry Mechanism Demo ===")

    // 创建短重试间隔的配置
    let config = DeliveryConfig(
        Duration.millisecond * 100,  // 短重试间隔
        5,                           // 最大重试次数
        Duration.second * 1,
        Duration.minute * 5,
        100
    )
    let delivery = createAtLeastOnceDeliveryWithConfig("/user/retry-service", config)
    let handler = DemoDeliveryHandler()
    delivery.setEventHandler(handler)

    println("Sending messages with retry configuration...")
    println("  Redeliver interval: 100ms")
    println("  Max retries: 5")
    let id1 = delivery.deliver("Retry message 1")
    let id2 = delivery.deliver("Retry message 2")

    println()
    println("Marking messages as sent...")
    delivery.markSent(id1)
    delivery.markSent(id2)

    println()
    println("Getting messages needing retry...")
    let retryList = delivery.getMessagesToRetry()
    println("  Messages pending retry: ${retryList.size}")

    println()
    println("Checking if message exceeded max retries...")
    delivery.markSent(id1)
    delivery.markSent(id1)
    delivery.markSent(id1)
    delivery.markSent(id1)
    delivery.markSent(id1)

    // 模拟超过最大重试次数
    println("  Attempting retry of exceeded message...")
    println()
}

/**
 * 运行投递取消演示
 */
public func runCancelDemo(): Unit {
    println("=== Delivery Cancellation Demo ===")
    let delivery = createAtLeastOnceDelivery("/user/cancellable-service")
    let handler = DemoDeliveryHandler()
    delivery.setEventHandler(handler)

    println("Sending messages...")
    let id1 = delivery.deliver("Cancellable task 1")
    let id2 = delivery.deliver("Cancellable task 2")
    let id3 = delivery.deliver("Cancellable task 3")

    println()
    println("Current pending: ${delivery.pendingCount()}")

    println()
    println("Cancelling message 2...")
    let cancelled = delivery.cancelDelivery(id2)
    println("  Cancel result: ${cancelled}")
    println("  Pending after cancel: ${delivery.pendingCount()}")
    println("  Total failed: ${delivery.totalFailed()}")

    println()
    println("Attempting to cancel non-existent message...")
    let notFound = delivery.cancelDelivery(999)
    println("  Cancel result: ${notFound}")
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor AtLeastOnceDelivery Demo")
    println("=================================")
    println()

    runBasicDeliveryDemo()
    runBatchDeliveryDemo()
    runTrackingDemo()
    runConfirmationDemo()
    runRetryDemo()
    runCancelDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}