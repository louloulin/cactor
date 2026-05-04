/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Fleet Manager 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === Helper ===

func createNode(nodeId: String, host: String, port: Int32): FleetNode {
    let addr = Address("cactor", "fleet", host, port)
    FleetNode(nodeId, addr)
}

// === NodeHealth Tests ===

@Test
func testNodeHealth_healthy() {
    @Expect(NodeHealth.Healthy.isHealthy(), true)
    @Expect(NodeHealth.Healthy.needsAttention(), false)
}

@Test
func testNodeHealth_degraded() {
    @Expect(NodeHealth.Degraded.isHealthy(), false)
    @Expect(NodeHealth.Degraded.needsAttention(), true)
}

@Test
func testNodeHealth_unhealthy() {
    @Expect(NodeHealth.Unhealthy.isHealthy(), false)
    @Expect(NodeHealth.Unhealthy.needsAttention(), true)
}

@Test
func testNodeHealth_unknown() {
    @Expect(NodeHealth.Unknown.isHealthy(), false)
    @Expect(NodeHealth.Unknown.needsAttention(), false)
}

// === FleetNode Tests ===

@Test
func testFleetNode_creation() {
    let node = createNode("node-1", "host1", 2552)
    @Expect(node.nodeId, "node-1")
    @Expect(node.status, MemberStatus.Joining)
    @Expect(node.health, NodeHealth.Unknown)
}

@Test
func testFleetNode_withStatus() {
    let node = createNode("node-1", "host1", 2552)
    let updated = node.withStatus(MemberStatus.Up)
    @Expect(updated.status, MemberStatus.Up)
}

@Test
func testFleetNode_withHealth() {
    let node = createNode("node-1", "host1", 2552)
    let updated = node.withHealth(NodeHealth.Healthy)
    @Expect(updated.health, NodeHealth.Healthy)
}

@Test
func testFleetNode_withMetadata() {
    let node = createNode("node-1", "host1", 2552)
    let updated = node.withMetadata("role", "worker")
    @Expect(updated.metadata.contains("role"), true)
}

// === FleetEvent Tests ===

@Test
func testFleetEvent_toString() {
    let event = FleetEvent.NodeJoined("node-1", Address("cactor", "fleet", "host1", 2552))
    let str = event.toString()
    @Expect(str.contains("node-1"), true)
}

// === FleetManager Tests ===

@Test
func testFleetManager_registerNode() {
    let manager = createFleetManager("test-fleet")
    let node = createNode("node-1", "host1", 2552)
    manager.registerNode(node)
    @Expect(manager.hasNode("node-1"), true)
}

@Test
func testFleetManager_nodeCount() {
    let manager = createFleetManager("test-fleet")
    manager.registerNode(createNode("node-1", "host1", 2552))
    manager.registerNode(createNode("node-2", "host2", 2552))
    @Expect(manager.nodeCount(), 2)
}

@Test
func testFleetManager_getNode() {
    let manager = createFleetManager("test-fleet")
    manager.registerNode(createNode("node-1", "host1", 2552))
    let node = manager.getNode("node-1")
    @Expect(node.isSome(), true)
}

@Test
func testFleetManager_getNodeNotFound() {
    let manager = createFleetManager("test-fleet")
    let node = manager.getNode("non-existent")
    @Expect(node.isNone(), true)
}

@Test
func testFleetManager_nodeUp() {
    let manager = createFleetManager("test-fleet")
    let node = createNode("node-1", "host1", 2552)
    manager.registerNode(node)
    manager.nodeUp(node)
    let updated = manager.getNode("node-1")
    match (updated) {
        case Some(n) => @Expect(n.status, MemberStatus.Up)
        case None => ()
    }
}

@Test
func testFleetManager_nodeLeft() {
    let manager = createFleetManager("test-fleet")
    let node = createNode("node-1", "host1", 2552)
    manager.registerNode(node)
    manager.nodeUp(node)
    manager.nodeLeft("node-1")
    let updated = manager.getNode("node-1")
    match (updated) {
        case Some(n) => @Expect(n.status, MemberStatus.Leaving)
        case None => ()
    }
}

@Test
func testFleetManager_nodeDown() {
    let manager = createFleetManager("test-fleet")
    let node = createNode("node-1", "host1", 2552)
    manager.registerNode(node)
    manager.nodeUp(node)
    manager.nodeDown("node-1")
    let updated = manager.getNode("node-1")
    match (updated) {
        case Some(n) => @Expect(n.status, MemberStatus.Down)
        case None => ()
    }
}

@Test
func testFleetManager_removeNode() {
    let manager = createFleetManager("test-fleet")
    manager.registerNode(createNode("node-1", "host1", 2552))
    @Expect(manager.nodeCount(), 1)
    manager.removeNode("node-1")
    @Expect(manager.hasNode("node-1"), false)
}

@Test
func testFleetManager_getAllNodes() {
    let manager = createFleetManager("test-fleet")
    manager.registerNode(createNode("node-1", "host1", 2552))
    manager.registerNode(createNode("node-2", "host2", 2552))
    let nodes = manager.getAllNodes()
    @Expect(nodes.size, 2)
}

