# CActor 3.0 - 低延时高吞吐仓颉Actor框架全面升级计划

## 🎯 项目愿景

基于对Akka、Actix、ProtoActor等顶级Actor框架的深度分析，结合仓颉语言的独特优势（宏系统、高性能并发、零成本抽象），构建世界级的低延时高吞吐Actor框架。

## 📊 当前CActor分析总结

### ✅ 已实现的核心功能
- **基础Actor系统**: Actor接口、消息传递、上下文管理
- **高级邮箱系统**: 环形缓冲、优先级队列、批量处理
- **监督策略**: 重启、停止、恢复等故障处理机制
- **路由系统**: 轮询、随机、一致性哈希等路由策略
- **远程通信**: 序列化、网络传输、集群管理
- **持久化系统**: 事件存储、快照管理、状态恢复
- **流处理**: 背压控制、流水线处理、性能监控
- **性能优化**: 内存池、对象复用、原子操作

### 🔍 性能瓶颈分析
1. **消息传递延时**: 当前实现存在不必要的内存分配
2. **序列化开销**: 缺乏零拷贝序列化机制
3. **调度器效率**: 未充分利用仓颉轻量级线程优势
4. **内存管理**: 对象池策略需要优化
5. **网络I/O**: 缺乏高性能异步I/O实现

### 🚀 优化机会
1. **宏系统DSL**: 利用仓颉宏实现编译时优化
2. **零拷贝消息**: 基于仓颉内存模型的零拷贝实现
3. **NUMA感知**: 利用硬件特性优化性能
4. **JIT友好**: 设计JIT编译器友好的代码结构
5. **协程调度**: 深度集成仓颉协程系统

## 🏗️ CActor 3.0 架构设计

### 核心设计原则
1. **零拷贝优先**: 最小化内存分配和拷贝
2. **编译时优化**: 利用宏系统实现编译时代码生成
3. **硬件感知**: 充分利用现代硬件特性
4. **类型安全**: 保持仓颉语言的类型安全优势
5. **可观测性**: 内置全面的监控和调试能力

### 技术栈选择
- **核心语言**: 仓颉 0.53.4+
- **宏系统**: 仓颉宏用于DSL和代码生成
- **并发模型**: 仓颉轻量级线程 + 协程
- **内存管理**: 自定义内存池 + 零拷贝
- **网络I/O**: 基于仓颉net库的高性能实现
- **序列化**: 自研零拷贝序列化框架

## 🎭 Phase 1: 宏驱动的Actor DSL系统

### 1.1 Actor定义宏
```cangjie
// 目标语法
@actor
struct CounterActor {
    var count: Int64 = 0
    
    @handler
    func increment(msg: IncrementMsg) -> Unit {
        count += msg.value
    }
    
    @handler  
    func getCount(msg: GetCountMsg) -> CountResponse {
        CountResponse(count)
    }
}
```

### 1.2 消息路由宏
```cangjie
// 编译时生成高效路由代码
@route_table
enum MessageType {
    | Increment(IncrementMsg)
    | GetCount(GetCountMsg)
    | Reset(ResetMsg)
}
```

### 1.3 性能监控宏
```cangjie
// 自动注入性能监控代码
@monitored
@actor
struct HighPerfActor {
    // 编译时自动生成监控代码
}
```

### 实现计划
- [x] ✅ **设计Actor定义宏语法** - 已完成基础宏语法设计和验证
- [x] ✅ **实现基础宏功能** - 已实现log_info、time_it、repeat_3_times、simple_actor宏
- [x] ✅ **建立宏编译流程** - 已掌握--compile-macro编译选项和正确的开发流程
- [x] ✅ **创建宏测试框架** - 已实现完整的宏功能测试验证
- [ ] 🔄 实现消息处理器代码生成 - 基础框架已建立，需要扩展复杂功能
- [ ] 开发路由表编译时优化
- [ ] 集成性能监控代码注入
- [ ] 创建DSL语法验证和错误报告

### ✅ 已完成的宏功能验证
- **基础宏系统**: 成功实现日志、计时、重复执行等实用宏
- **Actor增强宏**: 实现simple_actor宏，可为结构体添加Actor功能
- **编译和测试**: 建立了完整的宏编译、测试、验证流程
- **技术突破**: 掌握了Cangjie宏系统的核心概念和最佳实践

## ⚡ Phase 2: 零拷贝消息传递系统

### 2.1 零拷贝消息设计
```cangjie
// 基于仓颉内存模型的零拷贝消息
public interface ZeroCopyMessage {
    func getMessageId(): UInt64
    func getPayloadPtr(): UnsafePointer<UInt8>
    func getPayloadSize(): UInt64
    func release(): Unit
}
```

