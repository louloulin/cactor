/*
 * CActor 简单零拷贝测试
 * 验证基础的零拷贝消息功能
 */
package cactor.tests.simple_zerocopy_test

import cactor.core.zerocopy.*

// 简单的零拷贝消息测试
func testBasicZeroCopyMessage(): Bool {
    println("🧪 测试基础零拷贝消息...")
    
    // 创建测试负载
    let payload = Array<UInt8>(512, { i => UInt8(i % 256) })
    
    // 创建零拷贝消息
    let message = ZeroCopyMessageImpl(1, 512, 100, 200, Some(payload))
    
    // 测试基本属性
    if (message.getMessageId() == 0) {
        println("❌ 消息ID生成失败")
        return false
    }
    
    if (message.getPayloadSize() != 512) {
        println("❌ 负载大小不正确")
        return false
    }
    
    if (message.getSourceActor() != 100) {
        println("❌ 源Actor ID不正确")
        return false
    }
    
    if (message.getTargetActor() != 200) {
        println("❌ 目标Actor ID不正确")
        return false
    }
    
    // 测试引用计数
    let initialRefCount = message.getReferenceCount()
    message.retain()
    if (message.getReferenceCount() != initialRefCount + 1) {
        println("❌ 引用计数增加失败")
        return false
    }
    
    message.release()
    if (message.getReferenceCount() != initialRefCount) {
        println("❌ 引用计数减少失败")
        return false
    }
    
    // 测试有效性
    if (!message.isValid()) {
        println("❌ 消息有效性检查失败")
        return false
    }
    
    // 测试校验和
    let checksum = message.getChecksum()
    if (checksum == 0) {
        println("❌ 校验和计算失败")
        return false
    }
    
    println("✅ 基础零拷贝消息测试通过")
    return true
}

// 测试消息工厂
func testMessageFactory(): Bool {
    println("🧪 测试消息工厂...")
    
    let factory = ZeroCopyMessageFactory()
    
    // 创建空消息
    let emptyMessage = factory.createEmptyMessage(1, 0, 1, 2)
    if (emptyMessage.getPayloadSize() != 0) {
        println("❌ 空消息创建失败")
        return false
    }
    
    // 创建带负载的消息
    let payload = Array<UInt8>(256, { i => UInt8(i % 256) })
    let messageWithPayload = factory.createMessageWithPayload(2, 256, 1, 2, payload)
    if (messageWithPayload.getPayloadSize() != 256) {
        println("❌ 带负载消息创建失败")
        return false
    }
    
    println("✅ 消息工厂测试通过")
    return true
}

// 测试消息池
func testMessagePool(): Bool {
    println("🧪 测试消息池...")
    
    let pool = MessagePool(10)
    
    // 从池中获取消息
    let message1 = pool.acquire(1, 512, 1, 2)
    if (message1.getPayloadSize() != 512) {
        println("❌ 从池获取消息失败")
        return false
    }
    
    // 释放消息到池
    pool.release(message1)
    
    // 检查池大小
    let poolSize = pool.getPoolSize()
    if (poolSize < 0) {
        println("❌ 池大小检查失败")
        return false
    }
    
    println("✅ 消息池测试通过")
    return true
}

// 测试CRC32校验和
func testCRC32(): Bool {
    println("🧪 测试CRC32校验和...")
    
    let crc32 = CRC32()
    crc32.update(100)
    
    let checksum = crc32.getValue()
    if (checksum == 0) {
        println("❌ CRC32校验和计算失败")
        return false
    }
    
    println("✅ CRC32校验和测试通过")
    return true
}

// 测试消息构建器
func testMessageBuilder(): Bool {
    println("🧪 测试消息构建器...")
    
    let builder = ZeroCopyMessageBuilder()
    let message = builder
        .withMessageType(1)
        .withSource(100)
        .withTarget(200)
        .withPayloadSize(1024)
        .build()
    
    if (message.getSourceActor() != 100) {
        println("❌ 构建器设置源Actor失败")
        return false
    }
    
    if (message.getTargetActor() != 200) {
        println("❌ 构建器设置目标Actor失败")
        return false
    }
    
    if (message.getPayloadSize() != 1024) {
        println("❌ 构建器设置负载大小失败")
        return false
    }
    
    println("✅ 消息构建器测试通过")
    return true
}

// 主测试函数
main(): Int64 {
    println("=== CActor 简单零拷贝消息测试 ===")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testBasicZeroCopyMessage()
    allTestsPassed = allTestsPassed && testMessageFactory()
    allTestsPassed = allTestsPassed && testMessagePool()
    allTestsPassed = allTestsPassed && testCRC32()
    allTestsPassed = allTestsPassed && testMessageBuilder()
    
    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有简单零拷贝消息测试通过！")
        println("✅ 基础零拷贝消息功能验证成功")
        println("📋 已验证功能:")
        println("   - 零拷贝消息创建和属性访问")
        println("   - 引用计数管理")
        println("   - 消息有效性检查")
        println("   - CRC32校验和计算")
        println("   - 消息工厂模式")
        println("   - 消息池管理")
        println("   - 消息构建器模式")
        return 0
    } else {
        println("❌ 部分简单零拷贝消息测试失败")
        return 1
    }
}
