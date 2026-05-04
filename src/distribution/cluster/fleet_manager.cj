/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Fleet Manager 节点管理机制
 * 对标 Akka Cluster Fleet Manager
 * 管理集群节点的成员、状态和生命周期
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 节点健康状态
 */
public enum NodeHealth <: ToString {
    | Healthy
    | Degraded
    | Unhealthy
    | Unknown

    public func isHealthy(): Bool {
        match (this) {
            case Healthy => true
            case _ => false
        }
    }

    public func toString(): String {
        match (this) {
            case Healthy => "Healthy"
            case Degraded => "Degraded"
            case Unhealthy => "Unhealthy"
            case Unknown => "Unknown"
        }
    }

    public func needsAttention(): Bool {
        match (this) {
            case Degraded | Unhealthy => true
            case _ => false
        }
    }
}

/**
 * 节点信息
 */
public class FleetNode {
    public let nodeId: String
    public let address: Address
    public var status: MemberStatus
    public var health: NodeHealth
    public var lastSeen: Int64
    public var version: Int64
    public var metadata: HashMap<String, String>

    public init(nodeId: String, address: Address) {
        this.nodeId = nodeId
        this.address = address
        this.status = MemberStatus.Joining
        this.health = NodeHealth.Unknown
        this.lastSeen = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.version = 1
        this.metadata = HashMap<String, String>()
    }

    public func withStatus(s: MemberStatus): FleetNode {
        let node = FleetNode(nodeId, address)
        node.status = s
        node.health = health
        node.lastSeen = lastSeen
        node.version = version + 1
        node.metadata = metadata
        node
    }

    public func withHealth(h: NodeHealth): FleetNode {
        let node = FleetNode(nodeId, address)
        node.status = status
        node.health = h
        node.lastSeen = lastSeen
        node.version = version + 1
        node.metadata = metadata
        node
    }

    public func touch(): FleetNode {
        let node = FleetNode(nodeId, address)
        node.status = status
        node.health = health
        node.lastSeen = DateTime.now().toUnixTimeStamp().toMilliseconds()
        node.version = version
        node.metadata = metadata
        node
    }

    public func withMetadata(key: String, value: String): FleetNode {
        let node = FleetNode(nodeId, address)
        node.status = status
        node.health = health
        node.lastSeen = lastSeen
        node.version = version
        for ((k, v) in metadata) {
            node.metadata.add(k, v)
        }
        node.metadata.add(key, value)
        node
    }
}

/**
 * Fleet 事件
 */
public enum FleetEvent {
    | NodeJoined(String, Address)
    | NodeUp(String, Address)
    | NodeLeft(String)
    | NodeDown(String)
    | NodeRemoved(String)
    | HealthChanged(String, NodeHealth)
    | VersionChanged(String, Int64)

    public func toString(): String {
        match (this) {
            case NodeJoined(id, addr) => "NodeJoined(${id}, ${addr})"
            case NodeUp(id, addr) => "NodeUp(${id}, ${addr})"
            case NodeLeft(id) => "NodeLeft(${id})"
            case NodeDown(id) => "NodeDown(${id})"
            case NodeRemoved(id) => "NodeRemoved(${id})"
            case HealthChanged(id, h) => "HealthChanged(${id}, ${h})"
            case VersionChanged(id, v) => "VersionChanged(${id}, ${v})"
        }
    }
}

/**
 * Fleet 事件处理器
 */
public interface FleetEventHandler {
    func onNodeJoined(node: FleetNode): Unit
    func onNodeUp(node: FleetNode): Unit
    func onNodeLeft(node: FleetNode): Unit
    func onNodeDown(node: FleetNode): Unit
    func onNodeRemoved(node: FleetNode): Unit
    func onHealthChanged(node: FleetNode, oldHealth: NodeHealth, newHealth: NodeHealth): Unit
}

/**
 * Fleet 配置
 */
public class FleetConfig {
    public let fleetName: String
    public let nodeTimeout: Duration
    public let healthCheckInterval: Duration
    public let maxUnhealthyNodes: Int64
    public let autoRemoveDownNodes: Bool

    public init(fleetName: String) {
        this.fleetName = fleetName
        this.nodeTimeout = Duration.minute * 3
        this.healthCheckInterval = Duration.second * 30
        this.maxUnhealthyNodes = 3
        this.autoRemoveDownNodes = true
    }
}

/**
 * Fleet Manager - 对标 Akka Fleet Manager
 * 管理集群节点的成员、状态和生命周期
 */
public class FleetManager {
    private let config: FleetConfig
    private let nodes: HashMap<String, FleetNode>
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<FleetEventHandler>

    public init(config: FleetConfig) {
        this.config = config
        this.nodes = HashMap<String, FleetNode>()
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
    }

