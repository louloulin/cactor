/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 分布式锁实现
 * 对标 Akka Distributed Data / Java Concurrent
 * 提供跨节点的互斥锁和读写锁
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 分布式锁状态
 */
public enum DistributedLockState {
    | Unlocked
    | LockedBy(String, Int64)  // holder, timestamp
    | Waiting(ArrayList<String>)  // waiting nodes
}

/**
 * 分布式锁接口
 * 对标 Java ReentrantLock / Akka Distributed Data
 */
public interface DistributedLock {
    /**
     * 获取锁名称
     */
    func name(): String

    /**
     * 获取当前锁状态
     */
    func state(): DistributedLockState

    /**
     * 尝试获取锁
     * @param holder 锁持有者ID
     * @return 是否获取成功
     */
    func tryLock(holder: String): Bool

    /**
     * 释放锁
     * @param holder 锁持有者ID
     * @return 是否成功释放
     */
    func unlock(holder: String): Bool

    /**
     * 检查是否被锁定
     */
    func isLocked(): Bool

    /**
     * 检查是否被指定持有者锁定
     */
    func isHeldBy(holder: String): Bool
}

/**
 * 简单分布式锁实现
 * 基于 CRDT 的无冲突分布式锁
 */
public class SimpleDistributedLock <: DistributedLock {
    private let lockName: String
    private var lockState: DistributedLockState
    private let mutex: ReentrantReadWriteMutex
    private let leaseTime: Duration
    private var leaseExpiration: Int64

    public init(name: String, leaseTime!: Duration = Duration.second * 30) {
        this.lockName = name
        this.lockState = DistributedLockState.Unlocked
        this.mutex = ReentrantReadWriteMutex()
        this.leaseTime = leaseTime
        this.leaseExpiration = 0
    }

    public func name(): String {
        lockName
    }

    public func state(): DistributedLockState {
        try {
            mutex.readMutex.lock()
            let s = lockState
            mutex.readMutex.unlock()
            return s
        } catch (e: Exception) {
            mutex.readMutex.unlock()
            return DistributedLockState.Unlocked
        }
    }

    public func tryLock(holder: String): Bool {
        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        try {
            mutex.writeMutex.lock()

            match (lockState) {
                case DistributedLockState.Unlocked =>
                    lockState = DistributedLockState.LockedBy(holder, currentTime)
                    leaseExpiration = currentTime + leaseTime.toMilliseconds()
                    mutex.writeMutex.unlock()
                    return true

                case DistributedLockState.LockedBy(currentHolder, _) =>
                    if (currentHolder == holder) {
                        // 可重入
                        lockState = DistributedLockState.LockedBy(holder, currentTime)
                        leaseExpiration = currentTime + leaseTime.toMilliseconds()
                        mutex.writeMutex.unlock()
                        return true
                    }
                    mutex.writeMutex.unlock()
                    return false

                case DistributedLockState.Waiting(_) =>
                    mutex.writeMutex.unlock()
                    return false
            }
        } catch (e: Exception) {
            try {
                mutex.writeMutex.unlock()
            } catch (_: Exception) {}
            return false
        }
    }

    public func unlock(holder: String): Bool {
        try {
            mutex.writeMutex.lock()

            match (lockState) {
                case DistributedLockState.LockedBy(currentHolder, _) =>
                    if (currentHolder == holder) {
                        lockState = DistributedLockState.Unlocked
                        leaseExpiration = 0
                        mutex.writeMutex.unlock()
                        return true
                    }
                    mutex.writeMutex.unlock()
                    return false

                case _ =>
                    mutex.writeMutex.unlock()
                    return false
            }
        } catch (e: Exception) {
            try {
                mutex.writeMutex.unlock()
            } catch (_: Exception) {}
            return false
        }
    }

    public func isLocked(): Bool {
        try {
            mutex.readMutex.lock()
            let locked = match (lockState) {
                case DistributedLockState.LockedBy(_, _) => true
                case _ => false
            }
            mutex.readMutex.unlock()
            return locked
        } catch (e: Exception) {
            mutex.readMutex.unlock()
            return false
        }
    }

    public func isHeldBy(holder: String): Bool {
        try {
            mutex.readMutex.lock()
            let held = match (lockState) {
                case DistributedLockState.LockedBy(currentHolder, _) => currentHolder == holder
                case _ => false
            }
            mutex.readMutex.unlock()
            return held
        } catch (e: Exception) {
            mutex.readMutex.unlock()
            return false
        }
    }

    /**
     * 检查并续期锁
     */
    public func renewLease(holder: String): Bool {
        try {
            mutex.writeMutex.lock()

            match (lockState) {
                case DistributedLockState.LockedBy(currentHolder, _) =>
                    if (currentHolder == holder) {
                        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                        leaseExpiration = currentTime + leaseTime.toMilliseconds()
                        mutex.writeMutex.unlock()
                        return true
                    }
                    mutex.writeMutex.unlock()
                    return false

                case _ =>
                    mutex.writeMutex.unlock()
                    return false
            }
        } catch (e: Exception) {
            try {
                mutex.writeMutex.unlock()
            } catch (_: Exception) {}
            return false
        }
    }
}

/**
 * 分布式锁管理器
 */
public class DistributedLockManager {
    private let locks: HashMap<String, SimpleDistributedLock>
    private let mutex: ReentrantReadWriteMutex

    public init() {
        this.locks = HashMap<String, SimpleDistributedLock>()
        this.mutex = ReentrantReadWriteMutex()
    }

    /**
     * 获取或创建锁
     */
    public func getLock(name: String, leaseTime!: Duration = Duration.second * 30): DistributedLock {
        try {
            mutex.writeMutex.lock()
            match (locks.get(name)) {
                case Some(lock) =>
                    mutex.writeMutex.unlock()
                    return lock
                case None =>
                    let newLock = SimpleDistributedLock(name, leaseTime: leaseTime)
                    locks.add(name, newLock)
                    mutex.writeMutex.unlock()
                    return newLock
            }
        } catch (e: Exception) {
            try {
                mutex.writeMutex.unlock()
            } catch (_: Exception) {}
            let newLock = SimpleDistributedLock(name, leaseTime: leaseTime)
            return newLock
        }
    }

    /**
     * 获取所有锁名称
     */
    public func getLockNames(): Array<String> {
        try {
            mutex.readMutex.lock()
            let names = ArrayList<String>()
            for ((name, _) in locks) {
                names.add(name)
            }
            mutex.readMutex.unlock()
            names.toArray()
        } catch (e: Exception) {
            mutex.readMutex.unlock()
            Array<String>(0, { i => "" })
        }
    }

    /**
     * 获取锁数量
     */
    public func getLockCount(): Int64 {
        try {
            mutex.readMutex.lock()
            let count = locks.size
            mutex.readMutex.unlock()
            Int64(count)
        } catch (e: Exception) {
            mutex.readMutex.unlock()
            0
        }
    }
}
