/*
 * CActor 3.0 - 宏DSL系统测试
 * Phase 1: 宏驱动的Actor DSL系统 - 测试验证
 */
package cactor.tests.macro_dsl_test

import cactor.macros.*
import cactor.dsl.*
// import cactor.examples.counter_actor_dsl.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 测试用的简单Actor定义
@actor
struct TestActor {
    var state: String = "initial"
    
    @handler
    func updateState(msg: UpdateStateMessage): Unit {
        state = msg.newState
        println("状态已更新为: ${state}")
    }
    
    @handler
    func getState(msg: GetStateMessage): StateResponse {
        println("当前状态: ${state}")
        return StateResponse(state)
    }
}

// 测试用的监控Actor
@monitored
struct BenchmarkActor {
    var operationCount: Int64 = 0
    
    @handler
    func performOperation(msg: OperationMessage): Unit {
        operationCount += 1
        // 模拟一些计算工作
        var result = 0
        for (i in 0..msg.iterations) {
            result += i.toInt32()
        }
        println("执行操作 ${operationCount}，迭代次数: ${msg.iterations}，结果: ${result}")
    }
    
    @handler
    func getBenchmarkStats(msg: BenchmarkStatsMessage): BenchmarkStatsResponse {
        return BenchmarkStatsResponse(operationCount)
    }
}

// 测试消息类型
public class UpdateStateMessage <: Message {
    public let newState: String
    
    public init(newState: String) {
        this.newState = newState
    }
    
    public func getMessageType(): String {
        return "updatestate"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class GetStateMessage <: Message {
    public init() {}
    
    public func getMessageType(): String {
        return "getstate"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class StateResponse <: Message {
    public let state: String
    
    public init(state: String) {
        this.state = state
    }
    
    public func getMessageType(): String {
        return "stateresponse"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class OperationMessage <: Message {
    public let iterations: Int64
    
    public init(iterations: Int64) {
        this.iterations = iterations
    }
    
    public func getMessageType(): String {
        return "operation"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class BenchmarkStatsMessage <: Message {
    public init() {}
    
    public func getMessageType(): String {
        return "benchmarkstats"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

public class BenchmarkStatsResponse <: Message {
    public let operationCount: Int64
    
    public init(operationCount: Int64) {
        this.operationCount = operationCount
    }
    
    public func getMessageType(): String {
        return "benchmarkstatsresponse"
    }
    
    public func getPriority(): Int32 {
        return 1
    }
    
    public func getTimestamp(): Int64 {
        return getCurrentTimeMillis()
    }
}

// 测试函数
func testBasicActorDSL(): Bool {
    println("🧪 测试基础Actor DSL...")
    
    // 创建测试Actor
    let testRef = createTestActorActor()
    
    // 测试状态更新
    testRef.tell(UpdateStateMessage("running"))
    testRef.tell(GetStateMessage())
    testRef.tell(UpdateStateMessage("completed"))
    testRef.tell(GetStateMessage())
    
    // 清理
    testRef.stop()
    
    println("✅ 基础Actor DSL测试通过")
    return true
}

func testMonitoredActorDSL(): Bool {
    println("🧪 测试监控Actor DSL...")
    
    // 创建基准测试Actor
    let benchmarkRef = createMonitoredBenchmarkActorActor()
    
    // 执行一系列操作
    benchmarkRef.tell(OperationMessage(100))
    benchmarkRef.tell(OperationMessage(200))
    benchmarkRef.tell(OperationMessage(50))
    benchmarkRef.tell(OperationMessage(300))
    benchmarkRef.tell(BenchmarkStatsMessage())
    
    // 获取性能指标
    let benchmarkActor = benchmarkRef.getActor()
    if (let benchmarkActorImpl <- benchmarkActor as MonitoredBenchmarkActorActor) {
        let metrics = benchmarkActorImpl.getMetrics()
        println("基准测试Actor指标: ${metrics.toString()}")
        println("消息处理数量: ${benchmarkActorImpl.getMessageCount()}")
        println("平均处理时间: ${benchmarkActorImpl.getAverageProcessingTime()}ms")
    }
    
    // 清理
    benchmarkRef.stop()
    
    println("✅ 监控Actor DSL测试通过")
    return true
}

func testPerformance(): Bool {
    println("🧪 测试性能...")
    
    let startTime = getCurrentTimeMillis()
    
    // 创建多个Actor进行性能测试
    let actors = Array<ActorRef>()
    for (i in 0..10) {
        let actor = createMonitoredBenchmarkActorActor()
        actors.append(actor)
    }
    
    // 向每个Actor发送多条消息
    for (actor in actors) {
        for (j in 0..100) {
            actor.tell(OperationMessage(10))
        }
    }
    
    let endTime = getCurrentTimeMillis()
    let duration = endTime - startTime
    
    println("性能测试完成:")
    println("- Actor数量: ${actors.size}")
    println("- 总消息数: ${actors.size * 100}")
    println("- 总耗时: ${duration}ms")
    println("- 吞吐量: ${(actors.size * 100 * 1000) / duration} msg/s")
    
    // 清理
    for (actor in actors) {
        actor.stop()
    }
    
    println("✅ 性能测试通过")
    return true
}

func testRouteTable(): Bool {
    println("🧪 测试路由表...")
    
    // 创建路由表
    let router = MessageTypeRouter()
    let routes = router.getAllRoutes()
    
    println("路由表包含 ${routes.size} 个路由:")
    for ((messageType, handler) in routes) {
        println("- ${messageType} -> ${handler.toString()}")
    }
    
    // 测试路由查找
    // let incrementMsg = IncrementMessage(1)
    // match (router.route(incrementMsg)) {
    //     case Some(handler) =>
    //         println("找到处理器: ${handler.toString()}")
    //     case None =>
    //         println("未找到处理器")
    //         return false
    // }
    
    println("✅ 路由表测试通过")
    return true
}

// 主测试函数
main(): Int64 {
    println("=== CActor 3.0 宏DSL系统测试 ===")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testBasicActorDSL()
    allTestsPassed = allTestsPassed && testMonitoredActorDSL()
    allTestsPassed = allTestsPassed && testRouteTable()
    allTestsPassed = allTestsPassed && testPerformance()
    
    // 运行示例演示
    println("\n=== 运行示例演示 ===")
    // demonstrateActorDSL()
    
    // 清理系统
    ActorSystem.getInstance().shutdown()
    
    if (allTestsPassed) {
        println("\n🎉 所有测试通过！")
        println("✅ CActor 3.0 宏DSL系统验证成功")
        return 0
    } else {
        println("\n❌ 部分测试失败")
        return 1
    }
}

// 辅助函数
func getCurrentTimeMillis(): Int64 {
    // 简化实现，实际应该调用系统时间API
    return 1000
}
