#!/bin/bash
# benchmark_cactor.sh - CActor 7.0 性能基准测试

echo "=== CActor 7.0 性能基准测试 ==="

# 创建基准测试结果目录
mkdir -p benchmark_results
timestamp=$(date +%Y%m%d_%H%M%S)
result_file="benchmark_results/cactor_benchmark_${timestamp}.log"

echo "测试时间: $(date)" > $result_file
echo "系统信息:" >> $result_file
uname -a >> $result_file
echo "" >> $result_file

# 1. Foundation层性能基准
echo "🔧 Foundation层性能基准测试..." | tee -a $result_file

echo "1.1 LockFreeQueue性能测试" | tee -a $result_file
cat > benchmark_lockfree_queue.cj << 'EOF'
import cactor.foundation.queue.LockFreeQueue
import std.time.*

main() {
    let queue = LockFreeQueue<String>(1024)
    let iterations = 100000
    
    // 入队性能测试
    let startTime = DateTime.now()
    for (i in 0..iterations) {
        queue.enqueue("benchmark_${i}")
    }
    let enqueueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                     startTime.toUnixTimeStamp().toMilliseconds()
    
    // 出队性能测试
    let dequeueStart = DateTime.now()
    var dequeueCount = 0
    while (!queue.isEmpty()) {
        match (queue.dequeue()) {
            case Some(_) => dequeueCount += 1
            case None => break
        }
    }
    let dequeueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                     dequeueStart.toUnixTimeStamp().toMilliseconds()
    
    let totalTime = enqueueTime + dequeueTime
    let throughput = if (totalTime > 0) { (iterations * 2 * 1000) / totalTime } else { 0 }
    
    println("LockFreeQueue基准:")
    println("  入队时间: ${enqueueTime}ms")
    println("  出队时间: ${dequeueTime}ms")
    println("  总吞吐量: ${throughput} ops/sec")
    println("  处理消息: ${dequeueCount}")
}
EOF

echo "1.2 序列化性能测试" | tee -a $result_file
cat > benchmark_serialization.cj << 'EOF'
import cactor.foundation.serialization.SerializationManager
import std.time.*

main() {
    let manager = SerializationManager()
    let iterations = 50000
    let testString = "Performance benchmark test string with reasonable length"
    
    let startTime = DateTime.now()
    for (i in 0..iterations) {
        let serialized = manager.serializeString(testString)
        let deserialized = manager.deserializeString(serialized)
    }
    let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                   startTime.toUnixTimeStamp().toMilliseconds()
    
    let throughput = if (totalTime > 0) { (iterations * 1000) / totalTime } else { 0 }
    
    println("序列化基准:")
    println("  总时间: ${totalTime}ms")
    println("  吞吐量: ${throughput} ops/sec")
    println("  处理次数: ${iterations}")
}
EOF

echo "1.3 内存池性能测试" | tee -a $result_file
cat > benchmark_memory_pool.cj << 'EOF'
import cactor.foundation.memory.StringPool
import std.time.*

main() {
    let pool = StringPool(100)
    let iterations = 10000
    
    let startTime = DateTime.now()
    for (i in 0..iterations) {
        let pooled = pool.acquire()
        pool.release(pooled)
    }
    let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                   startTime.toUnixTimeStamp().toMilliseconds()
    
    let throughput = if (totalTime > 0) { (iterations * 1000) / totalTime } else { 0 }
    
    println("内存池基准:")
    println("  总时间: ${totalTime}ms")
    println("  吞吐量: ${throughput} ops/sec")
    println("  处理次数: ${iterations}")
    
    let stats = pool.getStatistics()
    println("  获取次数: ${stats.totalAcquired}")
    println("  释放次数: ${stats.totalReleased}")
}
EOF

# 2. Core层性能基准
echo "" | tee -a $result_file
echo "💬 Core层性能基准测试..." | tee -a $result_file

echo "2.1 消息序列化性能测试" | tee -a $result_file
cat > benchmark_message_serialization.cj << 'EOF'
import cactor.core.message.{StringMessage, PingMessage, MessageSerializer}
import std.time.*

main() {
    let serializer = MessageSerializer()
    let iterations = 20000
    
    let startTime = DateTime.now()
    for (i in 0..iterations) {
        let message = if (i % 2 == 0) {
            StringMessage("Benchmark message ${i}")
        } else {
            PingMessage(i)
        }
        
        let serialized = serializer.serialize(message)
        let deserialized = serializer.deserialize(serialized)
    }
    let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                   startTime.toUnixTimeStamp().toMilliseconds()
    
    let throughput = if (totalTime > 0) { (iterations * 1000) / totalTime } else { 0 }
    
    println("消息序列化基准:")
    println("  总时间: ${totalTime}ms")
    println("  吞吐量: ${throughput} msg/sec")
    println("  处理消息: ${iterations}")
}
EOF

# 3. Runtime层性能基准
echo "" | tee -a $result_file
echo "📮 Runtime层性能基准测试..." | tee -a $result_file

echo "3.1 邮箱性能测试" | tee -a $result_file
cat > benchmark_mailbox.cj << 'EOF'
import cactor.runtime.mailbox.FoundationMailbox
import cactor.core.message.{StringMessage, Envelope}
import std.time.*

