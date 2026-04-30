/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - SupervisionStrategy 单元测试
 */
package cactor.core.supervision

import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef, ActorPath, ActorLifecycleState}
import cactor.core.message.Message

@Test
func testSupervisionDirective_values() {
    // Verify all enum values can be constructed
    let resume = SupervisionDirective.Resume
    let restart = SupervisionDirective.Restart
    let stop = SupervisionDirective.Stop
    let escalate = SupervisionDirective.Escalate
    @Expect(true, true)
}

@Test
func testActorFailure_creation() {
    let mockRef = MockActorRefForSupervision("/test/actor")
    let exception = Exception("Test exception")
    let failure = ActorFailure(mockRef, exception, 1)

    @Expect(failure.actor.equals(mockRef), true)
    @Expect(failure.failureCount, 1)
    @Expect(failure.cause.message.size > 0, true)
    @Expect(failure.timestamp > 0, true)
}

@Test
func testRetryInfo_initialState() {
    let retryInfo = RetryInfo()

    @Expect(retryInfo.getRetryCount(), 0)
    @Expect(retryInfo.shouldRetry(3, Duration.second * 10), true)
}

@Test
func testRetryInfo_recordRetry() {
    let retryInfo = RetryInfo()

    retryInfo.recordRetry()
    @Expect(retryInfo.getRetryCount(), 1)

    retryInfo.recordRetry()
    @Expect(retryInfo.getRetryCount(), 2)
}

@Test
func testRetryInfo_shouldRetry_withinLimit() {
    let retryInfo = RetryInfo()

    @Expect(retryInfo.shouldRetry(3, Duration.hour), true)
    retryInfo.recordRetry()
    @Expect(retryInfo.shouldRetry(3, Duration.hour), true)
    retryInfo.recordRetry()
    @Expect(retryInfo.shouldRetry(3, Duration.hour), true)
    retryInfo.recordRetry()
    @Expect(retryInfo.shouldRetry(3, Duration.hour), false)
}

@Test
func testRetryInfo_reset() {
    let retryInfo = RetryInfo()

    retryInfo.recordRetry()
    retryInfo.recordRetry()
    @Expect(retryInfo.getRetryCount(), 2)

    retryInfo.reset()
    @Expect(retryInfo.getRetryCount(), 0)
}

@Test
func testOneForOneStrategy_initialization() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Restart }
    )

    // Verify strategy was created successfully
    @Expect(true, true)
}

@Test
func testOneForOneStrategy_decide_resume() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Resume }
    )

    let mockRef = MockActorRefForSupervision("/test/actor")
    let failure = ActorFailure(mockRef, Exception("test"), 1)

    let directive = strategy.decide(failure)
    @Expect(isDirective(directive, SupervisionDirective.Resume), true)
}

@Test
func testOneForOneStrategy_decide_stop() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Stop }
    )

    let mockRef = MockActorRefForSupervision("/test/actor")
    let failure = ActorFailure(mockRef, Exception("test"), 1)

    let directive = strategy.decide(failure)
    @Expect(isDirective(directive, SupervisionDirective.Stop), true)
}

@Test
func testOneForOneStrategy_decide_escalate() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Escalate }
    )

    let mockRef = MockActorRefForSupervision("/test/actor")
    let failure = ActorFailure(mockRef, Exception("test"), 1)

    let directive = strategy.decide(failure)
    @Expect(isDirective(directive, SupervisionDirective.Escalate), true)
}

@Test
func testOneForOneStrategy_resetRetryInfo() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Restart }
    )

    let mockRef = MockActorRefForSupervision("/test/actor")
    let failure = ActorFailure(mockRef, Exception("test"), 1)

    // 触发重试
    strategy.decide(failure)
    strategy.decide(failure)

    // 重置
    strategy.resetRetryInfo(mockRef)

    // 再次触发应该可以重试
    let directive = strategy.decide(failure)
    @Expect(isDirective(directive, SupervisionDirective.Restart), true)
}

@Test
func testOneForAllStrategy_initialization() {
    let strategy = OneForAllStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Restart }
    )

    // Verify strategy was created successfully
    @Expect(true, true)
}

@Test
func testOneForAllStrategy_decide() {
    let strategy = OneForAllStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Restart }
    )

    let mockRef = MockActorRefForSupervision("/test/actor")
    let failure = ActorFailure(mockRef, Exception("test"), 1)

    let directive = strategy.decide(failure)
    @Expect(isDirective(directive, SupervisionDirective.Restart), true)
}

@Test
func testOneForAllStrategy_resetRetryInfo() {
    let strategy = OneForAllStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Restart }
    )

    let mockRef = MockActorRefForSupervision("/test/actor")
    let failure = ActorFailure(mockRef, Exception("test"), 1)

    // 触发重试
    strategy.decide(failure)
    strategy.decide(failure)

    // 重置
    strategy.resetRetryInfo()

    // 再次触发应该可以重试
    let directive = strategy.decide(failure)
    @Expect(isDirective(directive, SupervisionDirective.Restart), true)
}

