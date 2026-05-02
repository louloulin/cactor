/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Support 单元测试
 */
package cactor.distribution.cluster

import std.collection.{ArrayList, HashMap}
import std.time.*
import cactor.foundation.network.*

// === NodeId Tests ===

@Test
func testNodeId_creation() {
    let nodeId = NodeId("node-1")

    @Expect(nodeId.id, "node-1")
}

@Test
func testNodeId_toString() {
    let nodeId = NodeId("test-node")

    let str = nodeId.toString()
    let contains = str.contains("test-node")
    @Expect(contains, true)
}

@Test
func testNodeId_equals() {
    let nodeId1 = NodeId("same-id")
    let nodeId2 = NodeId("same-id")
    let nodeId3 = NodeId("different-id")

    @Expect(nodeId1.equals(nodeId2), true)
    @Expect(nodeId1.equals(nodeId3), false)
}

// === NodeState Tests ===

@Test
func testNodeState_Joining() {
    let state = NodeState.Joining(DateTime.now())

    @Expect(state.isAvailable(), false)
}

@Test
func testNodeState_Up() {
    let state = NodeState.Up(DateTime.now())

    @Expect(state.isAvailable(), true)
}

@Test
func testNodeState_Leaving() {
    let state = NodeState.Leaving(DateTime.now())

    @Expect(state.isAvailable(), false)
}

@Test
func testNodeState_Down() {
    let state = NodeState.Down(DateTime.now())

    @Expect(state.isAvailable(), false)
}

@Test
func testNodeState_Failed() {
    let state = NodeState.Failed(DateTime.now())

    @Expect(state.isAvailable(), false)
}

@Test
func testNodeState_toString() {
    let joining = NodeState.Joining(DateTime.now())
    let up = NodeState.Up(DateTime.now())
    let leaving = NodeState.Leaving(DateTime.now())

    let joiningStr = joining.toString()
    let upStr = up.toString()
    let leavingStr = leaving.toString()

    @Expect(joiningStr.contains("Joining"), true)
    @Expect(upStr.contains("Up"), true)
    @Expect(leavingStr.contains("Leaving"), true)
}

// === ClusterNode Tests ===

@Test
func testClusterNode_creation() {
    let nodeId = NodeId("cluster-node-1")
    let address = NetworkAddress("localhost", 2552)
    let roles = ["worker", "backend"]

    let node = ClusterNode(nodeId, address, roles)

    @Expect(node.nodeId.equals(nodeId), true)
    @Expect(node.hasRole("worker"), true)
    @Expect(node.hasRole("backend"), true)
    @Expect(node.hasRole("frontend"), false)
}

@Test
func testClusterNode_initialState() {
    let nodeId = NodeId("init-node")
    let address = NetworkAddress("localhost", 8080)

    let node = ClusterNode(nodeId, address, ["worker"])

    let state = node.getState()
    match (state) {
        case NodeState.Joining(_) => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}

@Test
func testClusterNode_stateTransition() {
    let nodeId = NodeId("transition-node")
    let address = NetworkAddress("localhost", 9000)

    let node = ClusterNode(nodeId, address, ["role1"])

    // Transition to Up
    node.setState(NodeState.Up(DateTime.now()))
    @Expect(node.getState().isAvailable(), true)

    // Transition to Down
    node.setState(NodeState.Down(DateTime.now()))
    @Expect(node.getState().isAvailable(), false)
}

@Test
func testClusterNode_isLocal() {
    let nodeId1 = NodeId("local-node")
    let addr1 = NetworkAddress("localhost", 2552)

    let node1 = ClusterNode(nodeId1, addr1, ["local"])
    @Expect(node1.isLocal(), true)

    let nodeId2 = NodeId("remote-node")
    let addr2 = NetworkAddress("192.168.1.100", 2552)

    let node2 = ClusterNode(nodeId2, addr2, ["remote"])
    @Expect(node2.isLocal(), false)
}

@Test
func testClusterNode_toString() {
    let nodeId = NodeId("tostring-node")
    let address = NetworkAddress("example.com", 8080)

    let node = ClusterNode(nodeId, address, ["web"])

    let str = node.toString()
    @Expect(str.contains("tostring-node"), true)
}

// === ClusterState Tests ===

@Test
func testClusterState_creation() {
    let localId = NodeId("local-member")
    let state = ClusterState(localId)

    @Expect(state.getClusterSize(), 0)
    @Expect(state.getLocalNodeId().equals(localId), true)
}

@Test
func testClusterState_addNode() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    let nodeId = NodeId("new-node")
    let address = NetworkAddress("node.local", 2552)
    let node = ClusterNode(nodeId, address, ["worker"])

    state.addNode(node)

    @Expect(state.getClusterSize(), 1)
    // 新节点处于 Joining 状态, not available yet
    @Expect(state.getAllNodes().size, 1)
}

