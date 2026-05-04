/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting Middleware 示例
 * 演示 HTTP 请求限流中间件
 */
package cactor.examples

import std.collection.*
import std.time.*
import cactor.api.http.*

// ============================================================================
// Rate Limiting Middleware 示例演示
// ============================================================================

/**
 * 创建测试 HTTP 请求
 */
private func createRequest(ip: String, path: String): HttpRequest {
    let headers = HashMap<String, String>()
    HttpRequest(
        HttpMethod.GET,
        path,
        path,
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        Some(ip)
    )
}

/**
 * 创建带 Header 的请求
 */
private func createRequestWithHeader(ip: String, path: String, apiKey: String): HttpRequest {
    let headers = HashMap<String, String>()
    let _ = headers.add("X-Api-Key", apiKey)
    HttpRequest(
        HttpMethod.GET,
        path,
        path,
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        Some(ip)
    )
}

/**
 * 演示全局限流
 */
public func demonstrateGlobalRateLimit(): Unit {
    println("=== 全局限流演示 ===")

    // 严格的全局限流：每秒 2 个请求
    let config = RateLimitingMiddlewareConfig(
        2.0,    // 2 requests per second
        2,      // burst of 2
        1,      // 全局共享
        ClientIdentificationStrategy.IPAddress,
        RateLimitResponseConfig(60, "Too many requests"),
        true
    )

    let middleware = RateLimitingMiddleware(config)

    // 模拟多个客户端发送请求
    for (i in 0..5) {
        let request = createRequest("192.168.1.${i % 3 + 1}", "/api/test")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(response) =>
                println("请求 ${i + 1}: 被限流 (状态: ${response.status})")
            case None =>
                println("请求 ${i + 1}: 通过")
        }
    }

    let stats = middleware.getStats()
    println("统计: 总请求=${stats.totalRequests}, 拒绝=${stats.totalRejected}")
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
        ClientIdentificationStrategy.IPAddress,
        RateLimitResponseConfig.defaultConfig(),
        true
    )

    let middleware = RateLimitingMiddleware(config)

    // 客户端 1
    println("客户端 1 请求:")
    for (i in 0..3) {
        let request = createRequest("192.168.1.1", "/api/data")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("  请求 ${i + 1}: 被限流")
            case None => println("  请求 ${i + 1}: 通过")
        }
    }

    // 客户端 2 (独立限流)
    println("客户端 2 请求:")
    for (i in 0..3) {
        let request = createRequest("192.168.1.2", "/api/data")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("  请求 ${i + 1}: 被限流")
            case None => println("  请求 ${i + 1}: 通过")
        }
    }

    let stats = middleware.getStats()
    println("统计: 总请求=${stats.totalRequests}, 拒绝=${stats.totalRejected}, 活跃客户端=${stats.activeClients}")
    println()
}

/**
 * 演示基于 Header 的限流
 */
public func demonstrateHeaderBasedRateLimit(): Unit {
    println("=== 基于 Header 的限流演示 ===")

    let config = RateLimitingMiddlewareConfig(
        1.0,    // 1 request per second per API key
        1,      // burst of 1
        10000,
        ClientIdentificationStrategy.Header("X-Api-Key"),
        RateLimitResponseConfig.defaultConfig(),
        true
    )

    let middleware = RateLimitingMiddleware(config)

    // API Key 1 的请求
    println("API Key 'key-123' 请求:")
    for (i in 0..3) {
        let request = createRequestWithHeader("10.0.0.1", "/api/secure", "key-123")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("  请求 ${i + 1}: 被限流")
            case None => println("  请求 ${i + 1}: 通过")
        }
    }

    // API Key 2 的请求 (独立限流)
    println("API Key 'key-456' 请求:")
    for (i in 0..3) {
        let request = createRequestWithHeader("10.0.0.2", "/api/secure", "key-456")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("  请求 ${i + 1}: 被限流")
            case None => println("  请求 ${i + 1}: 通过")
        }
    }

    let stats = middleware.getStats()
    println("统计: 总请求=${stats.totalRequests}, 拒绝=${stats.totalRejected}")
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
        ClientIdentificationStrategy.IPAddress,
        RateLimitResponseConfig.defaultConfig(),
        false  // 禁用
    )

    let middleware = RateLimitingMiddleware(config)

    // 即使配置了严格的限流，禁用后也应该全部通过
    for (i in 0..5) {
        let request = createRequest("192.168.1.1", "/api/test")
        let result = middleware.handleRequest(request)
        match (result) {
            case Some(_) => println("请求 ${i + 1}: 被限流 (不应该发生!)")
            case None => println("请求 ${i + 1}: 通过 (限流已禁用)")
        }
    }
    println()
}

/**
 * 演示限流响应头
 */
public func demonstrateRateLimitHeaders(): Unit {
    println("=== 限流响应头演示 ===")

    let middleware = RateLimitingMiddleware()
    let response = middleware.createRejectedResponse()

    println("被限流时的响应:")
    println("  状态码: ${response.status}")
    match (response.headers.get("Retry-After")) {
        case Some(v) => println("  Retry-After: ${v}")
        case None => println("  Retry-After: (未设置)")
    }
    match (response.headers.get("X-RateLimit-Limit")) {
        case Some(v) => println("  X-RateLimit-Limit: ${v}")
        case None => println("  X-RateLimit-Limit: (未设置)")
    }
    match (response.headers.get("X-RateLimit-Remaining")) {
        case Some(v) => println("  X-RateLimit-Remaining: ${v}")
        case None => println("  X-RateLimit-Remaining: (未设置)")
    }
    println()
}

/**
 * 运行所有演示
 */
public func main(): Unit {
    println("========================================")
    println("   CActor Rate Limiting Middleware 演示")
    println("========================================")
    println()

    demonstrateRateLimitHeaders()
    demonstrateDisabledRateLimit()
    demonstrateGlobalRateLimit()
    demonstratePerClientRateLimit()
    demonstrateHeaderBasedRateLimit()

    println("========================================")
    println("   Rate Limiting Middleware 演示完成!")
    println("========================================")
}