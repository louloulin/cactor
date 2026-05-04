/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - DowningProvider 集群宕机处理机制
 * 对标 Akka Cluster DowningProvider
 * 决定不可达成员何时被标记为 DOWN
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * Downing 可达性状态
 * 用于 DowningProvider 内部表示成员的可达性
 */
public enum DowningReachability {
    | Reachable
    | Unreachable
    | Down

    public func isReachable(): Bool {
        match (this) {
            case Reachable => true
            case _ => false
        }
    }

    public func isDown(): Bool {
        match (this) {
            case Down => true
            case _ => false
        }
    }
}

/**
 * Downing 成员信息
 * 用于 DowningProvider 处理的简化成员信息
 */
public class MemberInfo2 {
    public let nodeId: String
    public let address: Address
    public var reachability: DowningReachability
    public var status: MemberStatus
    public var upTimestamp: Int64

    public init(nodeId: String, address: Address) {
        this.nodeId = nodeId
        this.address = address
        this.reachability = DowningReachability.Reachable
        this.status = MemberStatus.Up
        this.upTimestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func withReachability(r: DowningReachability): MemberInfo2 {
        let copy = MemberInfo2(nodeId, address)
        copy.reachability = r
        copy.status = status
        copy.upTimestamp = upTimestamp
        copy
    }

    public func withStatus(s: MemberStatus): MemberInfo2 {
        let copy = MemberInfo2(nodeId, address)
        copy.reachability = reachability
        copy.status = s
        copy.upTimestamp = upTimestamp
        copy
    }
}

/**
 * Downing 决策
 */
public class DowningDecision {
    public let nodesToDown: ArrayList<MemberInfo2>
    public let reason: String
    public let timestamp: Int64

    public init(nodesToDown: ArrayList<MemberInfo2>, reason: String) {
        this.nodesToDown = nodesToDown
        this.reason = reason
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func isEmpty(): Bool {
        nodesToDown.size == 0
    }

    public func size(): Int64 {
        nodesToDown.size
    }
}

/**
 * DowningProvider 接口 - 对标 Akka DowningProvider
 * 决定不可达节点何时被标记为 DOWN
 */
public interface DowningProvider {
    /**
     * 处理不可达成员变更
     */
    func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision

    /**
     * 处理成员变更
     */
    func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision

    /**
     * 获取名称
     */
    func name(): String
}

/**
 * 检查成员状态是否为 Up
 */
public func isMemberStatusUp(status: MemberStatus): Bool {
    match (status) {
        case MemberStatus.Up => true
        case _ => false
    }
}

/**
 * 自动 Downing Provider
 * 不可达成员超时后自动标记为 DOWN
 */
public class AutoDowningProvider <: DowningProvider {
    private let timeout: Duration
    private let unreachableTime: HashMap<String, Int64>
    private let lock: ReentrantReadWriteMutex

    public init(timeout: Duration) {
        this.timeout = timeout
        this.unreachableTime = HashMap<String, Int64>()
        this.lock = ReentrantReadWriteMutex()
    }

    public func name(): String {
        "auto-downing"
    }

    public func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let toDown = ArrayList<MemberInfo2>()

        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Unreachable =>
                    lock.writeMutex.lock()
                    let existing = unreachableTime.get(member.nodeId)
                    if (existing.isNone()) {
                        unreachableTime.add(member.nodeId, now)
                    }
                    lock.writeMutex.unlock()

                    lock.readMutex.lock()
                    let unreachableSince = unreachableTime.get(member.nodeId).getOrDefault({=> now})
                    lock.readMutex.unlock()

                    let elapsed = now - unreachableSince
                    if (elapsed >= timeout.toMilliseconds()) {
                        toDown.add(member.withReachability(DowningReachability.Down))
                        lock.writeMutex.lock()
                        unreachableTime.remove(member.nodeId)
                        lock.writeMutex.unlock()
                    }
                case DowningReachability.Reachable =>
                    lock.writeMutex.lock()
                    unreachableTime.remove(member.nodeId)
                    lock.writeMutex.unlock()
                case _ => ()
            }
        }

        DowningDecision(toDown, "auto-downing-timeout")
    }

    public func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision {
        let toDown = ArrayList<MemberInfo2>()
        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Down =>
                    if (!isMemberStatusUp(member.status)) {
                        toDown.add(member)
                    }
                case _ => ()
            }
        }
        DowningDecision(toDown, "member-change-cleanup")
    }
}

/**
 * 多数派 Downing Provider
 * 保留多数派分区，将少数派分区标记为 DOWN
 */
public class MajorityDowningProvider <: DowningProvider {
    private let selfAddress: Address
    private let lock: ReentrantReadWriteMutex

    public init(selfAddress: Address) {
        this.selfAddress = selfAddress
        this.lock = ReentrantReadWriteMutex()
    }

    public func name(): String {
        "majority-downing"
    }