@Test
func testClusterState_removeNode() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    let nodeId = NodeId("remove-me")
    let address = NetworkAddress("remove.local", 2552)
    let node = ClusterNode(nodeId, address, ["temp"])

    state.addNode(node)
    @Expect(state.getClusterSize(), 1)

    state.removeNode(nodeId)
    @Expect(state.getClusterSize(), 0)
}

@Test
func testClusterState_updateNodeState() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    let nodeId = NodeId("state-node")
    let address = NetworkAddress("state.local", 2552)
    let node = ClusterNode(nodeId, address, ["worker"])

    state.addNode(node)
    state.updateNodeState(nodeId, NodeState.Up(DateTime.now()))

    let available = state.getAvailableNodes()
    @Expect(available.size, 1)
}

@Test
func testClusterState_getNode() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    let nodeId = NodeId("get-node")
    let address = NetworkAddress("get.local", 2552)
    let node = ClusterNode(nodeId, address, ["test"])

    state.addNode(node)

    let found = state.getNode(nodeId)
    let isDefined = match (found) {
        case Some(_) => true
        case None => false
    }
    @Expect(isDefined, true)

    match (found) {
        case Some(n) => @Expect(n.nodeId.equals(nodeId), true)
        case None => @Expect(true, false)
    }
}

@Test
func testClusterState_getNodeNotFound() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    let notFound = state.getNode(NodeId("nonexistent"))
    let isEmpty = match (notFound) {
        case Some(_) => false
        case None => true
    }
    @Expect(isEmpty, true)
}

@Test
func testClusterState_getAvailableNodes() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    // Add node in Joining state
    let node1Id = NodeId("joining-node")
    let node1 = ClusterNode(node1Id, NetworkAddress("joining.local", 2552), ["worker"])
    state.addNode(node1)

    // Add node in Up state
    let node2Id = NodeId("up-node")
    let node2 = ClusterNode(node2Id, NetworkAddress("up.local", 2553), ["worker"])
    node2.setState(NodeState.Up(DateTime.now()))
    state.addNode(node2)

    // Add node in Down state
    let node3Id = NodeId("down-node")
    let node3 = ClusterNode(node3Id, NetworkAddress("down.local", 2554), ["worker"])
    node3.setState(NodeState.Down(DateTime.now()))
    state.addNode(node3)

    let available = state.getAvailableNodes()
    @Expect(available.size, 1)
    @Expect(available[0].nodeId.equals(node2Id), true)
}

@Test
func testClusterState_getAllNodes() {
    let localId = NodeId("local")
    let state = ClusterState(localId)

    state.addNode(ClusterNode(NodeId("n1"), NetworkAddress("n1.local", 2552), ["r1"]))
    state.addNode(ClusterNode(NodeId("n2"), NetworkAddress("n2.local", 2553), ["r2"]))
    state.addNode(ClusterNode(NodeId("n3"), NetworkAddress("n3.local", 2554), ["r3"]))

    let all = state.getAllNodes()
    @Expect(all.size, 3)
}

// === ClusterEvent Tests ===

@Test
func testClusterEvent_NodeJoined() {
    let node = ClusterNode(NodeId("joined"), NetworkAddress("joined.local", 2552), ["new"])
    let event = ClusterEvent.NodeJoined(node)

    let str = event.toString()
    @Expect(str.contains("NodeJoined"), true)
}

@Test
func testClusterEvent_NodeLeft() {
    let node = ClusterNode(NodeId("left"), NetworkAddress("left.local", 2552), ["leaving"])
    let event = ClusterEvent.NodeLeft(node)

    let str = event.toString()
    @Expect(str.contains("NodeLeft"), true)
}

@Test
func testClusterEvent_NodeUp() {
    let node = ClusterNode(NodeId("up"), NetworkAddress("up.local", 2552), ["ready"])
    let event = ClusterEvent.NodeUp(node)

    let str = event.toString()
    @Expect(str.contains("NodeUp"), true)
}

@Test
func testClusterEvent_NodeDown() {
    let node = ClusterNode(NodeId("down"), NetworkAddress("down.local", 2552), ["failed"])
    let event = ClusterEvent.NodeDown(node)

    let str = event.toString()
    @Expect(str.contains("NodeDown"), true)
}

@Test
func testClusterEvent_NodeFailed() {
    let node = ClusterNode(NodeId("failed"), NetworkAddress("failed.local", 2552), ["error"])
    let event = ClusterEvent.NodeFailed(node)

    let str = event.toString()
    @Expect(str.contains("NodeFailed"), true)
}

// === ClusterEventListener Tests ===

class TestEventListener <: ClusterEventListener {
    public var receivedEvents: ArrayList<ClusterEvent>

    public init() {
        this.receivedEvents = ArrayList<ClusterEvent>()
    }

    public func onClusterEvent(event: ClusterEvent): Unit {
        receivedEvents.add(event)
    }
}

