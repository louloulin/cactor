/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - PersistenceFSM 状态机持久化
 * 对标 Akka PersistenceFSM
 * 结合事件溯源和有限状态机的持久化状态机 Actor
 */
package cactor.distribution.persistence

import std.collection.*
import std.sync.*
import std.time.*
import std.convert.*

/**
 * FSM 状态标识
 */
public interface FSMState {
    func stateName(): String
}

/**
 * FSM 事件
 */
public interface FSMEvent {
    func eventName(): String
}

/**
 * FSM 状态数据
 */
public interface FSMStateData {
    func isDefined(): Bool
}

/**
 * 状态转换事件
 */
public class StateTransitionEvent <: PersistentEvent & FSMEvent {
    private let fromState: String
    private let toState: String
    private let seqNr: Int64
    private let ts: Int64

    public init(fromState: String, toState: String, seqNr: Int64) {
        this.fromState = fromState
        this.toState = toState
        this.seqNr = seqNr
        this.ts = DateTime.now().toUnixTimeStamp().toSeconds()
    }

    public func eventType(): String { "StateTransition" }
    public func eventName(): String { "StateTransition" }
    public func eventData(): Any { this }
    public func sequenceNr(): Int64 { seqNr }
    public func timestamp(): Int64 { ts }

    public func from(): String { fromState }
    public func to(): String { toState }
}

/**
 * 超时设置
 */
public class Timeout {
    public let target: String
    public let duration: Duration

    public init(target: String, duration: Duration) {
        this.target = target
        this.duration = duration
    }

    public static func idle(duration: Duration): Timeout {
        Timeout("IdleTimeout", duration)
    }
}

/**
 * 状态机状态类型
 */
public enum FSMStateType {
    | Initial
    | Active
    | Waiting
    | Terminated
}

/**
 * 状态转换器接口
 */
public interface StateTransitionHandler {
    /**
     * 状态进入回调
     */
    func onTransition(stateName: String): Unit

    /**
     * 状态退出回调
     */
    func onExit(stateName: String): Unit
}

/**
 * PersistenceFSM Actor 核心实现
 * 对标 Akka PersistenceFSM
 */
public class PersistenceFSMActor {
    // 状态管理
    private var currentStateName: String
    private var stateDataMap: HashMap<String, Any>
    // 持久化相关
    private let persistenceId: String
    private var lastSequenceNr: Int64
    private let journal: PersistenceJournal
    private let snapshotStore: PersistenceSnapshotStore
    // 超时管理
    private var stateTimeout: Option<Duration>
    private var timeoutTask: Option<Int64>
    private let lock: ReentrantReadWriteMutex
    // 状态机配置
    private let transitionHandler: Option<StateTransitionHandler>

    public init(
        persistenceId: String,
        initialStateName: String,
        initialData: Any,
        journal: PersistenceJournal,
        snapshotStore: PersistenceSnapshotStore
    ) {
        this.persistenceId = persistenceId
        this.currentStateName = initialStateName
        this.stateDataMap = HashMap<String, Any>()
        this.stateDataMap.add(initialStateName, initialData)
        this.journal = journal
        this.snapshotStore = snapshotStore
        this.lastSequenceNr = 0
        this.stateTimeout = None
        this.timeoutTask = None
        this.lock = ReentrantReadWriteMutex()
        this.transitionHandler = None
    }

    /**
     * 获取当前状态名
     */
    public func getStateName(): String {
        currentStateName
    }

    /**
     * 获取状态数据
     */
    public func getStateData(): Option<Any> {
        stateDataMap.get(currentStateName)
    }

    /**
     * 处理事件
     */
    public func handleEvent(event: FSMEvent): Unit {
        match (event) {
            case timeout: Timeout =>
                this.handleTimeout(timeout)
            case _ =>
                this.processEvent(event)
        }
    }

    /**
     * 处理超时
     */
    private func handleTimeout(timeout: Timeout): Unit {
        if (currentStateName == timeout.target) {
            this.processTimeout()
        }
    }

    /**
     * 处理超时事件
     */
    private func processTimeout(): Unit {
        // 超时处理逻辑
    }

    /**
     * 处理事件
     */
    private func processEvent(event: FSMEvent): Unit {
        // 事件处理逻辑
        lastSequenceNr += 1
    }

