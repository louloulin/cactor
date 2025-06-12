/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 远程Actor系统
 * 支持分布式Actor通信和集群管理
 */
package cactor.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.core.message.{Message, Envelope}
import cactor.runtime.ActorSystem
import cactor.network.{NetworkTransport, NetworkAddress, NetworkMessage, TransportFactory, TransportProtocol}
import cactor.serialization.{SerializationManager, GlobalSerializationManager}

/**
 * 远程Actor引用
 * 代表远程节点上的Actor
 */
public class RemoteActorRef <: ActorRef {
    private let path: ActorPath
    private let remoteAddress: NetworkAddress
    private let transport: NetworkTransport
    private let serializationManager: SerializationManager

    public init(path: ActorPath, remoteAddress: NetworkAddress, transport: NetworkTransport) {
        this.path = path
        this.remoteAddress = remoteAddress
        this.transport = transport
        this.serializationManager = GlobalSerializationManager.getInstance()
    }

    public func tell(message: Message): Unit {
        try {
            let networkMessage = NetworkMessage(path.toString(), message, None)
            transport.send(remoteAddress, networkMessage)
        } catch (e: Exception) {
            println("远程消息发送失败: ${e.message}")
        }
    }

    public func tell(message: Message, sender: ActorRef): Unit {
        try {
            let senderPath = sender.path().toString()
            let networkMessage = NetworkMessage(path.toString(), message, Some(senderPath))
            transport.send(remoteAddress, networkMessage)
        } catch (e: Exception) {
            println("远程消息发送失败: ${e.message}")
        }
    }

    public func path(): ActorPath {
        path
    }

    public func stop(): Unit {
        // 远程Actor的停止需要发送停止消息
        let stopMessage = StopMessage("remote_stop")
        tell(stopMessage)
    }
}

/**
 * 远程Actor系统
 * 管理分布式Actor通信
 */
public class RemoteActorSystem {
    private let localSystem: ActorSystem
    private let transport: NetworkTransport
    private let localAddress: NetworkAddress
    private let remoteNodes: ConcurrentHashMap<String, NetworkAddress>
    private let remoteActors: ConcurrentHashMap<String, RemoteActorRef>
    private let isStarted: AtomicBool
    private let mutex: ReentrantMutex

    public init(localSystem: ActorSystem, localAddress: NetworkAddress, protocol: TransportProtocol) {
        this.localSystem = localSystem
        this.localAddress = localAddress
        this.transport = TransportFactory.createTransport(protocol, localAddress)
        this.remoteNodes = ConcurrentHashMap<String, NetworkAddress>()
        this.remoteActors = ConcurrentHashMap<String, RemoteActorRef>()
        this.isStarted = AtomicBool(false)
        this.mutex = ReentrantMutex()
        
        // 设置消息处理器
        transport.setMessageHandler(handleRemoteMessage)
    }

    /**
     * 启动远程系统
     */
    public func start(): Unit {
        if (isStarted.compareAndSwap(false, true)) {
            transport.start()
            println("远程Actor系统启动在地址: ${localAddress.toString()}")
        }
    }

    /**
     * 停止远程系统
     */
    public func stop(): Unit {
        if (isStarted.compareAndSwap(true, false)) {
            transport.stop()
            println("远程Actor系统停止")
        }
    }

    /**
     * 连接到远程节点
     */
    public func connectToNode(nodeId: String, address: NetworkAddress): Unit {
        mutex.lock()
        remoteNodes[nodeId] = address
        mutex.unlock()
        println("连接到远程节点: ${nodeId} @ ${address.toString()}")
    }

    /**
     * 断开远程节点连接
     */
    public func disconnectFromNode(nodeId: String): Unit {
        mutex.lock()
        remoteNodes.remove(nodeId)
        mutex.unlock()
        println("断开远程节点: ${nodeId}")
    }

    /**
     * 获取远程Actor引用
     */
    public func actorSelection(actorPath: String, nodeId: String): Option<RemoteActorRef> {
        mutex.lock()
        let result = match (remoteNodes.get(nodeId)) {
            case Some(address) => {
                let path = ActorPath.parse(actorPath)
                let remoteRef = RemoteActorRef(path, address, transport)
                remoteActors[actorPath] = remoteRef
                Some(remoteRef)
            }
            case None => None
        }
        mutex.unlock()
        result
    }

    /**
     * 处理远程消息
     */
    private func handleRemoteMessage(networkMessage: NetworkMessage): Unit {
        try {
            // 查找本地Actor
            let targetPath = networkMessage.targetActor
            match (localSystem.actorSelection(targetPath)) {
                case Some(localActor) => {
                    // 转发消息给本地Actor
                    localActor.tell(networkMessage.message)
                    println("转发远程消息到本地Actor: ${targetPath}")
                }
                case None => {
                    println("本地Actor不存在: ${targetPath}")
                }
            }
        } catch (e: Exception) {
            println("处理远程消息失败: ${e.message}")
        }
    }

