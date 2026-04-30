/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 集群单例
 * 对标 Akka Cluster Singleton
 * 确保集群中只有一个指定Actor实例运行
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*
import cactor.core.message.*
import cactor.core.actor.{ActorRef, ActorPath, ActorContext, Actor}

/**
 * 集群单例配置
 * 对标 Akka ClusterSingletonSettings
 */
public class ClusterSingletonSettings {
    /** 单例名称 */
    public let singletonName: String

    /** 单例角色要求（可选） */
    public let role: Option<String>

    /** 节点成为单例前需要等待的UP节点数 */
    public let minNrOfMembers: Int64

    /** 节点最大启动超时时间 */
    public let maxInitializationTimeout: Duration

    /** 是否在所有节点上创建代理 */
    public let runProxyOnMemberUp: Bool

    /** 代理缓冲队列容量 */
    public let proxyBufferSize: Int64

    /** 停止超时时间 */
    public let stopTimeout: Duration

    public init(
        singletonName: String,
        role!: Option<String> = None,
        minNrOfMembers!: Int64 = 1,
        maxInitializationTimeout!: Duration = Duration.second * 10,
        runProxyOnMemberUp!: Bool = true,
        proxyBufferSize!: Int64 = 100,
        stopTimeout!: Duration = Duration.second * 5
    ) {
        this.singletonName = singletonName
        this.role = role
        this.minNrOfMembers = minNrOfMembers
        this.maxInitializationTimeout = maxInitializationTimeout
        this.runProxyOnMemberUp = runProxyOnMemberUp
        this.proxyBufferSize = proxyBufferSize
        this.stopTimeout = stopTimeout
    }

    public static func defaultSettings(singletonName: String): ClusterSingletonSettings {
        ClusterSingletonSettings(singletonName)
    }

    public static func withRole(singletonName: String, role: String): ClusterSingletonSettings {
        ClusterSingletonSettings(singletonName, role: Some(role))
    }
}

/**
 * 单例实例信息
 */
public class SingletonInstance {
    /** 单例Actor引用 */
    public let actorRef: ActorRef

    /** 拥有该实例的节点地址 */
    public let ownerAddress: UniqueAddress

    /** 实例版本号 */
    public let version: Int64

    public init(actorRef: ActorRef, ownerAddress: UniqueAddress, version: Int64) {
        this.actorRef = actorRef
        this.ownerAddress = ownerAddress
        this.version = version
    }
}

/**
 * 单例状态
 */
public enum SingletonStatus {
    | Initializing
    | Active
    | Migrating
    | Stopping
    | Terminated

    public func isActive(): Bool {
        match (this) {
            case Active => true
            case _ => false
        }
    }

    public func canMigrate(): Bool {
        match (this) {
            case Active | Migrating => true
            case _ => false
        }
    }

    public func isInitializing(): Bool {
        match (this) {
            case Initializing => true
            case _ => false
        }
    }

    public func isMigrating(): Bool {
        match (this) {
            case Migrating => true
            case _ => false
        }
    }
}

/**
 * 单例管理消息
 */
public interface SingletonManagerMessage {
    func messageType(): String
}

/** 获取当前单例实例 */
public struct SingletonGetInstance <: SingletonManagerMessage & Message {
    public init() {}

    public func messageType(): String { "SingletonGetInstance" }
}

/** 单例实例响应 */
public class SingletonInstanceResponse <: Message {
    public let instance: Option<SingletonInstance>
    public let status: SingletonStatus

    public init(instance: Option<SingletonInstance>, status: SingletonStatus) {
        this.instance = instance
        this.status = status
    }

    public func messageType(): String { "SingletonInstanceResponse" }
}

/** 请求成为单例 */
public struct BecomeSingleton <: SingletonManagerMessage & Message {
    public let actorRef: ActorRef
    public let address: UniqueAddress

    public init(actorRef: ActorRef, address: UniqueAddress) {
        this.actorRef = actorRef
        this.address = address
    }

    public func messageType(): String { "BecomeSingleton" }
}

/** 放弃单例角色 */
public struct ReleaseSingleton <: SingletonManagerMessage & Message {
    public let address: UniqueAddress

    public init(address: UniqueAddress) {
        this.address = address
    }

    public func messageType(): String { "ReleaseSingleton" }
}

/** 单例选举消息 */
public struct ElectSingleton <: SingletonManagerMessage & Message {
    public let candidates: Array<UniqueAddress>

