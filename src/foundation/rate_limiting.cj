/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting 限流机制
 * 对标 Akka 限流机制
 * 实现 TokenBucket 和 LeakyBucket 算法
 */
package cactor.foundation

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 限流结果
 */
public enum RateLimitResult {
    | Allowed(count: Int64)
    | Rejected(waitTime: Int64)  // 等待时间（纳秒）
}

/**
 * 限流配置
 */
public class RateLimitConfig {
    public let requestsPerSecond: Float64
    public let burstSize: Int64
    public let maxQueueSize: Int64

    public init(requestsPerSecond: Float64, burstSize: Int64, maxQueueSize: Int64) {
        this.requestsPerSecond = requestsPerSecond
        this.burstSize = burstSize
        this.maxQueueSize = maxQueueSize
    }
}

/**
 * 限流器接口
 */
public interface RateLimiter {
    /**
     * 尝试获取许可
     * @return RateLimitResult 允许或拒绝
     */
    public func tryAcquire(): RateLimitResult

    /**
     * 尝试获取指定数量的许可
     */
    public func tryAcquire(count: Int64): RateLimitResult

    /**
     * 同步获取许可（阻塞等待）
     */
    public func acquire(): Bool

    /**
     * 同步获取指定数量许可
     */
    public func acquire(count: Int64): Bool

    /**
     * 获取当前可用令牌数
     */
    public func available(): Int64

    /**
     * 重置限流器
     */
    public func reset(): Unit
}

/**
 * TokenBucket 限流器
 * 对标 Guava RateLimiter / Akka RateLimiter
 * 支持突发流量和匀速发放
 */
public class TokenBucketRateLimiter <: RateLimiter {
    private let config: RateLimitConfig
    private var tokens: Float64
    private var lastRefillTime: Int64
    private let lock: ReentrantReadWriteMutex
    private var totalRequests: Int64
    private var rejectedRequests: Int64

    public init(config: RateLimitConfig) {
        this.config = config
        this.tokens = Float64(config.burstSize)  // 初始满桶
        this.lastRefillTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.lock = ReentrantReadWriteMutex()
        this.totalRequests = 0
        this.rejectedRequests = 0
    }

    /**
     * 创建每秒指定请求数的限流器
     */
    public static func create(rps: Float64): TokenBucketRateLimiter {
        let config = RateLimitConfig(rps, Int64(rps * 2.0), 1000)
        TokenBucketRateLimiter(config)
    }

    /**
     * 创建带突发大小的限流器
     */
    public static func create(rps: Float64, burstSize: Int64): TokenBucketRateLimiter {
        let config = RateLimitConfig(rps, burstSize, 1000)
        TokenBucketRateLimiter(config)
    }

    public func tryAcquire(): RateLimitResult {
        tryAcquireWithLock(1)
    }

    public func tryAcquire(count: Int64): RateLimitResult {
        if (count <= 0) {
            return RateLimitResult.Allowed(0)
        }
        tryAcquireWithLock(count)
    }

    private func tryAcquireWithLock(count: Int64): RateLimitResult {
        lock.writeMutex.lock()
        refillTokens()
        if (tokens >= Float64(count)) {
            tokens -= Float64(count)
            totalRequests += 1
            lock.writeMutex.unlock()
            RateLimitResult.Allowed(count)
        } else {
            rejectedRequests += 1
            let waitNanos = Int64((Float64(count) - tokens) * 1_000_000_000.0 / config.requestsPerSecond)
            lock.writeMutex.unlock()
            RateLimitResult.Rejected(waitNanos)
        }
    }

    public func acquire(): Bool {
        match (tryAcquire()) {
            case RateLimitResult.Allowed(_) => true
            case RateLimitResult.Rejected(waitNanos) =>
                // 简单等待（实际使用应考虑取消）
                let waitMs = waitNanos / 1_000_000
                if (waitMs > 0) {
                    Thread.sleep(Duration.millisecond * waitMs)
                }
                // 重试
                match (tryAcquire()) {
                    case RateLimitResult.Allowed(_) => true
                    case _ => false
                }
        }
    }

    public func acquire(count: Int64): Bool {
        match (tryAcquire(count)) {
            case RateLimitResult.Allowed(_) => true
            case RateLimitResult.Rejected(_) => false
        }
    }

    public func available(): Int64 {
        lock.writeMutex.lock()
        refillTokens()
        let avail = Int64(tokens)
        lock.writeMutex.unlock()
        avail
    }

