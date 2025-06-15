/*
 * CActor 高级宏功能测试
 * 验证plan3.md中实现的所有高级宏功能
 * 基于CActor的class架构
 */
package cactor.tests.advanced_macro_test

import cactor.macros.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 简单的ActorContext实现用于测试
class TestActorContext <: ActorContext {
    public init() {}

    public func sender(): Option<String> {
        None<String>
    }
}

// ============================================================================
// 1. 测试Actor定义DSL宏
// ============================================================================

// 使用高级Actor定义宏
@actor_def[high_performance]
class AdvancedActor <: Actor {
    private var id: Int64 = 1
    private var actorName: String = "AdvancedActor"
    private var processedMessages: Int64 = 0

    public init() {}

    public prop name: String { get() { actorName } }
    public prop description: String { get() { "高级测试Actor" } }

    public func receive(message: Message, context: ActorContext): MessageResult {
        processedMessages += 1
        println("AdvancedActor 处理消息: " + message.messageType())
        return MessageResult.Handled
    }

    public func processMessage(msg: String): String {
        processedMessages += 1
        return "处理消息: " + msg
    }

    public func getProcessedCount(): Int64 {
        return processedMessages
    }
}

// 测试Actor定义DSL功能
func testActorDefDSL(): Bool {
    println("🧪 测试Actor定义DSL宏...")
    
    var actor = AdvancedActor()
    let info = actor.getActorInfo()
    println("Actor信息: " + info)
    
    // 测试状态管理器
    var stateManager = actor.createStateManager()
    stateManager.setState("RUNNING")
    stateManager.setState("PROCESSING")
    let currentState = stateManager.getCurrentState()
    
    if (currentState != "PROCESSING") {
        println("❌ 状态管理器测试失败")
        return false
    }
    
    // 测试消息处理器
    var messageHandler = actor.createMessageHandler()
    let result = messageHandler.handleMessage("TEST", "payload")
    let msgCount = messageHandler.getMessageCount()
    
    if (msgCount != 1) {
        println("❌ 消息处理器测试失败")
        return false
    }
    
    println("✅ Actor定义DSL宏测试通过")
    return true
}

// ============================================================================
// 2. 测试消息处理DSL宏
// ============================================================================

// 使用消息处理宏
@message_handler
class MessageProcessor <: Actor {
    private var processedCount: Int64 = 0
    private var processorName: String = "MessageProcessor"

    public init() {}

    public prop name: String { get() { processorName } }
    public prop description: String { get() { "消息处理器Actor" } }

    public func receive(message: Message, context: ActorContext): MessageResult {
        processedCount += 1
        return MessageResult.Handled
    }

    public func process(msg: String): String {
        processedCount += 1
        return "已处理: " + msg
    }

    public func getProcessedCount(): Int64 {
        return processedCount
    }
}

// 测试消息处理DSL功能
func testMessageHandlerDSL(): Bool {
    println("🧪 测试消息处理DSL宏...")
    
    var processor = MessageProcessor()
    
    // 测试消息分发
    let result1 = processor.dispatchMessage("INIT", "初始化")
    let result2 = processor.dispatchMessage("PROCESS", "业务数据")
    let result3 = processor.dispatchMessage("UNKNOWN", "未知消息")
    
    if (result1 != "INIT_OK" || result2 != "PROCESS_OK" || result3 != "UNKNOWN") {
        println("❌ 消息分发测试失败")
        return false
    }
    
    println("✅ 消息处理DSL宏测试通过")
    return true
}

// ============================================================================
// 3. 测试路由表生成宏
// ============================================================================

// 使用路由表宏
@route_table[message_routing]
class RouterActor <: Actor {
    private var routedMessages: Int64 = 0
    private var routerName: String = "RouterActor"

    public init() {}

    public prop name: String { get() { routerName } }
    public prop description: String { get() { "路由器Actor" } }

    public func receive(message: Message, context: ActorContext): MessageResult {
        routedMessages += 1
        return MessageResult.Handled
    }

    public func routeMessage(msg: String): String {
        routedMessages += 1
        return "路由消息: " + msg
    }

    public func getRoutedCount(): Int64 {
        return routedMessages
    }
}

// 测试路由表功能
func testRouteTableDSL(): Bool {
    println("🧪 测试路由表生成宏...")
    
    var routerActor = RouterActor()
    var router = routerActor.createRouter()
    
    // 测试路由查找
    let route1 = router.findRoute("INIT_MESSAGE")
    let route2 = router.findRoute("PROCESS_DATA")
    let route3 = router.findRoute("UNKNOWN_MSG")
    
    if (route1 != "INIT" || route2 != "PROCESS" || route3 != "DEFAULT") {
        println("❌ 路由查找测试失败")
        return false
    }
    
    let routeCount = router.getRouteCount()
    if (routeCount != 3) {
        println("❌ 路由数量测试失败")
        return false
    }
    
    println("✅ 路由表生成宏测试通过")
    return true
}

// ============================================================================
// 4. 测试性能监控宏
// ============================================================================

// 使用Actor性能监控宏
@actor_perf_monitor
class PerfActor <: Actor {
    private var perfName: String = "PerfActor"

    public init() {}

    public prop name: String { get() { perfName } }
    public prop description: String { get() { "性能监控Actor" } }

    public func receive(message: Message, context: ActorContext): MessageResult {
        return MessageResult.Handled
    }

    public func doWork(): String {
        return "工作完成"
    }
}

// 测试性能监控功能
func testPerfMonitorDSL(): Bool {
    println("🧪 测试性能监控宏...")

    // 测试Actor性能监控
    var perfActor = PerfActor()
    var perfMonitor = perfActor.createPerfMonitor()
    perfMonitor.recordCall("doWork", 50)

    let methodCalls = perfMonitor.getMethodCalls()
    if (methodCalls != 1) {
        println("❌ Actor性能监控测试失败")
        return false
    }

    let perfInfo = perfActor.getPerfInfo()
    println("性能监控信息: " + perfInfo)

    println("✅ 性能监控宏测试通过")
    return true
}

// ============================================================================
// 5. 测试基础宏功能验证
// ============================================================================

// 测试基础宏功能
func testBasicMacroFeatures(): Bool {
    println("🧪 测试基础宏功能...")

    // 测试日志宏
    @log_info("基础宏功能测试")

    // 测试计时宏
    @time_it(
        var sum: Int64 = 0
        for (i in 0..10) {
            sum += i
        }
        println("计算结果: " + sum.toString())
    )

    // 测试重复执行宏
    var counter: Int64 = 0
    @repeat_3_times(
        counter += 1
        println("重复执行第" + counter.toString() + "次")
    )

    if (counter != 3) {
        println("❌ 重复执行宏测试失败")
        return false
    }

    println("✅ 基础宏功能测试通过")
    return true
}

// ============================================================================
// 主测试函数
// ============================================================================

main(): Int64 {
    println("=== CActor 高级宏功能测试 ===")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testActorDefDSL()
    allTestsPassed = allTestsPassed && testMessageHandlerDSL()
    allTestsPassed = allTestsPassed && testRouteTableDSL()
    allTestsPassed = allTestsPassed && testPerfMonitorDSL()
    allTestsPassed = allTestsPassed && testBasicMacroFeatures()
    
    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有高级宏测试通过！")
        println("✅ plan3.md 高级宏功能验证成功")
        println("🚀 CActor高级DSL系统已完全就绪")
        return 0
    } else {
        println("❌ 部分高级宏测试失败")
        return 1
    }
}
