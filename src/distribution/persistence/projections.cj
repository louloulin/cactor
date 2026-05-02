/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Akka Projections 实现
 * 对标 Akka Projections
 */
package cactor.distribution.persistence

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 投影偏移量接口
 */
public interface ProjectionOffset {
    func toOffsetString(): String
    func compareTo(other: ProjectionOffset): Int64
}

/**
 * 长整型偏移量
 */
public class LongOffset <: ProjectionOffset {
    private let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func getValue(): Int64 {
        value
    }

    public func toOffsetString(): String {
        value.toString()
    }

    public func compareTo(other: ProjectionOffset): Int64 {
        match (other) {
            case lo: LongOffset => value - lo.value
            case _ => 0
        }
    }
}

/**
 * 字符串偏移量
 */
public class StringOffset <: ProjectionOffset {
    private let value: String

    public init(value: String) {
        this.value = value
    }

    public func getValue(): String {
        value
    }

    public func toOffsetString(): String {
        value
    }

    public func compareTo(other: ProjectionOffset): Int64 {
        match (other) {
            case so: StringOffset =>
                if (value < so.value) { -1 }
                else if (value > so.value) { 1 }
                else { 0 }
            case _ => 0
        }
    }
}

/**
 * 偏移存储接口
 */
public interface OffsetStore {
    func saveOffset(projectionId: String, offset: ProjectionOffset): Unit
    func readOffset(projectionId: String): Option<ProjectionOffset>
    func deleteOffset(projectionId: String): Unit
    func getProjectionIds(): Array<String>
}

/**
 * 内存偏移量存储
 */
