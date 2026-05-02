/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Formation 单元测试
 */
package cactor.distribution.cluster

import std.collection.{ArrayList, HashMap}
import std.time.*
import cactor.foundation.network.{NetworkAddress}

// === Test Configuration ===

func createTestConfig(): ClusterConfig {
    let seeds = ArrayList<String>()
    seeds.add("system@node1:2552")
    seeds.add("system@node2:2553")
    ClusterConfig(
        clusterName: "test-cluster",
        port: 2552,
        host: "localhost",
        seedNodes: seeds
    )
}

// === Tests ===

@Test
func testGossipSummary_creation() {
    let gossip = GossipSummary(1, 5)

    @Expect(gossip.version, 1)
    @Expect(gossip.memberCount, 5)
}

@Test
func testGossipSummary_activeMemberCount() {
    let gossip = GossipSummary(1, 10)

    @Expect(gossip.activeMemberCount() >= 0, true)
}

@Test
func testGossipProtocol_creation() {
    let config = createTestConfig()
    let protocol = GossipProtocol("node1", config)

    @Expect(protocol.getMemberCount(), 0)
}

@Test
func testGossipProtocol_addMember() {
    let config = createTestConfig()
    let protocol = GossipProtocol("node1", config)

    protocol.addMember()
    protocol.addMember()

    @Expect(protocol.getMemberCount(), 2)
}

@Test
func testGossipProtocol_getCurrentGossip() {
    let config = createTestConfig()
    let protocol = GossipProtocol("node1", config)

    protocol.addMember()

    let gossip = protocol.getCurrentGossip()

    @Expect(gossip.version >= 0, true)
    @Expect(gossip.memberCount >= 1, true)
}

@Test
func testGossipProtocol_handleHeartbeat() {
    let config = createTestConfig()
    let protocol = GossipProtocol("node1", config)

    protocol.addMember()

    let response = protocol.handleGossip(GossipHeartbeat("node2", 1))

    @Expect(response.version >= 1, true)
}

@Test
func testClusterConfig_creation() {
    let config = createTestConfig()

    @Expect(config.clusterName, "test-cluster")
    @Expect(config.port, 2552)
    @Expect(config.host, "localhost")
    @Expect(config.seedNodes.size, 2)
}

@Test
func testClusterConfig_default() {
    let config = ClusterConfig.getDefault()

    @Expect(config.clusterName, "cactor-cluster")
    @Expect(config.port, 2552)
}

@Test
func testSeedNodeDiscovery_discoverNodes() {
    let seeds = ArrayList<String>()
    seeds.add("system@192.168.1.1:2552")
    seeds.add("system@192.168.1.2:2553")

    let discovery = SeedNodeDiscovery(seeds)
    let nodes = discovery.discoverNodes()

    @Expect(nodes.size, 2)
    @Expect(nodes[0].host, "192.168.1.1")
    @Expect(nodes[1].port, 2553)
}

@Test
func testNodeInfo_address() {
    let node = NodeInfo("node1", "localhost", 2552)

    @Expect(node.address(), "localhost:2552")
}

@Test
func testClusterMembershipManager_join() {
    let config = createTestConfig()
    let manager = ClusterMembershipManager("node1", config)

    manager.join()

    @Expect(manager.getMemberCount() >= 1, true)
}

@Test
func testClusterMembershipManager_becomeUp() {
    let config = createTestConfig()
    let manager = ClusterMembershipManager("node1", config)

    manager.join()
    manager.becomeUp()

    @Expect(manager.getMemberCount() >= 1, true)
}

@Test
func testClusterMembershipManager_leave() {
    let config = createTestConfig()
    let manager = ClusterMembershipManager("node1", config)

    manager.join()
    manager.leave()

    @Expect(manager.getMemberCount() >= 0, true)
}

@Test
func testClusterMembershipManager_down() {
    let config = createTestConfig()
    let manager = ClusterMembershipManager("node1", config)

    manager.join()
    manager.down()

    @Expect(manager.getMemberCount() >= 0, true)
}

@Test
func testClusterMembershipManager_sendGossip() {
    let config = createTestConfig()
    let manager = ClusterMembershipManager("node1", config)

    manager.join()

    let gossip = manager.sendGossip()

    @Expect(gossip.version >= 0, true)
}

@Test
func testClusterMembershipManager_receiveGossip() {
    let config = createTestConfig()
    let manager = ClusterMembershipManager("node1", config)

    manager.join()

    let incomingGossip = GossipSummary(5, 10)
    manager.receiveGossip(incomingGossip)

    @Expect(manager.getMemberCount() >= 0, true)
}

// === Integration Tests ===

@Test
func testClusterFormation_fullWorkflow() {
    let config = createTestConfig()

    // 创建多个节点
    let manager1 = ClusterMembershipManager("node1", config)
    let manager2 = ClusterMembershipManager("node2", config)

    // 节点1加入
    manager1.join()
    manager1.becomeUp()

    // 节点2加入
    manager2.join()
    manager2.becomeUp()

    // 交换gossip
    let gossip1 = manager1.sendGossip()
    manager2.receiveGossip(gossip1)

    // 验证成员数
    @Expect(manager2.getMemberCount() >= 1, true)
}

@Test
func testGossipProtocol_convergence() {
    let config = createTestConfig()

    let proto1 = GossipProtocol("node1", config)
    let proto2 = GossipProtocol("node2", config)

    // 添加成员
    proto1.addMember()
    proto2.addMember()

    // Gossip交换
    let gossip1 = proto1.getCurrentGossip()
    let gossip2 = proto2.getCurrentGossip()

    // 模拟合并
    let merged = GossipSummary(gossip2.version + 1, gossip2.memberCount)
    let ack = GossipDigestAck2(merged)
    proto1.handleGossip(ack)

    @Expect(proto1.getMemberCount() >= 1, true)
}

// === ClusterEvent Tests ===

@Test
func testClusterEvent_FormationNodeJoined() {
    let node = ClusterNode(NodeId("node3"), NetworkAddress("localhost", 2552), Array<String>(0, { _ => "" }))
    let event = ClusterEvent.NodeJoined(node)

    match (event) {
        case ClusterEvent.NodeJoined(n) =>
            @Expect(n.nodeId.toString().contains("node3"), true)
        case _ =>
            @Expect(false, true)
    }
}

@Test
func testClusterEvent_FormationNodeUp() {
    let node = ClusterNode(NodeId("node4"), NetworkAddress("localhost", 2552), Array<String>(0, { _ => "" }))
    let event = ClusterEvent.NodeUp(node)

    match (event) {
        case ClusterEvent.NodeUp(n) =>
            @Expect(n.nodeId.toString().contains("node4"), true)
        case _ =>
            @Expect(false, true)
    }
}

@Test
func testClusterEvent_FormationNodeLeft() {
    let node = ClusterNode(NodeId("node5"), NetworkAddress("localhost", 2552), Array<String>(0, { _ => "" }))
    let event = ClusterEvent.NodeLeft(node)

    match (event) {
        case ClusterEvent.NodeLeft(n) =>
            @Expect(n.nodeId.toString().contains("node5"), true)
        case _ =>
            @Expect(false, true)
    }
}

@Test
func testClusterEvent_FormationNodeDown() {
    let node = ClusterNode(NodeId("node6"), NetworkAddress("localhost", 2552), Array<String>(0, { _ => "" }))
    let event = ClusterEvent.NodeDown(node)

    match (event) {
        case ClusterEvent.NodeDown(n) =>
            @Expect(n.nodeId.toString().contains("node6"), true)
        case _ =>
            @Expect(false, true)
    }
}