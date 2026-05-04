/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ClusterBootstrap 集群自动引导
 * 对标 Akka Cluster Bootstrap
 * 实现自动集群形成，支持多种发现机制
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*
import std.convert.*

/**
 * 引导状态
 */
public enum BootstrapState {
    | Idle
    | Discovering
    | Joining
    | Done
    | Failed(String)
}

/**
 * 引导发现方法
 */
public enum BootstrapDiscoveryMethod {
    | ConfigBased
    | DnsBased
    | KubernetesApi
    | StaticList
}

/**
 * 联系人节点
 */
public class ContactPoint {
    public let nodeId: String
    public let host: String
    public let port: Int64
    public let isSeedNode: Bool
    public var isReachable: Bool
    public var lastCheckTime: Int64
    public var responseTime: Int64  // 毫秒

    public init(nodeId: String, host: String, port: Int64, isSeedNode: Bool) {
        this.nodeId = nodeId
        this.host = host
        this.port = port
        this.isSeedNode = isSeedNode
        this.isReachable = false
        this.lastCheckTime = 0
        this.responseTime = 0
    }

    public func address(): String {
        "${host}:${port}"
    }

    public func touch(): Unit {
        lastCheckTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 引导配置
 */
public class BootstrapConfig {
    public let discoveryMethod: BootstrapDiscoveryMethod
    public let contactPoints: ArrayList<String>      // 格式: "host:port"
    public let dnsServiceName: String
    public let kubernetesNamespace: String
    public let kubernetesPortName: String
    public let bootstrapTimeout: Duration
    public let interval: Duration
    public let maxRetryAttempts: Int64
    public let startupTimeout: Duration

    public init(
        discoveryMethod: BootstrapDiscoveryMethod,
        contactPoints: ArrayList<String>,
        dnsServiceName: String,
        kubernetesNamespace: String,
        kubernetesPortName: String,
        bootstrapTimeout: Duration,
        interval: Duration,
        maxRetryAttempts: Int64,
        startupTimeout: Duration
    ) {
        this.discoveryMethod = discoveryMethod
        this.contactPoints = contactPoints
        this.dnsServiceName = dnsServiceName
        this.kubernetesNamespace = kubernetesNamespace
        this.kubernetesPortName = kubernetesPortName
        this.bootstrapTimeout = bootstrapTimeout
        this.interval = interval
        this.maxRetryAttempts = maxRetryAttempts
        this.startupTimeout = startupTimeout
    }
}

/**
 * 引导结果
 */
public class BootstrapResult {
    public let success: Bool
    public let joinedNodeId: String
    public let joinedAddress: String
    public let clusterMembers: ArrayList<String>
    public let bootstrapTime: Int64
    public let attemptCount: Int64
    public let failureReason: Option<String>

    public init(
        success: Bool,
        joinedNodeId: String,
        joinedAddress: String,
        clusterMembers: ArrayList<String>,
        bootstrapTime: Int64,
        attemptCount: Int64,
        failureReason: Option<String>
    ) {
        this.success = success
        this.joinedNodeId = joinedNodeId
        this.joinedAddress = joinedAddress
        this.clusterMembers = clusterMembers
        this.bootstrapTime = bootstrapTime
        this.attemptCount = attemptCount
        this.failureReason = failureReason
    }
}

/**
 * 引导事件
 */
public enum BootstrapEvent {
    | BootstrapStarted(String)
    | DiscoveryStarted(BootstrapDiscoveryMethod)
    | ContactPointFound(String, String)
    | ContactPointReachable(String, String)
    | ContactPointUnreachable(String, String)
    | JoiningCluster(String, String)
    | ClusterJoined(String, ArrayList<String>)
    | BootstrapFailed(String, String)
    | RetryAttempt(Int64, Int64)
    | StateChanged(BootstrapState, BootstrapState)
}

/**
 * 引导事件处理器接口
 */
public interface BootstrapEventHandler {
    public func onBootstrapStarted(nodeId: String): Unit
    public func onDiscoveryStarted(method: BootstrapDiscoveryMethod): Unit
    public func onContactPointFound(nodeId: String, address: String): Unit
    public func onContactPointReachable(nodeId: String, address: String): Unit
    public func onContactPointUnreachable(nodeId: String, address: String): Unit
    public func onJoiningCluster(nodeId: String, targetAddress: String): Unit
    public func onClusterJoined(nodeId: String, members: ArrayList<String>): Unit
    public func onBootstrapFailed(nodeId: String, reason: String): Unit
    public func onRetryAttempt(attempt: Int64, maxAttempts: Int64): Unit
    public func onStateChanged(fromState: BootstrapState, toState: BootstrapState): Unit
}

/**
 * 集群引导器
 * 对标 Akka Cluster Bootstrap
 * 自动发现集群节点并加入
 */
public class ClusterBootstrap {
    private let nodeId: String
    private let config: BootstrapConfig
    private var state: BootstrapState
    private let contactPointsMap: HashMap<String, ContactPoint>
    private let lock: ReentrantReadWriteMutex
    private var attemptCount: Int64
    private var startTime: Int64
    private var eventHandler: Option<BootstrapEventHandler>
    private var joinedAddress: String
    private var clusterMembers: ArrayList<String>

    public init(nodeId: String, config: BootstrapConfig) {
        this.nodeId = nodeId
        this.config = config
        this.state = BootstrapState.Idle
        this.contactPointsMap = HashMap<String, ContactPoint>()
        this.lock = ReentrantReadWriteMutex()
        this.attemptCount = 0
        this.startTime = 0
        this.eventHandler = None
        this.joinedAddress = ""
        this.clusterMembers = ArrayList<String>()
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: BootstrapEventHandler): Unit {
        lock.writeMutex.lock()
        this.eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 开始引导过程
     */
    public func start(): BootstrapResult {
        lock.writeMutex.lock()
        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        if (startTime == 0) {
            startTime = currentTime
        }
        let oldState = state
        state = BootstrapState.Discovering
        fireStateChanged(oldState, state)
        fireBootstrapStarted()
        lock.writeMutex.unlock()

        // 发现联系人节点
        discoverContactPoints()

        // 尝试加入
        lock.writeMutex.lock()
        attemptCount += 1
        fireRetryAttempt(attemptCount, config.maxRetryAttempts)
        let joinResult = tryJoin()
        lock.writeMutex.unlock()

        joinResult
    }

    /**
     * 发现联系人节点
     */
    private func discoverContactPoints(): Unit {
        fireDiscoveryStarted(config.discoveryMethod)

        match (config.discoveryMethod) {
            case BootstrapDiscoveryMethod.ConfigBased => discoverFromConfig()
            case BootstrapDiscoveryMethod.DnsBased => discoverFromDns()
            case BootstrapDiscoveryMethod.KubernetesApi => discoverFromKubernetes()
            case BootstrapDiscoveryMethod.StaticList => discoverFromStaticList()
        }
    }

    /**
     * 从配置发现节点
     */
    private func discoverFromConfig(): Unit {
        lock.writeMutex.lock()
        for (contact in config.contactPoints) {
            addContactPoint(contact, false)
        }
        lock.writeMutex.unlock()
    }

    /**
     * 从静态列表发现节点
     */
    private func discoverFromStaticList(): Unit {
        lock.writeMutex.lock()
        for (contact in config.contactPoints) {
            addContactPoint(contact, true)  // 都是种子节点
        }
        lock.writeMutex.unlock()
    }

    /**
     * 从 DNS 发现节点
     */
    private func discoverFromDns(): Unit {
        lock.writeMutex.lock()
        // 模拟 DNS 发现 - 实际环境中会查询 DNS SRV 记录
        let serviceName = config.dnsServiceName
        // 假设 DNS 解析返回的节点
        for (contact in config.contactPoints) {
            addContactPoint(contact, true)
        }
        lock.writeMutex.unlock()
    }

    /**
     * 从 Kubernetes API 发现节点
     */
    private func discoverFromKubernetes(): Unit {
        lock.writeMutex.lock()
        let namespace = config.kubernetesNamespace
        let portName = config.kubernetesPortName
        // 模拟 Kubernetes API 发现 - 实际环境中会查询 K8s Endpoints
        // 这里使用配置的联系人节点作为已发现的节点
        for (contact in config.contactPoints) {
            addContactPoint(contact, true)
        }
        lock.writeMutex.unlock()
    }

    /**
     * 添加联系人节点
     */
    private func addContactPoint(address: String, isSeed: Bool): Unit {
        if (contactPointsMap.contains(address)) {
            return
        }
        let parts = address.split(":")
        if (parts.size >= 2) {
            let host = parts[0]
            let port = Int64.parse(parts[1])
            let nodeId = "node-${host}-${port}"
            let cp = ContactPoint(nodeId, host, port, isSeed)
            cp.touch()
            contactPointsMap.add(address, cp)
            fireContactPointFound(nodeId, address)
        }
    }

    /**
     * 尝试验证并加入
     */
    private func tryJoin(): BootstrapResult {
        // 找到可达的种子节点
        let reachableSeeds = getReachableSeeds()
        if (reachableSeeds.size > 0) {
            // 选择第一个可达种子节点
            let target = reachableSeeds[0]
            fireJoiningCluster(nodeId, target.address())

            // 模拟加入成功
            lock.writeMutex.lock()
            joinedAddress = target.address()
            clusterMembers = ArrayList<String>()
            clusterMembers.add(nodeId)
            for ((_, cp) in contactPointsMap) {
                if (cp.isReachable && cp.nodeId != nodeId) {
                    clusterMembers.add(cp.nodeId)
                }
            }
            let oldState = state
            state = BootstrapState.Done
            fireStateChanged(oldState, state)
            fireClusterJoined(nodeId, clusterMembers)
            lock.writeMutex.unlock()

            let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            return BootstrapResult(
                true,
                nodeId,
                joinedAddress,
                clusterMembers,
                endTime - startTime,
                attemptCount,
                None
            )
        }

        // 无可达节点，检查是否超时
        lock.writeMutex.lock()
        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let elapsed = currentTime - startTime
        let timeoutMs = config.bootstrapTimeout.toMilliseconds()
        lock.writeMutex.unlock()

        if (attemptCount >= config.maxRetryAttempts || elapsed > timeoutMs) {
            lock.writeMutex.lock()
            let reason = if (attemptCount >= config.maxRetryAttempts) {
                "最大重试次数 ${attemptCount} 已达"
            } else {
                "引导超时 ${elapsed}ms > ${timeoutMs}ms"
            }
            let oldState = state
            state = BootstrapState.Failed(reason)
            fireStateChanged(oldState, state)
            fireBootstrapFailed(nodeId, reason)
            lock.writeMutex.unlock()

            return BootstrapResult(
                false,
                nodeId,
                "",
                ArrayList<String>(),
                elapsed,
                attemptCount,
                Some(reason)
            )
        }

        // 继续重试
        BootstrapResult(
            false,
            nodeId,
            "",
            ArrayList<String>(),
            elapsed,
            attemptCount,
            Some("无可达种子节点，等待重试")
        )
    }

    /**
     * 获取可达的种子节点
     */
    private func getReachableSeeds(): ArrayList<ContactPoint> {
        let result = ArrayList<ContactPoint>()
        lock.readMutex.lock()
        for ((_, cp) in contactPointsMap) {
            if (cp.isSeedNode && cp.isReachable) {
                result.add(cp)
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 检查节点是否可达
     */
    public func checkReachability(address: String): Bool {
        lock.readMutex.lock()
        let result = match (contactPointsMap.get(address)) {
            case Some(cp) => cp.isReachable
            case None => false
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 标记节点为可达
     */
    public func markReachable(address: String): Unit {
        lock.writeMutex.lock()
        match (contactPointsMap.get(address)) {
            case Some(cp) =>
                cp.isReachable = true
                cp.touch()
                fireContactPointReachable(cp.nodeId, address)
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 标记节点为不可达
     */
    public func markUnreachable(address: String): Unit {
        lock.writeMutex.lock()
        match (contactPointsMap.get(address)) {
            case Some(cp) =>
                cp.isReachable = false
                fireContactPointUnreachable(cp.nodeId, address)
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 获取当前状态
     */
    public func getState(): BootstrapState {
        lock.readMutex.lock()
        let s = state
        lock.readMutex.unlock()
        s
    }

    /**
     * 获取节点 ID
     */
    public func getNodeId(): String {
        nodeId
    }

    /**
     * 获取配置
     */
    public func getConfig(): BootstrapConfig {
        config
    }

    /**
     * 获取联系人节点列表
     */
    public func getContactPoints(): ArrayList<ContactPoint> {
        lock.readMutex.lock()
        let result = ArrayList<ContactPoint>()
        for ((_, cp) in contactPointsMap) {
            result.add(cp)
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取联系人节点数量
     */
    public func contactPointCount(): Int64 {
        lock.readMutex.lock()
        let count = contactPointsMap.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取可达节点数量
     */
    public func reachableCount(): Int64 {
        lock.readMutex.lock()
        var count = 0
        for ((_, cp) in contactPointsMap) {
            if (cp.isReachable) {
                count += 1
            }
        }
        lock.readMutex.unlock()
        Int64(count)
    }

    /**
     * 获取种子节点数量
     */
    public func seedNodeCount(): Int64 {
        lock.readMutex.lock()
        var count = 0
        for ((_, cp) in contactPointsMap) {
            if (cp.isSeedNode) {
                count += 1
            }
        }
        lock.readMutex.unlock()
        Int64(count)
    }

    /**
     * 获取已加入的地址
     */
    public func getJoinedAddress(): String {
        lock.readMutex.lock()
        let addr = joinedAddress
        lock.readMutex.unlock()
        addr
    }

    /**
     * 获取集群成员
     */
    public func getClusterMembers(): ArrayList<String> {
        lock.readMutex.lock()
        let members = ArrayList<String>()
        for (m in clusterMembers) {
            members.add(m)
        }
        lock.readMutex.unlock()
        members
    }

    /**
     * 获取重试次数
     */
    public func getAttemptCount(): Int64 {
        lock.readMutex.lock()
        let count = attemptCount
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取引导耗时
     */
    public func getElapsedTime(): Int64 {
        lock.readMutex.lock()
        let elapsed = if (startTime > 0) {
            DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime
        } else {
            0
        }
        lock.readMutex.unlock()
        elapsed
    }

    /**
     * 重置引导状态
     */
    public func reset(): Unit {
        lock.writeMutex.lock()
        state = BootstrapState.Idle
        attemptCount = 0
        startTime = 0
        joinedAddress = ""
        clusterMembers.clear()
        for ((_, cp) in contactPointsMap) {
            cp.isReachable = false
        }
        lock.writeMutex.unlock()
    }

    // === 事件触发 ===

    private func fireBootstrapStarted(): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onBootstrapStarted(nodeId)
            case None => ()
        }
    }

    private func fireDiscoveryStarted(method: BootstrapDiscoveryMethod): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onDiscoveryStarted(method)
            case None => ()
        }
    }

    private func fireContactPointFound(nodeId: String, address: String): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onContactPointFound(nodeId, address)
            case None => ()
        }
    }

    private func fireContactPointReachable(nodeId: String, address: String): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onContactPointReachable(nodeId, address)
            case None => ()
        }
    }

    private func fireContactPointUnreachable(nodeId: String, address: String): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onContactPointUnreachable(nodeId, address)
            case None => ()
        }
    }

    private func fireJoiningCluster(nodeId: String, targetAddress: String): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onJoiningCluster(nodeId, targetAddress)
            case None => ()
        }
    }

    private func fireClusterJoined(nodeId: String, members: ArrayList<String>): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onClusterJoined(nodeId, members)
            case None => ()
        }
    }

    private func fireBootstrapFailed(nodeId: String, reason: String): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onBootstrapFailed(nodeId, reason)
            case None => ()
        }
    }

