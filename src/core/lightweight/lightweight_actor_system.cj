/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 4: 轻量级Actor系统管理器
 * 内存优化的Actor系统，支持大规模Actor创建和管理
 */
package cactor.core.lightweight

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.dispatcher.optimized.*

/**
 * 轻量级Actor系统配置
 */
public struct LightweightActorSystemConfig {
    public let maxActors: Int64
    public let contextPoolSize: Int64
    public let bufferPoolAlignment: Int64
    public let enableMemoryCompression: Bool
    public let enableObjectPooling: Bool
    public let gcOptimizationLevel: Int32
    
    public init(maxActors: Int64, contextPoolSize: Int64, bufferPoolAlignment: Int64,
                enableMemoryCompression: Bool, enableObjectPooling: Bool, gcOptimizationLevel: Int32) {
        this.maxActors = maxActors
        this.contextPoolSize = contextPoolSize
        this.bufferPoolAlignment = bufferPoolAlignment
        this.enableMemoryCompression = enableMemoryCompression
        this.enableObjectPooling = enableObjectPooling
        this.gcOptimizationLevel = gcOptimizationLevel
    }
    
    public static func createDefault(): LightweightActorSystemConfig {
        LightweightActorSystemConfig(
            1000000,  // 支持100万个Actor
            10000,    // 1万个上下文池
            64,       // 64字节对齐
            true,     // 启用内存压缩
            true,     // 启用对象池化
            2         // 中等GC优化级别
        )
    }
    
    public static func createHighDensity(): LightweightActorSystemConfig {
        LightweightActorSystemConfig(
            10000000, // 支持1000万个Actor
            50000,    // 5万个上下文池
            64,       // 64字节对齐
            true,     // 启用内存压缩
            true,     // 启用对象池化
            3         // 高级GC优化级别
        )
    }
}

/**
 * Actor行为接口
 */
public interface ActorBehavior {
    func receive(message: Message, context: PooledContext): MessageResult
}

/**
 * 消息处理结果
 */
public enum MessageResult {
    | Handled      // 消息已处理
    | Unhandled    // 消息未处理
    | Failed       // 处理失败
}

/**
 * 轻量级Actor系统
 * 支持大规模Actor创建，每个Actor内存占用<1KB
 */
public class LightweightActorSystem {
    private let config: LightweightActorSystemConfig
    private let actors: HashMap<String, LightweightActor>
    private let contextPool: ContextPool
    private let bufferPool: AlignedBufferPool
    private let dispatcher: OptimizedWorkStealingDispatcher
    private let actorCount: AtomicInt64
    private let messageCount: AtomicInt64
    private let errorCount: AtomicInt64
    private let startTime: Int64
    private let isRunning: AtomicBool
    private let systemMutex: ReentrantMutex
    
    public init(config: LightweightActorSystemConfig) {
        this.config = config
        this.actors = HashMap<String, LightweightActor>()
        this.contextPool = ContextPool(config.contextPoolSize)
        this.bufferPool = AlignedBufferPool(config.bufferPoolAlignment)
        this.dispatcher = OptimizedWorkStealingDispatcher.createHighThroughput()
        this.actorCount = AtomicInt64(0)
        this.messageCount = AtomicInt64(0)
        this.errorCount = AtomicInt64(0)
        this.startTime = getCurrentTimeNanos()
        this.isRunning = AtomicBool(false)
        this.systemMutex = ReentrantMutex()
    }
    
    public static func create(): LightweightActorSystem {
        LightweightActorSystem(LightweightActorSystemConfig.createDefault())
    }
    
    public static func createHighDensity(): LightweightActorSystem {
        LightweightActorSystem(LightweightActorSystemConfig.createHighDensity())
    }
    
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            dispatcher.start()
            println("轻量级Actor系统启动")
            println("  最大Actor数: ${config.maxActors}")
            println("  上下文池大小: ${config.contextPoolSize}")
            println("  内存压缩: ${config.enableMemoryCompression}")
            println("  对象池化: ${config.enableObjectPooling}")
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            // 停止所有Actor
            systemMutex.lock()
            for ((actorId, actor) in actors) {
                actor.stop()
            }
            actors.clear()
            systemMutex.unlock()
            
            dispatcher.stop()
            
            // 清理资源池
            contextPool.clear()
            bufferPool.clear()
            
