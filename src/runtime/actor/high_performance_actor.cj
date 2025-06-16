/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - 高性能Actor实现
 * 基于tu.md优化计划的高性能Actor系统
 * 从Core层移动到Runtime层
 */
package cactor.runtime.actor

import std.sync.*
import std.time.*
import cactor.core.actor.{Actor}
import cactor.core.message.*
import cactor.core.context.*
import cactor.runtime.mailbox.{Mailbox, FoundationMailbox}
// import cactor.runtime.context.pooled_actor_context.{PooledActorContext, PooledActorContextPool}
import cactor.foundation.memory.*

/**
 * 压缩Actor状态 - 8字节紧凑表示
 * 使用位字段技术压缩状态信息
 */
public struct CompactActorState {
    // 状态标志位组合 (32位)
    private let stateFlags: UInt32
    // 消息计数 (16位) + 错误计数 (8位) + 优先级 (8位)
    private let countersAndPriority: UInt32
    
    // 状态标志位常量
    public static let RUNNING_FLAG: UInt32 = 0x01
    public static let SUSPENDED_FLAG: UInt32 = 0x02
    public static let STOPPED_FLAG: UInt32 = 0x04
    public static let FAILED_FLAG: UInt32 = 0x08
    public static let RESTARTING_FLAG: UInt32 = 0x10
    public static let HIGH_PRIORITY_FLAG: UInt32 = 0x20
    
    public init() {
        this.stateFlags = 0
        this.countersAndPriority = 0
    }
    
    public init(flags: UInt32, messageCount: UInt16, errorCount: UInt8, priority: UInt8) {
        this.stateFlags = flags
        this.countersAndPriority = (UInt32(messageCount) << 16) | (UInt32(errorCount) << 8) | UInt32(priority)
    }
    
    public func isRunning(): Bool {
        (stateFlags & CompactActorState.RUNNING_FLAG) != 0
    }
    
    public func isSuspended(): Bool {
        (stateFlags & CompactActorState.SUSPENDED_FLAG) != 0
    }
    
    public func isStopped(): Bool {
        (stateFlags & CompactActorState.STOPPED_FLAG) != 0
    }
    
    public func getMessageCount(): UInt16 {
        UInt16((countersAndPriority >> 16) & 0xFFFF)
    }
    
    public func getErrorCount(): UInt8 {
        UInt8((countersAndPriority >> 8) & 0xFF)
    }
    
    public func getPriority(): UInt8 {
        UInt8(countersAndPriority & 0xFF)
    }
    
    public func withRunning(running: Bool): CompactActorState {
        let newFlags = if (running) {
            stateFlags | CompactActorState.RUNNING_FLAG
        } else {
            stateFlags & (0xFFFFFFFF ^ CompactActorState.RUNNING_FLAG)
        }
        CompactActorState(newFlags, getMessageCount(), getErrorCount(), getPriority())
    }

    public func withStopped(): CompactActorState {
        let clearMask = 0xFFFFFFFF ^ (CompactActorState.RUNNING_FLAG | CompactActorState.SUSPENDED_FLAG)
        let newFlags = (stateFlags & clearMask) | CompactActorState.STOPPED_FLAG
        CompactActorState(newFlags, getMessageCount(), getErrorCount(), getPriority())
    }
    
    public func incrementMessageCount(): CompactActorState {
        let newCount = getMessageCount() + 1
        CompactActorState(stateFlags, newCount, getErrorCount(), getPriority())
    }
    
    public func incrementErrorCount(): CompactActorState {
        let newErrorCount = getErrorCount() + 1
        CompactActorState(stateFlags, getMessageCount(), newErrorCount, getPriority())
    }
}

/**
 * 高性能Actor行为接口
 * 优化的消息处理接口
 */
public interface HighPerformanceActorBehavior {
    /**
     * 高性能消息处理
     * 使用池化上下文减少内存分配
     */
    func receive(message: Message, context: PooledActorContext): MessageResult
    
