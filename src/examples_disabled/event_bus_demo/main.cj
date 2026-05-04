/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Event Bus 示例程序
 * 演示发布-订阅模式的事件分发
 */
package cactor.examples.event_bus_demo

import std.collection.*
import std.time.*
import cactor.patterns.event_bus.*

// ============================================================================
// Event Bus 示例演示
// ============================================================================

/**
 * 演示简单事件总线
 */
public func demonstrateSimpleEventBus(): Unit {
    println("=== 简单事件总线演示 ===")

    let bus = SubclassificationBasedEventBus()

    // 创建订阅者
    var notificationCount: Int64 = 0
    let handler = { e: Event =>
        notificationCount += 1
        println("  收到事件: ${e}")
    }
    let subscriber = SimpleSubscriber("subscriber-1", handler)

    // 订阅频道
    let subscribed = bus.subscribe(subscriber, "notifications")
    println("订阅结果: ${subscribed}")

    // 发布事件
    println("发布事件到 'notifications' 频道:")
    bus.publishToClassifier(Event("Hello, World!", "publisher-1"), "notifications")

    // 订阅另一个频道
    let _ = bus.subscribe(subscriber, "alerts")
    println("订阅 'alerts' 频道后，总订阅者数量: ${bus.getSubscriberCount("alerts")}")

    println("总通知数: ${notificationCount}")
    println()
}

/**
 * 演示集群事件总线
 */
public func demonstrateClusterEventBus(): Unit {
    println("=== 集群事件总线演示 ===")

    let bus = ClusterEventBus()

    // 创建事件监听器
    var memberEvents: Int64 = 0
    var leaderEvents: Int64 = 0

    let memberHandler = { e: Event =>
        memberEvents += 1
        println("  成员事件监听器收到事件")
    }
    let leaderHandler = { e: Event =>
        leaderEvents += 1
        println("  领导者变更监听器收到事件")
    }

    let memberSubscriber = SimpleSubscriber("member-listener", memberHandler)
    let leaderSubscriber = SimpleSubscriber("leader-listener", leaderHandler)

    // 订阅成员变更事件
    let _ = bus.subscribeToMemberChanges(memberSubscriber)
    // 订阅领导者变更事件
    let _ = bus.subscribeToLeaderChanges(leaderSubscriber)

    // 发布事件
    println("发布成员加入事件:")
    bus.publishMemberJoined("node-1")
    println("发布成员上线事件:")
    bus.publishMemberUp("node-2")
    println("发布领导者变更事件:")
    bus.publishLeaderChanged("node-3")
    println("发布成员不可达事件:")
    bus.publishMemberUnreachable("node-4")

    println("成员事件数: ${memberEvents}")
    println("领导者事件数: ${leaderEvents}")
    println()
}

/**
 * 演示多订阅者场景
 */
public func demonstrateMultipleSubscribers(): Unit {
    println("=== 多订阅者场景演示 ===")

    let bus = SubclassificationBasedEventBus()

    // 创建多个订阅者
    var count1: Int64 = 0
    var count2: Int64 = 0
    var count3: Int64 = 0

    let sub1 = SimpleSubscriber("consumer-1", { e: Event => count1 += 1 })
    let sub2 = SimpleSubscriber("consumer-2", { e: Event => count2 += 1 })
    let sub3 = SimpleSubscriber("consumer-3", { e: Event => count3 += 1 })

    // 订阅同一个频道
    let _ = bus.subscribe(sub1, "news")
    let _ = bus.subscribe(sub2, "news")
    let _ = bus.subscribe(sub3, "news")

    println("订阅者数量: ${bus.getSubscriberCount("news")}")

    // 发布一条消息，所有订阅者都能收到
    println("发布新闻消息:")
    bus.publishToClassifier(Event("Breaking news!", "news-desk"), "news")

    println("Consumer-1 收到: ${count1}")
    println("Consumer-2 收到: ${count2}")
    println("Consumer-3 收到: ${count3}")
    println()
}

/**
 * 演示取消订阅
 */
public func demonstrateUnsubscribe(): Unit {
    println("=== 取消订阅演示 ===")

    let bus = SubclassificationBasedEventBus()

    var received: Int64 = 0
    let handler = { e: Event => received += 1 }
    let subscriber = SimpleSubscriber("temp-subscriber", handler)

    // 订阅
    let _ = bus.subscribe(subscriber, "temp-channel")
    println("订阅后订阅者数量: ${bus.getSubscriberCount("temp-channel")}")

    // 接收消息
    bus.publishToClassifier(Event("Message 1"), "temp-channel")
    println("接收消息后计数: ${received}")

    // 取消订阅
    let unsubscribed = bus.unsubscribe(subscriber, "temp-channel")
    println("取消订阅结果: ${unsubscribed}")
    println("取消订阅后订阅者数量: ${bus.getSubscriberCount("temp-channel")}")

    // 再次发布消息，不应该收到
    bus.publishToClassifier(Event("Message 2"), "temp-channel")
    println("取消订阅后接收计数: ${received} (应该仍然是 1)")
    println()
}

/**
 * 演示分类器管理
 */
public func demonstrateClassifiers(): Unit {
    println("=== 分类器管理演示 ===")

    let bus = SubclassificationBasedEventBus()

    let sub = SimpleSubscriber("test-sub", { e: Event => () })

    // 订阅多个频道
    let _ = bus.subscribe(sub, "sports")
    let _ = bus.subscribe(sub, "politics")
    let _ = bus.subscribe(sub, "entertainment")

    let classifiers = bus.getClassifiers()
    println("所有分类器: ${classifiers.size} 个")
    for (c in classifiers) {
        println("  - ${c}")
    }
    println()
}

/**
 * 演示取消所有订阅
 */
public func demonstrateUnsubscribeAll(): Unit {
    println("=== 取消所有订阅演示 ===")

    let bus = SubclassificationBasedEventBus()

    let subscriber = SimpleSubscriber("multi-channel-sub", { e: Event => () })

    // 订阅多个频道
    let _ = bus.subscribe(subscriber, "channel-1")
    let _ = bus.subscribe(subscriber, "channel-2")
    let _ = bus.subscribe(subscriber, "channel-3")

    println("订阅前分类器数: ${bus.getClassifiers().size}")

    // 取消所有订阅
    bus.unsubscribeAll(subscriber)

    println("取消所有订阅后分类器数: ${bus.getClassifiers().size}")
    println()
}

/**
 * 运行所有演示
 */
main(): Unit {
    println("========================================")
    println("   CActor Event Bus 事件总线演示")
    println("========================================")
    println()

    demonstrateSimpleEventBus()
    demonstrateClusterEventBus()
    demonstrateMultipleSubscribers()
    demonstrateUnsubscribe()
    demonstrateClassifiers()
    demonstrateUnsubscribeAll()

    println("========================================")
    println("   Event Bus 演示完成!")
    println("========================================")
}