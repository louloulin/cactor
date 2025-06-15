# CActor 彻底架构改造计划 - plan6.md

## 🎯 改造愿景

基于对Akka、ProtoActor、Actix等世界级Actor框架的深度分析，结合CActor现有代码库的全面审查，制定一个彻底的架构改造计划。不采用适配器模式的渐进式改造，而是从根本上重新设计整个架构，实现世界级的高性能Actor系统。

## 📊 主流Actor框架深度分析

### 🏆 Akka架构精髓
**核心设计原则**:
- **Actor层次结构**: 严格的监督树，每个Actor都有明确的父子关系
- **位置透明**: ActorRef抽象，本地和远程Actor使用相同接口
- **消息驱动**: 纯异步消息传递，无共享状态
- **弹性设计**: Let-it-crash哲学，通过监督策略处理故障
- **响应式流**: 背压控制，防止系统过载

**关键组件架构**:
```
ActorSystem
├── Guardian Actor (系统守护者)
├── Dispatcher (消息调度器)
│   ├── MessageQueue (消息队列)
│   └── ExecutionContext (执行上下文)
├── Mailbox (邮箱系统)
│   ├── UnboundedMailbox
│   ├── BoundedMailbox
│   └── PriorityMailbox
├── Supervision (监督系统)
│   ├── SupervisorStrategy
│   └── DeathWatch
└── Scheduler (定时器系统)
```

### 🦀 Actix架构精髓
**核心设计原则**:
- **类型安全**: 强类型消息系统，编译时检查
- **零成本抽象**: Rust的零成本抽象，极致性能
- **异步优先**: 基于Tokio的异步运行时
- **内存安全**: Rust的所有权系统保证内存安全

### 🚀 ProtoActor架构精髓
**核心设计原则**:
- **跨平台**: .NET、Go、Java多语言实现
- **高性能**: 优化的消息传递路径
- **简化API**: 更简洁的API设计
- **云原生**: 为云环境优化

## 🔍 CActor现有架构深度分析

### ❌ 严重架构缺陷

#### 1. 包结构混乱 (致命缺陷)
**问题**: 职责边界不清，循环依赖严重
```
当前混乱结构:
src/
├── core/ (18个子包，职责混乱)
│   ├── actor/ ✅ 核心逻辑
│   ├── mailbox/ ❌ 应属于基础设施
│   ├── memory/ ❌ 应属于基础设施
│   ├── monitoring/ ❌ 应属于横切关注点
│   └── zerocopy/ ❌ 应属于基础设施
├── runtime/ (与core重叠)
├── mailbox/ (与core/mailbox重复)
└── 16个顶级包全量导出
```

#### 2. 缺乏统一的Actor层次结构 (架构缺陷)
**问题**: 没有Guardian Actor概念，缺乏系统级监督
- 无系统守护者Actor
- 无明确的Actor层次结构
- 监督策略分散，无统一管理

#### 3. 消息传递路径低效 (性能缺陷)
**问题**: 消息传递存在多次拷贝和序列化
- 缺乏零拷贝消息传递
- 序列化开销大
- 无消息池化机制

#### 4. 调度器设计落后 (性能缺陷)
**问题**: 调度器未充分利用仓颉并发特性
- 无工作窃取算法
- 无NUMA感知调度
- 无优先级调度

#### 5. 监督系统不完整 (可靠性缺陷)
**问题**: 监督策略实现简陋
- 无DeathWatch机制
- 无系统级故障恢复
- 监督树不完整

## 🏗️ 彻底重构架构设计

### 核心设计原则
1. **仓颉原生**: 充分利用仓颉语言特性
2. **零拷贝优先**: 最小化内存分配和拷贝
3. **类型安全**: 编译时类型检查
4. **高性能**: 针对高吞吐量低延迟优化
5. **云原生**: 为分布式环境设计

### 新架构层次设计
```
CActor 6.0 架构:
├── Foundation Layer (基础层)
│   ├── Memory Management (内存管理)
│   ├── Concurrency Primitives (并发原语)
│   ├── Serialization (序列化)
│   └── Network Transport (网络传输)
├── Core Layer (核心层)
│   ├── Actor System (Actor系统)
│   ├── Message System (消息系统)
│   ├── Supervision System (监督系统)
│   └── Lifecycle Management (生命周期管理)
├── Runtime Layer (运行时层)
│   ├── Dispatcher System (调度系统)
│   ├── Mailbox System (邮箱系统)
│   ├── Scheduler System (定时器系统)
│   └── Execution Context (执行上下文)
├── Pattern Layer (模式层)
│   ├── Ask Pattern (请求响应模式)
│   ├── Routing System (路由系统)
│   ├── Circuit Breaker (断路器)
│   └── Backpressure (背压控制)
├── Distribution Layer (分布式层)
│   ├── Remote System (远程系统)
│   ├── Cluster Management (集群管理)
│   ├── Persistence (持久化)
│   └── Streaming (流处理)
└── Integration Layer (集成层)
    ├── Configuration (配置管理)
    ├── Monitoring (监控系统)
    ├── Logging (日志系统)
    └── Testing Framework (测试框架)
```

## 🚀 Phase 1: Foundation Layer 重构 (第1-2周)

### 1.1 内存管理系统重构
**目标**: 实现零拷贝、NUMA感知的内存管理

```cangjie
// src/foundation/memory/memory_manager.cj
public interface MemoryManager {
    func allocate(size: UInt64, alignment: UInt64): MemoryRegion
    func deallocate(region: MemoryRegion): Unit
    func createPool<T>(capacity: UInt64): ObjectPool<T>
}

public class NumaAwareMemoryManager <: MemoryManager {
    private let numaNodes: Array<NumaNode>
    private let threadLocalPools: ThreadLocal<MemoryPool>
    
    public func allocate(size: UInt64, alignment: UInt64): MemoryRegion {
        // NUMA感知的内存分配
        let currentNode = getCurrentNumaNode()
        return currentNode.allocate(size, alignment)
    }
}
```

### 1.2 并发原语重构
**目标**: 基于仓颉并发特性的高性能原语

