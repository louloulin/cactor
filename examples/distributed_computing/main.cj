/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 分布式计算示例
 * 
 * 这个示例展示了如何使用Actor模型进行分布式计算
 * 包括：工作分发、结果聚合、错误处理等
 */
package cactor.examples.distributed_computing

import std.time.*
import std.collection.*
import cactor.core.message.{Message, StringMessage}
import cactor.core.actor.{Actor, ActorContext}
import cactor.pattern.ask.{AskPattern, AskRequest, AskResponse}
import cactor.routing.{RoundRobinRouter}
import cactor.supervision.{SupervisionStrategy, SupervisionDirective}
import cactor.logging.{LoggerFactory, LogLevel}

/**
 * 计算任务消息
 */
public struct ComputeTask {
    public let taskId: String
    public let data: Array<Int64>
    public let operation: String
    
    public init(taskId: String, data: Array<Int64>, operation: String) {
        this.taskId = taskId
        this.data = data
        this.operation = operation
    }
}

/**
 * 计算结果消息
 */
public struct ComputeResult {
    public let taskId: String
    public let result: Int64
    public let processingTime: Int64
    
    public init(taskId: String, result: Int64, processingTime: Int64) {
        this.taskId = taskId
        this.result = result
        this.processingTime = processingTime
    }
}

/**
 * 工作完成消息
 */
public struct WorkComplete {
    public let totalTasks: Int64
    public let totalTime: Int64
    public let results: Array<ComputeResult>
    
    public init(totalTasks: Int64, totalTime: Int64, results: Array<ComputeResult>) {
        this.totalTasks = totalTasks
        this.totalTime = totalTime
        self.results = results
    }
}

/**
 * 工作者Actor - 执行具体的计算任务
 */
public class WorkerActor <: Actor {
    private let workerId: String
    private let logger = LoggerFactory.getLogger("Worker")
    private let tasksProcessed: AtomicInt64
    
    public init(workerId: String) {
        this.workerId = workerId
        this.tasksProcessed = AtomicInt64(0)
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case task: ComputeTask => 
                processTask(task, context)
            case msg: StringMessage => 
                if (msg.getContent() == "status") {
                    println("👷 Worker[${workerId}] 已处理 ${tasksProcessed.load()} 个任务")
                } else if (msg.getContent() == "stop") {
                    println("🛑 Worker[${workerId}] 收到停止信号")
                    context.stop()
                }
            case _ => 
                logger.warn("Worker[${workerId}] 收到未知消息类型")
        }
    }
    
    private func processTask(task: ComputeTask, context: ActorContext): Unit {
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        
        try {
            logger.info("Worker[${workerId}] 开始处理任务 ${task.taskId}")
            
            // 执行计算
            let result = performComputation(task.data, task.operation)
            
            let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            let processingTime = endTime - startTime
            
            // 发送结果（这里简化为打印）
            let computeResult = ComputeResult(task.taskId, result, processingTime)
            println("✅ Worker[${workerId}] 完成任务 ${task.taskId}: 结果=${result}, 耗时=${processingTime}ms")
            
            tasksProcessed.fetchAdd(1)
            
        } catch (e: Exception) {
            logger.error("Worker[${workerId}] 处理任务 ${task.taskId} 失败: ${e.message}")
            // 在实际系统中，这里会发送错误消息给监督者
        }
    }
    
    private func performComputation(data: Array<Int64>, operation: String): Int64 {
        // 模拟计算延迟
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        while (DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime < 10) {
            // 等待10毫秒
        }
        
        match (operation) {
            case "sum" => 
                var total = Int64(0)
                for (value in data) {
                    total += value
                }
                total
            case "product" => 
                var product = Int64(1)
                for (value in data) {
                    product *= value
                }
                product
            case "max" => 
                if (data.size == 0) {
                    0
                } else {
                    var maxValue = data[0]
                    for (value in data) {
                        if (value > maxValue) {
                            maxValue = value
                        }
                    }
                    maxValue
                }
            case "min" => 
                if (data.size == 0) {
                    0
                } else {
                    var minValue = data[0]
                    for (value in data) {
                        if (value < minValue) {
                            minValue = value
                        }
                    }
                    minValue
                }
            case _ => 
                throw Exception("不支持的操作: ${operation}")
        }
    }
    
    public func preStart(): Unit {
        logger.info("Worker[${workerId}] 启动")
        println("🚀 Worker[${workerId}] 准备就绪")
    }
    
    public func postStop(): Unit {
        logger.info("Worker[${workerId}] 停止，总共处理了 ${tasksProcessed.load()} 个任务")
        println("🛑 Worker[${workerId}] 已停止")
    }
}

