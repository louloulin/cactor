/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 集群协议
 * 对标 Akka Cluster
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.ActorRef
import cactor.core.message.Message
import cactor.core.system.SimpleFuture

/**
 * 成员状态 - 对标 Akka MemberStatus
 */
public enum MemberStatus {
    | Joining      // 加入中
    | WeaklyUp     // 弱上线
    | Up           // 上线
    | Leaving      // 离开中
    | Exiting      // 退出中
    | Down         // 下线
    | Removed      // 已移除

    public func toInt64(): Int64 {
        match (this) {
            case Joining => 0
            case WeaklyUp => 1
            case Up => 2
            case Leaving => 3
            case Exiting => 4
            case Down => 5
            case Removed => 6
        }
    }

    public static func fromInt64(value: Int64): MemberStatus {
        match (value) {
            case 0 => Joining
            case 1 => WeaklyUp
            case 2 => Up
            case 3 => Leaving
            case 4 => Exiting
            case 5 => Down
            case 6 => Removed
            case _ => Removed
        }
    }

    public func isAtLeast(target: MemberStatus): Bool {
        this.toInt64() >= target.toInt64()
    }

    public func isActive(): Bool {
        match (this) {
            case Up | WeaklyUp => true
            case _ => false
        }
    }
}

/**
 * 成员角色
 */
public class MemberRole {
    private let name: String

    public init(name: String) {
        this.name = name
    }

    public func getName(): String {
        name
    }

    public func equals(other: MemberRole): Bool {
        name == other.name
    }

    public func hashCode(): Int64 {
        name.hashCode()
    }
}

/**
 * 成员接口 - 对标 Akka Member
 */
public interface Member {
    /**
     * 获取成员地址
     * @return 地址
     */
    func address(): Address

    /**
     * 获取成员状态
     * @return 状态
     */
    func getStatus(): MemberStatus

    /**
     * 获取成员角色
     * @return 角色集合
     */
    func getRoles(): Set<MemberRole>

    /**
     * 获取成员唯一编号
     * @return 编号
     */
    func getUniqueAddress(): UniqueAddress

    /**
     * 检查是否有特定角色
     * @param role 角色
     * @return 是否有该角色
     */
    func hasRole(role: String): Bool

    /**
     * 获取节点优先级（用于Leader选举）
     * @return 优先级
     */
    func priority(): Int64
}

/**
 * 唯一地址 - 对标 Akka UniqueAddress
 */
public class UniqueAddress <: Hashable & Equatable<UniqueAddress> & ToString {
    public let address: Address
    public let uid: Int64

    public init(address: Address, uid: Int64) {
        this.address = address
        this.uid = uid
    }

    public func toString(): String {
        "${address.toString()}:${uid}"
    }

    public func equals(other: UniqueAddress): Bool {
        address.equals(other.address) && uid == other.uid
    }

    public operator func ==(other: UniqueAddress): Bool {
        equals(other)
    }

    public func hashCode(): Int64 {
        address.hashCode() ^ uid
    }
}

/**
 * 成员实现
 */
public class MemberImpl <: Member {
    private let uniqueAddress: UniqueAddress
    private let roles: Set<MemberRole>
    private var status: MemberStatus

    public init(uniqueAddress: UniqueAddress, roles: Set<MemberRole>) {
        this.uniqueAddress = uniqueAddress
        this.roles = roles
        this.status = MemberStatus.Joining
    }

    public func address(): Address {
        uniqueAddress.address
    }

    public func getStatus(): MemberStatus {
        status
    }

    public func getRoles(): Set<MemberRole> {
        roles
    }

    public func getUniqueAddress(): UniqueAddress {
        uniqueAddress
    }

    public func hasRole(role: String): Bool {
        roles.contains(MemberRole(role))
    }

    public func priority(): Int64 {
        uniqueAddress.uid
    }

    public func updateStatus(newStatus: MemberStatus): MemberImpl {
        let copy = MemberImpl(uniqueAddress, roles)
        copy.status = newStatus
        copy
    }
}

