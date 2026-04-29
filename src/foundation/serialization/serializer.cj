/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 序列化框架
 * 提供通用序列化和反序列化功能，零依赖实现
 * 对标 Akka Serializer/SerializerRegistry
 */
package cactor.foundation.serialization

import std.collection.*
import std.sync.*

/**
 * 序列化器标识符类型
 */
public type SerializerIdentifier = Int32

/**
 * 序列化器接口 - 对标 Akka Serializer
 * 所有消息序列化器必须实现此接口
 */
public interface Serializer {
    /**
     * 获取序列化器唯一标识符
     * 对标 Akka: Serializer.identifier()
     */
    func identifier(): Int32

    /**
     * 序列化对象为字节数组
     * 对标 Akka: Serializer.toBinary()
     */
    func toBinary(o: Any): Array<UInt8>

    /**
     * 从字节数组反序列化对象
     * 对标 Akka: Serializer.fromBinary()
     */
    func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any

    /**
     * 获取序列化器名称
     */
    func getName(): String

    /**
     * 检查是否包含序列化器特定的manifest
     * 对标 Akka: Serializer.includeManifest
     */
    func includeManifest(): Bool
}

/**
 * 序列化器注册表 - 对标 Akka SerializerRegistry
 * 管理所有序列化器的注册和查找
 */
public class SerializerRegistry {
    private let serializers: HashMap<Int32, Serializer>
    private let manifestToId: HashMap<String, Int32>
    private let idToManifest: HashMap<Int32, String>
    private let mutex: ReentrantMutex

    public init() {
        this.serializers = HashMap<SerializerIdentifier, Serializer>()
        this.manifestToId = HashMap<String, SerializerIdentifier>()
        this.idToManifest = HashMap<SerializerIdentifier, String>()
        this.mutex = ReentrantMutex()

        // 注册内置序列化器
        registerInternalSerializers()
    }

    /**
     * 注册序列化器
     * @param serializer 序列化器实例
     * @param manifests 该序列化器支持的 manifest 列表
     */
    public func register(serializer: Serializer, manifests: Array<String>): Unit {
        mutex.lock()
        

        let id = serializer.identifier()
        serializers.add(id, serializer)

        for (manifest in manifests) {
            manifestToId.add(manifest, id)
            idToManifest.add(id, manifest)
        }

        println("序列化器注册: ${serializer.getName()} (id=${id}), manifests: ${manifests}")
    }

    /**
     * 根据 manifest 获取序列化器
     * @param manifest 类型标识
     * @return 序列化器
     */
    public func get(manifest: String): Serializer {
        mutex.lock()
        

        match (manifestToId.get(manifest)) {
            case Some(id) =>
                match (serializers.get(id)) {
                    case Some(serializer) => serializer
                    case None => throw SerializerNotFoundException("找不到序列化器 id=${id}")
                }
            case None => throw SerializerNotFoundException("找不到 manifest: ${manifest}")
        }
    }

    /**
     * 根据 identifier 获取序列化器
     * @param id 序列化器标识符
     * @return 序列化器
     */
    public func get(id: Int32): Serializer {
        mutex.lock()
        

        match (serializers.get(id)) {
            case Some(serializer) => serializer
            case None => throw SerializerNotFoundException("找不到序列化器 id=${id}")
        }
    }

    /**
     * 获取 manifest 对应的 identifier
     */
    public func getIdentifier(manifest: String): Option<Int32> {
        mutex.lock()
        
        manifestToId.get(manifest)
    }

    /**
     * 根据 identifier 获取 manifest
     */
    public func getManifest(id: Int32): Option<String> {
        mutex.lock()
        
        idToManifest.get(id)
    }

    /**
     * 获取所有注册的序列化器数量
     */
    public func size(): Int64 {
        mutex.lock()
        let sz = serializers.size
        mutex.unlock()
        Int64(sz)
    }

    /**
     * 序列化对象
     * @param o 要序列化的对象
     * @param manifest 类型标识
     * @return 序列化后的字节数组
     */
    public func serialize(o: Any, manifest: String): Array<UInt8> {
        let serializer = get(manifest)
        serializer.toBinary(o)
    }

