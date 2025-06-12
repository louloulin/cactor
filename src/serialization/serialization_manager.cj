/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 序列化管理器
 * 管理多种序列化器，提供统一的序列化接口
 */
package cactor.serialization

import std.collection.*
import std.sync.*
import cactor.core.message.Message

/**
 * 序列化管理器
 * 管理多个序列化器，根据消息类型选择合适的序列化器
 */
public open class SerializationManager {
    private let serializers: HashMap<String, Serializer>
    private let defaultSerializer: Serializer
    private let mutex: ReentrantMutex

    public init() {
        this.serializers = HashMap<String, Serializer>()
        this.defaultSerializer = JsonSerializer()
        this.mutex = ReentrantMutex()
    }

    /**
     * 初始化默认序列化器
     */
    public func initializeDefaultSerializers(): Unit {
        registerSerializer(defaultSerializer)
        registerSerializer(BinarySerializer())
    }

    /**
     * 注册序列化器
     */
    public func registerSerializer(serializer: Serializer): Unit {
        mutex.lock()
        let supportedTypes = serializer.getSupportedTypes()
        for (messageType in supportedTypes) {
            serializers[messageType] = serializer
        }
        mutex.unlock()
    }

    /**
     * 序列化消息
     */
    public open func serialize(message: Message): Array<UInt8> {
        let messageType = message.messageType()
        let serializer = getSerializerForType(messageType)
        serializer.serialize(message)
    }

    /**
     * 反序列化消息
     */
    public open func deserialize(data: Array<UInt8>, messageType: String): Message {
        let serializer = getSerializerForType(messageType)
        serializer.deserialize(data)
    }

    /**
     * 获取指定类型的序列化器
     */
    private func getSerializerForType(messageType: String): Serializer {
        mutex.lock()
        let result = match (serializers.get(messageType)) {
            case Some(serializer) => serializer
            case None => defaultSerializer
        }
        mutex.unlock()
        result
    }

    /**
     * 获取所有支持的消息类型
     */
    public func getSupportedTypes(): Array<String> {
        mutex.lock()
        let types = ArrayList<String>()
        for ((key, _) in serializers) {
            types.append(key)
        }
        let result = types.toArray()
        mutex.unlock()
        result
    }

    /**
     * 获取序列化器数量
     */
    public func getSerializerCount(): Int64 {
        mutex.lock()
        let count = serializers.size
        mutex.unlock()
        count
    }
}

/**
 * 序列化工厂
 * 提供创建序列化器的工厂方法
 */
public class SerializationFactory {
    /**
     * 创建JSON序列化器
     */
    public static func createJsonSerializer(): Serializer {
        JsonSerializer()
    }

    /**
     * 创建二进制序列化器
     */
    public static func createBinarySerializer(): Serializer {
        BinarySerializer()
    }

    /**
     * 创建默认序列化管理器
     */
    public static func createDefaultManager(): SerializationManager {
        let manager = SerializationManager()
        manager.initializeDefaultSerializers()
        manager
    }

    /**
     * 创建自定义序列化管理器
     */
    public static func createCustomManager(serializers: Array<Serializer>): SerializationManager {
        let manager = SerializationManager()
        for (serializer in serializers) {
            manager.registerSerializer(serializer)
        }
        manager
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
 * 带统计的序列化管理器
 */
public class StatefulSerializationManager <: SerializationManager {
    private let stats: SerializationStats
    private let config: SerializationConfig

    public init(config: SerializationConfig) {
        super()
        this.stats = SerializationStats()
        this.config = config
    }

    public func serialize(message: Message): Array<UInt8> {
        try {
            let data = super.serialize(message)
            stats.recordSerialization(Int64(data.size))
            
            // 检查消息大小限制
            if (data.size > config.maxMessageSize) {
                throw SerializationException("消息大小超过限制: ${data.size} > ${config.maxMessageSize}")
            }
            
            data
        } catch (e: Exception) {
            stats.recordError()
            throw e
        }
    }

    public func deserialize(data: Array<UInt8>, messageType: String): Message {
        try {
            let message = super.deserialize(data, messageType)
            stats.recordDeserialization(Int64(data.size))
            message
        } catch (e: Exception) {
            stats.recordError()
            throw e
        }
    }

    public func getStats(): SerializationStats {
        stats
    }

    public func getConfig(): SerializationConfig {
        config
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
