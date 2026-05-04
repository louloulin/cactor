/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Multi-DC 多数据中心支持单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// ============================================================================
// DatacenterId Tests
// ============================================================================

@Test
func testDatacenterId_creation() {
    let dc = DatacenterId("dc1", "us-east")
    @Expect(dc.name, "dc1")
    @Expect(dc.region, "us-east")
}

@Test
func testDatacenterId_toString() {
    let dc = DatacenterId("dc1", "us-east")
    @Expect(dc.toString() == "us-east/dc1", true)
}

@Test
func testDatacenterId_equals() {
    let dc1 = DatacenterId("dc1", "us-east")
    let dc2 = DatacenterId("dc1", "us-east")
    let dc3 = DatacenterId("dc2", "us-east")
    @Expect(dc1.equals(dc2), true)
    @Expect(dc1.equals(dc3), false)
}

// ============================================================================
// DcRole Tests
// ============================================================================

@Test
func testDcRole_values() {
    @Expect(DcRole.PrimaryDC.toString() == "PrimaryDC", true)
    @Expect(DcRole.BackupDC.toString() == "BackupDC", true)
    @Expect(DcRole.ReadOnlyDC.toString() == "ReadOnlyDC", true)
    @Expect(DcRole.Neutral.toString() == "Neutral", true)
}

// ============================================================================
// DcMemberInfo Tests
// ============================================================================

@Test
func testDcMemberInfo_creation() {
    let dc = DatacenterId("dc1", "us-east")
    let member = DcMemberInfo("node1", dc, DcRole.PrimaryDC)
    @Expect(member.nodeId, "node1")
    @Expect(member.role.toString() == "PrimaryDC", true)
    @Expect(member.isReachabl, false)
}

@Test
func testDcMemberInfo_markReachable() {
    let dc = DatacenterId("dc1", "us-east")
    let member = DcMemberInfo("node1", dc, DcRole.PrimaryDC)
    member.markReachable()
    @Expect(member.isReachabl, true)
}

@Test
func testDcMemberInfo_markUnreachable() {
    let dc = DatacenterId("dc1", "us-east")
    let member = DcMemberInfo("node1", dc, DcRole.PrimaryDC)
    member.markReachable()
    member.markUnreachable()
    @Expect(member.isReachabl, false)
}

// ============================================================================
// MultiDcConfig Tests
// ============================================================================

@Test
func testMultiDcConfig_defaultConfig() {
    let config = MultiDcConfig.defaultConfig()
    @Expect(config.enabled, true)
    @Expect(config.primaryDC == "dc1", true)
    @Expect(config.crossDcReplication, true)
    @Expect(config.dcAwareRouting, true)
}

@Test
func testMultiDcConfig_toString() {
    let config = MultiDcConfig.defaultConfig()
    let s = config.toString()
    @Expect(s.size > 0, true)
}

// ============================================================================
// DcMembershipManager Tests
// ============================================================================

@Test
func testDcMembershipManager_addMember() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    let members = manager.getAllMembers()
    @Expect(members.size, 1)
}

@Test
func testDcMembershipManager_removeMember() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    manager.removeMember("node1")
    let members = manager.getAllMembers()
    @Expect(members.size, 0)
}

@Test
func testDcMembershipManager_getMembersInDc() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc1 = DatacenterId("dc1", "us-east")
    let dc2 = DatacenterId("dc2", "us-west")

    manager.addMember("node1", dc1, DcRole.PrimaryDC)
    manager.addMember("node2", dc1, DcRole.PrimaryDC)
    manager.addMember("node3", dc2, DcRole.BackupDC)

    let dc1Members = manager.getMembersInDc("dc1")
    let dc2Members = manager.getMembersInDc("dc2")
    @Expect(dc1Members.size, 2)
    @Expect(dc2Members.size, 1)
}

@Test
func testDcMembershipManager_getPrimaryDCMembers() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc1 = DatacenterId("dc1", "us-east")
    let dc2 = DatacenterId("dc2", "us-west")

    manager.addMember("node1", dc1, DcRole.PrimaryDC)
    manager.addMember("node2", dc2, DcRole.BackupDC)

    let primaryMembers = manager.getPrimaryDCMembers()
    @Expect(primaryMembers.size, 1)
}

@Test
func testDcMembershipManager_getDatacenters() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc1 = DatacenterId("dc1", "us-east")
    let dc2 = DatacenterId("dc2", "us-west")

    manager.addMember("node1", dc1, DcRole.PrimaryDC)
    manager.addMember("node2", dc2, DcRole.BackupDC)

    let dcs = manager.getDatacenters()
    @Expect(dcs.size, 2)
}

