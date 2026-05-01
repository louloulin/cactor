/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - CRDT 分布式数据结构实现
 * 对标 Akka Distributed Data
 * 提供无冲突复制数据类型，支持最终一致性
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * Vector Clock 用于因果排序
 */
public class VectorClock {
    private var clock: HashMap<String, Int64>
    private let nodeId: String
    private let lock: Mutex

    public init(nodeId: String) {
        this.clock = HashMap<String, Int64>()
        this.nodeId = nodeId
        this.lock = Mutex()
        clock.add(nodeId, 0)
    }

    /**
     * 增加当前节点版本
     */
    public func increment(): Unit {
        try {
            lock.lock()
            let current = clock.get(nodeId)
            match (current) {
                case Some(v) =>
                    clock.remove(nodeId)
                    clock.add(nodeId, v + 1)
                case None =>
                    clock.add(nodeId, 1)
            }
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }

    /**
     * 合并另一个 Vector Clock
     */
    public func merge(other: VectorClock): Unit {
        try {
            lock.lock()
            for ((nid, version) in other.clock) {
                match (clock.get(nid)) {
                    case Some(current) =>
                        if (version > current) {
                            clock.remove(nid)
                            clock.add(nid, version)
                        }
                    case None =>
                        clock.add(nid, version)
                }
            }
            lock.unlock()
        } catch (e: Exception) {
            lock.unlock()
        }
    }

    public func toString(): String {
        var result = "{"
        var first = true
        for ((nid, version) in clock) {
            if (!first) {
                result = "${result}, "
            }
            result = "${result}${nid}: ${version}"
            first = false
        }
        "${result}}"
    }
}

/**
 * LWW-Register (最后写入胜出注册表)
 */
public class LWWRegister<T> {
    private var value: T
    private var timestamp: Int64
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String, initialValue: T) {
        this.value = initialValue
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
    }

    public func set(newValue: T): Unit {
        clock.increment()
        value = newValue
        timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func merge(other: LWWRegister<T>): LWWRegister<T> {
        clock.merge(other.clock)
        if (other.timestamp > timestamp) {
            value = other.value
            timestamp = other.timestamp
        }
        this
    }

    public func getValue(): T { value }

    public func identity(): String { "LWWRegister:${nodeId}" }

    public func getTimestamp(): Int64 { timestamp }
}

/**
 * PN-Counter (正负计数器)
 */
public class PNCounter {
    private var positive: HashMap<String, Int64>
    private var negative: HashMap<String, Int64>
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String) {
        this.positive = HashMap<String, Int64>()
        this.negative = HashMap<String, Int64>()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
        positive.add(nodeId, 0)
        negative.add(nodeId, 0)
    }

    /**
     * 增加计数
     */
    public func increment(amount: Int64): Unit {
        clock.increment()
        match (positive.get(nodeId)) {
            case Some(v) =>
                positive.remove(nodeId)
                positive.add(nodeId, v + amount)
            case None =>
                positive.add(nodeId, amount)
        }
    }

    /**
     * 减少计数
     */
    public func decrement(amount: Int64): Unit {
        clock.increment()
        match (negative.get(nodeId)) {
            case Some(v) =>
                negative.remove(nodeId)
                negative.add(nodeId, v + amount)
            case None =>
                negative.add(nodeId, amount)
        }
    }

    public func merge(other: PNCounter): PNCounter {
        clock.merge(other.clock)

        // 合并 positive
        for ((nid, v) in other.positive) {
            match (positive.get(nid)) {
                case Some(current) =>
                    if (v > current) {
                        positive.remove(nid)
                        positive.add(nid, v)
                    }
                case None =>
                    positive.add(nid, v)
            }
        }

        // 合并 negative
        for ((nid, v) in other.negative) {
            match (negative.get(nid)) {
                case Some(current) =>
                    if (v > current) {
                        negative.remove(nid)
                        negative.add(nid, v)
                    }
                case None =>
                    negative.add(nid, v)
            }
        }

        this
    }

    public func value(): Int64 {
        var posSum = 0
        var negSum = 0
        for ((_, v) in positive) {
            posSum += v
        }
        for ((_, v) in negative) {
            negSum += v
        }
        posSum - negSum
    }

    public func identity(): String { "PNCounter:${nodeId}" }
}

/**
 * G-Counter (只增计数器)
 */
public class GCounter {
    private var counts: HashMap<String, Int64>
    private let nodeId: String

    public init(nodeId: String) {
        this.counts = HashMap<String, Int64>()
        this.nodeId = nodeId
        counts.add(nodeId, 0)
    }

    /**
     * 增加计数
     */
    public func increment(amount: Int64): Unit {
        match (counts.get(nodeId)) {
            case Some(v) =>
                counts.remove(nodeId)
                counts.add(nodeId, v + amount)
            case None =>
                counts.add(nodeId, amount)
        }
    }