    /**
     * 状态转换
     */
    public func transitionTo(newStateName: String, newData: Any): Unit {
        let oldState = currentStateName
        try {
            lock.writeMutex.lock()

            // 触发退出回调
            match (transitionHandler) {
                case Some(handler) =>
                    handler.onExit(oldState)
                case None => ()
            }

            // 更新状态
            currentStateName = newStateName
            stateDataMap.add(newStateName, newData)
            lastSequenceNr += 1

            // 触发进入回调
            match (transitionHandler) {
                case Some(handler) =>
                    handler.onTransition(newStateName)
                case None => ()
            }

            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 设置状态超时
     */
    public func setStateTimeout(duration: Duration): Unit {
        try {
            lock.writeMutex.lock()
            stateTimeout = Some(duration)
            timeoutTask = Some(DateTime.now().toUnixTimeStamp().toMilliseconds() + duration.toMilliseconds())
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 取消超时
     */
    public func cancelTimeout(): Unit {
        try {
            lock.writeMutex.lock()
            stateTimeout = None
            timeoutTask = None
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 持久化事件
     */
    public func persist(event: PersistentEvent): Unit {
        lastSequenceNr += 1
        let persistentEvent = event
        // 写入 journal
    }

    /**
     * 保存快照
     */
    public func saveSnapshot(): Unit {
        let metadata = SnapshotMetadata(persistenceId, lastSequenceNr)
        let snapshot = currentStateName
        snapshotStore.save(metadata, snapshot)
    }

    /**
     * 获取 persistenceId
     */
    public func getPersistenceId(): String {
        persistenceId
    }

    /**
     * 获取最后序列号
     */
    public func getLastSequenceNr(): Int64 {
        lastSequenceNr
    }
}

/**
 * 内存持久化 Journal 实现
 */
public class InMemoryPersistenceJournal <: PersistenceJournal {
    private var events: HashMap<String, ArrayList<PersistentEvent>>
    private let lock: Mutex

    public init() {
        this.events = HashMap<String, ArrayList<PersistentEvent>>()
        this.lock = Mutex()
    }

    public func append(persistenceId: String, event: PersistentEvent): Unit {
        try {
            lock.lock()
            match (events.get(persistenceId)) {
                case Some(list) =>
                    list.add(event)
                case None =>
                    let list = ArrayList<PersistentEvent>()
                    list.add(event)
                    events.add(persistenceId, list)
            }
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }

    public func loadEvents(persistenceId: String, fromSeq: Int64, toSeq: Int64): ArrayList<PersistentEvent> {
        let result = ArrayList<PersistentEvent>()
        try {
            lock.lock()
            match (events.get(persistenceId)) {
                case Some(list) =>
                    for (event in list) {
                        let seq = event.sequenceNr()
                        if (seq >= fromSeq && seq <= toSeq) {
                            result.add(event)
                        }
                    }
                case None => ()
            }
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
        result
    }

    public func deleteEvents(persistenceId: String, toSeq: Int64): Unit {
        try {
            lock.lock()
            match (events.get(persistenceId)) {
                case Some(list) =>
                    let filtered = ArrayList<PersistentEvent>()
                    for (event in list) {
                        if (event.sequenceNr() > toSeq) {
                            filtered.add(event)
                        }
                    }
                    events.remove(persistenceId)
                    events.add(persistenceId, filtered)
                case None => ()
            }
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }

    public func persistConfirm(persistenceId: String, sequenceNr: Int64): Unit {
        // 简化实现
    }
}

/**
 * 简化版内存快照存储 (用于测试)
 */
public class SimpleSnapshotStore <: PersistenceSnapshotStore {
    private var snapshots: HashMap<String, Any>
    private let lock: Mutex

    public init() {
        this.snapshots = HashMap<String, Any>()
        this.lock = Mutex()
    }

    public func save(metadata: SnapshotMetadata, snapshot: Any): Unit {
        try {
            lock.lock()
            snapshots.add(metadata.toString(), snapshot)
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }

    public func loadLatest(persistenceId: String): Option<Any> {
        try {
            lock.lock()
            let result = snapshots.get(persistenceId)
            lock.unlock()
            result
        } catch (e: Exception) {
            lock.unlock()
            None
        }
    }

    public func load(persistenceId: String, sequenceNr: Int64): Option<Any> {
        let key = "${persistenceId}_${sequenceNr}"
        try {
            lock.lock()
            let result = snapshots.get(key)
            lock.unlock()
            result
        } catch (e: Exception) {
            lock.unlock()
            None
        }
    }

    public func delete(persistenceId: String, sequenceNr: Int64): Unit {
        let key = "${persistenceId}_${sequenceNr}"
        try {
            lock.lock()
            snapshots.remove(key)
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }

    public func deleteBefore(persistenceId: String, sequenceNr: Int64): Unit {
        try {
            lock.lock()
            let keysToRemove = ArrayList<String>()
            for ((key, _) in snapshots) {
                if (key.startsWith(persistenceId)) {
                    let parts = key.split("_")
                    if (parts.size >= 2) {
                        let seq = Int64.parse(parts[1])
                        if (seq < sequenceNr) {
                            keysToRemove.add(key)
                        }
                    }
                }
            }
            for (key in keysToRemove) {
                snapshots.remove(key)
            }
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }
}

/**
 * PersistenceFSM Actor 基类
 */
public class PersistentFSMActorBase {
    private let eventHandlers: HashMap<String, (FSMEvent) -> Option<String>>
    private let persistenceId: String
    private var currentStateName: String
    private var stateDataMap: HashMap<String, Any>
    private let journal: PersistenceJournal
    private let snapshotStore: PersistenceSnapshotStore

    public init(
        persistenceId: String,
        initialStateName: String,
        initialData: Any,
        journal: PersistenceJournal,
        snapshotStore: PersistenceSnapshotStore
    ) {
        this.eventHandlers = HashMap<String, (FSMEvent) -> Option<String>>()
        this.persistenceId = persistenceId
        this.currentStateName = initialStateName
        this.stateDataMap = HashMap<String, Any>()
        this.stateDataMap.add(initialStateName, initialData)
        this.journal = journal
        this.snapshotStore = snapshotStore
    }

    /**
     * 注册事件处理器
     */
    public func registerEventHandler(stateName: String, handler: (FSMEvent) -> Option<String>): Unit {
        eventHandlers.add(stateName, handler)
    }

    /**
     * 定义状态转移
     */
    public func when(stateName: String, handler: (FSMEvent) -> Option<String>): Unit {
        eventHandlers.add(stateName, handler)
    }

    /**
     * 定义默认处理器
     */
    public func whenUnhandled(handler: (FSMEvent) -> Unit): Unit {
        // 未处理事件时的默认处理
    }

    /**
     * 转到新状态
     */
    public func goto(state: String, data: Any): Unit {
        // 更新状态
        currentStateName = state
        if (stateDataMap.contains(state)) {
            stateDataMap.remove(state)
        }
        stateDataMap.add(state, data)
    }
}