/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Failover 单元测试
 */
package cactor.distribution.cluster

import std.time.*

// === NodeHealthInfo Tests ===

@Test
func testNodeHealthInfo_creation() {
    let now = DateTime.now()
    let info = NodeHealthInfo(now, true)

    match (info.lastHeartbeat) {
        case t where t == now => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    @Expect(info.isHealthy, true)
}

@Test
func testNodeHealthInfo_healthy() {
    let now = DateTime.now()
    let info = NodeHealthInfo(now, true)

    @Expect(info.isHealthy, true)
}

@Test
func testNodeHealthInfo_unhealthy() {
    let now = DateTime.now()
    let info = NodeHealthInfo(now, false)

    @Expect(info.isHealthy, false)
}

@Test
func testNodeHealthInfo_toString() {
    let now = DateTime.now()
    let info = NodeHealthInfo(now, true)
    let str = info.toString()

    @Expect(str.contains("NodeHealthInfo"), true)
    @Expect(str.contains("isHealthy=true"), true)
}

// === FailoverStrategy Tests ===

@Test
func testFailoverStrategy_values() {
    let strategies = [
        FailoverStrategy.NoFailover,
        FailoverStrategy.RestartOnSameNode,
        FailoverStrategy.MigrateToOtherNode,
        FailoverStrategy.ReplicateToMultipleNodes
    ]
    let count = strategies.size
    @Expect(count, 4)
}

@Test
func testFailoverStrategy_toString() {
    let noFailover = FailoverStrategy.NoFailover
    @Expect(noFailover.toString(), "NoFailover")

    let restart = FailoverStrategy.RestartOnSameNode
    @Expect(restart.toString(), "RestartOnSameNode")

    let migrate = FailoverStrategy.MigrateToOtherNode
    @Expect(migrate.toString(), "MigrateToOtherNode")

    let replicate = FailoverStrategy.ReplicateToMultipleNodes
    @Expect(replicate.toString(), "ReplicateToMultipleNodes")
}

@Test
func testFailoverStrategy_match() {
    let strategy = FailoverStrategy.NoFailover
    var result = ""
    match (strategy) {
        case FailoverStrategy.NoFailover => result = "NoFailover"
        case FailoverStrategy.RestartOnSameNode => result = "Restart"
        case FailoverStrategy.MigrateToOtherNode => result = "Migrate"
        case FailoverStrategy.ReplicateToMultipleNodes => result = "Replicate"
    }
    @Expect(result, "NoFailover")
}

@Test
func testFailoverStrategy_allCases() {
    var results = ""
    match (FailoverStrategy.NoFailover) {
        case FailoverStrategy.NoFailover => results += "A"
        case _ => results += "?"
    }
    match (FailoverStrategy.RestartOnSameNode) {
        case FailoverStrategy.RestartOnSameNode => results += "B"
        case _ => results += "?"
    }
    match (FailoverStrategy.MigrateToOtherNode) {
        case FailoverStrategy.MigrateToOtherNode => results += "C"
        case _ => results += "?"
    }
    match (FailoverStrategy.ReplicateToMultipleNodes) {
        case FailoverStrategy.ReplicateToMultipleNodes => results += "D"
        case _ => results += "?"
    }
    @Expect(results, "ABCD")
}

// === NodeState Tests ===

@Test
func testFailoverNodeState_values() {
    let now = DateTime.now()
    let states = [
        NodeState.Up(now),
        NodeState.Down(now),
        NodeState.Leaving(now),
        NodeState.Joining(now),
        NodeState.Failed(now)
    ]
    let count = states.size
    @Expect(count, 5)
}

@Test
func testFailoverNodeState_toString() {
    let now = DateTime.now()
    let upStr = NodeState.Up(now).toString()
    let downStr = NodeState.Down(now).toString()
    let leavingStr = NodeState.Leaving(now).toString()
    let joiningStr = NodeState.Joining(now).toString()
    let failedStr = NodeState.Failed(now).toString()

    @Expect(upStr.contains("Up"), true)
    @Expect(downStr.contains("Down"), true)
    @Expect(leavingStr.contains("Leaving"), true)
    @Expect(joiningStr.contains("Joining"), true)
    @Expect(failedStr.contains("Failed"), true)
}

@Test
func testFailoverNodeState_isAvailable() {
    let now = DateTime.now()
    let up = NodeState.Up(now)
    let down = NodeState.Down(now)

    @Expect(up.isAvailable(), true)
    @Expect(down.isAvailable(), false)
}

// === Address Tests ===

@Test
func testFailoverAddress_creation() {
    let addr = Address("cactor", "testSystem", "localhost", 2552)

    @Expect(addr.protocol, "cactor")
    @Expect(addr.system, "testSystem")
    @Expect(addr.port, 2552)
}

@Test
func testFailoverAddress_toString() {
    let addr = Address("cactor", "sys", "node1.local", 2552)
    let str = addr.toString()

    @Expect(str.contains("cactor"), true)
    @Expect(str.contains("node1.local"), true)
    @Expect(str.contains("2552"), true)
}

@Test
func testFailoverAddress_equals() {
    let addr1 = Address("cactor", "sys", "localhost", 2552)
    let addr2 = Address("cactor", "sys", "localhost", 2552)
    let addr3 = Address("cactor", "sys", "localhost", 2553)

    @Expect(addr1.equals(addr2), true)
    @Expect(addr1.equals(addr3), false)
}

// === UniqueAddress Tests ===

@Test
func testFailoverUniqueAddress_creation() {
    let addr = Address("cactor", "sys", "node1", 2552)
    let uniqueAddr = UniqueAddress(addr, 12345)

    @Expect(uniqueAddr.uid, 12345)
    @Expect(uniqueAddr.address.protocol, "cactor")
}

@Test
func testFailoverUniqueAddress_toString() {
    let addr = Address("cactor", "sys", "node1", 2552)
    let uniqueAddr = UniqueAddress(addr, 1)
    let str = uniqueAddr.toString()

    @Expect(str.contains("cactor"), true)
    @Expect(str.contains("1"), true)
}

@Test
func testFailoverUniqueAddress_equals() {
    let addr1 = Address("cactor", "sys", "node1", 2552)
    let addr2 = Address("cactor", "sys", "node1", 2552)
    let uniqueAddr1 = UniqueAddress(addr1, 1)
    let uniqueAddr2 = UniqueAddress(addr2, 1)
    let uniqueAddr3 = UniqueAddress(addr2, 2)

    @Expect(uniqueAddr1.equals(uniqueAddr2), true)
    @Expect(uniqueAddr1.equals(uniqueAddr3), false)
}

@Test
func testFailoverUniqueAddress_hashCode() {
    let addr = Address("cactor", "sys", "node1", 2552)
    let uniqueAddr = UniqueAddress(addr, 42)

    // hashCode should be a computed value, not just uid
    // Just verify it's consistent (same input gives same output)
    let hash1 = uniqueAddr.hashCode()
    let hash2 = uniqueAddr.hashCode()
    @Expect(hash1, hash2)
    // Also verify different instances have different hashes
    let addr2 = Address("cactor", "sys", "node2", 2552)
    let uniqueAddr2 = UniqueAddress(addr2, 42)
    let hash3 = uniqueAddr2.hashCode()
    @Expect(hash1 != hash3, true)
}

// === Simple Integration Tests ===

@Test
func testNodeHealthInfo_differentStates() {
    let now = DateTime.now()

    let healthy = NodeHealthInfo(now, true)
    let unhealthy = NodeHealthInfo(now, false)

    @Expect(healthy.isHealthy, true)
    @Expect(unhealthy.isHealthy, false)
}

@Test
func testFailoverStrategy_defaultBehavior() {
    let noFailover = FailoverStrategy.NoFailover
    let restart = FailoverStrategy.RestartOnSameNode
    let migrate = FailoverStrategy.MigrateToOtherNode
    let replicate = FailoverStrategy.ReplicateToMultipleNodes

    // All strategies should have string representation
    @Expect(noFailover.toString().size > 0, true)
    @Expect(restart.toString().size > 0, true)
    @Expect(migrate.toString().size > 0, true)
    @Expect(replicate.toString().size > 0, true)
}

@Test
func testFailoverNodeState_allStates() {
    let now = DateTime.now()
    // Test all node states can be matched
    var results = ""
    match (NodeState.Up(now)) {
        case NodeState.Up(_) => results += "A"
        case _ => results += "?"
    }
    match (NodeState.Down(now)) {
        case NodeState.Down(_) => results += "B"
        case _ => results += "?"
    }
    match (NodeState.Leaving(now)) {
        case NodeState.Leaving(_) => results += "C"
        case _ => results += "?"
    }
    match (NodeState.Joining(now)) {
        case NodeState.Joining(_) => results += "D"
        case _ => results += "?"
    }
    match (NodeState.Failed(now)) {
        case NodeState.Failed(_) => results += "E"
        case _ => results += "?"
    }
    @Expect(results, "ABCDE")
}