    public init(candidates: Array<UniqueAddress>) {
        this.candidates = candidates
    }

    public func messageType(): String { "ElectSingleton" }
}

/** 选举结果 */
public struct ElectionResult <: SingletonManagerMessage & Message {
    public let winner: Option<UniqueAddress>
    public let version: Int64

    public init(winner: Option<UniqueAddress>, version: Int64) {
        this.winner = winner
        this.version = version
    }

    public func messageType(): String { "ElectionResult" }
}

/**
 * 成员事件类型
 */
public enum MemberEventType {
    | MemberUp
    | MemberLeft
    | MemberDown
    | MemberExited
}

/**
 * 成员事件
 */
public class MemberEvent <: Message {
    public let member: Option<Member>
    public let address: Option<UniqueAddress>
    public let eventType: MemberEventType

    public init(member: Member, eventType: MemberEventType) {
        this.member = Some(member)
        this.address = None
        this.eventType = eventType
    }

    public init(address: UniqueAddress, eventType: MemberEventType) {
        this.member = None
        this.address = Some(address)
        this.eventType = eventType
    }

    public func messageType(): String {
        match (eventType) {
            case MemberUp => "MemberUp"
            case MemberLeft => "MemberLeft"
            case MemberDown => "MemberDown"
            case MemberExited => "MemberExited"
        }
    }
}

/**
 * 集群单例管理器
 * 对标 Akka ClusterSingletonManager
 */
public class ClusterSingletonManager <: Actor {
    /** 单例配置 */
    private let settings: ClusterSingletonSettings

    /** 当前单例实例 */
    private var currentInstance: Option<SingletonInstance>

    /** 单例状态 */
    private var status: SingletonStatus

    /** 单例版本号 */
    private var version: Int64

    /** 已知成员 */
    private let members: HashMap<UniqueAddress, MemberStatus>

    /** 待迁移消息 */
    private let pendingMessages: ArrayList<Envelope>

    /** 单例角色候选者（按优先级排序） */
    private var candidates: ArrayList<UniqueAddress>

    public init(settings: ClusterSingletonSettings) {
        this.settings = settings
        this.currentInstance = None
        this.status = SingletonStatus.Initializing
        this.version = 0
        this.members = HashMap<UniqueAddress, MemberStatus>()
        this.pendingMessages = ArrayList<Envelope>()
        this.candidates = ArrayList<UniqueAddress>()
    }

    public prop name: String {
        get() { settings.singletonName }
    }

    public prop description: String {
        get() { "ClusterSingletonManager for ${settings.singletonName}" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: SingletonGetInstance =>
                handleGetInstance(msg, context)
            case msg: BecomeSingleton =>
                handleBecomeSingleton(msg)
            case msg: ReleaseSingleton =>
                handleReleaseSingleton(msg)
            case msg: ElectSingleton =>
                handleElectSingleton(msg)
            case msg: MemberEvent =>
                handleMemberEvent(msg)
            case _ =>
                handleMessage(message, context)
        }
    }

    private func handleGetInstance(msg: SingletonGetInstance, context: ActorContext): MessageResult {
        let response = SingletonInstanceResponse(currentInstance, status)
        context.sender().tell(response)
        MessageResult.Handled
    }

    private func handleBecomeSingleton(msg: BecomeSingleton): MessageResult {
        // 检查是否已经有单例实例
        var shouldBecome = true
        match (currentInstance) {
            case Some(instance) =>
                // 如果当前实例更优（更低版本），拒绝
                if (instance.version <= version) {
                    shouldBecome = false
                }
            case None => ()
        }

        if (shouldBecome) {
            // 成为新的单例实例
            currentInstance = Some(SingletonInstance(msg.actorRef, msg.address, version + 1))
            version = version + 1
            status = SingletonStatus.Active

            // 清空待处理消息
            drainPendingMessages()
        }
        MessageResult.Handled
    }

    private func handleReleaseSingleton(msg: ReleaseSingleton): MessageResult {
        var shouldRelease = false
        match (currentInstance) {
            case Some(instance) =>
                if (instance.ownerAddress.equals(msg.address)) {
                    shouldRelease = true
                }
            case None => ()
        }

        if (shouldRelease) {
            currentInstance = None
            status = SingletonStatus.Migrating
            // 触发新选举
            triggerElection()
        }
        MessageResult.Handled
    }

