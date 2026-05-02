/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - DistributedLock 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === DistributedLock Tests ===

@Test
func testDistributedLock_creation() {
    let lock = SimpleDistributedLock("test-lock")

    @Expect(lock.name(), "test-lock")
    @Expect(lock.isLocked(), false)
}

@Test
func testDistributedLock_tryLock() {
    let lock = SimpleDistributedLock("lock-1")
    let holder = "node-1"

    let acquired = lock.tryLock(holder)

    @Expect(acquired, true)
    @Expect(lock.isLocked(), true)
    @Expect(lock.isHeldBy(holder), true)
}

@Test
func testDistributedLock_unlock() {
    let lock = SimpleDistributedLock("lock-2")
    let holder = "node-2"

    lock.tryLock(holder)
    let released = lock.unlock(holder)

    @Expect(released, true)
    @Expect(lock.isLocked(), false)
}

@Test
func testDistributedLock_unlockByDifferentHolder() {
    let lock = SimpleDistributedLock("lock-3")
    let holder1 = "node-1"
    let holder2 = "node-2"

    lock.tryLock(holder1)
    let released = lock.unlock(holder2)

    @Expect(released, false)
    @Expect(lock.isLocked(), true)
}

@Test
func testDistributedLock_reentrant() {
    let lock = SimpleDistributedLock("lock-4")
    let holder = "node-same"

    let first = lock.tryLock(holder)
    let second = lock.tryLock(holder)

    @Expect(first, true)
    @Expect(second, true)
    @Expect(lock.isHeldBy(holder), true)

    // 解锁两次
    lock.unlock(holder)
    lock.unlock(holder)
    @Expect(lock.isLocked(), false)
}

@Test
func testDistributedLock_tryLockWhenLocked() {
    let lock = SimpleDistributedLock("lock-5")
    let holder1 = "node-a"
    let holder2 = "node-b"

    lock.tryLock(holder1)
    let acquiredByOther = lock.tryLock(holder2)

    @Expect(acquiredByOther, false)
    @Expect(lock.isHeldBy(holder1), true)
    @Expect(lock.isHeldBy(holder2), false)
}

@Test
func testDistributedLock_state() {
    let lock = SimpleDistributedLock("lock-state")
    let holder = "holder-1"

    let unlockedState = lock.state()
    let isUnlocked = match (unlockedState) {
        case Unlocked => true
        case _ => false
    }
    @Expect(isUnlocked, true)

    lock.tryLock(holder)

    let lockedState = lock.state()
    let isHeld = match (lockedState) {
        case LockedBy(h, _) => h == holder
        case _ => false
    }
    @Expect(isHeld, true)
}

@Test
func testDistributedLock_renewLease() {
    let lock = SimpleDistributedLock("lock-renew", leaseTime: Duration.second * 10)
    let holder = "renew-holder"

    lock.tryLock(holder)
    let renewed = lock.renewLease(holder)

    @Expect(renewed, true)
    @Expect(lock.isHeldBy(holder), true)
}

@Test
func testDistributedLock_renewLeaseByNonHolder() {
    let lock = SimpleDistributedLock("lock-renew-2")
    let holder1 = "holder-a"
    let holder2 = "holder-b"

    lock.tryLock(holder1)
    let renewed = lock.renewLease(holder2)

    @Expect(renewed, false)
}

// === DistributedLockManager Tests ===

@Test
func testDistributedLockManager_creation() {
    let manager = DistributedLockManager()

    @Expect(manager.getLockCount(), 0)
}

@Test
func testDistributedLockManager_getLock() {
    let manager = DistributedLockManager()

    let lock1 = manager.getLock("shared-lock")
    let lock2 = manager.getLock("shared-lock")

    @Expect(lock1.name() == lock2.name(), true)
    @Expect(manager.getLockCount(), 1)
}

@Test
func testDistributedLockManager_getLockNames() {
    let manager = DistributedLockManager()

    manager.getLock("lock-a")
    manager.getLock("lock-b")
    manager.getLock("lock-c")

    let names = manager.getLockNames()
    @Expect(names.size, 3)
}

@Test
func testDistributedLockManager_multipleLocks() {
    let manager = DistributedLockManager()

    let lock1 = manager.getLock("lock-1")
    let lock2 = manager.getLock("lock-2")
    let lock3 = manager.getLock("lock-3")

    @Expect(lock1.name(), "lock-1")
    @Expect(lock2.name(), "lock-2")
    @Expect(lock3.name(), "lock-3")
    @Expect(manager.getLockCount(), 3)
}

@Test
func testDistributedLockManager_independentLocks() {
    let manager = DistributedLockManager()

    let lock1 = manager.getLock("independent-1")
    let lock2 = manager.getLock("independent-2")
    let holder1 = "node-1"
    let holder2 = "node-2"

    lock1.tryLock(holder1)
    lock2.tryLock(holder2)

    @Expect(lock1.isLocked(), true)
    @Expect(lock2.isLocked(), true)
    @Expect(lock1.isHeldBy(holder1), true)
    @Expect(lock2.isHeldBy(holder2), true)
}

// === Integration Tests ===

@Test
func testDistributedLock_integration() {
    let manager = DistributedLockManager()

    // 创建分布式资源锁
    let resourceLock = manager.getLock("resource-lock")
    let resourceId = "resource-123"
    let nodeId = "cluster-node-1"

    // 获取锁
    let acquired = resourceLock.tryLock(nodeId)
    @Expect(acquired, true)

    // 模拟资源访问
    let canAccess = resourceLock.isHeldBy(nodeId)
    @Expect(canAccess, true)

    // 释放锁
    let released = resourceLock.unlock(nodeId)
    @Expect(released, true)
    @Expect(resourceLock.isLocked(), false)
}

@Test
func testDistributedLock_concurrentScenario() {
    let manager = DistributedLockManager()

    // 模拟两个节点竞争同一资源
    let resourceLock = manager.getLock("exclusive-resource")
    let node1 = "node-1"
    let node2 = "node-2"

    // Node1 获取锁
    let node1Acquired = resourceLock.tryLock(node1)
    @Expect(node1Acquired, true)

    // Node2 尝试获取锁（应该失败）
    let node2Acquired = resourceLock.tryLock(node2)
    @Expect(node2Acquired, false)

    // Node1 释放锁
    resourceLock.unlock(node1)

    // Node2 再次尝试获取锁（应该成功）
    let node2NowAcquired = resourceLock.tryLock(node2)
    @Expect(node2NowAcquired, true)

    // 清理
    resourceLock.unlock(node2)
}

@Test
func testDistributedLock_leaseTime() {
    let lock = SimpleDistributedLock("lease-lock", leaseTime: Duration.second * 1)
    let holder = "lease-holder"

    lock.tryLock(holder)
    @Expect(lock.isHeldBy(holder), true)

    // 续期
    let renewed = lock.renewLease(holder)
    @Expect(renewed, true)

    // 解锁
    lock.unlock(holder)
    @Expect(lock.isLocked(), false)
}