    public func merge(other: GCounter): GCounter {
        for ((nid, v) in other.counts) {
            match (counts.get(nid)) {
                case Some(current) =>
                    if (v > current) {
                        counts.remove(nid)
                        counts.add(nid, v)
                    }
                case None =>
                    counts.add(nid, v)
            }
        }
        this
    }

    public func value(): Int64 {
        var sum = 0
        for ((_, v) in counts) {
            sum += v
        }
        sum
    }

    public func identity(): String { "GCounter:${nodeId}" }
}

/**
 * OR-Set (观察移除集)
 */
public class ORSet<T> {
    private var elements: HashMap<String, (T, Int64)>  // elementId -> (value, addTimestamp)
    private var removedKeys: HashSet<String>            // 已删除的元素ID
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String) {
        this.elements = HashMap<String, (T, Int64)>()
        this.removedKeys = HashSet<String>()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
    }

    /**
     * 添加元素
     */
    public func add(element: T): String {
        clock.increment()
        let elementId = generateElementId()
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        elements.add(elementId, (element, timestamp))
        elementId
    }

    /**
     * 移除元素
     */
    public func remove(elementId: String): Bool {
        clock.increment()
        if (elements.contains(elementId)) {
            removedKeys.add(elementId)
            return true
        }
        false
    }

    public func merge(other: ORSet<T>): ORSet<T> {
        clock.merge(other.clock)

        // 添加新元素
        for ((eid, (value, ts)) in other.elements) {
            if (!removedKeys.contains(eid)) {
                match (elements.get(eid)) {
                    case Some((_, existingTs)) =>
                        if (ts > existingTs) {
                            elements.remove(eid)
                            elements.add(eid, (value, ts))
                        }
                    case None =>
                        elements.add(eid, (value, ts))
                }
            }
        }

        this
    }

    public func value(): ArrayList<T> {
        let result = ArrayList<T>()
        for ((eid, (value, _)) in elements) {
            if (!removedKeys.contains(eid)) {
                result.add(value)
            }
        }
        result
    }

    public func getElements(): ArrayList<(String, T)> {
        let result = ArrayList<(String, T)>()
        for ((eid, (value, _)) in elements) {
            if (!removedKeys.contains(eid)) {
                result.add((eid, value))
            }
        }
        result
    }

    public func identity(): String { "ORSet:${nodeId}" }

    private func generateElementId(): String {
        let ts = DateTime.now().toUnixTimeStamp().toMilliseconds()
        "${nodeId}_${ts}_${elements.size}"
    }
}

/**
 * LWW-Map (最后写入胜出映射)
 */
public class LWWMap {
    private var entries: HashMap<String, (String, Int64)>
    private var removedSet: HashSet<String>
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String) {
        this.entries = HashMap<String, (String, Int64)>()
        this.removedSet = HashSet<String>()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
    }

    /**
     * 设置键值
     */
    public func set(key: String, value: String): Unit {
        clock.increment()
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        // 先移除旧条目（如果存在）
        if (entries.contains(key)) {
            entries.remove(key)
        }
        entries.add(key, (value, timestamp))
        // 从已删除集合中移除
        if (removedSet.contains(key)) {
            removedSet.remove(key)
        }
    }

    /**
     * 删除键
     */
    public func delete(key: String): Unit {
        clock.increment()
        removedSet.add(key)
        if (entries.contains(key)) {
            entries.remove(key)
        }
    }

    public func merge(other: LWWMap): LWWMap {
        clock.merge(other.clock)

        // 合并 entries
        for ((key, (value, ts)) in other.entries) {
            if (!removedSet.contains(key)) {
                match (entries.get(key)) {
                    case Some((_, existingTs)) =>
                        if (ts > existingTs) {
                            entries.remove(key)
                            entries.add(key, (value, ts))
                        }
                    case None =>
                        entries.add(key, (value, ts))
                }
            }
        }

        this
    }

    public func get(key: String): Option<String> {
        if (removedSet.contains(key)) {
            return None
        }
        match (entries.get(key)) {
            case Some((value, _)) => Some(value)
            case None => None
        }
    }

    public func size(): Int64 { Int64(entries.size) }

    public func identity(): String { "LWWMap:${nodeId}" }
}

/**
 * Distributed Data 节点
 */
public class DistributedDataNode {
    private let nodeId: String
    private var data: HashMap<String, Int64>  // 简化：使用计数器
    private let lock: ReentrantReadWriteMutex

    public init(nodeId: String) {
        this.nodeId = nodeId
        this.data = HashMap<String, Int64>()
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 注册数据
     */
    public func register(key: String, value: Int64): Unit {
        try {
            lock.writeMutex.lock()
            data.add(key, value)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 获取数据
     */
    public func get(key: String): Option<Int64> {
        try {
            lock.readMutex.lock()
            let result = data.get(key)
            lock.readMutex.unlock()
            result
        } catch (e: Exception) {
            lock.readMutex.unlock()
            None
        }
    }

    public func getNodeId(): String { nodeId }
}