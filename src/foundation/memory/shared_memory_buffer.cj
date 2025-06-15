/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Foundation - 共享内存缓冲区
 * 提供零拷贝消息传递的共享内存缓冲区实现
 */
package cactor.foundation.memory

import std.sync.*
import std.collection.*

/**
 * 共享内存缓冲区
 * 支持引用计数的零拷贝缓冲区
 */
public class SharedMemoryBuffer {
    private let data: Array<UInt8>
    private let size: UInt64
    private let refCount: AtomicInt64
    private let isValidFlag: AtomicBool
    private let mutex: ReentrantMutex

    public init(size: UInt64) {
        this.size = size
        this.data = Array<UInt8>(Int64(size), { i => UInt8(0) })
        this.refCount = AtomicInt64(1)
        this.isValidFlag = AtomicBool(true)
        this.mutex = ReentrantMutex()
    }

    public init(data: Array<UInt8>) {
        this.size = UInt64(data.size)
        this.data = data
        this.refCount = AtomicInt64(1)
        this.isValidFlag = AtomicBool(true)
        this.mutex = ReentrantMutex()
    }

    /**
     * 获取缓冲区大小
     */
    public func getSize(): UInt64 {
        size
    }

    /**
     * 获取数据数组
     */
    public func getData(): Array<UInt8> {
        data
    }

    /**
     * 检查缓冲区是否有效
     */
    public func isValid(): Bool {
        isValidFlag.load()
    }

    /**
     * 获取引用计数
     */
    public func getRefCount(): Int64 {
        refCount.load()
    }

    /**
     * 增加引用计数
     */
    public func retain(): Unit {
        if (isValidFlag.load()) {
            refCount.fetchAdd(1)
        }
    }

    /**
     * 减少引用计数
     */
    public func release(): Unit {
        if (isValidFlag.load()) {
            let newCount = refCount.fetchAdd(-1)
            if (newCount <= 1) {
                // 引用计数为0，标记为无效
                isValidFlag.store(false)
            }
        }
    }

    /**
     * 复制数据到缓冲区
     */
    public func copyFrom(source: Array<UInt8>, offset: UInt64): Bool {
        if (!isValidFlag.load()) {
            return false
        }

        mutex.lock()
        try {
            let copySize = if (UInt64(source.size) + offset > size) {
                size - offset
            } else {
                UInt64(source.size)
            }

            for (i in 0..Int64(copySize)) {
                data[Int64(offset) + i] = source[i]
            }
            return true
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 从缓冲区复制数据
     */
    public func copyTo(dest: Array<UInt8>, offset: UInt64, length: UInt64): Bool {
        if (!isValidFlag.load()) {
            return false
        }

        mutex.lock()
        try {
            let copySize = if (offset + length > size) {
                size - offset
            } else {
                length
            }

            let destSize = if (Int64(copySize) > dest.size) {
                dest.size
            } else {
                Int64(copySize)
            }

            for (i in 0..destSize) {
                dest[i] = data[Int64(offset) + i]
            }
            return true
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 清零缓冲区
     */
    public func clear(): Unit {
        if (!isValidFlag.load()) {
            return
        }

        mutex.lock()
        try {
            for (i in 0..data.size) {
                data[i] = UInt8(0)
            }
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 获取缓冲区切片
     */
    public func slice(offset: UInt64, length: UInt64): Array<UInt8> {
        if (!isValidFlag.load()) {
            return Array<UInt8>(0, { i => UInt8(0) })
        }

        let endPos = if (offset + length > size) {
            size
        } else {
            offset + length
        }

        let sliceSize = Int64(endPos - offset)
        if (sliceSize <= 0) {
            return Array<UInt8>(0, { i => UInt8(0) })
        }

        let result = Array<UInt8>(sliceSize, { i => UInt8(0) })
        mutex.lock()
        try {
            for (i in 0..sliceSize) {
                result[i] = data[Int64(offset) + i]
            }
        } finally {
            mutex.unlock()
        }

        return result
    }
}

// 注意：MemoryPool和MemoryPoolStats已在numa_memory_pool.cj中定义
