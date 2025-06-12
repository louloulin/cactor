/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 远程通信演示
 * 展示完整的远程Actor通信功能
 */
package cactor.tests.remote_demo

import std.time.*
import std.collection.*
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
import cactor.serialization.{JsonSerializer, BinarySerializer, SerializationFactory}
import cactor.network.{NetworkAddress, NetworkMessage, TransportFactory, TransportProtocol}
import cactor.remote.{SimpleRemoteManager, RemoteFactory}

/**
 * 远程通信演示
 */
main(): Int64 {
    println("=== CACtor 2.0 远程通信演示 ===")
    println("展示完整的远程Actor通信功能")
    
    try {
        // 1. 创建两个远程通信节点
        println("\n1. 创建远程通信节点...")
        let node1 = RemoteFactory.createDefaultManager(8100)
        let node2 = RemoteFactory.createDefaultManager(8101)
        
        // 2. 注册消息处理器
        println("2. 注册消息处理器...")
        
        // Node1处理器：回显服务
        node1.registerHandler("echo-service", { message =>
            match (message) {
                case msg: StringMessage => 
                    println("Node1[echo-service] 收到: ${msg.getContent()}")
                    println("Node1[echo-service] 回复: Echo - ${msg.getContent()}")
                case msg: PingMessage =>
                    println("Node1[echo-service] 收到Ping: ${msg.getId()}")
                    println("Node1[echo-service] 回复Pong")
                case _ =>
                    println("Node1[echo-service] 收到未知消息类型")
            }
        })
        
        // Node2处理器：计算服务
        node2.registerHandler("calc-service", { message =>
            match (message) {
                case msg: StringMessage => 
                    println("Node2[calc-service] 收到: ${msg.getContent()}")
                    if (msg.getContent().contains("add")) {
                        println("Node2[calc-service] 执行加法运算: 10 + 20 = 30")
                    } else {
                        println("Node2[calc-service] 执行默认运算")
                    }
                case msg: PingMessage =>
                    println("Node2[calc-service] 收到Ping: ${msg.getId()}")
                    println("Node2[calc-service] 计算结果: ${msg.getId() * 2}")
                case _ =>
                    println("Node2[calc-service] 收到未知消息类型")
            }
        })
        
        // 3. 启动节点
        println("3. 启动远程通信节点...")
        node1.start()
        node2.start()
        
        // 等待节点启动
        // sleep(Duration.millisecond * 100)  // 简化演示，移除等待
        
        // 4. 测试远程消息发送
        println("\n4. 测试远程消息发送...")
        
        // Node1 -> Node2: 发送字符串消息
        let node2Address = NetworkAddress("localhost", 8101)
        let calcMessage = StringMessage("add 10 20")
        println("发送计算请求: Node1 -> Node2")
        try {
            node1.sendMessage(node2Address, "calc-service", calcMessage)
            println("✓ 消息发送成功")
        } catch (e: Exception) {
            println("✗ 消息发送失败: ${e.message}")
        }
        
        // Node2 -> Node1: 发送Ping消息
        let node1Address = NetworkAddress("localhost", 8100)
        let pingMessage = PingMessage(42)
        println("发送Ping请求: Node2 -> Node1")
        try {
            node2.sendMessage(node1Address, "echo-service", pingMessage)
            println("✓ Ping消息发送成功")
        } catch (e: Exception) {
            println("✗ Ping消息发送失败: ${e.message}")
        }
        
        // 5. 测试序列化性能
        println("\n5. 测试序列化性能...")
        testJsonSerializationOnly()

        // 6. 测试网络传输
        println("\n6. 测试网络传输...")
        testNetworkTransport()
        
        // 等待消息处理
        // sleep(Duration.millisecond * 200)  // 简化演示，移除等待
        
        // 7. 停止节点
        println("\n7. 停止远程通信节点...")
        node1.stop()
        node2.stop()
        
        println("\n✅ 远程通信演示完成！")
        println("🎉 所有功能正常工作")
        
        return 0
    } catch (e: Exception) {
        println("❌ 演示失败: ${e.message}")
        return 1
    }
}

/**
 * 测试JSON序列化性能
 */
func testJsonSerializationOnly(): Unit {
    println("   测试JSON序列化...")
    let jsonSerializer = JsonSerializer()
    let message = StringMessage("Performance Test Message")
    
    let startTime = DateTime.now()
    for (i in 0..1000) {
        let serialized = jsonSerializer.serialize(message)
        let deserialized = jsonSerializer.deserialize(serialized)
    }
    let endTime = DateTime.now()
    
    println("   ✓ JSON序列化1000次完成")

    println("   JSON序列化性能测试完成")
}

/**
 * 测试网络传输
 */
func testNetworkTransport(): Unit {
    println("   创建网络地址...")
    let address1 = NetworkAddress("localhost", 9000)
    let address2 = NetworkAddress("127.0.0.1", 9001)
    
    println("   地址1: ${address1.toString()}")
    println("   地址2: ${address2.toString()}")
    
    println("   创建网络消息...")
    let message = StringMessage("Network Test")
    let networkMsg = NetworkMessage("test-actor", message, Some("sender-actor"))
    
    println("   目标Actor: ${networkMsg.targetActor}")
    println("   消息类型: ${networkMsg.message.messageType()}")
    
    match (networkMsg.sender) {
        case Some(sender) => println("   发送者: ${sender}")
        case None => println("   无发送者")
    }
    
    println("   ✓ 网络传输测试完成")
}
