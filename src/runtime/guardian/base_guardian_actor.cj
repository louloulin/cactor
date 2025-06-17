/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - Guardian Actor基础实现
 * 从Core层移动到Runtime层的具体实现
 */
package cactor.runtime.guardian

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.guardian.{GuardianActor, GuardianType, GuardianStats, GuardianHealthStatus}
import cactor.core.supervision.{SupervisionStrategy, ActorFailure}
import cactor.core.guardian.{CreateChildMessage, StopChildMessage, RestartChildMessage}

/**
 * Guardian Actor基础实现
 * 从Core层移动到Runtime层，提供具体的Guardian功能实现
 */
public open class BaseGuardianActor <: GuardianActor {
    protected let children: HashMap<String, ActorRef>
    protected let supervisionStrategies: HashMap<String, SupervisionStrategy>
    protected let childCounter: AtomicInt64
    protected let restartCounter: AtomicInt64
    protected let stopCounter: AtomicInt64
    protected let failureCounter: AtomicInt64
    protected var lastFailureTime: Option<DateTime>
    protected let startTime: DateTime
    protected let guardianTypeValue: GuardianType
    protected let parentRef: Option<ActorRef>

    public init(guardianType: GuardianType, parent: Option<ActorRef>) {
        this.children = HashMap<String, ActorRef>()
        this.supervisionStrategies = HashMap<String, SupervisionStrategy>()
        this.childCounter = AtomicInt64(0)
        this.restartCounter = AtomicInt64(0)
        this.stopCounter = AtomicInt64(0)
        this.failureCounter = AtomicInt64(0)
        this.lastFailureTime = None<DateTime>
        this.startTime = DateTime.now()
        this.guardianTypeValue = guardianType
        this.parentRef = parent
    }

    // 实现GuardianActor接口属性
    public prop guardianType: GuardianType {
        get() { guardianTypeValue }
    }

    public prop parent: Option<ActorRef> {
        get() { parentRef }
    }
    
    public func createChild(props: Props<Actor>, name: String): ActorRef {
        // 检查名称是否已存在
        match (children.get(name)) {
            case Some(_) => throw Exception("子Actor名称 '${name}' 已存在")
            case None => ()
        }
        
        // 创建子Actor（由子类实现具体逻辑）
        let childRef = doCreateChild(props, name)
        
        // 注册子Actor
        children.put(name, childRef)
        childCounter.fetchAdd(1)
        
        return childRef
    }
    
    public func supervise(child: ActorRef, strategy: SupervisionStrategy): Unit {
        let childPath = child.path.toString()
        supervisionStrategies.put(childPath, strategy)
    }
    
    public func getChildren(): Array<ActorRef> {
        let childList = ArrayList<ActorRef>()
        for ((_, childRef) in children) {
            childList.append(childRef)
        }
        return childList.toArray()
    }

    public func findChild(name: String): Option<ActorRef> {
        children.get(name)
    }
    
    public func stopChild(child: ActorRef): Unit {
        let childPath = child.path.toString()
        
        // 从children中移除
        for ((name, childRef) in children) {
            if (childRef.path.toString() == childPath) {
                children.remove(name)
                break
            }
        }
        
        // 移除监督策略
        supervisionStrategies.remove(childPath)
        stopCounter.fetchAdd(1)
        
        // 执行停止逻辑（由子类实现）
        doStopChild(child)
    }
    
    public func restartChild(child: ActorRef, reason: Exception): Unit {
        restartCounter.fetchAdd(1)
        
        // 执行重启逻辑（由子类实现）
        doRestartChild(child, reason)
    }
    
    public func handleFailure(failure: ActorFailure): Unit {
        failureCounter.fetchAdd(1)
        lastFailureTime = Some(DateTime.now())

        // 默认实现：打印失败信息
        println("Guardian处理Actor失败: ${failure.actor.path.toString()}, 原因: ${failure.cause}")

        // 可以由子类重写以实现更复杂的失败处理逻辑
        doHandleFailure(failure)
    }

    /**
     * 获取Guardian统计信息
     */
    public func getStats(): GuardianStats {
        let currentTime = DateTime.now()
        let uptime = Duration.second * 1  // 简化实现，实际应该计算真实运行时间

        GuardianStats(
            childCounter.load(),
            Int64(children.size),
            restartCounter.load(),
            stopCounter.load(),
            failureCounter.load(),
            lastFailureTime,
            uptime
        )
    }

    public func getHealthStatus(): GuardianHealthStatus {
        let stats = getStats()

        // 简单的健康状态判断逻辑
        if (stats.failureCount == 0) {
            GuardianHealthStatus.Healthy
        } else if (stats.failureCount < 5) {
            GuardianHealthStatus.Degraded
        } else if (stats.failureCount < 20) {
            GuardianHealthStatus.Unhealthy
        } else {
            GuardianHealthStatus.Critical
        }
    }
    
    // 虚方法，由子类重写
    protected open func doCreateChild(props: Props<Actor>, name: String): ActorRef {
        // 默认实现：抛出异常，要求子类实现
        throw Exception("doCreateChild must be implemented by subclass")
    }

    protected open func doStopChild(child: ActorRef): Unit {
        // 默认实现：简单打印
        println("Stopping child actor: ${child.path.toString()}")
    }

    protected open func doRestartChild(child: ActorRef, reason: Exception): Unit {
        // 默认实现：简单打印
        println("Restarting child actor: ${child.path.toString()}, reason: ${reason}")
    }

    protected open func doHandleFailure(failure: ActorFailure): Unit {
        // 默认实现：简单打印
        println("Handling actor failure: ${failure.actor.path.toString()}")
    }
    
    // Actor接口实现
    public open prop name: String {
        get() { "guardian" }
    }

    public open prop description: String {
        get() { "Guardian Actor for managing child actors" }
    }

    public open func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case createMsg: CreateChildMessage =>
                try {
                    createChild(createMsg.getProps(), createMsg.getChildName())
                    MessageResult.Handled
                } catch (e: Exception) {
                    println("创建子Actor失败: ${e}")
                    MessageResult.Unhandled
                }
            case stopMsg: StopChildMessage =>
                try {
                    stopChild(stopMsg.getChildRef())
                    MessageResult.Handled
                } catch (e: Exception) {
                    println("停止子Actor失败: ${e}")
                    MessageResult.Unhandled
                }
            case restartMsg: RestartChildMessage =>
                try {
                    restartChild(restartMsg.getChildRef(), restartMsg.getReason())
                    MessageResult.Handled
                } catch (e: Exception) {
                    println("重启子Actor失败: ${e}")
                    MessageResult.Unhandled
                }
            case _ => MessageResult.Unhandled
        }
    }
}
