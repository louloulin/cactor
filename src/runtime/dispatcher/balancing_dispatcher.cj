/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - BalancingDispatcher 负载均衡调度器
 * 对标 Akka BalancingDispatcher
 */
package cactor.runtime.dispatcher

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.ActorRef
import cactor.core.config.{DispatcherConfig, DispatcherType, ExecutorConfig}
import cactor.core.message.Envelope
import cactor.runtime.dispatcher.advanced.AdvancedMessageDispatcher
import cactor.runtime.dispatcher.advanced.Priority

/*
 * 负载均衡策略
 */
public enum BalanceStrategy {
    | RoundRobin        // 轮询
    | LeastLoaded       // 最少负载优先
    | Random            // 随机分配
}

/*
 * Worker 统计信息
 */
public class WorkerStats {
    private let actorRef: ActorRef
    private let pendingCount: AtomicInt64
    private let processedCount: AtomicInt64

    public init(actorRef: ActorRef) {
        this.actorRef = actorRef
        this.pendingCount = AtomicInt64(0)
        this.processedCount = AtomicInt64(0)
    }

    public func getActorRef(): ActorRef { actorRef }

    public func getPendingCount(): Int64 { pendingCount.load() }

    public func getProcessedCount(): Int64 { processedCount.load() }

    public func incrementPending(): Unit { pendingCount.fetchAdd(1) }

    public func decrementPending(): Unit {
        pendingCount.fetchSub(1)
        processedCount.fetchAdd(1)
    }
}

/*
 * BalancingDispatcher - 负载均衡调度器
 * 将消息均匀分配到多个 worker Actor
 */
public class BalancingDispatcher <: AdvancedMessageDispatcher {
    private let config: DispatcherConfig
    private let strategy: BalanceStrategy
    private let workers: ArrayList<WorkerStats>
    private let counter: AtomicInt64
    private var running: Bool

    public init(config: DispatcherConfig, strategy: BalanceStrategy) {
        this.config = config
        this.strategy = strategy
        this.workers = ArrayList<WorkerStats>()
        this.counter = AtomicInt64(0)
        this.running = false
    }

    public init(strategy: BalanceStrategy) {
        this.config = DispatcherConfig(
            DispatcherType.Custom,
            100,
            Duration.second * 0,
            ExecutorConfig.createDefault(),
            "balancing-dispatcher"
        )
        this.strategy = strategy
        this.workers = ArrayList<WorkerStats>()
        this.counter = AtomicInt64(0)
        this.running = false
    }

    /**
     * 添加 worker
     */
    public func addWorker(actorRef: ActorRef): Unit {
        workers.add(WorkerStats(actorRef))
    }

    /**
     * 移除 worker
     */
    public func removeWorker(actorRef: ActorRef): Bool {
        var i = 0
        while (i < workers.size) {
            if (workers[i].getActorRef().equals(actorRef)) {
                workers.remove(Int64(i)..Int64(i + 1))
                return true
            }
            i += 1
        }
        false
    }

    /**
     * 获取 worker 数量
     */
    public func workerCount(): Int64 { Int64(workers.size) }

    /**
     * 选择下一个 worker
     */
    public func selectWorker(): Option<ActorRef> {
        if (workers.size == 0) {
            return None
        }
        match (strategy) {
            case BalanceStrategy.RoundRobin => selectRoundRobin()
            case BalanceStrategy.LeastLoaded => selectLeastLoaded()
            case BalanceStrategy.Random => selectRandom()
        }
    }

    private func selectRoundRobin(): Option<ActorRef> {
        let idx = counter.fetchAdd(1) % Int64(workers.size)
        Some(workers[Int64(idx)].getActorRef())
    }

    private func selectLeastLoaded(): Option<ActorRef> {
        var minIdx = 0
        var minLoad = workers[0].getPendingCount()
        var i = 1
        while (i < workers.size) {
            let load = workers[i].getPendingCount()
            if (load < minLoad) {
                minLoad = load
                minIdx = i
            }
            i += 1
        }
        Some(workers[minIdx].getActorRef())
    }

    private func selectRandom(): Option<ActorRef> {
        let idx = counter.fetchAdd(1) % Int64(workers.size)
        Some(workers[Int64(idx)].getActorRef())
    }

    // === AdvancedMessageDispatcher 接口实现 ===

    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        match (selectWorker()) {
            case Some(worker) =>
                worker.tell(envelope.getMessage())
            case None =>
                actorRef.tell(envelope.getMessage())
        }
    }

    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        dispatch(envelope, actorRef)
    }

    public func dispatchBatch(envelopes: Array<Envelope>, actorRefs: Array<ActorRef>): Unit {
        for (envelope in envelopes) {
            match (selectWorker()) {
                case Some(worker) =>
                    worker.tell(envelope.getMessage())
                case None =>
                    if (actorRefs.size > 0) {
                        actorRefs[0].tell(envelope.getMessage())
                    }
            }
        }
    }

    public func start(): Unit { running = true }

    public func stop(): Unit { running = false }

    public func getConfig(): DispatcherConfig { config }

    public func getPerformanceStats(): String {
        let totalPending = getPendingCount()
        let totalProcessed = getProcessedCount()
        "BalancingDispatcher(workers=${workers.size}, strategy=${strategyName()}, pending=${totalPending}, processed=${totalProcessed})"
    }

    public func isRunning(): Bool { running }

    /**
     * 获取策略名称
     */
    public func strategyName(): String {
        match (strategy) {
            case BalanceStrategy.RoundRobin => "RoundRobin"
            case BalanceStrategy.LeastLoaded => "LeastLoaded"
            case BalanceStrategy.Random => "Random"
        }
    }

    /**
     * 获取所有 worker 统计信息
     */
    public func getWorkerStats(): Array<WorkerStats> { workers.toArray() }

    /**
     * 获取总待处理数
     */
    public func getPendingCount(): Int64 {
        var total: Int64 = 0
        for (w in workers) {
            total += w.getPendingCount()
        }
        total
    }

    /**
     * 获取总处理数
     */
    public func getProcessedCount(): Int64 {
        var total: Int64 = 0
        for (w in workers) {
            total += w.getProcessedCount()
        }
        total
    }
}
