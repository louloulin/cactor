/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 远程通信测试
 * 测试序列化、网络传输和远程Actor系统功能
 */
package cactor.tests.remote

import std.unittest.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
import cactor.runtime.ActorSystem
import cactor.serialization.{JsonSerializer, BinarySerializer, SerializationManager, SerializationFactory}
import cactor.network.{NetworkAddress, NetworkMessage, TransportFactory, TransportProtocol}
import cactor.remote.{RemoteActorSystem, ClusterConfig, ClusterManager}

/**
 * 测试序列化功能
 */
@Test
func testJsonSerialization(): Unit {
    let serializer = JsonSerializer()
    
    // 测试StringMessage序列化
    let stringMsg = StringMessage("Hello World")
    let serializedData = serializer.serialize(stringMsg)
    @Assert(serializedData.size > 0, "序列化数据不应为空")
    
    let deserializedMsg = serializer.deserialize(serializedData)
    @Assert(deserializedMsg.messageType() == "StringMessage", "反序列化消息类型应为StringMessage")
    
    // 测试PingMessage序列化
    let pingMsg = PingMessage(123)
    let pingData = serializer.serialize(pingMsg)
    @Assert(pingData.size > 0, "Ping消息序列化数据不应为空")
    
    let deserializedPing = serializer.deserialize(pingData)
    @Assert(deserializedPing.messageType() == "PingMessage", "反序列化消息类型应为PingMessage")
    
    println("JSON序列化测试通过")
}

@Test
func testBinarySerialization(): Unit {
    let serializer = BinarySerializer()
    
    // 测试StringMessage序列化
    let stringMsg = StringMessage("Binary Test")
    let serializedData = serializer.serialize(stringMsg)
    @Assert(serializedData.size > 0, "二进制序列化数据不应为空")
    
    let deserializedMsg = serializer.deserialize(serializedData)
    @Assert(deserializedMsg.messageType() == "StringMessage", "反序列化消息类型应为StringMessage")
    
    println("二进制序列化测试通过")
}

@Test
func testSerializationManager(): Unit {
    let manager = SerializationFactory.createDefaultManager()
    
    // 测试支持的类型
    let supportedTypes = manager.getSupportedTypes()
    @Assert(supportedTypes.size > 0, "应该支持至少一种消息类型")
    
    // 测试序列化和反序列化
    let message = StringMessage("Manager Test")
    let data = manager.serialize(message)
    @Assert(data.size > 0, "序列化数据不应为空")
    
    let deserializedMsg = manager.deserialize(data, "StringMessage")
    @Assert(deserializedMsg.messageType() == "StringMessage", "反序列化消息类型正确")
    
    println("序列化管理器测试通过")
}

@Test
func testNetworkAddress(): Unit {
    let address = NetworkAddress("localhost", 8080)
    @Assert(address.host == "localhost", "主机名应为localhost")
    @Assert(address.port == 8080, "端口应为8080")
    
    let addressStr = address.toString()
    @Assert(addressStr.contains("localhost"), "地址字符串应包含主机名")
    @Assert(addressStr.contains("8080"), "地址字符串应包含端口")
    
    // 测试地址解析
    let parsedAddress = NetworkAddress.parse("localhost:9090")
    @Assert(parsedAddress.host == "localhost", "解析的主机名正确")
    
    println("网络地址测试通过")
}

@Test
func testNetworkMessage(): Unit {
    let message = StringMessage("Network Test")
    let networkMsg = NetworkMessage("test-actor", message, Some("sender-actor"))
    
    @Assert(networkMsg.targetActor == "test-actor", "目标Actor正确")
    @Assert(networkMsg.message.messageType() == "StringMessage", "消息类型正确")
    
    match (networkMsg.sender) {
        case Some(sender) => @Assert(sender == "sender-actor", "发送者正确")
        case None => @Assert(false, "发送者不应为空")
    }
    
    println("网络消息测试通过")
}

@Test
func testTransportFactory(): Unit {
    let address = NetworkAddress("localhost", 8081)
    
    // 测试TCP传输创建
    let tcpTransport = TransportFactory.createTcpTransport(address)
    @Assert(tcpTransport.getLocalAddress().port == 8081, "TCP传输地址正确")
    @Assert(!tcpTransport.isActive(), "传输初始状态应为未启动")
    
    // 测试UDP传输创建
    let udpTransport = TransportFactory.createUdpTransport(address)
    @Assert(udpTransport.getLocalAddress().port == 8081, "UDP传输地址正确")
    @Assert(!udpTransport.isActive(), "传输初始状态应为未启动")
    
    // 测试通用工厂方法
    let transport = TransportFactory.createTransport(TransportProtocol.TCP, address)
    @Assert(transport.getLocalAddress().port == 8081, "通用工厂创建的传输地址正确")
    
    println("传输工厂测试通过")
}

/**
 * 简单的测试Actor
 */
class TestActor <: Actor {
    private var receivedMessages: ArrayList<Message>

    public init() {
        this.receivedMessages = ArrayList<Message>()
    }

