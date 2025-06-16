/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Core - Guardian Actor接口
 * 实现Akka风格的Guardian Actor层次结构
 * 企业级Guardian Actor系统，支持完整的监督树和故障恢复
 */
package cactor.core.guardian

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props, ActorPath, ActorFactory, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.supervision.{SupervisionStrategy, ActorFailure, SupervisionDirective}

/**
 * Guardian类型枚举
 */
public enum GuardianType {
    | System      // 系统Guardian
    | User        // 用户Guardian
    | Custom(String)  // 自定义Guardian类型

    public func toString(): String {
        match (this) {
            case System => "System"
            case User => "User"
            case Custom(name) => "Custom(${name})"
        }
    }
}

/**
 * Guardian健康状态
 */
public enum GuardianHealthStatus {
    | Healthy           // 健康
    | Degraded          // 降级
    | Unhealthy         // 不健康
    | Critical          // 严重
}

/**
 * Guardian统计信息
 */
public struct GuardianStats {
    public let childCount: Int64          // 子Actor总数
    public let activeChildren: Int64      // 活跃子Actor数
    public let restartCount: Int64        // 重启次数
    public let stopCount: Int64           // 停止次数
    public let failureCount: Int64        // 失败次数
    public let lastFailureTime: Option<DateTime>  // 最后失败时间
    public let uptime: Duration           // 运行时长

    public init(
        childCount: Int64,
        activeChildren: Int64,
        restartCount: Int64,
        stopCount: Int64,
        failureCount: Int64,
        lastFailureTime: Option<DateTime>,
        uptime: Duration
    ) {
        this.childCount = childCount
        this.activeChildren = activeChildren
        this.restartCount = restartCount
        this.stopCount = stopCount
        this.failureCount = failureCount
        this.lastFailureTime = lastFailureTime
        this.uptime = uptime
    }

    /**
     * 创建默认统计信息
     */
    public static func empty(): GuardianStats {
        GuardianStats(0, 0, 0, 0, 0, None<DateTime>, Duration.nanosecond * 0)
    }
}

/**
 * Guardian Actor接口
 * 管理Actor层次结构和监督策略
 * 企业级Guardian Actor系统核心接口
 */
public interface GuardianActor <: Actor {
    /**
     * Guardian类型标识
     */
    prop guardianType: GuardianType

    /**
     * 父Guardian引用（可选）
     */
    prop parent: Option<ActorRef>

    /**
     * 创建子Actor
     * @param props Actor属性配置
     * @param name Actor名称
     * @return Actor引用
     */
    func createChild(props: Props<Actor>, name: String): ActorRef

    /**
     * 监督子Actor
     * @param child 子Actor引用
     * @param strategy 监督策略
     */
    func supervise(child: ActorRef, strategy: SupervisionStrategy): Unit

    /**
     * 获取所有子Actor
     * @return 子Actor数组
     */
    func getChildren(): Array<ActorRef>

    /**
     * 根据名称查找子Actor
     * @param name 子Actor名称
     * @return Actor引用（可选）
     */
    func findChild(name: String): Option<ActorRef>

    /**
     * 停止子Actor
     * @param child 要停止的子Actor
     */
    func stopChild(child: ActorRef): Unit

    /**
     * 重启子Actor
     * @param child 要重启的子Actor
     * @param reason 重启原因
     */
    func restartChild(child: ActorRef, reason: Exception): Unit

    /**
     * 处理Actor失败
     * @param failure Actor失败信息
     */
    func handleFailure(failure: ActorFailure): Unit

    /**
     * 获取Guardian统计信息
     * @return Guardian统计数据
     */
    func getStats(): GuardianStats

    /**
     * 获取Guardian健康状态
     * @return 健康状态
     */
    func getHealthStatus(): GuardianHealthStatus
}

/**
 * Guardian消息类型
 */
public class CreateChildMessage <: Message {
    private let props: Props<Actor>
    private let childName: String
    
    public init(props: Props<Actor>, name: String) {
        this.props = props
        this.childName = name
    }
    
    public func getProps(): Props<Actor> { props }
    public func getChildName(): String { childName }
    
    public func getType(): String { "CreateChild" }
    public func getPayload(): String { "CreateChild(${childName})" }
    public func messageType(): String { "CreateChild" }
}

public class StopChildMessage <: Message {
    private let childRef: ActorRef
    
    public init(child: ActorRef) {
        this.childRef = child
    }
    
    public func getChildRef(): ActorRef { childRef }
    
    public func getType(): String { "StopChild" }
    public func getPayload(): String { "StopChild(${childRef.path.toString()})" }
    public func messageType(): String { "StopChild" }
}

public class RestartChildMessage <: Message {
    private let childRef: ActorRef
    private let reason: Exception
    
    public init(child: ActorRef, reason: Exception) {
        this.childRef = child
        this.reason = reason
    }
    
    public func getChildRef(): ActorRef { childRef }
    public func getReason(): Exception { reason }
    
    public func getType(): String { "RestartChild" }
    public func getPayload(): String { "RestartChild(${childRef.path.toString()})" }
    public func messageType(): String { "RestartChild" }
}



/**
 * Guardian Actor基础实现
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