    private func fireRetryAttempt(attempt: Int64, maxAttempts: Int64): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onRetryAttempt(attempt, maxAttempts)
            case None => ()
        }
    }

    private func fireStateChanged(from: BootstrapState, to: BootstrapState): Unit {
        match (eventHandler) {
            case Some(handler) => handler.onStateChanged(from, to)
            case None => ()
        }
    }
}

/**
 * 创建默认引导配置（基于配置）
 */
public func createBootstrapConfigWithContactPoints(contactPoints: ArrayList<String>): BootstrapConfig {
    BootstrapConfig(
        BootstrapDiscoveryMethod.ConfigBased,
        contactPoints,
        "",          // dnsServiceName
        "",          // kubernetesNamespace
        "client",    // kubernetesPortName
        Duration.second * 30,
        Duration.second * 3,
        10,
        Duration.second * 10
    )
}

/**
 * 创建 DNS 引导配置
 */
public func createBootstrapConfigWithDns(serviceName: String, contactPoints: ArrayList<String>): BootstrapConfig {
    BootstrapConfig(
        BootstrapDiscoveryMethod.DnsBased,
        contactPoints,
        serviceName,
        "",
        "client",
        Duration.second * 30,
        Duration.second * 3,
        10,
        Duration.second * 10
    )
}