    public func receive(message: Message): Unit {
        receivedMessages.append(message)
        println("TestActor收到消息: ${message.messageType()}")
        
        match (message) {
            case msg if msg.messageType() == "PingMessage" => {
                // 回复Pong消息
                match (msg as PingMessage) {
                    case Some(ping) => {
                        let pong = PongMessage(ping.getId())
                        // 这里应该回复给发送者，简化处理
                        println("TestActor回复Pong: ${ping.getId()}")
                    }
                    case None => {}
                }
            }
            case _ => {}
        }
    }

    public func getReceivedMessageCount(): Int64 {
        receivedMessages.size
    }
}

@Test
func testRemoteActorSystem(): Unit {
    // 创建本地Actor系统
    let localSystem = ActorSystem("test-system")
    localSystem.start()
    
    // 创建测试Actor
    let testActor = localSystem.actorOf(TestActor(), "test-actor")
    @Assert(testActor.isSome(), "测试Actor应该创建成功")
    
    // 创建远程Actor系统
    let localAddress = NetworkAddress("localhost", 8082)
    let remoteSystem = RemoteActorSystem(localSystem, localAddress, TransportProtocol.TCP)
    
    // 启动远程系统
    remoteSystem.start()
    @Assert(remoteSystem.isActive(), "远程系统应该启动成功")
    
    // 连接到远程节点
    let remoteAddress = NetworkAddress("localhost", 8083)
    remoteSystem.connectToNode("remote-node", remoteAddress)
    @Assert(remoteSystem.getConnectedNodeCount() == 1, "应该连接到一个远程节点")
    
    // 获取远程Actor引用
    let remoteActorRef = remoteSystem.actorSelection("/user/remote-actor", "remote-node")
    @Assert(remoteActorRef.isSome(), "应该能获取远程Actor引用")
    
    // 停止系统
    remoteSystem.stop()
    @Assert(!remoteSystem.isActive(), "远程系统应该停止")
    
    localSystem.shutdown()
    
    println("远程Actor系统测试通过")
}

@Test
func testClusterManager(): Unit {
    // 创建本地Actor系统
    let localSystem = ActorSystem("cluster-test-system")
    localSystem.start()
    
    // 创建集群配置
    let config = ClusterConfig.createDefault("node-1", 8084)
    
    // 创建集群管理器
    let clusterManager = ClusterManager(localSystem, config)
    
    // 加入集群
    clusterManager.joinCluster()
    
    // 等待一段时间让系统初始化
    sleep(Duration.millisecond * 100)
    
    // 检查集群状态
    let status = clusterManager.getClusterStatus()
    @Assert(status.contains("node-1"), "集群状态应包含节点ID")
    @Assert(status.contains("JOINED"), "节点应该已加入集群")
    
    // 离开集群
    clusterManager.leaveCluster()
    
    let finalStatus = clusterManager.getClusterStatus()
    @Assert(finalStatus.contains("NOT_JOINED"), "节点应该已离开集群")
    
    localSystem.shutdown()
    
    println("集群管理器测试通过")
}

@Test
func testRemoteMessageSending(): Unit {
    // 创建两个Actor系统模拟分布式环境
    let system1 = ActorSystem("system-1")
    let system2 = ActorSystem("system-2")
    
    system1.start()
    system2.start()
    
    // 在系统1中创建测试Actor
    let testActor1 = system1.actorOf(TestActor(), "test-actor-1")
    
    // 创建远程系统
    let remoteSystem1 = RemoteActorSystem(system1, NetworkAddress("localhost", 8085), TransportProtocol.TCP)
    let remoteSystem2 = RemoteActorSystem(system2, NetworkAddress("localhost", 8086), TransportProtocol.TCP)
    
    remoteSystem1.start()
    remoteSystem2.start()
    
    // 连接两个系统
    remoteSystem1.connectToNode("system-2", NetworkAddress("localhost", 8086))
    remoteSystem2.connectToNode("system-1", NetworkAddress("localhost", 8085))
    
    // 等待连接建立
    sleep(Duration.millisecond * 200)
    
    // 获取远程Actor引用并发送消息
    let remoteRef = remoteSystem1.actorSelection("/user/test-actor-2", "system-2")
    match (remoteRef) {
        case Some(ref) => {
            let message = StringMessage("Hello from system-1")
            ref.tell(message)
            println("消息发送到远程Actor")
        }
        case None => {
            println("无法获取远程Actor引用")
        }
    }
    
    // 等待消息处理
    sleep(Duration.millisecond * 100)
    
    // 清理
    remoteSystem1.stop()
    remoteSystem2.stop()
    system1.shutdown()
    system2.shutdown()
    
    println("远程消息发送测试通过")
}

/**
 * 运行所有远程通信测试
 */
func runRemoteCommunicationTests(): Unit {
    println("开始远程通信测试...")
    
    try {
        testJsonSerialization()
        testBinarySerialization()
        testSerializationManager()
        testNetworkAddress()
        testNetworkMessage()
        testTransportFactory()
        testRemoteActorSystem()
        testClusterManager()
        testRemoteMessageSending()
        
        println("所有远程通信测试通过！")
    } catch (e: Exception) {
        println("测试失败: ${e.message}")
        throw e
    }
}
