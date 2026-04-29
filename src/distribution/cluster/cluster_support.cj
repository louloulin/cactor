/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 集群支持实现
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.{Message, StringMessage}
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.foundation.network.{NetworkAddress}
import cactor.distribution.remote.{SimpleRemoteManager}
import cactor.foundation.network.{TransportProtocol}

/**
 * 集群节点标识
 */
public struct NodeId {
    public let id: String
    
    public init(id: String) {
        this.id = id
    }
    
    public func toString(): String {
        "NodeId(${id})"
    }
    
    public func equals(other: NodeId): Bool {
        this.id == other.id
    }
}

/**
 * 集群节点状态
 */
public enum NodeState {
    | Joining(DateTime)
    | Up(DateTime)
    | Leaving(DateTime)
    | Down(DateTime)
    | Failed(DateTime)
    
    public func isAvailable(): Bool {
        match (this) {
            case Up(_) => true
            case _ => false
        }
    }
    
    public func toString(): String {
        match (this) {
            case Joining(time) => "Joining(${time})"
            case Up(time) => "Up(${time})"
            case Leaving(time) => "Leaving(${time})"
            case Down(time) => "Down(${time})"
            case Failed(time) => "Failed(${time})"
        }
    }
}

/**
 * 集群节点信息
 */
public class ClusterNode {
    public let nodeId: NodeId
    public let address: NetworkAddress
    public let roles: Array<String>
    private var state: NodeState
    private let mutex: ReentrantMutex
    
    public init(nodeId: NodeId, address: NetworkAddress, roles: Array<String>) {
        this.nodeId = nodeId
        this.address = address
        this.roles = roles
        this.state = NodeState.Joining(DateTime.now())
        this.mutex = ReentrantMutex()
    }
    
    public func getState(): NodeState {
        mutex.lock()
        let currentState = state
        mutex.unlock()
        currentState
    }
    
    public func setState(newState: NodeState): Unit {
        mutex.lock()
        this.state = newState
        mutex.unlock()
        println("节点 ${nodeId.toString()} 状态变更为: ${newState.toString()}")
    }
    
    public func isLocal(): Bool {
        // 简化实现：检查是否为本地地址
        address.host == "localhost" || address.host == "127.0.0.1"
    }
    
    public func hasRole(role: String): Bool {
        for (r in roles) {
            if (r == role) {
                return true
            }
        }
        false
    }
    
    public func toString(): String {
        "ClusterNode(${nodeId.toString()}, ${address.toString()}, ${getState().toString()})"
    }
}

/**
 * 集群状态管理
 */
public class ClusterState {
    private let nodes: HashMap<String, ClusterNode>
    private let mutex: ReentrantMutex
    private let localNodeId: NodeId
    
    public init(localNodeId: NodeId) {
        this.nodes = HashMap<String, ClusterNode>()
        this.mutex = ReentrantMutex()
        this.localNodeId = localNodeId
    }

    public func addNode(node: ClusterNode): Unit {
        mutex.lock()
        nodes[node.nodeId.id] = node
        mutex.unlock()
        println("添加集群节点: ${node.toString()}")
    }

    public func removeNode(nodeId: NodeId): Unit {
        mutex.lock()
        nodes.remove(nodeId.id)
        mutex.unlock()
        println("移除集群节点: ${nodeId.toString()}")
    }

    public func updateNodeState(nodeId: NodeId, newState: NodeState): Unit {
        mutex.lock()
        match (nodes.get(nodeId.id)) {
            case Some(node) =>
                node.setState(newState)
            case None =>
                println("警告: 尝试更新不存在的节点状态: ${nodeId.toString()}")
        }
        mutex.unlock()
    }
    
    public func getAvailableNodes(): Array<ClusterNode> {
        mutex.lock()
        let availableNodes = ArrayList<ClusterNode>()
        for ((_, node) in nodes) {
            if (node.getState().isAvailable()) {
                availableNodes.add(node)
            }
        }
        mutex.unlock()
        availableNodes.toArray()
    }
    
    public func getNode(nodeId: NodeId): Option<ClusterNode> {
        mutex.lock()
        let result = nodes.get(nodeId.id)
        mutex.unlock()
        result
    }
    
    public func getAllNodes(): Array<ClusterNode> {
        mutex.lock()
        let allNodes = ArrayList<ClusterNode>()
        for ((_, node) in nodes) {
            allNodes.add(node)
        }
        mutex.unlock()
        allNodes.toArray()
    }
    
    public func getLocalNodeId(): NodeId {
        localNodeId
    }
    