/**
 * 集群状态 - 对标 Akka ClusterState
 */
public class ClusterMembershipState {
    public let members: HashMap<UniqueAddress, Member>
    public let leader: Option<UniqueAddress>
    public let seenBy: Set<UniqueAddress>
    public let reachability: Reachability
    public let version: Int64

    public init() {
        this.members = HashMap<UniqueAddress, Member>()
        this.leader = None
        this.seenBy = HashSet<UniqueAddress>()
        this.reachability = Reachability()
        this.version = 0
    }

    public func getMember(address: UniqueAddress): Option<Member> {
        members.get(address)
    }

    public func getMembersByStatus(status: MemberStatus): Array<Member> {
        let result = ArrayList<Member>()
        for ((_, member) in members) {
            let memberStatus = member.getStatus()
            if (memberStatus.toInt64() == status.toInt64()) {
                result.add(member)
            }
        }
        result.toArray()
    }

    public func memberCount(): Int64 {
        Int64(members.size)
    }

    public func activeMemberCount(): Int64 {
        var count = 0
        for ((_, member) in members) {
            if (member.getStatus().isActive()) {
                count += 1
            }
        }
        count
    }
}

/**
 * 可达性 - 对标 Akka Reachability
 */
public class Reachability {
    public let entries: HashMap<UniqueAddress, ReachabilityStatus>

    public init() {
        this.entries = HashMap<UniqueAddress, ReachabilityStatus>()
    }

    public func isReachable(address: UniqueAddress): Bool {
        match (entries.get(address)) {
            case Some(status) => match (status) {
                case ReachabilityStatus.Reachable => true
                case _ => false
            }
            case None => true
        }
    }

    public func isUnreachable(address: UniqueAddress): Bool {
        !isReachable(address)
    }
}

/**
 * 可达性状态
 */
public enum ReachabilityStatus {
    | Reachable
    | Unreachable
    | Terminated
}

/**
 * Gossip状态 - 对标 Akka Gossip
 */
public class Gossip {
    public var version: Int64
    public var members: HashMap<UniqueAddress, MemberState>
    public var overview: GossipOverview

    public init() {
        this.version = 0
        this.members = HashMap<UniqueAddress, MemberState>()
        this.overview = GossipOverview()
    }

    public func incrementVersion(): Gossip {
        let newGossip = Gossip()
        newGossip.version = version + 1
        newGossip.members = members
        newGossip.overview = overview
        newGossip
    }

    public func merge(other: Gossip): Gossip {
        let result = Gossip()
        result.version = if (version > other.version) { version } else { other.version }
        // 简化合并逻辑
        result
    }
}

/**
 * Gossip概述
 */
public class GossipOverview {
    public let seen: Set<UniqueAddress>
    public let reachability: Reachability

    public init() {
        this.seen = HashSet<UniqueAddress>()
        this.reachability = Reachability()
    }
}

/**
 * 成员状态
 */
public class MemberState {
    public let status: MemberStatus
    public let roles: Set<MemberRole>
    public let appVersion: Int64

    public init(status: MemberStatus, roles: Set<MemberRole>) {
        this.status = status
        this.roles = roles
        this.appVersion = 0
    }
}

/**
 * 集群协议接口 - 对标 Akka Cluster
 */
public interface ClusterProtocol {
    /**
     * 加入集群
     * @param address 要加入的地址
     */
    func join(address: Address): SimpleFuture<Unit>

    /**
     * 离开集群
     * @param address 要离开的地址
     */
    func leave(address: Address): SimpleFuture<Unit>

    /**
     * 下线节点
     * @param address 要下线的地址
     */
    func down(address: Address): SimpleFuture<Unit>

    /**
     * 获取当前成员集合
     * @return 成员集合
     */
    func members(): Set<Member>

    /**
     * 获取当前集群状态
     * @return 状态
     */
    func state(): ClusterMembershipState

    /**
     * 获取集群事件流
     * @return 事件订阅
     */
    func events(): ClusterEventStream