@Test
func testDcMembershipManager_getMemberCount() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    manager.addMember("node2", dc, DcRole.PrimaryDC)

    let count = manager.getMemberCount("dc1")
    @Expect(count, 2)
}

@Test
func testDcMembershipManager_updateHeartbeat() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    manager.updateHeartbeat("node1")

    @Expect(manager.isMemberReachable("node1"), true)
}

@Test
func testDcMembershipManager_markUnreachable() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    manager.updateHeartbeat("node1")
    manager.markUnreachable("node1")

    @Expect(manager.isMemberReachable("node1"), false)
}

@Test
func testDcMembershipManager_getReachableMembers() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    manager.addMember("node2", dc, DcRole.PrimaryDC)
    manager.updateHeartbeat("node1")
    // node2 is not reachable

    let reachable = manager.getReachableMembers()
    @Expect(reachable.size, 1)
}

// ============================================================================
// DcRoutingStrategy Tests
// ============================================================================

@Test
func testDcRoutingStrategy_values() {
    @Expect(DcRoutingStrategy.LocalDCFirst.toString() == "LocalDCFirst", true)
    @Expect(DcRoutingStrategy.PrimaryDCOnly.toString() == "PrimaryDCOnly", true)
    @Expect(DcRoutingStrategy.AllDCs.toString() == "AllDCs", true)
    @Expect(DcRoutingStrategy.RoundRobinAcrossDCs.toString() == "RoundRobinAcrossDCs", true)
}

// ============================================================================
// DcAwareRouter Tests
// ============================================================================

@Test
func testDcAwareRouter_selectLocalDcFirst() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc1 = DatacenterId("dc1", "us-east")
    let dc2 = DatacenterId("dc2", "us-west")

    manager.addMember("node1", dc1, DcRole.PrimaryDC)
    manager.addMember("node2", dc2, DcRole.BackupDC)
    manager.updateHeartbeat("node1")
    manager.updateHeartbeat("node2")

    let router = DcAwareRouter(manager, DcRoutingStrategy.LocalDCFirst)
    let target = router.selectTarget("dc1")

    match (target) {
        case Some(t) => @Expect(t.nodeId == "node1", true)
        case None => @Expect(false, true)
    }
}

@Test
func testDcAwareRouter_selectPrimaryDcOnly() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc1 = DatacenterId("dc1", "us-east")
    let dc2 = DatacenterId("dc2", "us-west")

    manager.addMember("node1", dc1, DcRole.PrimaryDC)
    manager.addMember("node2", dc2, DcRole.BackupDC)
    manager.updateHeartbeat("node1")
    manager.updateHeartbeat("node2")

    let router = DcAwareRouter(manager, DcRoutingStrategy.PrimaryDCOnly)
    let target = router.selectTarget("dc2")

    match (target) {
        case Some(t) => @Expect(t.nodeId == "node1", true)
        case None => @Expect(false, true)
    }
}

@Test
func testDcAwareRouter_selectTargets() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc, DcRole.PrimaryDC)
    manager.addMember("node2", dc, DcRole.PrimaryDC)
    manager.updateHeartbeat("node1")
    manager.updateHeartbeat("node2")

    let router = DcAwareRouter(manager, DcRoutingStrategy.LocalDCFirst)
    let targets = router.selectTargets("dc1", 2)

    @Expect(targets.size, 2)
}

// ============================================================================
// DcFailoverManager Tests
// ============================================================================

@Test
func testDcFailoverManager_shouldFailover_noFailover() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let dc1 = DatacenterId("dc1", "us-east")

    manager.addMember("node1", dc1, DcRole.PrimaryDC)

    let failoverManager = DcFailoverManager(config, manager)
    @Expect(failoverManager.shouldFailover(), false)
}

@Test
func testDcFailoverManager_isPrimaryDCAvailable() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let failoverManager = DcFailoverManager(config, manager)

    @Expect(failoverManager.isPrimaryDCAvailable(), true)
}

@Test
func testDcFailoverManager_getActiveDC() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let failoverManager = DcFailoverManager(config, manager)

    let activeDC = failoverManager.getActiveDC()
    @Expect(activeDC == "dc1", true)
}

@Test
func testDcFailoverManager_recoverPrimaryDC() {
    let config = MultiDcConfig.defaultConfig()
    let manager = DcMembershipManager(config)
    let failoverManager = DcFailoverManager(config, manager)

    failoverManager.recoverPrimaryDC()
    @Expect(failoverManager.isPrimaryDCAvailable(), true)
}