```cangjie
// src/foundation/concurrency/primitives.cj
public class LockFreeQueue<T> {
    private let head: AtomicPtr<Node<T>>
    private let tail: AtomicPtr<Node<T>>
    
    public func enqueue(item: T): Bool {
        // 无锁队列实现
    }
    
    public func dequeue(): Option<T> {
        // 无锁出队实现
    }
}

public class WorkStealingQueue<T> {
    private let items: Array<AtomicPtr<T>>
    private let head: AtomicUInt64
    private let tail: AtomicUInt64
    
    public func push(item: T): Bool {
        // 工作窃取队列实现
    }
    
    public func steal(): Option<T> {
        // 工作窃取实现
    }
}
```

### 1.3 零拷贝序列化系统
**目标**: 高性能的零拷贝序列化框架

```cangjie
// src/foundation/serialization/zero_copy_serializer.cj
public interface ZeroCopySerializer {
    func serialize<T>(obj: T, buffer: MutableBuffer): SerializationResult
    func deserialize<T>(buffer: Buffer): DeserializationResult<T>
}

public class CangjieNativeSerializer <: ZeroCopySerializer {
    public func serialize<T>(obj: T, buffer: MutableBuffer): SerializationResult {
        // 基于仓颉反射的零拷贝序列化
        let metadata = getTypeMetadata<T>()
        return serializeWithMetadata(obj, metadata, buffer)
    }
}
```

## 🎭 Phase 2: Core Layer 彻底重构 (第3-4周)

### 2.1 Actor系统核心重构
**目标**: 实现Akka级别的Actor系统

```cangjie
// src/core/actor_system/actor_system.cj
public class CActorSystem {
    private let guardian: GuardianActor
    private let systemGuardian: SystemGuardianActor
    private let userGuardian: UserGuardianActor
    private let dispatchers: DispatcherRegistry
    private let mailboxes: MailboxRegistry
    private let supervision: SupervisionSystem
    
    public func actorOf<T>(props: Props<T>, name: String): ActorRef<T> where T <: Actor {
        return userGuardian.actorOf(props, name)
    }
}

public class GuardianActor <: Actor {
    // 系统顶级守护者Actor
    public func receive(message: SystemMessage): MessageResult {
        match (message) {
            case CreateActor(props, name) => createChildActor(props, name)
            case TerminateSystem => terminateSystem()
            case _ => MessageResult.Unhandled
        }
    }
}
```

### 2.2 消息系统重构
**目标**: 类型安全的零拷贝消息系统

```cangjie
// src/core/message/message_system.cj
public interface Message {
    func getMessageId(): MessageId
    func getTimestamp(): Timestamp
    func getSender(): Option<ActorRef>
}

public class TypedMessage<T> <: Message {
    private let payload: T
    private let metadata: MessageMetadata
    
    public func getPayload(): T { payload }
}

public class MessageEnvelope<T> {
    private let message: TypedMessage<T>
    private let recipient: ActorRef<T>
    private let sender: Option<ActorRef>
    
    public func deliver(): DeliveryResult {
        return recipient.tell(message, sender)
    }
}
```

### 2.3 监督系统重构
**目标**: 完整的监督树和故障恢复机制

```cangjie
// src/core/supervision/supervision_system.cj
public class SupervisionSystem {
    private let strategies: Map<ActorPath, SupervisionStrategy>
    private let deathWatch: DeathWatchSystem
    
    public func supervise(child: ActorRef, strategy: SupervisionStrategy): Unit {
        strategies.put(child.path, strategy)
        deathWatch.watch(child)
    }
    
    public func handleFailure(failed: ActorRef, cause: Exception): SupervisionDirective {
        let strategy = strategies.get(failed.path).getOrElse(defaultStrategy)
        return strategy.decide(cause)
    }
}

public enum SupervisionDirective {
    | Resume      // 恢复Actor
    | Restart     // 重启Actor
    | Stop        // 停止Actor
    | Escalate    // 上报给父Actor
}
```

## ⚡ Phase 3: Runtime Layer 高性能重构 (第5-6周)

### 3.1 调度器系统重构
**目标**: 工作窃取、NUMA感知的高性能调度器

```cangjie
// src/runtime/dispatcher/work_stealing_dispatcher.cj
public class WorkStealingDispatcher <: MessageDispatcher {
    private let workers: Array<WorkerThread>
    private let globalQueue: LockFreeQueue<MessageEnvelope>
    private let scheduler: WorkStealingScheduler
    
    public func dispatch(envelope: MessageEnvelope): Unit {
        // 优先尝试本地队列
        let currentWorker = getCurrentWorker()
        if (!currentWorker.localQueue.offer(envelope)) {
            // 本地队列满，放入全局队列
            globalQueue.enqueue(envelope)
        }
    }
}

public class WorkerThread {
    private let localQueue: WorkStealingQueue<MessageEnvelope>
    private let dispatcher: WorkStealingDispatcher
    
    public func run(): Unit {
        while (!shouldStop()) {
            // 1. 处理本地队列
            match (localQueue.pop()) {
                case Some(envelope) => processMessage(envelope)
                case None => 
                    // 2. 尝试从全局队列获取
                    match (dispatcher.globalQueue.dequeue()) {
                        case Some(envelope) => processMessage(envelope)
                        case None => 
                            // 3. 尝试工作窃取
                            tryStealWork()
                    }
            }
        }
    }
}
```

### 3.2 邮箱系统重构
**目标**: 多种高性能邮箱实现

```cangjie
// src/runtime/mailbox/mailbox_system.cj
public interface Mailbox<T> {
    func enqueue(message: T): EnqueueResult
    func dequeue(): Option<T>
    func size(): UInt64
    func isEmpty(): Bool
}

public class RingBufferMailbox<T> <: Mailbox<T> {
    private let buffer: Array<AtomicPtr<T>>
    private let head: AtomicUInt64
    private let tail: AtomicUInt64
    private let mask: UInt64
    
    public func enqueue(message: T): EnqueueResult {
        let currentTail = tail.load()
        let nextTail = (currentTail + 1) & mask
        
        if (nextTail == head.load()) {
            return EnqueueResult.Full
        }
        
        buffer[currentTail].store(message)
        tail.store(nextTail)
        return EnqueueResult.Success
    }
}
```

## 📋 实施时间表

### Week 1-2: Foundation Layer
- [ ] 内存管理系统重构
- [ ] 并发原语实现
- [ ] 零拷贝序列化系统
- [ ] 网络传输层重构

### Week 3-4: Core Layer  
- [ ] Actor系统核心重构
- [ ] 消息系统重构
- [ ] 监督系统重构
- [ ] 生命周期管理重构

