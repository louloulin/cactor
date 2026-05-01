/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - DeathWatch 实现
 * 对标 Akka DeathWatch - Actor 终止监控
 */
package cactor.core.actor

import std.collection.*
import std.time.*
import cactor.core.message.Message

/**
 * Terminated 消息 - 当被监视的 Actor 终止时发送
 * 对标 Akka: Terminated
 */
public class Terminated <: Message {
    private let actor: ActorRef
    private let existenceConfirmed: Bool
    private let addressTerminated: Bool

    public init(actor: ActorRef, existenceConfirmed!: Bool = true, addressTerminated!: Bool = false) {
        this.actor = actor
        this.existenceConfirmed = existenceConfirmed
        this.addressTerminated = addressTerminated
    }

    public prop actorRef: ActorRef {
        get() { actor }
    }

    public func getExistenceConfirmed(): Bool {
        existenceConfirmed
    }

    public func getAddressTerminated(): Bool {
        addressTerminated
    }

    public func messageType(): String {
        "Terminated"
    }
}

/**
 * Watch 消息 - 开始监视 Actor
 */
public class WatchMessage <: Message {
    private let watcher: ActorRef
    private let subject: ActorRef

    public init(watcher: ActorRef, subject: ActorRef) {
        this.watcher = watcher
        this.subject = subject
    }

    public prop watcherRef: ActorRef {
        get() { watcher }
    }

    public prop subjectRef: ActorRef {
        get() { subject }
    }

    public func messageType(): String {
        "Watch"
    }
}

/**
 * Unwatch 消息 - 取消监视 Actor
 */
public class UnwatchMessage <: Message {
    private let watcher: ActorRef
    private let subject: ActorRef

    public init(watcher: ActorRef, subject: ActorRef) {
        this.watcher = watcher
        this.subject = subject
    }

    public prop watcherRef: ActorRef {
        get() { watcher }
    }

    public prop subjectRef: ActorRef {
        get() { subject }
    }

    public func messageType(): String {
        "Unwatch"
    }
}

/**
 * DeathWatch 状态
 */
public enum DeathWatchState {
    | Watching
    | Terminated
}

/**
 * DeathWatch 条目 - 记录对单个 Actor 的监视
 */
public class DeathWatchEntry {
    private let watcher: ActorRef
    private let subject: ActorRef
    private var state: DeathWatchState
    private let watchTime: Int64

    public init(watcher: ActorRef, subject: ActorRef) {
        this.watcher = watcher
        this.subject = subject
        this.state = DeathWatchState.Watching
        this.watchTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func getWatcher(): ActorRef {
        watcher
    }

    public func getSubject(): ActorRef {
        subject
    }

    public func getState(): DeathWatchState {
        state
    }

    public func setTerminated(): Unit {
        state = DeathWatchState.Terminated
    }

    public func isWatching(): Bool {
        match (state) {
            case DeathWatchState.Watching => true
            case _ => false
        }
    }

    public func getWatchTime(): Int64 {
        watchTime
    }

    public func getSubjectPath(): String {
        subject.path.toString()
    }
}

/**
 * DeathWatch 接口 - Actor 终止监控
 * 对标 Akka DeathWatch
 */
public interface DeathWatch {
    /**
     * 监视一个 Actor
     * 当被监视的 Actor 终止时，监视者会收到 Terminated 消息
     * @param watcher 监视者 Actor
     * @param subject 被监视的 Actor
     */
    func watch(watcher: ActorRef, subject: ActorRef): Unit

    /**
     * 取消对 Actor 的监视
     * @param watcher 监视者 Actor
     * @param subject 被监视的 Actor
     */
    func unwatch(watcher: ActorRef, subject: ActorRef): Unit

    /**
     * 当 Actor 终止时调用
     * 会向所有监视者发送 Terminated 消息
     * @param actor 终止的 Actor
     */
    func notifyTerminated(actor: ActorRef): Unit

    /**
     * 获取监视指定 Actor 的所有监视者
     * @param subject 被监视的 Actor
     * @return 监视者列表
     */
    func getWatchers(subject: ActorRef): ArrayList<ActorRef>

    /**
     * 检查是否正在监视指定 Actor
     * @param watcher 监视者
     * @param subject 被监视者
     * @return 是否正在监视
     */
    func isWatching(watcher: ActorRef, subject: ActorRef): Bool

    /**
     * 获取当前监视条目数量
     */
    func getWatchCount(): Int64

    /**
     * 获取监视者的所有监视条目
     * @param watcher 监视者
     * @return 监视条目列表
     */
    func getWatchEntries(watcher: ActorRef): ArrayList<DeathWatchEntry>
}

/**
 * DeathWatch 统计信息
 */
public class DeathWatchStats {
    private var totalWatches: Int64 = 0
    private var totalTerminations: Int64 = 0
    private var totalUnwatches: Int64 = 0

    public func incrementWatch(): Unit {
        totalWatches += 1
    }

    public func incrementTermination(): Unit {
        totalTerminations += 1
    }

    public func incrementUnwatch(): Unit {
        totalUnwatches += 1
    }

    public func getTotalWatches(): Int64 {
        totalWatches
    }

    public func getTotalTerminations(): Int64 {
        totalTerminations
    }

    public func getTotalUnwatches(): Int64 {
        totalUnwatches
    }

