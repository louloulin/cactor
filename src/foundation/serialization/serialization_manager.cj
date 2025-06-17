/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 序列化管理器
 * 管理多种序列化器，提供统一的序列化接口，零依赖实现
 */
package cactor.foundation.serialization

import std.collection.*
import std.sync.*

/**
 * 通用序列化管理器 - 零依赖
 * 管理字节数组的序列化和反序列化
 */
public open class SerializationManager {
    private let byteSerializer: ByteSerializer
    private let stringSerializer: StringSerializer
    private let intSerializer: IntSerializer
    private let mutex: ReentrantMutex

    public init() {
        this.byteSerializer = ByteSerializer()
        this.stringSerializer = StringSerializer()
        this.intSerializer = IntSerializer()
        this.mutex = ReentrantMutex()
    }

    /**
     * 序列化字节数组
     */
    public func serializeBytes(data: Array<UInt8>): Array<UInt8> {
        byteSerializer.serialize(data)
    }

    /**
     * 反序列化字节数组
     */
    public func deserializeBytes(data: Array<UInt8>): Array<UInt8> {
        byteSerializer.deserialize(data)
    }

    /**
     * 序列化字符串
     */
    public func serializeString(str: String): Array<UInt8> {
        stringSerializer.serialize(str)
    }

    /**
     * 反序列化字符串
     */
    public func deserializeString(data: Array<UInt8>): String {
        stringSerializer.deserialize(data)
    }

    /**
     * 序列化整数
     */
    public func serializeInt(value: Int64): Array<UInt8> {
        intSerializer.serialize(value)
    }

    /**
     * 反序列化整数
     */
    public func deserializeInt(data: Array<UInt8>): Int64 {
        intSerializer.deserialize(data)
    }

    /**
     * 获取支持的数据类型
     */
    public func getSupportedTypes(): Array<String> {
        ["bytes", "string", "int64"]
    }
}

/**
 * 序列化工厂
 * 提供创建序列化器的工厂方法
 */
public class SerializationFactory {
    /**
     * 创建字节序列化器
     */
    public static func createByteSerializer(): ByteSerializer {
        ByteSerializer()
    }

    /**
     * 创建字符串序列化器
     */
    public static func createStringSerializer(): StringSerializer {
        StringSerializer()
    }

    /**
     * 创建整数序列化器
     */
    public static func createIntSerializer(): IntSerializer {
        IntSerializer()
    }

    /**
     * 创建默认序列化管理器
     */
    public static func createDefaultManager(): SerializationManager {
        SerializationManager()
    }
}

/**
 * 序列化配置
 */
public struct SerializationConfig {
    public let defaultFormat: String
    public let enableCompression: Bool
    public let maxMessageSize: Int64

    public init(defaultFormat: String, enableCompression: Bool, maxMessageSize: Int64) {
        this.defaultFormat = defaultFormat
        this.enableCompression = enableCompression
        this.maxMessageSize = maxMessageSize
    }

    public static func getDefault(): SerializationConfig {
        SerializationConfig("json", false, 1024 * 1024)  // 1MB
    }
}

/**
 * 序列化统计信息
 */
public class SerializationStats {
    private let serializedCount: AtomicInt64
    private let deserializedCount: AtomicInt64
    private let totalSerializedBytes: AtomicInt64
    private let totalDeserializedBytes: AtomicInt64
    private let errorCount: AtomicInt64

    public init() {
        this.serializedCount = AtomicInt64(0)
        this.deserializedCount = AtomicInt64(0)
        this.totalSerializedBytes = AtomicInt64(0)
        this.totalDeserializedBytes = AtomicInt64(0)
        this.errorCount = AtomicInt64(0)
    }

    public func recordSerialization(bytes: Int64): Unit {
        serializedCount.fetchAdd(1)
        totalSerializedBytes.fetchAdd(bytes)
    }

    public func recordDeserialization(bytes: Int64): Unit {
        deserializedCount.fetchAdd(1)
        totalDeserializedBytes.fetchAdd(bytes)
    }

    public func recordError(): Unit {
        errorCount.fetchAdd(1)
    }

    public func getSerializedCount(): Int64 {
        serializedCount.load()
    }

    public func getDeserializedCount(): Int64 {
        deserializedCount.load()
    }

    public func getTotalSerializedBytes(): Int64 {
        totalSerializedBytes.load()
    }

    public func getTotalDeserializedBytes(): Int64 {
        totalDeserializedBytes.load()
    }

    public func getErrorCount(): Int64 {
        errorCount.load()
    }

    public func getAverageSerializedSize(): Float64 {
        let count = serializedCount.load()
        if (count > 0) {
            Float64(totalSerializedBytes.load()) / Float64(count)
        } else {
            0.0
        }
    }

    public func getAverageDeserializedSize(): Float64 {
        let count = deserializedCount.load()
        if (count > 0) {
            Float64(totalDeserializedBytes.load()) / Float64(count)
        } else {
            0.0
        }
    }

    public func reset(): Unit {
        serializedCount.store(0)
        deserializedCount.store(0)
        totalSerializedBytes.store(0)
        totalDeserializedBytes.store(0)
        errorCount.store(0)
    }
}



/**
 * 全局序列化管理器实例
 */
public class GlobalSerializationManager {
    private static var instance: Option<SerializationManager> = None
    private static let mutex: ReentrantMutex = ReentrantMutex()

    public static func getInstance(): SerializationManager {
        mutex.lock()
        let result = match (instance) {
            case Some(manager) => manager
            case None =>
                let manager = SerializationFactory.createDefaultManager()
                instance = Some(manager)
                manager
        }
        mutex.unlock()
        result
    }

    public static func setInstance(manager: SerializationManager): Unit {
        mutex.lock()
        instance = Some(manager)
        mutex.unlock()
    }

    public static func reset(): Unit {
        mutex.lock()
        instance = None
        mutex.unlock()
    }
}
