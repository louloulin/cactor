/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - SplitBrainResolver 单元测试
 */
package cactor.distribution.cluster

import std.time.*

// === Test Helper ===

class TestUniqueAddress <: Hashable & Equatable<TestUniqueAddress> & ToString {
    public let uid: Int64

    public init(uid: Int64) {
        this.uid = uid
    }

    public func toString(): String {
        "TestAddr(${uid})"
    }

    public func equals(other: TestUniqueAddress): Bool {
        uid == other.uid
    }

    public operator func ==(other: TestUniqueAddress): Bool {
        equals(other)
    }

    public func hashCode(): Int64 {
        uid
    }
}

// === SBRConfig Tests ===

@Test
func testSBRConfig_defaultCreation() {
    let config = SBRConfig(SBRStrategy.KeepMajority)
    match (config.strategy) {
        case SBRStrategy.KeepMajority => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    @Expect(config.quitClaimRetries, 3)
}

@Test
func testSBRConfig_customValues() {
    let config = SBRConfig(
        SBRStrategy.StaticQuorum,
        downAllWhenUnreachable: Duration.second * 60,
        stableAfter: Duration.second * 30,
        majorityCanSplit: false,
        refereeCanSplit: false,
        downRemovalsEnabled: false,
        quitClaimRetries: 5
    )
    match (config.strategy) {
        case SBRStrategy.StaticQuorum => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    @Expect(config.downAllWhenUnreachable, Duration.second * 60)
    @Expect(config.stableAfter, Duration.second * 30)
    @Expect(config.majorityCanSplit, false)
    @Expect(config.refereeCanSplit, false)
    @Expect(config.downRemovalsEnabled, false)
    @Expect(config.quitClaimRetries, 5)
}

@Test
func testSBRConfig_getDefault() {
    let config = SBRConfig.getDefault()
    match (config.strategy) {
        case SBRStrategy.KeepMajority => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testSBRConfig_keepOldest() {
    let config = SBRConfig.keepOldest()
    match (config.strategy) {
        case SBRStrategy.KeepOldest => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testSBRConfig_staticQuorum() {
    let config = SBRConfig.staticQuorum(3, stableAfter: Duration.second * 20)
    match (config.strategy) {
        case SBRStrategy.StaticQuorum => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testSBRConfig_downAll() {
    let config = SBRConfig.downAll()
    match (config.strategy) {
        case SBRStrategy.DownAll => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

// === SBRStrategy Tests ===

@Test
func testSBRStrategy_values() {
    let strategies = [
        SBRStrategy.KeepMajority,
        SBRStrategy.KeepOldest,
        SBRStrategy.KeepReferee,
        SBRStrategy.StaticQuorum,
        SBRStrategy.DownAll,
        SBRStrategy.KeepMinority
    ]
    let count = strategies.size
    @Expect(count, 6)
}

@Test
func testSBRStrategy_toString() {
    let strategy = SBRStrategy.KeepMajority
    @Expect(strategy.toString(), "KeepMajority")

    let strategy2 = SBRStrategy.DownAll
    @Expect(strategy2.toString(), "DownAll")
}

// === SBRDecision Tests ===

@Test
func testSBRDecision_creation() {
    let survivors: HashSet<UniqueAddress> = HashSet()
    let victims: HashSet<UniqueAddress> = HashSet()
    let addr1 = UniqueAddress(Address("cactor", "sys", "localhost", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "localhost", 2553), 2)
    survivors.add(addr1)
    victims.add(addr2)

    let decision = SBRDecision(SBRStrategy.KeepMajority, survivors, victims, "test reason")

    match (decision.strategy) {
        case SBRStrategy.KeepMajority => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    let survivorsCount = decision.survivors.size()
    let victimsCount = decision.victims.size()
    @Expect(survivorsCount, 1)
    @Expect(victimsCount, 1)
    @Expect(decision.reason, "test reason")
    @Expect(decision.timestamp > 0, true)
}

@Test
func testSBRDecision_isSurvivor() {
    let survivors: HashSet<UniqueAddress> = HashSet()
    let victims: HashSet<UniqueAddress> = HashSet()
    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    survivors.add(addr1)
    victims.add(addr2)

    let decision = SBRDecision(SBRStrategy.KeepMajority, survivors, victims, "test")

    @Expect(decision.isSurvivor(addr1), true)
    @Expect(decision.isSurvivor(addr2), false)
}

@Test
func testSBRDecision_isVictim() {
    let survivors: HashSet<UniqueAddress> = HashSet()
    let victims: HashSet<UniqueAddress> = HashSet()
    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    survivors.add(addr1)
    victims.add(addr2)

    let decision = SBRDecision(SBRStrategy.KeepMajority, survivors, victims, "test")

    @Expect(decision.isVictim(addr1), false)
    @Expect(decision.isVictim(addr2), true)
}

@Test
func testSBRDecision_toString() {
    let survivors: HashSet<UniqueAddress> = HashSet()
    let victims: HashSet<UniqueAddress> = HashSet()
    let addr = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    survivors.add(addr)

    let decision = SBRDecision(SBRStrategy.KeepOldest, survivors, victims, "test reason")
    let str = decision.toString()

    @Expect(str.contains("KeepOldest"), true)
    @Expect(str.contains("test reason"), true)
}

// === KeepMajorityResolver Tests ===

@Test
func testKeepMajorityResolver_majority() {
    let config = SBRConfig(SBRStrategy.KeepMajority)
    let resolver = KeepMajorityResolver(config)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    all.add(addr1)
    all.add(addr2)
    all.add(addr3)
    unreachable.add(addr3)  // 3 is unreachable

    let decision = resolver.resolve(all, unreachable, downed)

    match (decision.strategy) {
        case SBRStrategy.KeepMajority => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    let survivorsCount = decision.survivors.size()
    let victimsCount = decision.victims.size()
    @Expect(survivorsCount, 2)
    @Expect(victimsCount, 1)
    @Expect(decision.isSurvivor(addr1), true)
    @Expect(decision.isSurvivor(addr2), true)
    @Expect(decision.isSurvivor(addr3), false)
}

@Test
func testKeepMajorityResolver_minority() {
    let config = SBRConfig(SBRStrategy.KeepMajority)
    let resolver = KeepMajorityResolver(config)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    all.add(addr1)
    all.add(addr2)
    all.add(addr3)
    unreachable.add(addr1)  // 1 is unreachable
    unreachable.add(addr2)  // 2 is unreachable

    let decision = resolver.resolve(all, unreachable, downed)

    // Minority (1/3), should down all
    let survivorsCount = decision.survivors.size()
    let victimsCount = decision.victims.size()
    @Expect(survivorsCount, 0)
    @Expect(victimsCount, 3)
}

@Test
func testKeepMajorityResolver_shouldResolve() {
    let config = SBRConfig(SBRStrategy.KeepMajority)
    let resolver = KeepMajorityResolver(config)

    let unreachable: HashSet<UniqueAddress> = HashSet()
    @Expect(resolver.shouldResolve(unreachable), false)

    let addr = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    unreachable.add(addr)
    @Expect(resolver.shouldResolve(unreachable), true)
}

@Test
func testKeepMajorityResolver_setNodePriority() {
    let config = SBRConfig(SBRStrategy.KeepMajority)
    let resolver = KeepMajorityResolver(config)

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)

    resolver.setNodePriority(addr1, 100)
    resolver.setNodePriority(addr2, 200)

    // Priority is set, no exception means success
    @Expect(true, true)
}

// === KeepOldestResolver Tests ===

@Test
func testKeepOldestResolver_oldestSurvives() {
    let config = SBRConfig.keepOldest()
    let resolver = KeepOldestResolver(config)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    // uid=1 is oldest
    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    all.add(addr1)
    all.add(addr2)
    all.add(addr3)
    unreachable.add(addr2)  // node2 is unreachable
    unreachable.add(addr3)  // node3 is unreachable

    let decision = resolver.resolve(all, unreachable, downed)

    match (decision.strategy) {
        case SBRStrategy.KeepOldest => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    let survivorsCount = decision.survivors.size()
    @Expect(survivorsCount, 1)
    @Expect(decision.isSurvivor(addr1), true)  // Oldest survives
    @Expect(decision.isSurvivor(addr2), false)
    @Expect(decision.isSurvivor(addr3), false)
}

@Test
func testKeepOldestResolver_allUnreachable() {
    let config = SBRConfig.keepOldest()
    let resolver = KeepOldestResolver(config)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    all.add(addr1)
    all.add(addr2)
    unreachable.add(addr1)
    unreachable.add(addr2)

    let decision = resolver.resolve(all, unreachable, downed)

    // Oldest survives even when all unreachable
    let survivorsCount = decision.survivors.size()
    @Expect(survivorsCount, 1)
    @Expect(decision.isSurvivor(addr1), true)  // Oldest
}

// === StaticQuorumResolver Tests ===

@Test
func testStaticQuorumResolver_quorumMet() {
    let quorumSize: Int32 = 2
    let config = SBRConfig.staticQuorum(quorumSize)
    let resolver = StaticQuorumResolver(config, quorumSize)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    let addr4 = UniqueAddress(Address("cactor", "sys", "node4", 2552), 4)
    all.add(addr1)
    all.add(addr2)
    all.add(addr3)
    all.add(addr4)
    unreachable.add(addr4)

    let decision = resolver.resolve(all, unreachable, downed)

    match (decision.strategy) {
        case SBRStrategy.StaticQuorum => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    // 3 reachable >= quorum(2), so majority survives
    let survivorsCount = decision.survivors.size()
    @Expect(survivorsCount, 3)
}

@Test
func testStaticQuorumResolver_quorumNotMet() {
    let quorumSize: Int32 = 3
    let config = SBRConfig.staticQuorum(quorumSize)
    let resolver = StaticQuorumResolver(config, quorumSize)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    let addr4 = UniqueAddress(Address("cactor", "sys", "node4", 2552), 4)
    all.add(addr1)
    all.add(addr2)
    all.add(addr3)
    all.add(addr4)
    unreachable.add(addr3)
    unreachable.add(addr4)

    let decision = resolver.resolve(all, unreachable, downed)

    // 2 reachable < quorum(3), down all
    let survivorsCount = decision.survivors.size()
    @Expect(survivorsCount, 0)
}

// === DownAllResolver Tests ===

@Test
func testDownAllResolver_alwaysDownAll() {
    let config = SBRConfig.downAll()
    let resolver = DownAllResolver(config)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    all.add(addr1)
    all.add(addr2)

    let decision = resolver.resolve(all, unreachable, downed)

    match (decision.strategy) {
        case SBRStrategy.DownAll => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    let survivorsCount = decision.survivors.size()
    let victimsCount = decision.victims.size()
    @Expect(survivorsCount, 0)
    @Expect(victimsCount, 2)
}

// === Integration Tests ===

@Test
func testSBRConfig_withDownedNodes() {
    let config = SBRConfig(
        SBRStrategy.KeepMajority,
        downRemovalsEnabled: true
    )
    let resolver = KeepMajorityResolver(config)

    let all: HashSet<UniqueAddress> = HashSet()
    let unreachable: HashSet<UniqueAddress> = HashSet()
    let downed: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    let addr4 = UniqueAddress(Address("cactor", "sys", "node4", 2552), 4)
    all.add(addr1)
    all.add(addr2)
    all.add(addr3)
    all.add(addr4)
    downed.add(addr4)  // addr4 already down

    let decision = resolver.resolve(all, unreachable, downed)

    // 3 reachable nodes (4 total - 1 downed), majority is 3/4 > 1.5, so 2 is enough
    // Actually, majority is > half: 4/2 = 2, so 3 >= 3 is majority
    let survivorsCount = decision.survivors.size()
    @Expect(survivorsCount, 3)
}

@Test
func testSBRDecision_withMultipleSurvivors() {
    let survivors: HashSet<UniqueAddress> = HashSet()
    let victims: HashSet<UniqueAddress> = HashSet()

    let addr1 = UniqueAddress(Address("cactor", "sys", "node1", 2552), 1)
    let addr2 = UniqueAddress(Address("cactor", "sys", "node2", 2552), 2)
    let addr3 = UniqueAddress(Address("cactor", "sys", "node3", 2552), 3)
    survivors.add(addr1)
    survivors.add(addr2)
    survivors.add(addr3)

    let decision = SBRDecision(SBRStrategy.KeepMajority, survivors, victims, "test")

    let survivorsCount = decision.survivors.size()
    let victimsCount = decision.victims.size()
    @Expect(survivorsCount, 3)
    @Expect(victimsCount, 0)
    @Expect(decision.isSurvivor(addr1), true)
    @Expect(decision.isSurvivor(addr2), true)
    @Expect(decision.isSurvivor(addr3), true)
}