/**
 * 主管Actor - 分发任务和收集结果
 */
public class MasterActor <: Actor {
    private let workers: ArrayList<WorkerActor>
    private let results: ArrayList<ComputeResult>
    private let pendingTasks: AtomicInt64
    private let completedTasks: AtomicInt64
    private let startTime: AtomicInt64
    private let logger = LoggerFactory.getLogger("Master")
    
    public init(workerCount: Int64) {
        this.workers = ArrayList<WorkerActor>()
        this.results = ArrayList<ComputeResult>()
        this.pendingTasks = AtomicInt64(0)
        this.completedTasks = AtomicInt64(0)
        this.startTime = AtomicInt64(0)
        
        // 创建工作者
        for (i in 0..workerCount) {
            let worker = WorkerActor("worker-${i}")
            worker.preStart()
            workers.append(worker)
        }
        
        logger.info("Master创建了 ${workerCount} 个工作者")
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case msg: StringMessage => 
                let content = msg.getContent()
                if (content.startsWith("compute:")) {
                    let operation = content.substring(8)
                    startDistributedComputation(operation)
                } else if (content == "status") {
                    printStatus()
                } else if (content == "stop") {
                    stopAllWorkers()
                    context.stop()
                }
            case result: ComputeResult => 
                handleResult(result)
            case _ => 
                logger.warn("Master收到未知消息类型")
        }
    }
    
    private func startDistributedComputation(operation: String): Unit {
        logger.info("开始分布式计算: ${operation}")
        startTime.store(DateTime.now().toUnixTimeStamp().toMilliseconds())
        
        // 生成测试数据和任务
        let tasks = generateTasks(operation, 20)  // 生成20个任务
        pendingTasks.store(Int64(tasks.size))
        completedTasks.store(0)
        results.clear()
        
        println("📋 Master开始分发 ${tasks.size} 个${operation}计算任务")
        
        // 分发任务给工作者（轮询方式）
        var workerIndex = 0
        for (task in tasks) {
            let worker = workers[workerIndex % workers.size]
            worker.receive(task, MockActorContext())
            workerIndex += 1
        }
    }
    
    private func generateTasks(operation: String, taskCount: Int64): Array<ComputeTask> {
        let tasks = ArrayList<ComputeTask>()
        
        for (i in 0..taskCount) {
            // 生成随机数据
            let data = ArrayList<Int64>()
            for (j in 0..10) {
                data.append(Int64(i * 10 + j + 1))
            }
            
            let task = ComputeTask("task-${i}", data.toArray(), operation)
            tasks.append(task)
        }
        
        tasks.toArray()
    }
    
    private func handleResult(result: ComputeResult): Unit {
        results.append(result)
        let completed = completedTasks.fetchAdd(1) + 1
        let pending = pendingTasks.load()
        
        logger.info("收到任务 ${result.taskId} 的结果: ${result.result}")
        println("📊 任务进度: ${completed}/${pending}")
        
        // 检查是否所有任务都完成了
        if (completed >= pending) {
            let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            let totalTime = endTime - startTime.load()
            
            let workComplete = WorkComplete(pending, totalTime, results.toArray())
            handleWorkComplete(workComplete)
        }
    }
    
    private func handleWorkComplete(workComplete: WorkComplete): Unit {
        logger.info("所有计算任务完成")
        println("🎉 所有计算任务完成！")
        println("📈 统计信息:")
        println("   - 总任务数: ${workComplete.totalTasks}")
        println("   - 总耗时: ${workComplete.totalTime}ms")
        println("   - 平均耗时: ${workComplete.totalTime / workComplete.totalTasks}ms/任务")
        
        // 打印部分结果
        println("📋 部分计算结果:")
        let maxResults = if (workComplete.results.size > 5) { 5 } else { workComplete.results.size }
        for (i in 0..maxResults) {
            let result = workComplete.results[i]
            println("   - ${result.taskId}: ${result.result} (${result.processingTime}ms)")
        }
        
        if (workComplete.results.size > 5) {
            println("   - ... 还有 ${workComplete.results.size - 5} 个结果")
        }
    }
    
    private func printStatus(): Unit {
        println("📊 Master状态:")
        println("   - 工作者数量: ${workers.size}")
        println("   - 待处理任务: ${pendingTasks.load()}")
        println("   - 已完成任务: ${completedTasks.load()}")
        println("   - 收到结果: ${results.size}")
        
        // 查询工作者状态
        for (worker in workers) {
            worker.receive(StringMessage("status"), MockActorContext())
        }
    }
    
    private func stopAllWorkers(): Unit {
        logger.info("停止所有工作者")
        println("🛑 Master停止所有工作者")
        
        for (worker in workers) {
            worker.receive(StringMessage("stop"), MockActorContext())
            worker.postStop()
        }
    }
    
    public func preStart(): Unit {
        logger.info("Master启动")
        println("🚀 Master准备就绪，管理 ${workers.size} 个工作者")
    }
    
    public func postStop(): Unit {
        logger.info("Master停止")
        println("🛑 Master已停止")
    }
}