    /**
     * 反序列化对象
     * @param bytes 字节数组
     * @param manifest 类型标识
     * @return 反序列化后的对象
     */
    public func deserialize(bytes: Array<UInt8>, manifest: String): Any {
        let serializer = get(manifest)
        serializer.fromBinary(bytes, Some(manifest))
    }

    /**
     * 注册内置序列化器
     */
    private func registerInternalSerializers(): Unit {
        // 注册 ByteSerializer
        let byteSerializer = ByteSerializer()
        let byteManifests = Array<String>(2, { i => if (i == 0) { "byte[]" } else { "array[byte]" } })
        register(byteSerializer, byteManifests)

        // 注册 StringSerializer
        let stringSerializer = StringSerializer()
        let stringManifests = Array<String>(2, { i => if (i == 0) { "string" } else { "java.lang.String" } })
        register(stringSerializer, stringManifests)

        // 注册 JsonSerializer
        let jsonSerializer = JsonSerializer()
        let jsonManifests = Array<String>(2, { i => if (i == 0) { "json" } else { "application/json" } })
        register(jsonSerializer, jsonManifests)

        // 注册 IntSerializer
        let intSerializer = IntSerializer()
        let intManifests = Array<String>(3, { i =>
            if (i == 0) { "int64" }
            else if (i == 1) { "long" }
            else { "java.lang.Long" }
        })
        register(intSerializer, intManifests)
    }
}

/**
 * 序列化器未找到异常
 */
public class SerializerNotFoundException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 可序列化接口 - 对标 Akka Serializable
 * 实现此接口的类型可以被序列化
 */
public interface Serializable {}

// 预定义的序列化器标识符
public class SerializerIdentifiers {
    public static let BYTE: Int32 = 1
    public static let STRING: Int32 = 2
    public static let JSON: Int32 = 3
    public static let INT: Int32 = 4
    public static let LONG: Int32 = 5
    public static let DOUBLE: Int32 = 6
    public static let BOOLEAN: Int32 = 7
    public static let CUSTOM_START: Int32 = 100
}

/**
 * 字节序列化器 - 处理原始字节数据
 * 对标 Akka ByteStringSerializer
 */
public class ByteSerializer <: Serializer {
    public init() {}

    public func identifier(): Int32 {
        SerializerIdentifiers.BYTE
    }

    public func toBinary(o: Any): Array<UInt8> {
        match (o) {
            case data: Array<UInt8> => data
            case _ => throw SerializationException("ByteSerializer: 无法序列化类型")
        }
    }

    public func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any {
        bytes
    }

    public func getName(): String {
        "ByteSerializer"
    }

    public func includeManifest(): Bool {
        false
    }
}

/**
 * 字符串序列化器 - 对标 Akka StringSerializer
 */
public class StringSerializer <: Serializer {
    public init() {}

    public func identifier(): Int32 {
        SerializerIdentifiers.STRING
    }

    public func toBinary(o: Any): Array<UInt8> {
        match (o) {
            case s: String => stringToBytes(s)
            case _ => throw SerializationException("StringSerializer: 无法序列化类型")
        }
    }

    public func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any {
        bytesToString(bytes)
    }

    public func getName(): String {
        "StringSerializer"
    }

    public func includeManifest(): Bool {
        false
    }

    private func stringToBytes(str: String): Array<UInt8> {
        // 简化实现：将字符串转换为字节数组
        let bytes = ArrayList<UInt8>()
        // 简化：假设都是ASCII字符，使用字符的实际ASCII值
        for (i in 0..str.size) {
            let char = str[i]
            // Rune类型转换为Int32，然后转为UInt8
            let runeValue = Int32(char)
            if (runeValue <= 127) {
                bytes.add(UInt8(runeValue))
            } else {
                bytes.add(UInt8(63))  // '?' 字符作为替代
            }
        }
        bytes.toArray()
    }

    private func bytesToString(data: Array<UInt8>): String {
        // 简化实现：将UTF-8字节数组转换为字符串
        let chars = ArrayList<Rune>()
        var i = 0
        while (i < data.size) {
            let byte = data[i]
            if (byte <= 127) {
                // ASCII字符
                chars.add(Rune(Int32(byte)))
                i += 1
            } else {
                // 非ASCII字符，跳过
                i += 1
            }
        }
        String(chars.toArray())
    }
}

/**
 * 序列化异常
 */
public class SerializationException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 反序列化异常
 */
