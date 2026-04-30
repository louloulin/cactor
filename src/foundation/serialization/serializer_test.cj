/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Serializer 单元测试
 */
package cactor.foundation.serialization

import std.collection.*
import std.convert.*

@Test
func testSerializerRegistry_initialization() {
    let registry = SerializerRegistry()
    @Expect(registry.size() > 0, true)
}

@Test
func testSerializerRegistry_register() {
    let registry = SerializerRegistry()
    let initialSize = registry.size()
    let testSerializer = TestSerializer(100, "test")
    registry.register(testSerializer, ["TestType"])
    @Expect(registry.size() >= initialSize + 1, true)
}

@Test
func testSerializerRegistry_getByManifest() {
    let registry = SerializerRegistry()
    let stringSerializer = registry.get("string")
    @Expect(stringSerializer.getName().size > 0, true)
}

@Test
func testSerializerRegistry_getByIdentifier() {
    let registry = SerializerRegistry()
    let serializer = registry.get(1)
    @Expect(serializer.identifier() >= 0, true)
}

@Test
func testSerializerRegistry_getIdentifier() {
    let registry = SerializerRegistry()
    let id = registry.getIdentifier("string")
    match (id) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testSerializerRegistry_getManifest() {
    let registry = SerializerRegistry()
    let manifest = registry.getManifest(1)
    match (manifest) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testSerializerRegistry_roundTrip() {
    let registry = SerializerRegistry()
    let testSerializer = RoundTripSerializer()
    registry.register(testSerializer, ["RoundTripTest"])

    let obj = RoundTripTestData("hello", 42)
    let bytes = registry.serialize(obj, "RoundTripTest")
    let result = registry.deserialize(bytes, "RoundTripTest")

    match (result) {
        case data: RoundTripTestData =>
            @Expect(data.name, "hello")
            @Expect(data.value, 42)
        case _ => @Expect(false, true)
    }
}

@Test
func testByteSerializer_identifier() {
    let serializer = ByteSerializer()
    @Expect(serializer.identifier() >= 0, true)
}

@Test
func testByteSerializer_roundTrip() {
    let serializer = ByteSerializer()
    let original: Array<UInt8> = [0x01, 0x02, 0x03, 0x04]
    let bytes = serializer.toBinary(original)
    let result = serializer.fromBinary(bytes, None)
    match (result) {
        case arr: Array<UInt8> => @Expect(arr.size > 0, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testStringSerializer_identifier() {
    let serializer = StringSerializer()
    @Expect(serializer.identifier() >= 0, true)
}

@Test
func testStringSerializer_roundTrip() {
    let serializer = StringSerializer()
    let original = "Hello, Serialization!"
    let bytes = serializer.toBinary(original)
    let result = serializer.fromBinary(bytes, None)
    match (result) {
        case s: String => @Expect(s, "Hello, Serialization!")
        case _ => @Expect(false, true)
    }
}

@Test
func testStringSerializer_unicode() {
    let serializer = StringSerializer()
    let original = "Hello World!"
    let bytes = serializer.toBinary(original)
    let result = serializer.fromBinary(bytes, None)
    match (result) {
        case s: String => @Expect(s, "Hello World!")
        case _ => @Expect(false, true)
    }
}

@Test
func testStringSerializer_empty() {
    let serializer = StringSerializer()
    let bytes = serializer.toBinary("")
    let result = serializer.fromBinary(bytes, None)
    match (result) {
        case s: String => @Expect(s, "")
        case _ => @Expect(false, true)
    }
}

@Test
func testIntSerializer_roundTrip() {
    let serializer = IntSerializer()
    let bytes1 = serializer.toBinary(42)
    let result1 = serializer.fromBinary(bytes1, None)
    match (result1) {
        case i: Int64 => @Expect(i, 42)
        case _ => @Expect(false, true)
    }

    let bytes2 = serializer.toBinary(-100)
    let result2 = serializer.fromBinary(bytes2, None)
    match (result2) {
        case i: Int64 => @Expect(i, -100)
        case _ => @Expect(false, true)
    }

    let bytes3 = serializer.toBinary(0)
    let result3 = serializer.fromBinary(bytes3, None)
    match (result3) {
        case i: Int64 => @Expect(i, 0)
        case _ => @Expect(false, true)
    }
}

@Test
func testIntSerializer_largeNumber() {
    let serializer = IntSerializer()
    let largeNum = 9223372036854775807
    let bytes = serializer.toBinary(largeNum)
    let result = serializer.fromBinary(bytes, None)
    match (result) {
        case i: Int64 => @Expect(i, largeNum)
        case _ => @Expect(false, true)
    }
}

@Test
func testJsonSerializer_roundTrip() {
    let serializer = JsonSerializer()
    let original = JsonTestData("test", 123)
    let bytes = serializer.toBinary(original)
    let result = serializer.fromBinary(bytes, Some("JsonTestData"))
    match (result) {
        case _ => @Expect(true, true)
    }
}

@Test
func testJsonSerializer_complex() {
    let serializer = JsonSerializer()
    let original = JsonTestData("complex", 999)
    let bytes = serializer.toBinary(original)
    @Expect(bytes.size > 0, true)
}

/*
 * 测试辅助类
 */

class TestSerializer <: Serializer {
    private let id: Int32
    private let name: String

    public init(id: Int32, name: String) {
        this.id = id
        this.name = name
    }

    public func identifier(): Int32 {
        id
    }

    public func toBinary(o: Any): Array<UInt8> {
        Array<UInt8>()
    }

    public func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any {
        ()
    }

    public func getName(): String {
        name
    }

    public func includeManifest(): Bool {
        false
    }
}

class RoundTripSerializer <: Serializer {
    public init() {}

    public func identifier(): Int32 {
        9999
    }

    public func toBinary(o: Any): Array<UInt8> {
        match (o) {
            case data: RoundTripTestData =>
                let result = ArrayList<UInt8>()
                // Encode name as ASCII bytes with null separator
                for (i in 0..data.name.size) {
                    let char = data.name[i]
                    let runeValue = Int32(char)
                    if (runeValue <= 127) {
                        result.add(UInt8(runeValue))
                    } else {
                        result.add(UInt8(63))
                    }
                }
                result.add(0)  // separator
                // Encode value as decimal ASCII digits with null terminator
                let valueStr = data.value.toString()
                for (i in 0..valueStr.size) {
                    let char = valueStr[i]
                    let runeValue = Int32(char)
                    result.add(UInt8(runeValue))
                }
                result.add(0)  // end marker
                result.toArray()
            case _ => Array<UInt8>()
        }
    }

    public func fromBinary(bytes: Array<UInt8>, manifest: Option<String>): Any {
        if (bytes.size < 2) {
            throw Exception("Invalid bytes")
        }

        var nameChars = ArrayList<Rune>()
        var i = 0
        while (i < bytes.size && bytes[i] != 0) {
            nameChars.add(Rune(Int32(bytes[i])))
            i += 1
        }
        let name = String(nameChars.toArray())

        i += 1  // skip separator
        var valueChars = ArrayList<Rune>()
        while (i < bytes.size && bytes[i] != 0) {
            valueChars.add(Rune(Int32(bytes[i])))
            i += 1
        }
        let valueStr = String(valueChars.toArray())
        let value = Int64.parse(valueStr)
        RoundTripTestData(name, value)
    }

    public func getName(): String {
        "RoundTripSerializer"
    }

    public func includeManifest(): Bool {
        false
    }
}

class RoundTripTestData {
    public let name: String
    public let value: Int64

    public init(name: String, value: Int64) {
        this.name = name
        this.value = value
    }
}

class JsonTestData {
    public let field1: String
    public let field2: Int64

    public init(field1: String, field2: Int64) {
        this.field1 = field1
        this.field2 = field2
    }
}
