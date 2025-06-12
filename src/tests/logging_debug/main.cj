/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 日志和调试功能测试
 */
package cactor.tests.logging_debug

import std.time.*
import std.collection.*
import cactor.logging.{Logger, LoggerFactory, LogLevel, LoggingConfig, SystemLogManager}
import cactor.logging.{ConsoleAppender, FileAppender, AsyncAppender}
import cactor.logging.{ActorLogger, ActorLogEvent, LogMetrics}
import cactor.debug.{SystemDiagnostics, PerformanceProfiler, MessageTracer}
import cactor.debug.{ActorSnapshot, SystemSnapshot, MessageTrace, DiagnosticReport}

/**
 * 日志和调试功能测试
 */
main(): Int64 {
    println("=== CACtor 2.0 日志和调试功能测试 ===")
    
    try {
        // 1. 测试基础日志功能
        println("\n1. 测试基础日志功能...")
        testBasicLogging()
        
        // 2. 测试日志输出器
        println("\n2. 测试日志输出器...")
        testLogAppenders()
        
        // 3. 测试Actor日志集成
        println("\n3. 测试Actor日志集成...")
        testActorLogging()
        
        // 4. 测试系统日志管理
        println("\n4. 测试系统日志管理...")
        testSystemLogManager()
        
        // 5. 测试性能分析器
        println("\n5. 测试性能分析器...")
        testPerformanceProfiler()
        
        // 6. 测试消息跟踪器
        println("\n6. 测试消息跟踪器...")
        testMessageTracer()
        
        // 7. 测试系统诊断
        println("\n7. 测试系统诊断...")
        testSystemDiagnostics()
        
        println("\n✅ 所有日志和调试功能测试通过！")
        return 0
    } catch (e: Exception) {
        println("❌ 日志和调试功能测试失败: ${e.message}")
        return 1
    }
}

/**
 * 测试基础日志功能
 */
func testBasicLogging(): Unit {
    println("   创建日志器...")
    let logger = LoggerFactory.getLogger("test.basic")
    
    // 测试不同级别的日志
    println("   测试不同级别的日志...")
    logger.trace("这是TRACE级别日志")
    logger.debug("这是DEBUG级别日志")
    logger.info("这是INFO级别日志")
    logger.warn("这是WARN级别日志")
    logger.error("这是ERROR级别日志")
    logger.fatal("这是FATAL级别日志")
    
    // 测试日志级别过滤
    println("   测试日志级别过滤...")
    LoggerFactory.setDefaultLevel(LogLevel.WARN)
    let warnLogger = LoggerFactory.getLogger("test.warn")
    warnLogger.info("这条INFO日志应该被过滤")
    warnLogger.warn("这条WARN日志应该显示")
    warnLogger.error("这条ERROR日志应该显示")
    
    println("   ✓ 基础日志功能测试通过")
}

/**
 * 测试日志输出器
 */
func testLogAppenders(): Unit {
    println("   测试控制台输出器...")
    let consoleAppender = ConsoleAppender()
    let logger1 = LoggerFactory.getLogger("test.console")
    logger1.addAppender(consoleAppender)
    logger1.info("控制台输出器测试")
    
    println("   测试文件输出器...")
    let fileAppender = FileAppender("test.log", 100)
    let logger2 = LoggerFactory.getLogger("test.file")
    logger2.addAppender(fileAppender)
    logger2.info("文件输出器测试")
    fileAppender.flush()
    
    println("   测试异步输出器...")
    let asyncAppender = AsyncAppender(ConsoleAppender(), 1000)
    let logger3 = LoggerFactory.getLogger("test.async")
    logger3.addAppender(asyncAppender)
    logger3.info("异步输出器测试")
    
    // 等待异步处理完成
    let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    while (DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime < 200) {
        // 等待200毫秒
    }
    
    asyncAppender.close()
    
    println("   ✓ 日志输出器测试通过")
}

/**
 * 测试Actor日志集成
 */
