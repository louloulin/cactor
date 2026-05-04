/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Coordinated Shutdown 协调关闭机制
 * 对标 Akka CoordinatedShutdown
 * 实现集群协调式优雅关闭
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 关闭阶段
 */
public enum ShutdownPhase <: ToString {
    | PhaseBeforeClusterQuarantined
    | PhaseClusterExiting
    | PhaseClusterSharding
    | PhaseClusterSingleton
    | PhaseServiceStop
    | PhaseApplicationServices
    | PhaseExternalServices
    | PhaseDone

    public func toString(): String {
        match (this) {
            case PhaseBeforeClusterQuarantined => "PhaseBeforeClusterQuarantined"
            case PhaseClusterExiting => "PhaseClusterExiting"
            case PhaseClusterSharding => "PhaseClusterSharding"
            case PhaseClusterSingleton => "PhaseClusterSingleton"
            case PhaseServiceStop => "PhaseServiceStop"
            case PhaseApplicationServices => "PhaseApplicationServices"
            case PhaseExternalServices => "PhaseExternalServices"
            case PhaseDone => "PhaseDone"
        }
    }
}

/**
 * 关闭原因
 */
public enum ShutdownReason <: ToString {
    | NodeShutdown
    | ClusterShutdown
    | AbortedStartup
    | Crashed
    | ExitProcess
    | IncompatibleConfiguration
    | Unknown

    public func toString(): String {
        match (this) {
            case NodeShutdown => "NodeShutdown"
            case ClusterShutdown => "ClusterShutdown"
            case AbortedStartup => "AbortedStartup"
            case Crashed => "Crashed"
            case ExitProcess => "ExitProcess"
            case IncompatibleConfiguration => "IncompatibleConfiguration"
            case Unknown => "Unknown"
        }
    }
}

/**
 * 关闭任务
 */
public class ShutdownTask {
    public let name: String
    public let phase: ShutdownPhase
    public let task: () -> Unit
    public let timeout: Duration
    public var executed: Bool
    public var failed: Bool

    public init(name: String, phase: ShutdownPhase, task: () -> Unit, timeout: Duration) {
        this.name = name
        this.phase = phase
        this.task = task
        this.timeout = timeout
        this.executed = false
        this.failed = false
    }
}

/**
 * 关闭结果
 */
public class ShutdownResult {
    public let reason: ShutdownReason
    public let phaseResults: HashMap<String, Bool>
    public let totalTasks: Int64
    public let failedTasks: Int64
    public let success: Bool

    public init(reason: ShutdownReason, phaseResults: HashMap<String, Bool>, totalTasks: Int64, failedTasks: Int64) {
        this.reason = reason
        this.phaseResults = phaseResults
        this.totalTasks = totalTasks
        this.failedTasks = failedTasks
        this.success = failedTasks == 0
    }
}

/**
 * 协调关闭事件处理器
 */
public interface CoordinatedShutdownEventHandler {
    /**
     * 关闭开始
     */
    func onShutdownStarted(reason: ShutdownReason, phase: ShutdownPhase): Unit

    /**
     * 阶段开始
     */
    func onPhaseStarted(phase: ShutdownPhase, taskCount: Int64): Unit

    /**
     * 阶段完成
     */
    func onPhaseCompleted(phase: ShutdownPhase, success: Bool): Unit

    /**
     * 任务完成
     */
    func onTaskCompleted(taskName: String, phase: ShutdownPhase): Unit

    /**
     * 任务失败
     */
    func onTaskFailed(taskName: String, phase: ShutdownPhase, reason: String): Unit

    /**
     * 关闭完成
     */
    func onShutdownCompleted(result: ShutdownResult): Unit
}

/**
 * 协调关闭配置
 */
public class CoordinatedShutdownConfig {
    public let defaultTimeout: Duration
    public let retryInterval: Duration
    public let maxRetries: Int64
    public let abortOnFailure: Bool
    public let enableJvmShutdownHook: Bool

    public init(
        defaultTimeout: Duration,
        retryInterval: Duration,
        maxRetries: Int64,
        abortOnFailure: Bool,
        enableJvmShutdownHook: Bool
    ) {
        this.defaultTimeout = defaultTimeout
        this.retryInterval = retryInterval
        this.maxRetries = maxRetries
        this.abortOnFailure = abortOnFailure
        this.enableJvmShutdownHook = enableJvmShutdownHook
    }
}