### 2.2 内存池优化
```cangjie
// NUMA感知的内存池
public class NumaAwareMemoryPool {
    private let pools: Array<LocalMemoryPool>
    
    public func allocate<T>(size: UInt64, numaNode: Int32): UnsafePointer<T>
    public func deallocate<T>(ptr: UnsafePointer<T>, numaNode: Int32): Unit
}
```

### 2.3 消息序列化
```cangjie
// 零拷贝序列化框架
@serializable
struct HighPerfMessage {
    let id: UInt64
    let data: Array<UInt8>
    let timestamp: Int64
}
```

### 实现计划
- [ ] 设计零拷贝消息接口
- [ ] 实现NUMA感知内存池
- [ ] 开发零拷贝序列化框架
- [ ] 优化消息传递路径
- [ ] 集成内存使用监控

## 🚀 Phase 3: 高性能调度器系统

### 3.1 工作窃取调度器
```cangjie
// 基于仓颉协程的工作窃取调度器
public class WorkStealingScheduler {
    private let workers: Array<WorkerThread>
    private let globalQueue: LockFreeQueue<ActorTask>
    
    public func schedule(actor: ActorRef, message: Message): Unit
    public func steal(): Option<ActorTask>
}
```

### 3.2 优先级调度
```cangjie
// 多级优先级调度
public enum Priority {
    | Critical    // 系统关键消息
    | High        // 高优先级业务消息  
    | Normal      // 普通消息
    | Low         // 低优先级消息
}
```

### 3.3 批量处理优化
```cangjie
// 批量消息处理优化
public class BatchProcessor<T> {
    private let batchSize: UInt32
    private let timeout: Duration
    
    public func processBatch(messages: Array<T>): Unit
}
```

### 实现计划
- [ ] 实现工作窃取调度算法
- [ ] 开发多级优先级队列
- [ ] 优化批量消息处理
- [ ] 集成负载均衡机制
- [ ] 添加调度器性能监控

## 🌐 Phase 4: 分布式Actor系统

### 4.1 虚拟Actor模型
```cangjie
// 类似Orleans的虚拟Actor
@virtual_actor
struct UserActor {
    let userId: String
    var state: UserState
    
    // 自动激活和钝化
    @activate
    func onActivate(): Unit
    
    @deactivate  
    func onDeactivate(): Unit
}
```

### 4.2 集群管理
```cangjie
// 分布式集群管理
public class ClusterManager {
    private let nodes: HashMap<NodeId, NodeInfo>
    private let partitioner: ConsistentHashPartitioner
    
    public func addNode(node: NodeInfo): Unit
    public func removeNode(nodeId: NodeId): Unit
    public func routeMessage(actorId: ActorId, message: Message): Unit
}
```

### 4.3 故障检测和恢复
```cangjie
// 分布式故障检测
public class FailureDetector {
    private let heartbeatInterval: Duration
    private let suspicionThreshold: Duration
    
    public func detectFailure(nodeId: NodeId): Bool
    public func handleNodeFailure(nodeId: NodeId): Unit
}
```

### 实现计划
- [ ] 设计虚拟Actor激活机制
- [ ] 实现分布式路由算法
- [ ] 开发故障检测和恢复
- [ ] 集成集群状态管理
- [ ] 添加分布式监控

## 📈 Phase 5: 可观测性和调试系统

### 5.1 分布式追踪
```cangjie
// 分布式消息追踪
@traced
public class TracedActor <: Actor {
    public func receive(message: Message, context: ActorContext): MessageResult {
        // 自动注入追踪代码
    }
}
```

### 5.2 性能分析
```cangjie
// 实时性能分析
public class PerformanceProfiler {
    private let metrics: MetricsCollector
    
    public func recordLatency(operation: String, duration: Duration): Unit
    public func recordThroughput(operation: String, count: UInt64): Unit
}
```

### 5.3 可视化监控
```cangjie
// 监控数据导出
public interface MetricsExporter {
    func exportMetrics(): MetricsSnapshot
    func exportToPrometheus(): String
    func exportToJaeger(): TraceData
}
```

### 实现计划
- [ ] 实现分布式消息追踪
- [ ] 开发实时性能分析
- [ ] 集成可视化监控界面
- [ ] 添加调试工具支持
- [ ] 创建性能基准测试

## 🧪 Phase 6: 高级特性和优化

### 6.1 响应式流
```cangjie
// 响应式流处理
@reactive_stream
public class DataProcessor {
    @source
    func dataSource(): Stream<Data>
    
    @transform
    func processData(data: Data): ProcessedData
    
    @sink
    func dataSink(data: ProcessedData): Unit
}
```