    private func handleElectSingleton(msg: ElectSingleton): MessageResult {
        if (msg.candidates.size == 0) {
            return MessageResult.Handled
        }

        // 选择优先级最高的候选者（通常是加入最早的节点）
        let winner = selectWinner(msg.candidates)
        let result = ElectionResult(Some(winner), version + 1)

        MessageResult.Handled
    }

    private func handleMemberEvent(event: MemberEvent): MessageResult {
        match (event.eventType) {
            case MemberUp =>
                match (event.member) {
                    case Some(m) =>
                        addOrUpdateMember(m, MemberStatus.Up)
                        if (status.isInitializing()) {
                            checkAndStartSingleton()
                        } else if (status.isMigrating()) {
                            triggerElection()
                        }
                    case None => ()
                }
            case MemberLeft =>
                match (event.member) {
                    case Some(m) =>
                        addOrUpdateMember(m, MemberStatus.Leaving)
                        checkForMigration(m)
                    case None => ()
                }
            case MemberDown =>
                match (event.address) {
                    case Some(addr) =>
                        removeMember(addr)
                        checkForMigrationByAddress(addr)
                    case None => ()
                }
            case MemberExited =>
                match (event.member) {
                    case Some(m) =>
                        addOrUpdateMember(m, MemberStatus.Exiting)
                        checkForMigration(m)
                    case None => ()
                }
        }
        MessageResult.Handled
    }

    private func handleMessage(message: Message, context: ActorContext): MessageResult {
        match (currentInstance) {
            case Some(instance) =>
                // 转发消息到单例
                instance.actorRef.tell(message)
            case None =>
                // 缓存消息
                let env = Envelope(message, context.sender())
                pendingMessages.add(env)
                // 限制缓存大小
                if (Int64(pendingMessages.size) > settings.proxyBufferSize) {
                    pendingMessages.remove(0..1)
                }
        }
        MessageResult.Handled
    }

    private func addOrUpdateMember(member: Member, newStatus: MemberStatus): Unit {
        members.add(member.getUniqueAddress(), newStatus)
    }

    private func removeMember(address: UniqueAddress): Unit {
        members.remove(address)
        var indexToRemove: Int64 = -1
        for (i in 0..candidates.size) {
            if (candidates[i].equals(address)) {
                indexToRemove = i
                break
            }
        }
        if (indexToRemove >= 0) {
            candidates.remove(Int64(indexToRemove)..Int64(indexToRemove + 1))
        }
    }

    private func checkAndStartSingleton(): Unit {
        let eligibleMembers = getEligibleMembers()
        if (eligibleMembers.size >= settings.minNrOfMembers) {
            triggerElection()
        }
    }

    private func checkForMigration(member: Member): Unit {
        match (currentInstance) {
            case Some(instance) =>
                if (instance.ownerAddress.equals(member.getUniqueAddress())) {
                    // 当前单例持有者离开，开始迁移
                    status = SingletonStatus.Migrating
                    triggerElection()
                }
            case None => ()
        }
    }

    private func checkForMigrationByAddress(address: UniqueAddress): Unit {
        match (currentInstance) {
            case Some(instance) =>
                if (instance.ownerAddress.equals(address)) {
                    status = SingletonStatus.Migrating
                    triggerElection()
                }
            case None => ()
        }
    }

    private func getEligibleMembers(): Array<UniqueAddress> {
        let result = ArrayList<UniqueAddress>()
        for ((address, memberStatus) in members) {
            if (memberStatus.isActive() && matchesRole(address)) {
                result.add(address)
            }
        }
        // 按uid排序（从小到大）
        let arr = result.toArray()
        let sorted = Array<UniqueAddress>(Int64(arr.size), { i => arr[i] })
        // 简单冒泡排序
        for (i in 0..sorted.size) {
            for (j in Int64(i + 1)..sorted.size) {
                if (sorted[i].uid > sorted[j].uid) {
                    let temp = sorted[i]
                    sorted[i] = sorted[j]
                    sorted[j] = temp
                }
            }
        }
        sorted
    }

    private func matchesRole(address: UniqueAddress): Bool {
        match (settings.role) {
            case Some(requiredRole) =>
                // 实际实现需要检查节点角色
                true
            case None =>
                true
        }
    }

    private func selectWinner(candidates: Array<UniqueAddress>): UniqueAddress {
        var winner = candidates[0]
        for (candidate in candidates) {
            if (candidate.uid < winner.uid) {
                winner = candidate
            }
        }
        winner
    }

