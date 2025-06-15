/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 监督策略测试
 * 验证Actor监督和容错机制
 */
package cactor.integration.testing.supervision_test

import std.sync.*
import std.time.*
import cactor.supervision.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.Message

/**
 * 测试异常类
 */
class TestException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 虚拟ActorRef用于测试
 */
class TestActorRef <: ActorRef {
    private let id: String

    public init(id: String) {
        this.id = id
    }

    public prop path: ActorPath {
        get() {
            ActorPath("test", id)
        }
    }

    public func tell(message: Message): Unit {
        println("TestActorRef[${id}] 收到消息: ${message.messageType()}")
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        println("TestActorRef[${id}] 收到来自${sender}的消息: ${message.messageType()}")
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case ref: TestActorRef => this.id == ref.id
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(id.hashCode())
    }

    public func toString(): String {
        "TestActorRef(${id})"
    }
}

/**
 * 测试重试信息
 */
func testRetryInfo(): Bool {
    let retryInfo = RetryInfo()
    
    // 测试初始状态
    if (retryInfo.getRetryCount() != 0) {
        println("✗ 初始重试次数应该是0")
        return false
    }
    
    // 测试记录重试
    retryInfo.recordRetry()
    if (retryInfo.getRetryCount() != 1) {
        println("✗ 记录重试后次数应该是1")
        return false
    }
    
    // 测试重试限制
    if (!retryInfo.shouldRetry(3, Duration.minute)) {
        println("✗ 在限制内应该允许重试")
        return false
    }
    
    // 测试超出重试次数
    retryInfo.recordRetry()
    retryInfo.recordRetry()
    retryInfo.recordRetry()  // 现在是4次
    
    if (retryInfo.shouldRetry(3, Duration.minute)) {
        println("✗ 超出重试次数应该不允许重试")
        return false
    }
    
    // 测试重置
    retryInfo.reset()
    if (retryInfo.getRetryCount() != 0) {
        println("✗ 重置后重试次数应该是0")
        return false
    }
    
    println("✓ 重试信息测试通过")
    return true
}

/**
 * 测试一对一监督策略
 */
func testOneForOneStrategy(): Bool {
    let strategy = OneForOneStrategy(
        2,
        Duration.minute,
        { exception => SupervisionDirective.Restart }
    )
    
    let actor = TestActorRef("test-actor")
    let exception = TestException("测试异常")
    
    // 第一次失败 - 应该重启
    let failure1 = ActorFailure(actor, exception, 1)
    let directive1 = strategy.decide(failure1)
    match (directive1) {
        case SupervisionDirective.Restart => ()
        case _ =>
            println("✗ 第一次失败应该重启")
            return false
    }
    
    // 第二次失败 - 应该重启
    let failure2 = ActorFailure(actor, exception, 2)
    let directive2 = strategy.decide(failure2)
    match (directive2) {
        case SupervisionDirective.Restart => ()
        case _ =>
            println("✗ 第二次失败应该重启")
            return false
    }

    // 第三次失败 - 应该停止（超出重试限制）
    let failure3 = ActorFailure(actor, exception, 3)
    let directive3 = strategy.decide(failure3)
    match (directive3) {
        case SupervisionDirective.Stop => ()
        case _ =>
            println("✗ 第三次失败应该停止")
            return false
    }
    
    println("✓ 一对一监督策略测试通过")
    return true
}

/**
 * 测试一对全监督策略
 */
func testOneForAllStrategy(): Bool {
    let strategy = OneForAllStrategy(
        1,
        Duration.minute,
        { exception => SupervisionDirective.Restart }
    )
    
    let actor1 = TestActorRef("actor1")
    let actor2 = TestActorRef("actor2")
    let exception = TestException("测试异常")
    
    // actor1失败 - 应该重启
    let failure1 = ActorFailure(actor1, exception, 1)
    let directive1 = strategy.decide(failure1)
    match (directive1) {
        case SupervisionDirective.Restart => ()
        case _ =>
            println("✗ actor1失败应该重启")
            return false
    }

    // actor2失败 - 应该停止（全局重试次数已用完）
    let failure2 = ActorFailure(actor2, exception, 1)
    let directive2 = strategy.decide(failure2)
    match (directive2) {
        case SupervisionDirective.Stop => ()
        case _ =>
            println("✗ actor2失败应该停止")
            return false
    }
    
    println("✓ 一对全监督策略测试通过")
    return true
}

/**
 * 测试默认监督策略
 */
