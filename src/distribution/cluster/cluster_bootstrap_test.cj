/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ClusterBootstrap 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === BootstrapState Tests ===

@Test
func testBootstrapState_values() {
    let idle = BootstrapState.Idle
    let discovering = BootstrapState.Discovering
    let joining = BootstrapState.Joining
    let done = BootstrapState.Done
    let failed = BootstrapState.Failed("timeout")

    match (idle) {
        case BootstrapState.Idle => @Expect(true, true)
        case _ => @Expect(true, false)
    }
    match (done) {
        case BootstrapState.Done => @Expect(true, true)
        case _ => @Expect(true, false)
    }
    match (failed) {
        case BootstrapState.Failed(msg) => @Expect(msg, "timeout")
        case _ => @Expect(true, false)
    }
}

// === BootstrapDiscoveryMethod Tests ===

@Test
func testBootstrapDiscoveryMethod_values() {
    let config = BootstrapDiscoveryMethod.ConfigBased
    let dns = BootstrapDiscoveryMethod.DnsBased
    let k8s = BootstrapDiscoveryMethod.KubernetesApi
    let static_ = BootstrapDiscoveryMethod.StaticList

    match (config) {
        case BootstrapDiscoveryMethod.ConfigBased => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}

// === ContactPoint Tests ===

@Test
func testContactPoint_creation() {
    let cp = ContactPoint("node-1", "localhost", 2552, true)
    @Expect(cp.nodeId, "node-1")
    @Expect(cp.host, "localhost")
    @Expect(cp.port, 2552)
    @Expect(cp.isSeedNode, true)
    @Expect(cp.isReachable, false)
    @Expect(cp.responseTime, 0)
}

@Test
func testContactPoint_address() {
    let cp = ContactPoint("node-1", "192.168.1.100", 8080, false)
    @Expect(cp.address(), "192.168.1.100:8080")
}

@Test
func testContactPoint_touch() {
    let cp = ContactPoint("node-1", "localhost", 2552, false)
    @Expect(cp.lastCheckTime, 0)
    cp.touch()
    @Expect(cp.lastCheckTime > 0, true)
}

// === BootstrapConfig Tests ===

@Test
func testBootstrapConfig_creation() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("host1:2552")
    contactPoints.append("host2:2552")

    let config = BootstrapConfig(
        BootstrapDiscoveryMethod.ConfigBased,
        contactPoints,
        "",
        "",
        "client",
        Duration.second * 30,
        Duration.second * 3,
        10,
        Duration.second * 10
    )
    @Expect(config.discoveryMethod, BootstrapDiscoveryMethod.ConfigBased)
    @Expect(config.contactPoints.size, 2)
    @Expect(config.maxRetryAttempts, 10)
}

// === BootstrapResult Tests ===

@Test
func testBootstrapResult_success() {
    let members = ArrayList<String>()
    members.append("node-1")
    members.append("node-2")

    let result = BootstrapResult(
        true,
        "node-1",
        "localhost:2552",
        members,
        100,
        1,
        None
    )
    @Expect(result.success, true)
    @Expect(result.joinedNodeId, "node-1")
    @Expect(result.clusterMembers.size, 2)
    @Expect(result.bootstrapTime, 100)
    @Expect(result.attemptCount, 1)
    @Expect(result.failureReason.isNone(), true)
}

@Test
func testBootstrapResult_failure() {
    let result = BootstrapResult(
        false,
        "node-1",
        "",
        ArrayList<String>(),
        30000,
        10,
        Some("timeout")
    )
    @Expect(result.success, false)
    @Expect(result.failureReason.getOrThrow(), "timeout")
}

// === ClusterBootstrap Tests ===

@Test
func testClusterBootstrap_creation() {
    let bootstrap = createClusterBootstrap("node-1")
    @Expect(bootstrap.getNodeId(), "node-1")
    @Expect(bootstrap.getState(), BootstrapState.Idle)
}