    public func setEventHandler(handler: FleetEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 注册节点
     */
    public func registerNode(node: FleetNode): Unit {
        lock.writeMutex.lock()
        let existing = nodes.get(node.nodeId)
        nodes.add(node.nodeId, node)
        lock.writeMutex.unlock()

        match (existing) {
            case Some(_) => ()
            case None =>
                match (eventHandler) {
                    case Some(handler) => handler.onNodeJoined(node)
                    case None => ()
                }
        }
    }

    /**
     * 节点上线
     */
    public func nodeUp(node: FleetNode): Unit {
        lock.writeMutex.lock()
        let existing = nodes.get(node.nodeId)
        nodes.add(node.nodeId, node.withStatus(MemberStatus.Up))
        lock.writeMutex.unlock()

        match (existing) {
            case Some(oldNode) =>
                match (eventHandler) {
                    case Some(handler) =>
                        if (!oldNode.status.isActive()) {
                            handler.onNodeUp(node)
                        }
                    case None => ()
                }
            case None =>
                match (eventHandler) {
                    case Some(handler) => handler.onNodeUp(node)
                    case None => ()
                }
        }
    }

    /**
     * 节点离开
     */
    public func nodeLeft(nodeId: String): Unit {
        lock.writeMutex.lock()
        let nodeOpt = nodes.get(nodeId)
        match (nodeOpt) {
            case Some(node) =>
                let updatedNode = node.withStatus(MemberStatus.Leaving)
                nodes.add(nodeId, updatedNode)
                lock.writeMutex.unlock()
                match (eventHandler) {
                    case Some(handler) => handler.onNodeLeft(updatedNode)
                    case None => ()
                }
            case None =>
                lock.writeMutex.unlock()
        }
    }

    /**
     * 节点下线
     */
    public func nodeDown(nodeId: String): Unit {
        lock.writeMutex.lock()
        let nodeOpt = nodes.get(nodeId)
        match (nodeOpt) {
            case Some(node) =>
                let updatedNode = node.withStatus(MemberStatus.Down)
                nodes.add(nodeId, updatedNode)
                lock.writeMutex.unlock()
                match (eventHandler) {
                    case Some(handler) => handler.onNodeDown(updatedNode)
                    case None => ()
                }
            case None =>
                lock.writeMutex.unlock()
        }
    }

    /**
     * 节点移除
     */
    public func removeNode(nodeId: String): Unit {
        lock.writeMutex.lock()
        let nodeOpt = nodes.remove(nodeId)
        lock.writeMutex.unlock()

        match (nodeOpt) {
            case Some(node) =>
                match (eventHandler) {
                    case Some(handler) => handler.onNodeRemoved(node)
                    case None => ()
                }
            case None => ()
        }
    }

    /**
     * 更新节点健康状态
     */
    public func updateHealth(nodeId: String, health: NodeHealth): Unit {
        lock.writeMutex.lock()
        let nodeOpt = nodes.get(nodeId)
        match (nodeOpt) {
            case Some(node) =>
                let oldHealth = node.health
                let updatedNode = node.withHealth(health)
                nodes.add(nodeId, updatedNode)
                lock.writeMutex.unlock()
                match (eventHandler) {
                    case Some(handler) => handler.onHealthChanged(updatedNode, oldHealth, health)
                    case None => ()
                }
            case None =>
                lock.writeMutex.unlock()
        }
    }

    /**
     * 获取节点
     */
    public func getNode(nodeId: String): Option<FleetNode> {
        lock.readMutex.lock()
        let node = nodes.get(nodeId)
        lock.readMutex.unlock()
        node
    }

    /**
     * 获取所有节点
     */
    public func getAllNodes(): ArrayList<FleetNode> {
        lock.readMutex.lock()
        let result = ArrayList<FleetNode>()
        for ((_, node) in nodes) {
            result.add(node)
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取活跃节点
     */
    public func getActiveNodes(): ArrayList<FleetNode> {
        lock.readMutex.lock()
        let result = ArrayList<FleetNode>()
        for ((_, node) in nodes) {
            if (node.status.isActive()) {
                result.add(node)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取健康节点
     */
    public func getHealthyNodes(): ArrayList<FleetNode> {
        lock.readMutex.lock()
        let result = ArrayList<FleetNode>()
        for ((_, node) in nodes) {
            if (node.health.isHealthy() && node.status.isActive()) {
                result.add(node)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取不健康节点
     */
    public func getUnhealthyNodes(): ArrayList<FleetNode> {
        lock.readMutex.lock()
        let result = ArrayList<FleetNode>()
        for ((_, node) in nodes) {
            if (node.health.needsAttention()) {
                result.add(node)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取节点数量
     */
    public func nodeCount(): Int64 {
        lock.readMutex.lock()
        let count = nodes.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取活跃节点数量
     */
    public func activeNodeCount(): Int64 {
        lock.readMutex.lock()
        var count = 0
        for ((_, node) in nodes) {
            if (node.status.isActive()) {
                count += 1
            }
        }
        lock.readMutex.unlock()
        count
    }

    /**
     * 检查节点是否存在
     */
    public func hasNode(nodeId: String): Bool {
        lock.readMutex.lock()
        let exists = nodes.contains(nodeId)
        lock.readMutex.unlock()
        exists
    }

    /**
     * 检查所有节点是否健康
     */
    public func isAllHealthy(): Bool {
        lock.readMutex.lock()
        var allHealthy = true
        for ((_, node) in nodes) {
            if (node.status.isActive() && !node.health.isHealthy()) {
                allHealthy = false
            }
        }
        lock.readMutex.unlock()
        allHealthy
    }

    /**
     * 获取健康率
     */
    public func healthRatio(): Float64 {
        lock.readMutex.lock()
        var total = 0
        var healthy = 0
        for ((_, node) in nodes) {
            if (node.status.isActive()) {
                total += 1
                if (node.health.isHealthy()) {
                    healthy += 1
                }
            }
        }
        lock.readMutex.unlock()
        if (total == 0) {
            return 1.0
        }
        Float64(healthy) / Float64(total)
    }

    /**
     * 获取节点 IDs
     */
    public func getNodeIds(): ArrayList<String> {
        lock.readMutex.lock()
        let ids = ArrayList<String>()
        for ((id, _) in nodes) {
            ids.add(id)
        }
        lock.readMutex.unlock()
        ids
    }
}

/**
 * 创建 Fleet Manager
 */
public func createFleetManager(fleetName: String): FleetManager {
    let config = FleetConfig(fleetName)
    FleetManager(config)
}