    public func reset(): Unit {
        lock.writeMutex.lock()
        tokens = Float64(config.burstSize)
        lastRefillTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        lock.writeMutex.unlock()
    }

    /**
     * 补充令牌
     */
    private func refillTokens(): Unit {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let elapsed = now - lastRefillTime
        if (elapsed > 0) {
            let tokensToAdd = (Float64(elapsed) / 1000.0) * config.requestsPerSecond
            tokens = Float64.min(tokens + tokensToAdd, Float64(config.burstSize))
            lastRefillTime = now
        }
    }

    /**
     * 获取总请求数
     */
    public func getTotalRequests(): Int64 {
        lock.readMutex.lock()
        let total = totalRequests
        lock.readMutex.unlock()
        total
    }

    /**
     * 获取拒绝请求数
     */
    public func getRejectedRequests(): Int64 {
        lock.readMutex.lock()
        let rejected = rejectedRequests
        lock.readMutex.unlock()
        rejected
    }

    /**
     * 获取当前速率
     */
    public func getCurrentRate(): Float64 {
        lock.readMutex.lock()
        let rate = config.requestsPerSecond
        lock.readMutex.unlock()
        rate
    }

    /**
     * 获取配置
     */
    public func getConfig(): RateLimitConfig {
        config
    }
}

/**
 * 滑动窗口限流器
 * 使用滑动窗口算法统计时间窗口内的请求数
 */
public class SlidingWindowRateLimiter <: RateLimiter {
    private let windowSizeMs: Int64
    private let maxRequests: Int64
    private let lock: ReentrantReadWriteMutex
    private var timestamps: ArrayList<Int64>
    private var totalRequests: Int64
    private var rejectedRequests: Int64

    public init(windowSizeMs: Int64, maxRequests: Int64) {
        this.windowSizeMs = windowSizeMs
        this.maxRequests = maxRequests
        this.lock = ReentrantReadWriteMutex()
        this.timestamps = ArrayList<Int64>()
        this.totalRequests = 0
        this.rejectedRequests = 0
    }

    /**
     * 创建滑动窗口限流器
     * @param windowSizeSeconds 窗口大小（秒）
     * @param maxRequests 窗口内最大请求数
     */
    public static func create(windowSizeSeconds: Int64, maxRequests: Int64): SlidingWindowRateLimiter {
        SlidingWindowRateLimiter(windowSizeSeconds * 1000, maxRequests)
    }

    public func tryAcquire(): RateLimitResult {
        tryAcquireWithLock(1)
    }

    public func tryAcquire(count: Int64): RateLimitResult {
        if (count <= 0) {
            return RateLimitResult.Allowed(0)
        }
        tryAcquireWithLock(count)
    }

    private func tryAcquireWithLock(count: Int64): RateLimitResult {
        lock.writeMutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let windowStart = now - windowSizeMs

        // 移除窗口外的请求
        var i = 0
        while (i < timestamps.size) {
            if (timestamps[i] < windowStart) {
                i += 1
            } else {
                break
            }
        }
        if (i > 0) {
            // 删除已过期的
            let newList = ArrayList<Int64>()
            for (j in i..timestamps.size) {
                newList.add(timestamps[j])
            }
            timestamps = newList
        }

        // 检查是否允许
        if (Int64(timestamps.size) + count <= maxRequests) {
            for (k in 0..count) {
                timestamps.add(now)
            }
            totalRequests += count
            lock.writeMutex.unlock()
            RateLimitResult.Allowed(count)
        } else {
            rejectedRequests += count
            lock.writeMutex.unlock()
            // 计算最早过期时间
            let oldest = if (timestamps.size > 0) { timestamps[0] } else { now }
            let waitTime = (oldest + windowSizeMs) - now
            RateLimitResult.Rejected(waitTime * 1_000_000)
        }
    }

    public func acquire(): Bool {
        match (tryAcquire()) {
            case RateLimitResult.Allowed(_) => true
            case _ => false
        }
    }

    public func acquire(count: Int64): Bool {
        match (tryAcquire(count)) {
            case RateLimitResult.Allowed(_) => true
            case _ => false
        }
    }

    public func available(): Int64 {
        lock.readMutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let windowStart = now - windowSizeMs
        var validCount = 0
        for (ts in timestamps) {
            if (ts >= windowStart) {
                validCount += 1
            }
        }
        let avail = maxRequests - validCount
        lock.readMutex.unlock()
        if (avail < 0) { 0 } else { avail }
    }

    public func reset(): Unit {
        lock.writeMutex.lock()
        timestamps.clear()
        lock.writeMutex.unlock()
    }

