/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - HA 分片协调器单元测试
 */
package cactor.distribution.cluster

import std.time.*
import std.collection.*
import cactor.core.actor.ActorPath

// === Test Helper ===

class TestEventHandler <: ShardCoordinatorEventHandler {
    public let stateChanges = ArrayList<(String, String)>()
    public let allocations = ArrayList<(String, String)>()
    public let rebalances = ArrayList<Int64>()

    public func onCoordinatorStateChange(oldState: CoordinatorState, newState: CoordinatorState): Unit {
        stateChanges.add((oldState.toString(), newState.toString()))
    }

    public func onShardAllocated(shardId: String, nodeAddress: Address): Unit {
        allocations.add((shardId, nodeAddress.toString()))
    }

    public func onShardDeallocated(shardId: String): Unit {
        println("Deallocated: ${shardId}")
    }

    public func onRebalanceRequired(shardIds: Array<String>): Unit {
        rebalances.add(Int64(shardIds.size))
    }
}

// === CoordinatorState Tests ===

@Test
func testCoordinatorState_creation() {
    let state = CoordinatorState.INACTIVE
    @Expect(state.toString(), "INACTIVE")
}

@Test
func testCoordinatorState_activating() {
    let state = CoordinatorState.ACTIVATING
    @Expect(state.toString(), "ACTIVATING")
    @Expect(state.isActive(), false)
}

@Test
func testCoordinatorState_active() {
    let state = CoordinatorState.ACTIVE
    @Expect(state.toString(), "ACTIVE")
    @Expect(state.isActive(), true)
}

@Test
func testCoordinatorState_passive() {
    let state = CoordinatorState.PASSIVE
    @Expect(state.toString(), "PASSIVE")
    @Expect(state.isActive(), false)
}

// === HAShardCoordinator Tests ===

@Test
func testHAShardCoordinator_creation() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)

    @Expect(coordinator.isLeaderNode(), false)
    @Expect(coordinator.getState().toString(), "INACTIVE")
}

@Test
func testHAShardCoordinator_start() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    let handler = TestEventHandler()
    coordinator.setEventHandler(handler)

    coordinator.start()

    @Expect(coordinator.isLeaderNode(), true)
    @Expect(coordinator.getState().toString(), "ACTIVE")
    @Expect(handler.stateChanges.size, 1)
}

@Test
func testHAShardCoordinator_allocateShard() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    let handler = TestEventHandler()
    coordinator.setEventHandler(handler)
    coordinator.start()

    let node1 = Address("cactor", "test-system", "node1", 2552)
    coordinator.allocateShard("shard-1", node1)
    coordinator.allocateShard("shard-2", node1)

    let location = coordinator.getShardLocation("shard-1")
    @Expect(location.isSome(), true)

    let stats = coordinator.getStats()
    @Expect(stats.totalShards, 2)
}

@Test
func testHAShardCoordinator_allocateToMultipleNodes() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    coordinator.start()

    let node1 = Address("cactor", "test-system", "node1", 2552)
    let node2 = Address("cactor", "test-system", "node2", 2552)
    let node3 = Address("cactor", "test-system", "node3", 2552)

    coordinator.allocateShard("shard-1", node1)
    coordinator.allocateShard("shard-2", node1)
    coordinator.allocateShard("shard-3", node2)
    coordinator.allocateShard("shard-4", node3)

    let allocs = coordinator.getAllAllocations()
    @Expect(allocs.size, 4)

    let nodeMap = coordinator.getNodeShardMap()
    @Expect(nodeMap.size, 3)
}

@Test
func testHAShardCoordinator_getShardCount() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    coordinator.start()

    let node1 = Address("cactor", "test-system", "node1", 2552)
    let node2 = Address("cactor", "test-system", "node2", 2552)

    coordinator.allocateShard("shard-1", node1)
    coordinator.allocateShard("shard-2", node1)
    coordinator.allocateShard("shard-3", node2)

    @Expect(coordinator.getShardCount(node1), 2)
    @Expect(coordinator.getShardCount(node2), 1)
}

@Test
func testHAShardCoordinator_updateShardLocation() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    coordinator.start()

    let node1 = Address("cactor", "test-system", "node1", 2552)
    let node2 = Address("cactor", "test-system", "node2", 2552)

    coordinator.allocateShard("shard-1", node1)
    coordinator.updateShardLocation("shard-1", node2)

    let location = coordinator.getShardLocation("shard-1")
    @Expect(location.isSome(), true)
}

@Test
func testHAShardCoordinator_removeNode() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    let handler = TestEventHandler()
    coordinator.setEventHandler(handler)
    coordinator.start()

    let node1 = Address("cactor", "test-system", "node1", 2552)

    coordinator.allocateShard("shard-1", node1)
    coordinator.allocateShard("shard-2", node1)

    coordinator.removeNode(node1)

    let stats = coordinator.getStats()
    @Expect(stats.totalShards, 0)
}

@Test
func testHAShardCoordinator_getStats() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    coordinator.start()

    let node1 = Address("cactor", "test-system", "node1", 2552)
    let node2 = Address("cactor", "test-system", "node2", 2552)

    coordinator.allocateShard("shard-1", node1)
    coordinator.allocateShard("shard-2", node1)
    coordinator.allocateShard("shard-3", node2)

    let stats = coordinator.getStats()
    @Expect(stats.totalShards, 3)
    @Expect(stats.totalNodes, 2)
    @Expect(stats.isLeader, true)
}

@Test
func testHAShardCoordinator_stop() {
    let address = Address("cactor", "test-system", "localhost", 2552)
    let coordinator = createHAShardCoordinator(address)
    let handler = TestEventHandler()
    coordinator.setEventHandler(handler)
    coordinator.start()

    coordinator.stop()

    @Expect(coordinator.isLeaderNode(), false)
    @Expect(coordinator.getState().toString(), "INACTIVE")
}

// === CoordinatorStats Tests ===

@Test
func testCoordinatorStats_toString() {
    let stats = CoordinatorStats(10, 3, 3, true)
    let str = stats.toString()

    @Expect(str.contains("10"), true)
    @Expect(str.contains("3"), true)
}