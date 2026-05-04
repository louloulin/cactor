/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Lease 租约机制单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === LeaseState Tests ===

@Test
func testLeaseState_released() {
    @Expect(LeaseState.Released.isActive(), false)
}

@Test
func testLeaseState_leased() {
    @Expect(LeaseState.Leased.isActive(), true)
}

@Test
func testLeaseState_acquiring() {
    @Expect(LeaseState.Acquiring.isActive(), false)
}

// === LeaseResult Tests ===

@Test
func testLeaseResult_granted() {
    let result = LeaseResult.granted("test")
    @Expect(result.granted, true)
    @Expect(result.reason, "test")
}

@Test
func testLeaseResult_denied() {
    let result = LeaseResult.denied("conflict")
    @Expect(result.granted, false)
    @Expect(result.reason, "conflict")
}

// === LeaseConfig Tests ===

@Test
func testLeaseConfig_creation() {
    let config = LeaseConfig("test-lease", Duration.minute * 5)
    @Expect(config.leaseName, "test-lease")
}

@Test
func testLeaseConfig_withRetryInterval() {
    let config = LeaseConfig("test-lease", Duration.minute * 5)
        .withRetryInterval(Duration.second * 2)
    @Expect(config.retryInterval, Duration.second * 2)
}

@Test
func testLeaseConfig_withMaxRetries() {
    let config = LeaseConfig("test-lease", Duration.minute * 5)
        .withMaxRetries(10)
    @Expect(config.maxRetries, 10)
}

// === SingleOwnerLease Tests ===

@Test
func testSingleOwnerLease_acquire() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    let result = lease.acquire("owner-1", Duration.minute * 5)
    @Expect(result.granted, true)
}

@Test
func testSingleOwnerLease_acquireTwice() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    let result1 = lease.acquire("owner-1", Duration.minute * 5)
    @Expect(result1.granted, true)

    let result2 = lease.acquire("owner-2", Duration.minute * 5)
    @Expect(result2.granted, false)
}

@Test
func testSingleOwnerLease_acquireSameOwner() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    lease.acquire("owner-1", Duration.minute * 5)
    let result = lease.acquire("owner-1", Duration.minute * 5)
    @Expect(result.granted, true)
}

@Test
func testSingleOwnerLease_release() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    lease.acquire("owner-1", Duration.minute * 5)
    let released = lease.release("owner-1")
    @Expect(released, true)
    @Expect(lease.check().isActive(), false)
}

@Test
func testSingleOwnerLease_releaseWrongOwner() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    lease.acquire("owner-1", Duration.minute * 5)
    let released = lease.release("owner-2")
    @Expect(released, false)
    @Expect(lease.check().isActive(), true)
}

@Test
func testSingleOwnerLease_getOwner() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    lease.acquire("owner-1", Duration.minute * 5)
    let owner = lease.getOwner()
    @Expect(owner.isSome(), true)
}

@Test
func testSingleOwnerLease_getOwnerNone() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    let owner = lease.getOwner()
    @Expect(owner.isNone(), true)
}

@Test
func testSingleOwnerLease_renew() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    lease.acquire("owner-1", Duration.minute * 5)
    let renewed = lease.renew("owner-1", Duration.minute * 10)
    @Expect(renewed, true)
}

@Test
func testSingleOwnerLease_renewWrongOwner() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    lease.acquire("owner-1", Duration.minute * 5)
    let renewed = lease.renew("owner-2", Duration.minute * 10)
    @Expect(renewed, false)
}

// === LeaseManager Tests ===

@Test
func testLeaseManager_register() {
    let manager = createLeaseManager()
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    manager.register(lease)
    @Expect(manager.hasLease("test-lease"), true)
}

@Test
func testLeaseManager_getLease() {
    let manager = createLeaseManager()
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    manager.register(lease)
    let retrieved = manager.getLease("test-lease")
    @Expect(retrieved.isSome(), true)
}

@Test
func testLeaseManager_getLeaseNames() {
    let manager = createLeaseManager()
    manager.register(createSingleOwnerLease("lease-1", Duration.minute * 5))
    manager.register(createSingleOwnerLease("lease-2", Duration.minute * 5))
    let names = manager.getLeaseNames()
    @Expect(names.size, 2)
}

@Test
func testLeaseManager_getActiveLeases() {
    let manager = createLeaseManager()
    let lease1 = createSingleOwnerLease("lease-1", Duration.minute * 5)
    let lease2 = createSingleOwnerLease("lease-2", Duration.minute * 5)
    manager.register(lease1)
    manager.register(lease2)
    lease1.acquire("owner-1", Duration.minute * 5)

    let active = manager.getActiveLeases()
    @Expect(active.size, 1)
}

// === LeaseEventHandler Tests ===

class TestLeaseHandler <: LeaseEventHandler {
    public let acquired = ArrayList<String>()
    public let released = ArrayList<String>()
    public let failed = ArrayList<String>()

    public func onLeaseAcquired(leaseName: String, owner: String): Unit {
        acquired.add("${leaseName}:${owner}")
    }

    public func onLeaseReleased(leaseName: String, owner: String): Unit {
        released.add("${leaseName}:${owner}")
    }

    public func onLeaseAcquireFailed(leaseName: String, owner: String, reason: String): Unit {
        failed.add("${leaseName}:${owner}:${reason}")
    }
}

@Test
func testSingleOwnerLease_eventHandler_acquire() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    let handler = TestLeaseHandler()
    lease.setEventHandler(handler)

    lease.acquire("owner-1", Duration.minute * 5)
    @Expect(handler.acquired.size, 1)
}

@Test
func testSingleOwnerLease_eventHandler_release() {
    let lease = createSingleOwnerLease("test-lease", Duration.minute * 5)
    let handler = TestLeaseHandler()
    lease.setEventHandler(handler)

    lease.acquire("owner-1", Duration.minute * 5)
    lease.release("owner-1")
    @Expect(handler.released.size, 1)
}