    /**
     * 批量消息处理 - 提升吞吐量
     */
    func receiveBatch(messages: Array<Message>, context: PooledActorContext): Array<MessageResult> {
        // 默认实现：逐个处理
        let results = Array<MessageResult>(messages.size, { i => MessageResult.Unhandled })
        for (i in 0..messages.size) {
            results[i] = receive(messages[i], context)
        }
        return results
    }
    
    /**
     * 预处理钩子 - 在消息处理前调用
     */
    func preProcess(message: Message): Bool {
        true  // 默认允许处理
    }
    
    /**
     * 后处理钩子 - 在消息处理后调用
     */
    func postProcess(message: Message, result: MessageResult): Unit {
        // 默认空实现
    }
}

// 简化时间函数
func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    now.toUnixTimeStamp().toMilliseconds() * 1000000
}

/**
 * 高性能Actor实现
 * 基于tu.md优化计划：64字节内存占用，无锁邮箱，对象池化
 */
public class HighPerformanceActor <: Actor {
    // 核心状态 (8字节) - 使用原子整数代替
    private let stateValue: AtomicInt64
    
    // Actor标识 (8字节指针)
    private let actorId: String
    
    // 高性能无锁邮箱 (8字节指针)
    private let mailbox: FoundationMailbox
    
    // Actor行为 (8字节指针)
    private let behavior: HighPerformanceActorBehavior
    
    // 池化上下文 (8字节指针)
    private let contextPool: ObjectPool<PooledActorContext>
    
    // 性能统计 (8字节)
    private let stats: AtomicInt64  // 打包：处理消息数(32位) + 错误数(16位) + 其他(16位)
    
    // 创建时间戳 (8字节)
    private let createdAt: Int64
    
    // 最后活跃时间 (8字节) - 总计64字节
    private let lastActiveTime: AtomicInt64
    
    public init(actorId: String, behavior: HighPerformanceActorBehavior, contextPool: ObjectPool<PooledActorContext>) {
        this.actorId = actorId
        this.behavior = behavior
        this.contextPool = contextPool
        this.stateValue = AtomicInt64(1)  // 1表示运行状态
        this.mailbox = FoundationMailbox(1024, true)  // 1K容量，适合高吞吐量
        this.stats = AtomicInt64(0)
        this.createdAt = getCurrentTimeNanos()
        this.lastActiveTime = AtomicInt64(getCurrentTimeNanos())
    }
    
    public prop name: String {
        get() { actorId }
    }
    
    public prop description: String {
        get() { "HighPerformanceActor(${actorId})" }
    }
    
    /**
     * 高性能消息处理
     * 优化路径：无锁邮箱 + 池化上下文 + 压缩状态
     */
    public func receive(message: Message, context: ActorContext): MessageResult {
        // 快速状态检查
        let currentStateValue = stateValue.load()
        if (currentStateValue != 1) {  // 1表示运行状态
            return MessageResult.Unhandled
        }
        
        // 获取池化上下文
        let pooledContext = contextPool.acquire()
        
        // 预处理检查
        if (!behavior.preProcess(message)) {
            contextPool.release(pooledContext)
            return MessageResult.Unhandled
        }
        
        // 处理消息
        let result = behavior.receive(message, pooledContext)
        
        // 后处理
        behavior.postProcess(message, result)
        
        // 更新统计信息
        updateStats(result)
        
        // 释放池化上下文
        contextPool.release(pooledContext)
        
        // 更新最后活跃时间
        lastActiveTime.store(getCurrentTimeNanos())
        
        return result
    }

    /**
     * 启动Actor
     */
    public func start(): Unit {
        stateValue.store(1)  // 1表示运行状态
        behavior.preProcess(StartMessage())
    }

    /**
     * 停止Actor
     */
    public func stop(): Unit {
        stateValue.store(0)  // 0表示停止状态
        behavior.postProcess(StopMessage(), MessageResult.Stop)
    }

    /**
     * 高性能消息发送
     * 直接使用无锁邮箱
     */
    public func tell(message: Message): Unit {
        let envelope = Envelope(message, None)
        if (!mailbox.enqueue(envelope)) {
            // 邮箱满，记录错误
            incrementErrorCount()
        }
    }

