/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ClusterBootstrap 示例程序
 * 展示自动集群引导的使用
 */
package cactor.examples.bootstrap_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示引导事件处理器
 */
public class DemoBootstrapHandler <: BootstrapEventHandler {
    public let events = ArrayList<String>()

    public func onBootstrapStarted(nodeId: String): Unit {
        let event = "Bootstrap started for: ${nodeId}"
        events.add(event)
        println("  [START] ${event}")
    }

    public func onDiscoveryStarted(method: BootstrapDiscoveryMethod): Unit {
        let methodName = match (method) {
            case BootstrapDiscoveryMethod.ConfigBased => "Config-Based"
            case BootstrapDiscoveryMethod.DnsBased => "DNS-Based"
            case BootstrapDiscoveryMethod.KubernetesApi => "Kubernetes API"
            case BootstrapDiscoveryMethod.StaticList => "Static Seed Nodes"
        }
        let event = "Discovery started: ${methodName}"
        events.add(event)
        println("  [DISCOVERY] ${event}")
    }

    public func onContactPointFound(nodeId: String, address: String): Unit {
        let event = "Found contact point: ${nodeId} @ ${address}"
        events.add(event)
        println("  [FOUND] ${event}")
    }

    public func onContactPointReachable(nodeId: String, address: String): Unit {
        let event = "Contact point reachable: ${nodeId} @ ${address}"
        events.add(event)
        println("  [REACHABLE] ${event}")
    }

    public func onContactPointUnreachable(nodeId: String, address: String): Unit {
        let event = "Contact point unreachable: ${nodeId} @ ${address}"
        events.add(event)
        println("  [UNREACHABLE] ${event}")
    }

    public func onJoiningCluster(nodeId: String, targetAddress: String): Unit {
        let event = "Joining cluster: ${nodeId} -> ${targetAddress}"
        events.add(event)
        println("  [JOINING] ${event}")
    }

    public func onClusterJoined(nodeId: String, members: ArrayList<String>): Unit {
        let event = "Joined cluster: ${nodeId} with ${members.size} members"
        events.add(event)
        println("  [JOINED] ${event}")
        println("    Members: ${members}")
    }

    public func onBootstrapFailed(nodeId: String, reason: String): Unit {
        let event = "Bootstrap failed: ${reason}"
        events.add(event)
        println("  [FAILED] ${event}")
    }

    public func onRetryAttempt(attempt: Int64, maxAttempts: Int64): Unit {
        let event = "Retry attempt ${attempt}/${maxAttempts}"
        events.add(event)
        println("  [RETRY] ${event}")
    }

    public func onStateChanged(fromState: BootstrapState, toState: BootstrapState): Unit {
        let fromName = stateToString(fromState)
        let toName = stateToString(toState)
        let event = "State: ${fromName} -> ${toName}"
        events.add(event)
        println("  [STATE] ${event}")
    }

    private func stateToString(state: BootstrapState): String {
        match (state) {
            case BootstrapState.Idle => "Idle"
            case BootstrapState.Discovering => "Discovering"
            case BootstrapState.Joining => "Joining"
            case BootstrapState.Done => "Done"
            case BootstrapState.Failed(reason) => "Failed(${reason})"
        }
    }
}

/**
 * 运行基本引导演示
 */
public func runBasicBootstrapDemo(): Unit {
    println("=== Basic Cluster Bootstrap Demo ===")

    let seedNodes = ArrayList<String>()
    seedNodes.append("seed-node-1:2552")
    seedNodes.append("seed-node-2:2552")
    seedNodes.append("seed-node-3:2552")

    let config = createBootstrapConfigWithSeedNodes(seedNodes)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)
    let handler = DemoBootstrapHandler()
    bootstrap.setEventHandler(handler)

    println("Contact points discovered:")
    println("  Total: ${bootstrap.contactPointCount()}")
    println("  Seed nodes: ${bootstrap.seedNodeCount()}")

    println()
    println("Marking seed nodes as reachable...")
    bootstrap.markReachable("seed-node-1:2552")
    bootstrap.markReachable("seed-node-2:2552")
    bootstrap.markReachable("seed-node-3:2552")

    println()
    println("Starting bootstrap...")
    let result = bootstrap.start()

    println()
    println("Bootstrap Result:")
    println("  Success: ${result.success}")
    println("  Node ID: ${result.joinedNodeId}")
    println("  Joined Address: ${result.joinedAddress}")
    println("  Members: ${result.clusterMembers.size}")
    println("  Time: ${result.bootstrapTime}ms")
    println("  Attempts: ${result.attemptCount}")
    println()
}

/**
 * 运行配置发现演示
 */
public func runConfigBasedDiscoveryDemo(): Unit {
    println("=== Config-Based Discovery Demo ===")

    let contactPoints = ArrayList<String>()
    contactPoints.append("192.168.1.10:2552")
    contactPoints.append("192.168.1.11:2552")
    contactPoints.append("192.168.1.12:2552")

    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("config-node-1", config)
    let handler = DemoBootstrapHandler()
    bootstrap.setEventHandler(handler)

    println("Starting discovery with config-based method...")
    let result = bootstrap.start()

    println()
    println("Result: ${if (result.success) "SUCCESS" else "FAILED"}")
    match (result.failureReason) {
        case Some(reason) => println("  Reason: ${reason}")
        case None => ()
    }
    println()
}

