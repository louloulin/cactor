/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Receptionist 集群服务发现机制
 * 对标 Akka Cluster Receptionist
 * 实现集群范围的服务注册和发现
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*
import std.random.*

/**
 * 服务实例信息
 */
public class ServiceInstance {
    public let serviceName: String
    public let actorPath: String
    public let nodeId: String
    public let nodeAddress: Address
    public var metadata: HashMap<String, String>
    public let registeredAt: Int64
    public var lastSeen: Int64

    public init(serviceName: String, actorPath: String, nodeId: String, nodeAddress: Address) {
        this.serviceName = serviceName
        this.actorPath = actorPath
        this.nodeId = nodeId
        this.nodeAddress = nodeAddress
        this.metadata = HashMap<String, String>()
        this.registeredAt = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.lastSeen = registeredAt
    }

    /**
     * 添加元数据
     */
    public func withMetadata(key: String, value: String): ServiceInstance {
        metadata.add(key, value)
        this
    }

    /**
     * 获取元数据值
     */
    public func getMetadata(key: String): Option<String> {
        metadata.get(key)
    }

    /**
     * 更新最后可见时间
     */
    public func touch(): Unit {
        lastSeen = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /**
     * 获取服务实例标识
     */
    public func instanceId(): String {
        "${nodeId}:${actorPath}"
    }

    /**
     * 检查是否来自同一节点
     */
    public func isFromNode(nodeId: String): Bool {
        this.nodeId == nodeId
    }
}

/**
 * 服务实例注册请求
 */
public class RegisterRequest {
    public let serviceName: String
    public let actorPath: String
    public let nodeId: String
    public let nodeAddress: Address
    public let timestamp: Int64

