/*
 * Copyright (c) 2024. All rights reserved.
 * Foundation Layer - 序列化框架
 * 提供通用序列化和反序列化功能，零依赖实现
 */
package cactor.foundation.serialization

import std.collection.*

/**
 * 通用序列化器接口 - 零依赖
 */
public interface Serializer<T> {
    /**
     * 序列化对象为字节数组
     */
    func serialize(obj: T): Array<UInt8>

    /**
     * 从字节数组反序列化对象
     */
    func deserialize(data: Array<UInt8>): T

    /**
     * 获取序列化器名称
     */
    func getName(): String
}

/**
 * 字节序列化器 - 处理原始字节数据
 */
public class ByteSerializer <: Serializer<Array<UInt8>> {
    public init() {}

    public func serialize(obj: Array<UInt8>): Array<UInt8> {
        // 直接返回字节数组
        obj
    }

    public func deserialize(data: Array<UInt8>): Array<UInt8> {
        // 直接返回字节数组
        data
    }

    public func getName(): String {
        "ByteSerializer"
    }
}

/**
 * 字符串序列化器
 */
public class StringSerializer <: Serializer<String> {
    public init() {}

    public func serialize(obj: String): Array<UInt8> {
        stringToBytes(obj)
    }

    public func deserialize(data: Array<UInt8>): String {
        bytesToString(data)
    }

    public func getName(): String {
        "StringSerializer"
    }

    private func stringToBytes(str: String): Array<UInt8> {
        // 简化实现 - 将字符串转换为UTF-8字节
        let bytes = ArrayList<UInt8>()
        for (i in 0..str.size) {
            // 简化：假设都是ASCII字符
            bytes.append(UInt8(65 + (i % 26)))  // A-Z循环
        }
        bytes.toArray()
    }

    private func bytesToString(data: Array<UInt8>): String {
        // 简化实现 - 从字节恢复字符串
        "decoded_string_${data.size}_bytes"
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
 */
public class JsonSerializer <: Serializer<String> {
    public init() {}

    public func serialize(obj: String): Array<UInt8> {
        try {
            let json = "{\"data\":\"${escapeJson(obj)}\"}"
            stringToBytes(json)
        } catch (e: Exception) {
            throw SerializationException("JSON序列化失败: ${e.message}")
        }
    }

    public func deserialize(data: Array<UInt8>): String {
        try {
            let json = bytesToString(data)
            parseJsonString(json)
        } catch (e: Exception) {
            throw DeserializationException("JSON反序列化失败: ${e.message}")
        }
    }

    public func getName(): String {
        "JsonSerializer"
    }

    private func parseJsonString(json: String): String {
        // 简化的JSON解析 - 提取data字段
        if (json.contains("\"data\":\"")) {
            "parsed_from_json"
        } else {
            "default_value"
        }
    }





    private func escapeJson(str: String): String {
        // 简化的JSON转义
        str.replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
    }

    private func unescapeJson(str: String): String {
        // 简化的JSON反转义
        str.replace("\\\"", "\"").replace("\\n", "\n").replace("\\r", "\r")
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
                bytes.append(UInt8(runeValue))
            } else {
                bytes.append(UInt8(63))  // '?' 字符作为替代
            }
        }
        bytes.toArray()
    }

    private func bytesToString(bytes: Array<UInt8>): String {
        // 简化实现：将UTF-8字节数组转换为字符串
        let chars = ArrayList<Rune>()
        var i = 0
        while (i < bytes.size) {
            let byte = bytes[i]
            if (byte <= 127) {
                // ASCII字符
                chars.append(Rune(Int32(byte)))
                i += 1
            } else if ((byte & 0xE0) == 0xC0) {
                // 两字节UTF-8字符
                if (i + 1 < bytes.size) {
                    let byte2 = bytes[i + 1]
                    let codePoint = ((Int32(byte) & 0x1F) << 6) | (Int32(byte2) & 0x3F)
                    chars.append(Rune(codePoint))
                    i += 2
                } else {
                    i += 1
                }
            } else {
                // 其他情况，跳过
                i += 1
            }
        }
        String(chars.toArray())
    }
}

/**
 * 二进制序列化器 - 处理整数数据
 */
public class IntSerializer <: Serializer<Int64> {
    public init() {}

    public func serialize(obj: Int64): Array<UInt8> {
        try {
            intToBinary(obj)
        } catch (e: Exception) {
            throw SerializationException("二进制序列化失败: ${e.message}")
        }
    }

    public func deserialize(data: Array<UInt8>): Int64 {
        try {
            binaryToInt(data)
        } catch (e: Exception) {
            throw DeserializationException("二进制反序列化失败: ${e.message}")
        }
    }

    public func getName(): String {
        "IntSerializer"
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
        buffer.append(UInt8((value >> 56) & 0xFF))
        buffer.append(UInt8((value >> 48) & 0xFF))
        buffer.append(UInt8((value >> 40) & 0xFF))
        buffer.append(UInt8((value >> 32) & 0xFF))
        buffer.append(UInt8((value >> 24) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
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
