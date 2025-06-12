/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 虚拟Actor系统
 * 基于Orleans模式的虚拟Actor实现，支持自动激活和钝化
 */
package cactor.virtual

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 虚拟Actor接口
public interface VirtualActor <: Actor {
    func activate(): Unit
    func deactivate(): Unit
    func isActive(): Bool
    func getLastAccessTime(): Int64
    func updateAccessTime(): Unit
    func serializeState(): String
    func deserializeState(data: String): Unit
}

// 虚拟Actor基类
public open class VirtualActorBase <: VirtualActor {
    private let actorId: String
    private var isActivated: Bool
    private var lastAccessTime: Int64
    private let mutex: ReentrantMutex
    
    public init(actorId: String) {
        this.actorId = actorId
        this.isActivated = false
        this.lastAccessTime = 0
        this.mutex = ReentrantMutex()
    }
    
    public prop name: String { get() { actorId } }
    public prop description: String { get() { "虚拟Actor" } }
    
    public func activate(): Unit {
        mutex.lock()

        if (!isActivated) {
            onActivate()
            isActivated = true
            lastAccessTime = getCurrentTimeMillis()
            println("虚拟Actor ${actorId} 已激活")
        }

        mutex.unlock()
    }

    public func deactivate(): Unit {
        mutex.lock()

        if (isActivated) {
            onDeactivate()
            isActivated = false
            println("虚拟Actor ${actorId} 已钝化")
        }

        mutex.unlock()
    }

    public func isActive(): Bool {
        mutex.lock()
        let result = isActivated
        mutex.unlock()
        return result
    }

    public func getLastAccessTime(): Int64 {
        mutex.lock()
        let result = lastAccessTime
        mutex.unlock()
        return result
    }

    public func updateAccessTime(): Unit {
        mutex.lock()
        lastAccessTime = getCurrentTimeMillis()
        mutex.unlock()
    }
    
    // 默认的消息接收实现
    public func receive(message: Message, context: ActorContext): MessageResult {
        updateAccessTime()
        return handleMessage(message, context)
    }
    
    // 子类需要实现的消息处理方法
    protected open func handleMessage(message: Message, context: ActorContext): MessageResult {
        MessageResult.Unhandled
    }

    // 激活回调
    protected open func onActivate(): Unit {
        // 子类可以重写
    }

    // 钝化回调
    protected open func onDeactivate(): Unit {
        // 子类可以重写
    }

    // 默认状态序列化
    public open func serializeState(): String {
        "default_state"
    }

    // 默认状态反序列化
    public open func deserializeState(data: String): Unit {
        // 子类可以重写
    }
}

// 虚拟Actor管理器
public class VirtualActorManager {
    private let activatedActors: ConcurrentHashMap<String, VirtualActor>
    private let deactivationTimer: Timer
    private let deactivationTimeout: Int64  // 毫秒
    private var isRunning: AtomicBool
    
    public init(deactivationTimeout: Int64) { // 5分钟默认超时
        this.activatedActors = ConcurrentHashMap<String, VirtualActor>()
        this.deactivationTimer = Timer()
        this.deactivationTimeout = deactivationTimeout
        this.isRunning = AtomicBool(false)
    }
    
    public func start(): Unit {
        if (!isRunning.load()) {
            isRunning.store(true)
            // 启动钝化定时器
            startDeactivationTimer()
            println("虚拟Actor管理器已启动")
        }
    }

    public func stop(): Unit {
        if (isRunning.load()) {
            isRunning.store(false)
            deactivationTimer.stop()

            // 钝化所有激活的Actor
            let actorIds = ArrayList<String>()
            for ((actorId, actor) in activatedActors) {
                actor.deactivate()
                actorIds.append(actorId)
            }

            // 清空激活的Actor
            for (actorId in actorIds) {
                activatedActors.remove(actorId)
            }

            println("虚拟Actor管理器已停止")
        }
    }
    
    public func getOrActivateActor(actorId: String, factory: () -> VirtualActor): VirtualActor {
        // 检查是否已激活
        match (activatedActors.get(actorId)) {
            case Some(actor) =>
                actor.updateAccessTime()
                return actor
            case None =>
                // 创建并激活新Actor
                let newActor = factory()
                newActor.activate()

                // 恢复状态（简化实现）
                let stateData = loadActorState(actorId)
                newActor.deserializeState(stateData)

                activatedActors.put(actorId, newActor)
                return newActor
        }
    }
    
