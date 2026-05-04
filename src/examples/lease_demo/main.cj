/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Lease 租约机制示例程序
 * 展示分布式租约在协调场景中的使用
 */
package cactor.examples.lease_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示事件处理器
 */
public class DemoLeaseHandler <: LeaseEventHandler {
    public let acquired = ArrayList<String>()
    public let released = ArrayList<String>()
    public let failed = ArrayList<String>()

    public func onLeaseAcquired(leaseName: String, owner: String): Unit {
        acquired.add("${leaseName}:${owner}")
        println("  [EVENT] Lease acquired: ${leaseName} by ${owner}")
    }

    public func onLeaseReleased(leaseName: String, owner: String): Unit {
        released.add("${leaseName}:${owner}")
        println("  [EVENT] Lease released: ${leaseName} by ${owner}")
    }

    public func onLeaseAcquireFailed(leaseName: String, owner: String, reason: String): Unit {
        failed.add("${leaseName}:${owner}:${reason}")
        println("  [EVENT] Lease acquire failed: ${leaseName} by ${owner} - ${reason}")
    }
}

/**
 * 模拟分片协调器
 * 使用租约确保同一时刻只有一个节点是主协调器
 */
public class ShardLeaseCoordinator {
    private let lease: SingleOwnerLease
    private let nodeId: String

    public init(nodeId: String, leaseName: String, timeout: Duration) {
        this.nodeId = nodeId
        this.lease = createSingleOwnerLease(leaseName, timeout)
    }

    public func tryBecomeLeader(): Bool {
        let result = lease.acquire(nodeId, Duration.minute * 5)
        if (result.granted) {
            println("[${nodeId}] Became leader!")
        } else {
            let owner = lease.getOwner()
            match (owner) {
                case Some(o) => println("[${nodeId}] Failed to become leader, held by ${o}")
                case None => println("[${nodeId}] Failed to become leader")
            }
        }
        result.granted
    }

    public func isLeader(): Bool {
        match (lease.getOwner()) {
            case Some(owner) => owner == nodeId
            case None => false
        }
    }

    public func resign(): Unit {
        if (isLeader()) {
            lease.release(nodeId)
            println("[${nodeId}] Resigned leadership")
        }
    }
}

/**
 * 运行基本租约演示
 */
public func runBasicLeaseDemo(): Unit {
    println("=== Basic Lease Demo ===")
    let handler = DemoLeaseHandler()
    let lease = createSingleOwnerLease("exclusive-operation", Duration.minute * 5)
    lease.setEventHandler(handler)

    println("Attempting to acquire lease...")
    let result1 = lease.acquire("node-1", Duration.minute * 5)
    println("Result: ${result1.granted}, reason: ${result1.reason}")

    println("Attempting to acquire again by different owner...")
    let result2 = lease.acquire("node-2", Duration.minute * 5)
    println("Result: ${result2.granted}, reason: ${result2.reason}")

    println("Checking lease state: ${lease.check()}")
    println("Current owner: ${lease.getOwner()}")

    println("Releasing lease...")
    lease.release("node-1")
    println("Lease state after release: ${lease.check()}")

    println()
}

/**
 * 运行领导人选举演示
 */
public func runLeaderElectionDemo(): Unit {
    println("=== Leader Election Demo ===")
    let node1 = ShardLeaseCoordinator("node-1", "shard-coordinator", Duration.minute * 3)
    let node2 = ShardLeaseCoordinator("node-2", "shard-coordinator", Duration.minute * 3)
    let node3 = ShardLeaseCoordinator("node-3", "shard-coordinator", Duration.minute * 3)

    println("Simulating leader election...")
    println()

    let elected = node1.tryBecomeLeader()
    if (elected) {
        println("node-1 elected as leader")
    }

    println()
    println("Other nodes trying to become leader...")
    node2.tryBecomeLeader()
    node3.tryBecomeLeader()

    println()
    println("Checking leadership...")
    println("node-1 is leader: ${node1.isLeader()}")
    println("node-2 is leader: ${node2.isLeader()}")
    println("node-3 is leader: ${node3.isLeader()}")

    println()
    println("node-1 resigning...")
    node1.resign()

    println()
    println("After resignation, node-2 trying to become leader...")
    node2.tryBecomeLeader()

    println()
}

/**
 * 运行租约管理器演示
 */
public func runLeaseManagerDemo(): Unit {
    println("=== Lease Manager Demo ===")
    let manager = createLeaseManager()

    let lease1 = createSingleOwnerLease("shard-1-coordinator", Duration.minute * 5)
    let lease2 = createSingleOwnerLease("shard-2-coordinator", Duration.minute * 5)
    let lease3 = createSingleOwnerLease("shard-3-coordinator", Duration.minute * 5)

    manager.register(lease1)
    manager.register(lease2)
    manager.register(lease3)

    println("Registered ${manager.getLeaseNames().size} leases")

    lease1.acquire("node-1", Duration.minute * 5)
    lease2.acquire("node-2", Duration.minute * 5)

    let active = manager.getActiveLeases()
    println("Active leases: ${active.size}")
    for (name in active) {
        let lease = manager.getLease(name)
        match (lease) {
            case Some(l) =>
                match (l.getOwner()) {
                    case Some(o) => println("  - ${name} owned by ${o}")
                    case None => ()
                }
            case None => ()
        }
    }

    println()
}

/**
 * 运行配置演示
 */
public func runConfigDemo(): Unit {
    println("=== Lease Config Demo ===")

    let config = LeaseConfig("custom-lease", Duration.minute * 10)
        .withRetryInterval(Duration.second * 2)
        .withMaxRetries(5)

    println("Lease name: ${config.leaseName}")
    println("Timeout: ${config.timeout}")
    println("Retry interval: ${config.retryInterval}")
    println("Max retries: ${config.maxRetries}")

    let lease = SingleOwnerLease(config)
    let result = lease.acquire("owner", Duration.minute * 5)
    println("Acquired with config: ${result.granted}")

    println()
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    println("CActor Lease Demo")
    println("==================")
    println()

    runBasicLeaseDemo()
    runLeaderElectionDemo()
    runLeaseManagerDemo()
    runConfigDemo()

    println("=== Demo Complete ===")
}
