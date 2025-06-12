/*
 * CActor 3.0 - 宏系统支持类型
 * Phase 1: 宏驱动的Actor DSL系统 - 支持类型
 */
package cactor.dsl

import std.collection.*
import std.sync.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 消息处理器定义
public class MessageHandler {
    public let messageType: String
    public let handlerName: String
    public let isAsync: Bool
    
    public init(messageType: String, handlerName: String, isAsync: Bool) {
        this.messageType = messageType
        this.handlerName = handlerName
        this.isAsync = isAsync
    }
    
    public func toString(): String {
        return "MessageHandler(${messageType}, ${handlerName}, ${isAsync})"
    }
}

// 路由表实现
public class RouteTable {
    private let routes: HashMap<String, MessageHandler>
    private let mutex: ReentrantMutex
    
    public init() {
        this.routes = HashMap<String, MessageHandler>()
        this.mutex = ReentrantMutex()
    }
    
    public func addRoute(messageType: String, handler: MessageHandler): Unit {
        mutex.lock()
        routes.put(messageType, handler)
        mutex.unlock()
    }
    
    public func getHandler(messageType: String): Option<MessageHandler> {
        mutex.lock()
        let result = routes.get(messageType)
        mutex.unlock()
        return result
    }
    
    public func getAllRoutes(): Array<(String, MessageHandler)> {
        mutex.lock()
        let result = ArrayList<(String, MessageHandler)>()
        for ((msgType, handler) in routes) {
            result.append((msgType, handler))
        }
        mutex.unlock()
        return result.toArray()
    }
    
    public func removeRoute(messageType: String): Unit {
        mutex.lock()
        routes.remove(messageType)
        mutex.unlock()
    }
    
    public func clear(): Unit {
        mutex.lock()
        routes.clear()
        mutex.unlock()
    }
    
    public func size(): Int64 {
        mutex.lock()
        let result = routes.size
        mutex.unlock()
        return result
    }
}

// Actor性能指标
public class ActorMetrics {
    private var messageCount: AtomicInt64
    private var totalProcessingTime: AtomicInt64
    private var errorCount: AtomicInt64
    private var lastMessageTime: AtomicInt64
    private let messageTypeStats: HashMap<String, MessageTypeStats>
    
    public init() {
        this.messageCount = AtomicInt64(0)
        this.totalProcessingTime = AtomicInt64(0)
        this.errorCount = AtomicInt64(0)
        this.lastMessageTime = AtomicInt64(0)
        this.messageTypeStats = HashMap<String, MessageTypeStats>()
    }
    
    public func recordMessage(messageType: String, processingTime: Int64, success: Bool): Unit {
        messageCount.store(messageCount.load() + 1)
        totalProcessingTime.store(totalProcessingTime.load() + processingTime)
        lastMessageTime.store(getCurrentTimeMillis())
        
        if (!success) {
            errorCount.store(errorCount.load() + 1)
        }
        
        // 记录消息类型统计
        let stats = match (messageTypeStats.get(messageType)) {
            case Some(s) => s
            case None =>
                let newStats = MessageTypeStats()
                messageTypeStats.put(messageType, newStats)
                newStats
        }
        stats.recordMessage(processingTime, success)
    }
    
    public func getMessageCount(): Int64 {
        return messageCount.load()
    }
    
    public func getTotalProcessingTime(): Int64 {
        return totalProcessingTime.load()
    }
    
    public func getAverageProcessingTime(): Float64 {
        let count = messageCount.load()
        if (count == 0) {
            return 0.0
        }
        return Float64(totalProcessingTime.load()) / Float64(count)
    }
    
    public func getErrorCount(): Int64 {
        return errorCount.load()
    }
    
    public func getErrorRate(): Float64 {
        let count = messageCount.load()
        if (count == 0) {
            return 0.0
        }
        return Float64(errorCount.load()) / Float64(count)
    }
    
    public func getLastMessageTime(): Int64 {
        return lastMessageTime.load()
    }
    
    public func getMessageTypeStats(): HashMap<String, MessageTypeStats> {
        let result = HashMap<String, MessageTypeStats>()
        for ((msgType, stats) in messageTypeStats) {
            result.put(msgType, stats)
        }
        return result
    }
    
    public func reset(): Unit {
        messageCount.store(0)
        totalProcessingTime.store(0)
        errorCount.store(0)
        lastMessageTime.store(0)
        messageTypeStats.clear()
    }
    
    public func toString(): String {
        return "ActorMetrics(messages=${getMessageCount()}, avgTime=${getAverageProcessingTime()}ms, errorRate=${getErrorRate()})"
    }
}