### Week 5-6: Runtime Layer
- [ ] 调度器系统重构
- [ ] 邮箱系统重构
- [ ] 定时器系统重构
- [ ] 执行上下文重构

### Week 7-8: Pattern Layer
- [ ] Ask模式重构
- [ ] 路由系统重构
- [ ] 断路器重构
- [ ] 背压控制重构

### Week 9-10: Distribution Layer
- [ ] 远程系统重构
- [ ] 集群管理重构
- [ ] 持久化系统重构
- [ ] 流处理系统重构

### Week 11-12: Integration & Testing
- [ ] 配置管理重构
- [ ] 监控系统重构
- [ ] 测试框架重构
- [ ] 性能基准测试

## 🎯 预期成果

### 性能目标
- **消息吞吐量**: 10,000,000+ 消息/秒 (当前5,000,000)
- **消息延迟**: < 0.0001毫秒 (当前0.0002毫秒)
- **内存占用**: < 50MB启动内存 (当前300MB+)
- **CPU利用率**: 95%+ 多核利用率

### 架构质量目标
- **包耦合度**: < 0.1 (当前0.85)
- **代码重复率**: < 1% (当前22%)
- **测试覆盖率**: > 95% (当前60%)
- **文档覆盖率**: > 95% (当前<25%)

## 🔧 关键技术实现细节

### 4.1 零拷贝消息传递实现
**核心思想**: 消息在整个传递路径中避免不必要的拷贝

```cangjie
// src/foundation/message/zero_copy_message.cj
public class ZeroCopyMessage<T> {
    private let sharedBuffer: SharedMemoryRegion
    private let offset: UInt64
    private let size: UInt64
    private let refCount: AtomicUInt64

    public func getPayload(): T {
        // 直接从共享内存读取，无拷贝
        return deserializeFromBuffer<T>(sharedBuffer, offset, size)
    }

    public func clone(): ZeroCopyMessage<T> {
        // 增加引用计数，无实际拷贝
        refCount.fetchAdd(1)
        return ZeroCopyMessage(sharedBuffer, offset, size, refCount)
    }
}

public class MessagePassingOptimizer {
    public func optimizeMessagePath(message: Message, target: ActorRef): PassingStrategy {
        let messageSize = message.getSerializedSize()
        let targetLocation = target.getLocation()

        return match (messageSize, targetLocation) {
            case (size, Local) if size < 1024 => PassingStrategy.DirectCopy
            case (size, Local) if size >= 1024 => PassingStrategy.ZeroCopy
            case (_, Remote) => PassingStrategy.NetworkSerialization
            case (_, Cluster) => PassingStrategy.ClusterOptimized
        }
    }
}
```

### 4.2 NUMA感知调度器实现
**核心思想**: 充分利用现代多核CPU的NUMA架构

```cangjie
// src/runtime/scheduler/numa_aware_scheduler.cj
public class NumaAwareScheduler {
    private let numaTopology: NumaTopology
    private let nodeSchedulers: Array<NodeScheduler>
    private let affinityManager: CpuAffinityManager

    public func scheduleActor(actor: ActorRef): SchedulingResult {
        // 1. 获取Actor的内存访问模式
        let memoryPattern = analyzeMemoryPattern(actor)

        // 2. 选择最优NUMA节点
        let optimalNode = selectOptimalNode(memoryPattern)

        // 3. 在该节点上调度Actor
        return nodeSchedulers[optimalNode].schedule(actor)
    }

    private func selectOptimalNode(pattern: MemoryAccessPattern): UInt32 {
        var bestNode: UInt32 = 0
        var bestScore: Float64 = 0.0

        for (nodeId in 0..numaTopology.nodeCount) {
            let score = calculateNodeScore(nodeId, pattern)
            if (score > bestScore) {
                bestScore = score
                bestNode = nodeId
            }
        }

        return bestNode
    }
}

public class NodeScheduler {
    private let nodeId: UInt32
    private let cpuCores: Array<CpuCore>
    private let localMemory: MemoryPool
    private let workStealingQueues: Array<WorkStealingQueue<Task>>

    public func schedule(actor: ActorRef): SchedulingResult {
        // 在本NUMA节点内进行工作窃取调度
        let leastLoadedCore = findLeastLoadedCore()
        return leastLoadedCore.schedule(actor)
    }
}
```

### 4.3 类型安全的Actor系统实现
**核心思想**: 编译时类型检查，运行时零开销

```cangjie
// src/core/actor/typed_actor_system.cj
public interface TypedActor<TMessage> where TMessage <: Message {
    func receive(message: TMessage, context: ActorContext<TMessage>): Behavior<TMessage>
}

public enum Behavior<TMessage> where TMessage <: Message {
    | Same                           // 保持当前行为
    | Become(Behavior<TMessage>)     // 切换到新行为
    | Stop                          // 停止Actor
    | Unhandled                     // 未处理消息
}

public class TypedActorRef<TMessage> where TMessage <: Message {
    private let path: ActorPath
    private let mailbox: TypedMailbox<TMessage>
    private let dispatcher: MessageDispatcher

    public func tell(message: TMessage): Unit {
        let envelope = MessageEnvelope(message, this, None)
        dispatcher.dispatch(envelope)
    }

    public func ask<TResponse>(message: TMessage): Future<TResponse> where TResponse <: Message {
        let askMessage = AskMessage(message, generateRequestId())
        let future = createFuture<TResponse>()

        // 注册响应处理器
        registerResponseHandler(askMessage.requestId, future)

        tell(askMessage)
        return future
    }
}

// 编译时类型检查的消息路由
public macro typed_receive(messageType: Type, handler: Tokens): Tokens {
    return quote(
        match (message) {
            case msg: $(messageType) => $(handler)(msg)
            case _ => Behavior.Unhandled
        }
    )
}
```

### 4.4 高性能监督系统实现
**核心思想**: 快速故障检测和恢复