/**
 * 运行 DNS 发现演示
 */
public func runDnsDiscoveryDemo(): Unit {
    println("=== DNS-Based Discovery Demo ===")

    let fallbackPoints = ArrayList<String>()
    fallbackPoints.append("dns-seed-1:2552")
    fallbackPoints.append("dns-seed-2:2552")

    let config = createBootstrapConfigWithDns("my-cluster", fallbackPoints)
    let bootstrap = createClusterBootstrapWithConfig("dns-node-1", config)
    let handler = DemoBootstrapHandler()
    bootstrap.setEventHandler(handler)

    println("Discovery method: DNS-Based")
    println("Service name: my-cluster")
    println()

    // 标记一些为可达
    bootstrap.markReachable("dns-seed-1:2552")

    let result = bootstrap.start()

    println()
    println("Result: ${if (result.success) "SUCCESS" else "FAILED"}")
    println()
}

/**
 * 运行 Kubernetes 发现演示
 */
public func runKubernetesDiscoveryDemo(): Unit {
    println("=== Kubernetes API Discovery Demo ===")

    let config = createBootstrapConfigWithKubernetes("production", "cactor-cluster", "remoting")
    let bootstrap = createClusterBootstrapWithConfig("k8s-node-1", config)
    let handler = DemoBootstrapHandler()
    bootstrap.setEventHandler(handler)

    println("Discovery method: Kubernetes API")
    println("Namespace: production")
    println("Service: cactor-cluster")
    println("Port: remoting")
    println()

    // 模拟 K8s 发现结果
    let result = bootstrap.start()

    println()
    println("Result: ${if (result.success) "SUCCESS" else "FAILED"}")
    println()
}

/**
 * 运行节点可达性管理演示
 */
public func runReachabilityDemo(): Unit {
    println("=== Node Reachability Management Demo ===")

    let seedNodes = ArrayList<String>()
    seedNodes.append("node-a:2552")
    seedNodes.append("node-b:2552")
    seedNodes.append("node-c:2552")

    let config = createBootstrapConfigWithSeedNodes(seedNodes)
    let bootstrap = createClusterBootstrapWithConfig("node-monitor", config)
    let handler = DemoBootstrapHandler()
    bootstrap.setEventHandler(handler)

    println("Initial state:")
    println("  Total: ${bootstrap.contactPointCount()}")
    println("  Reachable: ${bootstrap.reachableCount()}")

    println()
    println("Marking nodes reachable...")
    bootstrap.markReachable("node-a:2552")
    bootstrap.markReachable("node-b:2552")

    println()
    println("After marking reachable:")
    println("  Reachable: ${bootstrap.reachableCount()}")

    println()
    println("Marking node-b unreachable...")
    bootstrap.markUnreachable("node-b:2552")

    println()
    println("After marking unreachable:")
    println("  Reachable: ${bootstrap.reachableCount()}")

    // 完成引导
    bootstrap.markReachable("node-c:2552")
    let result = bootstrap.start()

    println()
    println("Final result: ${if (result.success) "SUCCESS" else "FAILED"}")
    println()
}

/**
 * 运行重试机制演示
 */
public func runRetryDemo(): Unit {
    println("=== Retry Mechanism Demo ===")

    let seedNodes = ArrayList<String>()
    seedNodes.append("flaky-node:2552")
    seedNodes.append("stable-node:2552")

    // 短超时和少重试次数配置
    let contactPoints = ArrayList<String>()
    let config = BootstrapConfig(
        BootstrapDiscoveryMethod.StaticList,
        seedNodes,
        "",
        "",
        "client",
        Duration.second * 1,   // 短超时
        Duration.millisecond * 100,
        3,                      // 少重试
        Duration.second * 1
    )

    let bootstrap = createClusterBootstrapWithConfig("retry-node", config)
    let handler = DemoBootstrapHandler()
    bootstrap.setEventHandler(handler)

    println("Config: maxAttempts=3, timeout=1s")
    println()

    // 初始没有可达节点 - 会重试
    println("Starting bootstrap without reachable nodes...")
    let result = bootstrap.start()

    println()
    println("Result: ${if (result.success) "SUCCESS" else "FAILED"}")
    println("Attempts: ${result.attemptCount}")

    match (result.failureReason) {
        case Some(reason) => println("  Failure reason: ${reason}")
        case None => ()
    }

    println()
    println("Now marking stable-node reachable and retrying...")
    bootstrap.markReachable("stable-node:2552")
    let retryResult = bootstrap.start()

    println()
    println("Retry result: ${if (retryResult.success) "SUCCESS" else "FAILED"}")
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Cluster Bootstrap Demo")
    println("==============================")
    println()

    runBasicBootstrapDemo()
    runConfigBasedDiscoveryDemo()
    runDnsDiscoveryDemo()
    runKubernetesDiscoveryDemo()
    runReachabilityDemo()
    runRetryDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}
