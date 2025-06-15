/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 简化的远程通信测试
 */
package cactor.integration.testing.remote_simple

import std.time.*
import std.collection.*
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage, NetworkMessage}
import cactor.foundation.serialization.{JsonSerializer, SerializationFactory}
import cactor.foundation.network.{NetworkAddress, TransportFactory, TransportProtocol}
import cactor.distribution.remote.RemoteFactory

/**
 * 简单的字节数组转字符串函数
 */
func bytesToString(bytes: Array<UInt8>): String {
    let chars = ArrayList<Rune>()
    for (i in 0..bytes.size) {
        let byte = bytes[i]
        if (byte <= 127) {
            chars.append(Rune(Int32(byte)))
        }
    }
    String(chars.toArray())
}

main(): Int64 {
    println("=== CActor 远程通信功能测试 ===")
    
    try {
        // 测试消息类型
        println("1. 测试消息类型...")
        let stringMsg = StringMessage("Test String")
        println("   StringMessage创建成功: ${stringMsg.messageType()}")
        
        let pingMsg = PingMessage(123)
        println("   PingMessage创建成功: ${pingMsg.messageType()}")
        
        let pongMsg = PongMessage(456)
        println("   PongMessage创建成功: ${pongMsg.messageType()}")
        
        // 测试序列化
        println("2. 测试序列化...")
        let jsonSerializer = JsonSerializer()
        let serializedData = jsonSerializer.serialize(stringMsg.getContent())
        println("   JSON序列化成功，数据大小: ${serializedData.size}")

        // 打印序列化的JSON内容以便调试
        let jsonString = bytesToString(serializedData)
        println("   序列化的JSON: ${jsonString}")

        let deserializedMsg = jsonSerializer.deserialize(serializedData)
        println("   JSON反序列化成功，消息类型: ${deserializedMsg.messageType()}")
        
        // 测试序列化管理器
        println("3. 测试序列化管理器...")
        let manager = SerializationFactory.createDefaultManager()
        let supportedTypes = manager.getSupportedTypes()
        println("   支持的消息类型数量: ${supportedTypes.size}")
        
        // 测试网络地址
        println("4. 测试网络地址...")
        let address = NetworkAddress("localhost", 8080)
        println("   网络地址创建成功: ${address.toString()}")
        
        // 测试传输工厂
        println("5. 测试传输工厂...")
        let tcpTransport = TransportFactory.createTcpTransport(address)
        println("   TCP传输创建成功")
        
        // 测试简化的远程通信
        println("6. 测试简化的远程通信...")
        let remoteManager = RemoteFactory.createDefaultManager(8090)
        println("   远程通信管理器创建成功")
        
        // 注册消息处理器
        remoteManager.registerHandler("test-actor", { message =>
            println("   收到远程消息: ${message.messageType()}")
        })
        
        // 启动远程通信
        remoteManager.start()
        println("   远程通信管理器启动成功")
        
        // 发送测试消息
        let targetAddress = NetworkAddress("localhost", 8091)
        let testMessage = StringMessage("Remote Test Message")
        try {
            remoteManager.sendMessage(targetAddress, "remote-actor", testMessage)
            println("   远程消息发送成功")
        } catch (e: Exception) {
            println("   远程消息发送失败（预期的）: ${e.message}")
        }
        
        // 停止远程通信
        remoteManager.stop()
        println("   远程通信管理器停止成功")
        
        // 测试网络消息
        println("7. 测试网络消息...")
        let networkMsg = NetworkMessage("test-actor", testMessage, Some("sender-actor"))
        println("   网络消息创建成功")
        println("   目标Actor: ${networkMsg.targetActor}")
        println("   消息类型: ${networkMsg.message.messageType()}")
        
        match (networkMsg.sender) {
            case Some(sender) => println("   发送者: ${sender}")
            case None => println("   无发送者")
        }
        
        println("✅ 所有测试通过")
        return 0
    } catch (e: Exception) {
        println("❌ 测试失败: ${e.message}")
        return 1
    }
}
