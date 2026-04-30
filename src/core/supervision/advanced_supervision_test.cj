/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - AdvancedSupervisionStrategy 单元测试
 */
package cactor.core.supervision

import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.Message

/*
 * Helper: check if two SupervisionDirective values are equal using match.
 */
func directiveEquals(a: SupervisionDirective, b: SupervisionDirective): Bool {
    match (a) {
        case SupervisionDirective.Resume =>
            match (b) {
                case SupervisionDirective.Resume => true
                case _ => false
            }
        case SupervisionDirective.Restart =>
            match (b) {
                case SupervisionDirective.Restart => true
                case _ => false
            }
        case SupervisionDirective.Stop =>
            match (b) {
                case SupervisionDirective.Stop => true
                case _ => false
            }
        case SupervisionDirective.Escalate =>
            match (b) {
                case SupervisionDirective.Escalate => true
                case _ => false
            }
    }
}

// === BackoffSupervisionStrategy Tests ===

@Test
func testBackoffStrategy_initialization() {
    let strategy = BackoffSupervisionStrategy(
        Duration.millisecond * 100,
        Duration.second * 10,
        5
    )
    @Expect(true, true)
}

@Test
func testBackoffStrategy_firstFailure_returnsRestart() {
    let strategy = BackoffSupervisionStrategy(
        Duration.millisecond * 100,
        Duration.second * 10,
        5
    )
    let ref = ASTestActorRef("/test/actor1")
    let failure = ActorFailure(ref, Exception("test error"), 1)
    let result = strategy.decide(failure)
    @Expect(directiveEquals(result, SupervisionDirective.Restart), true)
}

@Test
func testBackoffStrategy_multipleRetries_returnsRestart() {
    let strategy = BackoffSupervisionStrategy(
        Duration.millisecond * 100,
        Duration.second * 10,
        3
    )
    let ref = ASTestActorRef("/test/actor2")
    let failure = ActorFailure(ref, Exception("test error"), 1)

    // First two failures should return Restart
    let result1 = strategy.decide(failure)
    @Expect(directiveEquals(result1, SupervisionDirective.Restart), true)

    let result2 = strategy.decide(failure)
    @Expect(directiveEquals(result2, SupervisionDirective.Restart), true)
}

@Test
func testBackoffStrategy_exceedsMaxRetries_returnsStop() {
    let strategy = BackoffSupervisionStrategy(
        Duration.millisecond * 100,
        Duration.second * 10,
        2
    )
    let ref = ASTestActorRef("/test/actor3")
    let failure = ActorFailure(ref, Exception("test error"), 1)

    // Use up retries
    strategy.decide(failure)
    strategy.decide(failure)

    // Third failure exceeds maxRetries=2
    let result = strategy.decide(failure)
    @Expect(directiveEquals(result, SupervisionDirective.Stop), true)
}

@Test
func testBackoffStrategy_resetBackoff() {
    let strategy = BackoffSupervisionStrategy(
        Duration.millisecond * 100,
        Duration.second * 10,
        2
    )
    let ref = ASTestActorRef("/test/actor4")
    let failure = ActorFailure(ref, Exception("test error"), 1)

    // Use up one retry
    strategy.decide(failure)

    // Reset
    strategy.resetBackoff(ref)

    // Should allow retry again
    let result = strategy.decide(failure)
    @Expect(directiveEquals(result, SupervisionDirective.Restart), true)
}

@Test
func testBackoffStrategy_differentActors_independent() {
    let strategy = BackoffSupervisionStrategy(
        Duration.millisecond * 100,
        Duration.second * 10,
        2
    )
    let ref1 = ASTestActorRef("/test/actorA")
    let ref2 = ASTestActorRef("/test/actorB")
    let failure1 = ActorFailure(ref1, Exception("error1"), 1)
    let failure2 = ActorFailure(ref2, Exception("error2"), 1)

    // Exhaust retries for actor A
    strategy.decide(failure1)
    strategy.decide(failure1)
    let resultA = strategy.decide(failure1)
    @Expect(directiveEquals(resultA, SupervisionDirective.Stop), true)

    // Actor B should still get Restart
    let resultB = strategy.decide(failure2)
    @Expect(directiveEquals(resultB, SupervisionDirective.Restart), true)
}

// === CircuitBreakerSupervisionStrategy Tests ===

@Test
func testCircuitBreaker_initialization() {
    let strategy = CircuitBreakerSupervisionStrategy(3, Duration.second * 60)
    @Expect(true, true)
}

@Test
func testCircuitBreaker_closedState_returnsRestart() {
    let strategy = CircuitBreakerSupervisionStrategy(3, Duration.second * 60)
    let ref = ASTestActorRef("/test/cb1")
    let failure = ActorFailure(ref, Exception("error"), 1)

    // Below threshold, should restart
    let result = strategy.decide(failure)
    @Expect(directiveEquals(result, SupervisionDirective.Restart), true)
}

@Test
func testCircuitBreaker_reachesThreshold_opensCircuit() {
    let strategy = CircuitBreakerSupervisionStrategy(2, Duration.second * 60)
    let ref = ASTestActorRef("/test/cb2")
    let failure = ActorFailure(ref, Exception("error"), 1)

    // First failure: restart
    strategy.decide(failure)

    // Second failure: reaches threshold, circuit opens
    let result = strategy.decide(failure)
    @Expect(directiveEquals(result, SupervisionDirective.Stop), true)
}

@Test
func testCircuitBreaker_openState_returnsStop() {
    let strategy = CircuitBreakerSupervisionStrategy(1, Duration.second * 60)
    let ref = ASTestActorRef("/test/cb3")
    let failure = ActorFailure(ref, Exception("error"), 1)

    // Open the circuit
    strategy.decide(failure)

    // Next failure while open: should stop
    let result = strategy.decide(failure)
    @Expect(directiveEquals(result, SupervisionDirective.Stop), true)
}

@Test
func testCircuitBreaker_multipleFailuresBeforeThreshold() {
    let strategy = CircuitBreakerSupervisionStrategy(3, Duration.second * 60)
    let ref = ASTestActorRef("/test/cbMulti")
    let failure = ActorFailure(ref, Exception("error"), 1)

    // First two failures should restart
    let result1 = strategy.decide(failure)
    @Expect(directiveEquals(result1, SupervisionDirective.Restart), true)

    let result2 = strategy.decide(failure)
    @Expect(directiveEquals(result2, SupervisionDirective.Restart), true)

    // Third failure reaches threshold, circuit opens
    let result3 = strategy.decide(failure)
    @Expect(directiveEquals(result3, SupervisionDirective.Stop), true)
}

/*
 * Test helper classes
 */

class ASTestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(pathStr: String) {
        this.pathValue = ActorPath("test-system", pathStr)
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}
    public func tell(message: Message, sender: Option<String>): Unit {}
    public func equals(other: ActorRef): Bool { pathValue.toString() == other.path.toString() }
    public func hashCode(): Int32 { 0 }
}