/**
 * CoordinatedShutdown - 协调式关闭
 * 对标 Akka CoordinatedShutdown
 * 实现集群节点的有序协调关闭
 */
public class CoordinatedShutdown {
    private let nodeId: String
    private let config: CoordinatedShutdownConfig
    private let phases: HashMap<String, ArrayList<ShutdownTask>>
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<CoordinatedShutdownEventHandler>
    private var isRunning: Bool
    private var currentPhase: Option<ShutdownPhase>
    private var shutdownReason: Option<ShutdownReason>

    public init(nodeId: String, config: CoordinatedShutdownConfig) {
        this.nodeId = nodeId
        this.config = config
        this.phases = HashMap<String, ArrayList<ShutdownTask>>()
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
        this.isRunning = false
        this.currentPhase = None
        this.shutdownReason = None

        // 初始化所有阶段
        initPhases()
    }

    /**
     * 初始化所有阶段
     */
    private func initPhases(): Unit {
        let phaseList = [
            ShutdownPhase.PhaseBeforeClusterQuarantined,
            ShutdownPhase.PhaseClusterExiting,
            ShutdownPhase.PhaseClusterSharding,
            ShutdownPhase.PhaseClusterSingleton,
            ShutdownPhase.PhaseServiceStop,
            ShutdownPhase.PhaseApplicationServices,
            ShutdownPhase.PhaseExternalServices,
            ShutdownPhase.PhaseDone
        ]
        for (phase in phaseList) {
            phases.add(phase.toString(), ArrayList<ShutdownTask>())
        }
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: CoordinatedShutdownEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 添加关闭任务
     */
    public func addTask(name: String, phase: ShutdownPhase, task: () -> Unit): Unit {
        addTaskWithTimeout(name, phase, task, config.defaultTimeout)
    }

    /**
     * 添加带超时的关闭任务
     */
    public func addTaskWithTimeout(name: String, phase: ShutdownPhase, task: () -> Unit, timeout: Duration): Unit {
        lock.writeMutex.lock()
        match (phases.get(phase.toString())) {
            case Some(tasks) =>
                let shutdownTask = ShutdownTask(name, phase, task, timeout)
                tasks.add(shutdownTask)
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 添加集群相关任务
     */
    public func addClusterTask(name: String, phase: ShutdownPhase, task: () -> Unit): Unit {
        let clusterTask = { =>
            println("  [Cluster] ${name}: starting")
            task()
            println("  [Cluster] ${name}: completed")
        }
        addTask(name, phase, clusterTask)
    }

    /**
     * 添加应用服务停止任务
     */
    public func addServiceStopTask(name: String, task: () -> Unit): Unit {
        addTask(name, ShutdownPhase.PhaseServiceStop, task)
    }

    /**
     * 添加外部服务停止任务
     */
    public func addExternalServiceTask(name: String, task: () -> Unit): Unit {
        addTask(name, ShutdownPhase.PhaseExternalServices, task)
    }

    /**
     * 执行协调关闭
     */
    public func run(reason: ShutdownReason): ShutdownResult {
        lock.writeMutex.lock()
        if (isRunning) {
            lock.writeMutex.unlock()
            return ShutdownResult(reason, HashMap<String, Bool>(), 0, 0)
        }
        isRunning = true
        shutdownReason = Some(reason)
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) =>
                let startPhase = getStartPhase(reason)
                handler.onShutdownStarted(reason, startPhase)
            case None => ()
        }

        let phaseResults = HashMap<String, Bool>()
        var totalTasks: Int64 = 0
        var failedTasks: Int64 = 0

        // 确定要执行的阶段顺序
        let phasesToRun = getPhasesToRun(reason)

        for (phase in phasesToRun) {
            lock.readMutex.lock()
            let tasks = match (phases.get(phase.toString())) {
                case Some(t) => t
                case None => ArrayList<ShutdownTask>()
            }
            lock.readMutex.unlock()

            match (eventHandler) {
                case Some(handler) => handler.onPhaseStarted(phase, tasks.size)
                case None => ()
            }

            var phaseSuccess = true
            for (task in tasks) {
                totalTasks += 1
                let success = executeTask(task)
                if (!success) {
                    phaseSuccess = false
                    failedTasks += 1
                    if (config.abortOnFailure) {
                        break
                    }
                }
            }

            phaseResults.add(phase.toString(), phaseSuccess)

            match (eventHandler) {
                case Some(handler) => handler.onPhaseCompleted(phase, phaseSuccess)
                case None => ()
            }

            if (!phaseSuccess && config.abortOnFailure) {
                break
            }
        }

        // 添加 Done 阶段
        phaseResults.add(ShutdownPhase.PhaseDone.toString(), failedTasks == 0)

        match (eventHandler) {
            case Some(handler) =>
                let result = ShutdownResult(reason, phaseResults, totalTasks, failedTasks)
                handler.onShutdownCompleted(result)
            case None => ()
        }

        lock.writeMutex.lock()
        currentPhase = Some(ShutdownPhase.PhaseDone)
        lock.writeMutex.unlock()

        ShutdownResult(reason, phaseResults, totalTasks, failedTasks)
    }

    /**
     * 执行单个任务
     */
    private func executeTask(task: ShutdownTask): Bool {
        lock.writeMutex.lock()
        task.executed = true
        lock.writeMutex.unlock()

        try {
            task.task()
            match (eventHandler) {
                case Some(handler) => handler.onTaskCompleted(task.name, task.phase)
                case None => ()
            }
            return true
        } catch (e: Exception) {
            lock.writeMutex.lock()
            task.failed = true
            lock.writeMutex.unlock()

            match (eventHandler) {
                case Some(handler) => handler.onTaskFailed(task.name, task.phase, e.toString())
                case None => ()
            }
            return false
        }
    }

    /**
     * 获取起始阶段
     */
    private func getStartPhase(reason: ShutdownReason): ShutdownPhase {
        match (reason) {
            case ShutdownReason.NodeShutdown => ShutdownPhase.PhaseServiceStop
            case ShutdownReason.ClusterShutdown => ShutdownPhase.PhaseClusterExiting
            case ShutdownReason.AbortedStartup => ShutdownPhase.PhaseBeforeClusterQuarantined
            case ShutdownReason.Crashed => ShutdownPhase.PhaseBeforeClusterQuarantined
            case ShutdownReason.ExitProcess => ShutdownPhase.PhaseBeforeClusterQuarantined
            case ShutdownReason.IncompatibleConfiguration => ShutdownPhase.PhaseBeforeClusterQuarantined
            case ShutdownReason.Unknown => ShutdownPhase.PhaseServiceStop
        }
    }

    /**
     * 获取要执行的阶段顺序
     */
    private func getPhasesToRun(reason: ShutdownReason): ArrayList<ShutdownPhase> {
        let phasesToRun = ArrayList<ShutdownPhase>()

        // 根据原因确定起始阶段
        let startPhase = getStartPhase(reason)
        let allPhases = [
            ShutdownPhase.PhaseBeforeClusterQuarantined,
            ShutdownPhase.PhaseClusterExiting,
            ShutdownPhase.PhaseClusterSharding,
            ShutdownPhase.PhaseClusterSingleton,
            ShutdownPhase.PhaseServiceStop,
            ShutdownPhase.PhaseApplicationServices,
            ShutdownPhase.PhaseExternalServices
        ]

        var started = false
        for (phase in allPhases) {
            if (!started) {
                let phaseStr = phase.toString()
                let startStr = startPhase.toString()
                if (phaseStr != startStr) {
                    continue
                }
            }
            started = true
            phasesToRun.add(phase)
        }

        phasesToRun
    }

    /**
     * 获取任务数量
     */
    public func taskCount(): Int64 {
        lock.readMutex.lock()
        var count: Int64 = 0
        for ((_, tasks) in phases) {
            count += tasks.size
        }
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取特定阶段的任务数量
     */
    public func taskCountForPhase(phase: ShutdownPhase): Int64 {
        lock.readMutex.lock()
        let count = match (phases.get(phase.toString())) {
            case Some(tasks) => tasks.size
            case None => 0
        }
        lock.readMutex.unlock()
        count
    }

    /**
     * 检查是否正在运行
     */
    public func isShuttingDown(): Bool {
        lock.readMutex.lock()
        let running = isRunning
        lock.readMutex.unlock()
        running
    }

    /**
     * 获取当前阶段
     */
    public func getCurrentPhase(): Option<ShutdownPhase> {
        lock.readMutex.lock()
        let phase = currentPhase
        lock.readMutex.unlock()
        phase
    }

    /**
     * 获取节点 ID
     */
    public func getNodeId(): String {
        nodeId
    }

    /**
     * 获取所有任务
     */
    public func getAllTasks(): ArrayList<(String, String)> {
        lock.readMutex.lock()
        let result = ArrayList<(String, String)>()
        for ((phase, tasks) in phases) {
            for (task in tasks) {
                result.add((task.name, phase))
            }
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取阶段顺序
     */
    public func getPhaseOrder(): ArrayList<ShutdownPhase> {
        let order = ArrayList<ShutdownPhase>()
        order.add(ShutdownPhase.PhaseBeforeClusterQuarantined)
        order.add(ShutdownPhase.PhaseClusterExiting)
        order.add(ShutdownPhase.PhaseClusterSharding)
        order.add(ShutdownPhase.PhaseClusterSingleton)
        order.add(ShutdownPhase.PhaseServiceStop)
        order.add(ShutdownPhase.PhaseApplicationServices)
        order.add(ShutdownPhase.PhaseExternalServices)
        order.add(ShutdownPhase.PhaseDone)
        order
    }

    /**
     * 清除所有任务
     */
    public func clearAllTasks(): Unit {
        lock.writeMutex.lock()
        for ((_, tasks) in phases) {
            tasks.clear()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 移除特定阶段的任务
     */
    public func clearPhaseTasks(phase: ShutdownPhase): Int64 {
        lock.writeMutex.lock()
        let count = match (phases.get(phase.toString())) {
            case Some(tasks) => tasks.size
            case None => 0
        }
        phases.remove(phase.toString())
        phases.add(phase.toString(), ArrayList<ShutdownTask>())
        lock.writeMutex.unlock()
        count
    }
}

/**
 * 创建协调关闭实例
 */
public func createCoordinatedShutdown(nodeId: String): CoordinatedShutdown {
    let config = CoordinatedShutdownConfig(
        Duration.second * 30,    // defaultTimeout
        Duration.second * 1,      // retryInterval
        3,                         // maxRetries
        true,                      // abortOnFailure
        true                       // enableJvmShutdownHook
    )
    CoordinatedShutdown(nodeId, config)
}

/**
 * 创建带配置的协调关闭实例
 */
public func createCoordinatedShutdownWithConfig(nodeId: String, config: CoordinatedShutdownConfig): CoordinatedShutdown {
    CoordinatedShutdown(nodeId, config)
}

/**
 * 创建默认配置
 */
public func createDefaultCoordinatedShutdownConfig(): CoordinatedShutdownConfig {
    CoordinatedShutdownConfig(
        Duration.second * 30,
        Duration.second * 1,
        3,
        true,
        true
    )
}

/**
 * 优雅关闭钩子管理器
 */
public class ShutdownHookManager {
    private let hooks: ArrayList<() -> Unit>
    private let lock: ReentrantMutex
    private var registered: Bool

    public init() {
        this.hooks = ArrayList<() -> Unit>()
        this.lock = ReentrantMutex()
        this.registered = false
    }

    /**
     * 注册关闭钩子
     */
    public func register(hook: () -> Unit): Unit {
        lock.lock()
        hooks.add(hook)
        lock.unlock()
    }

    /**
     * 执行所有钩子
     */
    public func execute(): Unit {
        lock.lock()
        for (hook in hooks) {
            try {
                hook()
            } catch (e: Exception) {
                println("Shutdown hook failed: ${e}")
            }
        }
        hooks.clear()
        lock.unlock()
    }

    /**
     * 获取钩子数量
     */
    public func hookCount(): Int64 {
        lock.lock()
        let count = hooks.size
        lock.unlock()
        count
    }

    /**
     * 检查是否已注册
     */
    public func isRegistered(): Bool {
        lock.lock()
        let result = registered
        lock.unlock()
        result
    }

    /**
     * 设置为已注册
     */
    public func setRegistered(): Unit {
        lock.lock()
        registered = true
        lock.unlock()
    }
}