    /**
     * 批量消息处理 - 提升吞吐量
     */
    public func processBatch(batchSize: Int32): Int32 {
        let messages = Array<Message>(Int64(batchSize), { i => StringMessage("") })
        var processedCount: Int32 = 0

        // 批量出队
        for (i in 0..Int64(batchSize)) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    messages[i] = envelope.getMessage()
                    processedCount += 1
                case None =>
                    break
            }
        }

        if (processedCount > 0) {
            // 获取池化上下文
            let pooledContext = contextPool.acquire()

            // 批量处理
            let batchMessages = messages.slice(0, Int64(processedCount))
            let results = behavior.receiveBatch(batchMessages, pooledContext)

            // 批量更新统计
            for (result in results) {
                updateStats(result)
            }

            // 释放池化上下文
            contextPool.release(pooledContext)

            // 更新最后活跃时间
            lastActiveTime.store(getCurrentTimeNanos())
        }

        return processedCount
    }

    /**
     * 获取Actor状态值
     */
    public func getStateValue(): Int64 {
        stateValue.load()
    }

    /**
     * 获取性能统计
     */
    public func getStats(): ActorStats {
        let statsValue = stats.load()
        let processedMessages = UInt32((statsValue >> 32) & 0xFFFFFFFF)
        let errorCount = UInt16((statsValue >> 16) & 0xFFFF)
        let otherStats = UInt16(statsValue & 0xFFFF)

        ActorStats(
            processedMessages,
            errorCount,
            createdAt,
            lastActiveTime.load(),
            mailbox.size()
        )
    }

    /**
     * 更新统计信息
     */
    private func updateStats(result: MessageResult): Unit {
        let currentStats = stats.load()
        let processedMessages = UInt32((currentStats >> 32) & 0xFFFFFFFF) + 1
        let errorCount = match (result) {
            case MessageResult.Unhandled => UInt16((currentStats >> 16) & 0xFFFF) + 1
            case _ => UInt16((currentStats >> 16) & 0xFFFF)
        }
        let otherStats = UInt16(currentStats & 0xFFFF)

        let newStats = (Int64(processedMessages) << 32) | (Int64(errorCount) << 16) | Int64(otherStats)
        stats.store(newStats)
    }

    /**
     * 增加错误计数
     */
    private func incrementErrorCount(): Unit {
        let currentStats = stats.load()
        let errorCount = UInt16((currentStats >> 16) & 0xFFFF) + 1
        let processedMessages = UInt32((currentStats >> 32) & 0xFFFFFFFF)
        let otherStats = UInt16(currentStats & 0xFFFF)

        let newStats = (Int64(processedMessages) << 32) | (Int64(errorCount) << 16) | Int64(otherStats)
        stats.store(newStats)
    }
}

/**
 * Actor性能统计
 */
public struct ActorStats {
    public let processedMessages: UInt32
    public let errorCount: UInt16
    public let createdAt: Int64
    public let lastActiveTime: Int64
    public let mailboxSize: Int64

    public init(processedMessages: UInt32, errorCount: UInt16, createdAt: Int64, lastActiveTime: Int64, mailboxSize: Int64) {
        this.processedMessages = processedMessages
        this.errorCount = errorCount
        this.createdAt = createdAt
        this.lastActiveTime = lastActiveTime
        this.mailboxSize = mailboxSize
    }

    public func getSuccessRate(): Float64 {
        if (processedMessages == 0) {
            return 100.0
        }
        return (Float64(processedMessages - UInt32(errorCount)) / Float64(processedMessages)) * 100.0
    }

    public func getAgeInSeconds(): Float64 {
        Float64(getCurrentTimeNanos() - createdAt) / 1000000000.0
    }

    public func getIdleTimeInSeconds(): Float64 {
        Float64(getCurrentTimeNanos() - lastActiveTime) / 1000000000.0
    }
}

/**
 * 启动消息
 */
public struct StartMessage <: SystemMessage {
    public init() {}

    public func messageType(): String {
        "StartMessage"
    }
}

/**
 * 停止消息
 */
public struct StopMessage <: SystemMessage {
    public init() {}

    public func messageType(): String {
        "StopMessage"
    }
}