    /**
     * 订阅集群事件
     * @param subscriber 订阅者
     * @param eventType 事件类型
     */
    func subscribe(subscriber: ActorRef, eventType: Class): Unit

    /**
     * 取消订阅
     * @param subscriber 订阅者
     * @param eventType 事件类型
     */
    func unsubscribe(subscriber: ActorRef, eventType: Class): Unit
}

/**
 * 集群事件流
 */
public interface ClusterEventStream {
    /**
     * 发布事件
     * @param event 事件
     */
    func publish(event: ClusterDomainEvent): Unit
}

/**
 * 集群事件 - 对标 Akka ClusterEvent
 */
public interface ClusterDomainEvent {
    func eventType(): String
}

/**
 * 成员加入事件
 */
public class MemberJoined <: ClusterDomainEvent {
    public let member: Member

    public init(member: Member) {
        this.member = member
    }

    public func eventType(): String {
        "MemberJoined"
    }
}

/**
 * 成员上线事件
 */
public class MemberUp <: ClusterDomainEvent {
    public let member: Member

    public init(member: Member) {
        this.member = member
    }

    public func eventType(): String {
        "MemberUp"
    }
}

/**
 * 成员离开事件
 */
public class MemberLeft <: ClusterDomainEvent {
    public let member: Member

    public init(member: Member) {
        this.member = member
    }

    public func eventType(): String {
        "MemberLeft"
    }
}

/**
 * 成员下线事件
 */
public class MemberExited <: ClusterDomainEvent {
    public let member: Member

    public init(member: Member) {
        this.member = member
    }

    public func eventType(): String {
        "MemberExited"
    }
}

/**
 * 成员移除事件
 */
public class MemberRemoved <: ClusterDomainEvent {
    public let member: Member

    public init(member: Member) {
        this.member = member
    }

    public func eventType(): String {
        "MemberRemoved"
    }
}

/**
 * Leader变更事件
 */
public class LeaderChanged <: ClusterDomainEvent {
    public let leader: Option<Address>

    public init(leader: Option<Address>) {
        this.leader = leader
    }

    public func eventType(): String {
        "LeaderChanged"
    }
}

/**
 * 角色类（占位）
 */
public class Class {
    private let name: String

    public init(name: String) {
        this.name = name
    }

    public func getName(): String {
        name
    }
}

/**
 * 地址
 */
public struct Address {
    public let protocol: String
    public let system: String
    public let host: String
    public let port: Int32

    public init(protocol: String, system: String, host: String, port: Int32) {
        this.protocol = protocol
        this.system = system
        this.host = host
        this.port = port
    }

    public func toString(): String {
        "${protocol}://${system}@${host}:${port}"
    }

    public func equals(other: Address): Bool {
        protocol == other.protocol && system == other.system && host == other.host && port == other.port
    }

    public func hashCode(): Int64 {
        protocol.hashCode() ^ system.hashCode() ^ host.hashCode() ^ Int64(port)
    }
}

/**
 * 集合接口（占位）
 */
public interface Set<T> {
    func add(item: T): Unit
    func contains(item: T): Bool
    func size(): Int64
}

/**
 * HashSet实现
 */
public class HashSet<T> <: Set<T> where T <: Hashable & Equatable<T> {
    private let map: HashMap<T, Bool>

    public init() {
        this.map = HashMap<T, Bool>()
    }

    public init(items: Array<T>) {
        this.map = HashMap<T, Bool>()
        for (item in items) {
            map.add(item, true)
        }
    }

    public func add(item: T): Unit {
        map.add(item, true)
    }

    public func size(): Int64 {
        map.size
    }

    public func contains(item: T): Bool {
        map.contains(item)
    }

    public func clear(): Unit {
        map.clear()
    }

    public func remove(item: T): Bool {
        match (map.remove(item)) {
            case Some(v) => v
            case None => false
        }
    }

    public func toArray(): Array<T> {
        let result = ArrayList<T>()
        for ((key, _) in map) {
            result.add(key)
        }
        result.toArray()
    }
}
