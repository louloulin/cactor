/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting Middleware
 * HTTP 请求限流中间件
 */
package cactor.api.http

import std.collection.*
import std.sync.*
import std.time.*
import cactor.foundation.*

/**
 * 客户端标识策略
 */
public enum ClientIdentificationStrategy {
    | IPAddress              // 基于 IP 地址
    | Header(String)          // 基于指定 Header
    | IPOrHeader(String)     // IP 优先，fallback 到 Header
}

/**
 * 限流响应配置
 */
public class RateLimitResponseConfig {
    public let retryAfterSeconds: Int64
    public let message: String

    public init(retryAfterSeconds: Int64, message: String) {
        this.retryAfterSeconds = retryAfterSeconds
        this.message = message
    }

    public static func defaultConfig(): RateLimitResponseConfig {
        RateLimitResponseConfig(60, "Rate limit exceeded. Please retry later.")
    }
}

/**
 * 限流中间件配置
 */
public class RateLimitingMiddlewareConfig {
    public let requestsPerSecond: Float64
    public let burstSize: Int64
    public let maxClients: Int64
    public let clientStrategy: ClientIdentificationStrategy
    public let responseConfig: RateLimitResponseConfig
    public let enabled: Bool

    public init(
        requestsPerSecond: Float64,
        burstSize: Int64,
        maxClients: Int64,
        clientStrategy: ClientIdentificationStrategy,
        responseConfig: RateLimitResponseConfig,
        enabled: Bool
    ) {
        this.requestsPerSecond = requestsPerSecond
        this.burstSize = burstSize
        this.maxClients = maxClients
        this.clientStrategy = clientStrategy
        this.responseConfig = responseConfig
        this.enabled = enabled
    }

    public static func defaultConfig(): RateLimitingMiddlewareConfig {
        RateLimitingMiddlewareConfig(
            100.0,      // 100 requests per second per client
            200,        // burst size
            10000,      // max 10000 unique clients
            ClientIdentificationStrategy.IPAddress,
            RateLimitResponseConfig.defaultConfig(),
            true
        )
    }

    /**
     * 创建全局限流配置（所有客户端共享一个限流器）
     */
    public static func globalLimit(rps: Float64, burst: Int64): RateLimitingMiddlewareConfig {
        RateLimitingMiddlewareConfig(
            rps,
            burst,
            1,
            ClientIdentificationStrategy.IPAddress,
            RateLimitResponseConfig.defaultConfig(),
            true
        )
    }

    /**
     * 创建按客户端限流配置
     */
    public static func perClientLimit(rps: Float64, burst: Int64, maxClients: Int64): RateLimitingMiddlewareConfig {
        RateLimitingMiddlewareConfig(
            rps,
            burst,
            maxClients,
            ClientIdentificationStrategy.IPAddress,
            RateLimitResponseConfig.defaultConfig(),
            true
        )
    }
}

/**
 * 限流中间件
 * 对请求进行限流，支持全局限流和按客户端限流
 */
public class RateLimitingMiddleware {
    private let config: RateLimitingMiddlewareConfig
    private let globalLimiter: TokenBucketRateLimiter
    private let clientLimiters: HashMap<String, TokenBucketRateLimiter>
    private let lock: ReentrantReadWriteMutex
    private var totalRequests: Int64
    private var totalRejected: Int64

    public init(config: RateLimitingMiddlewareConfig) {
        this.config = config
        this.globalLimiter = TokenBucketRateLimiter(
            RateLimitConfig(config.requestsPerSecond, config.burstSize, 10000)
        )
        this.clientLimiters = HashMap<String, TokenBucketRateLimiter>()
        this.lock = ReentrantReadWriteMutex()
        this.totalRequests = 0
        this.totalRejected = 0
    }

    public init() {
        this(RateLimitingMiddlewareConfig.defaultConfig())
    }

    /**
     * 获取客户端标识
     */
    private func getClientIdentifier(request: HttpRequest): String {
        match (config.clientStrategy) {
            case ClientIdentificationStrategy.IPAddress =>
                match (request.remoteAddress) {
                    case Some(ip) => ip
                    case None => "unknown"
                }
            case ClientIdentificationStrategy.Header(headerName) =>
                match (request.header(headerName)) {
                    case Some(value) => value
                    case None => "unknown"
                }
            case ClientIdentificationStrategy.IPOrHeader(headerName) =>
                let ip = match (request.remoteAddress) {
                    case Some(addr) => addr
                    case None => ""
                }
                if (ip != "" && ip != "unknown") {
                    ip
                } else {
                    match (request.header(headerName)) {
                        case Some(value) => value
                        case None => "unknown"
                    }
                }
        }
    }