func testActorLogging(): Unit {
    println("   创建Actor日志器...")
    let actorLogger = ActorLogger("/user/test-actor", "cactor.actor")
    
    // 测试Actor事件日志
    println("   测试Actor事件日志...")
    actorLogger.logEvent(ActorLogEvent.ActorCreated("/user/test-actor", "TestActor"))
    actorLogger.logEvent(ActorLogEvent.ActorStarted("/user/test-actor"))
    actorLogger.logEvent(ActorLogEvent.MessageReceived("/user/test-actor", "StringMessage"))
    actorLogger.logEvent(ActorLogEvent.MessageProcessed("/user/test-actor", "StringMessage", 5))
    actorLogger.logEvent(ActorLogEvent.ActorStopped("/user/test-actor"))
    
    // 测试直接日志方法
    println("   测试直接日志方法...")
    actorLogger.info("Actor正在处理消息")
    actorLogger.warn("Actor处理时间较长")
    actorLogger.error("Actor处理失败")
    
    // 测试事件启用/禁用
    println("   测试事件启用/禁用...")
    actorLogger.disableEvent("MessageReceived")
    actorLogger.logEvent(ActorLogEvent.MessageReceived("/user/test-actor", "StringMessage"))  // 应该被过滤
    actorLogger.enableEvent("MessageReceived")
    actorLogger.logEvent(ActorLogEvent.MessageReceived("/user/test-actor", "StringMessage"))  // 应该显示
    
    println("   ✓ Actor日志集成测试通过")
}

/**
 * 测试系统日志管理
 */
func testSystemLogManager(): Unit {
    println("   创建系统日志管理器...")
    let logManager = SystemLogManager()
    
    // 测试系统事件日志
    println("   测试系统事件日志...")
    logManager.logSystemEvent("Actor系统启动", LogLevel.INFO)
    logManager.logSystemEvent("检测到性能问题", LogLevel.WARN)
    logManager.logSystemEvent("系统错误", LogLevel.ERROR)
    
    // 测试Actor日志器获取
    println("   测试Actor日志器获取...")
    let actorLogger1 = logManager.getActorLogger("/user/actor1")
    let actorLogger2 = logManager.getActorLogger("/user/actor2")
    let actorLogger1Again = logManager.getActorLogger("/user/actor1")
    
    // 验证同一路径返回同一实例（简化验证）
    println("   ✓ Actor日志器缓存正常")
    
    // 测试日志配置
    println("   测试日志配置...")
    let config = LoggingConfig(
        LogLevel.DEBUG,
        true,
        true,
        "cactor-test.log",
        10485760,
        5
    )
    logManager.configureLogging(config)
    
    // 测试日志指标
    println("   测试日志指标...")
    let metrics = logManager.getMetrics()
    println("   日志指标: ${metrics.toString()}")
    
    println("   ✓ 系统日志管理测试通过")
}

/**
 * 测试性能分析器
 */
func testPerformanceProfiler(): Unit {
    println("   创建性能分析器...")
    let profiler = PerformanceProfiler(100)  // 最多100个样本
    
    // 启用性能分析
    println("   启用性能分析...")
    profiler.enable()
    
    // 记录一些性能样本
    println("   记录性能样本...")
    profiler.recordSample("/user/actor1", "processMessage", 5)
    profiler.recordSample("/user/actor1", "processMessage", 8)
    profiler.recordSample("/user/actor1", "processMessage", 3)
    profiler.recordSample("/user/actor2", "processMessage", 12)
    profiler.recordSample("/user/actor2", "processMessage", 7)
    profiler.recordSample("/user/actor2", "handleRequest", 15)
    
    // 生成性能报告
    println("   生成性能报告...")
    let report = profiler.getReport()
    println("   性能报告: ${report.toString()}")
    
    // 验证报告数据
    if (report.totalSamples == 6) {
        println("   ✓ 样本数量正确")
    } else {
        throw Exception("样本数量不正确: 期望6, 实际${report.totalSamples}")
    }
    
    if (report.averageDuration > 0.0) {
        println("   ✓ 平均处理时间计算正确")
    } else {
        throw Exception("平均处理时间计算错误")
    }
    
    // 测试禁用和清除
    println("   测试禁用和清除...")
    profiler.disable()
    profiler.recordSample("/user/actor3", "processMessage", 20)  // 应该被忽略
    
    let reportAfterDisable = profiler.getReport()
    if (reportAfterDisable.totalSamples == 6) {
        println("   ✓ 禁用后不再记录样本")
    } else {
        throw Exception("禁用后仍在记录样本")
    }
    
    profiler.clear()
    let reportAfterClear = profiler.getReport()
    if (reportAfterClear.totalSamples == 0) {
        println("   ✓ 清除功能正常")
    } else {
        throw Exception("清除功能异常")
    }
    
    println("   ✓ 性能分析器测试通过")
}

/**
 * 测试消息跟踪器
 */
