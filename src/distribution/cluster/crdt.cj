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
 * G-Set (Grow-only Set - 只增集合)
 * 只能添加元素，不能移除元素
 * 使用 String 类型以避免泛型限制
 */
public class GSet {
    private var elements: HashMap<String, String>  // element -> element
    private let nodeId: String

    public init(nodeId: String) {
        this.elements = HashMap<String, String>()
        this.nodeId = nodeId
    }

    /**
     * 添加元素
     */
    public func add(element: String): Unit {
        if (!elements.contains(element)) {
            elements.add(element, element)
        }
    }

    /**
     * 合并另一个 G-Set
     */
    public func merge(other: GSet): GSet {
        for ((key, val) in other.elements) {
            if (!elements.contains(key)) {
                elements.add(key, val)
            }
        }
        this
    }

    /**
     * 获取所有元素
     */
    public func value(): HashMap<String, String> {
        elements
    }

    /**
     * 检查是否包含元素
     */
    public func contains(element: String): Bool {
        elements.contains(element)
    }

    /**
     * 获取元素数量
     */
    public func size(): Int64 {
        Int64(elements.size)
    }

    public func identity(): String { "GSet:${nodeId}" }
}

/**
 * Flag (Enable-Wins Flag - 启用胜出标志)
 * 用于协调跨节点的事件，只能从 false 变为 true
 */
public class Flag {
    private var isEnabled: Bool
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String) {
        this.isEnabled = false
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
    }

    /**
     * 创建已启用的 Flag
     */
    public static func createEnabled(nodeId: String): Flag {
        let flag = Flag(nodeId)
        flag.isEnabled = true
        flag
    }

    /**
     * 启用标志（只能从 false 变为 true）
     */
    public func enable(): Unit {
        clock.increment()
        isEnabled = true
    }

    /**
     * 合并另一个 Flag（任一节点启用则最终启用）
     */
    public func merge(other: Flag): Flag {
        clock.merge(other.clock)
        isEnabled = isEnabled || other.isEnabled
        this
    }

    /**
     * 获取当前值
     */
    public func value(): Bool {
        isEnabled
    }

    public func identity(): String { "Flag:${nodeId}" }
}

/**
 * 2P-Set (Two-Phase Set)
 * 由两个 G-Set 组成：一个添加集，一个移除集
 */
public class TwoPhaseSet {
    private var addedSet: GSet
    private var removedSet: GSet
    private let nodeId: String

    public init(nodeId: String) {
        this.addedSet = GSet(nodeId)
        this.removedSet = GSet(nodeId)
        this.nodeId = nodeId
    }

    /**
     * 添加元素
     */
    public func add(element: String): Unit {
        addedSet.add(element)
    }

    /**
     * 移除元素
     */
    public func remove(element: String): Bool {
        // 只能移除已添加且未移除的元素
        if (addedSet.contains(element) && !removedSet.contains(element)) {
            removedSet.add(element)
            return true
        }
        false
    }

    /**
     * 合并另一个 2P-Set
     */
    public func merge(other: TwoPhaseSet): TwoPhaseSet {
        addedSet = addedSet.merge(other.addedSet)
        removedSet = removedSet.merge(other.removedSet)
        this
    }

    /**
     * 获取当前可见的元素
     */
    public func value(): HashMap<String, String> {
        let result = HashMap<String, String>()
        for ((key, val) in addedSet.value()) {
            if (!removedSet.contains(key)) {
                result.add(key, val)
            }
        }
        result
    }

    public func identity(): String { "TwoPhaseSet:${nodeId}" }
}

/**
 * MV-Register (Multi-Value Register)
 * 允许多个并发值，最终收敛到所有可能值之一
 */
public class MVRegister<T> {
    private var values: HashMap<String, T>  // nodeId -> value
    private var timestamps: HashMap<String, Int64>  // nodeId -> timestamp
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String, initialValue: T) {
        this.values = HashMap<String, T>()
        this.timestamps = HashMap<String, Int64>()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
        values.add(nodeId, initialValue)
        timestamps.add(nodeId, DateTime.now().toUnixTimeStamp().toMilliseconds())
    }

    /**
     * 设置值
     */
    public func set(newValue: T): Unit {
        clock.increment()
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        values.remove(nodeId)
        values.add(nodeId, newValue)
        timestamps.remove(nodeId)
        timestamps.add(nodeId, timestamp)
    }

    /**
     * 合并另一个 MV-Register
     */
    public func merge(other: MVRegister<T>): MVRegister<T> {
        clock.merge(other.clock)

        for ((nid, v) in other.values) {
            let ts = match (other.timestamps.get(nid)) {
                case Some(t) => t
                case None => 0
            }
            match (timestamps.get(nid)) {
                case Some(currentTs) =>
                    if (ts > currentTs) {
                        values.remove(nid)
                        values.add(nid, v)
                        timestamps.remove(nid)
                        timestamps.add(nid, ts)
                    }
                case None =>
                    values.add(nid, v)
                    timestamps.add(nid, ts)
            }
        }
        this
    }

    /**
     * 获取所有可能的值
     */
    public func value(): ArrayList<T> {
        let result = ArrayList<T>()
        for ((_, v) in values) {
            result.add(v)
        }
        result
    }

    public func identity(): String { "MVRegister:${nodeId}" }
}

