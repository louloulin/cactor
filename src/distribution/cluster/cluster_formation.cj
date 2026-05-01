/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Formation 和 Gossip 协议实现
 * 对标 Akka Cluster Gossip
 * 提供 Gossip 协议、心跳等功能
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*
import std.convert.*

/**
 * Gossip 汇总
 */
public class GossipSummary {
    public let version: Int64
    public let memberCount: Int64
    public let timestamp: Int64

    public init(version: Int64, memberCount: Int64) {
        this.version = version
        this.memberCount = memberCount
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func activeMemberCount(): Int64 {
        memberCount  // 简化：返回总成员数
    }
}

/**
 * Gossip 消息类型
 */
public enum GossipMessage {
    | GossipDigest(String, Int64)
    | GossipDigestAck(String, GossipSummary)
    | GossipDigestAck2(GossipSummary)
    | GossipHeartbeat(String, Int64)
}

/**
 * Gossip 协议实现
 */
public class GossipProtocol {
    private let nodeId: String
    private var gossipVersion: Int64
    private var memberCount: Int64
    private let clusterConfig: ClusterConfig
    private let lock: ReentrantReadWriteMutex

    public init(nodeId: String, config: ClusterConfig) {
        this.nodeId = nodeId
        this.gossipVersion = 0
        this.memberCount = 0
        this.clusterConfig = config
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 添加成员
     */
    public func addMember(): Unit {
        try {
            lock.writeMutex.lock()
            memberCount += 1
            gossipVersion += 1
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 获取当前 gossip
     */
    public func getCurrentGossip(): GossipSummary {
        try {
            lock.readMutex.lock()
            let gossip = GossipSummary(gossipVersion, memberCount)
            lock.readMutex.unlock()
            return gossip
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return GossipSummary(0, 0)
        }
    }

    /**
     * 处理 gossip 消息
     */
    public func handleGossip(message: GossipMessage): GossipSummary {
        match (message) {
            case GossipDigest(_, remoteVersion) =>
                this.handleGossipDigest(remoteVersion)
            case GossipDigestAck(remoteNodeId, remoteGossip) =>
                this.handleGossipDigestAck(remoteNodeId, remoteGossip)
            case GossipDigestAck2(remoteGossip) =>
                this.handleGossipDigestAck2(remoteGossip)
            case GossipHeartbeat(_, _) =>
                this.handleHeartbeat()
        }
    }

    private func handleGossipDigest(remoteVersion: Int64): GossipSummary {
        try {
            lock.readMutex.lock()
            let localGossip = GossipSummary(gossipVersion, memberCount)
            lock.readMutex.unlock()
            return localGossip
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return GossipSummary(0, 0)
        }
    }

    private func handleGossipDigestAck(remoteNodeId: String, remoteGossip: GossipSummary): GossipSummary {
        try {
            lock.writeMutex.lock()
            // 合并：取较大版本和成员数
            if (remoteGossip.version > gossipVersion) {
                gossipVersion = remoteGossip.version + 1
            }
            if (remoteGossip.memberCount > memberCount) {
                memberCount = remoteGossip.memberCount
            }
            let result = GossipSummary(gossipVersion, memberCount)
            lock.writeMutex.unlock()
            return result
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            return GossipSummary(0, 0)
        }
    }

    private func handleGossipDigestAck2(remoteGossip: GossipSummary): GossipSummary {
        this.handleGossipDigestAck(nodeId, remoteGossip)
    }

    private func handleHeartbeat(): GossipSummary {
        try {
            lock.writeMutex.lock()
            gossipVersion += 1
            let result = GossipSummary(gossipVersion, memberCount)
            lock.writeMutex.unlock()
            return result
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            return GossipSummary(0, 0)
        }
    }

    /**
     * 获取成员数
     */
    public func getMemberCount(): Int64 {
        try {
            lock.readMutex.lock()
            let count = memberCount
            lock.readMutex.unlock()
            return count
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return 0
        }
    }
}

/**
 * 集群配置
 */
public class ClusterConfig {
    public let clusterName: String
    public let port: Int32
    public let host: String
    public let seedNodes: ArrayList<String>
    public let gossipInterval: Duration
    public let heartbeatInterval: Duration
    public let failureTimeout: Duration
    public let reachableNodes: Int64
    public let downingProvider: String

    public init(
        clusterName!: String = "cactor-cluster",
        port!: Int32 = 2552,
        host!: String = "localhost",
        seedNodes!: ArrayList<String> = ArrayList<String>(),
        gossipInterval!: Duration = Duration.millisecond * 500,
        heartbeatInterval!: Duration = Duration.millisecond * 1000,
        failureTimeout!: Duration = Duration.second * 5,
        reachableNodes!: Int64 = 2,
        downingProvider!: String = "auto"
    ) {
        this.clusterName = clusterName
        this.port = port
        this.host = host
        this.seedNodes = seedNodes
        this.gossipInterval = gossipInterval
        this.heartbeatInterval = heartbeatInterval
        this.failureTimeout = failureTimeout
        this.reachableNodes = reachableNodes
        this.downingProvider = downingProvider
    }

    public static func getDefault(): ClusterConfig {
        ClusterConfig()
    }
}

/**
 * 节点发现服务
 */
public interface NodeDiscovery {
    func discoverNodes(): ArrayList<NodeInfo>
    func registerCallback(callback: (String) -> Unit): Unit
}

/**
 * 简化的节点信息
 */
public class NodeInfo {
    public let nodeId: String
    public let host: String
    public let port: Int32

    public init(nodeId: String, host: String, port: Int32) {
        this.nodeId = nodeId
        this.host = host
        this.port = port
    }

    public func address(): String {
        "${host}:${port}"
    }
}

/**
 * 基于种子节点的发现
 */
public class SeedNodeDiscovery <: NodeDiscovery {
    private let seeds: ArrayList<String>
    private let lock: Mutex
    private let callbacks: ArrayList<(String) -> Unit>

    public init(seeds: ArrayList<String>) {
        this.seeds = seeds
        this.lock = Mutex()
        this.callbacks = ArrayList<(String) -> Unit>()
    }

    public func discoverNodes(): ArrayList<NodeInfo> {
        let result = ArrayList<NodeInfo>()
        for (seed in seeds) {
            let parts = seed.split("@")
            if (parts.size >= 2) {
                let system = parts[0]
                let hostPort = parts[1].split(":")
                if (hostPort.size >= 2) {
                    let host = hostPort[0]
                    let portVal = Int64.parse(hostPort[1])
                    let nodeInfo = NodeInfo("seed-${host}", host, Int32(portVal))
                    result.add(nodeInfo)
                }
            }
        }
        result
    }

    public func registerCallback(callback: (String) -> Unit): Unit {
        try {
            lock.lock()
            callbacks.add(callback)
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }
}

/**
 * 集群成员管理器
 */
public class ClusterMembershipManager {
    private let nodeId: String
    private let protocol: GossipProtocol
    private let config: ClusterConfig
    private let lock: ReentrantReadWriteMutex

    public init(nodeId: String, config: ClusterConfig) {
        this.nodeId = nodeId
        this.protocol = GossipProtocol(nodeId, config)
        this.config = config
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 加入集群
     */
    public func join(): Unit {
        protocol.addMember()
    }

    /**
     * 标记为已上线
     */
    public func becomeUp(): Unit {
        // 成员已添加，视为上线
    }

    /**
     * 离开集群
     */
    public func leave(): Unit {
        // 简化：减少成员数
    }

    /**
     * 下线
     */
    public func down(): Unit {
        // 简化处理
    }

    /**
     * 获取成员数
     */
    public func getMemberCount(): Int64 {
        protocol.getMemberCount()
    }

    /**
     * 发送 gossip
     */
    public func sendGossip(): GossipSummary {
        protocol.getCurrentGossip()
    }

    /**
     * 处理 gossip 响应
     */
    public func receiveGossip(gossip: GossipSummary): Unit {
        let ack = GossipDigestAck2(gossip)
        protocol.handleGossip(ack)
    }
}