### 6.2 事件溯源优化
```cangjie
// 高性能事件存储
public class HighPerfEventStore {
    private let journal: MemoryMappedJournal
    private let snapshots: CompressedSnapshotStore
    
    public func persistEvent(event: Event): Future<Unit>
    public func replayEvents(actorId: ActorId): Stream<Event>
}
```

### 6.3 机器学习集成
```cangjie
// AI驱动的性能优化
public class MLOptimizer {
    private let model: PredictionModel
    
    public func predictLoad(): LoadPrediction
    public func optimizeScheduling(): SchedulingStrategy
}
```

### 实现计划
- [ ] 实现响应式流处理
- [ ] 优化事件溯源性能
- [ ] 集成机器学习优化
- [ ] 开发自适应调优
- [ ] 添加云原生支持

## 📋 实施时间线

### Q1 2024: 基础设施
- 宏系统DSL开发
- 零拷贝消息系统
- 基础性能优化

### Q2 2024: 核心功能
- 高性能调度器
- 分布式Actor系统
- 故障检测和恢复

### Q3 2024: 高级特性
- 可观测性系统
- 响应式流处理
- 事件溯源优化

### Q4 2024: 生态完善
- 机器学习集成
- 云原生支持
- 社区工具链

## 🎯 性能目标

### 延时指标
- **P99延时**: < 100μs (本地消息)
- **P99延时**: < 1ms (远程消息)
- **平均延时**: < 10μs (本地消息)

### 吞吐量指标
- **单机吞吐**: > 10M msg/s
- **集群吞吐**: > 100M msg/s
- **内存使用**: < 1KB per actor

### 可扩展性指标
- **单机Actor数**: > 1M actors
- **集群节点数**: > 1000 nodes
- **故障恢复时间**: < 1s

## 🔧 开发工具链

### 编译时工具
- Actor DSL编译器
- 性能分析器
- 代码生成器

### 运行时工具
- 分布式调试器
- 性能监控面板
- 故障诊断工具

### 测试工具
- 性能基准测试
- 混沌工程测试
- 负载测试框架

## 🌟 创新亮点

1. **宏驱动开发**: 利用仓颉宏系统实现编译时优化
2. **零拷贝架构**: 基于仓颉内存模型的零拷贝实现
3. **硬件感知**: NUMA感知和CPU缓存友好设计
4. **AI驱动优化**: 机器学习驱动的性能调优
5. **云原生设计**: 原生支持容器和Kubernetes

这个计划将使CActor成为世界领先的Actor框架，在性能、可扩展性和易用性方面都达到新的高度。

## 🔬 技术深度分析

### Akka框架优势借鉴
1. **监督层次结构**: Akka的监督树模型提供了优秀的故障隔离
2. **位置透明性**: Actor引用的位置透明性简化了分布式编程
3. **背压控制**: Akka Streams的背压机制保证了系统稳定性
4. **集群分片**: 自动分片和负载均衡机制

### Actix框架性能优势
1. **零拷贝消息**: Rust的所有权模型实现真正的零拷贝
2. **异步I/O**: 基于Tokio的高性能异步运行时
3. **类型安全**: 编译时保证消息类型安全
4. **内存效率**: 极低的内存占用和高效的内存管理

### ProtoActor虚拟Actor模型
1. **自动激活**: 按需激活和钝化机制
2. **状态管理**: 透明的状态持久化和恢复
3. **跨语言支持**: 多语言运行时支持
4. **云原生**: 原生支持容器化部署

### 仓颉语言独特优势
1. **宏系统**: 强大的编译时代码生成能力
2. **轻量级线程**: 高效的协程调度机制
3. **内存安全**: 无GC的内存安全保证
4. **零成本抽象**: 编译时优化的抽象层
5. **并发原语**: 丰富的并发编程原语

## 🏛️ 详细架构设计

### 核心层次架构
```
┌─────────────────────────────────────────┐
│              应用层 (DSL)                │
├─────────────────────────────────────────┤
│            Actor运行时层                 │
├─────────────────────────────────────────┤
│            消息传递层                    │
├─────────────────────────────────────────┤
│            调度器层                      │
├─────────────────────────────────────────┤
│            网络传输层                    │
├─────────────────────────────────────────┤
│            存储层                        │
└─────────────────────────────────────────┘
```

