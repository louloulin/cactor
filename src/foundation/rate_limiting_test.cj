/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting 单元测试
 */
package cactor.foundation

import std.collection.*
import std.time.*

// === RateLimitConfig Tests ===

@Test
func testRateLimitConfig_creation() {
    let config = RateLimitConfig(100.0, 200, 1000)
    @Expect(config.requestsPerSecond, 100.0)
    @Expect(config.burstSize, 200)
    @Expect(config.maxQueueSize, 1000)
}

// === TokenBucketRateLimiter Tests ===

@Test
func testTokenBucket_creation() {
    let limiter = createTokenBucketLimiter(100.0)
    @Expect(limiter.available() > 0, true)
    @Expect(limiter.getCurrentRate(), 100.0)
}

@Test
func testTokenBucket_tryAcquireAllowed() {
    let limiter = createTokenBucketLimiter(100.0)
    match (limiter.tryAcquire()) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 1)
        case RateLimitResult.Rejected(_) =>
            @Expect(true, false)
    }
}

@Test
func testTokenBucket_tryAcquireMultiple() {
    let limiter = createTokenBucketLimiterWithBurst(100.0, 10)
    match (limiter.tryAcquire(5)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 5)
        case RateLimitResult.Rejected(_) =>
            @Expect(true, false)
    }
}

@Test
func testTokenBucket_burstExhaustion() {
    let limiter = createTokenBucketLimiterWithBurst(10.0, 5)
    // 耗尽所有令牌
    for (i in 0..5) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => ()
            case RateLimitResult.Rejected(_) => @Expect(true, false)
        }
    }
    // 下一个应该被拒绝
    match (limiter.tryAcquire()) {
        case RateLimitResult.Allowed(_) => @Expect(true, false)
        case RateLimitResult.Rejected(waitTime) =>
            @Expect(waitTime > 0, true)
    }
}

@Test
func testTokenBucket_reset() {
    let limiter = createTokenBucketLimiterWithBurst(100.0, 10)
    // 消耗一些令牌
    limiter.tryAcquire(5)
    @Expect(limiter.available() < 10, true)

    // 重置
    limiter.reset()
    @Expect(limiter.available(), 10)
}

@Test
func testTokenBucket_zeroCount() {
    let limiter = createTokenBucketLimiter(100.0)
    match (limiter.tryAcquire(0)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 0)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testTokenBucket_negativeCount() {
    let limiter = createTokenBucketLimiter(100.0)
    match (limiter.tryAcquire(-1)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 0)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testTokenBucket_getTotalRequests() {
    let limiter = createTokenBucketLimiterWithBurst(100.0, 100)
    limiter.tryAcquire(3)
    limiter.tryAcquire(2)
    @Expect(limiter.getTotalRequests(), 5)
}

@Test
func testTokenBucket_getRejectedRequests() {
    let limiter = createTokenBucketLimiterWithBurst(1.0, 1)
    limiter.tryAcquire()
    // 第二个请求应该被拒绝
    limiter.tryAcquire()
    @Expect(limiter.getRejectedRequests() > 0, true)
}

@Test
func testTokenBucket_config() {
    let limiter = createTokenBucketLimiterWithBurst(50.0, 25)
    let config = limiter.getConfig()
    @Expect(config.requestsPerSecond, 50.0)
    @Expect(config.burstSize, 25)
}

// === SlidingWindowRateLimiter Tests ===

@Test
func testSlidingWindow_creation() {
    let limiter = createSlidingWindowLimiter(60, 100)
    @Expect(limiter.getWindowSizeMs(), 60000)
    @Expect(limiter.getMaxRequests(), 100)
}

@Test
func testSlidingWindow_tryAcquireAllowed() {
    let limiter = createSlidingWindowLimiter(60, 100)
    match (limiter.tryAcquire()) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 1)
        case RateLimitResult.Rejected(_) =>
            @Expect(true, false)
    }
}

@Test
func testSlidingWindow_multiple() {
    let limiter = createSlidingWindowLimiter(60, 100)
    match (limiter.tryAcquire(50)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 50)
        case _ =>
            @Expect(true, false)
    }
    @Expect(limiter.available() >= 50, true)
}

