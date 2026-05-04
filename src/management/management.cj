/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Akka Management 实现
 * 对标 Akka Management，提供集群管理 HTTP 端点
 */
package cactor.management

import std.collection.*
import std.sync.*
import cactor.api.http.*

// ============================================================================
// Management 配置
// ============================================================================

/**
 * Management 配置
 */
public class ManagementConfig {
    public var host: String
    public var port: Int32
    public var basePath: String
    public var enableHealthCheck: Bool
    public var enableClusterEndpoint: Bool
    public var enableReadinessCheck: Bool

    public init() {
        this.host = "0.0.0.0"
        this.port = 8558
        this.basePath = "/management"
        this.enableHealthCheck = true
        this.enableClusterEndpoint = true
        this.enableReadinessCheck = true
    }
}

// ============================================================================
// Health Check
// ============================================================================

/**
 * 健康检查严重程度
 */
public enum HealthSeverity <: ToString {
    | Healthy      // 健康
    | Degraded     // 降级
    | Unhealthy    // 不健康

    public func toString(): String {
        match (this) {
            case Healthy => "Healthy"
            case Degraded => "Degraded"
            case Unhealthy => "Unhealthy"
        }
    }
}

/**
 * 健康检查结果
 */
public class HealthResult {
    public let status: String
    public let severity: HealthSeverity
    public let timestamp: Int64
    public let details: HashMap<String, String>

    public init(status: String) {
        this.status = status
        this.severity = match (status) {
            case "UP" => HealthSeverity.Healthy
            case "DOWN" => HealthSeverity.Unhealthy
            case _ => HealthSeverity.Degraded
        }
        this.timestamp = 0
        this.details = HashMap<String, String>()
    }

    public init(status: String, severity: HealthSeverity) {
        this.status = status
        this.severity = severity
        this.timestamp = 0
        this.details = HashMap<String, String>()
    }

    public init(status: String, details: HashMap<String, String>) {
        this.status = status
        this.severity = match (status) {
            case "UP" => HealthSeverity.Healthy
            case "DOWN" => HealthSeverity.Unhealthy
            case _ => HealthSeverity.Degraded
        }
        this.timestamp = 0
        this.details = details
    }

    /**
     * 是否健康
     */
    public func isHealthy(): Bool {
        match (severity) {
            case HealthSeverity.Healthy => true
            case _ => false
        }
    }
}

/**
 * 健康检查接口
 */
public interface HealthCheck {
    func name(): String
    func check(): HealthResult
}

/**
 * 简单健康检查
 */
public class SimpleHealthCheck <: HealthCheck {
    private let checkName: String
    private let isHealthy: Bool

    public init(name: String, healthy: Bool) {
        this.checkName = name
        this.isHealthy = healthy
    }

    public func name(): String {
        checkName
    }

    public func check(): HealthResult {
        if (isHealthy) {
            HealthResult("UP")
        } else {
            HealthResult("DOWN")
        }
    }
}

/**
 * 组合健康检查 - 聚合多个健康检查
 */
public class CompositeHealthCheck <: HealthCheck {
    private let checkName: String
    private let checks: ArrayList<HealthCheck>
    private let failFast: Bool

    public init(name: String, failFast: Bool) {
        this.checkName = name
        this.checks = ArrayList<HealthCheck>()
        this.failFast = failFast
    }

    public func name(): String {
        checkName
    }

    /**
     * 添加子检查
     */
    public func addCheck(check: HealthCheck): CompositeHealthCheck {
        checks.add(check)
        this
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        var worstSeverity = HealthSeverity.Healthy

        for (c in checks) {
            let result = c.check()
            let _ = details.add(c.name(), result.status)

            // Track worst severity
            match (result.severity) {
                case HealthSeverity.Unhealthy =>
                    worstSeverity = HealthSeverity.Unhealthy
                    if (failFast) {
                        return HealthResult("DOWN", details)
                    }
                case HealthSeverity.Degraded =>
                    if (match (worstSeverity) {
                        case HealthSeverity.Healthy => true
                        case _ => false
                    }) {
                        worstSeverity = HealthSeverity.Degraded
                    }
                case HealthSeverity.Healthy => ()
            }
        }

        let status = match (worstSeverity) {
            case HealthSeverity.Healthy => "UP"
            case HealthSeverity.Degraded => "DEGRADED"
            case HealthSeverity.Unhealthy => "DOWN"
        }
        HealthResult(status, details)
    }
}

