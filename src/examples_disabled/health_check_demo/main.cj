/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Health Check 示例程序
 * 演示健康检查增强功能
 */
package cactor.examples.health_check_demo

import std.collection.*
import std.time.*
import cactor.management.*

// ============================================================================
// Health Check 示例演示
// ============================================================================

/**
 * 自定义健康检查：内存使用检查
 */
public class MemoryHealthCheck <: HealthCheck {
    private let maxUsageMB: Int64

    public init(maxUsageMB: Int64) {
        this.maxUsageMB = maxUsageMB
    }

    public func name(): String {
        "MemoryHealthCheck"
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        // 模拟内存使用
        let usageMB: Int64 = 512
        let _ = details.add("currentUsageMB", usageMB.toString())
        let _ = details.add("maxUsageMB", maxUsageMB.toString())

        if (usageMB > maxUsageMB) {
            HealthResult("DOWN", details)
        } else if (usageMB > maxUsageMB * 80 / 100) {
            HealthResult("DEGRADED", details)
        } else {
            HealthResult("UP", details)
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

    public func name(): String {
        "DatabaseHealthCheck"
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        let _ = details.add("connectionString", connectionString)
        // 模拟健康状态
        HealthResult("UP", details)
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

    public func name(): String {
        "ExternalServiceHealthCheck(${serviceName})"
    }

    public func check(): HealthResult {
        let details = HashMap<String, String>()
        let _ = details.add("service", serviceName)
        let _ = details.add("reachable", isHealthy.toString())

        if (isHealthy) {
            HealthResult("UP", details)
        } else {
            HealthResult("DOWN", details)
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

    let checks = [
        (memoryCheck, "内存检查"),
        (dbCheck, "数据库检查"),
        (apiCheck, "API 网关检查"),
        (paymentCheck, "支付服务检查")
    ]

    for ((check, name) in checks) {
        let result = check.check()
        println("${name}: ${result.status}")
        if (result.details.size > 0) {
            for ((key, value) in result.details) {
                println("  ${key}: ${value}")
            }
        }
    }
    println()
}

/**
 * 演示组合健康检查
 */
public func demonstrateCompositeHealthCheck(): Unit {
    println("=== 组合健康检查演示 ===")

    // 创建组合检查
    let composite = CompositeHealthCheck("SystemHealth", true)  // failFast = true

    // 添加子检查
    composite.addCheck(MemoryHealthCheck(1024))
    composite.addCheck(DatabaseHealthCheck("postgres://localhost:5432/app"))
    composite.addCheck(ExternalServiceHealthCheck("api-gateway", true))
    composite.addCheck(ExternalServiceHealthCheck("payment-service", false))

    println("执行组合健康检查 (failFast=true):")
    let result = composite.check()
    println("最终状态: ${result.status}")
    println("严重程度: ${result.severity}")

    if (result.details.size > 0) {
        println("详细信息:")
        for ((name, status) in result.details) {
            println("  ${name}: ${status}")
        }
    }
    println()
}

/**
 * 演示健康检查注册表
 */
public func demonstrateHealthCheckRegistry(): Unit {
    println("=== 健康检查注册表演示 ===")

    let registry = HealthCheckRegistry()

    // 注册健康检查
    registry.register("memory", MemoryHealthCheck(1024))
    registry.register("database", DatabaseHealthCheck("postgres://localhost:5432/app"))
    registry.register("api-gateway", ExternalServiceHealthCheck("api-gateway", true))
    registry.register("payment", ExternalServiceHealthCheck("payment-service", false))

    println("已注册检查: ${registry.getCheckNames().size} 个")
    for (name in registry.getCheckNames()) {
        println("  - ${name}")
    }
    println()

    // 执行所有检查
    println("执行所有检查:")
    let results = registry.checkAll()
    for ((name, result) in results) {
        println("  ${name}: ${result.status}")
    }
    println()

    // 获取整体健康状态
    let overall = registry.getOverallHealth()
    println("整体健康状态: ${overall.status}")
    println("严重程度: ${overall.severity}")
    println()
}

/**
 * 演示集群健康检查
 */
public func demonstrateClusterHealthCheck(): Unit {
    println("=== 集群健康检查演示 ===")

    let endpoint = InternalClusterEndpoint()
    let roles = ArrayList<String>()
    roles.add("member")

    // 添加集群成员
    endpoint.addMember("node-1", "Up", roles)
    endpoint.addMember("node-2", "Up", roles)
    endpoint.addMember("node-3", "Up", roles)
    endpoint.setLeader("node-1")

    // 创建集群健康检查
    let clusterCheck = ClusterHealthCheck(endpoint, 2)

    println("检查集群健康状态 (最小成员数: 2):")
    let result = clusterCheck.check()
    println("状态: ${result.status}")

    if (result.details.size > 0) {
        for ((key, value) in result.details) {
            println("  ${key}: ${value}")
        }
    }
    println()
}

/**
 * 演示存活探针
 */
public func demonstrateLivenessHealthCheck(): Unit {
    println("=== 存活探针演示 ===")

    // 创建存活探针
    let healthyCheck = LivenessHealthCheck(true)
    let unhealthyCheck = LivenessHealthCheck(false)

    println("健康状态存活探针:")
    let healthyResult = healthyCheck.check()
    println("  状态: ${healthyResult.status}")
    println("  是否健康: ${healthyResult.isHealthy()}")
    println()

    println("不健康状态存活探针:")
    let unhealthyResult = unhealthyCheck.check()
    println("  状态: ${unhealthyResult.status}")
    println("  是否健康: ${unhealthyResult.isHealthy()}")
    println()
}

/**
 * 演示严重程度枚举
 */
public func demonstrateSeverityLevels(): Unit {
    println("=== 严重程度级别演示 ===")

    let healthy = HealthSeverity.Healthy
    let degraded = HealthSeverity.Degraded
    let unhealthy = HealthSeverity.Unhealthy

    println("严重程度级别:")
    println("  Healthy: ${healthy.toString()}")
    println("  Degraded: ${degraded.toString()}")
    println("  Unhealthy: ${unhealthy.toString()}")
    println()

    // 模拟不同状态的健康结果
    let upResult = HealthResult("UP", HealthSeverity.Healthy)
    let degradedResult = HealthResult("DEGRADED", HealthSeverity.Degraded)
    let downResult = HealthResult("DOWN", HealthSeverity.Unhealthy)

    println("健康结果示例:")
    println("  UP: ${upResult.severity.toString()}, isHealthy=${upResult.isHealthy()}")
    println("  DEGRADED: ${degradedResult.severity.toString()}, isHealthy=${degradedResult.isHealthy()}")
    println("  DOWN: ${downResult.severity.toString()}, isHealthy=${downResult.isHealthy()}")
    println()
}

/**
 * 运行所有演示
 */
main(): Unit {
    println("========================================")
    println("   CActor Health Check 健康检查演示")
    println("========================================")
    println()

    demonstrateSeverityLevels()
    demonstrateSimpleHealthChecks()
    demonstrateCompositeHealthCheck()
    demonstrateHealthCheckRegistry()
    demonstrateClusterHealthCheck()
    demonstrateLivenessHealthCheck()

    println("========================================")
    println("   Health Check 演示完成!")
    println("========================================")
}