@Test
func testSlidingWindow_exceedLimit() {
    let limiter = createSlidingWindowLimiter(60, 10)
    // 达到限制
    for (i in 0..10) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => ()
            case RateLimitResult.Rejected(_) => @Expect(true, false)
        }
    }
    // 下一个应该被拒绝
    match (limiter.tryAcquire()) {
        case RateLimitResult.Allowed(_) => @Expect(true, false)
        case RateLimitResult.Rejected(_) => @Expect(true, true)
    }
}

@Test
func testSlidingWindow_reset() {
    let limiter = createSlidingWindowLimiter(60, 100)
    limiter.tryAcquire(50)
    @Expect(limiter.available() < 100, true)

    limiter.reset()
    @Expect(limiter.available(), 100)
}

@Test
func testSlidingWindow_zeroCount() {
    let limiter = createSlidingWindowLimiter(60, 100)
    match (limiter.tryAcquire(0)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 0)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testSlidingWindow_totalRequests() {
    let limiter = createSlidingWindowLimiter(60, 100)
    limiter.tryAcquire(3)
    limiter.tryAcquire(2)
    @Expect(limiter.getTotalRequests(), 5)
}

@Test
func testSlidingWindow_rejectedRequests() {
    let limiter = createSlidingWindowLimiter(60, 5)
    limiter.tryAcquire(5)
    limiter.tryAcquire(3)  // 部分被拒绝
    @Expect(limiter.getRejectedRequests() >= 3, true)
}

// === FixedWindowRateLimiter Tests ===

@Test
func testFixedWindow_creation() {
    let limiter = createFixedWindowLimiter(60, 100)
    @Expect(limiter.available() <= 100, true)
}

@Test
func testFixedWindow_tryAcquire() {
    let limiter = createFixedWindowLimiter(60, 100)
    match (limiter.tryAcquire()) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 1)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testFixedWindow_multiple() {
    let limiter = createFixedWindowLimiter(60, 100)
    match (limiter.tryAcquire(30)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 30)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testFixedWindow_exceedLimit() {
    let limiter = createFixedWindowLimiter(60, 10)
    // 达到限制
    for (i in 0..10) {
        match (limiter.tryAcquire()) {
            case RateLimitResult.Allowed(_) => ()
            case RateLimitResult.Rejected(_) => @Expect(true, false)
        }
    }
    // 下一个应该被拒绝
    match (limiter.tryAcquire()) {
        case RateLimitResult.Allowed(_) => @Expect(true, false)
        case RateLimitResult.Rejected(_) => @Expect(true, true)
    }
}

@Test
func testFixedWindow_reset() {
    let limiter = createFixedWindowLimiter(60, 100)
    limiter.tryAcquire(50)
    limiter.reset()
    @Expect(limiter.available() >= 50, true)  // 重置后回到完整窗口
}

@Test
func testFixedWindow_totalRequests() {
    let limiter = createFixedWindowLimiter(60, 100)
    limiter.tryAcquire(5)
    limiter.tryAcquire(3)
    @Expect(limiter.getTotalRequests(), 8)
}

@Test
func testFixedWindow_zeroCount() {
    let limiter = createFixedWindowLimiter(60, 100)
    match (limiter.tryAcquire(0)) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 0)
        case _ =>
            @Expect(true, false)
    }
}

// === RateLimiter Interface Tests ===

@Test
func testRateLimiterInterface_tokenBucket() {
    let limiter: RateLimiter = createTokenBucketLimiter(100.0)
    @Expect(limiter.available() > 0, true)
    limiter.reset()
    @Expect(limiter.available() > 0, true)
}

@Test
func testRateLimiterInterface_slidingWindow() {
    let limiter: RateLimiter = createSlidingWindowLimiter(60, 100)
    @Expect(limiter.available() >= 0, true)
    limiter.reset()
}

@Test
func testRateLimiterInterface_fixedWindow() {
    let limiter: RateLimiter = createFixedWindowLimiter(60, 100)
    @Expect(limiter.available() >= 0, true)
    limiter.reset()
}

// === Edge Case Tests ===

@Test
func testRateLimitResult_allowed() {
    let result = RateLimitResult.Allowed(5)
    match (result) {
        case RateLimitResult.Allowed(count) =>
            @Expect(count, 5)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testRateLimitResult_rejected() {
    let result = RateLimitResult.Rejected(1000000)
    match (result) {
        case RateLimitResult.Rejected(waitTime) =>
            @Expect(waitTime, 1000000)
        case _ =>
            @Expect(true, false)
    }
}