    public init(serviceName: String, actorPath: String, nodeId: String, nodeAddress: Address) {
        this.serviceName = serviceName
        this.actorPath = actorPath
        this.nodeId = nodeId
        this.nodeAddress = nodeAddress
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 服务发现请求类型
 */
public enum DiscoveryRequestType {
    | Find
    | FindAll
    | FindWithPrefix
    | Count
}

/**
 * 服务发现请求
 */
public class DiscoveryRequest {
    public let requestType: DiscoveryRequestType
    public let serviceName: String
    public let timestamp: Int64

    public init(requestType: DiscoveryRequestType, serviceName: String) {
        this.requestType = requestType
        this.serviceName = serviceName
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 服务发现响应
 */
public class DiscoveryResponse {
    public let serviceName: String
    public let instances: ArrayList<ServiceInstance>
    public let timestamp: Int64

    public init(serviceName: String, instances: ArrayList<ServiceInstance>) {
        this.serviceName = serviceName
        this.instances = instances
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 集群接待员事件
 */
public enum ReceptionistEvent {
    | ServiceRegistered(String, ServiceInstance)
    | ServiceUnregistered(String, String)
    | ServiceUpdated(String, ServiceInstance)
    | DiscoveryPerformed(String, Int64)
}

/**
 * 集群接待员事件处理器
 */
public interface ReceptionistEventHandler {
    /**
     * 服务注册事件
     */
    func onServiceRegistered(serviceName: String, instance: ServiceInstance): Unit

    /**
     * 服务注销事件
     */
    func onServiceUnregistered(serviceName: String, actorPath: String): Unit

    /**
     * 服务更新事件
     */
    func onServiceUpdated(serviceName: String, instance: ServiceInstance): Unit

    /**
     * 服务发现事件
     */
    func onDiscovery(serviceName: String, instances: ArrayList<ServiceInstance>): Unit
}

/**
 * 集群接待员配置
 */
public class ReceptionistConfig {
    public let maxServices: Int64
    public let maxInstancesPerService: Int64
    public let heartbeatInterval: Duration
    public let staleThreshold: Duration
    public let enableReplication: Bool

    public init(maxServices: Int64, maxInstancesPerService: Int64, heartbeatInterval: Duration, staleThreshold: Duration, enableReplication: Bool) {
        this.maxServices = maxServices
        this.maxInstancesPerService = maxInstancesPerService
        this.heartbeatInterval = heartbeatInterval
        this.staleThreshold = staleThreshold
        this.enableReplication = enableReplication
    }
}

/**
 * ClusterReceptionist - 集群服务发现
 * 对标 Akka Cluster Receptionist
 * 提供集群范围的服务注册和发现
 */
public class ClusterReceptionist {
    private let nodeId: String
    private let nodeAddress: Address
    private let services: HashMap<String, ArrayList<ServiceInstance>>
    private let actorToService: HashMap<String, String>
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<ReceptionistEventHandler>
    private var registrationCount: Int64
    private var discoveryCount: Int64

    public init(nodeId: String, nodeAddress: Address) {
        this.nodeId = nodeId
        this.nodeAddress = nodeAddress
        this.services = HashMap<String, ArrayList<ServiceInstance>>()
        this.actorToService = HashMap<String, String>()
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
        this.registrationCount = 0
        this.discoveryCount = 0
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: ReceptionistEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 注册服务
     */
    public func register(serviceName: String, actorPath: String): ServiceInstance {
        lock.writeMutex.lock()
        let instance = ServiceInstance(serviceName, actorPath, nodeId, nodeAddress)

        // 添加到服务列表
        match (services.get(serviceName)) {
            case Some(instances) =>
                // 检查是否已存在
                var exists = false
                for (inst in instances) {
                    if (inst.actorPath == actorPath) {
                        exists = true
                        inst.touch()
                        break
                    }
                }
                if (!exists) {
                    instances.add(instance)
                }
            case None =>
                let instances = ArrayList<ServiceInstance>()
                instances.add(instance)
                services.add(serviceName, instances)
        }

        // 记录 actor 到服务的映射
        actorToService.add(actorPath, serviceName)
        registrationCount += 1
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onServiceRegistered(serviceName, instance)
            case None => ()
        }

        instance
    }

    /**
     * 批量注册服务
     */
    public func registerAll(registrations: ArrayList<RegisterRequest>): Int64 {
        var count: Int64 = 0
        for (req in registrations) {
            register(req.serviceName, req.actorPath)
            count += 1
        }
        count
    }

    /**
     * 注销服务
     */
    public func unregister(serviceName: String, actorPath: String): Bool {
        lock.writeMutex.lock()
        var found = false
        match (services.get(serviceName)) {
            case Some(instances) =>
                let toRemove = ArrayList<Int64>()
                for (i in 0..instances.size) {
                    if (instances[i].actorPath == actorPath) {
                        toRemove.add(i)
                        found = true
                    }
                }
                // 按逆序移除
                var idx: Int64 = toRemove.size - 1
                while (idx >= 0) {
                    instances.remove(toRemove[idx]..toRemove[idx])
                    idx -= 1
                }
                if (instances.size == 0) {
                    services.remove(serviceName)
                }
            case None => ()
        }
        actorToService.remove(actorPath)
        lock.writeMutex.unlock()

        if (found) {
            match (eventHandler) {
                case Some(handler) => handler.onServiceUnregistered(serviceName, actorPath)
                case None => ()
            }
        }

        found
    }

    /**
     * 查找服务实例（随机选择一个）
     */
    public func find(serviceName: String): Option<ServiceInstance> {
        lock.readMutex.lock()
        let result: Option<ServiceInstance> = match (services.get(serviceName)) {
            case Some(instances) =>
                if (instances.size > 0) {
                    // 简单负载均衡：选择第一个
                    let inst = instances[0]
                    inst.touch()
                    Some(inst)
                } else {
                    None<ServiceInstance>
                }
            case None => None<ServiceInstance>
        }
        lock.readMutex.unlock()

        if (result.isSome()) {
            discoveryCount += 1
        }

        match (eventHandler) {
            case Some(handler) =>
                match (result) {
                    case Some(inst) =>
                        let list = ArrayList<ServiceInstance>()
                        list.add(inst)
                        handler.onDiscovery(serviceName, list)
                    case None => ()
                }
            case None => ()
        }

        result
    }

    /**
     * 查找所有服务实例
     */
    public func findAll(serviceName: String): ArrayList<ServiceInstance> {
        lock.readMutex.lock()
        let result = ArrayList<ServiceInstance>()
        match (services.get(serviceName)) {
            case Some(instances) =>
                for (inst in instances) {
                    inst.touch()
                    result.add(inst)
                }
            case None => ()
        }
        lock.readMutex.unlock()
        discoveryCount += 1

        match (eventHandler) {
            case Some(handler) => handler.onDiscovery(serviceName, result)
            case None => ()
        }

        result
    }

    /**
     * 按前缀查找服务
     */
    public func findWithPrefix(prefix: String): ArrayList<ServiceInstance> {
        lock.readMutex.lock()
        let result = ArrayList<ServiceInstance>()
        for ((name, instances) in services) {
            if (name.startsWith(prefix)) {
                for (inst in instances) {
                    inst.touch()
                    result.add(inst)
                }
            }
        }
        lock.readMutex.unlock()
        discoveryCount += 1
        result
    }

    /**
     * 获取服务实例数量
     */
    public func count(serviceName: String): Int64 {
        lock.readMutex.lock()
        let result = match (services.get(serviceName)) {
            case Some(instances) => instances.size
            case None => 0
        }
        lock.readMutex.unlock()
        discoveryCount += 1
        result
    }

    /**
     * 更新服务元数据
     */
    public func updateMetadata(serviceName: String, actorPath: String, key: String, value: String): Bool {
        lock.writeMutex.lock()
        var found = false
        match (services.get(serviceName)) {
            case Some(instances) =>
                for (inst in instances) {
                    if (inst.actorPath == actorPath) {
                        inst.metadata.add(key, value)
                        inst.touch()
                        found = true
                        break
                    }
                }
            case None => ()
        }
        lock.writeMutex.unlock()

        if (found) {
            match (services.get(serviceName)) {
                case Some(instances) =>
                    for (inst in instances) {
                        if (inst.actorPath == actorPath) {
                            match (eventHandler) {
                                case Some(handler) => handler.onServiceUpdated(serviceName, inst)
                                case None => ()
                            }
                            break
                        }
                    }
                case None => ()
            }
        }

        found
    }

    /**
     * 获取所有服务名称
     */
    public func getServiceNames(): ArrayList<String> {
        lock.readMutex.lock()
        let names = ArrayList<String>()
        for ((name, _) in services) {
            names.add(name)
        }
        lock.readMutex.unlock()
        names
    }

    /**
     * 获取服务数量
     */
    public func serviceCount(): Int64 {
        lock.readMutex.lock()
        let count = services.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取总实例数量
     */
    public func totalInstances(): Int64 {
        lock.readMutex.lock()
        var total: Int64 = 0
        for ((_, instances) in services) {
            total += instances.size
        }
        lock.readMutex.unlock()
        total
    }

    /**
     * 检查服务是否存在
     */
    public func hasService(serviceName: String): Bool {
        lock.readMutex.lock()
        let result = services.get(serviceName).isSome()
        lock.readMutex.unlock()
        result
    }

    /**
     * 检查实例是否存在
     */
    public func hasInstance(serviceName: String, actorPath: String): Bool {
        lock.readMutex.lock()
        var found = false
        match (services.get(serviceName)) {
            case Some(instances) =>
                for (inst in instances) {
                    if (inst.actorPath == actorPath) {
                        found = true
                        break
                    }
                }
            case None => ()
        }
        lock.readMutex.unlock()
        found
    }

    /**
     * 获取注册次数
     */
    public func getRegistrationCount(): Int64 {
        lock.readMutex.lock()
        let count = registrationCount
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取发现次数
     */
    public func getDiscoveryCount(): Int64 {
        lock.readMutex.lock()
        let count = discoveryCount
        lock.readMutex.unlock()
        count
    }

    /**
     * 清理过时实例
     */
    public func cleanupStaleInstances(): Int64 {
        lock.writeMutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let threshold = Duration.minute * 5
        var removed: Int64 = 0

        for ((serviceName, instances) in services) {
            let toRemove = ArrayList<Int64>()
            for (i in 0..instances.size) {
                let age = now - instances[i].lastSeen
                if (age > threshold.toMilliseconds()) {
                    toRemove.add(i)
                    actorToService.remove(instances[i].actorPath)
                    removed += 1
                }
            }
            var j: Int64 = toRemove.size - 1
            while (j >= 0) {
                instances.remove(toRemove[j]..toRemove[j])
                j -= 1
            }
        }

        // 清理空服务
        let emptyServices = ArrayList<String>()
        for ((name, instances) in services) {
            if (instances.size == 0) {
                emptyServices.add(name)
            }
        }
        for (name in emptyServices) {
            services.remove(name)
        }

        lock.writeMutex.unlock()
        removed
    }

    /**
     * 获取本节点实例
     */
    public func getLocalInstances(): ArrayList<ServiceInstance> {
        lock.readMutex.lock()
        let result = ArrayList<ServiceInstance>()
        for ((_, instances) in services) {
            for (inst in instances) {
                if (inst.nodeId == nodeId) {
                    result.add(inst)
                }
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取远程节点实例
     */
    public func getRemoteInstances(): ArrayList<ServiceInstance> {
        lock.readMutex.lock()
        let result = ArrayList<ServiceInstance>()
        for ((_, instances) in services) {
            for (inst in instances) {
                if (inst.nodeId != nodeId) {
                    result.add(inst)
                }
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取节点 ID
     */
    public func getNodeId(): String {
        nodeId
    }

    /**
     * 获取节点地址
     */
    public func getNodeAddress(): Address {
        nodeAddress
    }
}

/**
 * 创建集群接待员
 */
public func createClusterReceptionist(nodeId: String, nodeAddress: Address): ClusterReceptionist {
    ClusterReceptionist(nodeId, nodeAddress)
}

/**
 * 创建默认接待员配置
 */
public func createDefaultReceptionistConfig(): ReceptionistConfig {
    ReceptionistConfig(
        10000,              // maxServices
        1000,               // maxInstancesPerService
        Duration.minute,    // heartbeatInterval
        Duration.minute * 5, // staleThreshold
        true                // enableReplication
    )
}