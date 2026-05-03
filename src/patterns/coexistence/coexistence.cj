/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Coexistences 模式实现
 * 支持多 ActorSystem 桥接、类型适配和混合消息路由
 */
package cactor.patterns.coexistence

import std.collection.*
import std.time.*
import std.sync.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath, Actor, ActorSystem}

/**
 * ActorSystemBridge - 桥接多个 ActorSystem 实例
 *
 * 功能:
 * - 跨 ActorSystem 消息传递
 * - ActorRef 转换
 * - 系统间通信
 */
public class ActorSystemBridge {
    private let localSystem: ActorSystem
    private let remoteSystems: HashMap<String, ActorSystem>
    private let mutex: Mutex

    public init(localSystem: ActorSystem) {
        this.localSystem = localSystem
        this.remoteSystems = HashMap<String, ActorSystem>()
        this.mutex = Mutex()
    }

    /**
     * 注册远程 ActorSystem
     */
    public func registerRemoteSystem(name: String, system: ActorSystem): Unit {
        mutex.lock()
        try {
            let _ = remoteSystems.add(name, system)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取本地 ActorSystem
     */
    public func getLocalSystem(): ActorSystem {
        localSystem
    }

    /**
     * 获取远程 ActorSystem
     */
    public func getRemoteSystem(name: String): Option<ActorSystem> {
        mutex.lock()
        try {
            remoteSystems.get(name)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 列出所有已注册的远程系统
     */
    public func listRemoteSystems(): Array<String> {
        mutex.lock()
        try {
            remoteSystems.keys().toArray()
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 创建跨系统 ActorRef
     */
    public func createCrossSystemRef(
        remoteSystemName: String,
        actorPath: String
    ): Option<CrossSystemActorRef> {
        match (remoteSystems.get(remoteSystemName)) {
            case Some(system) =>
                let remotePath = ActorPath(remoteSystemName, actorPath)
                Some(CrossSystemActorRef(remotePath, remoteSystemName, this))
            case None => None
        }
    }

    /**
     * 发送跨系统消息
     */
    public func sendCrossSystemMessage(
        remoteSystemName: String,
        actorPath: String,
        message: Message,
        sender: Option<String>
    ): Bool {
        match (remoteSystems.get(remoteSystemName)) {
            case Some(system) =>
                let remotePath = ActorPath(remoteSystemName, actorPath)
                let ref = CrossSystemActorRef(remotePath, remoteSystemName, this)
                ref.tell(message, sender)
                true
            case None => false
        }
    }
}

/**
 * CrossSystemActorRef - 跨系统的 ActorRef
 */
public class CrossSystemActorRef <: ActorRef {
    private let actorPath: ActorPath
    private let remoteSystemName: String
    private let bridge: ActorSystemBridge
    private let messageQueue: ArrayList<Message>

    public init(path: ActorPath, remoteSystemName: String, bridge: ActorSystemBridge) {
        this.actorPath = path
        this.remoteSystemName = remoteSystemName
        this.bridge = bridge
        this.messageQueue = ArrayList<Message>()
    }

    public prop path: ActorPath {
        get() { actorPath }
    }

    public func tell(message: Message): Unit {
        bridge.sendCrossSystemMessage(remoteSystemName, actorPath.toString(), message, None)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        bridge.sendCrossSystemMessage(remoteSystemName, actorPath.toString(), message, sender)
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case cross: CrossSystemActorRef =>
                actorPath.equals(cross.actorPath) && remoteSystemName == cross.remoteSystemName
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(actorPath.toString().hashCode())
    }
}

/**
 * BridgeActorRef - 用于桥接的本地 ActorRef
 */
class BridgeActorRef <: ActorRef {
    private let pathString: String
    private let bridge: ActorSystemBridge

    public init(pathString: String, bridge: ActorSystemBridge) {
        this.pathString = pathString
        this.bridge = bridge
    }

    public prop path: ActorPath {
        get() { ActorPath("bridge", "/${pathString}") }
    }

    public func tell(message: Message): Unit {
        // 简化实现
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        // 简化实现
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case bridge: BridgeActorRef =>
                pathString == bridge.pathString
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(pathString.hashCode())
    }
}

/**
 * TypeAdapter - 类型适配器
 *
 * 功能:
 * - 在不同消息类型之间转换
 * - 支持 untyped/typed 混合
 */
public interface TypeAdapter<S, T> {
    /**
     * 将 S 类型转换为 T 类型
     */
    func adapt(source: S): T

    /**
     * 将 T 类型转换为 S 类型
     */
    func reverse(target: T): S
}

/**
 * MessageAdapter - 消息类型适配器
 */
public class MessageAdapter <: TypeAdapter<Message, Message> {
    private let toUntyped: (Message) -> Message
    private let toTyped: (Message) -> Message

    public init(
        toUntyped: (Message) -> Message,
        toTyped: (Message) -> Message
    ) {
        this.toUntyped = toUntyped
        this.toTyped = toTyped
    }

    public func adapt(source: Message): Message {
        toUntyped(source)
    }

    public func reverse(target: Message): Message {
        toTyped(target)
    }
}

/**
 * WrappedMessage - 包装消息
 */
public class WrappedMessage <: Message {
    public let originalMessage: Message
    public let sourceSystem: String
    public let ts: Int64

    public init(originalMessage: Message, sourceSystem: String) {
        this.originalMessage = originalMessage
        this.sourceSystem = sourceSystem
        this.ts = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func messageType(): String {
        "WrappedMessage"
    }

    public func getOriginalMessage(): Message {
        originalMessage
    }

    public func getSourceSystem(): String {
        sourceSystem
    }
}

/**
 * MixedMessageRouter - 混合消息路由器
 *
 * 功能:
 * - 在 untyped 和 typed Actor 之间路由
 * - 自动类型转换
 * - 消息过滤器
 */
public class MixedMessageRouter {
    private let adapters: HashMap<String, TypeAdapter<Message, Message>>
    private let routes: HashMap<String, ActorRef>
    private let mutex: Mutex
    private var defaultAdapter: Option<TypeAdapter<Message, Message>>

    public init() {
        this.adapters = HashMap<String, TypeAdapter<Message, Message>>()
        this.routes = HashMap<String, ActorRef>()
        this.mutex = Mutex()
        this.defaultAdapter = None
    }

    /**
     * 注册类型适配器
     */
    public func registerAdapter(
        messageType: String,
        adapter: TypeAdapter<Message, Message>
    ): Unit {
        mutex.lock()
        try {
            adapters.add(messageType, adapter)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 设置默认适配器
     */
    public func setDefaultAdapter(adapter: TypeAdapter<Message, Message>): Unit {
        mutex.lock()
        try {
            defaultAdapter = Some(adapter)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 添加路由规则
     */
    public func addRoute(path: String, target: ActorRef): Unit {
        mutex.lock()
        try {
            routes.add(path, target)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 移除路由规则
     */
    public func removeRoute(path: String): Unit {
        mutex.lock()
        try {
            routes.remove(path)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 路由消息
     */
    public func route(message: Message, sender: Option<String>): Unit {
        mutex.lock()
        let currentRoutes = routes.toArray()
        let currentAdapters = adapters.toArray()
        let currentDefault = defaultAdapter
        mutex.unlock()

        // 查找匹配的路由
        let targetPath = findMatchingRoute(message.messageType(), currentRoutes)
        match (targetPath) {
            case Some((path, target)) =>
                // 应用适配器
                let adaptedMessage = adaptMessage(message, currentAdapters, currentDefault)
                target.tell(adaptedMessage, sender)
            case None =>
                // 广播给所有路由
                for ((_, target) in currentRoutes) {
                    let adaptedMessage = adaptMessage(message, currentAdapters, currentDefault)
                    target.tell(adaptedMessage, sender)
                }
        }
    }

    /**
     * 查找匹配的路由
     */
    private func findMatchingRoute(
        messageType: String,
        routes: Array<(String, ActorRef)>
    ): Option<(String, ActorRef)> {
        for ((path, target) in routes) {
            if (messageType == path || messageType.startsWith(path)) {
                return Some((path, target))
            }
        }
        None
    }

    /**
     * 应用适配器
     */
    private func adaptMessage(
        message: Message,
        adapters: Array<(String, TypeAdapter<Message, Message>)>,
        defaultAdapter: Option<TypeAdapter<Message, Message>>
    ): Message {
        let msgType = message.messageType()

        // 查找特定适配器
        let adaptersArray = adapters
        var i: Int64 = 0
        while (i < adaptersArray.size) {
            let pair = adaptersArray[i]
            let typeName = pair[0]
            let adapter = pair[1]
            if (msgType == typeName) {
                return adapter.adapt(message)
            }
            i += 1
        }

        // 使用默认适配器
        match (defaultAdapter) {
            case Some(adapter) => adapter.adapt(message)
            case None => message
        }
    }

    /**
     * 获取所有路由
     */
    public func getRoutes(): Array<(String, ActorRef)> {
        mutex.lock()
        try {
            routes.toArray()
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * SystemCoordinator - 系统协调器
 *
 * 功能:
 * - 协调多个 ActorSystem
 * - 健康检查
 * - 故障转移
 */
public class SystemCoordinator {
    private let bridges: HashMap<String, ActorSystemBridge>
    private let healthStatus: HashMap<String, Bool>
    private let mutex: Mutex

    public init() {
        this.bridges = HashMap<String, ActorSystemBridge>()
        this.healthStatus = HashMap<String, Bool>()
        this.mutex = Mutex()
    }

    /**
     * 注册 ActorSystem
     */
    public func registerSystem(name: String, system: ActorSystem): Unit {
        mutex.lock()
        try {
            let bridge = ActorSystemBridge(system)
            bridges.add(name, bridge)
            healthStatus.add(name, true)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取桥接器
     */
    public func getBridge(systemName: String): Option<ActorSystemBridge> {
        mutex.lock()
        try {
            bridges.get(systemName)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 更新系统健康状态
     */
    public func updateHealthStatus(name: String, healthy: Bool): Unit {
        mutex.lock()
        try {
            healthStatus.add(name, healthy)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取所有健康系统
     */
    public func getHealthySystems(): Array<String> {
        mutex.lock()
        try {
            let healthy = ArrayList<String>()
            for ((name, status) in healthStatus) {
                if (status) {
                    healthy.add(name)
                }
            }
            healthy.toArray()
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取系统列表
     */
    public func listSystems(): Array<String> {
        mutex.lock()
        try {
            bridges.keys().toArray()
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * CoexistenceConfig - 共存配置
 */
public struct CoexistenceConfig {
    public let enableCrossSystem: Bool
    public let defaultTimeout: Duration
    public let maxRetries: Int64
    public let retryInterval: Duration

    public init() {
        this.enableCrossSystem = true
        this.defaultTimeout = Duration.second * 5
        this.maxRetries = 3
        this.retryInterval = Duration.millisecond * 100
    }

    public static func defaultConfig(): CoexistenceConfig {
        CoexistenceConfig()
    }
}
