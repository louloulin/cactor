/*
 * 简单的Foundation层测试
 */
import cactor.foundation.queue.{Queue, SimpleQueue, LockFreeQueue}

main() {
    println("=== Foundation层基础测试 ===")
    
    // 测试SimpleQueue
    println("测试SimpleQueue...")
    let simpleQueue = SimpleQueue<String>(5)
    
    if (simpleQueue.enqueue("test1")) {
        println("✅ SimpleQueue入队成功")
    } else {
        println("❌ SimpleQueue入队失败")
    }
    
    match (simpleQueue.dequeue()) {
        case Some(item) => println("✅ SimpleQueue出队成功: ${item}")
        case None => println("❌ SimpleQueue出队失败")
    }
    
    println("SimpleQueue容量: ${simpleQueue.capacity()}")
    
    // 测试LockFreeQueue
    println("测试LockFreeQueue...")
    let lockFreeQueue = LockFreeQueue<Int64>(8)
    
    if (lockFreeQueue.enqueue(100)) {
        println("✅ LockFreeQueue入队成功")
    } else {
        println("❌ LockFreeQueue入队失败")
    }
    
    match (lockFreeQueue.dequeue()) {
        case Some(value) => println("✅ LockFreeQueue出队成功: ${value}")
        case None => println("❌ LockFreeQueue出队失败")
    }
    
    println("LockFreeQueue容量: ${lockFreeQueue.capacity()}")
    
    let stats = lockFreeQueue.getStats()
    println("LockFreeQueue统计: 入队${stats.enqueueCount}次, 出队${stats.dequeueCount}次")
    
    println("=== Foundation层测试完成 ===")
}
