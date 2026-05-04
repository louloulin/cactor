/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - CoordinatedShutdown 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === ShutdownPhase Tests ===

@Test
func testShutdownPhase_values() {
    @Expect(ShutdownPhase.PhaseBeforeClusterQuarantined.toString().size > 0, true)
    @Expect(ShutdownPhase.PhaseClusterExiting.toString().size > 0, true)
    @Expect(ShutdownPhase.PhaseClusterSharding.toString().size > 0, true)
    @Expect(ShutdownPhase.PhaseDone.toString().size > 0, true)
}

// === ShutdownReason Tests ===

@Test
func testShutdownReason_values() {
    @Expect(ShutdownReason.NodeShutdown.toString().size > 0, true)
    @Expect(ShutdownReason.ClusterShutdown.toString().size > 0, true)
    @Expect(ShutdownReason.Crashed.toString().size > 0, true)
}

// === ShutdownTask Tests ===

@Test
func testShutdownTask_creation() {
    var executed = false
    let task = ShutdownTask(
        "test-task",
        ShutdownPhase.PhaseServiceStop,
        { => executed = true },
        Duration.second * 5
    )
    @Expect(task.name, "test-task")
    @Expect(task.phase, ShutdownPhase.PhaseServiceStop)
    @Expect(task.timeout, Duration.second * 5)
    @Expect(task.executed, false)
}

// === CoordinatedShutdown Tests ===

@Test
func testCoordinatedShutdown_creation() {
    let cs = createCoordinatedShutdown("node-1")
    @Expect(cs.getNodeId(), "node-1")
    @Expect(cs.isShuttingDown(), false)
}

@Test
func testCoordinatedShutdown_addTask() {
    let cs = createCoordinatedShutdown("node-1")
    var executed = false
    cs.addTask("test-task", ShutdownPhase.PhaseServiceStop, { => executed = true })
    @Expect(cs.taskCount(), 1)
    @Expect(cs.taskCountForPhase(ShutdownPhase.PhaseServiceStop), 1)
}

@Test
func testCoordinatedShutdown_addClusterTask() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addClusterTask("cluster-leave", ShutdownPhase.PhaseClusterExiting, { => () })
    @Expect(cs.taskCount(), 1)
}

@Test
func testCoordinatedShutdown_addServiceStopTask() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addServiceStopTask("stop-service", { => () })
    @Expect(cs.taskCountForPhase(ShutdownPhase.PhaseServiceStop), 1)
}

@Test
func testCoordinatedShutdown_addExternalServiceTask() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addExternalServiceTask("close-connection", { => () })
    @Expect(cs.taskCountForPhase(ShutdownPhase.PhaseExternalServices), 1)
}

@Test
func testCoordinatedShutdown_addTaskWithTimeout() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTaskWithTimeout(
        "timeout-task",
        ShutdownPhase.PhaseApplicationServices,
        { => () },
        Duration.second * 10
    )
    @Expect(cs.taskCountForPhase(ShutdownPhase.PhaseApplicationServices), 1)
}

@Test
func testCoordinatedShutdown_multipleTasks() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTask("task-1", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-2", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-3", ShutdownPhase.PhaseClusterSharding, { => () })
    @Expect(cs.taskCount(), 3)
    @Expect(cs.taskCountForPhase(ShutdownPhase.PhaseServiceStop), 2)
    @Expect(cs.taskCountForPhase(ShutdownPhase.PhaseClusterSharding), 1)
}

@Test
func testCoordinatedShutdown_run() {
    let cs = createCoordinatedShutdown("node-1")
    var executed1 = false
    var executed2 = false
    cs.addTask("task-1", ShutdownPhase.PhaseServiceStop, { => executed1 = true })
    cs.addTask("task-2", ShutdownPhase.PhaseServiceStop, { => executed2 = true })

    let result = cs.run(ShutdownReason.NodeShutdown)
    @Expect(result.success, true)
    @Expect(result.totalTasks, 2)
    @Expect(result.failedTasks, 0)
    @Expect(executed1, true)
    @Expect(executed2, true)
}

