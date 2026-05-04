/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Multi-DC 多数据中心支持
 * 对标 Akka Cluster Multi-Datacenter
 * 支持跨数据中心的高可用部署
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 数据中心标识
 */
public class DatacenterId <: ToString {
    public let name: String
    public let region: String

    public init(name: String, region: String) {
        this.name = name
        this.region = region
    }

    public func toString(): String {
        "${region}/${name}"
    }

    public func equals(other: DatacenterId): Bool {
        this.name == other.name && this.region == other.region
    }
}

/**
 * 节点 DC 角色
 */
public enum DcRole <: ToString {
    | PrimaryDC    // 主数据中心
    | BackupDC     // 备份数据中心
    | ReadOnlyDC   // 只读数据中心
    | Neutral      // 中立节点

    public func toString(): String {
        match (this) {
            case PrimaryDC => "PrimaryDC"
            case BackupDC => "BackupDC"
            case ReadOnlyDC => "ReadOnlyDC"
            case Neutral => "Neutral"
        }
    }
}

/**
 * DC 成员信息
 */
public class DcMemberInfo {
    public let nodeId: String
    public let datacenter: DatacenterId
    public let role: DcRole
    public var status: MemberStatus
    public var lastHeartbeat: Int64
    public var isReachabl: Bool

    public init(nodeId: String, datacenter: DatacenterId, role: DcRole) {
        this.nodeId = nodeId
        this.datacenter = datacenter
        this.role = role
        this.status = MemberStatus.Joining
        this.lastHeartbeat = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.isReachabl = false
    }

    public func markReachable(): Unit {
        isReachabl = true
        lastHeartbeat = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func markUnreachable(): Unit {
        isReachabl = false
    }
}

/**
 * DC 配置
 */
public class MultiDcConfig <: ToString {
    public let enabled: Bool
    public let primaryDC: String
    public let crossDcReplication: Bool
    public let dcAwareRouting: Bool
    public let failoverTimeout: Duration
    public let heartbeatInterval: Duration
    public let unreachableThreshold: Int64

    public init(
        enabled: Bool,
        primaryDC: String,
        crossDcReplication: Bool,
        dcAwareRouting: Bool,
        failoverTimeout: Duration,
        heartbeatInterval: Duration,
        unreachableThreshold: Int64
    ) {
        this.enabled = enabled
        this.primaryDC = primaryDC
        this.crossDcReplication = crossDcReplication
        this.dcAwareRouting = dcAwareRouting
        this.failoverTimeout = failoverTimeout
        this.heartbeatInterval = heartbeatInterval
        this.unreachableThreshold = unreachableThreshold
    }

    public func toString(): String {
        "MultiDcConfig(enabled=${enabled}, primaryDC=${primaryDC}, crossDcReplication=${crossDcReplication})"
    }

    public static func defaultConfig(): MultiDcConfig {
        MultiDcConfig(
            true,
            "dc1",
            true,
            true,
            Duration.second * 30,
            Duration.second * 5,
            3
        )
    }
}

/**
 * DC 成员管理器
 */
public class DcMembershipManager {
    private let config: MultiDcConfig
    private let members: HashMap<String, DcMemberInfo>
    private let datacenters: HashMap<String, ArrayList<String>>
    private let lock: ReentrantReadWriteMutex
    private let events: ArrayList<DcMembershipEvent>

    public init(config: MultiDcConfig) {
        this.config = config
        this.members = HashMap<String, DcMemberInfo>()
        this.datacenters = HashMap<String, ArrayList<String>>()
        this.lock = ReentrantReadWriteMutex()
        this.events = ArrayList<DcMembershipEvent>()
    }

    /**
     * 添加 DC 成员
     */
    public func addMember(nodeId: String, datacenter: DatacenterId, role: DcRole): Unit {
        lock.writeMutex.lock()
        let member = DcMemberInfo(nodeId, datacenter, role)
        members.add(nodeId, member)

        // 更新 DC 映射
        match (datacenters.get(datacenter.name)) {
            case Some(list) => list.add(nodeId)
            case None =>
                let newList = ArrayList<String>()
                newList.add(nodeId)
                datacenters.add(datacenter.name, newList)
        }

        events.add(DcMembershipEvent.NodeAdded(nodeId, datacenter))
        lock.writeMutex.unlock()
    }