public class DeserializationException <: Exception {
    public init(message: String) {
        super(message)
    }
}


/**
 * JSON序列化器 - 处理JSON字符串
 * 对标 Akka JsonSerializer
 */
public class JsonSerializer <: Serializer {
    public init() {}

    public func identifier(): Int32 {
        SerializerIdentifiers.JSON
    }

    public func toBinary(o: Any): Array<UInt8> {
        try {
            let json = objectToJson(o)
            stringToBytes(json)
        } catch (e: Exception) {
            throw SerializationException("JSON序列化失败: ${e.message}")
        }
    }

    public func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any {
        bytesToString(bytes)
    }

    public func getName(): String {
        "JsonSerializer"
    }

    public func includeManifest(): Bool {
        true
    }

    private func objectToJson(o: Any): String {
        match (o) {
            case s: String => "\"${escapeJson(s)}\""
            case i: Int64 => i.toString()
            case f: Float64 => f.toString()
            case b: Bool => b.toString()
            case _ => "\"unknown\""
        }
    }

    private func escapeJson(str: String): String {
        str.replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
    }

    private func stringToBytes(str: String): Array<UInt8> {
        let bytes = ArrayList<UInt8>()
        for (i in 0..str.size) {
            let char = str[i]
            let runeValue = Int32(char)
            if (runeValue <= 127) {
                bytes.add(UInt8(runeValue))
            } else {
                bytes.add(UInt8(63))
            }
        }
        bytes.toArray()
    }

    private func bytesToString(bytes: Array<UInt8>): String {
        let chars = ArrayList<Rune>()
        var i = 0
        while (i < bytes.size) {
            let byte = bytes[i]
            if (byte <= 127) {
                chars.add(Rune(Int32(byte)))
                i += 1
            } else if ((byte & 0xE0) == 0xC0) {
                if (i + 1 < bytes.size) {
                    let byte2 = bytes[i + 1]
                    let codePoint = ((Int32(byte) & 0x1F) << 6) | (Int32(byte2) & 0x3F)
                    chars.add(Rune(codePoint))
                    i += 2
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        String(chars.toArray())
    }
}

/**
 * Int64二进制序列化器 - 对标 Akka ProtobufSerializer
 */
public class IntSerializer <: Serializer {
    public init() {}

    public func identifier(): Int32 {
        SerializerIdentifiers.LONG
    }

    public func toBinary(o: Any): Array<UInt8> {
        match (o) {
            case i: Int64 => intToBinary(i)
            case i: Int32 => intToBinary(Int64(i))
            case _ => throw SerializationException("IntSerializer: 无法序列化类型")
        }
    }

    public func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any {
        binaryToInt(bytes)
    }

    public func getName(): String {
        "IntSerializer"
    }

    public func includeManifest(): Bool {
        false
    }

    private func intToBinary(value: Int64): Array<UInt8> {
        let result = ArrayList<UInt8>()
        writeInt64(result, value)
        result.toArray()
    }

    private func binaryToInt(data: Array<UInt8>): Int64 {
        if (data.size < 8) {
            throw DeserializationException("数据不完整，需要8字节")
        }
        readInt64(data, 0)
    }

    private func writeInt64(buffer: ArrayList<UInt8>, value: Int64): Unit {
        buffer.add(UInt8((value >> 56) & 0xFF))
        buffer.add(UInt8((value >> 48) & 0xFF))
        buffer.add(UInt8((value >> 40) & 0xFF))
        buffer.add(UInt8((value >> 32) & 0xFF))
        buffer.add(UInt8((value >> 24) & 0xFF))
        buffer.add(UInt8((value >> 16) & 0xFF))
        buffer.add(UInt8((value >> 8) & 0xFF))
        buffer.add(UInt8(value & 0xFF))
    }

    private func readInt64(data: Array<UInt8>, offset: Int64): Int64 {
        (Int64(data[offset]) << 56) |
        (Int64(data[offset + 1]) << 48) |
        (Int64(data[offset + 2]) << 40) |
        (Int64(data[offset + 3]) << 32) |
        (Int64(data[offset + 4]) << 24) |
        (Int64(data[offset + 5]) << 16) |
        (Int64(data[offset + 6]) << 8) |
        Int64(data[offset + 7])
    }
}