main() {
    let mailbox = FoundationMailbox(2048, true)
    let iterations = 50000
    
    // 创建测试消息
    let messages = ArrayList<Envelope>()
    for (i in 0..iterations) {
        let message = StringMessage("Mailbox benchmark ${i}")
        let envelope = Envelope(message, Some("benchmarkSender"))
        messages.append(envelope)
    }
    
    // 入队性能测试
    let enqueueStart = DateTime.now()
    for (envelope in messages) {
        mailbox.enqueue(envelope)
    }
    let enqueueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                     enqueueStart.toUnixTimeStamp().toMilliseconds()
    
    // 出队性能测试
    let dequeueStart = DateTime.now()
    var dequeueCount = 0
    while (!mailbox.isEmpty()) {
        match (mailbox.dequeue()) {
            case Some(_) => dequeueCount += 1
            case None => break
        }
    }
    let dequeueTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                     dequeueStart.toUnixTimeStamp().toMilliseconds()
    
    let totalTime = enqueueTime + dequeueTime
    let throughput = if (totalTime > 0) { (iterations * 2 * 1000) / totalTime } else { 0 }
    
    println("邮箱基准:")
    println("  入队时间: ${enqueueTime}ms")
    println("  出队时间: ${dequeueTime}ms")
    println("  总吞吐量: ${throughput} ops/sec")
    println("  处理消息: ${dequeueCount}")
    
    let stats = mailbox.getStats()
    println("  成功率: ${stats.getSuccessRate()}%")
}
EOF

# 4. 端到端性能基准
echo "" | tee -a $result_file
echo "🔄 端到端性能基准测试..." | tee -a $result_file

echo "4.1 完整消息流性能测试" | tee -a $result_file
cat > benchmark_end_to_end.cj << 'EOF'
import cactor.foundation.queue.LockFreeQueue
import cactor.core.message.{StringMessage, MessageSerializer, Envelope}
import cactor.runtime.mailbox.FoundationMailbox
import std.time.*

main() {
    let serializer = MessageSerializer()
    let mailbox = FoundationMailbox(1024, true)
    let iterations = 10000
    
    let startTime = DateTime.now()
    
    for (i in 0..iterations) {
        // 1. 创建消息
        let message = StringMessage("E2E benchmark ${i}")
        
        // 2. 序列化
        let serialized = serializer.serialize(message)
        
        // 3. 反序列化
        let deserialized = serializer.deserialize(serialized)
        
        // 4. 包装成信封
        let envelope = Envelope(deserialized, Some("e2eBenchmark"))
        
        // 5. 入队到邮箱
        mailbox.enqueue(envelope)
        
        // 6. 从邮箱出队
        mailbox.dequeue()
    }
    
    let totalTime = DateTime.now().toUnixTimeStamp().toMilliseconds() - 
                   startTime.toUnixTimeStamp().toMilliseconds()
    
    let throughput = if (totalTime > 0) { (iterations * 1000) / totalTime } else { 0 }
    
    println("端到端基准:")
    println("  总时间: ${totalTime}ms")
    println("  吞吐量: ${throughput} msg/sec")
    println("  处理消息: ${iterations}")
    
    // 检查是否达到性能目标
    if (throughput > 100000) {
        println("🎉 性能优秀！超过10万消息/秒")
    } else if (throughput > 50000) {
        println("✅ 性能良好！超过5万消息/秒")
    } else if (throughput > 10000) {
        println("⚠️  性能一般，超过1万消息/秒")
    } else {
        println("❌ 性能不足，需要优化")
    }
}
EOF

# 运行基准测试
echo "" | tee -a $result_file
echo "🚀 开始运行基准测试..." | tee -a $result_file

# 编译并运行测试
test_files=(
    "benchmark_lockfree_queue.cj"
    "benchmark_serialization.cj"
    "benchmark_memory_pool.cj"
    "benchmark_message_serialization.cj"
    "benchmark_mailbox.cj"
    "benchmark_end_to_end.cj"
)

for test_file in "${test_files[@]}"; do
    echo "" | tee -a $result_file
    echo "运行 $test_file..." | tee -a $result_file
    
    # 尝试编译和运行
    if cjc -o "${test_file%.cj}" "$test_file" 2>/dev/null; then
        if ./"${test_file%.cj}" 2>/dev/null; then
            echo "✅ $test_file 测试完成" | tee -a $result_file
        else
            echo "⚠️  $test_file 运行失败" | tee -a $result_file
        fi
        rm -f "${test_file%.cj}"  # 清理可执行文件
    else
        echo "❌ $test_file 编译失败" | tee -a $result_file
    fi
    
    rm -f "$test_file"  # 清理源文件
done

# 生成基准测试报告
echo "" | tee -a $result_file
echo "📊 基准测试总结" | tee -a $result_file
echo "==================" | tee -a $result_file
echo "测试完成时间: $(date)" | tee -a $result_file
echo "结果文件: $result_file" | tee -a $result_file

# 性能目标检查
echo "" | tee -a $result_file
echo "🎯 性能目标检查:" | tee -a $result_file
echo "- Foundation队列: 目标 > 100万 ops/sec" | tee -a $result_file
echo "- 消息序列化: 目标 > 50万 msg/sec" | tee -a $result_file
echo "- 邮箱处理: 目标 > 50万 ops/sec" | tee -a $result_file
echo "- 端到端处理: 目标 > 10万 msg/sec" | tee -a $result_file
echo "- 最终目标: 800万 msg/sec (需要多线程优化)" | tee -a $result_file

echo ""
echo "🎉 基准测试完成！"
echo "📄 详细结果请查看: $result_file"
echo ""
echo "💡 提示："
echo "- 如果性能不达标，请检查系统资源和配置"
echo "- 生产环境建议使用多线程和集群部署"
echo "- 定期运行基准测试监控性能变化"
