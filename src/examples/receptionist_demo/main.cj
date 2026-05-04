/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Receptionist 示例程序
 * 展示集群服务发现机制的使用
 */
package cactor.examples.receptionist_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示接待员事件处理器
 */
public class DemoReceptionistHandler <: ReceptionistEventHandler {
    public let registeredEvents = ArrayList<String>()
    public let unregisteredEvents = ArrayList<String>()
    public let updatedEvents = ArrayList<String>()
    public let discoveryEvents = ArrayList<String>()

    public func onServiceRegistered(serviceName: String, instance: ServiceInstance): Unit {
        registeredEvents.add(serviceName)
        println("  [REGISTERED] ${serviceName}: ${instance.actorPath} @ ${instance.nodeId}")
    }

    public func onServiceUnregistered(serviceName: String, actorPath: String): Unit {
        unregisteredEvents.add(serviceName)
        println("  [UNREGISTERED] ${serviceName}: ${actorPath}")
    }

    public func onServiceUpdated(serviceName: String, instance: ServiceInstance): Unit {
        updatedEvents.add(serviceName)
        println("  [UPDATED] ${serviceName}: ${instance.actorPath}")
    }

    public func onDiscovery(serviceName: String, instances: ArrayList<ServiceInstance>): Unit {
        discoveryEvents.add(serviceName)
        println("  [DISCOVERED] ${serviceName}: ${instances.size} instances")
    }
}

/**
 * 运行基本注册发现演示
 */
public func runBasicRegistrationDemo(): Unit {
    println("=== Basic Registration & Discovery Demo ===")
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))
    let handler = DemoReceptionistHandler()
    receptionist.setEventHandler(handler)

    println("Registering services...")
    receptionist.register("user-service", "/user/user-service")
    receptionist.register("order-service", "/user/order-service")
    receptionist.register("payment-service", "/user/payment-service")

    println()
    println("Registered services: ${receptionist.getServiceNames()}")

    println()
    println("Discovering services...")
    let userService = receptionist.find("user-service")
    match (userService) {
        case Some(inst) =>
            println("  Found user-service: ${inst.actorPath} @ ${inst.nodeId}")
        case None =>
            println("  user-service not found")
    }

    println()
    println("Finding all instances of order-service...")
    let orderInstances = receptionist.findAll("order-service")
    println("  ${orderInstances.size} instances")
    println()
}

/**
 * 运行批量注册演示
 */
public func runBatchRegistrationDemo(): Unit {
    println("=== Batch Registration Demo ===")
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))
    let handler = DemoReceptionistHandler()
    receptionist.setEventHandler(handler)

    println("Creating batch registrations...")
    let registrations = ArrayList<RegisterRequest>()
    registrations.append(RegisterRequest("service-a", "/user/sa1", "node-1", Address("cactor", "test", "host", 2552)))
    registrations.append(RegisterRequest("service-a", "/user/sa2", "node-1", Address("cactor", "test", "host", 2552)))
    registrations.append(RegisterRequest("service-b", "/user/sb1", "node-1", Address("cactor", "test", "host", 2552)))
    registrations.append(RegisterRequest("service-c", "/user/sc1", "node-1", Address("cactor", "test", "host", 2552)))

    println("Registering ${registrations.size} services...")
    let count = receptionist.registerAll(registrations)
    println()
    println("Registered ${count} services")
    println("  Total services: ${receptionist.serviceCount()}")
    println("  Total instances: ${receptionist.totalInstances()}")
    println()
}

/**
 * 运行前缀搜索演示
 */
public func runPrefixSearchDemo(): Unit {
    println("=== Prefix Search Demo ===")
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))

    println("Registering services with common prefix...")
    receptionist.register("user-service-v1", "/user/v1/actor")
    receptionist.register("user-service-v2", "/user/v2/actor")
    receptionist.register("user-api", "/user/api/actor")
    receptionist.register("admin-service", "/user/admin/actor")
    receptionist.register("admin-dashboard", "/user/dashboard/actor")

    println()
    println("Services: ${receptionist.getServiceNames()}")

    println()
    println("Searching for 'user-*' services...")
    let userServices = receptionist.findWithPrefix("user-")
    println("  Found ${userServices.size} services:")
    for (inst in userServices) {
        println("    - ${inst.serviceName}: ${inst.actorPath}")
    }

    println()
    println("Searching for 'admin-*' services...")
    let adminServices = receptionist.findWithPrefix("admin-")
    println("  Found ${adminServices.size} services:")
    for (inst in adminServices) {
        println("    - ${inst.serviceName}: ${inst.actorPath}")
    }
    println()
}