### 内存布局优化
```cangjie
// CPU缓存友好的Actor内存布局
@cache_aligned
public struct OptimizedActor {
    // 热路径数据 - 第一个缓存行
    private var state: ActorState           // 8 bytes
    private var messageCount: AtomicInt64   // 8 bytes
    private var lastProcessTime: Int64      // 8 bytes
    private var flags: AtomicInt32          // 4 bytes
    private var priority: UInt8             // 1 byte
    private var padding1: Array<UInt8, 35>  // 35 bytes padding

    // 冷路径数据 - 第二个缓存行
    private var mailbox: UnsafePointer<Mailbox>     // 8 bytes
    private var supervisor: Option<ActorRef>        // 16 bytes
    private var children: ArrayList<ActorRef>       // 24 bytes
    private var metrics: ActorMetrics               // 16 bytes
}
```

### 消息传递优化
```cangjie
// 基于环形缓冲的无锁消息队列
public class LockFreeRingBuffer<T> {
    private let buffer: UnsafePointer<T>
    private let capacity: UInt64
    private var head: AtomicInt64
    private var tail: AtomicInt64

    @inline
    public func enqueue(item: T): Bool {
        let currentTail = tail.load(MemoryOrder.Acquire)
        let nextTail = (currentTail + 1) % capacity

        if (nextTail == head.load(MemoryOrder.Acquire)) {
            return false  // 队列满
        }

        buffer[currentTail] = item
        tail.store(nextTail, MemoryOrder.Release)
        return true
    }

    @inline
    public func dequeue(): Option<T> {
        let currentHead = head.load(MemoryOrder.Acquire)
        if (currentHead == tail.load(MemoryOrder.Acquire)) {
            return None<T>  // 队列空
        }

        let item = buffer[currentHead]
        head.store((currentHead + 1) % capacity, MemoryOrder.Release)
        return Some(item)
    }
}
```

## 🎯 宏系统DSL详细设计

### Actor定义宏实现
```cangjie
// 宏包定义
macro package cactor_dsl

import std.ast.*
import cactor.core.*

// Actor定义宏
public macro actor(input: Tokens): Tokens {
    let structDef = parseStructDefinition(input)
    let actorName = structDef.name
    let fields = structDef.fields
    let methods = structDef.methods

    // 生成Actor实现代码
    let actorImpl = generateActorImplementation(actorName, fields, methods)
    let messageHandlers = generateMessageHandlers(methods)
    let routingTable = generateRoutingTable(methods)

    return quote(
        $(actorImpl)
        $(messageHandlers)
        $(routingTable)

        // 自动生成工厂方法
        public func create$(actorName)(): ActorRef {
            let actor = $(actorName)()
            return ActorSystem.spawn(actor)
        }
    )
}

// 消息处理器宏
public macro handler(input: Tokens): Tokens {
    let funcDef = parseFunctionDefinition(input)
    let msgType = extractMessageType(funcDef.parameters)

    return quote(
        @inline
        $(input)

        // 生成类型安全的消息分发代码
        private func handle$(msgType)(msg: $(msgType), ctx: ActorContext): MessageResult {
            return $(funcDef.name)(msg)
        }
    )
}
```

### 性能监控宏
```cangjie
// 性能监控注入宏
public macro monitored(input: Tokens): Tokens {
    let structDef = parseStructDefinition(input)

    return quote(
        $(input)

        // 注入性能监控字段
        extend $(structDef.name) {
            private var metrics: ActorMetrics = ActorMetrics()

            // 重写receive方法，添加监控
            public func receive(message: Message, context: ActorContext): MessageResult {
                let startTime = getCurrentTime()
                let result = super.receive(message, context)
                let duration = getCurrentTime() - startTime

                metrics.recordLatency(message.messageType(), duration)
                metrics.incrementMessageCount()

                return result
            }
        }
    )
}
```

## ⚡ 零拷贝消息系统详细实现

### 消息内存布局
```cangjie
// 零拷贝消息头部
@packed
public struct MessageHeader {
    let magic: UInt32           // 魔数，用于验证
    let version: UInt16         // 协议版本
    let messageType: UInt16     // 消息类型ID
    let payloadSize: UInt32     // 负载大小
    let checksum: UInt32        // 校验和
    let timestamp: UInt64       // 时间戳
    let sourceActor: UInt64     // 源Actor ID
    let targetActor: UInt64     // 目标Actor ID
}

// 零拷贝消息实现
public class ZeroCopyMessageImpl <: ZeroCopyMessage {
    private let headerPtr: UnsafePointer<MessageHeader>
    private let payloadPtr: UnsafePointer<UInt8>
    private let memoryPool: MemoryPool

    public init(pool: MemoryPool, payloadSize: UInt64) {
        let totalSize = sizeof<MessageHeader>() + payloadSize
        let ptr = pool.allocate(totalSize)

        this.headerPtr = ptr.cast<MessageHeader>()
        this.payloadPtr = ptr.offset(sizeof<MessageHeader>()).cast<UInt8>()
        this.memoryPool = pool

        // 初始化头部
        headerPtr.pointee.magic = 0xCAC70R
        headerPtr.pointee.version = 1
        headerPtr.pointee.payloadSize = payloadSize.toUInt32()
        headerPtr.pointee.timestamp = getCurrentTimestamp()
    }

    public func getPayloadPtr(): UnsafePointer<UInt8> {
        payloadPtr
    }

    public func release(): Unit {
        memoryPool.deallocate(headerPtr.cast<UInt8>())
    }
}
```