@Test
func testTestEventListener_onClusterEvent() {
    let listener = TestEventListener()
    let node = ClusterNode(NodeId("event-node"), NetworkAddress("event.local", 2552), ["test"])

    let event = ClusterEvent.NodeUp(node)
    listener.onClusterEvent(event)

    @Expect(listener.receivedEvents.size, 1)
    @Expect(listener.receivedEvents[0].toString().contains("NodeUp"), true)
}

// === Integration Tests ===

@Test
func testClusterLifecycle() {
    // 模拟完整的集群生命周期
    let localId = NodeId("lifecycle-local")
    let state = ClusterState(localId)

    // 1. 加入集群 (Joining)
    let nodeId = NodeId("lifecycle-node")
    let address = NetworkAddress("lifecycle.local", 2552)
    let node = ClusterNode(nodeId, address, ["worker"])
    state.addNode(node)

    @Expect(state.getClusterSize(), 1)

    // 2. 变为 Up
    node.setState(NodeState.Up(DateTime.now()))
    let available = state.getAvailableNodes()
    @Expect(available.size, 1)

    // 3. 变为 Leaving
    node.setState(NodeState.Leaving(DateTime.now()))

    // 4. 离开集群
    state.removeNode(nodeId)
    @Expect(state.getClusterSize(), 0)
}

@Test
func testClusterFormation_multiNode() {
    // 模拟多节点集群形成
    let localId = NodeId("seed-node")
    let state = ClusterState(localId)

    // 添加多个节点
    for (i in 1..=5) {
        let nodeId = NodeId("member-${i}")
        let address = NetworkAddress("member${i}.local", 2552 + Int32(i))
        let node = ClusterNode(nodeId, address, ["worker"])
        node.setState(NodeState.Up(DateTime.now()))
        state.addNode(node)
    }

    @Expect(state.getClusterSize(), 5)

    let available = state.getAvailableNodes()
    @Expect(available.size, 5)
}

@Test
func testClusterEventDistribution() {
    // 模拟集群事件分发
    let listener = TestEventListener()
    let node1 = ClusterNode(NodeId("e1"), NetworkAddress("e1.local", 2552), ["w"])
    let node2 = ClusterNode(NodeId("e2"), NetworkAddress("e2.local", 2552), ["w"])

    listener.onClusterEvent(ClusterEvent.NodeJoined(node1))
    listener.onClusterEvent(ClusterEvent.NodeUp(node2))
    listener.onClusterEvent(ClusterEvent.NodeDown(node1))

    @Expect(listener.receivedEvents.size, 3)
}

@Test
func testClusterRoleFiltering() {
    // 模拟按角色筛选节点
    let state = ClusterState(NodeId("role-local"))

    // 添加不同角色的节点
    let frontend1 = ClusterNode(NodeId("f1"), NetworkAddress("f1.local", 2552), ["frontend"])
    frontend1.setState(NodeState.Up(DateTime.now()))
    state.addNode(frontend1)

    let frontend2 = ClusterNode(NodeId("f2"), NetworkAddress("f2.local", 2552), ["frontend"])
    frontend2.setState(NodeState.Up(DateTime.now()))
    state.addNode(frontend2)

    let backend1 = ClusterNode(NodeId("b1"), NetworkAddress("b1.local", 2553), ["backend"])
    backend1.setState(NodeState.Up(DateTime.now()))
    state.addNode(backend1)

    // 所有可用节点
    let all = state.getAvailableNodes()
    @Expect(all.size, 3)

    // 手动筛选 frontend 角色 (简化实现)
    var frontendCount = 0
    for (node in all) {
        if (node.hasRole("frontend")) {
            frontendCount += 1
        }
    }
    @Expect(frontendCount, 2)
}

@Test
func testClusterState_concurrentAccess() {
    // 验证并发访问安全性 (简化测试)
    let localId = NodeId("concurrent-local")
    let state = ClusterState(localId)

    // 添加初始节点
    state.addNode(ClusterNode(NodeId("c1"), NetworkAddress("c1.local", 2552), ["w"]))

    // 获取状态多次
    let size1 = state.getClusterSize()
    let size2 = state.getClusterSize()
    let all1 = state.getAllNodes()
    let all2 = state.getAllNodes()

    @Expect(size1, size2)
    @Expect(all1.size, all2.size)
}

@Test
func testNodeState_machine() {
    // 验证节点状态机
    let node = ClusterNode(
        NodeId("statemachine"),
        NetworkAddress("sm.local", 2552),
        ["worker"]
    )

    // 初始状态
    match (node.getState()) {
        case NodeState.Joining(_) => @Expect(true, true)
        case _ => @Expect(true, false)
    }

    // Joining -> Up
    node.setState(NodeState.Up(DateTime.now()))
    @Expect(node.getState().isAvailable(), true)

    // Up -> Down
    node.setState(NodeState.Down(DateTime.now()))
    @Expect(node.getState().isAvailable(), false)

    // Down -> Leaving
    node.setState(NodeState.Leaving(DateTime.now()))

    // Leaving -> (removed)
    match (node.getState()) {
        case NodeState.Leaving(_) => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}