    /**
     * 获取本地地址
     */
    public func getLocalAddress(): NetworkAddress {
        localAddress
    }

    /**
     * 获取连接的节点数量
     */
    public func getConnectedNodeCount(): Int64 {
        mutex.lock()
        let count = remoteNodes.size
        mutex.unlock()
        count
    }

    /**
     * 获取所有连接的节点
     */
    public func getConnectedNodes(): Array<String> {
        mutex.lock()
        let nodes = remoteNodes.keySet().toArray()
        mutex.unlock()
        nodes
    }

    /**
     * 检查是否已启动
     */
    public func isActive(): Bool {
        isStarted.load()
    }
}

/**
 * 集群配置
 */
public struct ClusterConfig {
    public let nodeId: String
    public let localAddress: NetworkAddress
    public let seedNodes: Array<NetworkAddress>
    public let protocol: TransportProtocol

    public init(nodeId: String, localAddress: NetworkAddress, seedNodes: Array<NetworkAddress>, protocol: TransportProtocol) {
        this.nodeId = nodeId
        this.localAddress = localAddress
        this.seedNodes = seedNodes
        this.protocol = protocol
    }

    public static func createDefault(nodeId: String, port: Int32): ClusterConfig {
        let localAddress = NetworkAddress("localhost", port)
        let seedNodes = Array<NetworkAddress>(0, { i => NetworkAddress("localhost", 8080) })
        ClusterConfig(nodeId, localAddress, seedNodes, TransportProtocol.TCP)
    }
}

/**
 * 集群管理器
 */
public class ClusterManager {
    private let config: ClusterConfig
    private let remoteSystem: RemoteActorSystem
    private let connectedNodes: ConcurrentHashMap<String, NetworkAddress>
    private let isJoined: AtomicBool
    private let heartbeatInterval: Duration

    public init(localSystem: ActorSystem, config: ClusterConfig) {
        this.config = config
        this.remoteSystem = RemoteActorSystem(localSystem, config.localAddress, config.protocol)
        this.connectedNodes = ConcurrentHashMap<String, NetworkAddress>()
        this.isJoined = AtomicBool(false)
        this.heartbeatInterval = Duration.second * 5
    }

    /**
     * 加入集群
     */
    public func joinCluster(): Unit {
        if (isJoined.compareAndSwap(false, true)) {
            remoteSystem.start()
            
            // 连接到种子节点
            for (seedNode in config.seedNodes) {
                let nodeId = "seed_${seedNode.toString()}"
                remoteSystem.connectToNode(nodeId, seedNode)
                connectedNodes[nodeId] = seedNode
            }
            
            // 启动心跳
            startHeartbeat()
            
            println("节点 ${config.nodeId} 加入集群")
        }
    }

    /**
     * 离开集群
     */
    public func leaveCluster(): Unit {
        if (isJoined.compareAndSwap(true, false)) {
            remoteSystem.stop()
            connectedNodes.clear()
            println("节点 ${config.nodeId} 离开集群")
        }
    }

    /**
     * 获取远程Actor
     */
    public func getRemoteActor(actorPath: String, nodeId: String): Option<RemoteActorRef> {
        if (isJoined.load()) {
            remoteSystem.actorSelection(actorPath, nodeId)
        } else {
            None
        }
    }

    /**
     * 启动心跳
     */
    private func startHeartbeat(): Unit {
        spawn {
            while (isJoined.load()) {
                try {
                    sendHeartbeat()
                    sleep(heartbeatInterval)
                } catch (e: Exception) {
                    println("心跳发送失败: ${e.message}")
                }
            }
        }
    }

    /**
     * 发送心跳
     */
    private func sendHeartbeat(): Unit {
        // 简化的心跳实现
        println("发送心跳 from ${config.nodeId}")
    }

    /**
     * 获取集群状态
     */
    public func getClusterStatus(): String {
        let nodeCount = connectedNodes.size
        let status = if (isJoined.load()) "JOINED" else "NOT_JOINED"
        "Node: ${config.nodeId}, Status: ${status}, Connected: ${nodeCount}"
    }
}

/**
 * 远程Actor工厂
 */
public class RemoteActorFactory {
    public static func createRemoteSystem(localSystem: ActorSystem, address: NetworkAddress): RemoteActorSystem {
        RemoteActorSystem(localSystem, address, TransportProtocol.TCP)
    }

    public static func createClusterManager(localSystem: ActorSystem, config: ClusterConfig): ClusterManager {
        ClusterManager(localSystem, config)
    }
}