/**
 * 创建 Kubernetes 引导配置
 */
public func createBootstrapConfigWithKubernetes(
    namespace: String,
    serviceName: String,
    portName: String
): BootstrapConfig {
    let contactPoints = ArrayList<String>()
    BootstrapConfig(
        BootstrapDiscoveryMethod.KubernetesApi,
        contactPoints,
        serviceName,
        namespace,
        portName,
        Duration.second * 30,
        Duration.second * 3,
        10,
        Duration.second * 10
    )
}

/**
 * 创建静态种子节点引导配置
 */
public func createBootstrapConfigWithSeedNodes(seedNodes: ArrayList<String>): BootstrapConfig {
    BootstrapConfig(
        BootstrapDiscoveryMethod.StaticList,
        seedNodes,
        "",
        "",
        "client",
        Duration.second * 30,
        Duration.second * 3,
        10,
        Duration.second * 10
    )
}

/**
 * 创建集群引导器
 */
public func createClusterBootstrap(nodeId: String): ClusterBootstrap {
    let contactPoints = ArrayList<String>()
    let config = createBootstrapConfigWithContactPoints(contactPoints)
    ClusterBootstrap(nodeId, config)
}

/**
 * 创建带配置的集群引导器
 */
public func createClusterBootstrapWithConfig(nodeId: String, config: BootstrapConfig): ClusterBootstrap {
    ClusterBootstrap(nodeId, config)
}