    private func triggerElection(): Unit {
        let eligible = getEligibleMembers()
        if (eligible.size > 0) {
            let election = ElectSingleton(eligible)
            // 触发选举处理
            handleElectSingleton(election)
        }
    }

    private func drainPendingMessages(): Unit {
        // 清空待处理消息
        pendingMessages.clear()
    }

    /** 获取当前单例实例（同步） */
    public func getCurrentInstance(): Option<SingletonInstance> {
        currentInstance
    }

    /** 获取单例状态 */
    public func getStatus(): SingletonStatus {
        status
    }

    /** 获取版本号 */
    public func getVersion(): Int64 {
        version
    }

    /** 获取成员数量 */
    public func getMemberCount(): Int64 {
        Int64(members.size)
    }
}

/**
 * 集群单例代理
 * 对标 Akka ClusterSingletonProxy
 */
public class ClusterSingletonProxy <: Actor {
    /** 单例管理器路径 */
    private let singletonManagerPath: String

    /** 代理设置 */
    private let settings: ClusterSingletonSettings

    /** 当前单例实例引用 */
    private var singletonRef: Option<ActorRef>

    /** 单例状态 */
    private var singletonStatus: SingletonStatus

    /** 消息缓冲区 */
    private let messageBuffer: ArrayList<Envelope>

    /** 是否正在等待单例上线 */
    private var waitingForSingleton: Bool

    public init(singletonManagerPath: String, settings: ClusterSingletonSettings) {
        this.singletonManagerPath = singletonManagerPath
        this.settings = settings
        this.singletonRef = None
        this.singletonStatus = SingletonStatus.Initializing
        this.messageBuffer = ArrayList<Envelope>()
        this.waitingForSingleton = false
    }

    public prop name: String {
        get() { "SingletonProxy-${settings.singletonName}" }
    }

    public prop description: String {
        get() { "ClusterSingletonProxy for ${settings.singletonName}" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: SingletonInstanceResponse =>
                handleInstanceResponse(msg, context)
            case _ =>
                handleMessage(message, context)
        }
    }

    private func handleInstanceResponse(response: SingletonInstanceResponse, context: ActorContext): MessageResult {
        singletonStatus = response.status

        match (response.instance) {
            case Some(instance) =>
                singletonRef = Some(instance.actorRef)
                waitingForSingleton = false
                // 发送缓冲区中的消息
                drainBuffer()
            case None =>
                // 等待单例上线
                waitingForSingleton = true
        }
        MessageResult.Handled
    }

    private func handleMessage(message: Message, context: ActorContext): MessageResult {
        match (singletonRef) {
            case Some(ref) =>
                // 直接发送到单例
                ref.tell(message)
            case None =>
                // 缓存消息
                let sender = context.sender()
                let env = Envelope(message, sender)
                messageBuffer.add(env)

                // 限制缓冲区大小
                if (Int64(messageBuffer.size) > settings.proxyBufferSize) {
                    messageBuffer.remove(0..1)
                }

                // 请求单例实例
                if (!waitingForSingleton) {
                    waitingForSingleton = true
                }
        }
        MessageResult.Handled
    }

    private func drainBuffer(): Unit {
        match (singletonRef) {
            case Some(ref) =>
                for (env in messageBuffer) {
                    ref.tell(env.message)
                }
                messageBuffer.clear()
            case None => ()
        }
    }

    /** 获取当前单例引用 */
    public func getSingletonRef(): Option<ActorRef> {
        singletonRef
    }

    /** 获取单例状态 */
    public func getSingletonStatus(): SingletonStatus {
        singletonStatus
    }

    /** 获取缓冲区大小 */
    public func getBufferSize(): Int64 {
        Int64(messageBuffer.size)
    }
}

/**
 * 单例工厂
 */
public class SingletonManagerFactory {
    /** 创建单例管理器 */
    public static func create(settings: ClusterSingletonSettings): ClusterSingletonManager {
        ClusterSingletonManager(settings)
    }

    /** 创建单例代理 */
    public static func createProxy(managerPath: String, settings: ClusterSingletonSettings): ClusterSingletonProxy {
        ClusterSingletonProxy(managerPath, settings)
    }

    /** 创建默认配置 */
    public static func createSettings(name: String): ClusterSingletonSettings {
        ClusterSingletonSettings.defaultSettings(name)
    }
}

/**
 * 消息信封
 */
public class Envelope {
    public let message: Message
    public let sender: ActorRef

    public init(message: Message, sender: ActorRef) {
        this.message = message
        this.sender = sender
    }
}
