/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 服务发现机制
 * 对标 Akka Discovery
 * 提供服务注册、发现和动态更新功能
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 服务信息
 */
public class ServiceEndpoint {
    public let serviceName: String
    public let host: String
    public let port: Int32
    public let metadata: HashMap<String, String>
    public let timestamp: Int64

    public init(serviceName: String, host: String, port: Int32) {
        this.serviceName = serviceName
        this.host = host
        this.port = port
        this.metadata = HashMap<String, String>()
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func withMetadata(key: String, value: String): ServiceEndpoint {
        let instance = ServiceEndpoint(serviceName, host, port)
        for ((k, v) in metadata) {
            instance.metadata.add(k, v)
        }
        instance.metadata.add(key, value)
        instance
    }

    public func address(): String {
        "${host}:${port}"
    }

    public func toString(): String {
        "ServiceEndpoint(${serviceName}@${address()})"
    }
}

/**
 * 服务发现事件
 */
public interface ServiceDiscoveryEventHandler {
    func onServiceRegistered(instance: ServiceEndpoint): Unit
    func onServiceUnregistered(instance: ServiceEndpoint): Unit
    func onServicesChanged(serviceName: String): Unit
}

/**
 * 服务注册表
 */
public class ServiceRegistry {
    private let services: HashMap<String, ArrayList<ServiceEndpoint>>
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.services = HashMap<String, ArrayList<ServiceEndpoint>>()
        this.lock = ReentrantReadWriteMutex()
    }

    public func register(instance: ServiceEndpoint): Unit {
        lock.writeMutex.lock()
        try {
            let list = services.get(instance.serviceName).getOrDefault({=> ArrayList<ServiceEndpoint>()})
            // 检查是否已存在
            var found = false
            var i: Int64 = 0
            while (i < list.size && !found) {
                if (list[Int64(i)].address() == instance.address()) {
                    found = true
                }
                i += 1
            }
            if (!found) {
                list.add(instance)
                services.add(instance.serviceName, list)
            }
        } finally {
            lock.writeMutex.unlock()
        }
    }

    public func unregister(serviceName: String, host: String, port: Int32): Unit {
        lock.writeMutex.lock()
        try {
            let listOpt = services.get(serviceName)
            if (listOpt.isSome()) {
                let list = listOpt.getOrThrow()
                var removeIdx: Int64 = -1
                var i: Int64 = 0
                let targetAddr = "${host}:${port}"
                while (i < list.size) {
                    if (list[Int64(i)].address() == targetAddr) {
                        removeIdx = i
                        i = list.size
                    }
                    i += 1
                }
                if (removeIdx >= 0) {
                    let newList = ArrayList<ServiceEndpoint>()
                    var j: Int64 = 0
                    while (j < list.size) {
                        if (j != removeIdx) {
                            newList.add(list[Int64(j)])
                        }
                        j += 1
                    }
                    services.add(serviceName, newList)
                }
            }
        } finally {
            lock.writeMutex.unlock()
        }
    }

    public func find(serviceName: String): ArrayList<ServiceEndpoint> {
        lock.readMutex.lock()
        let result = services.get(serviceName).getOrDefault({=> ArrayList<ServiceEndpoint>()})
        lock.readMutex.unlock()
        result
    }

    public func findAll(): HashMap<String, ArrayList<ServiceEndpoint>> {
        lock.readMutex.lock()
        let result = HashMap<String, ArrayList<ServiceEndpoint>>()
        for ((name, list) in services) {
            let copy = ArrayList<ServiceEndpoint>()
            for (inst in list) {
                copy.add(inst)
            }
            result.add(name, copy)
        }
        lock.readMutex.unlock()
        result
    }

    public func getServiceNames(): ArrayList<String> {
        lock.readMutex.lock()
        let result = ArrayList<String>()
        for ((name, _) in services) {
            result.add(name)
        }
        lock.readMutex.unlock()
        result
    }

    public func clear(): Unit {
        lock.writeMutex.lock()
        services.clear()
        lock.writeMutex.unlock()
    }
}

/**
 * 服务发现接口 - 对标 Akka Discovery
 */
public interface ServiceDiscovery {
    /**
     * 发现服务实例
     */
    func discover(serviceName: String): ArrayList<ServiceEndpoint>

    /**
     * 注册服务
     */
    func register(instance: ServiceEndpoint): Unit

    /**
     * 注销服务
     */
    func unregister(serviceName: String, host: String, port: Int32): Unit

    /**
     * 获取所有服务名称
     */
    func getServiceNames(): ArrayList<String>
}

/**
 * 简单服务发现实现 - 基于内存注册表
 */
public class SimpleServiceDiscovery <: ServiceDiscovery {
    private let registry: ServiceRegistry
    private var eventHandler: Option<ServiceDiscoveryEventHandler>
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.registry = ServiceRegistry()
        this.eventHandler = None
        this.lock = ReentrantReadWriteMutex()
    }

    public func setEventHandler(handler: ServiceDiscoveryEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    public func discover(serviceName: String): ArrayList<ServiceEndpoint> {
        registry.find(serviceName)
    }

    public func register(instance: ServiceEndpoint): Unit {
        registry.register(instance)
        match (eventHandler) {
            case Some(handler) => handler.onServiceRegistered(instance)
            case None => ()
        }
        match (eventHandler) {
            case Some(handler) => handler.onServicesChanged(instance.serviceName)
            case None => ()
        }
    }

    public func unregister(serviceName: String, host: String, port: Int32): Unit {
        let instance = ServiceEndpoint(serviceName, host, port)
        registry.unregister(serviceName, host, port)
        match (eventHandler) {
            case Some(handler) => handler.onServiceUnregistered(instance)
            case None => ()
        }
        match (eventHandler) {
            case Some(handler) => handler.onServicesChanged(serviceName)
            case None => ()
        }
    }

    public func getServiceNames(): ArrayList<String> {
        registry.getServiceNames()
    }
}

/**
 * DNS 服务发现实现
 */
public class DnsServiceDiscovery <: ServiceDiscovery {
    private let domain: String
    private let registry: ServiceRegistry
    private let lock: ReentrantReadWriteMutex

    public init(domain: String) {
        this.domain = domain
        this.registry = ServiceRegistry()
        this.lock = ReentrantReadWriteMutex()
    }

    public func discover(serviceName: String): ArrayList<ServiceEndpoint> {
        lock.readMutex.lock()
        let instances = registry.find(serviceName)
        lock.readMutex.unlock()
        instances
    }

    public func register(instance: ServiceEndpoint): Unit {
        registry.register(instance)
    }

    public func unregister(serviceName: String, host: String, port: Int32): Unit {
        registry.unregister(serviceName, host, port)
    }

    public func getServiceNames(): ArrayList<String> {
        registry.getServiceNames()
    }

    /**
     * 添加 DNS 解析的服务实例
     */
    public func addFromDns(serviceName: String, host: String, port: Int32): Unit {
        let instance = ServiceEndpoint(serviceName, host, port)
            .withMetadata("dns", domain)
        registry.register(instance)
    }
}

/**
 * 创建简单的服务发现
 */
public func createSimpleServiceDiscovery(): SimpleServiceDiscovery {
    SimpleServiceDiscovery()
}

/**
 * 创建 DNS 服务发现
 */
public func createDnsServiceDiscovery(domain: String): DnsServiceDiscovery {
    DnsServiceDiscovery(domain)
}