/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Coexistence 示例程序
 * 演示多 ActorSystem 桥接、类型适配、混合路由
 */
package cactor.examples.coexistence_demo

import std.collection.*
import std.time.*

// ============================================================================
// Coexistence 示例演示
// ============================================================================

/**
 * ActorSystem 配置
 */
public class ActorSystemConfig <: ToString {
    public let name: String
    public let host: String
    public let port: Int32
    public let selfAddress: String

    public init(name: String, host: String, port: Int32) {
        this.name = name
        this.host = host
        this.port = port
        this.selfAddress = "${host}:${port}"
    }

    public func toString(): String {
        "ActorSystem(${name}, ${selfAddress})"
    }
}

/**
 * 消息信封
 */
public class Envelope {
    public let message: String
    public let sender: String
    public let timestamp: Int64

    public init(message: String, sender: String) {
        this.message = message
        this.sender = sender
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 地址映射
 */
public class AddressMapping {
    public let source: String
    public let target: String

    public init(source: String, target: String) {
        this.source = source
        this.target = target
    }
}

/**
 * 类型适配器
 */
public class TypeAdapter {
    private let mappings: HashMap<String, String>

    public init() {
        this.mappings = HashMap<String, String>()
    }

    public func register(localType: String, remoteType: String): TypeAdapter {
        mappings.add(localType, remoteType)
        this
    }

    public func adaptToRemote(localType: String): String {
        match (mappings.get(localType)) {
            case Some(remoteType) => remoteType
            case None => localType
        }
    }

    public func adaptToLocal(remoteType: String): String {
        for ((local, remote) in mappings) {
            if (remote == remoteType) {
                return local
            }
        }
        remoteType
    }
}

/**
 * 演示基本 ActorSystem 桥接
 */
public func demonstrateBasicBridging(): Unit {
    println("=== 基本 ActorSystem 桥接演示 ===")

    // 创建两个 ActorSystem
    let system1 = ActorSystemConfig("system-1", "localhost", 2551)
    let system2 = ActorSystemConfig("system-2", "localhost", 2552)

    println("ActorSystem 1: ${system1}")
    println("ActorSystem 2: ${system2}")

    // 创建桥接
    println()
    println("创建跨系统通信桥接:")
    println("  ${system1.selfAddress} <-> ${system2.selfAddress}")

    // 模拟消息发送
    let envelope = Envelope("Hello from system-1", "user@system-1")
    println("  发送消息: ${envelope.message}")
    println("  发送者: ${envelope.sender}")
    println()
}

/**
 * 演示地址适配
 */
public func demonstrateAddressAdaptation(): Unit {
    println("=== 地址适配演示 ===")

    // 模拟地址映射
    let mappings = ArrayList<AddressMapping>()
    mappings.add(AddressMapping("local://user/actor1", "remote://cluster/node-1/actor1"))
    mappings.add(AddressMapping("local://user/actor2", "remote://cluster/node-1/actor2"))

    println("地址映射:")
    for (mapping in mappings) {
        println("  ${mapping.source} -> ${mapping.target}")
    }

    // 模拟反向映射
    println()
    println("反向地址映射:")
    for (mapping in mappings) {
        println("  ${mapping.target} -> ${mapping.source}")
    }
    println()
}

/**
 * 演示类型适配
 */
public func demonstrateTypeAdaptation(): Unit {
    println("=== 类型适配演示 ===")

    let adapter = TypeAdapter()
        .register("UserCommand", "com.app.UserCommand")
        .register("OrderEvent", "com.app.OrderEvent")
        .register("PaymentRequest", "com.app.PaymentRequest")

    println("类型映射注册:")
    println("  UserCommand -> com.app.UserCommand")
    println("  OrderEvent -> com.app.OrderEvent")
    println("  PaymentRequest -> com.app.PaymentRequest")
    println()

    // 适配测试
    println("类型适配测试:")
    let localTypes = ArrayList<String>()
    localTypes.add("UserCommand")
    localTypes.add("OrderEvent")
    localTypes.add("PaymentRequest")
    localTypes.add("UnknownType")
    for (localType in localTypes) {
        let remoteType = adapter.adaptToRemote(localType)
        let backToLocal = adapter.adaptToLocal(remoteType)
        println("  ${localType} -> ${remoteType} -> ${backToLocal}")
    }
    println()
}

/**
 * 演示消息转换
 */
public func demonstrateMessageTransformation(): Unit {
    println("=== 消息转换演示 ===")

    // 模拟跨系统消息转换
    let original = Envelope("Order { id: 123, amount: 99.99 }", "order-service")

    println("原始消息:")
    println("  内容: ${original.message}")
    println("  发送者: ${original.sender}")
    println("  时间戳: ${original.timestamp}")
    println()

    // 模拟序列化/反序列化
    println("序列化/反序列化:")
    println("  序列化为字节流...")
    println("  发送到远程系统...")
    println("  接收字节流...")
    println("  反序列化为消息...")

    let bridgeSender = "bridge@${original.sender}"
    let transformed = Envelope(original.message, bridgeSender)
    println()
    println("转换后消息:")
    println("  内容: ${transformed.message}")
    println("  发送者: ${transformed.sender}")
    println()
}

/**
 * 演示混合路由
 */
public func demonstrateHybridRouting(): Unit {
    println("=== 混合路由演示 ===")

    // 模拟路由决策
    let routes = ArrayList<(String, String)>()
    routes.add(("local://user/service-a", "local"))
    routes.add(("local://user/service-b", "local"))
    routes.add(("remote://cluster/node-1/service-c", "remote"))
    routes.add(("remote://cluster/node-2/service-d", "remote"))

    println("路由表:")
    for ((address, kind) in routes) {
        println("  ${address} -> ${kind}")
    }
    println()

    // 模拟路由选择
    println("路由选择:")
    println("  本地消息 'Hello' -> 路由到 local://user/service-a")
    println("  远程消息 'Order' -> 路由到 remote://cluster/node-1/service-c")
    println()
}

/**
 * 演示协议转换
 */
public func demonstrateProtocolTranslation(): Unit {
    println("=== 协议转换演示 ===")

    // 模拟协议转换
    println("支持的消息协议:")
    println("  1. Akka Wire Protocol (二进制)")
    println("  2. JSON over HTTP")
    println("  3. gRPC")
    println()

    println("协议转换器:")
    println("  Wire -> JSON: 将二进制格式转换为 JSON")
    println("  JSON -> Wire: 将 JSON 转换为二进制格式")
    println("  HTTP -> gRPC: 将 HTTP 请求转换为 gRPC 调用")
    println("  gRPC -> HTTP: 将 gRPC 响应转换为 HTTP 响应")
    println()
}

/**
 * 演示系统发现
 */
public func demonstrateSystemDiscovery(): Unit {
    println("=== 系统发现演示 ===")

    // 模拟已发现的 ActorSystem
    let discovered = ArrayList<(String, String, String)>()
    discovered.add(("system-1", "localhost:2551", "up"))
    discovered.add(("system-2", "localhost:2552", "up"))
    discovered.add(("system-3", "192.168.1.10:2551", "down"))

    println("已发现的 ActorSystem:")
    for ((name, address, status) in discovered) {
        println("  ${name}: ${address} [${status}]")
    }
    println()

    // 模拟系统加入
    println("模拟系统加入:")
    println("  system-4 (localhost:2553) 加入集群")
    println("  更新路由表...")
    println("  通知所有连接的 ActorSystem")
    println()
}

/**
 * 演示版本兼容
 */
public func demonstrateVersionCompatibility(): Unit {
    println("=== 版本兼容演示 ===")

    // 模拟版本映射
    let versions = ArrayList<(String, String)>()
    versions.add(("v1.0", "com.app.v1.UserCommand"))
    versions.add(("v1.0", "com.app.v1.OrderEvent"))
    versions.add(("v2.0", "com.app.v2.UserCommand"))
    versions.add(("v2.0", "com.app.v2.OrderEvent"))

    println("版本映射:")
    for ((version, typ) in versions) {
        println("  ${typ} (${version})")
    }
    println()

    println("版本协商:")
    println("  系统 A (v1.0) 尝试与系统 B (v2.0) 通信")
    println("  协商使用 v1.0 兼容模式")
    println("  启用类型适配器进行消息转换")
    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor Coexistence 多系统共存演示")
    println("========================================")
    println()

    demonstrateBasicBridging()
    demonstrateAddressAdaptation()
    demonstrateTypeAdaptation()
    demonstrateMessageTransformation()
    demonstrateHybridRouting()
    demonstrateProtocolTranslation()
    demonstrateSystemDiscovery()
    demonstrateVersionCompatibility()

    println("========================================")
    println("   Coexistence 演示完成!")
    println("========================================")
}
