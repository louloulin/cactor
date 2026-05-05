/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Health Check 示例程序
 * 演示健康检查功能
 */
package cactor.examples.health_check_demo

import std.collection.*
import std.time.*

// ============================================================================
// Health Check 示例演示
// ============================================================================

/**
 * 健康状态枚举
 */
public enum HealthStatus {
    | Up
    | Down
    | Degraded
    | Unknown
}

/**
 * 健康结果
 */
public class HealthResult {
    public let status: HealthStatus
    public let details: HashMap<String, String>
    public let timestamp: Int64

    public init(status: HealthStatus) {
        this.status = status
        this.details = HashMap<String, String>()
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public init(status: HealthStatus, details: HashMap<String, String>) {
        this.status = status
        this.details = details
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func isHealthy(): Bool {
        match (status) {
            case Up => true
            case _ => false
        }
    }
}

/**
 * 健康检查接口
 */
public interface HealthCheck {
    func check(): HealthResult
}

/**
 * 自定义健康检查：内存使用检查
 */
public class MemoryHealthCheck <: HealthCheck {
    private let maxUsageMB: Int64

    public init(maxUsageMB: Int64) {
        this.maxUsageMB = maxUsageMB
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        // 模拟内存使用
        let usageMB: Int64 = 512
        details.add("currentUsageMB", usageMB.toString())
        details.add("maxUsageMB", maxUsageMB.toString())

        if (usageMB > maxUsageMB) {
            HealthResult(Down, details)
        } else if (usageMB > maxUsageMB * 80 / 100) {
            HealthResult(Degraded, details)
        } else {
            HealthResult(Up, details)
        }
    }
}

/**
 * 自定义健康检查：数据库连接检查
 */
public class DatabaseHealthCheck <: HealthCheck {
    private let connectionString: String

    public init(connectionString: String) {
        this.connectionString = connectionString
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        details.add("connectionString", connectionString)
        // 模拟健康状态
        HealthResult(Up, details)
    }
}

/**
 * 自定义健康检查：外部服务检查
 */
public class ExternalServiceHealthCheck <: HealthCheck {
    private let serviceName: String
    private let isHealthy: Bool

    public init(serviceName: String, isHealthy: Bool) {
        this.serviceName = serviceName
        this.isHealthy = isHealthy
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        details.add("service", serviceName)
        details.add("reachable", isHealthy.toString())

        if (isHealthy) {
            HealthResult(Up, details)
        } else {
            HealthResult(Down, details)
        }
    }
}

/**
 * 演示简单健康检查
 */
public func demonstrateSimpleHealthChecks(): Unit {
    println("=== 简单健康检查演示 ===")

    // 创建各种健康检查
    let memoryCheck = MemoryHealthCheck(1024)
    let dbCheck = DatabaseHealthCheck("postgres://localhost:5432/app")
    let apiCheck = ExternalServiceHealthCheck("api-gateway", true)
    let paymentCheck = ExternalServiceHealthCheck("payment-service", false)

    println("执行健康检查:")
    println()

    let checks = ArrayList<(HealthCheck, String)>()
    checks.add((memoryCheck, "内存检查"))
    checks.add((dbCheck, "数据库检查"))
    checks.add((apiCheck, "API 网关检查"))
    checks.add((paymentCheck, "支付服务检查"))

    for ((check, name) in checks) {
        let result = check.check()
        let statusStr = match (result.status) {
            case Up => "UP"
            case Down => "DOWN"
            case Degraded => "DEGRADED"
            case Unknown => "UNKNOWN"
        }
        println("${name}: ${statusStr}")
        if (result.details.size > 0) {
            for ((key, value) in result.details) {
                println("  ${key}: ${value}")
            }
        }
    }
    println()
}

/**
 * 演示健康状态统计
 */
public func demonstrateHealthStats(): Unit {
    println("=== 健康状态统计演示 ===")

    let checks = ArrayList<HealthCheck>()
    checks.add(MemoryHealthCheck(1024))
    checks.add(DatabaseHealthCheck("postgres://localhost:5432/app"))
    checks.add(ExternalServiceHealthCheck("api-gateway", true))

    var healthyCount = 0
    var unhealthyCount = 0

    for (check in checks) {
        let result = check.check()
        if (result.isHealthy()) {
            healthyCount += 1
        } else {
            unhealthyCount += 1
        }
    }

    println("健康检查统计:")
    println("  健康: ${healthyCount}")
    println("  不健康: ${unhealthyCount}")
    println("  总计: ${checks.size}")
    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor Health Check 健康检查演示")
    println("========================================")
    println()

    demonstrateSimpleHealthChecks()
    demonstrateHealthStats()

    println("========================================")
    println("   Health Check 演示完成!")
    println("========================================")
}