            println("轻量级Actor系统停止")
            printSystemStats()
        }
    }
    
    public func createActor(actorId: String, behavior: ActorBehavior): Option<LightweightActorRef> {
        if (!isRunning.load()) {
            return None
        }
        
        if (actorCount.load() >= config.maxActors) {
            println("警告：已达到最大Actor数量限制")
            return None
        }
        
        systemMutex.lock()
        
        if (actors.containsKey(actorId)) {
            systemMutex.unlock()
            return None  // Actor已存在
        }
        
        let actor = LightweightActor(actorId, behavior, contextPool)
        actors.put(actorId, actor)
        actorCount.fetchAdd(1)
        
        systemMutex.unlock()
        
        actor.start()
        return Some(LightweightActorRef(actorId, actor))
    }
    
    public func getActor(actorId: String): Option<LightweightActorRef> {
        systemMutex.lock()
        let actorOpt = actors.get(actorId)
        systemMutex.unlock()
        
        match (actorOpt) {
            case Some(actor) => Some(LightweightActorRef(actorId, actor))
            case None => None
        }
    }
    
    public func removeActor(actorId: String): Bool {
        systemMutex.lock()
        
        match (actors.get(actorId)) {
            case Some(actor) =>
                actor.stop()
                actors.remove(actorId)
                actorCount.fetchAdd(-1)
                systemMutex.unlock()
                return true
            case None =>
                systemMutex.unlock()
                return false
        }
    }
    
    public func sendMessage(actorId: String, message: Message): Bool {
        match (getActor(actorId)) {
            case Some(actorRef) =>
                actorRef.tell(message)
                messageCount.fetchAdd(1)
                return true
            case None =>
                return false
        }
    }
    
    public func processMessages(): Unit {
        systemMutex.lock()
        for ((actorId, actor) in actors) {
            try {
                actor.processMessages()
            } catch (e: Exception) {
                errorCount.fetchAdd(1)
                println("Actor ${actorId} 处理消息时出错: ${e}")
            }
        }
        systemMutex.unlock()
    }
    
    public func getSystemStats(): LightweightSystemStats {
        let currentTime = getCurrentTimeNanos()
        let runTime = currentTime - startTime
        let runTimeSeconds = Float64(runTime) / 1000000000.0
        
        let totalMemory = calculateTotalMemoryUsage()
        let avgMemoryPerActor = if (actorCount.load() > 0) {
            totalMemory / actorCount.load()
        } else {
            0
        }
        
        LightweightSystemStats(
            actorCount.load(),
            messageCount.load(),
            errorCount.load(),
            totalMemory,
            avgMemoryPerActor,
            runTimeSeconds,
            contextPool.getStats(),
            bufferPool.getAllStats()
        )
    }
    
    private func calculateTotalMemoryUsage(): Int64 {
        var totalMemory: Int64 = 0
        
        systemMutex.lock()
        for ((actorId, actor) in actors) {
            totalMemory += actor.getMemoryFootprint()
        }
        systemMutex.unlock()
        
        // 加上系统开销
        totalMemory += 1024 * 1024  // 1MB系统开销
        
        return totalMemory
    }
    
    private func printSystemStats(): Unit {
        let stats = getSystemStats()
        
        println("=== 轻量级Actor系统统计 ===")
        println("运行时间: ${stats.runTimeSeconds}秒")
        println("Actor数量: ${stats.actorCount}")
        println("处理消息数: ${stats.messageCount}")
        println("错误数: ${stats.errorCount}")
        println("总内存使用: ${stats.totalMemory / 1024}KB")
        println("平均每Actor内存: ${stats.avgMemoryPerActor}字节")
        
        let contextStats = stats.contextPoolStats
        println("\n上下文池统计:")
        println("  容量: ${contextStats.capacity}")
        println("  当前大小: ${contextStats.currentSize}")
        println("  命中率: ${contextStats.getHitRate() * 100.0}%")
        println("  利用率: ${contextStats.getUtilization() * 100.0}%")
        
        println("\n缓冲区池统计:")
        for (i in 0..Int64(stats.bufferPoolStats.size)) {
            let bufferStats = stats.bufferPoolStats[i]
            println("  大小类别${i}: 命中率=${bufferStats.getHitRate() * 100.0}%, " +
                   "利用率=${bufferStats.getUtilization() * 100.0}%")
        }
    }
    
    public func getConfig(): LightweightActorSystemConfig {
        config
    }
    
    public func getActorCount(): Int64 {
        actorCount.load()
    }
    
    public func getMessageCount(): Int64 {
        messageCount.load()
    }
    
    public func isSystemRunning(): Bool {
        isRunning.load()
    }
}

/**
 * 轻量级系统统计信息
 */
public struct LightweightSystemStats {
    public let actorCount: Int64
    public let messageCount: Int64
    public let errorCount: Int64
    public let totalMemory: Int64
    public let avgMemoryPerActor: Int64
    public let runTimeSeconds: Float64
    public let contextPoolStats: PoolStats
    public let bufferPoolStats: Array<PoolStats>
    
    public init(actorCount: Int64, messageCount: Int64, errorCount: Int64,
                totalMemory: Int64, avgMemoryPerActor: Int64, runTimeSeconds: Float64,
                contextPoolStats: PoolStats, bufferPoolStats: Array<PoolStats>) {
        this.actorCount = actorCount
        this.messageCount = messageCount
        this.errorCount = errorCount
        this.totalMemory = totalMemory
        this.avgMemoryPerActor = avgMemoryPerActor
        this.runTimeSeconds = runTimeSeconds
        this.contextPoolStats = contextPoolStats
        this.bufferPoolStats = bufferPoolStats
    }
    
    public func getMemoryEfficiency(): Float64 {
        // 内存效率：目标是每个Actor<1KB
        let targetMemoryPerActor: Int64 = 1024
        if (avgMemoryPerActor <= targetMemoryPerActor) {
            return 1.0  // 100%效率
        } else {
            return Float64(targetMemoryPerActor) / Float64(avgMemoryPerActor)
        }
    }
    
    public func getErrorRate(): Float64 {
        if (messageCount == 0) {
            return 0.0
        }
        return Float64(errorCount) / Float64(messageCount)
    }
}

func getCurrentTimeNanos(): Int64 {
    let now = DateTime.now()
    return now.toUnixTimeStamp().toMilliseconds() * 1000000
}
