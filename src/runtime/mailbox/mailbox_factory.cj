/*
 * Copyright (c) 2024. All rights reserved.
 * MailboxFactory - Plan10.md要求的邮箱工厂
 * 实现配置驱动的邮箱创建和管理
 */
package cactor.runtime.mailbox

import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, Envelope}

/**
 * 邮箱接口
 * 负责存储和管理Actor的消息队列
 */
public interface Mailbox {
    /**
     * 将消息入队
     * @param envelope 要入队的消息信封
     * @return 是否成功入队
     */
    func enqueue(envelope: Envelope): Bool

    /**
     * 从队列中取出消息
     * @return 消息信封，如果队列为空则返回None
     */
    func dequeue(): Option<Envelope>

    /**
     * 检查邮箱是否为空
     * @return 是否为空
     */
    func isEmpty(): Bool

    /**
     * 获取邮箱中消息的数量
     * @return 消息数量
     */
    func size(): Int64

    /**
     * 清空邮箱
     */
    func clear(): Unit
}

/**
 * 邮箱类型枚举
 */
public enum MailboxType {
    Unbounded       // 无界邮箱
    | Bounded       // 有界邮箱
    | Priority      // 优先级邮箱
    | Stashing      // 暂存邮箱
    | ZeroCopy      // 零拷贝邮箱
    | Foundation    // Foundation邮箱
}



/**
 * 邮箱配置
 */
public struct MailboxConfig {
    public let mailboxType: MailboxType
    public let capacity: Int32
    public let enableMetrics: Bool
    public let enableBackpressure: Bool
    public let name: String
    
    public init(
        mailboxType: MailboxType,
        capacity: Int32,
        enableMetrics: Bool,
        enableBackpressure: Bool,
        name: String
    ) {
        this.mailboxType = mailboxType
        this.capacity = capacity
        this.enableMetrics = enableMetrics
        this.enableBackpressure = enableBackpressure
        this.name = name
    }
    
    public static func createUnbounded(): MailboxConfig {
        MailboxConfig(
            MailboxType.Unbounded,
            -1,  // 无限容量
            true,
            false,
            "unbounded-mailbox"
        )
    }
    
    public static func createBounded(capacity: Int32): MailboxConfig {
        MailboxConfig(
            MailboxType.Bounded,
            capacity,
            true,
            true,
            "bounded-mailbox"
        )
    }
    
    public static func createFoundation(): MailboxConfig {
        MailboxConfig(
            MailboxType.Foundation,
            10000,
            true,
            false,
            "foundation-mailbox"
        )
    }
}

/**
 * 邮箱工厂统计信息
 */
public struct MailboxFactoryStats {
    public let totalMailboxes: Int64
    public let activeMailboxes: Int64
    public let mailboxesByType: HashMap<String, Int64>

    public init(totalMailboxes: Int64, activeMailboxes: Int64, mailboxesByType: HashMap<String, Int64>) {
        this.totalMailboxes = totalMailboxes
        this.activeMailboxes = activeMailboxes
        this.mailboxesByType = mailboxesByType
    }
}

/**
 * MailboxFactory - Plan10.md要求的核心组件
 * 
 * 职责：
 * 1. 根据配置创建不同类型的邮箱
 * 2. 管理邮箱生命周期
 * 3. 提供邮箱统计和监控
 * 4. 支持动态邮箱类型选择
 */
public class MailboxFactory {
    private let defaultConfig: MailboxConfig
    private let createdMailboxes: AtomicInt64
    private let activeMailboxes: AtomicInt64
    private let mailboxesByType: HashMap<String, AtomicInt64>
    private let isRunning: AtomicBool
    
    public init(defaultConfig: MailboxConfig) {
        this.defaultConfig = defaultConfig
        this.createdMailboxes = AtomicInt64(0)
        this.activeMailboxes = AtomicInt64(0)
        this.mailboxesByType = HashMap<String, AtomicInt64>()
        this.isRunning = AtomicBool(false)

        // 初始化统计计数器
        initializeCounters()
    }
    
    /**
     * 启动邮箱工厂
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("🚀 MailboxFactory启动成功")
        }
    }
    
    /**
     * 停止邮箱工厂
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("🛑 MailboxFactory已停止")
        }
    }
    
    /**
     * 创建邮箱 - Plan10.md要求的核心方法
     */
    public func createMailbox(actor: Actor, props: Props<Actor>): Mailbox {
        if (!isRunning.load()) {
            throw Exception("MailboxFactory未运行")
        }
        
        // 获取邮箱配置
        let config = getMailboxConfig(actor, props)
        
        // 根据类型创建邮箱
        let mailbox = match (config.mailboxType) {
            case MailboxType.Unbounded =>
                createUnboundedMailbox(config)
            case MailboxType.Bounded =>
                createBoundedMailbox(config)
            case MailboxType.Priority =>
                createPriorityMailbox(config)
            case MailboxType.Stashing =>
                createStashingMailbox(config)
            case MailboxType.ZeroCopy =>
                createZeroCopyMailbox(config)
            case MailboxType.Foundation =>
                createFoundationMailbox(config)
        }
        
        // 更新统计
        createdMailboxes.fetchAdd(1)
        activeMailboxes.fetchAdd(1)
        incrementTypeCounter(config.mailboxType)
        
        return mailbox
    }
    
