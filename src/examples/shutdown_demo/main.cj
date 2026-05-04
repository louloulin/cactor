/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - CoordinatedShutdown 示例程序
 * 展示协调关闭机制的使用
 */
package cactor.examples.shutdown_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示关闭事件处理器
 */
public class DemoShutdownHandler <: CoordinatedShutdownEventHandler {
    public let startEvents = ArrayList<String>()
    public let phaseStartedEvents = ArrayList<String>()
    public let phaseCompletedEvents = ArrayList<String>()
    public let taskCompletedEvents = ArrayList<String>()
    public let taskFailedEvents = ArrayList<String>()

    public func onShutdownStarted(reason: ShutdownReason, phase: ShutdownPhase): Unit {
        let event = "${reason} from phase ${phase}"
        startEvents.add(event)
        println("  [START] Shutdown initiated: ${reason}")
    }

    public func onPhaseStarted(phase: ShutdownPhase, taskCount: Int64): Unit {
        let event = "${phase} (${taskCount} tasks)"
        phaseStartedEvents.add(event)
        println("  [PHASE] Starting: ${phase} (${taskCount} tasks)")
    }

    public func onPhaseCompleted(phase: ShutdownPhase, success: Bool): Unit {
        let event = "${phase} -> ${if (success) "OK" else "FAILED"}"
        phaseCompletedEvents.add(event)
        println("  [PHASE] Completed: ${phase} - ${if (success) "SUCCESS" else "FAILED"}")
    }

    public func onTaskCompleted(taskName: String, phase: ShutdownPhase): Unit {
        taskCompletedEvents.add(taskName)
        println("    [TASK] Completed: ${taskName}")
    }

    public func onTaskFailed(taskName: String, phase: ShutdownPhase, reason: String): Unit {
        taskFailedEvents.add(taskName)
        println("    [TASK] FAILED: ${taskName} - ${reason}")
    }

    public func onShutdownCompleted(result: ShutdownResult): Unit {
        println()
        println("=== Shutdown Summary ===")
        println("  Reason: ${result.reason}")
        println("  Total tasks: ${result.totalTasks}")
        println("  Failed tasks: ${result.failedTasks}")
        println("  Overall: ${if (result.success) "SUCCESS" else "FAILED"}")
    }
}

/**
 * 模拟服务
 */
public class MockService {
    public let name: String
    public var isRunning: Bool
    public var connectionCount: Int64

    public init(name: String) {
        this.name = name
        this.isRunning = true
        this.connectionCount = 0
    }

    public func start(): Unit {
        isRunning = true
        println("  [SERVICE] ${name} started")
    }

    public func connect(): Unit {
        connectionCount += 1
        println("  [SERVICE] ${name}: new connection (total: ${connectionCount})")
    }

    public func stop(): Unit {
        isRunning = false
        println("  [SERVICE] ${name} stopped (handled ${connectionCount} connections)")
    }
}

/**
 * 运行基本关闭演示
 */
public func runBasicShutdownDemo(): Unit {
    println("=== Basic CoordinatedShutdown Demo ===")
    let cs = createCoordinatedShutdown("node-1")
    let handler = DemoShutdownHandler()
    cs.setEventHandler(handler)

    println("Adding shutdown tasks...")
    cs.addClusterTask("leave-cluster", ShutdownPhase.PhaseClusterExiting, { => println("    Leaving cluster...") })
    cs.addServiceStopTask("stop-http-server", { => println("    Stopping HTTP server...") })
    cs.addServiceStopTask("close-db-connections", { => println("    Closing database connections...") })
    cs.addExternalServiceTask("close-connections", { => println("    Closing external connections...") })

    println()
    println("Executing coordinated shutdown...")
    let result = cs.run(ShutdownReason.NodeShutdown)
    println()
}

/**
 * 运行服务停止演示
 */
