/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 分布式租约机制
 * 对标 Akka Cluster Lease
 * 用于分布式协调，确保同一时刻只有一个节点执行特定操作
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 租约状态
 */
public enum LeaseState <: ToString {
    | Released    // 未被租借
    | Leased     // 已被租借
    | Acquiring  // 正在获取

    public func isActive(): Bool {
        match (this) {
            case Leased => true
            case _ => false
        }
    }

    public func toString(): String {
        match (this) {
            case Released => "Released"
            case Leased => "Leased"
            case Acquiring => "Acquiring"
        }
    }
}

/**
 * 租约操作结果
 */
public class LeaseResult {
    public let granted: Bool
    public let reason: String
    public let timestamp: Int64

    public init(granted: Bool, reason: String) {
        this.granted = granted
        this.reason = reason
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public static func createGranted(reason: String): LeaseResult {
        LeaseResult(true, reason)
    }

    public static func createDenied(reason: String): LeaseResult {
        LeaseResult(false, reason)
    }
}

/**
 * 租约事件处理器
 */
public interface LeaseEventHandler {
    /**
     * 租约被获取
     */
    func onLeaseAcquired(leaseName: String, owner: String): Unit

    /**
     * 租约被释放
     */
    func onLeaseReleased(leaseName: String, owner: String): Unit

    /**
     * 租约获取失败
     */
    func onLeaseAcquireFailed(leaseName: String, owner: String, reason: String): Unit
}

/**
 * 租约接口 - 对标 Akka Lease
 * 提供分布式锁机制，确保同一时刻只有一个节点可以执行特定操作
 */
public interface Lease {
    /**
     * 获取租约名称
     */
    func name(): String

    /**
     * 尝试获取租约
     * @param owner 租约持有者标识
     * @param timeout 获取超时时间
     * @return 获取结果
     */
    func acquire(owner: String, timeout: Duration): LeaseResult

    /**
     * 释放租约
     * @param owner 租约持有者标识
     * @return 是否成功释放
     */
    func release(owner: String): Bool

    /**
     * 检查租约状态
     * @return 当前状态
     */
    func check(): LeaseState

    /**
     * 获取当前持有者
     * @return 持有者标识，如果没有则返回 None
     */
    func getOwner(): Option<String>

    /**
     * 续约租约
     * @param owner 租约持有者标识
     * @param timeout 新的超时时间
     * @return 是否成功续约
     */
    func renew(owner: String, timeout: Duration): Bool
}

/**
 * 租约配置
 */
public class LeaseConfig {
    public let leaseName: String
    public let timeout: Duration
    public var retryInterval: Duration
    public var maxRetries: Int64

    public init(leaseName: String, timeout: Duration) {
        this.leaseName = leaseName
        this.timeout = timeout
        this.retryInterval = Duration.second * 1
        this.maxRetries = 3
    }

    public func withRetryInterval(interval: Duration): LeaseConfig {
        var config = LeaseConfig(leaseName, timeout)
        config.retryInterval = interval
        config.maxRetries = maxRetries
        config
    }

    public func withMaxRetries(maxRetries: Int64): LeaseConfig {
        var config = LeaseConfig(leaseName, timeout)
        config.retryInterval = retryInterval
        config.maxRetries = maxRetries
        config
    }
}

/**
 * 单主租约实现
 * 简单的租约实现，同一时刻只能有一个持有者
 */
public class SingleOwnerLease <: Lease {
    private let config: LeaseConfig
    private let lock: ReentrantReadWriteMutex
    private var currentOwner: Option<String>
    private var state: LeaseState
    private var expireTime: Int64
    private var eventHandler: Option<LeaseEventHandler>

    public init(config: LeaseConfig) {
        this.config = config
        this.lock = ReentrantReadWriteMutex()
        this.currentOwner = None
        this.state = LeaseState.Released
        this.expireTime = 0
        this.eventHandler = None
    }

