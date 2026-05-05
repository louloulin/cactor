/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting Middleware 示例
 * 演示请求限流中间件
 */
package cactor.examples.rate_limiting_middleware_demo

import std.collection.*
import std.time.*

// ============================================================================
// Rate Limiting Middleware 示例演示
// ============================================================================

/**
 * 限流统计
 */
public class RateLimitStats {
    public var totalRequests: Int64
    public var totalAllowed: Int64
    public var totalRejected: Int64

    public init() {
        totalRequests = 0
        totalAllowed = 0
        totalRejected = 0
    }

    public func recordAllowed(): Unit {
        totalRequests += 1
        totalAllowed += 1
    }

    public func recordRejected(): Unit {
        totalRequests += 1
        totalRejected += 1
    }
}

/**
 * 模拟 HTTP 请求
 */
public class HttpRequest {
    public let clientIp: String
    public let path: String

    public init(clientIp: String, path: String) {
        this.clientIp = clientIp
        this.path = path
    }
}

/**
 * 模拟 HTTP 响应
 */
public class HttpResponse {
    public let status: Int32

    public init(status: Int32) {
        this.status = status
    }
}

/**
 * 限流中间件配置
 */
public class RateLimitingMiddlewareConfig {
    public let ratePerSecond: Float64
    public let burstSize: Int64
    public let maxClients: Int64
    public let enabled: Bool

    public init(
        ratePerSecond: Float64,
        burstSize: Int64,
        maxClients: Int64,
        enabled: Bool
    ) {
        this.ratePerSecond = ratePerSecond
        this.burstSize = burstSize
        this.maxClients = maxClients
        this.enabled = enabled
    }
}

/**
 * 限流中间件
 */
public class RateLimitingMiddleware {
    private let config: RateLimitingMiddlewareConfig
    private let clientTokens: HashMap<String, Int64>
    private let stats: RateLimitStats

    public init(config: RateLimitingMiddlewareConfig) {
        this.config = config
        this.clientTokens = HashMap<String, Int64>()
        this.stats = RateLimitStats()
    }

    public init() {
        this.config = RateLimitingMiddlewareConfig(
            1.0,  // ratePerSecond
            10,   // burstSize
            1000, // maxClients
            true  // enabled
        )
        this.clientTokens = HashMap<String, Int64>()
        this.stats = RateLimitStats()
    }

    private func tryAcquireToken(clientId: String): Bool {
        match (clientTokens.get(clientId)) {
            case Some(tokens) => this.useToken(clientId, tokens)
            case None => this.registerClient(clientId)
        }
    }

    private func useToken(clientId: String, tokens: Int64): Bool {
        if (tokens > 0) {
            clientTokens.remove(clientId)
            clientTokens.add(clientId, tokens - 1)
            true
        } else {
            false
        }
    }

    private func registerClient(clientId: String): Bool {
        if (clientTokens.size < config.maxClients) {
            clientTokens.add(clientId, config.burstSize - 1)
            true
        } else {
            false
        }
    }

    public func handleRequest(request: HttpRequest): Option<HttpResponse> {
        if (!config.enabled) {
            stats.recordAllowed()
            return None
        }

        let clientId = request.clientIp
        let allowed = tryAcquireToken(clientId)

        if (allowed) {
            stats.recordAllowed()
            None
        } else {
            stats.recordRejected()
            Some(HttpResponse(429))
        }
    }

    public func getStats(): RateLimitStats {
        stats
    }
}

/**
 * 演示全局限流
 */
public func demonstrateGlobalRateLimit(): Unit {
    println("=== 全局限流演示 ===")

    // 严格的全局限流
    let config = RateLimitingMiddlewareConfig(
        2.0,    // 2 requests per second
        2,      // burst of 2
        1,      // 全局共享
        true
    )

    let middleware = RateLimitingMiddleware(config)

    // 模拟多个客户端发送请求
    for (i in 0..5) {
        let request = HttpRequest("192.168.1.1", "/api/test")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(response) =>
                println("请求 ${i + 1}: 被限流 (状态: ${response.status})")
            case None =>
                println("请求 ${i + 1}: 通过")
        }
    }

    let stats = middleware.getStats()
    println("统计: 总请求=${stats.totalRequests}, 允许=${stats.totalAllowed}, 拒绝=${stats.totalRejected}")
    println()
}

/**
 * 演示按客户端限流
 */
public func demonstratePerClientRateLimit(): Unit {
    println("=== 按客户端限流演示 ===")

    // 每秒 1 个请求 per client
    let config = RateLimitingMiddlewareConfig(
        1.0,    // 1 request per second per client
        1,      // burst of 1
        10000,  // max 10000 clients
        true
    )

    let middleware = RateLimitingMiddleware(config)

    // 客户端 1
    println("客户端 1 请求:")
    for (i in 0..3) {
        let request = HttpRequest("192.168.1.1", "/api/data")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("  请求 ${i + 1}: 被限流")
            case None => println("  请求 ${i + 1}: 通过")
        }
    }

    // 客户端 2 (独立限流)
    println("客户端 2 请求:")
    for (i in 0..3) {
        let request = HttpRequest("192.168.1.2", "/api/data")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("  请求 ${i + 1}: 被限流")
            case None => println("  请求 ${i + 1}: 通过")
        }
    }

    let stats = middleware.getStats()
    println("统计: 总请求=${stats.totalRequests}, 允许=${stats.totalAllowed}, 拒绝=${stats.totalRejected}")
    println()
}

/**
 * 演示禁用限流
 */
public func demonstrateDisabledRateLimit(): Unit {
    println("=== 禁用限流演示 ===")

    let config = RateLimitingMiddlewareConfig(
        1.0,
        1,
        10000,
        false  // 禁用
    )

    let middleware = RateLimitingMiddleware(config)

    // 即使配置了严格的限流，禁用后也应该全部通过
    for (i in 0..5) {
        let request = HttpRequest("192.168.1.1", "/api/test")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("请求 ${i + 1}: 被限流 (不应该发生!)")
            case None => println("请求 ${i + 1}: 通过 (限流已禁用)")
        }
    }
    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor Rate Limiting Middleware 演示")
    println("========================================")
    println()

    demonstrateDisabledRateLimit()
    demonstrateGlobalRateLimit()
    demonstratePerClientRateLimit()

    println("========================================")
    println("   Rate Limiting Middleware 演示完成!")
    println("========================================")
}