@Test
func testCoordinatedShutdown_runWithFailure() {
    let config = CoordinatedShutdownConfig(
        Duration.second * 30,
        Duration.second * 1,
        3,
        false,  // abortOnFailure = false
        true
    )
    let cs = createCoordinatedShutdownWithConfig("node-1", config)
    cs.addTask("success-task", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("fail-task", ShutdownPhase.PhaseServiceStop, { => throw Exception("Test failure") })
    cs.addTask("another-task", ShutdownPhase.PhaseServiceStop, { => () })

    let result = cs.run(ShutdownReason.NodeShutdown)
    @Expect(result.success, false)
    @Expect(result.failedTasks, 1)
}

@Test
func testCoordinatedShutdown_runAbortedOnFailure() {
    let config = CoordinatedShutdownConfig(
        Duration.second * 30,
        Duration.second * 1,
        3,
        true,  // abortOnFailure = true
        true
    )
    let cs = createCoordinatedShutdownWithConfig("node-1", config)
    var executedCount = 0
    cs.addTask("task-1", ShutdownPhase.PhaseServiceStop, { => executedCount += 1 })
    cs.addTask("fail-task", ShutdownPhase.PhaseServiceStop, { => throw Exception("Test failure") })
    cs.addTask("task-3", ShutdownPhase.PhaseServiceStop, { => executedCount += 1 })

    let result = cs.run(ShutdownReason.NodeShutdown)
    @Expect(result.success, false)
    @Expect(result.failedTasks, 1)
}

@Test
func testCoordinatedShutdown_getCurrentPhase() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTask("task", ShutdownPhase.PhaseServiceStop, { => () })
    @Expect(cs.getCurrentPhase().isNone(), true)
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(cs.getCurrentPhase().getOrThrow(), ShutdownPhase.PhaseDone)
}

@Test
func testCoordinatedShutdown_getPhaseOrder() {
    let cs = createCoordinatedShutdown("node-1")
    let order = cs.getPhaseOrder()
    @Expect(order.size, 8)
    @Expect(order[0], ShutdownPhase.PhaseBeforeClusterQuarantined)
    @Expect(order[order.size - 1], ShutdownPhase.PhaseDone)
}

@Test
func testCoordinatedShutdown_clearAllTasks() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTask("task-1", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-2", ShutdownPhase.PhaseClusterExiting, { => () })
    @Expect(cs.taskCount(), 2)
    cs.clearAllTasks()
    @Expect(cs.taskCount(), 0)
}

@Test
func testCoordinatedShutdown_clearPhaseTasks() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTask("task-1", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-2", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-3", ShutdownPhase.PhaseClusterExiting, { => () })
    let cleared = cs.clearPhaseTasks(ShutdownPhase.PhaseServiceStop)
    @Expect(cleared, 2)
    @Expect(cs.taskCount(), 1)
}

@Test
func testCoordinatedShutdown_getAllTasks() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTask("task-a", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-b", ShutdownPhase.PhaseClusterSharding, { => () })
    let allTasks = cs.getAllTasks()
    @Expect(allTasks.size, 2)
}

@Test
func testCoordinatedShutdown_runDuplicatePrevention() {
    let cs = createCoordinatedShutdown("node-1")
    cs.addTask("task", ShutdownPhase.PhaseServiceStop, { => () })
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(cs.isShuttingDown(), true)
    let result = cs.run(ShutdownReason.NodeShutdown)
    @Expect(result.totalTasks, 0)
}

// === CoordinatedShutdownEventHandler Tests ===

class TestShutdownHandler <: CoordinatedShutdownEventHandler {
    public let startEvents = ArrayList<String>()
    public let phaseStartedEvents = ArrayList<ShutdownPhase>()
    public let phaseCompletedEvents = ArrayList<(ShutdownPhase, Bool)>()
    public let taskCompletedEvents = ArrayList<String>()
    public let taskFailedEvents = ArrayList<String>()
    public var completedResult: Option<ShutdownResult> = None

    public func onShutdownStarted(reason: ShutdownReason, phase: ShutdownPhase): Unit {
        startEvents.add(reason.toString())
    }

    public func onPhaseStarted(phase: ShutdownPhase, taskCount: Int64): Unit {
        phaseStartedEvents.add(phase)
    }

    public func onPhaseCompleted(phase: ShutdownPhase, success: Bool): Unit {
        phaseCompletedEvents.add((phase, success))
    }

    public func onTaskCompleted(taskName: String, phase: ShutdownPhase): Unit {
        taskCompletedEvents.add(taskName)
    }

    public func onTaskFailed(taskName: String, phase: ShutdownPhase, reason: String): Unit {
        taskFailedEvents.add(taskName)
    }

    public func onShutdownCompleted(result: ShutdownResult): Unit {
        completedResult = Some(result)
    }
}

@Test
func testCoordinatedShutdown_eventHandler_shutdownStarted() {
    let cs = createCoordinatedShutdown("node-1")
    let handler = TestShutdownHandler()
    cs.setEventHandler(handler)
    cs.addTask("task", ShutdownPhase.PhaseServiceStop, { => () })
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(handler.startEvents.size, 1)
}

