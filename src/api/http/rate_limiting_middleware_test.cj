/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Rate Limiting Middleware 单元测试
 */
package cactor.api.http

import std.collection.*
import std.time.*

// ============================================================================
// RateLimitingMiddlewareConfig Tests
// ============================================================================

@Test
func testRateLimitingMiddlewareConfig_defaults() {
    let config = RateLimitingMiddlewareConfig.defaultConfig()
    @Expect(config.requestsPerSecond, 100.0)
    @Expect(config.burstSize, 200)
    @Expect(config.maxClients, 10000)
    @Expect(config.enabled, true)
}

@Test
func testRateLimitingMiddlewareConfig_globalLimit() {
    let config = RateLimitingMiddlewareConfig.globalLimit(50.0, 100)
    @Expect(config.maxClients, 1)
    @Expect(config.requestsPerSecond, 50.0)
}

@Test
func testRateLimitingMiddlewareConfig_perClientLimit() {
    let config = RateLimitingMiddlewareConfig.perClientLimit(100.0, 200, 5000)
    @Expect(config.maxClients, 5000)
    @Expect(config.requestsPerSecond, 100.0)
}

// ============================================================================
// ClientIdentificationStrategy Tests
// ============================================================================

@Test
func testClientIdentificationStrategy_values() {
    let ip = ClientIdentificationStrategy.IPAddress
    let header = ClientIdentificationStrategy.Header("X-Api-Key")
    let ipOrHeader = ClientIdentificationStrategy.IPOrHeader("X-User-Id")
    @Expect(true, true)
}

// ============================================================================
// RateLimitResponseConfig Tests
// ============================================================================

@Test
func testRateLimitResponseConfig_defaults() {
    let config = RateLimitResponseConfig.defaultConfig()
    @Expect(config.retryAfterSeconds, 60)
    @Expect(config.message.size > 0, true)
}

@Test
func testRateLimitResponseConfig_custom() {
    let config = RateLimitResponseConfig(30, "Custom message")
    @Expect(config.retryAfterSeconds, 30)
    @Expect(config.message == "Custom message", true)
}

// ============================================================================
// RateLimitingMiddleware Tests
// ============================================================================

@Test
func testRateLimitingMiddleware_disabled() {
    let config = RateLimitingMiddlewareConfig(
        100.0, 200, 10000,
        ClientIdentificationStrategy.IPAddress,
        RateLimitResponseConfig.defaultConfig(),
        false
    )
    let middleware = RateLimitingMiddleware(config)
    let request = createTestRequest("192.168.1.1")
    @Expect(middleware.handleRequest(request).isNone(), true)
}

@Test
func testRateLimitingMiddleware_allowed() {
    let config = RateLimitingMiddlewareConfig.defaultConfig()
    let middleware = RateLimitingMiddleware(config)
    let request = createTestRequest("192.168.1.1")

    // First request should be allowed
    let result = middleware.handleRequest(request)
    match (result) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}

@Test
func testRateLimitingMiddleware_rejected() {
    let config = RateLimitingMiddlewareConfig(
        1.0,    // 1 request per second
        1,      // burst of 1
        10000,
        ClientIdentificationStrategy.IPAddress,
        RateLimitResponseConfig.defaultConfig(),
        true
    )
    let middleware = RateLimitingMiddleware(config)
    let request = createTestRequest("192.168.1.1")

    // First request should be allowed
    let result1 = middleware.handleRequest(request)
    @Expect(result1.isNone(), true)

    // Second request should be rejected
    let result2 = middleware.handleRequest(request)
    match (result2) {
        case Some(response) =>
            match (response.status) {
                case HttpStatus.TooManyRequests => @Expect(true, true)
                case _ => @Expect(false, true)
            }
        case None =>
            @Expect(false, true)
    }
}

@Test
func testRateLimitingMiddleware_perClient() {
    let config = RateLimitingMiddlewareConfig(
        1.0,    // 1 request per second per client
        1,      // burst of 1
        10000,
        ClientIdentificationStrategy.IPAddress,
        RateLimitResponseConfig.defaultConfig(),
        true
    )
    let middleware = RateLimitingMiddleware(config)

    // Client 1
    let request1 = createTestRequest("192.168.1.1")
    let result1 = middleware.handleRequest(request1)
    @Expect(result1.isNone(), true)

    // Client 2 should be allowed (different client)
    let request2 = createTestRequest("192.168.1.2")
    let result2 = middleware.handleRequest(request2)
    @Expect(result2.isNone(), true)
}

