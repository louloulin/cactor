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



// BaseGuardianActor具体实现已移动到runtime.guardian包
// Core层只保留纯抽象接口