// 消息类型统计
public class MessageTypeStats {
    private var count: AtomicInt64
    private var totalTime: AtomicInt64
    private var errorCount: AtomicInt64
    private var minTime: AtomicInt64
    private var maxTime: AtomicInt64
    
    public init() {
        this.count = AtomicInt64(0)
        this.totalTime = AtomicInt64(0)
        this.errorCount = AtomicInt64(0)
        this.minTime = AtomicInt64(9223372036854775807)
        this.maxTime = AtomicInt64(0)
    }
    
    public func recordMessage(processingTime: Int64, success: Bool): Unit {
        count.store(count.load() + 1)
        totalTime.store(totalTime.load() + processingTime)

        if (!success) {
            errorCount.store(errorCount.load() + 1)
        }
        
        // 更新最小和最大时间
        updateMinTime(processingTime)
        updateMaxTime(processingTime)
    }
    
    private func updateMinTime(time: Int64): Unit {
        let currentMin = minTime.load()
        if (time < currentMin) {
            minTime.store(time)
        }
    }

    private func updateMaxTime(time: Int64): Unit {
        let currentMax = maxTime.load()
        if (time > currentMax) {
            maxTime.store(time)
        }
    }
    
    public func getCount(): Int64 {
        return count.load()
    }
    
    public func getTotalTime(): Int64 {
        return totalTime.load()
    }
    
    public func getAverageTime(): Float64 {
        let c = count.load()
        if (c == 0) {
            return 0.0
        }
        return Float64(totalTime.load()) / Float64(c)
    }
    
    public func getMinTime(): Int64 {
        let min = minTime.load()
        return if (min == 9223372036854775807) { 0 } else { min }
    }
    
    public func getMaxTime(): Int64 {
        return maxTime.load()
    }
    
    public func getErrorCount(): Int64 {
        return errorCount.load()
    }
    
    public func getErrorRate(): Float64 {
        let c = count.load()
        if (c == 0) {
            return 0.0
        }
        return Float64(errorCount.load()) / Float64(c)
    }
    
    public func toString(): String {
        return "MessageTypeStats(count=${getCount()}, avgTime=${getAverageTime()}ms, errorRate=${getErrorRate()})"
    }
}

// Actor系统引用 - 简化版本
public class ActorSystem {
    private static var instance: Option<ActorSystem> = None<ActorSystem>
    private let actors: HashMap<String, Actor>
    private let mutex: ReentrantMutex
    
    private init() {
        this.actors = HashMap<String, Actor>()
        this.mutex = ReentrantMutex()
    }
    
    public static func getInstance(): ActorSystem {
        match (instance) {
            case Some(system) => system
            case None =>
                let system = ActorSystem()
                instance = Some(system)
                return system
        }
    }
    
    public static func `spawn`(actor: Actor): ActorRef {
        let system = getInstance()
        let actorId = "actor_" + system.actors.size.toString()
        system.actors.put(actorId, actor)
        return ActorRef(actorId, actor)
    }
    
    public func getActor(actorId: String): Option<Actor> {
        return actors.get(actorId)
    }
    
    public func removeActor(actorId: String): Unit {
        actors.remove(actorId)
    }
    
    public func getAllActors(): Array<Actor> {
        let result = ArrayList<Actor>()
        for ((_, actor) in actors) {
            result.append(actor)
        }
        return result.toArray()
    }
    
    public func shutdown(): Unit {
        actors.clear()
        instance = None<ActorSystem>
    }
}

// Actor引用 - 简化版本
public class ActorRef {
    public let actorId: String
    private let actor: Actor
    
    public init(actorId: String, actor: Actor) {
        this.actorId = actorId
        this.actor = actor
    }
    
    public func tell(message: Message): Unit {
        let context = SimpleActorContext(this)
        // 简化实现：直接打印消息
        println("Actor ${actorId} 收到消息")
    }
    
    public func getActor(): Actor {
        return actor
    }
    
    public func stop(): Unit {
        ActorSystem.getInstance().removeActor(actorId)
    }
}

// 简化的Actor上下文
public class SimpleActorContext <: ActorContext {
    private let self: ActorRef

    public init(self: ActorRef) {
        this.self = self
    }

    public func sender(): Option<String> {
        return None<String>
    }

    public func getSelf(): ActorRef {
        return self
    }

    public func getSender(): Option<ActorRef> {
        return None<ActorRef>
    }

    public func getSystem(): ActorSystem {
        return ActorSystem.getInstance()
    }
}

// 辅助函数
func getCurrentTimeMillis(): Int64 {
    // 简化实现，实际应该调用系统时间API
    return 1000
}