/**
 * 集群健康检查
 * 检查集群成员状态和可达性
 */
public class ClusterHealthCheck <: HealthCheck {
    private let endpoint: ClusterEndpoint
    private let minMembers: Int64

    public init(endpoint: ClusterEndpoint, minMembers: Int64) {
        this.endpoint = endpoint
        this.minMembers = minMembers
    }

    public init(endpoint: ClusterEndpoint) {
        this.endpoint = endpoint
        this.minMembers = 1
    }

    public func name(): String {
        "ClusterHealthCheck"
    }

    public func check(): HealthResult {
        let members = endpoint.getClusterMembers()
        let memberCount = members.size
        let details = HashMap<String, String>()
        let _ = details.add("memberCount", memberCount.toString())

        if (memberCount < minMembers) {
            HealthResult("DOWN", details)
        } else if (memberCount < 3) {
            HealthResult("DEGRADED", details)
        } else {
            HealthResult("UP", details)
        }
    }
}

/**
 * Liveness 健康检查
 * 简单的存活探针
 */
public class LivenessHealthCheck <: HealthCheck {
    private let isAlive: Bool

    public init(isAlive: Bool) {
        this.isAlive = isAlive
    }

    public func name(): String {
        "LivenessHealthCheck"
    }

    public func check(): HealthResult {
        if (isAlive) {
            HealthResult("UP")
        } else {
            HealthResult("DOWN")
        }
    }
}

/**
 * 健康检查注册表
 * 管理所有已注册的健康检查
 */
public class HealthCheckRegistry {
    private let checks: HashMap<String, HealthCheck>
    private let mutex: Mutex

    public init() {
        this.checks = HashMap<String, HealthCheck>()
        this.mutex = Mutex()
    }

