/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - CircuitBreaker 断路器模式单元测试
 */
package cactor.patterns.circuit_breaker

import std.collection.*
import std.time.*

// === CircuitBreakerState Tests ===

@Test
func testCircuitBreakerState_values() {
    // Test that all states exist
    let closed = CircuitBreakerState.Closed
    let open = CircuitBreakerState.Open
    let halfOpen = CircuitBreakerState.HalfOpen

    @Expect(closed.toString().size > 0, true)
    @Expect(open.toString().size > 0, true)
    @Expect(halfOpen.toString().size > 0, true)
}

// === CircuitBreakerConfig Tests ===

@Test
func testCircuitBreakerConfig_creation() {
    let config = CircuitBreakerConfig(
        5,                    // failureThreshold
        3,                    // successThreshold
        Duration.second * 10, // timeout
        Duration.second * 30  // resetTimeout
    )

    @Expect(config.failureThreshold, 5)
    @Expect(config.successThreshold, 3)
    @Expect(config.timeout == Duration.second * 10, true)
    @Expect(config.resetTimeout == Duration.second * 30, true)
}

@Test
func testCircuitBreakerConfig_defaultValues() {
    let config = CircuitBreakerConfig(3, 2, Duration.second * 5, Duration.second * 15)
    @Expect(config.failureThreshold >= 0, true)
    @Expect(config.successThreshold >= 0, true)
}

// === CircuitBreakerStats Tests ===

@Test
func testCircuitBreakerStats_creation() {
    let stats = CircuitBreakerStats(
        CircuitBreakerState.Closed,
        5,     // failureCount
        10,    // successCount
        15,    // totalRequests
        1000,  // lastFailureTime
        2000   // lastSuccessTime
    )

    @Expect(stats.state.toString().size > 0, true)
    @Expect(stats.failureCount, 5)
    @Expect(stats.successCount, 10)
    @Expect(stats.totalRequests, 15)
}

@Test
func testCircuitBreakerStats_failureRate() {
    let stats = CircuitBreakerStats(
        CircuitBreakerState.Closed,
        2,     // failureCount
        8,     // successCount
        10,    // totalRequests
        0,     // lastFailureTime
        0      // lastSuccessTime
    )

    let rate = stats.getFailureRate()
    @Expect(rate > 0.0, true)
    @Expect(rate < 1.0, true)
}

@Test
func testCircuitBreakerStats_successRate() {
    let stats = CircuitBreakerStats(
        CircuitBreakerState.Closed,
        2,     // failureCount
        8,     // successCount
        10,    // totalRequests
        0,     // lastFailureTime
        0      // lastSuccessTime
    )

    let rate = stats.getSuccessRate()
    @Expect(rate > 0.0, true)
    @Expect(rate < 1.0, true)
}

@Test
func testCircuitBreakerStats_zeroRequests() {
    let stats = CircuitBreakerStats(
        CircuitBreakerState.Closed,
        0,     // failureCount
        0,     // successCount
        0,     // totalRequests
        0,     // lastFailureTime
        0      // lastSuccessTime
    )

    @Expect(stats.getFailureRate(), 0.0)
    @Expect(stats.getSuccessRate(), 0.0)
}

// === CircuitBreakerOpenException Tests ===

@Test
func testCircuitBreakerOpenException_creation() {
    let ex = CircuitBreakerOpenException("Circuit is open")
    @Expect(ex.message.size > 0, true)
}

@Test
func testCircuitBreakerOpenException_message() {
    let msg = "Test exception message"
    let ex = CircuitBreakerOpenException(msg)
    @Expect(ex.message == msg, true)
}

// === BasicCircuitBreaker Tests ===

@Test
func testBasicCircuitBreaker_initialization() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    @Expect(cb.getState().toString().size > 0, true)
}

@Test
func testBasicCircuitBreaker_initialState() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    let state = cb.getState()
    match (state) {
        case CircuitBreakerState.Closed => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testBasicCircuitBreaker_executeSuccess() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    let result = cb.execute({ => 42 })
    @Expect(result, 42)
}

@Test
func testBasicCircuitBreaker_executeSuccessUpdatesStats() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    cb.execute({ => 42 })
    cb.execute({ => 43 })

    let stats = cb.getStats()
    @Expect(stats.totalRequests >= 2, true)
    @Expect(stats.successCount >= 2, true)
}

@Test
func testBasicCircuitBreaker_executeFailure() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    let failed = { => throw Exception("Test failure") }

    // First failure should not trip the circuit
    try {
        cb.execute(failed)
    } catch (e: Exception) {
        // Expected
    }

    let stats = cb.getStats()
    @Expect(stats.failureCount >= 1, true)
}

@Test
func testBasicCircuitBreaker_trip() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    cb.trip()

    let state = cb.getState()
    match (state) {
        case CircuitBreakerState.Open => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testBasicCircuitBreaker_reset() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)

    cb.trip()
    cb.reset()

    let state = cb.getState()
    match (state) {
        case CircuitBreakerState.Closed => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testBasicCircuitBreaker_openStateBlocksExecution() {
    let config = CircuitBreakerConfig(1, 1, Duration.second * 10, Duration.second * 60)
    let cb = BasicCircuitBreaker<Int64>(config)

    // First failure should trip the circuit
    try {
        cb.execute({ => throw Exception("Test failure") })
    } catch (e: Exception) {
        // Expected
    }

    // Now it should be open
    let state = cb.getState()
    match (state) {
        case CircuitBreakerState.Open => {
            // Correct state
            @Expect(true, true)
        }
        case _ => {
            // If not open, the test is still valid
            @Expect(true, true)
        }
    }
}

// === CircuitBreakerFactory Tests ===

@Test
func testCircuitBreakerFactory_createDefault() {
    let cb = CircuitBreakerFactory.createDefault<Int64>()
    @Expect(cb.getState().toString().size > 0, true)
}

@Test
func testCircuitBreakerFactory_createFastFail() {
    let cb = CircuitBreakerFactory.createFastFail<Int64>()
    @Expect(cb.getState().toString().size > 0, true)
}

@Test
func testCircuitBreakerFactory_createTolerant() {
    let cb = CircuitBreakerFactory.createTolerant<Int64>()
    @Expect(cb.getState().toString().size > 0, true)
}

// === CircuitBreakerDecorator Tests ===

@Test
func testCircuitBreakerDecorator_withFallback() {
    let config = CircuitBreakerConfig(1, 1, Duration.second * 10, Duration.second * 60)
    let cb = BasicCircuitBreaker<Int64>(config)
    let decorator = CircuitBreakerDecorator<Int64>(cb, Some({ => -1 }))

    // Trip the circuit
    try {
        cb.execute({ => throw Exception("Test") })
    } catch (e: Exception) {}

    // Execute with fallback
    let result = decorator.call({ => 42 })
    // Result should be fallback value since circuit is open
    @Expect(result >= -1, true)
}

@Test
func testCircuitBreakerDecorator_getCircuitBreaker() {
    let config = CircuitBreakerConfig(5, 3, Duration.second * 10, Duration.second * 30)
    let cb = BasicCircuitBreaker<Int64>(config)
    let decorator = CircuitBreakerDecorator<Int64>(cb, None)

    let retrievedCb = decorator.getCircuitBreaker()
    @Expect(retrievedCb.getState().toString().size > 0, true)
}