@Test
func testClusterBootstrap_startWithNoContactPoints() {
    let contactPoints = ArrayList<String>()
    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    @Expect(bootstrap.contactPointCount(), 0)
    @Expect(bootstrap.reachableCount(), 0)
}

@Test
func testClusterBootstrap_addContactPoints() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("localhost:2552")
    contactPoints.append("localhost:2553")

    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    @Expect(bootstrap.contactPointCount(), 2)
}

@Test
func testClusterBootstrap_markReachable() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("localhost:2552")

    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    @Expect(bootstrap.checkReachability("localhost:2552"), false)
    @Expect(bootstrap.reachableCount(), 0)

    bootstrap.markReachable("localhost:2552")
    @Expect(bootstrap.checkReachability("localhost:2552"), true)
    @Expect(bootstrap.reachableCount(), 1)
}

@Test
func testClusterBootstrap_markUnreachable() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("localhost:2552")

    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    bootstrap.markReachable("localhost:2552")
    @Expect(bootstrap.reachableCount(), 1)

    bootstrap.markUnreachable("localhost:2552")
    @Expect(bootstrap.checkReachability("localhost:2552"), false)
    @Expect(bootstrap.reachableCount(), 0)
}

@Test
func testClusterBootstrap_seedNodeCount() {
    let seedNodes = ArrayList<String>()
    seedNodes.append("seed1:2552")
    seedNodes.append("seed2:2552")

    let config = createBootstrapConfigWithSeedNodes(seedNodes)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    @Expect(bootstrap.seedNodeCount(), 2)
}

@Test
func testClusterBootstrap_getContactPoints() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("host1:2552")
    contactPoints.append("host2:2552")

    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    let points = bootstrap.getContactPoints()
    @Expect(points.size, 2)
}

@Test
func testClusterBootstrap_reset() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("localhost:2552")

    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)

    bootstrap.markReachable("localhost:2552")
    @Expect(bootstrap.reachableCount(), 1)

    bootstrap.reset()
    @Expect(bootstrap.getState(), BootstrapState.Idle)
    @Expect(bootstrap.reachableCount(), 0)
    @Expect(bootstrap.getAttemptCount(), 0)
}

@Test
func testClusterBootstrap_getJoinedAddress() {
    let bootstrap = createClusterBootstrap("node-1")
    @Expect(bootstrap.getJoinedAddress(), "")
}

@Test
func testClusterBootstrap_getClusterMembers() {
    let bootstrap = createClusterBootstrap("node-1")
    let members = bootstrap.getClusterMembers()
    @Expect(members.size, 0)
}

@Test
func testClusterBootstrap_getAttemptCount() {
    let bootstrap = createClusterBootstrap("node-1")
    @Expect(bootstrap.getAttemptCount(), 0)
}

@Test
func testClusterBootstrap_getElapsedTime() {
    let bootstrap = createClusterBootstrap("node-1")
    @Expect(bootstrap.getElapsedTime(), 0)
}

// === Bootstrap Config Factory Tests ===

@Test
func testCreateBootstrapConfigWithContactPoints() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("host:2552")
    let config = createBootstrapConfigWithContactPoints(contactPoints)
    @Expect(config.discoveryMethod, BootstrapDiscoveryMethod.ConfigBased)
    @Expect(config.contactPoints.size, 1)
}

@Test
func testCreateBootstrapConfigWithDns() {
    let contactPoints = ArrayList<String>()
    let config = createBootstrapConfigWithDns("my-service", contactPoints)
    @Expect(config.discoveryMethod, BootstrapDiscoveryMethod.DnsBased)
    @Expect(config.dnsServiceName, "my-service")
}

@Test
func testCreateBootstrapConfigWithKubernetes() {
    let config = createBootstrapConfigWithKubernetes("default", "my-app", "client")
    @Expect(config.discoveryMethod, BootstrapDiscoveryMethod.KubernetesApi)
    @Expect(config.kubernetesNamespace, "default")
    @Expect(config.kubernetesPortName, "client")
}

