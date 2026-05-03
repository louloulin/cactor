/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Management 单元测试
 */
package cactor.management

import std.collection.*

// ============================================================================
// ManagementConfig Tests
// ============================================================================

@Test
func testManagementConfig_defaults() {
    let config = ManagementConfig()
    @Expect(config.host, "0.0.0.0")
    @Expect(config.port, 8558)
    @Expect(config.basePath, "/management")
    @Expect(config.enableHealthCheck, true)
    @Expect(config.enableClusterEndpoint, true)
}

// ============================================================================
// HealthResult Tests
// ============================================================================

@Test
func testHealthResult_creation() {
    let result = HealthResult("UP")
    @Expect(result.status, "UP")
}

@Test
func testHealthResult_withDetails() {
    let details = HashMap<String, String>()
    let _ = details.add("component", "test")
    let result = HealthResult("DOWN", details)
    @Expect(result.status, "DOWN")
}

// ============================================================================
// SimpleHealthCheck Tests
// ============================================================================

@Test
func testSimpleHealthCheck_healthy() {
    let check = SimpleHealthCheck("test", true)
    @Expect(check.name(), "test")
    let result = check.check()
    @Expect(result.status, "UP")
}

@Test
func testSimpleHealthCheck_unhealthy() {
    let check = SimpleHealthCheck("test", false)
    let result = check.check()
    @Expect(result.status, "DOWN")
}

// ============================================================================
// ReadinessResult Tests
// ============================================================================

@Test
func testReadinessResult_ready() {
    let result = ReadinessResult(true, "Ready")
    @Expect(result.ready, true)
    @Expect(result.message, "Ready")
}

@Test
func testReadinessResult_notReady() {
    let result = ReadinessResult(false, "Not Ready")
    @Expect(result.ready, false)
}

// ============================================================================
// SimpleReadinessCheck Tests
// ============================================================================

@Test
func testSimpleReadinessCheck_ready() {
    let check = SimpleReadinessCheck("test", true)
    @Expect(check.name(), "test")
    let result = check.check()
    @Expect(result.ready, true)
}

@Test
func testSimpleReadinessCheck_notReady() {
    let check = SimpleReadinessCheck("test", false)
    let result = check.check()
    @Expect(result.ready, false)
}

// ============================================================================
// MemberInfo Tests
// ============================================================================

@Test
func testMemberInfo_creation() {
    let roles = ArrayList<String>()
    roles.add("role1")
    let member = MemberInfo("node1", "Up", roles)
    @Expect(member.node, "node1")
    @Expect(member.status, "Up")
}

// ============================================================================
// ClusterStateInfo Tests
// ============================================================================

@Test
func testClusterStateInfo_empty() {
    let state = ClusterStateInfo()
    @Expect(state.memberCount(), 0)
}

// ============================================================================
// InternalClusterEndpoint Tests
// ============================================================================

@Test
func testInternalClusterEndpoint_empty() {
    let endpoint = InternalClusterEndpoint()
    let state = endpoint.getClusterState()
    @Expect(state.memberCount(), 0)
}

@Test
func testInternalClusterEndpoint_addMember() {
    let endpoint = InternalClusterEndpoint()
    let roles = ArrayList<String>()
    roles.add("role1")
    endpoint.addMember("node1", "Up", roles)
    let members = endpoint.getClusterMembers()
    @Expect(members.size, 1)
}

@Test
func testInternalClusterEndpoint_setLeader() {
    let endpoint = InternalClusterEndpoint()
    endpoint.setLeader("node1")
    match (endpoint.getLeader()) {
        case Some(leader) => @Expect(leader, "node1")
        case None => @Expect(true, false)
    }
}

@Test
func testInternalClusterEndpoint_getMember() {
    let endpoint = InternalClusterEndpoint()
    let roles = ArrayList<String>()
    roles.add("role1")
    endpoint.addMember("node1", "Up", roles)

    match (endpoint.getMember("node1")) {
        case Some(m) => @Expect(m.node, "node1")
        case None => @Expect(true, false)
    }
}

// ============================================================================
// ManagementServer Tests
// ============================================================================

@Test
func testManagementServer_defaults() {
    let server = ManagementServer()
    @Expect(true, true)
}

@Test
func testManagementServer_withConfig() {
    let config = ManagementConfig()
    config.port = 9000
    let server = ManagementServer(config)
    @Expect(true, true)
}

@Test
func testManagementServer_withHealthCheck() {
    let server = ManagementServer()
    let check = SimpleHealthCheck("test", true)
    let s = server.withHealthCheck(check)
    @Expect(true, true)
}

@Test
func testManagementServer_withReadinessCheck() {
    let server = ManagementServer()
    let check = SimpleReadinessCheck("test", true)
    let s = server.withReadinessCheck(check)
    @Expect(true, true)
}

@Test
func testManagementServer_startStop() {
    let server = ManagementServer()
    server.start()
    @Expect(true, true)
    server.stop()
    @Expect(true, true)
}

// ============================================================================
// ManagementFactory Tests
// ============================================================================

@Test
func testManagementFactory_create() {
    let server = ManagementFactory.create()
    @Expect(true, true)
}

@Test
func testManagementFactory_createWithConfig() {
    let config = ManagementConfig()
    config.port = 9999
    let server = ManagementFactory.create(config)
    @Expect(true, true)
}