    /**
     * 移除 DC 成员
     */
    public func removeMember(nodeId: String): Unit {
        lock.writeMutex.lock()
        match (members.get(nodeId)) {
            case Some(member) =>
                let dc = member.datacenter.name
                members.remove(nodeId)

                // 从 DC 映射中移除 (简化处理)
                match (datacenters.get(dc)) {
                    case Some(list) =>
                        // 重建列表，不包含被移除的节点
                        let remaining = ArrayList<String>()
                        for (n in list) {
                            if (n != nodeId) {
                                remaining.add(n)
                            }
                        }
                        datacenters.remove(dc)
                        if (remaining.size > 0) {
                            datacenters.add(dc, remaining)
                        }
                    case None => ()
                }

                events.add(DcMembershipEvent.NodeRemoved(nodeId, member.datacenter))
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 获取所有成员
     */
    public func getAllMembers(): ArrayList<DcMemberInfo> {
        lock.readMutex.lock()
        let result = ArrayList<DcMemberInfo>()
        for ((_, member) in members) {
            result.add(member)
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取指定 DC 的成员
     */
    public func getMembersInDc(dcName: String): ArrayList<DcMemberInfo> {
        lock.readMutex.lock()
        let result = ArrayList<DcMemberInfo>()
        for ((_, member) in members) {
            if (member.datacenter.name == dcName) {
                result.add(member)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取主 DC 的成员
     */
    public func getPrimaryDCMembers(): ArrayList<DcMemberInfo> {
        getMembersInDc(config.primaryDC)
    }

    /**
     * 获取可达成员
     */
    public func getReachableMembers(): ArrayList<DcMemberInfo> {
        lock.readMutex.lock()
        let result = ArrayList<DcMemberInfo>()
        for ((_, member) in members) {
            if (member.isReachabl) {
                result.add(member)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取所有数据中心列表
     */
    public func getDatacenters(): ArrayList<String> {
        lock.readMutex.lock()
        let result = ArrayList<String>()
        for ((dc, _) in datacenters) {
            result.add(dc)
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取 DC 成员数量
     */
    public func getMemberCount(dcName: String): Int64 {
        lock.readMutex.lock()
        let count: Int64 = match (datacenters.get(dcName)) {
            case Some(list) => Int64(list.size)
            case None => 0
        }
        lock.readMutex.unlock()
        count
    }

    /**
     * 检查成员是否可达
     */
    public func isMemberReachable(nodeId: String): Bool {
        lock.readMutex.lock()
        let reachable = match (members.get(nodeId)) {
            case Some(m) => m.isReachabl
            case None => false
        }
        lock.readMutex.unlock()
        reachable
    }

    /**
     * 更新成员心跳
     */
    public func updateHeartbeat(nodeId: String): Unit {
        lock.writeMutex.lock()
        try {
            match (members.get(nodeId)) {
                case Some(member) => member.markReachable()
                case None => ()
            }
        } finally {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 标记成员不可达
     */
    public func markUnreachable(nodeId: String): Unit {
        lock.writeMutex.lock()
        match (members.get(nodeId)) {
            case Some(member) =>
                member.markUnreachable()
                events.add(DcMembershipEvent.NodeUnreachable(nodeId, member.datacenter))
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 获取最近的事件
     */
    public func getRecentEvents(count: Int64): ArrayList<DcMembershipEvent> {
        lock.readMutex.lock()
        let result = ArrayList<DcMembershipEvent>()
        let start = if (events.size > count) { events.size - count } else { 0 }
        var i = start
        while (i < events.size) {
            result.add(events[i])
            i += 1
        }
        lock.readMutex.unlock()
        result
    }
}

/**
 * DC 成员事件
 */
public enum DcMembershipEvent {
    | NodeAdded(String, DatacenterId)
    | NodeRemoved(String, DatacenterId)
    | NodeUnreachable(String, DatacenterId)
    | NodeReachable(String, DatacenterId)
    | DcBecamePrimary(String)
    | DcFailedOver(String)
}

/**
 * DC 感知的路由策略
 */
public enum DcRoutingStrategy <: ToString {
    | LocalDCFirst      // 本地 DC 优先
    | PrimaryDCOnly      // 仅主 DC
    | AllDCs             // 所有 DC
    | RoundRobinAcrossDCs // 跨 DC 轮询

    public func toString(): String {
        match (this) {
            case LocalDCFirst => "LocalDCFirst"
            case PrimaryDCOnly => "PrimaryDCOnly"
            case AllDCs => "AllDCs"
            case RoundRobinAcrossDCs => "RoundRobinAcrossDCs"
        }
    }
}

/**
 * DC 感知路由器
 */
public class DcAwareRouter {
    private let manager: DcMembershipManager
    private let strategy: DcRoutingStrategy
    private var currentDcIndex: Int64
    private let lock: Mutex

    public init(manager: DcMembershipManager, strategy: DcRoutingStrategy) {
        this.manager = manager
        this.strategy = strategy
        this.currentDcIndex = 0
        this.lock = Mutex()
    }

    /**
     * 选择目标成员
     */
    public func selectTarget(localDc: String): Option<DcMemberInfo> {
        match (strategy) {
            case DcRoutingStrategy.LocalDCFirst =>
                selectLocalDcFirst(localDc)
            case DcRoutingStrategy.PrimaryDCOnly =>
                selectPrimaryDcOnly()
            case DcRoutingStrategy.AllDCs =>
                selectFromAll()
            case DcRoutingStrategy.RoundRobinAcrossDCs =>
                selectRoundRobin()
        }
    }

    /**
     * 选择本地 DC 优先
     */
    private func selectLocalDcFirst(localDc: String): Option<DcMemberInfo> {
        let localMembers = manager.getMembersInDc(localDc)
        let reachable = filterReachable(localMembers)

        if (reachable.size > 0) {
            return Some(reachable[0])
        }

        // 回退到其他 DC
        let allMembers = manager.getReachableMembers()
        if (allMembers.size > 0) {
            return Some(allMembers[0])
        }
        None
    }

    /**
     * 仅选择主 DC
     */
    private func selectPrimaryDcOnly(): Option<DcMemberInfo> {
        let primaryMembers = manager.getPrimaryDCMembers()
        let reachable = filterReachable(primaryMembers)

        if (reachable.size > 0) {
            return Some(reachable[0])
        }
        None
    }

    /**
     * 从所有 DC 选择
     */
    private func selectFromAll(): Option<DcMemberInfo> {
        let allMembers = manager.getReachableMembers()
        if (allMembers.size > 0) {
            return Some(allMembers[0])
        }
        None
    }

    /**
     * 跨 DC 轮询选择
     */
    private func selectRoundRobin(): Option<DcMemberInfo> {
        lock.lock()
        let dcs = manager.getDatacenters()
        if (dcs.size == 0) {
            lock.unlock()
            return None
        }

        let selectedDc = dcs[currentDcIndex % dcs.size]
        currentDcIndex += 1
        lock.unlock()

        let members = manager.getMembersInDc(selectedDc)
        let reachable = filterReachable(members)

        if (reachable.size > 0) {
            return Some(reachable[0])
        }
        None
    }

    /**
     * 过滤可达成员
     */
    private func filterReachable(members: ArrayList<DcMemberInfo>): ArrayList<DcMemberInfo> {
        let result = ArrayList<DcMemberInfo>()
        for (m in members) {
            if (m.isReachabl && match (m.status) {
                case MemberStatus.Up => true
                case _ => false
            }) {
                result.add(m)
            }
        }
        result
    }

    /**
     * 选择多个目标（广播）
     */
    public func selectTargets(localDc: String, count: Int64): ArrayList<DcMemberInfo> {
        let result = ArrayList<DcMemberInfo>()

        match (strategy) {
            case DcRoutingStrategy.LocalDCFirst =>
                let local = manager.getMembersInDc(localDc)
                let reachable = filterReachable(local)
                var i: Int64 = 0
                while (i < count && i < reachable.size) {
                    result.add(reachable[i])
                    i += 1
                }
            case _ =>
                let all = manager.getReachableMembers()
                var i: Int64 = 0
                while (i < count && i < all.size) {
                    result.add(all[i])
                    i += 1
                }
        }
        result
    }
}

/**
 * DC 故障转移管理器
 */
public class DcFailoverManager {
    private let config: MultiDcConfig
    private let manager: DcMembershipManager
    private var primaryDCAvailable: AtomicBool
    private let lock: Mutex

    public init(config: MultiDcConfig, manager: DcMembershipManager) {
        this.config = config
        this.manager = manager
        this.primaryDCAvailable = AtomicBool(true)
        this.lock = Mutex()
    }

    /**
     * 检查是否需要故障转移
     */
    public func shouldFailover(): Bool {
        if (!config.crossDcReplication) {
            return false
        }

        let primaryCount = manager.getMemberCount(config.primaryDC)
        primaryCount == 0
    }

    /**
     * 执行故障转移
     */
    public func executeFailover(): Option<String> {
        lock.lock()
        var result: Option<String>
        try {
            if (!shouldFailover()) {
                result = None
            } else {
                let dcs = manager.getDatacenters()
                for (dc in dcs) {
                    if (dc != config.primaryDC) {
                        let count = manager.getMemberCount(dc)
                        if (count > 0) {
                            primaryDCAvailable.store(false)
                            result = Some(dc)
                            return result
                        }
                    }
                }
                result = None
            }
        } finally {
            lock.unlock()
        }
        result
    }

    /**
     * 检查主 DC 是否可用
     */
    public func isPrimaryDCAvailable(): Bool {
        primaryDCAvailable.load()
    }

    /**
     * 恢复主 DC
     */
    public func recoverPrimaryDC(): Unit {
        lock.lock()
        try {
            primaryDCAvailable.store(true)
        } finally {
            lock.unlock()
        }
    }

    /**
     * 获取当前活跃 DC
     */
    public func getActiveDC(): String {
        if (primaryDCAvailable.load()) {
            config.primaryDC
        } else {
            let dcs = manager.getDatacenters()
            if (dcs.size > 0) {
                dcs[0]
            } else {
                config.primaryDC
            }
        }
    }
}

/**
 * 创建 Multi-DC 配置
 */
public func createMultiDcConfig(
    primaryDC: String,
    crossDcReplication: Bool,
    dcAwareRouting: Bool
): MultiDcConfig {
    MultiDcConfig(
        true,
        primaryDC,
        crossDcReplication,
        dcAwareRouting,
        Duration.second * 30,
        Duration.second * 5,
        3
    )
}

/**
 * 创建默认 Multi-DC 配置
 */
public func createDefaultMultiDcConfig(): MultiDcConfig {
    MultiDcConfig.defaultConfig()
}

/**
 * 创建 DC 感知路由器
 */
public func createDcAwareRouter(
    manager: DcMembershipManager,
    strategy: DcRoutingStrategy
): DcAwareRouter {
    DcAwareRouter(manager, strategy)
}