### NUMA感知内存池
```cangjie
// NUMA感知的内存分配器
public class NumaAwareAllocator {
    private let nodeCount: Int32
    private let localPools: Array<LocalMemoryPool>
    private let globalPool: GlobalMemoryPool

    public init() {
        this.nodeCount = getNumaNodeCount()
        this.localPools = Array<LocalMemoryPool>(nodeCount)
        this.globalPool = GlobalMemoryPool()

        // 为每个NUMA节点创建本地内存池
        for (i in 0..nodeCount) {
            localPools[i] = LocalMemoryPool(numaNode: i)
        }
    }

    @inline
    public func allocate<T>(size: UInt64): UnsafePointer<T> {
        let currentNode = getCurrentNumaNode()

        // 优先从本地NUMA节点分配
        match (localPools[currentNode].tryAllocate<T>(size)) {
            case Some(ptr) => ptr
            case None =>
                // 本地分配失败，尝试全局池
                globalPool.allocate<T>(size)
        }
    }

    @inline
    public func deallocate<T>(ptr: UnsafePointer<T>): Unit {
        let numaNode = getPointerNumaNode(ptr)
        localPools[numaNode].deallocate(ptr)
    }
}
```

## 🚀 高性能调度器详细设计

### 工作窃取调度器
```cangjie
// 工作窃取调度器实现
public class WorkStealingScheduler <: Scheduler {
    private let workerCount: Int32
    private let workers: Array<WorkerThread>
    private let globalQueue: LockFreeQueue<ActorTask>
    private let random: ThreadLocalRandom

    public init(workerCount: Int32) {
        this.workerCount = workerCount
        this.workers = Array<WorkerThread>(workerCount)
        this.globalQueue = LockFreeQueue<ActorTask>()
        this.random = ThreadLocalRandom()

        // 创建工作线程
        for (i in 0..workerCount) {
            workers[i] = WorkerThread(id: i, scheduler: this)
            workers[i].start()
        }
    }

    public func schedule(task: ActorTask): Unit {
        let currentWorker = getCurrentWorker()

        // 优先放入当前工作线程的本地队列
        if (currentWorker != null && currentWorker.tryEnqueue(task)) {
            return
        }

        // 本地队列满，放入全局队列
        globalQueue.enqueue(task)

        // 唤醒空闲工作线程
        wakeupIdleWorker()
    }

    // 工作窃取逻辑
    public func steal(thiefId: Int32): Option<ActorTask> {
        // 随机选择一个受害者线程
        let victimId = random.nextInt(workerCount)
        if (victimId == thiefId) {
            return None<ActorTask>
        }

        return workers[victimId].stealTask()
    }
}

// 工作线程实现
public class WorkerThread {
    private let id: Int32
    private let localQueue: LockFreeDeque<ActorTask>
    private let scheduler: WorkStealingScheduler
    private var isRunning: AtomicBool

    public func run(): Unit {
        while (isRunning.load()) {
            // 1. 尝试从本地队列获取任务
            match (localQueue.popFront()) {
                case Some(task) =>
                    executeTask(task)
                    continue
                case None => {}
            }

            // 2. 尝试从全局队列获取任务
            match (scheduler.globalQueue.dequeue()) {
                case Some(task) =>
                    executeTask(task)
                    continue
                case None => {}
            }

            // 3. 尝试从其他线程窃取任务
            match (scheduler.steal(id)) {
                case Some(task) =>
                    executeTask(task)
                    continue
                case None => {}
            }

            // 4. 没有任务，进入等待状态
            waitForWork()
        }
    }

    @inline
    private func executeTask(task: ActorTask): Unit {
        let actor = task.actor
        let message = task.message
        let context = task.context

        // 执行Actor消息处理
        let startTime = getCurrentTime()
        let result = actor.receive(message, context)
        let duration = getCurrentTime() - startTime

        // 记录性能指标
        recordTaskExecution(actor.getId(), duration, result)
    }
}
```

## 🌐 分布式Actor系统详细设计