    public func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision {
        let reachable = ArrayList<MemberInfo2>()
        let unreachable = ArrayList<MemberInfo2>()

        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Reachable => reachable.add(member)
                case DowningReachability.Unreachable => unreachable.add(member)
                case _ => ()
            }
        }

        let totalCount = reachable.size + unreachable.size
        let majorityCount = totalCount / 2 + 1

        if (reachable.size >= majorityCount) {
            let toDown = ArrayList<MemberInfo2>()
            for (member in unreachable) {
                toDown.add(member.withReachability(DowningReachability.Down))
            }
            DowningDecision(toDown, "majority-downing-minority")
        } else {
            DowningDecision(ArrayList<MemberInfo2>(), "majority-downing-self-minority")
        }
    }

    public func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision {
        DowningDecision(ArrayList<MemberInfo2>(), "no-change")
    }
}

/**
 * 静态法定人数 Downing Provider
 * 当不可达节点数超过阈值时，将所有不可达标记为 DOWN
 */
public class StaticQuorumDowningProvider <: DowningProvider {
    private let quorumSize: Int64
    private let lock: ReentrantReadWriteMutex

    public init(quorumSize: Int64) {
        this.quorumSize = quorumSize
        this.lock = ReentrantReadWriteMutex()
    }

    public func name(): String {
        "static-quorum-downing"
    }

    public func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision {
        let reachable = ArrayList<MemberInfo2>()
        let unreachable = ArrayList<MemberInfo2>()

        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Reachable => reachable.add(member)
                case DowningReachability.Unreachable => unreachable.add(member)
                case _ => ()
            }
        }

        if (reachable.size < quorumSize) {
            let toDown = ArrayList<MemberInfo2>()
            for (member in unreachable) {
                toDown.add(member.withReachability(DowningReachability.Down))
            }
            DowningDecision(toDown, "static-quorum-below-threshold")
        } else {
            DowningDecision(ArrayList<MemberInfo2>(), "quorum-ok")
        }
    }

    public func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision {
        DowningDecision(ArrayList<MemberInfo2>(), "no-change")
    }
}

/**
 * 最老节点 Downing Provider
 * 保留最老的节点，如果没有不可达则不做任何操作
 */
public class KeepOldestDowningProvider <: DowningProvider {
    private let downIfOldestUnreachable: Bool
    private let lock: ReentrantReadWriteMutex

    public init(downIfOldestUnreachable: Bool) {
        this.downIfOldestUnreachable = downIfOldestUnreachable
        this.lock = ReentrantReadWriteMutex()
    }

    public func name(): String {
        "keep-oldest-downing"
    }

    public func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision {
        if (members.size == 0) {
            return DowningDecision(ArrayList<MemberInfo2>(), "no-members")
        }

        var oldestTime: Int64 = members[0].upTimestamp
        var oldestMember = members[0]
        for (member in members) {
            if (member.upTimestamp < oldestTime) {
                oldestTime = member.upTimestamp
                oldestMember = member
            }
        }

        let toDown = ArrayList<MemberInfo2>()
        match (oldestMember.reachability) {
            case DowningReachability.Unreachable =>
                if (downIfOldestUnreachable) {
                    toDown.add(oldestMember.withReachability(DowningReachability.Down))
                }
            case _ => ()
        }

        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Unreachable =>
                    if (member.nodeId != oldestMember.nodeId) {
                        toDown.add(member.withReachability(DowningReachability.Down))
                    }
                case _ => ()
            }
        }

        DowningDecision(toDown, "keep-oldest")
    }

    public func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision {
        DowningDecision(ArrayList<MemberInfo2>(), "no-change")
    }
}

/**
 * 全部下线 Downing Provider
 * 任何不可达节点都将被标记为 DOWN
 */
public class DownAllDowningProvider <: DowningProvider {
    public func name(): String {
        "down-all-downing"
    }

    public func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision {
        let toDown = ArrayList<MemberInfo2>()
        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Unreachable =>
                    toDown.add(member.withReachability(DowningReachability.Down))
                case _ => ()
            }
        }
        DowningDecision(toDown, "down-all-unreachable")
    }

    public func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision {
        DowningDecision(ArrayList<MemberInfo2>(), "no-change")
    }
}

/**
 * 创建自动 Downing Provider
 */
public func createAutoDowningProvider(timeout: Duration): AutoDowningProvider {
    AutoDowningProvider(timeout)
}

/**
 * 创建多数派 Downing Provider
 */
public func createMajorityDowningProvider(selfAddress: Address): MajorityDowningProvider {
    MajorityDowningProvider(selfAddress)
}

/**
 * 创建静态法定人数 Downing Provider
 */
public func createStaticQuorumDowningProvider(quorumSize: Int64): StaticQuorumDowningProvider {
    StaticQuorumDowningProvider(quorumSize)
}