```cangjie
// src/core/supervision/fast_supervision.cj
public class FastSupervisionSystem {
    private let supervisionTree: SupervisionTree
    private let failureDetector: FailureDetector
    private let recoveryManager: RecoveryManager

    public func handleActorFailure(failed: ActorRef, cause: Exception): Unit {
        // 1. 快速故障隔离
        isolateFailedActor(failed)

        // 2. 分析故障类型
        let failureType = classifyFailure(cause)

        // 3. 执行恢复策略
        let strategy = supervisionTree.getStrategy(failed.path)
        let directive = strategy.decide(failureType, cause)

        // 4. 异步执行恢复
        recoveryManager.executeRecovery(failed, directive)
    }

    private func isolateFailedActor(failed: ActorRef): Unit {
        // 立即停止消息处理
        failed.mailbox.suspend()

        // 通知子Actor暂停
        for (child in failed.children) {
            child.mailbox.suspend()
        }

        // 记录故障事件
        supervisionTree.recordFailure(failed, getCurrentTimestamp())
    }
}

public class CircuitBreakerSupervision {
    private let circuitBreakers: Map<ActorPath, CircuitBreaker>

    public func wrapActorWithCircuitBreaker(actor: ActorRef): ActorRef {
        let breaker = CircuitBreaker(
            failureThreshold = 5,
            timeout = Duration.seconds(10),
            resetTimeout = Duration.seconds(60)
        )

        circuitBreakers.put(actor.path, breaker)
        return CircuitBreakerActorRef(actor, breaker)
    }
}
```

### 4.5 分布式Actor系统实现
**核心思想**: 位置透明的分布式Actor通信

```cangjie
// src/distribution/remote/remote_actor_system.cj
public class RemoteActorSystem {
    private let localSystem: ActorSystem
    private let remoteRegistry: RemoteActorRegistry
    private let networkTransport: NetworkTransport
    private let serializer: DistributedSerializer

    public func resolveRemoteActor(address: ActorAddress): Future<ActorRef> {
        return match (address.location) {
            case Local =>
                Future.successful(localSystem.actorSelection(address.path))
            case Remote(host, port) =>
                establishRemoteConnection(host, port).flatMap { connection =>
                    connection.resolveActor(address.path)
                }
        }
    }

    public func sendRemoteMessage(target: RemoteActorRef, message: Message): Unit {
        let serialized = serializer.serialize(message)
        let envelope = RemoteEnvelope(target.address, serialized)
        networkTransport.send(envelope)
    }
}

public class ClusterActorSystem {
    private let clusterManager: ClusterManager
    private let shardingSystem: ShardingSystem
    private let replicationManager: ReplicationManager

    public func createShardedActor<T>(
        shardKey: String,
        props: Props<T>
    ): ShardedActorRef<T> where T <: Actor {
        let shard = shardingSystem.getShard(shardKey)
        let actor = shard.createActor(props)

        // 设置复制
        replicationManager.setupReplication(actor, replicationFactor = 3)

        return ShardedActorRef(actor, shard)
    }
}
```

## 🧪 测试策略

### 5.1 性能基准测试
```cangjie
// tests/benchmarks/throughput_benchmark.cj
public class ThroughputBenchmark {
    public func benchmarkMessageThroughput(): BenchmarkResult {
        let system = CActorSystem.create("benchmark")
        let producer = system.actorOf(ProducerActor.props())
        let consumer = system.actorOf(ConsumerActor.props())

        let messageCount = 10_000_000
        let startTime = getCurrentTimeMicros()

        // 发送消息
        for (i in 0..messageCount) {
            producer.tell(ProduceMessage(i, consumer))
        }

        // 等待完成
        waitForCompletion(consumer, messageCount)

        let endTime = getCurrentTimeMicros()
        let duration = endTime - startTime
        let throughput = Float64(messageCount) / (Float64(duration) / 1_000_000.0)

        return BenchmarkResult(
            messageCount = messageCount,
            duration = duration,
            throughput = throughput
        )
    }
}
```

### 5.2 故障恢复测试
```cangjie
// tests/resilience/supervision_test.cj
public class SupervisionTest {
    public func testActorRecovery(): TestResult {
        let system = CActorSystem.create("test")
        let supervisor = system.actorOf(SupervisorActor.props())
        let child = supervisor.createChild(FailingActor.props())

        // 触发故障
        child.tell(CauseFailure())

        // 验证重启
        Thread.sleep(100) // 等待重启完成
        child.tell(Ping())

        let response = awaitResponse(Duration.seconds(1))
        return match (response) {
            case Some(Pong()) => TestResult.Success
            case _ => TestResult.Failure("Actor未能恢复")
        }
    }
}
```

## 📊 迁移策略

### 6.1 渐进式迁移路径
1. **Phase 1**: 新建foundation层，与现有代码并存
2. **Phase 2**: 逐步迁移core层组件
3. **Phase 3**: 替换runtime层实现
4. **Phase 4**: 迁移应用层代码
5. **Phase 5**: 清理旧代码

### 6.2 兼容性保证
```cangjie
// src/compatibility/legacy_adapter.cj
public class LegacyActorAdapter <: Actor {
    private let newActor: TypedActor<Message>

    public func receive(message: Message, context: ActorContext): MessageResult {
        let typedContext = TypedActorContext.fromLegacy(context)
        let behavior = newActor.receive(message, typedContext)

        return match (behavior) {
            case Behavior.Same => MessageResult.Handled
            case Behavior.Stop => MessageResult.Stop
            case Behavior.Unhandled => MessageResult.Unhandled
            case _ => MessageResult.Handled
        }
    }
}
```

## 🚨 风险控制与缓解策略

### 7.1 技术风险控制
**风险1: 性能回归风险**
- **缓解策略**: 每个Phase都有性能基准测试
- **回滚机制**: 保持旧实现，性能不达标立即回滚
- **监控指标**: 实时监控吞吐量、延迟、内存使用

**风险2: 仓颉语言特性依赖风险**
- **缓解策略**: 深度研究仓颉文档，与仓颉团队保持沟通
- **备选方案**: 为关键特性准备fallback实现
- **验证机制**: 每个特性都有独立的验证测试

**风险3: 复杂度管理风险**
- **缓解策略**: 严格的模块化设计，清晰的接口边界
- **代码审查**: 每个模块都要经过架构审查
- **文档要求**: 每个组件都要有详细的设计文档

### 7.2 项目风险控制
**风险1: 时间进度风险**
- **缓解策略**: 分阶段交付，每个Phase独立可用
- **里程碑控制**: 每周进度检查，及时调整计划
- **资源预留**: 预留20%的缓冲时间

**风险2: 团队协作风险**
- **缓解策略**: 详细的接口规范，标准化的开发流程
- **沟通机制**: 每日站会，每周架构评审
- **知识共享**: 技术文档和代码注释标准化

