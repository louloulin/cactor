/*
 * 简单的Core层测试
 */
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
import cactor.core.message.{MessageSerializer, MessageSerializationManager}
import cactor.core.message.{NetworkMessage, NetworkMessageSerializer}

main() {
    println("=== Core层基础测试 ===")
    
    // 测试消息序列化
    println("测试MessageSerializer...")
    let serializer = MessageSerializer()
    
    let stringMsg = StringMessage("Core Test Message")
    let serialized = serializer.serialize(stringMsg)
    let deserialized = serializer.deserialize(serialized)
    
    if (deserialized.messageType() == "StringMessage") {
        println("✅ StringMessage序列化测试通过")
    } else {
        println("❌ StringMessage序列化测试失败")
    }
    
    // 测试PingMessage序列化
    let pingMsg = PingMessage(12345)
    let pingSerialized = serializer.serialize(pingMsg)
    let pingDeserialized = serializer.deserialize(pingSerialized)
    
    if (pingDeserialized.messageType() == "PingMessage") {
        println("✅ PingMessage序列化测试通过")
    } else {
        println("❌ PingMessage序列化测试失败")
    }
    
    // 测试消息序列化管理器
    println("测试MessageSerializationManager...")
    let manager = MessageSerializationManager()
    
    let testMsg = StringMessage("Manager Test")
    let managerSerialized = manager.serialize(testMsg)
    let managerDeserialized = manager.deserialize(managerSerialized)
    
    if (managerDeserialized.messageType() == "StringMessage") {
        println("✅ MessageSerializationManager测试通过")
    } else {
        println("❌ MessageSerializationManager测试失败")
    }
    
    println("序列化器名称: ${manager.getSerializerName()}")
    
    // 测试网络消息
    println("测试NetworkMessage...")
    let networkMsg = NetworkMessage("testActor", stringMsg, Some("senderActor"))
    
    println("目标Actor: ${networkMsg.targetActor}")
    println("消息类型: ${networkMsg.message.messageType()}")
    println("消息ID: ${networkMsg.messageId}")
    println("时间戳: ${networkMsg.timestamp}")
    
    // 测试网络消息序列化
    println("测试NetworkMessageSerializer...")
    let networkSerializer = NetworkMessageSerializer()
    
    let networkSerialized = networkSerializer.serialize(networkMsg)
    let networkDeserialized = networkSerializer.deserialize(networkSerialized)
    
    if (networkDeserialized.targetActor == networkMsg.targetActor) {
        println("✅ NetworkMessage序列化测试通过")
    } else {
        println("❌ NetworkMessage序列化测试失败")
    }
    
    println("=== Core层测试完成 ===")
}
