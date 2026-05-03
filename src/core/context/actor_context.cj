/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor上下文
 * 提供Actor运行时的环境和服务
 * 对标 Akka Typed ActorContext
 */
package cactor.core.context

import std.time.*
import std.collection.*
import cactor.core.actor.{ActorRef, ActorPath, Props, Actor}
import cactor.core.system.ActorSystem

/**
 * Actor上下文接口
 * 对标 Akka Typed ActorContext
 * 提供Actor运行时的完整服务
 *
 * Akka 参考:
 * - context.self: 自身ActorRef
 * - context.actorOf(): 创建子Actor
 * - context.parent: 父监督者
 * - context.children: 所有子Actor
 * - context.watch(): 监视Actor
 */
public interface ActorContext {
    /**
     * 获取当前消息的发送者
     * @return 发送者的ActorRef
     */
    func sender(): ActorRef

    /**
     * 获取自身的ActorRef
     * 对应 Akka: context.self
     * @return 自身Actor引用
     */
    func self(): ActorRef

    /**
     * 获取父监督者的ActorRef
     * 对应 Akka: context.parent
     * @return 父Actor引用
     */
    func parent(): ActorRef

    /**
     * 获取所有子Actor的引用
     * 对应 Akka: context.children
     * @return 子Actor引用数组
     */
    func children(): Array<ActorRef>

    /**
     * 获取指定名称的子Actor
     * 对应 Akka: context.child(name)
     * @param name 子Actor名称
     * @return 子Actor引用，如果不存在则为None
     */
    func child(name: String): Option<ActorRef>

    /**
     * 创建子Actor
     * 对应 Akka: context.spawn() / context.actorOf()
     * @param props Actor配置
     * @param name Actor名称
     * @return 子Actor引用
     */
    func actorOf(props: Props<Actor>, name: String): ActorRef

    /**
     * 创建子Actor（自动命名）
     * @param props Actor配置
     * @return 子Actor引用
     */
    func actorOf(props: Props<Actor>): ActorRef

    /**
     * 监视另一个Actor
     * 当被监视的Actor终止时会收到Terminated消息
     * 对应 Akka: context.watch(ref)
     * @param actorRef 要监视的Actor引用
     */
    func watch(actorRef: ActorRef): Unit

    /**
     * 取消监视
     * 对应 Akka: context.unwatch(ref)
     * @param actorRef 要取消监视的Actor引用
     */
    func unwatch(actorRef: ActorRef): Unit

    /**
     * 获取Actor系统
     * 对应 Akka: context.system
     * @return Actor系统
     */
    func getActorSystem(): ActorSystem

    /**
     * 设置接收超时
     * 如果在指定时间内没有收到消息，将触发ReceiveTimeout
     * 对应 Akka: context.setReceiveTimeout(timeout)
     * @param timeout 超时时间
     */
    func setReceiveTimeout(timeout: Duration): Unit

    /**
     * 获取当前接收超时设置
     * 对应 Akka: context.receiveTimeout
     * @return 超时时间
     */
    func receiveTimeout(): Duration

    /**
     * 停止自身Actor
     * 对应 Akka: context.stop(context.self)
     */
    func stop(): Unit

    /**
     * 停止指定子Actor
     * 对应 Akka: context.stop(child)
     * @param actorRef 要停止的Actor引用
     */
    func stop(actorRef: ActorRef): Unit
}

/**
 * Actor上下文的默认实现
 */
public class DefaultActorContext <: ActorContext {
    private let selfRef: ActorRef
    private let parentRef: ActorRef
    private let system: ActorSystem
    private let childrenMap: HashMap<String, ActorRef>
    private var currentSender: ActorRef
    private var receiveTimeoutDuration: Duration
    private let watchedActors: ArrayList<ActorRef>

    public init(selfRef: ActorRef, parentRef: ActorRef, system: ActorSystem) {
        this.selfRef = selfRef
        this.parentRef = parentRef
        this.system = system
        this.childrenMap = HashMap<String, ActorRef>()
        this.currentSender = selfRef  // 默认sender为自身
        this.receiveTimeoutDuration = Duration.second * 0
        this.watchedActors = ArrayList<ActorRef>()
    }

    public func sender(): ActorRef {
        currentSender
    }

    public func self(): ActorRef {
        selfRef
    }

    public func parent(): ActorRef {
        parentRef
    }

    public func children(): Array<ActorRef> {
        let entries = childrenMap.values()
        let result = ArrayList<ActorRef>()
        for (ref in entries) {
            result.add(ref)
        }
        result.toArray()
    }

    public func child(name: String): Option<ActorRef> {
        match (childrenMap.get(name)) {
            case Some(ref) => Some(ref)
            case None => None
        }
    }

    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        let actorRef = system.actorOf(props, name)
        childrenMap.add(name, actorRef)
        actorRef
    }

    public func actorOf(props: Props<Actor>): ActorRef {
        let autoName = "child-${generateUniqueId()}"
        actorOf(props, autoName)
    }

    public func watch(actorRef: ActorRef): Unit {
        watchedActors.add(actorRef)
    }

    public func unwatch(actorRef: ActorRef): Unit {
        var foundIdx = -1
        for (i in 0..watchedActors.size) {
            if (watchedActors[i].path.toString() == actorRef.path.toString()) {
                foundIdx = i
                break
            }
        }
        if (foundIdx >= 0) {
            watchedActors.remove(Int64(foundIdx)..Int64(foundIdx + 1))
        }
    }

    public func getActorSystem(): ActorSystem {
        system
    }

    public func setReceiveTimeout(timeout: Duration): Unit {
        receiveTimeoutDuration = timeout
    }

    public func receiveTimeout(): Duration {
        receiveTimeoutDuration
    }

    public func stop(): Unit {
        stop(selfRef)
    }

    public func stop(actorRef: ActorRef): Unit {
        // 从childrenMap中移除
        let toRemove = ArrayList<String>()
        for ((name, ref) in childrenMap) {
            if (ref.path.toString() == actorRef.path.toString()) {
                toRemove.add(name)
            }
        }
        for (name in toRemove) {
            childrenMap.remove(name)
        }
    }

    // 设置当前sender（由邮箱调用）
    public func setCurrentSender(sender: ActorRef): Unit {
        currentSender = sender
    }

    // 获取监视的Actor列表
    public func getWatchedActors(): ArrayList<ActorRef> {
        watchedActors
    }

    // 生成唯一ID
    private static var idCounter: Int64 = 0
    private func generateUniqueId(): String {
        DefaultActorContext.idCounter += 1
        "${DefaultActorContext.idCounter}"
    }
}

// 全局ID生成器
var globalActorContextIdCounter: Int64 = 0