    /**
     * 注册健康检查
     */
    public func register(name: String, check: HealthCheck): Unit {
        mutex.lock()
        try {
            checks.add(name, check)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 注销健康检查
     */
    public func unregister(name: String): Bool {
        mutex.lock()
        try {
            checks.remove(name).isSome()
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取检查
     */
    public func get(name: String): Option<HealthCheck> {
        mutex.lock()
        try {
            checks.get(name)
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取所有检查名称
     */
    public func getCheckNames(): ArrayList<String> {
        mutex.lock()
        try {
            let names = ArrayList<String>()
            for ((name, _) in checks) {
                names.add(name)
            }
            names
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 执行所有检查
     */
    public func checkAll(): ArrayList<(String, HealthResult)> {
        mutex.lock()
        let snapshot = ArrayList<(String, HealthCheck)>()
        try {
            for ((name, check) in checks) {
                snapshot.add((name, check))
            }
        } finally {
            mutex.unlock()
        }

        let results = ArrayList<(String, HealthResult)>()
        for ((name, check) in snapshot) {
            results.add((name, check.check()))
        }
        results
    }

    /**
     * 获取整体健康状态
     */
    public func getOverallHealth(): HealthResult {
        let results = checkAll()
        let details = HashMap<String, String>()

        var worstSeverity = HealthSeverity.Healthy
        for ((name, result) in results) {
            let _ = details.add(name, result.status)
            match (result.severity) {
                case HealthSeverity.Unhealthy =>
                    worstSeverity = HealthSeverity.Unhealthy
                case HealthSeverity.Degraded =>
                    if (match (worstSeverity) {
                        case HealthSeverity.Healthy => true
                        case _ => false
                    }) {
                        worstSeverity = HealthSeverity.Degraded
                    }
                case HealthSeverity.Healthy => ()
            }
        }

        let status = match (worstSeverity) {
            case HealthSeverity.Healthy => "UP"
            case HealthSeverity.Degraded => "DEGRADED"
            case HealthSeverity.Unhealthy => "DOWN"
        }
        HealthResult(status, details)
    }
}

// ============================================================================
// Readiness Check
// ============================================================================

/**
 * 就绪检查结果
 */
public class ReadinessResult {
    public let ready: Bool
    public let message: String

    public init(ready: Bool, message: String) {
        this.ready = ready
        this.message = message
    }
}

/**
 * 就绪检查接口
 */
public interface ReadinessCheck {
    func name(): String
    func check(): ReadinessResult
}

/**
 * 简单就绪检查
 */
public class SimpleReadinessCheck <: ReadinessCheck {
    private let checkName: String
    private let isReady: Bool

    public init(name: String, ready: Bool) {
        this.checkName = name
        this.isReady = ready
    }

    public func name(): String {
        checkName
    }

    public func check(): ReadinessResult {
        if (isReady) {
            ReadinessResult(true, "Ready")
        } else {
            ReadinessResult(false, "Not Ready")
        }
    }
}

// ============================================================================
// Cluster 管理端点
// ============================================================================

/**
 * 集群成员信息
 */
public class MemberInfo {
    public let node: String
    public let status: String
    public let roles: ArrayList<String>
    public let uptime: Int64

    public init(node: String, status: String, roles: ArrayList<String>) {
        this.node = node
        this.status = status
        this.roles = roles
        this.uptime = 0
    }
}

/**
 * 集群状态信息
 */
public class ClusterStateInfo {
    public var members: ArrayList<MemberInfo>
    public var leader: Option<String>

    public init() {
        this.members = ArrayList<MemberInfo>()
        this.leader = None
    }

    public func memberCount(): Int64 {
        var count = 0
        for (_ in members) {
            count++
        }
        count
    }
}

/**
 * 集群端点接口
 */
public interface ClusterEndpoint {
    func getClusterState(): ClusterStateInfo
    func getMember(address: String): Option<MemberInfo>
    func getClusterMembers(): ArrayList<MemberInfo>
    func getLeader(): Option<String>
}

// ============================================================================
// 内部集群端点实现
// ============================================================================

internal class InternalClusterEndpoint <: ClusterEndpoint {
    private let members: ArrayList<MemberInfo>
    private var currentLeader: Option<String>

    public init() {
        this.members = ArrayList<MemberInfo>()
        this.currentLeader = None
    }

    public func addMember(node: String, status: String, roles: ArrayList<String>): Unit {
        members.add(MemberInfo(node, status, roles))
    }

    public func setLeader(node: String): Unit {
        currentLeader = Some(node)
    }

    public func getClusterState(): ClusterStateInfo {
        let state = ClusterStateInfo()
        for (m in members) {
            state.members.add(m)
        }
        state.leader = currentLeader
        state
    }

    public func getMember(address: String): Option<MemberInfo> {
        for (m in members) {
            if (m.node == address) {
                return Some(m)
            }
        }
        None
    }

    public func getClusterMembers(): ArrayList<MemberInfo> {
        members
    }

    public func getLeader(): Option<String> {
        currentLeader
    }
}

// ============================================================================
// Management 服务器
// ============================================================================

/**
 * Management 服务器
 */
public class ManagementServer {
    private let config: ManagementConfig
    private let healthChecks: ArrayList<HealthCheck>
    private let readinessChecks: ArrayList<ReadinessCheck>
    private let clusterEndpoint: InternalClusterEndpoint
    private let isRunning: AtomicBool

    public init(config: ManagementConfig) {
        this.config = config
        this.healthChecks = ArrayList<HealthCheck>()
        this.readinessChecks = ArrayList<ReadinessCheck>()
        this.clusterEndpoint = InternalClusterEndpoint()
        this.isRunning = AtomicBool(false)
    }

    public init() {
        this.config = ManagementConfig()
        this.healthChecks = ArrayList<HealthCheck>()
        this.readinessChecks = ArrayList<ReadinessCheck>()
        this.clusterEndpoint = InternalClusterEndpoint()
        this.isRunning = AtomicBool(false)
    }

    /**
     * 添加健康检查
     */
    public func withHealthCheck(check: HealthCheck): ManagementServer {
        healthChecks.add(check)
        this
    }

    /**
     * 添加就绪检查
     */
    public func withReadinessCheck(check: ReadinessCheck): ManagementServer {
        readinessChecks.add(check)
        this
    }

    /**
     * 启动服务器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("Akka Management 启动在 ${config.host}:${config.port}${config.basePath}")
        }
    }

    /**
     * 停止服务器
     */
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("Akka Management 停止")
        }
    }

    /**
     * 获取 HTTP 服务器
     */
    public func httpServer(): HttpServer {
        HttpServer()
    }

    /**
     * 获取集群端点
     */
    public func getClusterEndpoint(): ClusterEndpoint {
        clusterEndpoint
    }
}

// ============================================================================
// Management 工厂
// ============================================================================

/**
 * Management 服务器工厂
 */
public class ManagementFactory {
    /**
     * 创建默认 Management 服务器
     */
    public static func create(): ManagementServer {
        ManagementServer()
    }

    /**
     * 创建带配置的 Management 服务器
     */
    public static func create(config: ManagementConfig): ManagementServer {
        ManagementServer(config)
    }
}