/**
 * ORMap (Observed-Remove Map)
 * 支持键值对的添加、删除和合并
 * 使用 HashMap<String, Int64> 记录删除时间戳来替代 HashSet
 */
public class ORMap {
    private var entries: HashMap<String, (String, Int64)>  // key -> (value, timestamp)
    private var removedTimestamps: HashMap<String, Int64>  // key -> delete timestamp
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String) {
        this.entries = HashMap<String, (String, Int64)>()
        this.removedTimestamps = HashMap<String, Int64>()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
    }

    /**
     * 设置键值
     */
    public func set(key: String, value: String): Unit {
        clock.increment()
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        entries.remove(key)
        entries.add(key, (value, timestamp))
        // 如果之前被删除，取消删除标记
        if (removedTimestamps.contains(key)) {
            removedTimestamps.remove(key)
        }
    }

    /**
     * 删除键
     */
    public func remove(key: String): Unit {
        clock.increment()
        if (entries.contains(key)) {
            let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
            removedTimestamps.remove(key)
            removedTimestamps.add(key, timestamp)
            entries.remove(key)
        }
    }

    private func isRemoved(key: String): Bool {
        removedTimestamps.contains(key)
    }

    /**
     * 合并另一个 ORMap
     */
    public func merge(other: ORMap): ORMap {
        clock.merge(other.clock)

        // 合并 entries
        for ((key, (value, ts)) in other.entries) {
            if (!isRemoved(key)) {
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

        // 合并删除时间戳
        for ((key, ts) in other.removedTimestamps) {
            match (removedTimestamps.get(key)) {
                case Some(existingTs) =>
                    if (ts > existingTs) {
                        removedTimestamps.remove(key)
                        removedTimestamps.add(key, ts)
                    }
                case None =>
                    removedTimestamps.add(key, ts)
            }
        }

        // 移除被标记为删除的键
        for ((key, _) in removedTimestamps) {
            if (entries.contains(key)) {
                entries.remove(key)
            }
        }

        this
    }

    /**
     * 获取键对应的值
     */
    public func get(key: String): Option<String> {
        if (isRemoved(key)) {
            return None
        }
        match (entries.get(key)) {
            case Some((value, _)) => Some(value)
            case None => None
        }
    }

    /**
     * 检查键是否存在
     */
    public func contains(key: String): Bool {
        !isRemoved(key) && entries.contains(key)
    }

    /**
     * 获取所有键
     */
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((key, _) in entries) {
            if (!isRemoved(key)) {
                result.add(key)
            }
        }
        result
    }

    /**
     * 获取条目数量
     */
    public func size(): Int64 {
        Int64(entries.size)
    }

    public func identity(): String { "ORMap:${nodeId}" }
}

/**
 * RWSequence (Read-Write Sequence)
 * 支持并发追加的序列，保证因果顺序
 */
public class RWSequence {
    private var elements: ArrayList<(String, Int64)>  // (nodeId, timestamp)
    private var tombstones: ArrayList<Int64>  // 已删除的索引
    private let nodeId: String
    private let clock: VectorClock

    public init(nodeId: String) {
        this.elements = ArrayList<(String, Int64)>()
        this.tombstones = ArrayList<Int64>()
        this.nodeId = nodeId
        this.clock = VectorClock(nodeId)
    }

    private func isTombstoned(idx: Int64): Bool {
        for (t in tombstones) {
            if (t == idx) {
                return true
            }
        }
        false
    }

    private func addTombstone(idx: Int64): Unit {
        if (!isTombstoned(idx)) {
            tombstones.add(idx)
        }
    }

    /**
     * 追加元素
     */
    public func append(): Int64 {
        clock.increment()
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let index = elements.size
        elements.add((nodeId, timestamp))
        Int64(index)
    }

    /**
     * 获取指定位置的值（按索引）
     */
    public func getAt(index: Int64): Option<(String, Int64)> {
        if (index >= 0 && index < Int64(elements.size) && !isTombstoned(index)) {
            Some(elements[index])
        } else {
            None
        }
    }

    /**
     * 合并另一个 RWSequence
     */
    public func merge(other: RWSequence): RWSequence {
        clock.merge(other.clock)

        // 合并元素
        for ((nid, ts) in other.elements) {
            var found = false
            for ((existingNid, existingTs) in elements) {
                if (existingNid == nid && existingTs == ts) {
                    found = true
                    break
                }
            }
            if (!found) {
                elements.add((nid, ts))
            }
        }

        // 合并墓碑
        for (idx in other.tombstones) {
            addTombstone(idx)
        }

        this
    }

    /**
     * 获取有效元素数量
     */
    public func size(): Int64 {
        Int64(elements.size) - Int64(tombstones.size)
    }

    /**
     * 获取所有有效元素
     */
    public func value(): ArrayList<(String, Int64)> {
        let result = ArrayList<(String, Int64)>()
        for (i in 0..elements.size) {
            if (!tombstones.contains(Int64(i))) {
                result.add(elements[i])
            }
        }
        result
    }

    public func identity(): String { "RWSequence:${nodeId}" }
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