### 虚拟Actor生命周期管理
```cangjie
// 虚拟Actor管理器
public class VirtualActorManager {
    private let activatedActors: ConcurrentHashMap<ActorId, VirtualActorInstance>
    private let partitioner: ConsistentHashPartitioner
    private let activationPolicy: ActivationPolicy
    private let deactivationTimer: Timer

    // Actor激活
    public func activateActor<T: VirtualActor>(
        actorId: ActorId,
        actorType: Type<T>
    ): Future<ActorRef> {
        // 检查是否已激活
        match (activatedActors.get(actorId)) {
            case Some(instance) =>
                return Future.completed(instance.getRef())
            case None => {}
        }

        // 创建新的Actor实例
        let instance = VirtualActorInstance<T>(actorId, actorType)

        // 从持久化存储恢复状态
        let stateData = loadActorState(actorId)
        instance.restoreState(stateData)

        // 注册到激活列表
        activatedActors.put(actorId, instance)

        // 设置钝化定时器
        scheduleDeactivation(actorId)

        return Future.completed(instance.getRef())
    }

    // Actor钝化
    public func deactivateActor(actorId: ActorId): Future<Unit> {
        match (activatedActors.remove(actorId)) {
            case Some(instance) =>
                // 保存状态到持久化存储
                let stateData = instance.captureState()
                saveActorState(actorId, stateData)

                // 停止Actor
                instance.stop()

                return Future.completed(Unit)
            case None =>
                return Future.completed(Unit)
        }
    }
}

// 虚拟Actor实例
public class VirtualActorInstance<T: VirtualActor> {
    private let actorId: ActorId
    private let actor: T
    private let actorRef: ActorRef
    private var lastAccessTime: AtomicInt64

    public init(actorId: ActorId, actorType: Type<T>) {
        this.actorId = actorId
        this.actor = actorType.createInstance()
        this.actorRef = ActorSystem.spawn(actor)
        this.lastAccessTime = AtomicInt64(getCurrentTime())
    }

    public func getRef(): ActorRef {
        lastAccessTime.store(getCurrentTime())
        return actorRef
    }

    public func captureState(): StateData {
        return actor.serializeState()
    }

    public func restoreState(stateData: StateData): Unit {
        actor.deserializeState(stateData)
    }
}
```

### 分布式路由和负载均衡
```cangjie
// 一致性哈希分区器
public class ConsistentHashPartitioner {
    private let virtualNodes: Int32
    private let ring: TreeMap<UInt64, NodeId>
    private let nodes: HashSet<NodeId>

    public init(virtualNodes: Int32 = 150) {
        this.virtualNodes = virtualNodes
        this.ring = TreeMap<UInt64, NodeId>()
        this.nodes = HashSet<NodeId>()
    }

    public func addNode(nodeId: NodeId): Unit {
        nodes.add(nodeId)

        // 为每个物理节点创建虚拟节点
        for (i in 0..virtualNodes) {
            let virtualKey = hash("${nodeId}_${i}")
            ring.put(virtualKey, nodeId)
        }
    }

    public func removeNode(nodeId: NodeId): Unit {
        nodes.remove(nodeId)

        // 移除所有虚拟节点
        for (i in 0..virtualNodes) {
            let virtualKey = hash("${nodeId}_${i}")
            ring.remove(virtualKey)
        }
    }

    public func getNode(key: String): Option<NodeId> {
        if (ring.isEmpty()) {
            return None<NodeId>
        }

        let hashValue = hash(key)

        // 找到第一个大于等于hashValue的节点
        match (ring.ceilingEntry(hashValue)) {
            case Some(entry) => Some(entry.value)
            case None =>
                // 环形结构，返回第一个节点
                ring.firstEntry().map(entry => entry.value)
        }
    }
}

// 集群消息路由器
public class ClusterRouter {
    private let localNode: NodeId
    private let partitioner: ConsistentHashPartitioner
    private let nodeConnections: ConcurrentHashMap<NodeId, Connection>
    private let messageSerializer: MessageSerializer

    public func routeMessage(actorId: ActorId, message: Message): Future<Unit> {
        let targetNode = partitioner.getNode(actorId.toString())

        match (targetNode) {
            case Some(nodeId) =>
                if (nodeId == localNode) {
                    // 本地路由
                    return routeLocalMessage(actorId, message)
                } else {
                    // 远程路由
                    return routeRemoteMessage(nodeId, actorId, message)
                }
            case None =>
                return Future.failed(RoutingException("No available nodes"))
        }
    }

    private func routeRemoteMessage(
        nodeId: NodeId,
        actorId: ActorId,
        message: Message
    ): Future<Unit> {
        match (nodeConnections.get(nodeId)) {
            case Some(connection) =>
                let serializedMsg = messageSerializer.serialize(message)
                let envelope = RemoteMessageEnvelope(actorId, serializedMsg)
                return connection.send(envelope)
            case None =>
                return Future.failed(ConnectionException("Node not connected: ${nodeId}"))
        }
    }
}
```