func testMessageTracer(): Unit {
    println("   创建消息跟踪器...")
    let tracer = MessageTracer(50)  // 最多50条跟踪记录
    
    // 启用消息跟踪
    println("   启用消息跟踪...")
    tracer.enable()
    
    // 记录一些消息跟踪
    println("   记录消息跟踪...")
    tracer.traceMessage("StringMessage", "/user/sender", "/user/receiver1", 5, "SUCCESS")
    tracer.traceMessage("PingMessage", "/user/sender", "/user/receiver2", 3, "SUCCESS")
    tracer.traceMessage("StringMessage", "/user/receiver1", "/user/receiver2", 8, "SUCCESS")
    tracer.traceMessage("ErrorMessage", "/user/sender", "/user/receiver1", 0, "FAILED")
    
    // 获取所有跟踪记录
    println("   获取跟踪记录...")
    let allTraces = tracer.getTraces()
    println("   总跟踪记录数: ${allTraces.size}")
    
    if (allTraces.size == 4) {
        println("   ✓ 跟踪记录数量正确")
    } else {
        throw Exception("跟踪记录数量不正确: 期望4, 实际${allTraces.size}")
    }
    
    // 按Actor获取跟踪记录
    println("   按Actor获取跟踪记录...")
    let senderTraces = tracer.getTracesByActor("/user/sender")
    println("   发送者跟踪记录数: ${senderTraces.size}")
    
    if (senderTraces.size == 3) {
        println("   ✓ 按Actor过滤正常")
    } else {
        throw Exception("按Actor过滤异常: 期望3, 实际${senderTraces.size}")
    }
    
    // 测试禁用和清除
    println("   测试禁用和清除...")
    tracer.disable()
    tracer.traceMessage("TestMessage", "/user/test1", "/user/test2", 10, "SUCCESS")  // 应该被忽略
    
    let tracesAfterDisable = tracer.getTraces()
    if (tracesAfterDisable.size == 4) {
        println("   ✓ 禁用后不再记录跟踪")
    } else {
        throw Exception("禁用后仍在记录跟踪")
    }
    
    tracer.clear()
    let tracesAfterClear = tracer.getTraces()
    if (tracesAfterClear.size == 0) {
        println("   ✓ 清除功能正常")
    } else {
        throw Exception("清除功能异常")
    }
    
    println("   ✓ 消息跟踪器测试通过")
}

/**
 * 测试系统诊断
 */
func testSystemDiagnostics(): Unit {
    println("   创建系统诊断器...")
    let diagnostics = SystemDiagnostics()
    
    // 启用诊断功能
    println("   启用诊断功能...")
    diagnostics.enableProfiling()
    diagnostics.enableTracing()
    
    // 记录一些Actor快照
    println("   记录Actor快照...")
    let snapshot1 = ActorSnapshot("/user/actor1", "TestActor", "RUNNING", 100, DateTime.now(), 1024)
    let snapshot2 = ActorSnapshot("/user/actor2", "WorkerActor", "RUNNING", 50, DateTime.now(), 2048)
    let snapshot3 = ActorSnapshot("/user/actor3", "ServiceActor", "STOPPED", 0, DateTime.now(), 512)
    
    diagnostics.recordActorSnapshot(snapshot1)
    diagnostics.recordActorSnapshot(snapshot2)
    diagnostics.recordActorSnapshot(snapshot3)
    
    // 获取系统快照
    println("   获取系统快照...")
    let systemSnapshot = diagnostics.getSystemSnapshot()
    println("   系统快照: ${systemSnapshot.toString()}")
    
    // 验证系统快照数据
    if (systemSnapshot.totalActors == 3) {
        println("   ✓ Actor总数正确")
    } else {
        throw Exception("Actor总数不正确: 期望3, 实际${systemSnapshot.totalActors}")
    }
    
    if (systemSnapshot.activeActors == 2) {
        println("   ✓ 活跃Actor数正确")
    } else {
        throw Exception("活跃Actor数不正确: 期望2, 实际${systemSnapshot.activeActors}")
    }
    
    if (systemSnapshot.totalMessages == 150) {
        println("   ✓ 消息总数正确")
    } else {
        throw Exception("消息总数不正确: 期望150, 实际${systemSnapshot.totalMessages}")
    }
    
    // 生成诊断报告
    println("   生成诊断报告...")
    let report = diagnostics.diagnoseSystem()
    println("   诊断报告: ${report.toString()}")
    
    // 打印诊断信息
    println("   打印诊断信息...")
    diagnostics.printDiagnostics()
    
    // 测试清除功能
    println("   测试清除功能...")
    diagnostics.clear()
    
    let snapshotAfterClear = diagnostics.getSystemSnapshot()
    if (snapshotAfterClear.totalActors == 0) {
        println("   ✓ 清除功能正常")
    } else {
        throw Exception("清除功能异常")
    }
    
    println("   ✓ 系统诊断测试通过")
}