    public func setEventHandler(handler: LeaseEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    public func name(): String {
        config.leaseName
    }

    public func acquire(owner: String, timeout: Duration): LeaseResult {
        lock.writeMutex.lock()

        // 如果已有持有者且未过期，则拒绝
        match (currentOwner) {
            case Some(existingOwner) =>
                let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
                if (expireTime > now) {
                    if (existingOwner == owner) {
                        // 同一持有者，续约
                        expireTime = now + timeout.toMilliseconds()
                        lock.writeMutex.unlock()
                        return LeaseResult.createGranted("lease renewed")
                    }
                    lock.writeMutex.unlock()
                    return LeaseResult.createDenied("lease held by ${existingOwner}")
                }
            case None => ()
        }

        // 获取租约
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        currentOwner = Some(owner)
        expireTime = now + timeout.toMilliseconds()
        state = LeaseState.Leased

        // 触发事件
        match (eventHandler) {
            case Some(handler) => handler.onLeaseAcquired(config.leaseName, owner)
            case None => ()
        }

        lock.writeMutex.unlock()
        LeaseResult.createGranted("lease acquired")
    }

    public func release(owner: String): Bool {
        lock.writeMutex.lock()

        match (currentOwner) {
            case Some(existingOwner) =>
                if (existingOwner == owner) {
                    currentOwner = None
                    state = LeaseState.Released
                    expireTime = 0

                    match (eventHandler) {
                        case Some(handler) => handler.onLeaseReleased(config.leaseName, owner)
                        case None => ()
                    }
                    lock.writeMutex.unlock()
                    return true
                }
                lock.writeMutex.unlock()
                return false
            case None =>
                lock.writeMutex.unlock()
                return true
        }
    }

    public func check(): LeaseState {
        lock.readMutex.lock()

        match (currentOwner) {
            case Some(_) =>
                let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
                if (expireTime > now) {
                    lock.readMutex.unlock()
                    return state
                }
                // 租约已过期
                lock.readMutex.unlock()
                return LeaseState.Released
            case None =>
                lock.readMutex.unlock()
                return LeaseState.Released
        }
    }

    public func getOwner(): Option<String> {
        lock.readMutex.lock()
        let owner = currentOwner
        lock.readMutex.unlock()
        owner
    }

    public func renew(owner: String, timeout: Duration): Bool {
        lock.writeMutex.lock()

        match (currentOwner) {
            case Some(existingOwner) =>
                if (existingOwner == owner) {
                    let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
                    expireTime = now + timeout.toMilliseconds()
                    lock.writeMutex.unlock()
                    return true
                }
                lock.writeMutex.unlock()
                return false
            case None =>
                lock.writeMutex.unlock()
                return false
        }
    }
}

/**
 * 租约管理器
 * 管理多个租约实例
 */
public class LeaseManager {
    private let leases: HashMap<String, Lease>
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.leases = HashMap<String, Lease>()
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 注册租约
     */
    public func register(lease: Lease): Unit {
        lock.writeMutex.lock()
        leases.add(lease.name(), lease)
        lock.writeMutex.unlock()
    }

    /**
     * 获取租约
     */
    public func getLease(name: String): Option<Lease> {
        lock.readMutex.lock()
        let lease = leases.get(name)
        lock.readMutex.unlock()
        lease
    }

    /**
     * 检查租约是否存在
     */
    public func hasLease(name: String): Bool {
        lock.readMutex.lock()
        let exists = leases.contains(name)
        lock.readMutex.unlock()
        exists
    }

    /**
     * 获取所有租约名称
     */
    public func getLeaseNames(): ArrayList<String> {
        lock.readMutex.lock()
        let names = ArrayList<String>()
        for ((name, _) in leases) {
            names.add(name)
        }
        lock.readMutex.unlock()
        names
    }

    /**
     * 获取所有活跃租约
     */
    public func getActiveLeases(): ArrayList<String> {
        lock.readMutex.lock()
        let active = ArrayList<String>()
        for ((name, lease) in leases) {
            if (lease.check().isActive()) {
                active.add(name)
            }
        }
        lock.readMutex.unlock()
        active
    }
}

/**
 * 创建单主租约
 */
public func createSingleOwnerLease(leaseName: String, timeout: Duration): SingleOwnerLease {
    let config = LeaseConfig(leaseName, timeout)
    SingleOwnerLease(config)
}

/**
 * 创建租约管理器
 */
public func createLeaseManager(): LeaseManager {
    LeaseManager()
}