@Test
func testCoordinatedShutdown_eventHandler_phaseStarted() {
    let cs = createCoordinatedShutdown("node-1")
    let handler = TestShutdownHandler()
    cs.setEventHandler(handler)
    cs.addTask("task-1", ShutdownPhase.PhaseServiceStop, { => () })
    cs.addTask("task-2", ShutdownPhase.PhaseServiceStop, { => () })
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(handler.phaseStartedEvents.size >= 1, true)
}

@Test
func testCoordinatedShutdown_eventHandler_taskCompleted() {
    let cs = createCoordinatedShutdown("node-1")
    let handler = TestShutdownHandler()
    cs.setEventHandler(handler)
    cs.addTask("my-task", ShutdownPhase.PhaseServiceStop, { => () })
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(handler.taskCompletedEvents.size, 1)
    @Expect(handler.taskCompletedEvents[0], "my-task")
}

@Test
func testCoordinatedShutdown_eventHandler_taskFailed() {
    let config = CoordinatedShutdownConfig(
        Duration.second * 30, Duration.second * 1, 3, false, true
    )
    let cs = createCoordinatedShutdownWithConfig("node-1", config)
    let handler = TestShutdownHandler()
    cs.setEventHandler(handler)
    cs.addTask("failing-task", ShutdownPhase.PhaseServiceStop, { => throw Exception("Failed") })
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(handler.taskFailedEvents.size, 1)
    @Expect(handler.taskFailedEvents[0], "failing-task")
}

@Test
func testCoordinatedShutdown_eventHandler_completed() {
    let cs = createCoordinatedShutdown("node-1")
    let handler = TestShutdownHandler()
    cs.setEventHandler(handler)
    cs.addTask("task", ShutdownPhase.PhaseServiceStop, { => () })
    cs.run(ShutdownReason.NodeShutdown)
    @Expect(handler.completedResult.isSome(), true)
    @Expect(handler.completedResult.getOrThrow().success, true)
}

// === ShutdownResult Tests ===

@Test
func testShutdownResult_success() {
    let results = HashMap<ShutdownPhase, Bool>()
    results.add(ShutdownPhase.PhaseServiceStop, true)
    let result = ShutdownResult(ShutdownReason.NodeShutdown, results, 1, 0)
    @Expect(result.success, true)
    @Expect(result.totalTasks, 1)
    @Expect(result.failedTasks, 0)
}

@Test
func testShutdownResult_failure() {
    let results = HashMap<ShutdownPhase, Bool>()
    results.add(ShutdownPhase.PhaseServiceStop, false)
    let result = ShutdownResult(ShutdownReason.Crashed, results, 1, 1)
    @Expect(result.success, false)
    @Expect(result.reason, ShutdownReason.Crashed)
}

// === CoordinatedShutdownConfig Tests ===

@Test
func testCoordinatedShutdownConfig_creation() {
    let config = CoordinatedShutdownConfig(
        Duration.second * 60,
        Duration.second * 2,
        5,
        true,
        false
    )
    @Expect(config.defaultTimeout, Duration.second * 60)
    @Expect(config.maxRetries, 5)
    @Expect(config.abortOnFailure, true)
    @Expect(config.enableJvmShutdownHook, false)
}

@Test
func testCreateDefaultCoordinatedShutdownConfig() {
    let config = createDefaultCoordinatedShutdownConfig()
    @Expect(config.defaultTimeout, Duration.second * 30)
    @Expect(config.maxRetries, 3)
}

// === ShutdownHookManager Tests ===

@Test
func testShutdownHookManager_creation() {
    let manager = ShutdownHookManager()
    @Expect(manager.hookCount(), 0)
}

@Test
func testShutdownHookManager_register() {
    let manager = ShutdownHookManager()
    var executed = false
    manager.register({ => executed = true })
    @Expect(manager.hookCount(), 1)
}

@Test
func testShutdownHookManager_execute() {
    let manager = ShutdownHookManager()
    var executed1 = false
    var executed2 = false
    manager.register({ => executed1 = true })
    manager.register({ => executed2 = true })
    manager.execute()
    @Expect(executed1, true)
    @Expect(executed2, true)
    @Expect(manager.hookCount(), 0)
}

@Test
func testShutdownHookManager_executeWithError() {
    let manager = ShutdownHookManager()
    var executed = false
    manager.register({ => executed = true })
    manager.register({ => throw Exception("Hook error") })
    manager.execute()
    @Expect(executed, true)
}

@Test
func testShutdownHookManager_setRegistered() {
    let manager = ShutdownHookManager()
    @Expect(manager.isRegistered(), false)
    manager.setRegistered()
    @Expect(manager.isRegistered(), true)
}