    public func getTotalRequests(): Int64 {
        lock.readMutex.lock()
        let total = totalRequests
        lock.readMutex.unlock()
        total
    }

    public func getRejectedRequests(): Int64 {
        lock.readMutex.lock()
        let rejected = rejectedRequests
        lock.readMutex.unlock()
        rejected
    }

    public func getWindowSizeMs(): Int64 {
        windowSizeMs
    }

    public func getMaxRequests(): Int64 {
        maxRequests
    }
}

/**
 * 计数器限流器（简单固定窗口）
 */
public class FixedWindowRateLimiter <: RateLimiter {
    private let windowSizeMs: Int64
    private let maxRequests: Int64
    private let lock: ReentrantReadWriteMutex
    private var count: Int64
    private var windowStart: Int64
    private var totalRequests: Int64
    private var rejectedRequests: Int64

    public init(windowSizeMs: Int64, maxRequests: Int64) {
        this.windowSizeMs = windowSizeMs
        this.maxRequests = maxRequests
        this.lock = ReentrantReadWriteMutex()
        this.count = 0
        this.windowStart = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.totalRequests = 0
        this.rejectedRequests = 0
    }

    public static func create(windowSizeSeconds: Int64, maxRequests: Int64): FixedWindowRateLimiter {
        FixedWindowRateLimiter(windowSizeSeconds * 1000, maxRequests)
    }

    public func tryAcquire(): RateLimitResult {
        tryAcquireWithLock(1)
    }

    public func tryAcquire(requestedCount: Int64): RateLimitResult {
        if (requestedCount <= 0) {
            return RateLimitResult.Allowed(0)
        }
        tryAcquireWithLock(requestedCount)
    }

    private func tryAcquireWithLock(requestedCount: Int64): RateLimitResult {
        lock.writeMutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()

        // 检查是否需要重置窗口
        if (now - windowStart >= windowSizeMs) {
            count = 0
            windowStart = now
        }

        if (count + requestedCount <= maxRequests) {
            count += requestedCount
            totalRequests += requestedCount
            lock.writeMutex.unlock()
            RateLimitResult.Allowed(requestedCount)
        } else {
            rejectedRequests += requestedCount
            let waitTime = windowStart + windowSizeMs - now
            lock.writeMutex.unlock()
            RateLimitResult.Rejected(waitTime * 1_000_000)
        }
    }

    public func acquire(): Bool {
        match (tryAcquire()) {
            case RateLimitResult.Allowed(_) => true
            case _ => false
        }
    }

    public func acquire(count: Int64): Bool {
        match (tryAcquire(count)) {
            case RateLimitResult.Allowed(_) => true
            case _ => false
        }
    }

    public func available(): Int64 {
        lock.writeMutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        if (now - windowStart >= windowSizeMs) {
            lock.writeMutex.unlock()
            return maxRequests
        }
        let avail = maxRequests - count
        lock.writeMutex.unlock()
        avail
    }

    public func reset(): Unit {
        lock.writeMutex.lock()
        count = 0
        windowStart = DateTime.now().toUnixTimeStamp().toMilliseconds()
        lock.writeMutex.unlock()
    }

    public func getTotalRequests(): Int64 {
        lock.readMutex.lock()
        let total = totalRequests
        lock.readMutex.unlock()
        total
    }

    public func getRejectedRequests(): Int64 {
        lock.readMutex.lock()
        let rejected = rejectedRequests
        lock.readMutex.unlock()
        rejected
    }
}

/**
 * 创建令牌桶限流器
 */
public func createTokenBucketLimiter(rps: Float64): TokenBucketRateLimiter {
    TokenBucketRateLimiter.create(rps)
}

/**
 * 创建带突发大小的令牌桶限流器
 */
public func createTokenBucketLimiterWithBurst(rps: Float64, burstSize: Int64): TokenBucketRateLimiter {
    TokenBucketRateLimiter.create(rps, burstSize)
}

/**
 * 创建滑动窗口限流器
 */
public func createSlidingWindowLimiter(windowSeconds: Int64, maxRequests: Int64): SlidingWindowRateLimiter {
    SlidingWindowRateLimiter.create(windowSeconds, maxRequests)
}

/**
 * 创建固定窗口限流器
 */
public func createFixedWindowLimiter(windowSeconds: Int64, maxRequests: Int64): FixedWindowRateLimiter {
    FixedWindowRateLimiter.create(windowSeconds, maxRequests)
}
