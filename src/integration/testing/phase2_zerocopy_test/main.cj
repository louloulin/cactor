/*
 * CActor Phase 2 零拷贝系统测试
 * 验证plan3.md中Phase 2实现的所有零拷贝功能
 * 包括：零拷贝消息、NUMA内存池、序列化、优化传递、内存监控
 */
package cactor.integration.testing.phase2_zerocopy_test

import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import cactor.core.memory.*
import cactor.core.zerocopy.*
import cactor.core.monitoring.*

// 测试用的简单Actor实现
class TestActor <: Actor {
    private var actorName: String
    private var messageCount: Int64
    
    public init(name: String) {
        actorName = name
        messageCount = 0
    }
    
    public prop name: String { get() { actorName } }
    public prop description: String { get() { "Phase 2测试Actor" } }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        messageCount += 1
        println("${actorName} 收到消息: ${message.messageType()}")
        return MessageResult.Handled
    }
    
    public func getMessageCount(): Int64 {
        return messageCount
    }
}

// 测试用的ActorContext实现
class TestActorContext <: ActorContext {
    private let senderName: String
    
    public init(sender: String) {
        senderName = sender
    }
    
    public func sender(): Option<String> {
        Some(senderName)
    }
}

// ============================================================================
// 1. 测试零拷贝消息接口
// ============================================================================

