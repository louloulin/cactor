/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 路由器实现
 * 提供消息路由和负载均衡功能
 */
package cactor.patterns.routing

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.message.{Message, Envelope}
import cactor.core.actor.{ActorRef, ActorPath}

/**
 * 路由策略接口
 */
public interface RoutingStrategy {
    /**
     * 选择目标Actor
     * @param routees 可用的Actor列表
     * @param message 要路由的消息
     * @return 选中的Actor，如果没有可用Actor返回None
     */
    func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef>
}

/**
 * 轮询路由策略
 * 按顺序轮流选择Actor
 */
public class RoundRobinRoutingStrategy <: RoutingStrategy {
    private let counter: AtomicInt64

    public init() {
        this.counter = AtomicInt64(0)
    }

    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }

        let index = counter.fetchAdd(1) % Int64(routees.size)
        Some(routees[index])
    }
}

/**
 * 随机路由策略
 * 随机选择Actor
 */
public class RandomRoutingStrategy <: RoutingStrategy {
    private let random: AtomicInt64

    public init() {
        this.random = AtomicInt64(DateTime.now().toUnixTimeStamp().toMilliseconds())
    }

    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }

        // 简单的线性同余随机数生成器
        let current = random.load()
        let next = ((current % 1000000) * 1103 + 12345) % 2147483647
        random.store(next)
        
        let index = next % Int64(routees.size)
        Some(routees[index])
    }
}

/**
 * 最小邮箱路由策略
 * 选择邮箱中消息最少的Actor
 */
public class SmallestMailboxRoutingStrategy <: RoutingStrategy {
    public init() {}

    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }

        // 简化实现：返回第一个Actor
        // 实际实现需要访问Actor的邮箱大小
        Some(routees[0])
    }
}

/**
 * 广播路由策略
 * 将消息发送给所有Actor
 */
public class BroadcastRoutingStrategy <: RoutingStrategy {
    public init() {}

    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        // 广播策略不选择单个Actor，而是在Router中特殊处理
        None
    }

    public func broadcast(routees: Array<ActorRef>, message: Message): Unit {
        for (routee in routees) {
            routee.tell(message)
        }
    }
}

/**
 * 一致性哈希路由策略
 * 基于消息内容的哈希值选择Actor
 */
public class ConsistentHashRoutingStrategy <: RoutingStrategy {
    public init() {}

    public func selectRoutee(routees: Array<ActorRef>, message: Message): Option<ActorRef> {
        if (routees.size == 0) {
            return None
        }

        // 使用消息类型的哈希值
        let hash = message.messageType().hashCode()
        let index = Int64(hash) % Int64(routees.size)
        Some(routees[index])
    }
}

/**
 * 路由器接口
 */
public interface Router {
    /**
     * 路由消息
     */
    func route(message: Message): Unit

    /**
     * 添加路由目标
     */
    func addRoutee(routee: ActorRef): Unit

    /**
     * 移除路由目标
     */
    func removeRoutee(routee: ActorRef): Unit

    /**
     * 获取所有路由目标
     */
    func getRoutees(): Array<ActorRef>

    /**
     * 获取路由策略
     */
    func getStrategy(): RoutingStrategy
}

/**
 * 基础路由器实现
 */
public class BasicRouter <: Router {
    private let strategy: RoutingStrategy
    private let routees: ArrayList<ActorRef>
    private let mutex: Mutex

    public init(strategy: RoutingStrategy) {
        this.strategy = strategy
        this.routees = ArrayList<ActorRef>()
        this.mutex = Mutex()
    }

    public func route(message: Message): Unit {
        mutex.lock()
        let routeeArray = routees.toArray()
        mutex.unlock()

        // 特殊处理广播策略
        match (strategy) {
            case broadcast: BroadcastRoutingStrategy => 
                broadcast.broadcast(routeeArray, message)
            case _ => 
                match (strategy.selectRoutee(routeeArray, message)) {
                    case Some(routee) => routee.tell(message)
                    case None => 
                        println("警告: 没有可用的路由目标")
                }
        }
    }

    public func addRoutee(routee: ActorRef): Unit {
        mutex.lock()
        try {
            routees.add(routee)
        } finally {
            mutex.unlock()
        }
    }

    public func removeRoutee(routee: ActorRef): Unit {
        mutex.lock()
        try {
            // 简化实现：遍历查找并移除
            var index = -1
            for (i in 0..routees.size) {
                if (routees[i].equals(routee)) {
                    index = i
                    break
                }
            }
            if (index >= 0) {
                routees.remove(Int64(index)..Int64(index + 1))
            }
        } finally {
            mutex.unlock()
        }
    }

    public func getRoutees(): Array<ActorRef> {
        mutex.lock()
        try {
            routees.toArray()
        } finally {
            mutex.unlock()
        }
    }

    public func getStrategy(): RoutingStrategy {
        strategy
    }
}

/**
 * 路由器工厂
 */
public struct RouterFactory {
    /**
     * 创建轮询路由器
     */
    public static func roundRobin(): BasicRouter {
        BasicRouter(RoundRobinRoutingStrategy())
    }

    /**
     * 创建随机路由器
     */
    public static func random(): BasicRouter {
        BasicRouter(RandomRoutingStrategy())
    }

    /**
     * 创建最小邮箱路由器
     */
    public static func smallestMailbox(): BasicRouter {
        BasicRouter(SmallestMailboxRoutingStrategy())
    }

    /**
     * 创建广播路由器
     */
    public static func broadcast(): BasicRouter {
        BasicRouter(BroadcastRoutingStrategy())
    }

    /**
     * 创建一致性哈希路由器
     */
    public static func consistentHash(): BasicRouter {
        BasicRouter(ConsistentHashRoutingStrategy())
    }
}

/**
 * 路由器Actor包装器
 * 将路由器包装成ActorRef
 */
public class RouterActorRef <: ActorRef {
    private let router: Router
    private let routerPath: ActorPath

    public init(router: Router, path: String) {
        this.router = router
        this.routerPath = ActorPath("router", "/${path}")
    }

    public prop path: ActorPath {
        get() {
            routerPath
        }
    }

    public func tell(message: Message): Unit {
        router.route(message)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        // 简化实现：忽略sender
        router.route(message)
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case routerRef: RouterActorRef => 
                this.routerPath.equals(routerRef.routerPath)
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        routerPath.hashCode()
    }

    public func getRouter(): Router {
        router
    }
}

/**
 * 路由配置
 */
public struct RoutingConfig {
    public let strategy: RoutingStrategy
    public let routeeCount: Int32
    public let resizePolicy: ResizePolicy

    public init(strategy: RoutingStrategy, routeeCount: Int32, resizePolicy: ResizePolicy) {
        this.strategy = strategy
        this.routeeCount = routeeCount
        this.resizePolicy = resizePolicy
    }
}

/**
 * 调整大小策略
 */
public enum ResizePolicy {
    | Fixed        // 固定大小
    | Dynamic      // 动态调整
}

/**
 * 路由统计信息
 */
public struct RoutingStatistics {
    public let totalMessages: Int64
    public let routeeCount: Int32
    public let averageLatency: Float64

    public init(totalMessages: Int64, routeeCount: Int32, averageLatency: Float64) {
        this.totalMessages = totalMessages
        this.routeeCount = routeeCount
        this.averageLatency = averageLatency
    }
}