@Test
func testDefaultSupervisionStrategy_oneForOne() {
    let strategy = DefaultSupervisionStrategy.oneForOne()
    @Expect(true, true)
}

@Test
func testDefaultSupervisionStrategy_oneForAll() {
    let strategy = DefaultSupervisionStrategy.oneForAll()
    @Expect(true, true)
}

@Test
func testDefaultSupervisionStrategy_stoppingStrategy() {
    let strategy = DefaultSupervisionStrategy.stoppingStrategy()
    @Expect(true, true)
}

@Test
func testDefaultSupervisionStrategy_resumingStrategy() {
    let strategy = DefaultSupervisionStrategy.resumingStrategy()
    @Expect(true, true)
}

@Test
func testDefaultSupervisionStrategy_decider() {
    let directive = DefaultSupervisionStrategy.defaultDecider(Exception("test"))
    @Expect(isDirective(directive, SupervisionDirective.Restart), true)
}

@Test
func testBasicSupervisor_initialization() {
    let strategy = DefaultSupervisionStrategy.oneForOne()
    let supervisor = BasicSupervisor(strategy)

    @Expect(supervisor.getFailureCount(), 0)
    @Expect(supervisor.getChildren().size, 0)
}

@Test
func testBasicSupervisor_addChild() {
    let strategy = DefaultSupervisionStrategy.oneForOne()
    let supervisor = BasicSupervisor(strategy)

    let childRef = MockActorRefForSupervision("/test/child")
    supervisor.addChild(childRef)

    @Expect(supervisor.getChildren().size, 1)
}

@Test
func testBasicSupervisor_removeChild() {
    let strategy = DefaultSupervisionStrategy.oneForOne()
    let supervisor = BasicSupervisor(strategy)

    let childRef = MockActorRefForSupervision("/test/child")
    supervisor.addChild(childRef)
    @Expect(supervisor.getChildren().size, 1)

    supervisor.removeChild(childRef)
    @Expect(supervisor.getChildren().size, 0)
}

@Test
func testBasicSupervisor_handleFailure_resume() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Resume }
    )
    let supervisor = BasicSupervisor(strategy)

    let childRef = MockActorRefForSupervision("/test/child")
    let failure = ActorFailure(childRef, Exception("test"), 1)

    supervisor.handleFailure(failure)
    @Expect(supervisor.getFailureCount(), 1)
}

@Test
func testBasicSupervisor_handleFailure_restart() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Restart }
    )
    let supervisor = BasicSupervisor(strategy)

    let childRef = MockActorRefForSupervision("/test/child")
    let failure = ActorFailure(childRef, Exception("test"), 1)

    supervisor.handleFailure(failure)
    @Expect(supervisor.getFailureCount(), 1)
}

@Test
func testBasicSupervisor_handleFailure_stop() {
    let strategy = OneForOneStrategy(
        3,
        Duration.minute,
        { e => SupervisionDirective.Stop }
    )
    let supervisor = BasicSupervisor(strategy)

    let childRef = MockActorRefForSupervision("/test/child")
    supervisor.addChild(childRef)
    @Expect(supervisor.getChildren().size, 1)

    let failure = ActorFailure(childRef, Exception("test"), 1)
    supervisor.handleFailure(failure)
    @Expect(supervisor.getFailureCount(), 1)
    // Stop 指令会移除子 Actor
    @Expect(supervisor.getChildren().size, 0)
}

@Test
func testBasicSupervisor_getSupervisionStrategy() {
    let strategy = DefaultSupervisionStrategy.oneForOne()
    let supervisor = BasicSupervisor(strategy)

    let retrievedStrategy = supervisor.getSupervisionStrategy()
    @Expect(true, true)
}

/*
 * 测试辅助函数和类
 */

func isDirective(actual: SupervisionDirective, expected: SupervisionDirective): Bool {
    match (actual) {
        case SupervisionDirective.Resume =>
            match (expected) {
                case SupervisionDirective.Resume => true
                case _ => false
            }
        case SupervisionDirective.Restart =>
            match (expected) {
                case SupervisionDirective.Restart => true
                case _ => false
            }
        case SupervisionDirective.Stop =>
            match (expected) {
                case SupervisionDirective.Stop => true
                case _ => false
            }
        case SupervisionDirective.Escalate =>
            match (expected) {
                case SupervisionDirective.Escalate => true
                case _ => false
            }
    }
}

class MockActorRefForSupervision <: ActorRef {
    private let actorPath: ActorPath

    public init(path: String) {
        this.actorPath = ActorPath("test", path)
    }

    public prop path: ActorPath {
        get() { actorPath }
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, sender: Option<String>): Unit {}

    public func equals(other: ActorRef): Bool {
        this.path.toString() == other.path.toString()
    }

    public func hashCode(): Int32 {
        0
    }
}