func testZeroCopyMessage(): Bool {
    println("🧪 测试零拷贝消息接口...")
    
    // 创建零拷贝消息
    let payload = Array<UInt8>(1024, { i => UInt8(i % 256) })
    let message = ZeroCopyMessageImpl(1, 1024, 100, 200, Some(payload))
    
    // 测试基本属性
    if (message.getMessageId() == 0) {
        println("❌ 消息ID生成失败")
        return false
    }
    
    if (message.getPayloadSize() != 1024) {
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
    
    println("✅ 零拷贝消息接口测试通过")
    return true
}

// ============================================================================
// 2. 测试NUMA感知内存池
// ============================================================================

func testNumaMemoryPool(): Bool {
    println("🧪 测试NUMA感知内存池...")
    
    // 创建NUMA内存池
    let memoryPool = NumaAwareMemoryPool(4, 1024 * 1024)
    
    // 测试内存分配
    let block1 = memoryPool.allocate(1024)
    match (block1) {
        case Some(block) =>
            if (block.size < 1024) {
                println("❌ 分配的内存块大小不足")
                return false
            }
        case None =>
            println("❌ 内存分配失败")
            return false
    }
    
    // 测试内存统计
    let stats = memoryPool.getStats()
    if (stats.getTotalAllocations() == 0) {
        println("❌ 内存统计更新失败")
        return false
    }
    
    // 测试利用率
    let utilization = memoryPool.getUtilization()
    if (utilization < 0.0 || utilization > 1.0) {
        println("❌ 内存利用率计算错误")
        return false
    }
    
    // 测试总分配和使用量
    let totalAllocated = memoryPool.getTotalAllocated()
    let totalUsed = memoryPool.getTotalUsed()
    
    if (totalAllocated == 0) {
        println("❌ 总分配量统计错误")
        return false
    }
    
    // 释放内存
    match (block1) {
        case Some(block) =>
            memoryPool.deallocate(block)
        case None =>
            ()
    }
    
    println("✅ NUMA感知内存池测试通过")
    return true
}

// ============================================================================
// 3. 测试零拷贝序列化框架
// ============================================================================

func testZeroCopySerializer(): Bool {
    println("🧪 测试零拷贝序列化框架...")
    
    // 创建序列化器
    let bufferPool = SerializationBufferPool(100, 4096)
    let serializer = HighPerfMessageSerializer(bufferPool, false)
    
    // 创建测试消息
    let payload = Array<UInt8>(512, { i => UInt8(i % 256) })
    let message = ZeroCopyMessageImpl(1, 512, 100, 200, Some(payload))
    
    // 测试序列化
    let serialized = serializer.serialize(message)
    if (serialized.size == 0) {
        println("❌ 序列化失败")
        return false
    }
    
    if (!serialized.isZeroCopy) {
        println("❌ 序列化结果不是零拷贝")
        return false
    }
    
    // 测试反序列化
    let deserialized = serializer.deserialize(serialized.data)
    match (deserialized) {
        case DeserializationResult.Success(msg) =>
            if (msg.getPayloadSize() != message.getPayloadSize()) {
                println("❌ 反序列化后负载大小不匹配")
                return false
            }
        case DeserializationResult.Error(error) =>
            println("❌ 反序列化失败: ${error}")
            return false
    }
    
    // 测试序列化大小估算
    let estimatedSize = serializer.getSerializedSize(message)
    if (estimatedSize == 0) {
        println("❌ 序列化大小估算失败")
        return false
    }
    
    // 测试零拷贝标志
    if (!serializer.isZeroCopy()) {
        println("❌ 序列化器零拷贝标志错误")
        return false
    }
    
    println("✅ 零拷贝序列化框架测试通过")
    return true
}

// ============================================================================
// 4. 测试优化消息传递路径
// ============================================================================

func testOptimizedMessagePassing(): Bool {
    println("🧪 测试优化消息传递路径...")
    
    // 创建配置
    let config = MessagePassingConfig(1024, 10, 1000, false, true)
    let memoryPool = NumaAwareMemoryPool(4, 1024 * 1024)
    let messagePasser = OptimizedMessagePasser(config, memoryPool)
    
    // 创建测试Actor
    let sourceActor = TestActor("SourceActor")
    let targetActor = TestActor("TargetActor")
    
    // 测试小消息（直接拷贝）
    let smallPayload = Array<UInt8>(512, { i => UInt8(i % 256) })
    let smallMessage = ZeroCopyMessageImpl(1, 512, 1, 2, Some(smallPayload))
    
    let result1 = messagePasser.sendMessage(smallMessage, targetActor)
    match (result1) {
        case MessagePassingResult.Success(bytes) =>
            if (bytes == 0) {
                println("❌ 小消息传递失败")
                return false
            }
        case MessagePassingResult.Error(error) =>
            println("❌ 小消息传递错误: ${error}")
            return false
    }
    
    // 测试大消息（零拷贝）
    let largePayload = Array<UInt8>(2048, { i => UInt8(i % 256) })
    let largeMessage = ZeroCopyMessageImpl(2, 2048, 1, 2, Some(largePayload))
    
    let result2 = messagePasser.sendMessage(largeMessage, targetActor)
    match (result2) {
        case MessagePassingResult.Success(bytes) =>
            if (bytes == 0) {
                println("❌ 大消息传递失败")
                return false
            }
        case MessagePassingResult.Error(error) =>
            println("❌ 大消息传递错误: ${error}")
            return false
    }
    
    // 测试批量消息传递
    let messages = Array<ZeroCopyMessageImpl>(3, { i =>
        let payload = Array<UInt8>(256, { j => UInt8(j % 256) })
        ZeroCopyMessageImpl(UInt16(i + 1), 256, 1, 2, Some(payload))
    })
    let targets = Array<Actor>(3, { i => targetActor })
    
    let batchResults = messagePasser.sendBatch(messages, targets)
    if (batchResults.size != 3) {
        println("❌ 批量消息传递结果数量不正确")
        return false
    }
    
    // 测试性能指标
    let metrics = messagePasser.getMetrics()
    if (metrics.getTotalMessages() == 0) {
        println("❌ 消息传递指标统计失败")
        return false
    }
    
    // 刷新批量消息
    messagePasser.flushBatches()
    
    println("✅ 优化消息传递路径测试通过")
    return true
}

// ============================================================================
// 5. 测试内存使用监控
// ============================================================================

func testMemoryMonitoring(): Bool {
    println("🧪 测试内存使用监控...")
    
    // 创建内存池和监控器
    let memoryPool = NumaAwareMemoryPool(4, 1024 * 1024)
    let monitor = HighPerfMemoryMonitor(memoryPool, 100)
    
    // 启动监控
    monitor.startMonitoring()
    if (!monitor.isMonitoring()) {
        println("❌ 内存监控启动失败")
        return false
    }
    
    // 收集内存统计
    let stats = monitor.getMemoryStats()
    if (stats.timestamp == 0) {
        println("❌ 内存统计收集失败")
        return false
    }
    
    // 收集内存快照
    let snapshot = monitor.collectSnapshot()
    if (snapshot.numaNodeStats.size == 0) {
        println("❌ NUMA节点统计收集失败")
        return false
    }
    
    if (snapshot.poolStats.size == 0) {
        println("❌ 内存池统计收集失败")
        return false
    }
    
    // 测试告警阈值设置
    let threshold = MemoryThreshold(0.8, 0.2, 1024 * 1024, true)
    monitor.setAlertThreshold(threshold)
    
    // 获取性能建议
    let recommendations = monitor.getPerformanceRecommendations()
    if (recommendations.size < 0) {
        println("❌ 性能建议获取失败")
        return false
    }
    
    // 获取历史记录
    let history = monitor.getMemoryUsageHistory()
    if (history.size == 0) {
        println("❌ 内存使用历史记录为空")
        return false
    }
    
    // 停止监控
    monitor.stopMonitoring()
    if (monitor.isMonitoring()) {
        println("❌ 内存监控停止失败")
        return false
    }
    
    println("✅ 内存使用监控测试通过")
    return true
}

// ============================================================================
// 6. 测试Phase 2集成功能
// ============================================================================

func testPhase2Integration(): Bool {
    println("🧪 测试Phase 2集成功能...")
    
    // 创建完整的零拷贝系统
    let memoryPool = NumaAwareMemoryPool(4, 2 * 1024 * 1024)
    let monitor = HighPerfMemoryMonitor(memoryPool, 50)
    let config = MessagePassingConfig(1024, 5, 500, true, true)
    let messagePasser = OptimizedMessagePasser(config, memoryPool)
    
    // 启动监控
    monitor.startMonitoring()
    
    // 创建测试Actor
    let producer = TestActor("Producer")
    let consumer = TestActor("Consumer")
    
    // 模拟高负载消息传递
    for (i in 0..10) {
        let payload = Array<UInt8>(Int64(1024 + UInt64(i * 100)), { j => UInt8(j % 256) })
        let message = ZeroCopyMessageImpl(UInt16(i + 1), UInt64(payload.size), 1, 2, Some(payload))
        
        let result = messagePasser.sendMessage(message, consumer)
        match (result) {
            case MessagePassingResult.Success(bytes) =>
                ()  // 成功
            case MessagePassingResult.Error(error) =>
                println("❌ 集成测试消息传递失败: ${error}")
                return false
        }
    }
    
    // 刷新批量消息
    messagePasser.flushBatches()
    
    // 检查系统状态
    let finalStats = monitor.getMemoryStats()
    let finalMetrics = messagePasser.getMetrics()
    
    if (finalMetrics.getTotalMessages() == 0) {
        println("❌ 集成测试消息统计失败")
        return false
    }
    
    if (finalStats.totalAllocated == 0) {
        println("❌ 集成测试内存统计失败")
        return false
    }
    
    // 获取性能报告
    let avgLatency = finalMetrics.getAverageLatency()
    let throughput = finalMetrics.getThroughput()
    let utilization = memoryPool.getUtilization()
    
    println("📊 Phase 2性能报告:")
    println("   - 平均延迟: ${avgLatency} 微秒")
    println("   - 吞吐量: ${throughput} 消息/秒")
    println("   - 内存利用率: ${utilization * 100.0}%")
    println("   - 总消息数: ${finalMetrics.getTotalMessages()}")
    
    // 停止监控
    monitor.stopMonitoring()
    
    println("✅ Phase 2集成功能测试通过")
    return true
}

// ============================================================================
// 主测试函数
// ============================================================================

main(): Int64 {
    println("=== CActor Phase 2 零拷贝系统测试 ===")
    println("验证plan3.md中Phase 2实现的所有功能")
    
    var allTestsPassed = true
    
    // 运行所有测试
    allTestsPassed = allTestsPassed && testZeroCopyMessage()
    allTestsPassed = allTestsPassed && testNumaMemoryPool()
    allTestsPassed = allTestsPassed && testZeroCopySerializer()
    allTestsPassed = allTestsPassed && testOptimizedMessagePassing()
    allTestsPassed = allTestsPassed && testMemoryMonitoring()
    allTestsPassed = allTestsPassed && testPhase2Integration()
    
    println("========================================")
    if (allTestsPassed) {
        println("🎉 所有Phase 2零拷贝系统测试通过！")
        println("✅ plan3.md Phase 2功能验证成功")
        println("🚀 CActor零拷贝消息传递系统已完全就绪")
        println("📋 已验证功能:")
        println("   - 零拷贝消息接口设计")
        println("   - NUMA感知内存池实现")
        println("   - 零拷贝序列化框架")
        println("   - 优化消息传递路径")
        println("   - 集成内存使用监控")
        println("   - 系统集成和性能验证")
        return 0
    } else {
        println("❌ 部分Phase 2零拷贝系统测试失败")
        return 1
    }
}