### 7.3 质量风险控制
**风险1: 测试覆盖不足风险**
- **缓解策略**: TDD开发模式，测试先行
- **覆盖率要求**: 单元测试覆盖率>95%，集成测试覆盖率>90%
- **自动化测试**: CI/CD流水线自动运行所有测试

**风险2: 内存安全风险**
- **缓解策略**: 充分利用仓颉的内存安全特性
- **静态分析**: 使用静态分析工具检查内存安全
- **压力测试**: 长时间运行测试检查内存泄漏

## 📈 成功指标与验收标准

### 8.1 性能指标验收标准
```cangjie
// tests/acceptance/performance_acceptance.cj
public struct PerformanceAcceptanceCriteria {
    public let minThroughput: UInt64 = 10_000_000  // 10M msg/sec
    public let maxLatency: UInt64 = 100            // 100 microseconds
    public let maxMemoryUsage: UInt64 = 50_000_000 // 50MB
    public let minCpuUtilization: Float64 = 0.95   // 95%

    public func validate(metrics: PerformanceMetrics): ValidationResult {
        let results = ArrayList<ValidationError>()

        if (metrics.throughput < minThroughput) {
            results.append(ValidationError.ThroughputTooLow(metrics.throughput, minThroughput))
        }

        if (metrics.averageLatency > maxLatency) {
            results.append(ValidationError.LatencyTooHigh(metrics.averageLatency, maxLatency))
        }

        if (metrics.memoryUsage > maxMemoryUsage) {
            results.append(ValidationError.MemoryUsageTooHigh(metrics.memoryUsage, maxMemoryUsage))
        }

        if (metrics.cpuUtilization < minCpuUtilization) {
            results.append(ValidationError.CpuUtilizationTooLow(metrics.cpuUtilization, minCpuUtilization))
        }

        return if (results.isEmpty()) {
            ValidationResult.Success
        } else {
            ValidationResult.Failure(results.toArray())
        }
    }
}
```

### 8.2 架构质量验收标准
```cangjie
// tests/acceptance/architecture_acceptance.cj
public struct ArchitectureAcceptanceCriteria {
    public let maxCouplingIndex: Float64 = 0.1     // 包耦合度<0.1
    public let minCohesionIndex: Float64 = 0.9     // 包内聚度>0.9
    public let maxCyclomaticComplexity: UInt32 = 10 // 圈复杂度<10
    public let minTestCoverage: Float64 = 0.95     // 测试覆盖率>95%

    public func validateArchitecture(codebase: Codebase): ArchitectureValidationResult {
        let couplingAnalysis = analyzeCoupling(codebase)
        let cohesionAnalysis = analyzeCohesion(codebase)
        let complexityAnalysis = analyzeComplexity(codebase)
        let coverageAnalysis = analyzeTestCoverage(codebase)

        return ArchitectureValidationResult(
            coupling = couplingAnalysis,
            cohesion = cohesionAnalysis,
            complexity = complexityAnalysis,
            coverage = coverageAnalysis
        )
    }
}
```

### 8.3 功能完整性验收标准
```cangjie
// tests/acceptance/functional_acceptance.cj
public class FunctionalAcceptanceTest {
    public func testActorLifecycle(): TestResult {
        // 测试Actor完整生命周期
        let system = CActorSystem.create("acceptance-test")
        let actor = system.actorOf(TestActor.props(), "test-actor")

        // 验证创建
        @Assert.IsNotNull(actor)

        // 验证消息处理
        actor.tell(TestMessage("hello"))
        let response = awaitResponse(Duration.seconds(1))
        @Assert.Equal("hello-processed", response)

        // 验证停止
        system.stop(actor)
        @Assert.IsTrue(actor.isTerminated())

        return TestResult.Success
    }

    public func testSupervisionStrategy(): TestResult {
        // 测试监督策略
        let system = CActorSystem.create("supervision-test")
        let supervisor = system.actorOf(SupervisorActor.props())
        let child = supervisor.createChild(FailingActor.props())

        // 触发故障
        child.tell(CauseException())

        // 验证重启
        Thread.sleep(100)
        child.tell(Ping())
        let response = awaitResponse(Duration.seconds(1))
        @Assert.Equal(Pong(), response)

        return TestResult.Success
    }

    public func testDistributedCommunication(): TestResult {
        // 测试分布式通信
        let system1 = CActorSystem.create("system1", port = 8001)
        let system2 = CActorSystem.create("system2", port = 8002)

        let localActor = system1.actorOf(LocalActor.props())
        let remoteActor = system2.actorOf(RemoteActor.props())

        // 跨系统通信
        localActor.tell(SendToRemote(remoteActor.address, "test-message"))

        let response = awaitResponse(Duration.seconds(5))
        @Assert.Equal("test-message-processed", response)

        return TestResult.Success
    }
}
```

## 🎯 项目交付物

### 9.1 代码交付物
- **Foundation Layer**: 内存管理、并发原语、序列化、网络传输
- **Core Layer**: Actor系统、消息系统、监督系统、生命周期管理
- **Runtime Layer**: 调度器、邮箱、定时器、执行上下文
- **Pattern Layer**: Ask模式、路由、断路器、背压控制
- **Distribution Layer**: 远程系统、集群管理、持久化、流处理
- **Integration Layer**: 配置、监控、日志、测试框架

### 9.2 文档交付物
- **架构设计文档**: 详细的系统架构和设计决策
- **API参考文档**: 完整的API文档和使用示例
- **性能调优指南**: 性能优化最佳实践
- **运维部署指南**: 生产环境部署和运维指南
- **迁移指南**: 从旧版本迁移的详细步骤

### 9.3 测试交付物
- **单元测试套件**: 覆盖率>95%的单元测试
- **集成测试套件**: 端到端的集成测试
- **性能基准测试**: 标准化的性能测试套件
- **压力测试套件**: 高负载和长时间运行测试
- **兼容性测试**: 多版本兼容性验证

---

## 🏆 项目愿景实现

**CActor 6.0将成为**:
- **世界级性能**: 10M+ msg/sec吞吐量，<0.1ms延迟
- **企业级可靠性**: 完整的故障恢复和监督机制
- **云原生架构**: 为现代分布式环境优化
- **开发者友好**: 类型安全、易用的API
- **生态系统完整**: 丰富的工具和集成支持

通过这个彻底的架构重构，CActor将从一个功能性的Actor系统演进为一个真正的世界级高性能Actor框架，为仓颉语言生态系统贡献一个重要的基础设施组件，并展示仓颉语言在系统编程领域的强大能力。