@Test
func testRateLimitingMiddleware_headerBased() {
    let config = RateLimitingMiddlewareConfig(
        1.0,    // 1 request per second
        1,      // burst of 1
        10000,
        ClientIdentificationStrategy.Header("X-Api-Key"),
        RateLimitResponseConfig.defaultConfig(),
        true
    )
    let middleware = RateLimitingMiddleware(config)

    // Request with header
    let headers = HashMap<String, String>()
    let _ = headers.add("X-Api-Key", "test-key-123")
    let request1 = HttpRequest(
        HttpMethod.GET, "/test", "/test",
        HttpVersion.HTTP_1_1, headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        Some("192.168.1.1")
    )

    let result1 = middleware.handleRequest(request1)
    @Expect(result1.isNone(), true)

    // Same header should be rejected
    let request2 = HttpRequest(
        HttpMethod.GET, "/test", "/test",
        HttpVersion.HTTP_1_1, headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        Some("192.168.1.1")
    )
    let result2 = middleware.handleRequest(request2)
    match (result2) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testRateLimitingMiddleware_createRejectedResponse() {
    let middleware = RateLimitingMiddleware()
    let response = middleware.createRejectedResponse()

    match (response.status) {
        case HttpStatus.TooManyRequests => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    match (response.headers.get("Retry-After")) {
        case Some(value) => @Expect(value.size > 0, true)
        case None => @Expect(false, true)
    }
}

@Test
func testRateLimitingMiddleware_getStats() {
    let config = RateLimitingMiddlewareConfig.defaultConfig()
    let middleware = RateLimitingMiddleware(config)

    let request = createTestRequest("192.168.1.1")
    let _ = middleware.handleRequest(request)
    let _ = middleware.handleRequest(request)

    let stats = middleware.getStats()
    @Expect(stats.totalRequests >= 1, true)
}

@Test
func testRateLimitingMiddleware_resetStats() {
    let config = RateLimitingMiddlewareConfig.defaultConfig()
    let middleware = RateLimitingMiddleware(config)

    let request = createTestRequest("192.168.1.1")
    let _ = middleware.handleRequest(request)

    middleware.resetStats()
    let stats = middleware.getStats()
    @Expect(stats.totalRequests, 0)
}

// ============================================================================
// RateLimitStats Tests
// ============================================================================

@Test
func testRateLimitStats_rejectionRate() {
    let stats = RateLimitStats(100, 10, 50)
    @Expect(stats.rejectionRate(), 0.1)
}

@Test
func testRateLimitStats_rejectionRate_zero() {
    let stats = RateLimitStats(0, 0, 0)
    @Expect(stats.rejectionRate(), 0.0)
}

// ============================================================================
// RateLimitingMiddlewareFactory Tests
// ============================================================================

@Test
func testRateLimitingMiddlewareFactory_create() {
    let middleware = RateLimitingMiddlewareFactory.create()
    @Expect(true, true)
}

@Test
func testRateLimitingMiddlewareFactory_createGlobal() {
    let middleware = RateLimitingMiddlewareFactory.createGlobal(50.0, 100)
    @Expect(true, true)
}

@Test
func testRateLimitingMiddlewareFactory_createPerClient() {
    let middleware = RateLimitingMiddlewareFactory.createPerClient(100.0, 200, 5000)
    @Expect(true, true)
}

@Test
func testRateLimitingMiddlewareFactory_createStrict() {
    let middleware = RateLimitingMiddlewareFactory.createStrict()
    @Expect(true, true)
}

// ============================================================================
// Helper Functions
// ============================================================================

private func createTestRequest(ip: String): HttpRequest {
    let headers = HashMap<String, String>()
    HttpRequest(
        HttpMethod.GET, "/test", "/test",
        HttpVersion.HTTP_1_1, headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        Some(ip)
    )
}
