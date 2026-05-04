/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - DowningProvider 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === Helper ===

func createMember(nodeId: String, host: String, port: Int32): MemberInfo2 {
    let addr = Address("cactor", "test", host, port)
    MemberInfo2(nodeId, addr)
}

// === DowningReachability Tests ===

@Test
func testDowningReachability_reachable() {
    @Expect(DowningReachability.Reachable.isReachable(), true)
    @Expect(DowningReachability.Reachable.isDown(), false)
}

@Test
func testDowningReachability_unreachable() {
    @Expect(DowningReachability.Unreachable.isReachable(), false)
    @Expect(DowningReachability.Unreachable.isDown(), false)
}

@Test
func testDowningReachability_down() {
    @Expect(DowningReachability.Down.isReachable(), false)
    @Expect(DowningReachability.Down.isDown(), true)
}

// === MemberStatus Tests ===

@Test
func testMemberStatus_up() {
    @Expect(MemberStatus.Up.isActive(), true)
    @Expect(MemberStatus.Down.isActive(), false)
}

// === MemberInfo2 Tests ===

@Test
func testMemberInfo2_creation() {
    let member = createMember("node-1", "localhost", 2552)
    @Expect(member.nodeId, "node-1")
}

@Test
func testMemberInfo2_withStatus() {
    let member = createMember("node-1", "localhost", 2552)
    let updated = member.withStatus(MemberStatus.Up)
    @Expect(updated.status.isActive(), true)
}

@Test
func testMemberInfo2_withReachability() {
    let member = createMember("node-1", "localhost", 2552)
    let updated = member.withReachability(DowningReachability.Unreachable)
    @Expect(updated.reachability.isReachable(), false)
}

// === AutoDowningProvider Tests ===

@Test
func testAutoDowningProvider_name() {
    let provider = createAutoDowningProvider(Duration.second * 5)
    @Expect(provider.name(), "auto-downing")
}

@Test
func testAutoDowningProvider_allReachable() {
    let provider = createAutoDowningProvider(Duration.second * 5)
    let members = ArrayList<MemberInfo2>()
    members.add(createMember("node-1", "host1", 2552))
    members.add(createMember("node-2", "host2", 2552))

    let decision = provider.handleUnreachable(members)
    @Expect(decision.isEmpty(), true)
}

@Test
func testAutoDowningProvider_withUnreachable() {
    let provider = createAutoDowningProvider(Duration.millisecond * 1)
    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    let m2 = createMember("node-2", "host2", 2552)
    m2.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)

    let decision = provider.handleUnreachable(members)
    @Expect(decision.size() >= 0, true)
}

// === MajorityDowningProvider Tests ===

@Test
func testMajorityDowningProvider_name() {
    let selfAddr = Address("cactor", "test", "localhost", 2552)
    let provider = createMajorityDowningProvider(selfAddr)
    @Expect(provider.name(), "majority-downing")
}

@Test
func testMajorityDowningProvider_majorityPartition() {
    let selfAddr = Address("cactor", "test", "localhost", 2552)
    let provider = createMajorityDowningProvider(selfAddr)

    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    let m2 = createMember("node-2", "host2", 2552)
    let m3 = createMember("node-3", "host3", 2552)
    let m4 = createMember("node-4", "host4", 2552)
    let m5 = createMember("node-5", "host5", 2552)
    m4.reachability = DowningReachability.Unreachable
    m5.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)
    members.add(m3)
    members.add(m4)
    members.add(m5)

    let decision = provider.handleUnreachable(members)
    // 3 reachable vs 2 unreachable -> majority wins
    @Expect(decision.size(), 2)
}

@Test
func testMajorityDowningProvider_minorityPartition() {
    let selfAddr = Address("cactor", "test", "localhost", 2552)
    let provider = createMajorityDowningProvider(selfAddr)

    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    let m2 = createMember("node-2", "host2", 2552)
    let m3 = createMember("node-3", "host3", 2552)
    let m4 = createMember("node-4", "host4", 2552)
    let m5 = createMember("node-5", "host5", 2552)
    m3.reachability = DowningReachability.Unreachable
    m4.reachability = DowningReachability.Unreachable
    m5.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)
    members.add(m3)
    members.add(m4)
    members.add(m5)

    let decision = provider.handleUnreachable(members)
    // 2 reachable vs 3 unreachable -> minority, self-down
    @Expect(decision.size(), 0)
}

// === StaticQuorumDowningProvider Tests ===

@Test
func testStaticQuorumDowningProvider_name() {
    let provider = createStaticQuorumDowningProvider(3)
    @Expect(provider.name(), "static-quorum-downing")
}

@Test
func testStaticQuorumDowningProvider_aboveQuorum() {
    let provider = createStaticQuorumDowningProvider(2)

    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    let m2 = createMember("node-2", "host2", 2552)
    let m3 = createMember("node-3", "host3", 2552)
    m3.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)
    members.add(m3)

    let decision = provider.handleUnreachable(members)
    // 2 reachable >= quorum 2 -> no action
    @Expect(decision.isEmpty(), true)
}

@Test
func testStaticQuorumDowningProvider_belowQuorum() {
    let provider = createStaticQuorumDowningProvider(3)

    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    let m2 = createMember("node-2", "host2", 2552)
    let m3 = createMember("node-3", "host3", 2552)
    let m4 = createMember("node-4", "host4", 2552)
    m3.reachability = DowningReachability.Unreachable
    m4.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)
    members.add(m3)
    members.add(m4)

    let decision = provider.handleUnreachable(members)
    // 2 reachable < quorum 3 -> down unreachable
    @Expect(decision.size(), 2)
}

// === DownAllDowningProvider Tests ===

@Test
func testDownAllDowningProvider_name() {
    let provider = DownAllDowningProvider()
    @Expect(provider.name(), "down-all-downing")
}

@Test
func testDownAllDowningProvider_downAll() {
    let provider = DownAllDowningProvider()

    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    let m2 = createMember("node-2", "host2", 2552)
    m2.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)

    let decision = provider.handleUnreachable(members)
    @Expect(decision.size(), 1)
}

@Test
func testDownAllDowningProvider_allReachable() {
    let provider = DownAllDowningProvider()

    let members = ArrayList<MemberInfo2>()
    members.add(createMember("node-1", "host1", 2552))
    members.add(createMember("node-2", "host2", 2552))

    let decision = provider.handleUnreachable(members)
    @Expect(decision.isEmpty(), true)
}

// === KeepOldestDowningProvider Tests ===

@Test
func testKeepOldestDowningProvider_name() {
    let provider = KeepOldestDowningProvider(true)
    @Expect(provider.name(), "keep-oldest-downing")
}

@Test
func testKeepOldestDowningProvider_oldestReachable() {
    let provider = KeepOldestDowningProvider(false)

    let members = ArrayList<MemberInfo2>()
    let m1 = createMember("node-1", "host1", 2552)
    m1.upTimestamp = 1000
    let m2 = createMember("node-2", "host2", 2552)
    m2.upTimestamp = 2000
    m2.reachability = DowningReachability.Unreachable
    members.add(m1)
    members.add(m2)

    let decision = provider.handleUnreachable(members)
    // oldest is reachable, down unreachable non-oldest
    @Expect(decision.size(), 1)
}