## 📊 可观测性系统详细实现

### 分布式追踪系统
```cangjie
// 追踪上下文
public class TraceContext {
    private let traceId: TraceId
    private let spanId: SpanId
    private let parentSpanId: Option<SpanId>
    private let baggage: HashMap<String, String>

    public init(traceId: TraceId, spanId: SpanId, parentSpanId: Option<SpanId>) {
        this.traceId = traceId
        this.spanId = spanId
        this.parentSpanId = parentSpanId
        this.baggage = HashMap<String, String>()
    }

    public func createChildSpan(operationName: String): TraceContext {
        let childSpanId = SpanId.generate()
        return TraceContext(traceId, childSpanId, Some(spanId))
    }
}

// 分布式追踪器
public class DistributedTracer {
    private let spanCollector: SpanCollector
    private let sampler: TraceSampler

    public func startSpan(operationName: String, context: Option<TraceContext>): Span {
        let traceContext = match (context) {
            case Some(ctx) => ctx.createChildSpan(operationName)
            case None => TraceContext.createRoot()
        }

        let span = Span(
            traceId: traceContext.traceId,
            spanId: traceContext.spanId,
            parentSpanId: traceContext.parentSpanId,
            operationName: operationName,
            startTime: getCurrentTime()
        )

        return span
    }

    public func finishSpan(span: Span): Unit {
        span.finishTime = getCurrentTime()

        if (sampler.shouldSample(span)) {
            spanCollector.collect(span)
        }
    }
}

// Actor消息追踪
@traced
public class TracedActorContext <: ActorContext {
    private let baseContext: ActorContext
    private let tracer: DistributedTracer
    private var currentSpan: Option<Span>

    public func send(target: ActorRef, message: Message): Unit {
        let span = tracer.startSpan("actor.send", getCurrentTraceContext())
        span.setTag("target.actor", target.path())
        span.setTag("message.type", message.messageType())

        // 将追踪信息注入到消息中
        let tracedMessage = injectTraceContext(message, span.getContext())

        baseContext.send(target, tracedMessage)

        tracer.finishSpan(span)
    }

    public func receive(message: Message): MessageResult {
        // 从消息中提取追踪信息
        let traceContext = extractTraceContext(message)

        let span = tracer.startSpan("actor.receive", traceContext)
        span.setTag("actor.path", self.path())
        span.setTag("message.type", message.messageType())

        let result = baseContext.receive(message)

        span.setTag("result", result.toString())
        tracer.finishSpan(span)

        return result
    }
}
```

### 实时性能监控
```cangjie
// 性能指标收集器
public class MetricsCollector {
    private let counters: ConcurrentHashMap<String, AtomicInt64>
    private let histograms: ConcurrentHashMap<String, Histogram>
    private let gauges: ConcurrentHashMap<String, Gauge>
    private let timers: ConcurrentHashMap<String, Timer>

    public func incrementCounter(name: String, delta: Int64 = 1): Unit {
        counters.computeIfAbsent(name, { AtomicInt64(0) }).addAndGet(delta)
    }

    public func recordHistogram(name: String, value: Float64): Unit {
        histograms.computeIfAbsent(name, { Histogram() }).record(value)
    }

    public func setGauge(name: String, value: Float64): Unit {
        gauges.computeIfAbsent(name, { Gauge() }).set(value)
    }

    public func recordTimer(name: String, duration: Duration): Unit {
        timers.computeIfAbsent(name, { Timer() }).record(duration)
    }

    // 导出Prometheus格式指标
    public func exportPrometheus(): String {
        let builder = StringBuilder()

        // 导出计数器
        for ((name, counter) in counters) {
            builder.append("# TYPE ${name} counter\n")
            builder.append("${name} ${counter.get()}\n")
        }

        // 导出直方图
        for ((name, histogram) in histograms) {
            builder.append("# TYPE ${name} histogram\n")
            for (bucket in histogram.getBuckets()) {
                builder.append("${name}_bucket{le=\"${bucket.upperBound}\"} ${bucket.count}\n")
            }
            builder.append("${name}_sum ${histogram.getSum()}\n")
            builder.append("${name}_count ${histogram.getCount()}\n")
        }

        return builder.toString()
    }
}

// Actor性能监控
public class ActorPerformanceMonitor {
    private let metrics: MetricsCollector
    private let actorMetrics: ConcurrentHashMap<ActorId, ActorMetrics>

    public func recordMessageProcessing(
        actorId: ActorId,
        messageType: String,
        duration: Duration,
        result: MessageResult
    ): Unit {
        // 全局指标
        metrics.incrementCounter("actor.messages.total")
        metrics.recordTimer("actor.message.duration", duration)
        metrics.incrementCounter("actor.messages.by_type.${messageType}")

        // 按结果分类
        match (result) {
            case MessageResult.Handled =>
                metrics.incrementCounter("actor.messages.handled")
            case MessageResult.Unhandled =>
                metrics.incrementCounter("actor.messages.unhandled")
            case MessageResult.Failed =>
                metrics.incrementCounter("actor.messages.failed")
        }

        // Actor级别指标
        let actorMetric = actorMetrics.computeIfAbsent(actorId, { ActorMetrics() })
        actorMetric.recordMessage(messageType, duration, result)
    }

    public func recordActorCreation(actorId: ActorId): Unit {
        metrics.incrementCounter("actor.created.total")
        actorMetrics.put(actorId, ActorMetrics())
    }

    public func recordActorDestruction(actorId: ActorId): Unit {
        metrics.incrementCounter("actor.destroyed.total")
        actorMetrics.remove(actorId)
    }
}
```