@Test
func testCreateBootstrapConfigWithSeedNodes() {
    let seedNodes = ArrayList<String>()
    seedNodes.append("seed1:2552")
    seedNodes.append("seed2:2552")
    let config = createBootstrapConfigWithSeedNodes(seedNodes)
    @Expect(config.discoveryMethod, BootstrapDiscoveryMethod.StaticList)
    @Expect(config.contactPoints.size, 2)
}

// === Bootstrap Event Handler Tests ===

@Test
func testClusterBootstrap_setEventHandler() {
    let bootstrap = createClusterBootstrap("node-1")
    let handler = TestBootstrapHandler()
    bootstrap.setEventHandler(handler)
    @Expect(handler.startedCount > 0, true)
}

@Test
func testClusterBootstrap_startCallsDiscovery() {
    let seedNodes = ArrayList<String>()
    seedNodes.append("localhost:2552")
    seedNodes.append("localhost:2553")
    let config = createBootstrapConfigWithSeedNodes(seedNodes)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)
    let handler = TestBootstrapHandler()
    bootstrap.setEventHandler(handler)

    // 标记种子节点为可达
    bootstrap.markReachable("localhost:2552")
    bootstrap.markReachable("localhost:2553")

    let result = bootstrap.start()
    // 如果有可达节点，应该成功
    @Expect(result.success, true)
    @Expect(result.joinedNodeId, "node-1")
}

// === BootstrapEventHandler Implementation for Tests ===

class TestBootstrapHandler <: BootstrapEventHandler {
    public var startedCount: Int64 = 0
    public var discoveryCount: Int64 = 0
    public var contactFoundCount: Int64 = 0
    public var reachableCount: Int64 = 0
    public var unreachableCount: Int64 = 0
    public var joiningCount: Int64 = 0
    public var joinedCount: Int64 = 0
    public var failedCount: Int64 = 0
    public var retryCount: Int64 = 0
    public var stateChangedCount: Int64 = 0

    public func onBootstrapStarted(nodeId: String): Unit {
        startedCount += 1
    }

    public func onDiscoveryStarted(method: BootstrapDiscoveryMethod): Unit {
        discoveryCount += 1
    }

    public func onContactPointFound(nodeId: String, address: String): Unit {
        contactFoundCount += 1
    }

    public func onContactPointReachable(nodeId: String, address: String): Unit {
        reachableCount += 1
    }

    public func onContactPointUnreachable(nodeId: String, address: String): Unit {
        unreachableCount += 1
    }

    public func onJoiningCluster(nodeId: String, targetAddress: String): Unit {
        joiningCount += 1
    }

    public func onClusterJoined(nodeId: String, members: ArrayList<String>): Unit {
        joinedCount += 1
    }

    public func onBootstrapFailed(nodeId: String, reason: String): Unit {
        failedCount += 1
    }

    public func onRetryAttempt(attempt: Int64, maxAttempts: Int64): Unit {
        retryCount += 1
    }

    public func onStateChanged(fromState: BootstrapState, toState: BootstrapState): Unit {
        stateChangedCount += 1
    }
}

// === Error Handling Tests ===

@Test
func testClusterBootstrap_invalidAddress() {
    // 测试无效地址（没有端口）
    let contactPoints = ArrayList<String>()
    contactPoints.append("invalid-address")  // 格式不正确
    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)
    @Expect(bootstrap.contactPointCount(), 0)  // 无效地址不应该被添加
}

@Test
func testClusterBootstrap_duplicateContactPoint() {
    let contactPoints = ArrayList<String>()
    contactPoints.append("localhost:2552")
    contactPoints.append("localhost:2552")  // 重复
    let config = createBootstrapConfigWithContactPoints(contactPoints)
    let bootstrap = createClusterBootstrapWithConfig("node-1", config)
    @Expect(bootstrap.contactPointCount(), 1)  // 只有一个
}