    public func getActiveWatches(): Int64 {
        totalWatches - totalTerminations - totalUnwatches
    }
}

/**
 * DeathWatch 默认实现
 * 对标 Akka DeathWatch implementation
 */
public class DefaultDeathWatch <: DeathWatch {
    // subject -> watcher -> entry 映射
    private let subjectToWatchers: HashMap<String, HashMap<String, DeathWatchEntry>>
    // watcher -> entry 映射
    private let watcherToEntries: HashMap<String, ArrayList<DeathWatchEntry>>
    private let stats: DeathWatchStats

    public init() {
        this.subjectToWatchers = HashMap<String, HashMap<String, DeathWatchEntry>>()
        this.watcherToEntries = HashMap<String, ArrayList<DeathWatchEntry>>()
        this.stats = DeathWatchStats()
    }

    public func watch(watcher: ActorRef, subject: ActorRef): Unit {
        let subjectPath = subject.path.toString()
        let watcherPath = watcher.path.toString()

        // 创建监视条目
        let entry = DeathWatchEntry(watcher, subject)

        // 更新 subject -> watcher 映射
        match (subjectToWatchers.get(subjectPath)) {
            case Some(watcherMap) =>
                watcherMap.add(watcherPath, entry)
            case None =>
                let watcherMap = HashMap<String, DeathWatchEntry>()
                watcherMap.add(watcherPath, entry)
                subjectToWatchers.add(subjectPath, watcherMap)
        }

        // 更新 watcher -> entry 映射
        match (watcherToEntries.get(watcherPath)) {
            case Some(entries) =>
                entries.add(entry)
            case None =>
                let entries = ArrayList<DeathWatchEntry>()
                entries.add(entry)
                watcherToEntries.add(watcherPath, entries)
        }

        stats.incrementWatch()
    }

    public func unwatch(watcher: ActorRef, subject: ActorRef): Unit {
        let subjectPath = subject.path.toString()
        let watcherPath = watcher.path.toString()

        // 从 subject -> watcher 映射中移除
        match (subjectToWatchers.get(subjectPath)) {
            case Some(watcherMap) =>
                watcherMap.remove(watcherPath)
                if (watcherMap.size == 0) {
                    subjectToWatchers.remove(subjectPath)
                }
            case None => ()
        }

        // 从 watcher -> entry 映射中移除
        match (watcherToEntries.get(watcherPath)) {
            case Some(entries) =>
                var i = 0
                while (i < entries.size) {
                    if (entries[i].getSubjectPath() == subjectPath) {
                        entries.remove(Int64(i)..Int64(i + 1))
                    } else {
                        i += 1
                    }
                }
                if (entries.size == 0) {
                    watcherToEntries.remove(watcherPath)
                }
            case None => ()
        }

        stats.incrementUnwatch()
    }

    public func notifyTerminated(actor: ActorRef): Unit {
        let actorPath = actor.path.toString()

        match (subjectToWatchers.get(actorPath)) {
            case Some(watcherMap) =>
                // 标记所有条目为终止状态 - 获取所有条目
                let entriesToTerminate = ArrayList<DeathWatchEntry>()
                for ((_, entry) in watcherMap) {
                    entriesToTerminate.add(entry)
                }
                for (entry in entriesToTerminate) {
                    entry.setTerminated()
                }
                // 清理映射
                subjectToWatchers.remove(actorPath)
            case None => ()
        }

        stats.incrementTermination()
    }

    public func getWatchers(subject: ActorRef): ArrayList<ActorRef> {
        let result = ArrayList<ActorRef>()
        let subjectPath = subject.path.toString()

        match (subjectToWatchers.get(subjectPath)) {
            case Some(watcherMap) =>
                let entries = ArrayList<DeathWatchEntry>()
                for ((_, entry) in watcherMap) {
                    entries.add(entry)
                }
                for (entry in entries) {
                    if (entry.isWatching()) {
                        result.add(entry.getWatcher())
                    }
                }
            case None => ()
        }

        result
    }

    public func isWatching(watcher: ActorRef, subject: ActorRef): Bool {
        let subjectPath = subject.path.toString()
        let watcherPath = watcher.path.toString()

        match (subjectToWatchers.get(subjectPath)) {
            case Some(watcherMap) =>
                match (watcherMap.get(watcherPath)) {
                    case Some(entry) => entry.isWatching()
                    case None => false
                }
            case None => false
        }
    }

    public func getWatchCount(): Int64 {
        var count: Int64 = 0
        for ((_, watcherMap) in subjectToWatchers) {
            count += Int64(watcherMap.size)
        }
        count
    }

    public func getWatchEntries(watcher: ActorRef): ArrayList<DeathWatchEntry> {
        let watcherPath = watcher.path.toString()
        match (watcherToEntries.get(watcherPath)) {
            case Some(entries) => entries
            case None => ArrayList<DeathWatchEntry>()
        }
    }

    /**
     * 获取统计信息
     */
    public func getStats(): DeathWatchStats {
        stats
    }
}

/**
 * DeathWatch 系统 - 全局 DeathWatch 管理器
 */
public class DeathWatchSystem {
    private static var instance: Option<DefaultDeathWatch> = None

    public static func getInstance(): DefaultDeathWatch {
        match (instance) {
            case Some(dw) => dw
            case None =>
                let dw = DefaultDeathWatch()
                instance = Some(dw)
                dw
        }
    }

    public static func reset(): Unit {
        instance = None
    }
}