@Test
func testFleetManager_getActiveNodes() {
    let manager = createFleetManager("test-fleet")
    let node1 = createNode("node-1", "host1", 2552)
    let node2 = createNode("node-2", "host2", 2552)
    manager.registerNode(node1)
    manager.registerNode(node2)
    manager.nodeUp(node1)
    let active = manager.getActiveNodes()
    @Expect(active.size, 1)
}

@Test
func testFleetManager_activeNodeCount() {
    let manager = createFleetManager("test-fleet")
    let node1 = createNode("node-1", "host1", 2552)
    let node2 = createNode("node-2", "host2", 2552)
    manager.registerNode(node1)
    manager.registerNode(node2)
    manager.nodeUp(node1)
    @Expect(manager.activeNodeCount(), 1)
}

@Test
func testFleetManager_updateHealth() {
    let manager = createFleetManager("test-fleet")
    manager.registerNode(createNode("node-1", "host1", 2552))
    manager.updateHealth("node-1", NodeHealth.Healthy)
    let node = manager.getNode("node-1")
    match (node) {
        case Some(n) => @Expect(n.health, NodeHealth.Healthy)
        case None => ()
    }
}

@Test
func testFleetManager_getHealthyNodes() {
    let manager = createFleetManager("test-fleet")
    let node1 = createNode("node-1", "host1", 2552)
    let node2 = createNode("node-2", "host2", 2552)
    manager.registerNode(node1)
    manager.registerNode(node2)
    manager.nodeUp(node1)
    manager.nodeUp(node2)
    manager.updateHealth("node-1", NodeHealth.Healthy)
    manager.updateHealth("node-2", NodeHealth.Degraded)
    let healthy = manager.getHealthyNodes()
    @Expect(healthy.size, 1)
}

@Test
func testFleetManager_getUnhealthyNodes() {
    let manager = createFleetManager("test-fleet")
    let node1 = createNode("node-1", "host1", 2552)
    let node2 = createNode("node-2", "host2", 2552)
    manager.registerNode(node1)
    manager.registerNode(node2)
    manager.nodeUp(node1)
    manager.nodeUp(node2)
    manager.updateHealth("node-1", NodeHealth.Healthy)
    manager.updateHealth("node-2", NodeHealth.Unhealthy)
    let unhealthy = manager.getUnhealthyNodes()
    @Expect(unhealthy.size, 1)
}

@Test
func testFleetManager_isAllHealthy() {
    let manager = createFleetManager("test-fleet")
    let node1 = createNode("node-1", "host1", 2552)
    let node2 = createNode("node-2", "host2", 2552)
    manager.registerNode(node1)
    manager.registerNode(node2)
    manager.nodeUp(node1)
    manager.nodeUp(node2)
    manager.updateHealth("node-1", NodeHealth.Healthy)
    manager.updateHealth("node-2", NodeHealth.Healthy)
    @Expect(manager.isAllHealthy(), true)
}

@Test
func testFleetManager_healthRatio() {
    let manager = createFleetManager("test-fleet")
    let node1 = createNode("node-1", "host1", 2552)
    let node2 = createNode("node-2", "host2", 2552)
    manager.registerNode(node1)
    manager.registerNode(node2)
    manager.nodeUp(node1)
    manager.nodeUp(node2)
    manager.updateHealth("node-1", NodeHealth.Healthy)
    manager.updateHealth("node-2", NodeHealth.Healthy)
    let ratio = manager.healthRatio()
    @Expect(ratio, 1.0)
}

// === FleetEventHandler Tests ===

class TestFleetHandler <: FleetEventHandler {
    public let joined = ArrayList<String>()
    public let up = ArrayList<String>()
    public let left = ArrayList<String>()
    public let down = ArrayList<String>()
    public let removed = ArrayList<String>()

    public func onNodeJoined(node: FleetNode): Unit {
        joined.add(node.nodeId)
    }

    public func onNodeUp(node: FleetNode): Unit {
        up.add(node.nodeId)
    }

    public func onNodeLeft(node: FleetNode): Unit {
        left.add(node.nodeId)
    }

    public func onNodeDown(node: FleetNode): Unit {
        down.add(node.nodeId)
    }

    public func onNodeRemoved(node: FleetNode): Unit {
        removed.add(node.nodeId)
    }

    public func onHealthChanged(node: FleetNode, oldHealth: NodeHealth, newHealth: NodeHealth): Unit {
        // Health change tracking
    }
}

@Test
func testFleetManager_eventHandler_nodeJoined() {
    let manager = createFleetManager("test-fleet")
    let handler = TestFleetHandler()
    manager.setEventHandler(handler)
    manager.registerNode(createNode("node-1", "host1", 2552))
    @Expect(handler.joined.size, 1)
}

@Test
func testFleetManager_eventHandler_nodeUp() {
    let manager = createFleetManager("test-fleet")
    let handler = TestFleetHandler()
    manager.setEventHandler(handler)
    let node = createNode("node-1", "host1", 2552)
    manager.registerNode(node)
    manager.nodeUp(node)
    @Expect(handler.up.size, 1)
}

@Test
func testFleetManager_eventHandler_nodeDown() {
    let manager = createFleetManager("test-fleet")
    let handler = TestFleetHandler()
    manager.setEventHandler(handler)
    let node = createNode("node-1", "host1", 2552)
    manager.registerNode(node)
    manager.nodeUp(node)
    manager.nodeDown("node-1")
    @Expect(handler.down.size, 1)
}