    /**
     * 获取或创建客户端限流器
     */
    private func getOrCreateClientLimiter(clientId: String): TokenBucketRateLimiter {
        lock.writeMutex.lock()
        defer { lock.writeMutex.unlock() }

        match (clientLimiters.get(clientId)) {
            case Some(limiter) => limiter
            case None =>
                // 检查是否超过最大客户端数
                if (clientLimiters.size >= config.maxClients) {
                    return globalLimiter
                }
                let limiter = TokenBucketRateLimiter(
                    RateLimitConfig(config.requestsPerSecond, config.burstSize, 1000)
                )
                clientLimiters.add(clientId, limiter)
                limiter
        }
    }

    /**
     * 检查是否允许请求
     */
    public func isAllowed(request: HttpRequest): Bool {
        if (!config.enabled) {
            return true
        }

        lock.writeMutex.lock()
        totalRequests += 1
        lock.writeMutex.unlock()

        // 使用全局限流器或客户端限流器
        let limiter = if (config.maxClients > 1) {
            let clientId = getClientIdentifier(request)
            getOrCreateClientLimiter(clientId)
        } else {
            globalLimiter
        }

        let result = limiter.tryAcquire()
        match (result) {
            case RateLimitResult.Allowed(_) => true
            case RateLimitResult.Rejected(_) =>
                lock.writeMutex.lock()
                totalRejected += 1
                lock.writeMutex.unlock()
                false
        }
    }

    /**
     * 创建被拒绝的响应
     */
    public func createRejectedResponse(): HttpResponse {
        let headers = HashMap<String, String>()
        let _ = headers.add("Content-Type", "application/json")
        let _ = headers.add("Retry-After", config.responseConfig.retryAfterSeconds.toString())
        let _ = headers.add("X-RateLimit-Limit", config.requestsPerSecond.toString())
        let _ = headers.add("X-RateLimit-Remaining", "0")

        HttpResponse(
            HttpStatus.TooManyRequests,
            headers,
            Array<UInt8>(0, { i: Int64 => 0u8 })
        )
    }

    /**
     * 处理请求
     * 如果被限流返回拒绝响应，否则返回 None
     */
    public func handleRequest(request: HttpRequest): Option<HttpResponse> {
        if (!config.enabled) {
            return None
        }

        if (!isAllowed(request)) {
            return Some(createRejectedResponse())
        }
        None
    }

    /**
     * 获取统计信息
     */
    public func getStats(): RateLimitStats {
        lock.readMutex.lock()
        let stats = RateLimitStats(
            totalRequests,
            totalRejected,
            clientLimiters.size
        )
        lock.readMutex.unlock()
        stats
    }

    /**
     * 重置统计
     */
    public func resetStats(): Unit {
        lock.writeMutex.lock()
        totalRequests = 0
        totalRejected = 0
        lock.writeMutex.unlock()
    }
}

/**
 * 限流统计
 */
public class RateLimitStats {
    public let totalRequests: Int64
    public let totalRejected: Int64
    public let activeClients: Int64

    public init(totalRequests: Int64, totalRejected: Int64, activeClients: Int64) {
        this.totalRequests = totalRequests
        this.totalRejected = totalRejected
        this.activeClients = activeClients
    }

    public func rejectionRate(): Float64 {
        if (totalRequests == 0) {
            return 0.0
        }
        Float64(totalRejected) / Float64(totalRequests)
    }
}

/**
 * 限流中间件工厂
 */
public class RateLimitingMiddlewareFactory {
    /**
     * 创建默认限流中间件
     */
    public static func create(): RateLimitingMiddleware {
        RateLimitingMiddleware()
    }

    /**
     * 创建全局限流中间件
     */
    public static func createGlobal(rps: Float64, burst: Int64): RateLimitingMiddleware {
        RateLimitingMiddleware(
            RateLimitingMiddlewareConfig.globalLimit(rps, burst)
        )
    }

    /**
     * 创建按客户端限流中间件
     */
    public static func createPerClient(rps: Float64, burst: Int64, maxClients: Int64): RateLimitingMiddleware {
        RateLimitingMiddleware(
            RateLimitingMiddlewareConfig.perClientLimit(rps, burst, maxClients)
        )
    }

    /**
     * 创建严格限流中间件
     */
    public static func createStrict(): RateLimitingMiddleware {
        RateLimitingMiddleware(
            RateLimitingMiddlewareConfig(
                10.0,     // 10 requests per second
                20,       // small burst
                10000,
                ClientIdentificationStrategy.IPAddress,
                RateLimitResponseConfig(60, "Rate limit exceeded"),
                true
            )
        )
    }
}