public func runServiceStopDemo(): Unit {
    println("=== Service Stop Demo ===")
    let cs = createCoordinatedShutdown("node-1")
    let handler = DemoShutdownHandler()
    cs.setEventHandler(handler)

    // 模拟服务
    let httpServer = MockService("HTTP Server")
    let dbService = MockService("Database Service")
    let cacheService = MockService("Cache Service")
    let queueService = MockService("Queue Service")

    httpServer.start()
    dbService.start()
    cacheService.start()
    queueService.start()

    println()
    println("Registering shutdown tasks...")
    cs.addServiceStopTask("shutdown-http", { => httpServer.stop() })
    cs.addServiceStopTask("shutdown-db", { => dbService.stop() })
    cs.addServiceStopTask("shutdown-cache", { => cacheService.stop() })
    cs.addServiceStopTask("shutdown-queue", { => queueService.stop() })

    println()
    println("Starting coordinated shutdown...")
    cs.run(ShutdownReason.NodeShutdown)
    println()
}

/**
 * 运行集群关闭演示
 */
public func runClusterShutdownDemo(): Unit {
    println("=== Cluster Shutdown Demo ===")
    let cs = createCoordinatedShutdown("cluster-leader")
    let handler = DemoShutdownHandler()
    cs.setEventHandler(handler)

    println("Simulating cluster-aware shutdown sequence...")

    // 集群退出前阶段
    cs.addTask("drain-ingress", ShutdownPhase.PhaseBeforeClusterQuarantined, { =>
        println("  [PHASE-0] Draining ingress traffic...")
    })

    // 集群退出阶段
    cs.addClusterTask("notify-leaving", ShutdownPhase.PhaseClusterExiting, { =>
        println("  [PHASE-1] Notifying other nodes about leaving...")
    })
    cs.addClusterTask("migrate-shards", ShutdownPhase.PhaseClusterExiting, { =>
        println("  [PHASE-1] Migrating shards to other nodes...")
    })

    // 分片协调器关闭
    cs.addClusterTask("close-coordinator", ShutdownPhase.PhaseClusterSharding, { =>
        println("  [PHASE-2] Closing shard coordinator...")
    })

    // 单例协调器关闭
    cs.addClusterTask("release-singletons", ShutdownPhase.PhaseClusterSingleton, { =>
        println("  [PHASE-3] Releasing cluster singletons...")
    })

    // 服务停止
    cs.addServiceStopTask("stop-services", { =>
        println("  [PHASE-4] Stopping application services...")
    })

    println()
    println("Running cluster shutdown...")
    cs.run(ShutdownReason.ClusterShutdown)
    println()
}

/**
 * 运行带超时的任务演示
 */
public func runTimeoutTaskDemo(): Unit {
    println("=== Timeout Task Demo ===")
    let cs = createCoordinatedShutdown("node-1")
    let handler = DemoShutdownHandler()
    cs.setEventHandler(handler)

    println("Adding tasks with custom timeouts...")

    // 正常快速任务
    cs.addTaskWithTimeout(
        "quick-cleanup",
        ShutdownPhase.PhaseServiceStop,
        { => println("    Quick cleanup done") },
        Duration.second * 5
    )

    // 长时间运行任务
    cs.addTaskWithTimeout(
        "drain-queue",
        ShutdownPhase.PhaseServiceStop,
        { => println("    Draining message queue...") },
        Duration.second * 60
    )

    // 外部服务关闭
    cs.addTaskWithTimeout(
        "close-connections",
        ShutdownPhase.PhaseExternalServices,
        { => println("    Closing all connections...") },
        Duration.second * 30
    )

    println()
    println("Running shutdown with timeouts...")
    cs.run(ShutdownReason.NodeShutdown)
    println()
}

/**
 * 运行失败处理演示
 */