**这不是一个简单的重构，而是一次架构革命。**

---

## 📁 全新包结构设计

基于6层架构设计，以下是CActor 6.0的完整包结构：

```
cactor/
├── foundation/                          # 基础层 - 零依赖的基础设施
│   ├── memory/                         # 内存管理子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── memory_manager.cj           # 内存管理器接口
│   │   ├── numa_memory_manager.cj      # NUMA感知内存管理器
│   │   ├── object_pool.cj              # 对象池实现
│   │   ├── memory_region.cj            # 内存区域抽象
│   │   ├── shared_memory.cj            # 共享内存实现
│   │   └── memory_metrics.cj           # 内存使用指标
│   ├── concurrency/                    # 并发原语子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── atomic_primitives.cj        # 原子操作原语
│   │   ├── lock_free_queue.cj          # 无锁队列
│   │   ├── work_stealing_queue.cj      # 工作窃取队列
│   │   ├── mpsc_queue.cj               # 多生产者单消费者队列
│   │   ├── ring_buffer.cj              # 环形缓冲区
│   │   ├── hazard_pointer.cj           # 危险指针
│   │   └── thread_local_storage.cj     # 线程本地存储
│   ├── serialization/                  # 序列化子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── serializer.cj               # 序列化器接口
│   │   ├── zero_copy_serializer.cj     # 零拷贝序列化器
│   │   ├── cangjie_native_serializer.cj # 仓颉原生序列化器
│   │   ├── binary_serializer.cj        # 二进制序列化器
│   │   ├── json_serializer.cj          # JSON序列化器
│   │   ├── compression.cj              # 压缩算法
│   │   └── serialization_buffer.cj     # 序列化缓冲区
│   ├── network/                        # 网络传输子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── transport.cj                # 传输层接口
│   │   ├── tcp_transport.cj            # TCP传输实现
│   │   ├── udp_transport.cj            # UDP传输实现
│   │   ├── websocket_transport.cj      # WebSocket传输实现
│   │   ├── connection_pool.cj          # 连接池
│   │   ├── network_codec.cj            # 网络编解码器
│   │   └── network_metrics.cj          # 网络指标
│   ├── time/                           # 时间子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── timestamp.cj                # 时间戳
│   │   ├── duration.cj                 # 时间间隔
│   │   ├── timer.cj                    # 定时器
│   │   └── clock.cj                    # 时钟抽象
│   └── pkg.cj                          # 基础层包导出
├── core/                               # 核心层 - Actor系统核心抽象
│   ├── actor/                          # Actor子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── actor.cj                    # Actor接口
│   │   ├── typed_actor.cj              # 类型安全Actor
│   │   ├── actor_ref.cj                # Actor引用
│   │   ├── typed_actor_ref.cj          # 类型安全Actor引用
│   │   ├── actor_path.cj               # Actor路径
│   │   ├── actor_selection.cj          # Actor选择器
│   │   ├── props.cj                    # Actor属性配置
│   │   ├── behavior.cj                 # Actor行为
│   │   ├── lifecycle.cj                # Actor生命周期
│   │   └── actor_factory.cj            # Actor工厂
│   ├── message/                        # 消息子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── message.cj                  # 消息接口
│   │   ├── typed_message.cj            # 类型安全消息
│   │   ├── message_envelope.cj         # 消息信封
│   │   ├── system_message.cj           # 系统消息
│   │   ├── user_message.cj             # 用户消息
│   │   ├── message_metadata.cj         # 消息元数据
│   │   ├── message_id.cj               # 消息ID
│   │   ├── zero_copy_message.cj        # 零拷贝消息
│   │   └── message_pool.cj             # 消息池
│   ├── system/                         # Actor系统子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── actor_system.cj             # Actor系统接口
│   │   ├── typed_actor_system.cj       # 类型安全Actor系统
│   │   ├── guardian_actor.cj           # 守护者Actor
│   │   ├── system_guardian.cj          # 系统守护者
│   │   ├── user_guardian.cj            # 用户守护者
│   │   ├── dead_letter_office.cj       # 死信办公室
│   │   ├── actor_registry.cj           # Actor注册表
│   │   └── system_settings.cj          # 系统设置
│   ├── supervision/                    # 监督子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── supervision_strategy.cj     # 监督策略
│   │   ├── supervision_directive.cj    # 监督指令
│   │   ├── supervision_tree.cj         # 监督树
│   │   ├── death_watch.cj              # 死亡监视
│   │   ├── failure_detector.cj         # 故障检测器
│   │   ├── recovery_manager.cj         # 恢复管理器
│   │   ├── escalation_handler.cj       # 升级处理器
│   │   └── supervision_metrics.cj      # 监督指标
│   ├── context/                        # 上下文子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── actor_context.cj            # Actor上下文
│   │   ├── typed_actor_context.cj      # 类型安全Actor上下文
│   │   ├── execution_context.cj        # 执行上下文
│   │   ├── context_factory.cj          # 上下文工厂
│   │   └── context_metrics.cj          # 上下文指标
│   └── pkg.cj                          # 核心层包导出
├── runtime/                            # 运行时层 - 高性能执行引擎
│   ├── dispatcher/                     # 调度器子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── message_dispatcher.cj       # 消息调度器接口
│   │   ├── work_stealing_dispatcher.cj # 工作窃取调度器
│   │   ├── thread_pool_dispatcher.cj   # 线程池调度器
│   │   ├── single_thread_dispatcher.cj # 单线程调度器
│   │   ├── pinned_dispatcher.cj        # 固定线程调度器
│   │   ├── dispatcher_registry.cj      # 调度器注册表
│   │   ├── dispatcher_configurator.cj  # 调度器配置器
│   │   ├── worker_thread.cj            # 工作线程
│   │   ├── numa_aware_scheduler.cj     # NUMA感知调度器
│   │   └── dispatcher_metrics.cj       # 调度器指标
│   ├── mailbox/                        # 邮箱子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── mailbox.cj                  # 邮箱接口
│   │   ├── typed_mailbox.cj            # 类型安全邮箱
│   │   ├── unbounded_mailbox.cj        # 无界邮箱
│   │   ├── bounded_mailbox.cj          # 有界邮箱
│   │   ├── priority_mailbox.cj         # 优先级邮箱
│   │   ├── ring_buffer_mailbox.cj      # 环形缓冲区邮箱
│   │   ├── batching_mailbox.cj         # 批处理邮箱
│   │   ├── lock_free_mailbox.cj        # 无锁邮箱
│   │   ├── mailbox_registry.cj         # 邮箱注册表
│   │   ├── mailbox_factory.cj          # 邮箱工厂
│   │   └── mailbox_metrics.cj          # 邮箱指标
│   ├── scheduler/                      # 定时器子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── scheduler.cj                # 调度器接口
│   │   ├── hash_wheel_timer.cj         # 哈希轮定时器
│   │   ├── hierarchical_timer.cj       # 分层定时器
│   │   ├── cancellable.cj              # 可取消任务
│   │   ├── scheduled_task.cj           # 调度任务
│   │   └── scheduler_metrics.cj        # 调度器指标
│   ├── execution/                      # 执行子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── executor.cj                 # 执行器接口
│   │   ├── thread_pool_executor.cj     # 线程池执行器
│   │   ├── coroutine_executor.cj       # 协程执行器
│   │   ├── task.cj                     # 任务抽象
│   │   ├── task_queue.cj               # 任务队列
│   │   └── execution_metrics.cj        # 执行指标
│   └── pkg.cj                          # 运行时层包导出
├── patterns/                           # 模式层 - 高级Actor模式
│   ├── ask/                            # Ask模式子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── ask_pattern.cj              # Ask模式接口
│   │   ├── ask_message.cj              # Ask消息
│   │   ├── ask_response.cj             # Ask响应
│   │   ├── ask_future.cj               # Ask Future
│   │   ├── ask_timeout.cj              # Ask超时
│   │   ├── ask_pattern_manager.cj      # Ask模式管理器
│   │   └── ask_metrics.cj              # Ask指标
│   ├── routing/                        # 路由子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── router.cj                   # 路由器接口
│   │   ├── round_robin_router.cj       # 轮询路由器
│   │   ├── random_router.cj            # 随机路由器
│   │   ├── consistent_hash_router.cj   # 一致性哈希路由器
│   │   ├── broadcast_router.cj         # 广播路由器
│   │   ├── scatter_gather_router.cj    # 分散聚集路由器
│   │   ├── adaptive_router.cj          # 自适应路由器
│   │   ├── routing_logic.cj            # 路由逻辑
│   │   ├── routee.cj                   # 路由目标
│   │   └── routing_metrics.cj          # 路由指标
│   ├── circuit_breaker/                # 断路器子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── circuit_breaker.cj          # 断路器接口
│   │   ├── circuit_breaker_state.cj    # 断路器状态
│   │   ├── failure_detector.cj         # 故障检测器
│   │   ├── circuit_breaker_config.cj   # 断路器配置
│   │   └── circuit_breaker_metrics.cj  # 断路器指标
│   ├── backpressure/                   # 背压子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── backpressure_strategy.cj    # 背压策略
│   │   ├── flow_control.cj             # 流量控制
│   │   ├── rate_limiter.cj             # 速率限制器
│   │   ├── buffer_overflow_strategy.cj # 缓冲区溢出策略
│   │   └── backpressure_metrics.cj     # 背压指标
│   └── pkg.cj                          # 模式层包导出
├── distribution/                       # 分布式层 - 分布式Actor系统
│   ├── remote/                         # 远程子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── remote_actor_system.cj      # 远程Actor系统
│   │   ├── remote_actor_ref.cj         # 远程Actor引用
│   │   ├── remote_message.cj           # 远程消息
│   │   ├── remote_transport.cj         # 远程传输
│   │   ├── remote_serializer.cj        # 远程序列化器
│   │   ├── remote_address.cj           # 远程地址
│   │   ├── remote_connection.cj        # 远程连接
│   │   ├── remote_registry.cj          # 远程注册表
│   │   └── remote_metrics.cj           # 远程指标
│   ├── cluster/                        # 集群子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── cluster_manager.cj          # 集群管理器
│   │   ├── cluster_member.cj           # 集群成员
│   │   ├── cluster_membership.cj       # 集群成员关系
│   │   ├── cluster_gossip.cj           # 集群Gossip协议
│   │   ├── cluster_heartbeat.cj        # 集群心跳
│   │   ├── cluster_leader_election.cj  # 集群领导者选举
│   │   ├── cluster_sharding.cj         # 集群分片
│   │   ├── cluster_singleton.cj        # 集群单例
│   │   └── cluster_metrics.cj          # 集群指标
│   ├── persistence/                    # 持久化子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── persistent_actor.cj         # 持久化Actor
│   │   ├── event_store.cj              # 事件存储
│   │   ├── snapshot_store.cj           # 快照存储
│   │   ├── journal.cj                  # 日志
│   │   ├── event_sourcing.cj           # 事件溯源
│   │   ├── persistence_id.cj           # 持久化ID
│   │   ├── recovery_strategy.cj        # 恢复策略
│   │   └── persistence_metrics.cj      # 持久化指标
│   ├── streaming/                      # 流处理子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── stream.cj                   # 流接口
│   │   ├── source.cj                   # 数据源
│   │   ├── sink.cj                     # 数据汇
│   │   ├── flow.cj                     # 数据流
│   │   ├── graph.cj                    # 流图
│   │   ├── materialization.cj          # 物化
│   │   ├── stream_supervisor.cj        # 流监督器
│   │   └── streaming_metrics.cj        # 流处理指标
│   └── pkg.cj                          # 分布式层包导出
├── integration/                        # 集成层 - 系统集成和工具
│   ├── configuration/                  # 配置子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── config.cj                   # 配置接口
│   │   ├── config_manager.cj           # 配置管理器
│   │   ├── config_source.cj            # 配置源
│   │   ├── file_config_source.cj       # 文件配置源
│   │   ├── env_config_source.cj        # 环境变量配置源
│   │   ├── remote_config_source.cj     # 远程配置源
│   │   ├── config_validator.cj         # 配置验证器
│   │   └── config_metrics.cj           # 配置指标
│   ├── monitoring/                     # 监控子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── metrics.cj                  # 指标接口
│   │   ├── metric_registry.cj          # 指标注册表
│   │   ├── counter.cj                  # 计数器
│   │   ├── gauge.cj                    # 仪表盘
│   │   ├── histogram.cj                # 直方图
│   │   ├── timer.cj                    # 计时器
│   │   ├── health_check.cj             # 健康检查
│   │   ├── performance_monitor.cj      # 性能监控器
│   │   └── monitoring_exporter.cj      # 监控导出器
│   ├── logging/                        # 日志子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── logger.cj                   # 日志器接口
│   │   ├── log_level.cj                # 日志级别
│   │   ├── log_event.cj                # 日志事件
│   │   ├── log_appender.cj             # 日志追加器
│   │   ├── console_appender.cj         # 控制台追加器
│   │   ├── file_appender.cj            # 文件追加器
│   │   ├── remote_appender.cj          # 远程追加器
│   │   ├── log_formatter.cj            # 日志格式化器
│   │   └── structured_logging.cj       # 结构化日志
│   ├── testing/                        # 测试子系统
│   │   ├── pkg.cj                      # 包导出
│   │   ├── test_kit.cj                 # 测试工具包
│   │   ├── test_probe.cj               # 测试探针
│   │   ├── test_actor_system.cj        # 测试Actor系统
│   │   ├── mock_actor.cj               # 模拟Actor
│   │   ├── test_scheduler.cj           # 测试调度器
│   │   ├── performance_test.cj         # 性能测试
│   │   ├── load_test.cj                # 负载测试
│   │   └── integration_test.cj         # 集成测试
│   └── pkg.cj                          # 集成层包导出
├── api/                                # API层 - 用户接口
│   ├── public/                         # 公共API
│   │   ├── pkg.cj                      # 包导出
│   │   ├── cactor.cj                   # 主要API入口
│   │   ├── actor_system_builder.cj     # Actor系统构建器
│   │   ├── typed_actor_system_builder.cj # 类型安全Actor系统构建器
│   │   ├── configuration_builder.cj    # 配置构建器
│   │   └── extension_registry.cj       # 扩展注册表
│   ├── extensions/                     # 扩展API
│   │   ├── pkg.cj                      # 包导出
│   │   ├── extension.cj                # 扩展接口
│   │   ├── extension_manager.cj        # 扩展管理器
│   │   ├── plugin_loader.cj            # 插件加载器
│   │   └── extension_registry.cj       # 扩展注册表
│   └── pkg.cj                          # API层包导出
├── examples/                           # 示例代码
│   ├── basic/                          # 基础示例
│   │   ├── hello_world.cj              # Hello World示例
│   │   ├── ping_pong.cj                # Ping Pong示例
│   │   ├── counter_actor.cj            # 计数器Actor示例
│   │   └── simple_supervision.cj       # 简单监督示例
│   ├── advanced/                       # 高级示例
│   │   ├── ask_pattern_demo.cj         # Ask模式示例
│   │   ├── routing_demo.cj             # 路由示例
│   │   ├── circuit_breaker_demo.cj     # 断路器示例
│   │   └── backpressure_demo.cj        # 背压示例
│   ├── distributed/                    # 分布式示例
│   │   ├── remote_actor_demo.cj        # 远程Actor示例
│   │   ├── cluster_demo.cj             # 集群示例
│   │   ├── persistence_demo.cj         # 持久化示例
│   │   └── streaming_demo.cj           # 流处理示例
│   └── performance/                    # 性能示例
│       ├── throughput_benchmark.cj     # 吞吐量基准测试
│       ├── latency_benchmark.cj        # 延迟基准测试
│       └── memory_benchmark.cj         # 内存基准测试
├── tests/                              # 测试代码
│   ├── unit/                           # 单元测试
│   │   ├── foundation/                 # 基础层测试
│   │   ├── core/                       # 核心层测试
│   │   ├── runtime/                    # 运行时层测试
│   │   ├── patterns/                   # 模式层测试
│   │   ├── distribution/               # 分布式层测试
│   │   └── integration/                # 集成层测试
│   ├── integration/                    # 集成测试
│   │   ├── actor_lifecycle_test.cj     # Actor生命周期测试
│   │   ├── supervision_test.cj         # 监督测试
│   │   ├── remote_communication_test.cj # 远程通信测试
│   │   └── cluster_test.cj             # 集群测试
│   ├── performance/                    # 性能测试
│   │   ├── throughput_test.cj          # 吞吐量测试
│   │   ├── latency_test.cj             # 延迟测试
│   │   ├── memory_test.cj              # 内存测试
│   │   └── scalability_test.cj         # 可扩展性测试
│   └── acceptance/                     # 验收测试
│       ├── functional_acceptance.cj    # 功能验收测试
│       ├── performance_acceptance.cj   # 性能验收测试
│       └── architecture_acceptance.cj  # 架构验收测试
├── docs/                               # 文档
│   ├── architecture/                   # 架构文档
│   ├── api/                            # API文档
│   ├── tutorials/                      # 教程
│   ├── guides/                         # 指南
│   └── examples/                       # 示例文档
├── tools/                              # 工具
│   ├── code_generator/                 # 代码生成器
│   ├── performance_profiler/           # 性能分析器
│   ├── dependency_analyzer/            # 依赖分析器
│   └── migration_tool/                 # 迁移工具
├── cjpm.toml                           # 项目配置
├── README.md                           # 项目说明
├── CHANGELOG.md                        # 变更日志
├── LICENSE                             # 许可证
└── CONTRIBUTING.md                     # 贡献指南
```

## 📋 包结构设计原则

### 1. **分层架构原则**
- **Foundation Layer**: 零依赖的基础设施，可独立使用
- **Core Layer**: 核心抽象，依赖Foundation Layer
- **Runtime Layer**: 高性能实现，依赖Core和Foundation
- **Patterns Layer**: 高级模式，依赖Runtime、Core、Foundation
- **Distribution Layer**: 分布式功能，依赖所有下层
- **Integration Layer**: 系统集成，依赖所有下层

### 2. **高内聚低耦合原则**
- 每个子系统内部高度相关
- 子系统间通过明确接口交互
- 避免循环依赖
- 最小化跨层依赖

### 3. **可扩展性原则**
- 插件化架构设计
- 扩展点明确定义
- 向后兼容性保证
- 模块化部署支持

### 4. **性能优先原则**
- 零拷贝设计
- 内存池化
- NUMA感知
- 无锁数据结构

### 5. **类型安全原则**
- 编译时类型检查
- 泛型设计
- 类型安全的消息传递
- 强类型配置

这个全新的包结构完全重新组织了CActor的架构，实现了世界级Actor框架的设计标准，为高性能、高可靠性、高可扩展性的Actor系统奠定了坚实的基础。