    public func getClusterSize(): Int64 {
        mutex.lock()
        let size = Int64(nodes.size)
        mutex.unlock()
        size
    }
}

/**
 * 集群事件
 */
public enum ClusterEvent {
    | NodeJoined(ClusterNode)
    | NodeLeft(ClusterNode)
    | NodeFailed(ClusterNode)
    | NodeUp(ClusterNode)
    | NodeDown(ClusterNode)
    
    public func toString(): String {
        match (this) {
            case NodeJoined(node) => "NodeJoined(${node.nodeId.toString()})"
            case NodeLeft(node) => "NodeLeft(${node.nodeId.toString()})"
            case NodeFailed(node) => "NodeFailed(${node.nodeId.toString()})"
            case NodeUp(node) => "NodeUp(${node.nodeId.toString()})"
            case NodeDown(node) => "NodeDown(${node.nodeId.toString()})"
        }
    }
}

/**
 * 集群事件监听器
 */
public interface ClusterEventListener {
    func onClusterEvent(event: ClusterEvent): Unit
}

/**
 * 简化的集群管理器
 */
public class SimpleClusterManager {
    private let clusterState: ClusterState
    private let remoteManager: SimpleRemoteManager
    private let eventListeners: ArrayList<ClusterEventListener>
    private let mutex: ReentrantMutex
    private let isStarted: AtomicBool
    
    public init(localNodeId: NodeId, localAddress: NetworkAddress) {
        this.clusterState = ClusterState(localNodeId)
        this.remoteManager = SimpleRemoteManager(localAddress, TransportProtocol.TCP)
        this.eventListeners = ArrayList<ClusterEventListener>()
        this.mutex = ReentrantMutex()
        this.isStarted = AtomicBool(false)
        
        // 添加本地节点
        let localNode = ClusterNode(localNodeId, localAddress, ["worker"])
        clusterState.addNode(localNode)
    }
    
    public func start(): Unit {
        if (isStarted.compareAndSwap(false, true)) {
            remoteManager.start()
            
            // 设置本地节点为Up状态
            clusterState.updateNodeState(clusterState.getLocalNodeId(), NodeState.Up(DateTime.now()))
            
            println("集群管理器启动: ${clusterState.getLocalNodeId().toString()}")
        }
    }
    
    public func stop(): Unit {
        if (isStarted.compareAndSwap(true, false)) {
            // 设置本地节点为Leaving状态
            clusterState.updateNodeState(clusterState.getLocalNodeId(), NodeState.Leaving(DateTime.now()))
            
            remoteManager.stop()
            println("集群管理器停止")
        }
    }
    
    public func joinCluster(seedNodes: Array<NetworkAddress>): Unit {
        println("尝试加入集群，种子节点: ${seedNodes.size}个")
        
        for (seedAddress in seedNodes) {
            try {
                // 发送加入请求
                let joinMessage = StringMessage("JOIN_REQUEST:${clusterState.getLocalNodeId().id}")
                remoteManager.sendMessage(seedAddress, "cluster-manager", joinMessage)
                println("发送加入请求到: ${seedAddress.toString()}")
            } catch (e: Exception) {
                println("发送加入请求失败: ${e.message}")
            }
        }
    }
    
    public func addNode(nodeId: NodeId, address: NetworkAddress, roles: Array<String>): Unit {
        let node = ClusterNode(nodeId, address, roles)
        clusterState.addNode(node)
        
        // 触发事件
        let event = ClusterEvent.NodeJoined(node)
        notifyEventListeners(event)
    }
    
    public func removeNode(nodeId: NodeId): Unit {
        match (clusterState.getNode(nodeId)) {
            case Some(node) => 
                clusterState.removeNode(nodeId)
                let event = ClusterEvent.NodeLeft(node)
                notifyEventListeners(event)
            case None => 
                println("尝试移除不存在的节点: ${nodeId.toString()}")
        }
    }
    
    public func addEventListener(listener: ClusterEventListener): Unit {
        mutex.lock()
        eventListeners.add(listener)
        mutex.unlock()
    }
    
    private func notifyEventListeners(event: ClusterEvent): Unit {
        mutex.lock()
        for (listener in eventListeners) {
            try {
                listener.onClusterEvent(event)
            } catch (e: Exception) {
                println("集群事件监听器异常: ${e.message}")
            }
        }
        mutex.unlock()
    }
    
    public func getClusterState(): ClusterState {
        clusterState
    }
    
    public func isActive(): Bool {
        isStarted.load()
    }
}