/**
 * 主函数 - 分布式计算示例
 */
main(): Int64 {
    println("🌟 === CActor 分布式计算示例 ===")
    
    try {
        // 1. 基础分布式计算
        println("\n1️⃣ 基础分布式计算演示")
        testBasicDistributedComputing()
        
        // 2. 多种计算操作
        println("\n2️⃣ 多种计算操作演示")
        testMultipleOperations()
        
        // 3. 性能测试
        println("\n3️⃣ 性能测试演示")
        testPerformance()
        
        println("\n🎉 分布式计算示例完成！")
        return 0
    } catch (e: Exception) {
        println("❌ 示例运行失败: ${e.message}")
        return 1
    }
}

/**
 * 基础分布式计算测试
 */
func testBasicDistributedComputing(): Unit {
    println("   创建Master和Workers...")
    let master = MasterActor(4)  // 4个工作者
    let context = MockActorContext()
    
    master.preStart()
    
    // 开始计算
    println("   开始求和计算...")
    master.receive(StringMessage("compute:sum"), context)
    
    // 等待计算完成（简化实现）
    let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    while (DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime < 1000) {
        // 等待1秒
    }
    
    // 查看状态
    master.receive(StringMessage("status"), context)
    
    // 停止
    master.receive(StringMessage("stop"), context)
    master.postStop()
    
    println("   ✅ 基础分布式计算演示完成")
}

/**
 * 多种计算操作测试
 */
func testMultipleOperations(): Unit {
    println("   测试多种计算操作...")
    let master = MasterActor(3)  // 3个工作者
    let context = MockActorContext()
    
    master.preStart()
    
    // 测试不同的计算操作
    let operations = ["sum", "product", "max", "min"]
    
    for (operation in operations) {
        println("   执行${operation}计算...")
        master.receive(StringMessage("compute:${operation}"), context)
        
        // 等待计算完成
        let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        while (DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime < 500) {
            // 等待500毫秒
        }
    }
    
    master.receive(StringMessage("stop"), context)
    master.postStop()
    
    println("   ✅ 多种计算操作演示完成")
}

/**
 * 性能测试
 */
func testPerformance(): Unit {
    println("   性能测试...")
    let master = MasterActor(8)  // 8个工作者
    let context = MockActorContext()
    
    master.preStart()
    
    // 执行大量计算任务
    println("   执行大量求和任务...")
    master.receive(StringMessage("compute:sum"), context)
    
    // 等待计算完成
    let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
    while (DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime < 2000) {
        // 等待2秒
    }
    
    master.receive(StringMessage("status"), context)
    master.receive(StringMessage("stop"), context)
    master.postStop()
    
    println("   ✅ 性能测试演示完成")
}

/**
 * 模拟Actor上下文
 */
public class MockActorContext <: ActorContext {
    private let stopped: AtomicBool
    
    public init() {
        this.stopped = AtomicBool(false)
    }
    
    public func stop(): Unit {
        stopped.store(true)
    }
    
    public func isStopped(): Bool {
        stopped.load()
    }
}
