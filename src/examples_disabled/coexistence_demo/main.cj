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
public class ActorSystemConfig {
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
    public let message: Any
    public let sender: String
    public let timestamp: Int64

    public init(message: Any, sender: String) {
        this.message = message
        this.sender = sender
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 地址适配器
 */
public class AddressAdapter {
    public let localPrefix: String
    public let remotePrefix: String

    public init(localPrefix: String, remotePrefix: String) {
        this.localPrefix = localPrefix
        this.remotePrefix = remotePrefix
    }

    public func adaptLocalToRemote(address: String): String {
        if (address.startsWith(localPrefix)) {
            let path = address.substring(localPrefix.size)
            "${remotePrefix}${path}"
        } else {
            address
        }
    }

    public func adaptRemoteToLocal(address: String): String {
        if (address.startsWith(remotePrefix)) {
            let path = address.substring(remotePrefix.size)
            "${localPrefix}${path}"
        } else {
            address
        }
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

    let adapter = AddressAdapter("local://", "remote://cluster/")

    // 本地地址转远程地址
    let localAddr = "local://user/actor1"
    let remoteAddr = adapter.adaptLocalToRemote(localAddr)
    println("本地地址: ${localAddr}")
    println("远程地址: ${remoteAddr}")

    // 远程地址转本地地址
    let backToLocal = adapter.adaptRemoteToLocal(remoteAddr)
    println("还原后: ${backToLocal}")
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
    let localTypes = ["UserCommand", "OrderEvent", "PaymentRequest", "UnknownType"]
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

    let transformed = Envelope(original.message, "bridge@" ++ original.sender)
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
    let routes = [
        ("local://user/service-a", "local"),
        ("local://user/service-b", "local"),
        ("remote://cluster/node-1/service-c", "remote"),
        ("remote://cluster/node-2/service-d", "remote")
    ]

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
    let discovered = [
        ("system-1", "localhost:2551", "up"),
        ("system-2", "localhost:2552", "up"),
        ("system-3", "192.168.1.10:2551", "down")
    ]

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
    let versions = [
        ("v1.0", "com.app.v1.UserCommand"),
        ("v1.0", "com.app.v1.OrderEvent"),
        ("v2.0", "com.app.v2.UserCommand"),
        ("v2.0", "com.app.v2.OrderEvent")
    ]

    println("版本映射:")
    for ((version, type) in versions) {
        println("  ${type} (${version})")
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
main(): Unit {
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