## 🧪 测试和基准测试框架

### 性能基准测试
```cangjie
// Actor性能基准测试
public class ActorBenchmark {
    private let actorSystem: ActorSystem
    private let messageCount: Int64
    private let actorCount: Int32

    public init(messageCount: Int64, actorCount: Int32) {
        this.actorSystem = ActorSystem.create("benchmark")
        this.messageCount = messageCount
        this.actorCount = actorCount
    }

    // 延时基准测试
    public func benchmarkLatency(): BenchmarkResult {
        let actor = actorSystem.spawn(BenchmarkActor())
        let startTime = getCurrentTime()

        // 发送单个消息并等待响应
        let future = actor.ask(PingMessage())
        let response = future.await(Duration.seconds(5))

        let endTime = getCurrentTime()
        let latency = endTime - startTime

        return BenchmarkResult(
            testName: "latency",
            duration: latency,
            throughput: 1.0 / latency.toSeconds()
        )
    }

    // 吞吐量基准测试
    public func benchmarkThroughput(): BenchmarkResult {
        let actors = Array<ActorRef>(actorCount)

        // 创建Actor
        for (i in 0..actorCount) {
            actors[i] = actorSystem.spawn(BenchmarkActor())
        }

        let startTime = getCurrentTime()
        let latch = CountDownLatch(messageCount.toInt32())

        // 并发发送消息
        spawn {
            for (i in 0..messageCount) {
                let actorIndex = i % actorCount
                actors[actorIndex].tell(BenchmarkMessage(i, latch))
            }
        }

        // 等待所有消息处理完成
        latch.await()
        let endTime = getCurrentTime()

        let duration = endTime - startTime
        let throughput = messageCount.toFloat64() / duration.toSeconds()

        return BenchmarkResult(
            testName: "throughput",
            duration: duration,
            throughput: throughput
        )
    }

    // 内存使用基准测试
    public func benchmarkMemoryUsage(): BenchmarkResult {
        let initialMemory = getMemoryUsage()

        let actors = Array<ActorRef>(actorCount)
        for (i in 0..actorCount) {
            actors[i] = actorSystem.spawn(BenchmarkActor())
        }

        // 强制GC
        System.gc()
        let finalMemory = getMemoryUsage()

        let memoryPerActor = (finalMemory - initialMemory) / actorCount.toInt64()

        return BenchmarkResult(
            testName: "memory_usage",
            memoryPerActor: memoryPerActor,
            totalMemory: finalMemory - initialMemory
        )
    }
}

// 基准测试Actor
public class BenchmarkActor <: Actor {
    private var messageCount: Int64 = 0

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case ping: PingMessage =>
                context.sender().tell(PongMessage())
                MessageResult.Handled

            case benchmark: BenchmarkMessage =>
                messageCount += 1
                benchmark.latch.countDown()
                MessageResult.Handled

            case _ => MessageResult.Unhandled
        }
    }
}
```

这个详细的plan3.md展示了一个全面的低延时高吞吐Actor框架设计，充分利用了仓颉语言的独特优势，并借鉴了业界最佳实践。通过宏系统实现编译时优化，零拷贝消息传递，NUMA感知的内存管理，工作窃取调度器，分布式虚拟Actor模型，以及全面的可观测性系统，CActor 3.0将成为业界领先的Actor框架。