func testDefaultSupervisionStrategy(): Bool {
    // 测试默认一对一策略
    let oneForOne = DefaultSupervisionStrategy.oneForOne()
    let actor = TestActorRef("default-actor")
    let exception = TestException("默认测试异常")
    let failure = ActorFailure(actor, exception, 1)
    
    let directive = oneForOne.decide(failure)
    match (directive) {
        case SupervisionDirective.Restart => ()
        case _ =>
            println("✗ 默认策略应该重启")
            return false
    }

    // 测试停止策略
    let stoppingStrategy = DefaultSupervisionStrategy.stoppingStrategy()
    let stopDirective = stoppingStrategy.decide(failure)
    match (stopDirective) {
        case SupervisionDirective.Stop => ()
        case _ =>
            println("✗ 停止策略应该停止")
            return false
    }

    // 测试恢复策略
    let resumingStrategy = DefaultSupervisionStrategy.resumingStrategy()
    let resumeDirective = resumingStrategy.decide(failure)
    match (resumeDirective) {
        case SupervisionDirective.Resume => ()
        case _ =>
            println("✗ 恢复策略应该恢复")
            return false
    }
    
    println("✓ 默认监督策略测试通过")
    return true
}

/**
 * 测试基础监督者
 */
func testBasicSupervisor(): Bool {
    let strategy = DefaultSupervisionStrategy.oneForOne()
    let supervisor = BasicSupervisor(strategy)
    
    let child1 = TestActorRef("child1")
    let child2 = TestActorRef("child2")
    
    // 添加子Actor
    supervisor.addChild(child1)
    supervisor.addChild(child2)
    
    let children = supervisor.getChildren()
    if (children.size != 2) {
        println("✗ 应该有2个子Actor")
        return false
    }
    
    // 测试处理失败
    let exception = TestException("子Actor失败")
    let failure = ActorFailure(child1, exception, 1)
    
    supervisor.handleFailure(failure)
    
    if (supervisor.getFailureCount() != 1) {
        println("✗ 失败计数应该是1")
        return false
    }
    
    // 测试移除子Actor
    supervisor.removeChild(child1)
    let remainingChildren = supervisor.getChildren()
    if (remainingChildren.size != 1) {
        println("✗ 移除后应该有1个子Actor")
        return false
    }
    
    println("✓ 基础监督者测试通过")
    return true
}

/**
 * 测试监督策略的时间窗口
 */
func testTimeWindow(): Bool {
    let strategy = OneForOneStrategy(
        2,
        Duration.millisecond * 100,  // 100ms窗口
        { exception => SupervisionDirective.Restart }
    )
    
    let actor = TestActorRef("time-test-actor")
    let exception = TestException("时间窗口测试")
    
    // 第一次失败
    let failure1 = ActorFailure(actor, exception, 1)
    let directive1 = strategy.decide(failure1)
    match (directive1) {
        case SupervisionDirective.Restart => ()
        case _ =>
            println("✗ 第一次失败应该重启")
            return false
    }

    // 等待超过时间窗口
    sleep(Duration.millisecond * 150)

    // 第二次失败（应该在新的时间窗口内）
    let failure2 = ActorFailure(actor, exception, 1)
    let directive2 = strategy.decide(failure2)
    match (directive2) {
        case SupervisionDirective.Restart => ()
        case _ =>
            println("✗ 新时间窗口内的失败应该重启")
            return false
    }
    
    println("✓ 时间窗口测试通过")
    return true
}

/**
 * 主测试函数
 */
main() {
    println("=== CActor 监督策略测试 ===")
    
    var allPassed = true
    
    // 运行所有测试
    allPassed = allPassed && testRetryInfo()
    allPassed = allPassed && testOneForOneStrategy()
    allPassed = allPassed && testOneForAllStrategy()
    allPassed = allPassed && testDefaultSupervisionStrategy()
    allPassed = allPassed && testBasicSupervisor()
    allPassed = allPassed && testTimeWindow()
    
    if (allPassed) {
        println("\n🎉 所有监督策略测试通过！")
        println("✓ 重试信息功能正常")
        println("✓ 一对一监督策略正确")
        println("✓ 一对全监督策略正确")
        println("✓ 默认监督策略正常")
        println("✓ 基础监督者功能正常")
        println("✓ 时间窗口机制正确")
        println("\n这验证了CActor的监督策略实现！")
        println("🚀 Phase 3: 监督策略功能完成！")
    } else {
        println("\n❌ 部分测试失败")
    }
}
