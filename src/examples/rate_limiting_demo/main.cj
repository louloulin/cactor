/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting 示例程序
 * 展示限流机制的使用
 */
package cactor.examples.rate_limiting_demo

import std.collection.*
import std.time.*

import cactor.foundation.*

/**
 * 模拟请求处理
 */
public class MockRequest {
    public let requestId: Int64
    public let timestamp: Int64

    public init(requestId: Int64) {
        this.requestId = requestId
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 运行 TokenBucket 演示
 */
public func runTokenBucketDemo(): Unit {
    println("=== TokenBucket Rate Limiter Demo ===")

    // 每秒 10 个请求，突发大小 20
    let limiter = createTokenBucketLimiterWithBurst(10.0, 20)
    println("Created limiter: 10 req/s, burst=20")

    println()
    println("Simulating requests...")
    var successCount = 0
    var rejectCount = 0

    for (i in 1..11) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(count) =>
                println("  Request ${i}: ALLOWED (${count} token(s))")
                successCount += 1
            case RateLimitResult.Rejected(waitNanos) =>
                println("  Request ${i}: REJECTED (wait ${waitNanos}ns)")
                rejectCount += 1
        }
    }

    println()
    println("Summary:")
    println("  Total requests: 10")
    println("  Allowed: ${successCount}")
    println("  Rejected: ${rejectCount}")
    println("  Available tokens: ${limiter.available()}")
    println("  Total requests handled: ${limiter.getTotalRequests()}")
    println()
}

/**
 * 运行滑动窗口演示
 */
public func runSlidingWindowDemo(): Unit {
    println("=== Sliding Window Rate Limiter Demo ===")

    // 60 秒窗口，最多 10 个请求
    let limiter = createSlidingWindowLimiter(60, 10)
    println("Created limiter: 10 req/minute (sliding window)")

    println()
    println("Simulating requests...")
    var successCount = 0
    var rejectCount = 0

    for (i in 1..15) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(count) =>
                println("  Request ${i}: ALLOWED")
                successCount += 1
            case RateLimitResult.Rejected(waitNanos) =>
                let waitMs = waitNanos / 1_000_000
                println("  Request ${i}: REJECTED (wait ${waitMs}ms)")
                rejectCount += 1
        }
    }

    println()
    println("Summary:")
    println("  Total requests: 15")
    println("  Allowed: ${successCount}")
    println("  Rejected: ${rejectCount}")
    println("  Available: ${limiter.available()}")
    println()
}

/**
 * 运行固定窗口演示
 */
public func runFixedWindowDemo(): Unit {
    println("=== Fixed Window Rate Limiter Demo ===")

    // 10 秒窗口，最多 5 个请求
    let limiter = createFixedWindowLimiter(10, 5)
    println("Created limiter: 5 req/10s (fixed window)")

    println()
    println("Simulating requests...")
    var successCount = 0
    var rejectCount = 0

    for (i in 1..10) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(count) =>
                println("  Request ${i}: ALLOWED")
                successCount += 1
            case RateLimitResult.Rejected(waitNanos) =>
                let waitMs = waitNanos / 1_000_000
                println("  Request ${i}: REJECTED (wait ${waitMs}ms)")
                rejectCount += 1
        }
    }

    println()
    println("Summary:")
    println("  Total requests: 10")
    println("  Allowed: ${successCount}")
    println("  Rejected: ${rejectCount}")
    println()
}

/**
 * 运行突发流量演示
 */
