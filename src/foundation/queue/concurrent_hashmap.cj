/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 简化并发HashMap实现
 */
package cactor.foundation.queue

import std.sync.*
import std.collection.*

/**
 * 简化的并发HashMap
 * 使用原子操作保护HashMap
 */
public class ConcurrentHashMap<K, V> where K <: Hashable & Equatable<K> {
    private let map: HashMap<K, V>
    private let lock: AtomicBool

    public init() {
        this.map = HashMap<K, V>()
        this.lock = AtomicBool(false)
    }

    /**
     * 获取锁
     */
    private func acquireLock(): Unit {
        while (!lock.compareAndSwap(false, true)) {
            // 自旋等待
        }
    }

    /**
     * 释放锁
     */
    private func releaseLock(): Unit {
        lock.store(false)
    }

    /**
     * 插入键值对
     */
    public func put(key: K, value: V): Option<V> {
        acquireLock()
        let result = map.put(key, value)
        releaseLock()
        return result
    }

    /**
     * 获取值
     */
    public func get(key: K): Option<V> {
        acquireLock()
        let result = map.get(key)
        releaseLock()
        return result
    }

    /**
     * 移除键值对
     */
    public func remove(key: K): Option<V> {
        acquireLock()
        let result = map.remove(key)
        releaseLock()
        return result
    }

    /**
     * 检查是否包含键
     */
    public func containsKey(key: K): Bool {
        acquireLock()
        let result = match (map.get(key)) {
            case Some(_) => true
            case None => false
        }
        releaseLock()
        return result
    }

    /**
     * 清空所有元素
     */
    public func clear(): Unit {
        acquireLock()
        map.clear()
        releaseLock()
    }

    /**
     * 获取大小
     */
    public func size(): Int64 {
        acquireLock()
        let result = map.size
        releaseLock()
        return result
    }

    /**
     * 检查是否为空
     */
    public func isEmpty(): Bool {
        acquireLock()
        let result = map.isEmpty()
        releaseLock()
        return result
    }
}