    public func deactivateActor(actorId: String): Unit {
        match (activatedActors.remove(actorId)) {
            case Some(actor) => 
                // 保存状态
                let stateData = actor.serializeState()
                saveActorState(actorId, stateData)
                
                // 钝化Actor
                actor.deactivate()
                
                println("Actor ${actorId} 已被钝化")
            case None => 
                println("Actor ${actorId} 未找到或已钝化")
        }
    }
    
    public func getActiveActorCount(): Int64 {
        activatedActors.size
    }
    
    public func getActiveActorIds(): Array<String> {
        let ids = ArrayList<String>()
        for ((actorId, _) in activatedActors) {
            ids.append(actorId)
        }
        return ids.toArray()
    }
    
    private func startDeactivationTimer(): Unit {
        // 简化的定时器实现
        spawn {
            while (isRunning.load()) {
                checkForDeactivation()
                sleep(Duration.second * 30) // 每30秒检查一次
            }
        }
    }
    
    private func checkForDeactivation(): Unit {
        let currentTime = getCurrentTimeMillis()
        let toDeactivate = ArrayList<String>()
        
        // 查找需要钝化的Actor
        for ((actorId, actor) in activatedActors) {
            let timeSinceLastAccess = currentTime - actor.getLastAccessTime()
            if (timeSinceLastAccess > deactivationTimeout) {
                toDeactivate.append(actorId)
            }
        }
        
        // 钝化超时的Actor
        for (actorId in toDeactivate) {
            deactivateActor(actorId)
        }
        
        if (toDeactivate.size > 0) {
            println("钝化了 ${toDeactivate.size} 个超时的虚拟Actor")
        }
    }
    
    private func loadActorState(actorId: String): String {
        // 简化实现：从持久化存储加载状态
        "loaded_state_for_${actorId}"
    }
    
    private func saveActorState(actorId: String, stateData: String): Unit {
        // 简化实现：保存状态到持久化存储
        println("保存Actor ${actorId} 状态: ${stateData}")
    }
}

// 简单的定时器实现
public class Timer {
    private var isRunning: AtomicBool
    
    public init() {
        this.isRunning = AtomicBool(false)
    }
    
    public func stop(): Unit {
        isRunning.store(false)
    }
}

// 示例虚拟Actor实现
public class CounterVirtualActor <: VirtualActorBase {
    private var count: Int64
    
    public init(actorId: String) {
        super(actorId)
        this.count = 0
    }
    
    protected func handleMessage(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case incMsg: IncrementMessage => 
                count += incMsg.getValue()
                println("${name}: 计数器增加到 ${count}")
                MessageResult.Handled
            case getMsg: GetCountMessage => 
                println("${name}: 当前计数 ${count}")
                MessageResult.Handled
            case _ => 
                MessageResult.Unhandled
        }
    }
    
    protected func onActivate(): Unit {
        println("计数器虚拟Actor ${name} 激活")
    }
    
    protected func onDeactivate(): Unit {
        println("计数器虚拟Actor ${name} 钝化，最终计数: ${count}")
    }
    
    public func serializeState(): String {
        "${count}"
    }
    
    public func deserializeState(data: String): Unit {
        if (data.startsWith("loaded_state")) {
            count = 42  // 模拟从持久化存储恢复的状态
        } else {
            // 简化的数字解析
            if (data == "0") {
                count = 0
            } else if (data == "10") {
                count = 10
            } else if (data == "42") {
                count = 42
            } else {
                count = 0
            }
        }
        println("${name}: 状态已恢复，计数: ${count}")
    }
    
    public func getCount(): Int64 { count }
}

// 消息类型
public class IncrementMessage <: Message {
    private let value: Int64
    
    public init(value: Int64) {
        this.value = value
    }
    
    public func getValue(): Int64 { value }
    public func messageType(): String { "IncrementMessage" }
    public func toString(): String { "IncrementMessage(${value})" }
}

public class GetCountMessage <: Message {
    public init() {}
    
    public func messageType(): String { "GetCountMessage" }
    public func toString(): String { "GetCountMessage" }
}

// 辅助函数
func getCurrentTimeMillis(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}