public func runBurstTrafficDemo(): Unit {
    println("=== Burst Traffic Handling Demo ===")

    // 每秒 5 个请求，突发大小 25
    let limiter = createTokenBucketLimiterWithBurst(5.0, 25)
    println("Created limiter: 5 req/s, burst=25")
    println()

    println("Phase 1: Burst of 25 requests...")
    var allowed1 = 0
    var rejected1 = 0
    for (i in 1..26) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => allowed1 += 1
            case RateLimitResult.Rejected(_) => rejected1 += 1
        }
    }
    println("  Allowed: ${allowed1}, Rejected: ${rejected1}")
    println()

    println("Phase 2: Trying more requests (rate limited)...")
    var allowed2 = 0
    var rejected2 = 0
    for (i in 1..6) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => allowed2 += 1
            case RateLimitResult.Rejected(_) => rejected2 += 1
        }
    }
    println("  Allowed: ${allowed2}, Rejected: ${rejected2}")
    println("  Remaining tokens: ${limiter.available()}")
    println()

    println("Phase 3: Reset and burst again...")
    limiter.reset()
    println("  Limiter reset, available tokens: ${limiter.available()}")
    println()
}

/**
 * 运行多消费者演示
 */
public func runMultiConsumerDemo(): Unit {
    println("=== Multi-Consumer Rate Limiting Demo ===")

    // 共享限流器
    let limiter = createTokenBucketLimiterWithBurst(100.0, 50)
    println("Created shared limiter: 100 req/s, burst=50")

    // 模拟多个服务
    println()
    println("Service A (priority) making requests...")
    var serviceACount = 0
    for (i in 1..10) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => serviceACount += 1
            case _ => ()
        }
    }
    println("  Service A: ${serviceACount} requests allowed")

    println()
    println("Service B making requests...")
    var serviceBCount = 0
    for (i in 1..10) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => serviceBCount += 1
            case _ => ()
        }
    }
    println("  Service B: ${serviceBCount} requests allowed")

    println()
    println("Service C making requests...")
    var serviceCCount = 0
    for (i in 1..10) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => serviceCCount += 1
            case _ => ()
        }
    }
    println("  Service C: ${serviceCCount} requests allowed")

    println()
    println("Total allowed: ${serviceACount + serviceBCount + serviceCCount}")
    println("Remaining tokens: ${limiter.available()}")
    println()
}

/**
 * 运行限流策略比较演示
 */
public func runStrategyComparisonDemo(): Unit {
    println("=== Rate Limiting Strategy Comparison Demo ===")
    println()

    // 场景：每秒最多 10 个请求，测试窗口 1 秒
    println("Scenario: Max 10 requests per second")
    println()

    // TokenBucket
    println("1. TokenBucket (10 req/s, burst=10):")
    let tokenLimiter = createTokenBucketLimiterWithBurst(10.0, 10)
    var tokenAllowed = 0
    for (i in 1..15) {
        match (tokenLimiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => tokenAllowed += 1
            case _ => ()
        }
    }
    println("   15 requests attempted: ${tokenAllowed} allowed, ${15 - tokenAllowed} rejected")
    println()

    // SlidingWindow
    println("2. SlidingWindow (10 req/minute):")
    let slidingLimiter = createSlidingWindowLimiter(1, 10)
    var slidingAllowed = 0
    for (i in 1..15) {
        match (slidingLimiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => slidingAllowed += 1
            case _ => ()
        }
    }
    println("   15 requests attempted: ${slidingAllowed} allowed, ${15 - slidingAllowed} rejected")
    println()

    // FixedWindow
    println("3. FixedWindow (10 req/s):")
    let fixedLimiter = createFixedWindowLimiter(1, 10)
    var fixedAllowed = 0
    for (i in 1..15) {
        match (fixedLimiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => fixedAllowed += 1
            case _ => ()
        }
    }
    println("   15 requests attempted: ${fixedAllowed} allowed, ${15 - fixedAllowed} rejected")
    println()

    println("Note: Different strategies have different burst handling characteristics")
    println("  - TokenBucket: Smooth rate with burst support")
    println("  - SlidingWindow: Precise rate limiting with overlap")
    println("  - FixedWindow: Simple but may have edge effects at window boundaries")
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor Rate Limiting Demo")
    println("==========================")
    println()

    runTokenBucketDemo()
    runSlidingWindowDemo()
    runFixedWindowDemo()
    runBurstTrafficDemo()
    runMultiConsumerDemo()
    runStrategyComparisonDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}