/**
 * 运行元数据更新演示
 */
public func runMetadataUpdateDemo(): Unit {
    println("=== Metadata Update Demo ===")
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))
    let handler = DemoReceptionistHandler()
    receptionist.setEventHandler(handler)

    println("Registering service with metadata...")
    let instance = receptionist.register("user-service", "/user/user-service")
        .withMetadata("version", "1.0")
        .withMetadata("region", "us-east-1")

    println()
    println("Initial metadata:")
    match (receptionist.find("user-service")) {
        case Some(inst) =>
            println("  version: ${inst.getMetadata("version").getOrThrow()}")
            println("  region: ${inst.getMetadata("region").getOrThrow()}")
        case None => ()
    }

    println()
    println("Updating metadata...")
    receptionist.updateMetadata("user-service", "/user/user-service", "version", "2.0")
    receptionist.updateMetadata("user-service", "/user/user-service", "health", "healthy")

    println()
    println("After update:")
    match (receptionist.find("user-service")) {
        case Some(inst) =>
            println("  version: ${inst.getMetadata("version").getOrThrow()}")
            println("  health: ${inst.getMetadata("health").getOrThrow()}")
        case None => ()
    }
    println()
}

/**
 * 运行服务统计演示
 */
public func runServiceStatsDemo(): Unit {
    println("=== Service Statistics Demo ===")
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))

    println("Registering multiple services...")
    receptionist.register("service-a", "/user/sa1")
    receptionist.register("service-a", "/user/sa2")
    receptionist.register("service-a", "/user/sa3")
    receptionist.register("service-b", "/user/sb1")
    receptionist.register("service-b", "/user/sb2")
    receptionist.register("service-c", "/user/sc1")

    println()
    println("Statistics:")
    println("  Total services: ${receptionist.serviceCount()}")
    println("  Total instances: ${receptionist.totalInstances()}")
    println()

    println("Per-service counts:")
    for (name in receptionist.getServiceNames()) {
        println("  ${name}: ${receptionist.count(name)} instances")
    }

    println()
    println("Making discoveries...")
    receptionist.find("service-a")
    receptionist.findAll("service-b")
    receptionist.findWithPrefix("service-")

    println()
    println("Activity counters:")
    println("  Total registrations: ${receptionist.getRegistrationCount()}")
    println("  Total discoveries: ${receptionist.getDiscoveryCount()}")
    println()
}

/**
 * 运行服务注销演示
 */
public func runServiceUnregistrationDemo(): Unit {
    println("=== Service Unregistration Demo ===")
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))
    let handler = DemoReceptionistHandler()
    receptionist.setEventHandler(handler)

    println("Registering services...")
    receptionist.register("user-service", "/user/user-service")
    receptionist.register("order-service", "/user/order-service")
    receptionist.register("payment-service", "/user/payment-service")

    println()
    println("Initial state:")
    println("  Services: ${receptionist.serviceCount()}")
    println("  Instances: ${receptionist.totalInstances()}")

    println()
    println("Unregistering order-service...")
    let found = receptionist.unregister("order-service", "/user/order-service")
    println("  Unregister result: ${found}")

    println()
    println("After unregistration:")
    println("  Services: ${receptionist.serviceCount()}")
    println("  Instances: ${receptionist.totalInstances()}")
    println("  Remaining: ${receptionist.getServiceNames()}")
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Cluster Receptionist Demo")
    println("==================================")
    println()

    runBasicRegistrationDemo()
    runBatchRegistrationDemo()
    runPrefixSearchDemo()
    runMetadataUpdateDemo()
    runServiceStatsDemo()
    runServiceUnregistrationDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}