    /**
     * 销毁邮箱
     */
    public func destroyMailbox(mailbox: Mailbox): Unit {
        // 简化实现：只更新统计
        activeMailboxes.fetchAdd(-1)
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): MailboxFactoryStats {
        let totalMailboxes = createdMailboxes.load()
        let activeMailboxes = this.activeMailboxes.load()
        let mailboxesByType = HashMap<String, Int64>()

        for ((mailboxType, counter) in this.mailboxesByType) {
            mailboxesByType.add(mailboxType, counter.load())
        }

        MailboxFactoryStats(totalMailboxes, activeMailboxes, mailboxesByType)
    }
    
    /**
     * 获取邮箱配置
     */
    private func getMailboxConfig(actor: Actor, props: Props<Actor>): MailboxConfig {
        // 简化实现：直接使用默认配置
        return selectDefaultConfig(actor)
    }
    
    /**
     * 选择默认配置
     */
    private func selectDefaultConfig(actor: Actor): MailboxConfig {
        let actorName = actor.name
        
        // 根据Actor名称选择合适的邮箱类型
        if (actorName.contains("high-performance")) {
            MailboxConfig.createFoundation()
        } else if (actorName.contains("bounded")) {
            MailboxConfig.createBounded(1000)
        } else {
            defaultConfig
        }
    }
    
    /**
     * 创建无界邮箱
     */
    private func createUnboundedMailbox(config: MailboxConfig): Mailbox {
        // 简化实现：创建一个简单的邮箱
        SimpleMailbox(10000)  // 大容量作为"无界"
    }

    /**
     * 创建有界邮箱
     */
    private func createBoundedMailbox(config: MailboxConfig): Mailbox {
        let capacity = if (config.capacity > 0) { Int64(config.capacity) } else { 1000 }
        SimpleMailbox(capacity)
    }

    /**
     * 创建优先级邮箱
     */
    private func createPriorityMailbox(config: MailboxConfig): Mailbox {
        // 简化实现：使用简单邮箱
        // 实际实现应该支持消息优先级
        SimpleMailbox(Int64(config.capacity))
    }

    /**
     * 创建暂存邮箱
     */
    private func createStashingMailbox(config: MailboxConfig): Mailbox {
        // 简化实现：使用简单邮箱
        // 实际实现应该支持消息暂存功能
        SimpleMailbox(Int64(config.capacity))
    }

    /**
     * 创建零拷贝邮箱
     */
    private func createZeroCopyMailbox(config: MailboxConfig): Mailbox {
        // 简化实现：使用简单邮箱
        // 实际实现应该支持零拷贝优化
        SimpleMailbox(Int64(config.capacity))
    }

    /**
     * 创建Foundation邮箱
     */
    private func createFoundationMailbox(config: MailboxConfig): Mailbox {
        let capacity = if (config.capacity > 0) { Int64(config.capacity) } else { 10000 }
        SimpleMailbox(capacity)
    }
    
    /**
     * 初始化统计计数器
     */
    private func initializeCounters(): Unit {
        mailboxesByType.add("Unbounded", AtomicInt64(0))
        mailboxesByType.add("Bounded", AtomicInt64(0))
        mailboxesByType.add("Priority", AtomicInt64(0))
        mailboxesByType.add("Stashing", AtomicInt64(0))
        mailboxesByType.add("ZeroCopy", AtomicInt64(0))
        mailboxesByType.add("Foundation", AtomicInt64(0))
    }

    /**
     * 增加类型计数器
     */
    private func incrementTypeCounter(mailboxType: MailboxType): Unit {
        let typeName = mailboxTypeToString(mailboxType)
        match (mailboxesByType.get(typeName)) {
            case Some(counter) =>
                counter.fetchAdd(1)
            case None =>
                let newCounter = AtomicInt64(1)
                mailboxesByType.add(typeName, newCounter)
        }
    }

    /**
     * 将邮箱类型转换为字符串
     */
    private func mailboxTypeToString(mailboxType: MailboxType): String {
        match (mailboxType) {
            case MailboxType.Unbounded => "Unbounded"
            case MailboxType.Bounded => "Bounded"
            case MailboxType.Priority => "Priority"
            case MailboxType.Stashing => "Stashing"
            case MailboxType.ZeroCopy => "ZeroCopy"
            case MailboxType.Foundation => "Foundation"
        }
    }
}

/**
 * 简单的邮箱实现
 */
public class SimpleMailbox <: Mailbox {
    private let messages: ArrayList<Envelope>
    private let capacity: Int64
    private let mutex: Mutex

    public init(capacity: Int64) {
        this.messages = ArrayList<Envelope>()
        this.capacity = capacity
        this.mutex = Mutex()
    }

    public func enqueue(envelope: Envelope): Bool {
        mutex.lock()

        if (capacity > 0 && messages.size >= capacity) {
            mutex.unlock()
            return false
        }

        messages.add(envelope)
        mutex.unlock()
        return true
    }

    public func dequeue(): Option<Envelope> {
        mutex.lock()

        if (messages.isEmpty()) {
            mutex.unlock()
            return None<Envelope>
        }

        let envelope = messages[0]
        // 创建新的列表，移除第一个元素
        let newMessages = ArrayList<Envelope>()
        for (i in 1..messages.size) {
            newMessages.add(messages[i])
        }
        messages.clear()
        for (msg in newMessages) {
            messages.add(msg)
        }

        mutex.unlock()
        return Some(envelope)
    }

    public func isEmpty(): Bool {
        mutex.lock()
        let result = messages.isEmpty()
        mutex.unlock()
        return result
    }

    public func size(): Int64 {
        mutex.lock()
        let result = messages.size
        mutex.unlock()
        return result
    }

    public func clear(): Unit {
        mutex.lock()
        messages.clear()
        mutex.unlock()
    }
}