public class InMemoryOffsetStore <: OffsetStore {
    private let offsets: HashMap<String, ProjectionOffset>
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.offsets = HashMap<String, ProjectionOffset>()
        this.lock = ReentrantReadWriteMutex()
    }

    public func saveOffset(projectionId: String, offset: ProjectionOffset): Unit {
        try {
            lock.writeMutex.lock()
            offsets.add(projectionId, offset)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    public func readOffset(projectionId: String): Option<ProjectionOffset> {
        try {
            lock.readMutex.lock()
            let result = offsets.get(projectionId)
            lock.readMutex.unlock()
            result
        } catch (e: Exception) {
            lock.readMutex.unlock()
            None
        }
    }

    public func deleteOffset(projectionId: String): Unit {
        try {
            lock.writeMutex.lock()
            let _ = offsets.remove(projectionId)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    public func getProjectionIds(): Array<String> {
        try {
            lock.readMutex.lock()
            let ids = offsets.keys()
            let result = ArrayList<String>()
            for (id in ids) {
                result.add(id)
            }
            lock.readMutex.unlock()
            result.toArray()
        } catch (e: Exception) {
            lock.readMutex.unlock()
            Array<String>(0, { i => "" })
        }
    }

    public func clear(): Unit {
        try {
            lock.writeMutex.lock()
            offsets.clear()
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }
}

/**
 * 事件迭代器
 */
public interface EventIterator {
    func hasNext(): Bool
    func next(): Option<Envelope>
}

/**
 * 事件信封
 */
public class Envelope {
    public let event: Any
    public let offset: ProjectionOffset
    public let timestamp: Int64

    public init(event: Any, offset: ProjectionOffset) {
        this.event = event
        this.offset = offset
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public init(event: Any, offset: ProjectionOffset, timestamp: Int64) {
        this.event = event
        this.offset = offset
        this.timestamp = timestamp
    }
}

/**
 * 简单事件迭代器
 */
public class SimpleEventIterator <: EventIterator {
    private let events: ArrayList<Envelope>
    private var index: Int64 = 0

    public init(events: ArrayList<Envelope>) {
        this.events = events
    }

    public func hasNext(): Bool {
        index < events.size
    }

    public func next(): Option<Envelope> {
        if (index < events.size) {
            let env = events[index]
            index += 1
            Some(env)
        } else {
            None
        }
    }
}

/**
 * 源提供者接口
 */
public interface SourceProvider {
    func initialOffset(): Option<ProjectionOffset>
    func source(): EventIterator
}

/**
 * 简单事件源提供者
 */
public class SimpleSourceProvider <: SourceProvider {
    private let events: ArrayList<Envelope>

    public init(events: ArrayList<Envelope>) {
        this.events = events
    }

    public func initialOffset(): Option<ProjectionOffset> {
        None
    }

    public func source(): EventIterator {
        SimpleEventIterator(events)
    }
}

/**
 * 投影配置
 */
public struct ProjectionConfig {
    public let name: String
    public let offsetStrategy: OffsetStrategy
    public let restartBackoff: Duration
    public let emitTrackProgress: Bool

    public init(
        name!: String = "",
        offsetStrategy!: OffsetStrategy = OffsetStrategy.Store,
        restartBackoff!: Duration = Duration.second * 3,
        emitTrackProgress!: Bool = true
    ) {
        this.name = name
        this.offsetStrategy = offsetStrategy
        this.restartBackoff = restartBackoff
        this.emitTrackProgress = emitTrackProgress
    }
}

/**
 * 偏移策略
 */
public enum OffsetStrategy {
    | Store
    | NoStore
    | Any
}

/**
 * 投影状态
 */
public enum ProjectionState {
    | Stopped
    | Starting
    | Running
    | Failed(String)
    | Paused

    public func isRunning(): Bool {
        match (this) {
            case Running => true
            case _ => false
        }
    }

    public func isStopped(): Bool {
        match (this) {
            case Stopped => true
            case _ => false
        }
    }
}

/**
 * 投影处理器
 */
public type ProjectionHandler = (Envelope) -> Unit

/**
 * 投影接口
 */
public interface Projection {
    func projectionId(): String
    func config(): ProjectionConfig
    func state(): ProjectionState
    func start(): Unit
    func stop(): Unit
    func pause(): Unit
    func resume(): Unit
}

/**
 * 简单投影实现
 */
public class SimpleProjection <: Projection {
    private let projId: String
    private let projConfig: ProjectionConfig
    private let projHandler: ProjectionHandler
    private let projSource: SourceProvider
    private let projOffsetStore: OffsetStore
    private var projState: ProjectionState
    private let projLock: ReentrantReadWriteMutex

    public init(
        projectionId: String,
        config: ProjectionConfig,
        handler: ProjectionHandler,
        sourceProvider: SourceProvider,
        offsetStore: OffsetStore
    ) {
        this.projId = projectionId
        this.projConfig = config
        this.projHandler = handler
        this.projSource = sourceProvider
        this.projOffsetStore = offsetStore
        this.projState = ProjectionState.Stopped
        this.projLock = ReentrantReadWriteMutex()
    }

    public func projectionId(): String {
        projId
    }

    public func config(): ProjectionConfig {
        projConfig
    }

    public func state(): ProjectionState {
        projState
    }

    public func start(): Unit {
        setState(ProjectionState.Starting)
        let startOffset = projOffsetStore.readOffset(projId)
        let source = projSource.source()
        runProjection(source, startOffset)
        setState(ProjectionState.Running)
    }

    public func stop(): Unit {
        setState(ProjectionState.Stopped)
    }

    public func pause(): Unit {
        match (projState) {
            case Running => setState(ProjectionState.Paused)
            case _ => ()
        }
    }

    public func resume(): Unit {
        match (projState) {
            case Paused => setState(ProjectionState.Running)
            case _ => ()
        }
    }

    private func setState(newState: ProjectionState): Unit {
        try {
            projLock.writeMutex.lock()
            projState = newState
            projLock.writeMutex.unlock()
        } catch (e: Exception) {
            projLock.writeMutex.unlock()
        }
    }

    private func runProjection(source: EventIterator, startOffset: Option<ProjectionOffset>): Unit {
        var skipOffset: Option<ProjectionOffset> = startOffset

        while (source.hasNext()) {
            let optEnv = source.next()
            processEnvelope(optEnv, skipOffset)
        }
    }

    private func processEnvelope(optEnv: Option<Envelope>, skip: Option<ProjectionOffset>): Unit {
        match (optEnv) {
            case Some(env) => handleEvent(env, skip)
            case None => ()
        }
    }

    private func handleEvent(env: Envelope, skip: Option<ProjectionOffset>): Unit {
        let shouldSkipEnv = checkSkipCondition(env, skip)
        if (!shouldSkipEnv) {
            projHandler(env)
            saveOffsetIfNeeded(env.offset)
        }
    }

    private func checkSkipCondition(env: Envelope, skip: Option<ProjectionOffset>): Bool {
        match (skip) {
            case Some(target) => env.offset.compareTo(target) <= 0
            case None => false
        }
    }

    private func saveOffsetIfNeeded(offset: ProjectionOffset): Unit {
        match (projConfig.offsetStrategy) {
            case OffsetStrategy.Store => projOffsetStore.saveOffset(projId, offset)
            case _ => ()
        }
    }
}

/**
 * 投影统计信息
 */
public class ProjectionStats {
    public let projectionId: String
    public let state: ProjectionState
    public let currentOffset: Option<ProjectionOffset>

    public init(
        projectionId: String,
        state: ProjectionState,
        currentOffset: Option<ProjectionOffset>
    ) {
        this.projectionId = projectionId
        this.state = state
        this.currentOffset = currentOffset
    }
}

/**
 * 投影注册表
 */
public class ProjectionRegistry {
    private let projections: HashMap<String, Projection>
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.projections = HashMap<String, Projection>()
        this.lock = ReentrantReadWriteMutex()
    }

    public func register(projection: Projection): Unit {
        try {
            lock.writeMutex.lock()
            projections.add(projection.projectionId(), projection)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    public func get(projectionId: String): Option<Projection> {
        try {
            lock.readMutex.lock()
            let result = projections.get(projectionId)
            lock.readMutex.unlock()
            result
        } catch (e: Exception) {
            lock.readMutex.unlock()
            None
        }
    }

    public func startAll(): Unit {
        try {
            lock.readMutex.lock()
            let ids = projections.keys()
            for (id in ids) {
                match (projections.get(id)) {
                    case Some(p) => p.start()
                    case None => ()
                }
            }
            lock.readMutex.unlock()
        } catch (e: Exception) {
            lock.readMutex.unlock()
        }
    }

    public func stopAll(): Unit {
        try {
            lock.readMutex.lock()
            let ids = projections.keys()
            for (id in ids) {
                match (projections.get(id)) {
                    case Some(p) => p.stop()
                    case None => ()
                }
            }
            lock.readMutex.unlock()
        } catch (e: Exception) {
            lock.readMutex.unlock()
        }
    }

    public func size(): Int64 {
        try {
            lock.readMutex.lock()
            let count = projections.size
            lock.readMutex.unlock()
            Int64(count)
        } catch (e: Exception) {
            lock.readMutex.unlock()
            0
        }
    }
}

/**
 * 投影构建器
 */
public class ProjectionBuilder {
    private var projectionId: String = ""
    private var handler: Option<ProjectionHandler> = None
    private var sourceProvider: Option<SourceProvider> = None
    private var offsetStore: Option<OffsetStore> = None
    private var config: ProjectionConfig = ProjectionConfig()

    public func withProjectionId(id: String): ProjectionBuilder {
        projectionId = id
        this
    }

    public func withHandler(h: ProjectionHandler): ProjectionBuilder {
        handler = Some(h)
        this
    }

    public func withSourceProvider(sp: SourceProvider): ProjectionBuilder {
        sourceProvider = Some(sp)
        this
    }

    public func withOffsetStore(store: OffsetStore): ProjectionBuilder {
        offsetStore = Some(store)
        this
    }

    public func withConfig(cfg: ProjectionConfig): ProjectionBuilder {
        config = cfg
        this
    }

    public func build(): Option<Projection> {
        if (handler.isNone()) {
            return None
        }
        if (sourceProvider.isNone()) {
            return None
        }
        if (offsetStore.isNone()) {
            return None
        }

        let name = if (projectionId.isEmpty()) {
            "projection-${DateTime.now().toUnixTimeStamp()}"
        } else {
            projectionId
        }

        let cfg = ProjectionConfig(name: name)
        Some(SimpleProjection(
            cfg.name,
            cfg,
            handler.getOrThrow(),
            sourceProvider.getOrThrow(),
            offsetStore.getOrThrow()
        ))
    }
}

/**
 * 投影实例包装器
 */
public class ProjectionInstance {
    private let projection: Projection
    private let offsetStore: OffsetStore

    public init(projection: Projection, offsetStore: OffsetStore) {
        this.projection = projection
        this.offsetStore = offsetStore
    }

    public func getProjection(): Projection {
        projection
    }

    public func getOffsetStore(): OffsetStore {
        offsetStore
    }

    public func getCurrentOffset(): Option<ProjectionOffset> {
        offsetStore.readOffset(projection.projectionId())
    }

    public func resetOffset(): Unit {
        offsetStore.deleteOffset(projection.projectionId())
    }

    public func getStats(): ProjectionStats {
        ProjectionStats(
            projection.projectionId(),
            projection.state(),
            getCurrentOffset()
        )
    }
}