public func runFailureHandlingDemo(): Unit {
    println("=== Failure Handling Demo ===")

    // 使用 abortOnFailure = false 的配置
    let config = CoordinatedShutdownConfig(
        Duration.second * 30,
        Duration.second * 1,
        3,
        false,  // abortOnFailure = false
        true
    )
    let cs = createCoordinatedShutdownWithConfig("node-1", config)
    let handler = DemoShutdownHandler()
    cs.setEventHandler(handler)

    println("Adding tasks with intentional failure...")
    cs.addServiceStopTask("first-service", { => println("    Stopping first service...") })
    cs.addServiceStopTask("second-service-fail", { =>
        println("    Stopping second service... (FAILING)")
        throw Exception("Connection refused")
    })
    cs.addServiceStopTask("third-service", { => println("    Stopping third service...") })
    cs.addServiceStopTask("fourth-service", { => println("    Stopping fourth service...") })

    println()
    println("Running shutdown (abortOnFailure=false)...")
    let result = cs.run(ShutdownReason.NodeShutdown)

    println()
    println("Result: ${if (result.success) "SUCCESS" else "PARTIAL FAILURE"}")
    println("  Completed tasks: ${result.totalTasks - result.failedTasks}")
    println("  Failed tasks: ${result.failedTasks}")
    println()

    // 显示哪些任务失败
    if (handler.taskFailedEvents.size > 0) {
        println("Failed task names:")
        for (name in handler.taskFailedEvents) {
            println("  - ${name}")
        }
    }
    println()
}

/**
 * 运行阶段顺序演示
 */
public func runPhaseOrderDemo(): Unit {
    println("=== Phase Order Demo ===")
    let cs = createCoordinatedShutdown("node-1")

    // 添加不同阶段的任务
    cs.addTask("early-task", ShutdownPhase.PhaseBeforeClusterQuarantined, { => () })
    cs.addTask("cluster-exit", ShutdownPhase.PhaseClusterExiting, { => () })
    cs.addTask("sharding", ShutdownPhase.PhaseClusterSharding, { => () })
    cs.addTask("singleton", ShutdownPhase.PhaseClusterSingleton, { => () })
    cs.addTask("service", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("app-service", ShutdownPhase.PhaseApplicationServices, { => () })
    cs.addTask("external", ShutdownPhase.PhaseExternalServices, { => () })

    println("Shutdown phases in order:")
    let order = cs.getPhaseOrder()
    for (phase in order) {
        let count = cs.taskCountForPhase(phase)
        let phaseName = match (phase) {
            case ShutdownPhase.PhaseBeforeClusterQuarantined => "Before Cluster Quarantined"
            case ShutdownPhase.PhaseClusterExiting => "Cluster Exiting"
            case ShutdownPhase.PhaseClusterSharding => "Cluster Sharding"
            case ShutdownPhase.PhaseClusterSingleton => "Cluster Singleton"
            case ShutdownPhase.PhaseServiceStop => "Service Stop"
            case ShutdownPhase.PhaseApplicationServices => "Application Services"
            case ShutdownPhase.PhaseExternalServices => "External Services"
            case ShutdownPhase.PhaseDone => "Done"
        }
        println("  ${phaseName}: ${count} tasks")
    }
    println()
}

/**
 * 运行关闭钩子演示
 */
public func runShutdownHookDemo(): Unit {
    println("=== Shutdown Hook Manager Demo ===")
    let manager = ShutdownHookManager()

    println("Registering shutdown hooks...")
    manager.register({ => println("  [HOOK] Flushing logs...") })
    manager.register({ => println("  [HOOK] Saving state to disk...") })
    manager.register({ => println("  [HOOK] Closing file handles...") })

    println("Hook count: ${manager.hookCount()}")

    println()
    println("Executing shutdown hooks...")
    manager.execute()

    println("Hook count after execution: ${manager.hookCount()}")
    println()
}

/**
 * 运行完整演示
 */
public func runFullDemo(): Unit {
    println("CActor CoordinatedShutdown Demo")
    println("==================================")
    println()

    runBasicShutdownDemo()
    runServiceStopDemo()
    runClusterShutdownDemo()
    runTimeoutTaskDemo()
    runFailureHandlingDemo()
    runPhaseOrderDemo()
    runShutdownHookDemo()

    println("=== Demo Complete ===")
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    runFullDemo()
}