# CActor 9.0 世界级Actor系统架构改造计划

## 📋 **执行摘要**

### **改造目标**
将CActor从基础Actor系统升级为世界级高性能Actor框架，参考Akka架构精髓，充分利用Cangjie语言特性，实现企业级生产标准。

### **核心问题**
1. **架构设计**: 当前ActorSystem过于简化，缺乏Guardian Actor层次结构
2. **性能瓶颈**: 4987 msg/s vs 目标50M msg/s，差距10,000倍
3. **企业特性**: 缺乏监控、配置管理、扩展机制等生产级功能

### **改造策略**
- **6个阶段**: Guardian Actor → 调度器 → 邮箱 → 监督 → 监控 → 配置
- **12周计划**: 每阶段2周，渐进式改造，确保向后兼容
- **性能目标**: 50M msg/s吞吐量，100μs延迟，1KB内存/Actor

### **关键创新**
- **Guardian Actor系统**: 实现Akka风格的监督树
- **企业级调度器**: Fork-Join、NUMA感知、工作窃取
- **高级邮箱系统**: 有界、优先级、暂存等多种类型
- **配置驱动架构**: HOCON配置文件，热重载支持
- **全面监控系统**: Prometheus集成，实时指标收集

### **预期成果**
- **性能提升**: 10,000倍吞吐量提升，达到世界级标准
- **企业就绪**: 完整的生产环境支持能力
- **生态价值**: 成为Cangjie语言核心基础设施

## 🎯 **战略愿景**

基于对当前CActor系统的深度分析和Akka、Actix、ProtoActor等世界级框架的研究，制定全面的架构改造计划。目标是将CActor打造成世界级的高性能Actor系统，充分利用Cangjie语言特性，实现生产级标准。

## 📊 **现状分析**

### ✅ **当前优势**
- **6层清晰架构**: Foundation → Core → Runtime → Patterns → Distribution → Integration
- **Foundation层零依赖**: 真正的分层架构，无循环依赖
- **编译成功**: 161个文件，36,947行高质量代码
- **基础功能完整**: Actor、消息、邮箱、调度器等核心组件
- **API 2.0**: 简化的用户接口

### ❌ **关键问题**
1. **架构设计问题**:
   - ActorSystem实现过于简单，缺乏企业级特性
   - 缺乏Guardian Actor概念和监督树
   - 配置系统不够灵活，硬编码过多
   - 扩展机制不完善

2. **性能瓶颈**:
   - 消息处理性能有限（当前4987 msg/s vs 目标5-50M msg/s）
   - 内存使用效率待优化
   - 调度器算法需要优化

3. **生产级特性缺失**:
   - 缺乏完整的监控和指标系统
   - 配置管理不够灵活
   - 缺乏热重载和动态配置
   - 错误处理和恢复机制不完善

## 🏗️ **Akka架构精髓分析**

### **核心设计原则**
1. **Actor层次结构**: 严格的监督树，每个Actor都有明确的父子关系
2. **位置透明**: ActorRef抽象，本地和远程Actor使用相同接口
3. **消息驱动**: 纯异步消息传递，无共享状态
4. **弹性设计**: Let-it-crash哲学，通过监督策略处理故障
5. **配置驱动**: 通过配置文件灵活配置所有组件

### **关键组件架构**
```scala
// Akka ActorSystem核心组件
ActorSystem {
  - Guardian Actor (系统根Actor)
  - Dispatcher Pool (调度器池)
  - Mailbox Factory (邮箱工厂)
  - Configuration (配置系统)
  - Extension Registry (扩展注册)
  - Event Bus (事件总线)
  - Scheduler (定时器)
  - Death Watch (死亡监视)
}
```

## 🚨 **关键架构问题分析**

### **❌ 当前设计的严重问题**

#### **1. 分层架构违反 (紧急修复)**
```
Foundation层依赖Core层 - 违反零依赖原则：
├── foundation.concurrency.mailbox.cj → import cactor.core.message.{Message, Envelope}
├── foundation.serialization.serializer.cj → import cactor.core.message.{Message}
└── foundation.network.transport.cj → import cactor.core.message.{Message, Envelope}

正确架构应该是：
Foundation (零依赖) ← Core ← Runtime ← Patterns ← Distribution ← Integration
```

#### **2. Runtime层职责混乱 (架构重构)**
```
问题：Runtime层缺乏统一的运行时管理
- SimpleActorSystem 功能不完整
- Guardian Actor系统放在Core层，应该在Runtime层实现
- 调度器、邮箱、Actor生命周期管理分散
- 缺乏统一的运行时入口

应该改为：
Runtime层 = 完整的Actor运行时系统 (包含Guardian、调度、生命周期管理)
Core层 = 纯抽象接口和数据结构
```

#### **3. Guardian Actor设计不完整 (功能缺陷)**
```
问题：Guardian Actor缺乏实际运行能力
- SystemGuardian.doCreateChild() 实现不完整
- 缺乏与调度器、邮箱的集成
- 没有真正的Actor生命周期管理
- 监督策略无法实际执行

需要：完整的Guardian Actor运行时实现
```

## 🚀 **CActor 9.0 架构改造计划**

### **Phase 1: 架构修复和Runtime层重构 (Week 1-2)**

#### **1.1 Foundation层依赖修复 (紧急)**
```cangjie
// 步骤1: 移除Foundation层对Core层的依赖
// 删除有问题的文件：
rm src/foundation/concurrency/mailbox.cj
rm src/foundation/concurrency/lockfree_mailbox.cj

// 步骤2: Foundation层只保留纯基础设施
// foundation.queue - 纯队列数据结构，无业务概念
// foundation.memory - 纯内存管理，无Actor概念
// foundation.serialization - 纯字节序列化，无Message概念
// foundation.network - 纯网络传输，无Envelope概念
```

#### **1.2 Runtime层统一运行时系统**
```cangjie
// 将Guardian Actor系统移到Runtime层，作为完整运行时的一部分
package cactor.runtime.system

public class CActorRuntime {
    // 统一的Actor运行时系统
    private let systemGuardian: RuntimeSystemGuardian
    private let userGuardian: RuntimeUserGuardian
    private let dispatcherPool: DispatcherPool
    private let mailboxFactory: MailboxFactory
    private let actorRegistry: ActorRegistry
    private let lifecycleManager: ActorLifecycleManager

    public func createActor(props: Props<Actor>, name: String): ActorRef
    public func stopActor(actorRef: ActorRef): Unit
    public func superviseActor(child: ActorRef, strategy: SupervisionStrategy): Unit
}

// Guardian Actor的Runtime实现
public class RuntimeSystemGuardian <: GuardianActor {
    private let runtime: CActorRuntime
    private let dispatcherPool: DispatcherPool
    private let mailboxFactory: MailboxFactory

    // 完整的Actor创建实现
    protected func doCreateChild(props: Props<Actor>, name: String): ActorRef {
        // 1. 创建Actor实例
        let actor = props.create()

        // 2. 分配调度器
        let dispatcher = dispatcherPool.selectDispatcher(actor)

        // 3. 创建邮箱
        let mailbox = mailboxFactory.createMailbox(actor)

        // 4. 创建ActorRef并启动
        let actorRef = runtime.createActorRef(actor, name, mailbox, dispatcher)

        // 5. 注册到运行时
        runtime.registerActor(actorRef)

        return actorRef
    }
}
```

#### **1.2 企业级ActorSystem**
```cangjie
public interface CActorSystem <: ActorSystem {
    // 配置管理
    func getConfig(): ActorSystemConfig
    func updateConfig(config: ActorSystemConfig): Unit
    
    // 扩展系统
    func registerExtension<T>(extension: T): Unit where T <: ActorSystemExtension
    func getExtension<T>(): Option<T> where T <: ActorSystemExtension
    
    // 监控和指标
    func getMetrics(): ActorSystemMetrics
    func getEventBus(): EventBus
    
    // 生命周期管理
    func whenTerminated(): Future<Unit>
    func terminate(timeout: Duration): Future<Unit>
}
```

#### **1.3 Core层纯抽象化**
```cangjie
// Core层只保留抽象接口和数据结构，无具体实现
package cactor.core

// 纯抽象接口
public interface Actor {
    func receive(message: Message, context: ActorContext): MessageResult
    prop name: String
    prop description: String
}

public interface ActorSystem {
    func actorOf(props: Props<Actor>, name: String): ActorRef
    func actorSelection(path: String): ActorSelection
    func terminate(): SimpleFuture<Unit>
}

public interface GuardianActor <: Actor {
    func createChild(props: Props<Actor>, name: String): ActorRef
    func supervise(child: ActorRef, strategy: SupervisionStrategy): Unit
    func getChildren(): Array<ActorRef>
}

// 纯数据结构
public struct ActorPath { ... }
public struct Props<T> { ... }
public interface Message { ... }
```

#### **1.4 Runtime层完整实现**
```cangjie
// Runtime层提供所有具体实现
package cactor.runtime.system

public class CActorSystem <: ActorSystem {
    private let runtime: CActorRuntime

    public init(name: String, config: ActorSystemConfig) {
        this.runtime = CActorRuntime(name, config)
    }

    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        return runtime.systemGuardian.createChild(props, name)
    }
}

// 配置驱动的运行时
public struct ActorSystemConfig {
    public let dispatchers: DispatcherConfig
    public let mailboxes: MailboxConfig
    public let supervision: SupervisionConfig
    public let monitoring: MonitoringConfig
}
```

### **Phase 2: 高性能调度器重构 (Week 3-4)**

#### **2.1 多层调度器架构**
```cangjie
public interface AdvancedDispatcher <: Dispatcher {
    func setThroughput(throughput: Int32): Unit
    func getThroughput(): Int32
    func getMetrics(): DispatcherMetrics
    func configureBatching(batchSize: Int32): Unit
}

// 实现多种调度器
public class ForkJoinDispatcher <: AdvancedDispatcher {
    // 基于Fork-Join池的高性能调度器
}

public class PinnedDispatcher <: AdvancedDispatcher {
    // 固定线程调度器，适用于阻塞操作
}

public class CallingThreadDispatcher <: AdvancedDispatcher {
    // 调用线程调度器，用于测试
}
```

#### **2.2 NUMA感知调度**
```cangjie
public class NUMADispatcher <: AdvancedDispatcher {
    private let numaNodes: Array<NUMANode>
    private let affinityManager: CPUAffinityManager
    
    public func scheduleOnNUMANode(task: ActorTask, nodeId: Int32): Unit
    public func optimizeForLocality(actorRef: ActorRef): Unit
}
```

### **Phase 3: 企业级邮箱系统 (Week 5-6)**

#### **3.1 多种邮箱实现**
```cangjie
// 参考Akka的邮箱类型
public interface MailboxType {
    func create(owner: ActorRef, system: ActorSystem): Mailbox
}

public class UnboundedMailboxType <: MailboxType {
    // 无界邮箱，基于ConcurrentLinkedQueue
}

public class BoundedMailboxType <: MailboxType {
    // 有界邮箱，支持背压
    private let capacity: Int32
    private let pushTimeOut: Duration
}

public class PriorityMailboxType <: MailboxType {
    // 优先级邮箱，支持消息优先级
    private let comparator: (Message, Message) -> Int32
}

public class StashingMailboxType <: MailboxType {
    // 支持消息暂存的邮箱
}
```

#### **3.2 邮箱工厂系统**
```cangjie
public class MailboxFactory {
    private let mailboxTypes: HashMap<String, MailboxType>
    
    public func registerMailboxType(name: String, mailboxType: MailboxType): Unit
    public func createMailbox(typeName: String, owner: ActorRef): Mailbox
    public func getDefaultMailbox(owner: ActorRef): Mailbox
}
```

### **Phase 4: 监督和容错增强 (Week 7-8)**

#### **4.1 高级监督策略**
```cangjie
public interface AdvancedSupervisionStrategy <: SupervisionStrategy {
    func handleFailure(child: ActorRef, cause: Exception, context: SupervisionContext): SupervisionDirective
    func escalate(failure: ActorFailure): Unit
    func getStatistics(): SupervisionStatistics
}

public class EscalatingSupervisionStrategy <: AdvancedSupervisionStrategy {
    // 升级策略，将失败向上传播
}

public class CircuitBreakerSupervisionStrategy <: AdvancedSupervisionStrategy {
    // 断路器监督策略
    private let circuitBreaker: CircuitBreaker
}
```

#### **4.2 死亡监视系统**
```cangjie
public interface DeathWatch {
    func watch(watcher: ActorRef, watchee: ActorRef): Unit
    func unwatch(watcher: ActorRef, watchee: ActorRef): Unit
    func publishTerminated(actor: ActorRef): Unit
}

public class DeathWatchExtension <: ActorSystemExtension, DeathWatch {
    private let watchers: ConcurrentHashMap<ActorRef, Set<ActorRef>>
}
```

### **Phase 5: 监控和指标系统 (Week 9-10)**

#### **5.1 全面指标收集**
```cangjie
public interface ActorSystemMetrics {
    func getActorCount(): Int64
    func getMessageThroughput(): Double
    func getAverageMessageLatency(): Duration
    func getMailboxSizes(): Map<String, Int64>
    func getDispatcherUtilization(): Map<String, Double>
}

public class PrometheusMetricsExtension <: ActorSystemExtension {
    // Prometheus指标导出
    public func exportMetrics(): String
    public func registerCustomMetric(name: String, metric: Metric): Unit
}
```

#### **5.2 事件总线系统**
```cangjie
public interface EventBus {
    func publish(event: Event): Unit
    func subscribe(subscriber: ActorRef, topic: String): Unit
    func unsubscribe(subscriber: ActorRef, topic: String): Unit
}

public class ActorEventBus <: EventBus {
    private let subscribers: ConcurrentHashMap<String, Set<ActorRef>>
    
    public func publishActorEvent(event: ActorLifecycleEvent): Unit
    public func publishSystemEvent(event: SystemEvent): Unit
}
```

### **Phase 6: 配置和扩展系统 (Week 11-12)**

#### **6.1 动态配置系统**
```cangjie
public interface ConfigurationProvider {
    func getConfig(path: String): Option<ConfigValue>
    func watchConfig(path: String, callback: (ConfigValue) -> Unit): Unit
    func updateConfig(path: String, value: ConfigValue): Unit
}

public class HotReloadConfigProvider <: ConfigurationProvider {
    // 支持热重载的配置提供者
    public func reloadConfiguration(): Unit
    public func validateConfiguration(): Bool
}
```

#### **6.2 扩展注册系统**
```cangjie
public interface ActorSystemExtension {
    func initialize(system: ActorSystem): Unit
    func shutdown(): Unit
}

public class ExtensionRegistry {
    private let extensions: ConcurrentHashMap<String, ActorSystemExtension>
    
    public func register<T>(extension: T): Unit where T <: ActorSystemExtension
    public func get<T>(): Option<T> where T <: ActorSystemExtension
    public func shutdown(): Unit
}
```

## 🎯 **性能目标**

### **吞吐量目标**
- **消息处理**: 5-50M msg/s (当前4987 msg/s，提升1000-10000倍)
- **Actor创建**: 100K actors/s
- **内存效率**: <1KB per Actor (当前未优化)

### **延迟目标**
- **消息延迟**: <100μs (P99)
- **Actor创建延迟**: <10μs
- **系统启动时间**: <1s

### **可扩展性目标**
- **并发Actor数**: 1M+ actors
- **集群节点数**: 100+ nodes
- **消息路由**: 支持复杂路由策略

## 📋 **实施计划**

### **Week 1-2: 架构修复和Runtime层重构**
- [ ] **紧急修复**: 移除Foundation层对Core层的依赖
- [ ] **架构重构**: 将Guardian Actor系统移到Runtime层
- [ ] **统一运行时**: 实现CActorRuntime统一管理系统
- [ ] **Core层纯化**: Core层只保留抽象接口和数据结构
- [ ] **Runtime完整实现**: Runtime层提供所有具体实现

### **Week 3-4: 调度器性能优化**
- [ ] 实现多种调度器类型
- [ ] 添加NUMA感知调度
- [ ] 优化工作窃取算法
- [ ] 性能基准测试

### **Week 5-6: 邮箱系统增强**
- [ ] 实现多种邮箱类型
- [ ] 添加邮箱工厂系统
- [ ] 优化内存使用
- [ ] 添加背压支持

### **Week 7-8: 监督容错增强**
- [ ] 实现高级监督策略
- [ ] 添加死亡监视系统
- [ ] 增强错误处理
- [ ] 容错测试

### **Week 9-10: 监控指标系统**
- [ ] 实现全面指标收集
- [ ] 添加事件总线
- [ ] 集成Prometheus
- [ ] 性能监控

### **Week 11-12: 配置扩展系统**
- [ ] 实现动态配置
- [ ] 完善扩展系统
- [ ] 热重载支持
- [ ] 生产部署

## 🔧 **关键技术创新**

### **1. Cangjie语言特性利用**
```cangjie
// 利用Cangjie的泛型和类型安全
public interface TypedActor<TMessage> <: Actor where TMessage <: Message {
    func receive(message: TMessage, context: ActorContext): MessageResult
}

// 利用Cangjie的模式匹配
public func handleMessage(message: Message): MessageResult {
    match (message) {
        case stringMsg: StringMessage => handleString(stringMsg)
        case numberMsg: NumberMessage => handleNumber(numberMsg)
        case _ => MessageResult.Unhandled
    }
}
```

### **2. 零拷贝消息传递**
```cangjie
public interface ZeroCopyMessage <: Message {
    func getBuffer(): ByteBuffer
    func transferOwnership(): ByteBuffer
}

public class ZeroCopyMailbox <: Mailbox {
    // 实现零拷贝消息传递
    public func enqueueZeroCopy(message: ZeroCopyMessage): Bool
}
```

### **3. 内存池优化**
```cangjie
public class ActorMemoryPool {
    private let actorPool: ObjectPool<Actor>
    private let messagePool: ObjectPool<Message>
    private let envelopePool: ObjectPool<Envelope>
    
    public func borrowActor<T>(): T where T <: Actor
    public func returnActor<T>(actor: T): Unit where T <: Actor
}
```

## 📊 **验收标准**

### **功能完整性**
- [ ] 所有Akka核心特性实现
- [ ] 100%向后兼容
- [ ] 完整的测试覆盖

### **性能指标**
- [ ] 消息吞吐量 ≥ 5M msg/s
- [ ] 消息延迟 ≤ 100μs (P99)
- [ ] 内存使用 ≤ 1KB per Actor
- [ ] 系统启动时间 ≤ 1s

### **生产就绪**
- [ ] 完整的监控系统
- [ ] 动态配置支持
- [ ] 热重载功能
- [ ] 故障恢复机制
- [ ] 完善的文档

## 🎉 **预期成果**

通过这次全面改造，CActor 9.0将成为：
- **世界级性能**: 达到Akka级别的性能指标
- **企业级特性**: 完整的生产环境支持
- **Cangjie原生**: 充分利用Cangjie语言特性
- **高度可扩展**: 支持大规模分布式部署
- **开发友好**: 简洁易用的API和完善的文档

这将使CActor成为Cangjie生态系统中的核心基础设施，为构建高性能、可扩展的并发应用提供强大支持。

## 🔍 **详细架构分析**

### **当前架构问题深度分析**

#### **1. ActorSystem设计缺陷**
```cangjie
// 当前问题：过于简化的ActorSystem
public class SimpleActorSystem <: ActorSystem {
    private let actors: ConcurrentHashMap<String, ActorRef>  // ❌ 扁平化管理
    private let actorCounter: AtomicInt64                    // ❌ 简单计数器

    // ❌ 缺少：
    // - Guardian Actor层次结构
    // - 配置系统
    // - 扩展机制
    // - 监控指标
    // - 事件总线
}
```

#### **2. 监督策略不完善**
```cangjie
// 当前问题：基础监督策略
public interface SupervisionStrategy {
    func decide(failure: ActorFailure): SupervisionDirective  // ❌ 过于简单

    // ❌ 缺少：
    // - 升级机制
    // - 统计信息
    // - 动态策略调整
    // - 断路器集成
}
```

#### **3. 配置系统硬编码**
```cangjie
// 当前问题：硬编码配置
let mailbox = FoundationMailbox(65535)  // ❌ 硬编码容量
return SimpleActorRef(name, actor, mailbox, this)  // ❌ 固定邮箱类型

// ❌ 缺少：
// - 配置文件支持
// - 动态配置
// - 环境变量支持
// - 配置验证
```

### **Akka架构深度对比**

#### **Akka ActorSystem核心组件**
```scala
// Akka的完整ActorSystem架构
class ActorSystemImpl extends ActorSystem {
  val guardian: ActorRef                    // ✅ 系统Guardian
  val systemGuardian: ActorRef             // ✅ 系统级Guardian
  val dispatchers: Dispatchers             // ✅ 调度器管理
  val mailboxes: Mailboxes                 // ✅ 邮箱工厂
  val eventBus: EventBus                   // ✅ 事件总线
  val scheduler: Scheduler                 // ✅ 定时器
  val deathWatch: DeathWatchExtension      // ✅ 死亡监视
  val extensions: ExtensionRegistry        // ✅ 扩展注册
  val settings: ActorSystemSettings        // ✅ 配置管理
}
```

#### **CActor 9.0目标架构**
```cangjie
// CActor 9.0的完整ActorSystem架构
public class CActorSystemImpl <: CActorSystem {
    private let systemGuardian: ActorRef              // ✅ 系统Guardian
    private let userGuardian: ActorRef                // ✅ 用户Guardian
    private let dispatcherRegistry: DispatcherRegistry // ✅ 调度器注册
    private let mailboxFactory: MailboxFactory        // ✅ 邮箱工厂
    private let eventBus: ActorEventBus               // ✅ 事件总线
    private let scheduler: ActorScheduler             // ✅ 定时器
    private let deathWatch: DeathWatchExtension       // ✅ 死亡监视
    private let extensionRegistry: ExtensionRegistry   // ✅ 扩展注册
    private let config: ActorSystemConfig             // ✅ 配置管理
    private let metrics: ActorSystemMetrics           // ✅ 指标收集
}
```

## 🚀 **核心组件详细设计**

### **1. Guardian Actor层次结构**

#### **1.1 系统Guardian设计**
```cangjie
public class SystemGuardian <: GuardianActor {
    private let userGuardian: ActorRef
    private let systemActors: ConcurrentHashMap<String, ActorRef>
    private let supervisionStrategy: SupervisionStrategy

    public init(system: ActorSystem) {
        this.supervisionStrategy = SystemSupervisionStrategy()
        this.userGuardian = createUserGuardian()
        this.systemActors = ConcurrentHashMap<String, ActorRef>()
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case createMsg: CreateSystemActor =>
                createSystemActor(createMsg.props, createMsg.name)
                MessageResult.Handled
            case terminateMsg: TerminateSystemActor =>
                terminateSystemActor(terminateMsg.name)
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }

    private func createSystemActor(props: Props<Actor>, name: String): ActorRef {
        let actorRef = context.actorOf(props, name)
        systemActors.put(name, actorRef)
        context.watch(actorRef)  // 监视系统Actor
        return actorRef
    }
}
```

#### **1.2 用户Guardian设计**
```cangjie
public class UserGuardian <: GuardianActor {
    private let userActors: ConcurrentHashMap<String, ActorRef>
    private let defaultSupervisionStrategy: SupervisionStrategy

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case createMsg: CreateUserActor =>
                createUserActor(createMsg.props, createMsg.name)
                MessageResult.Handled
            case supervisionMsg: SupervisionMessage =>
                handleSupervision(supervisionMsg)
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }

    public func createChild(props: Props<Actor>, name: String): ActorRef {
        let actorRef = context.actorOf(props, name)
        userActors.put(name, actorRef)

        // 应用监督策略
        let strategy = props.getSupervisionStrategy().getOrElse(defaultSupervisionStrategy)
        supervise(actorRef, strategy)

        return actorRef
    }
}
```

### **2. 企业级调度器系统**

#### **2.1 调度器注册表**
```cangjie
public class DispatcherRegistry {
    private let dispatchers: ConcurrentHashMap<String, Dispatcher>
    private let defaultDispatcher: Dispatcher
    private let config: DispatcherConfig

    public init(config: DispatcherConfig) {
        this.config = config
        this.dispatchers = ConcurrentHashMap<String, Dispatcher>()
        this.defaultDispatcher = createDefaultDispatcher()

        // 注册内置调度器
        registerBuiltinDispatchers()
    }

    public func getDispatcher(name: String): Dispatcher {
        match (dispatchers.get(name)) {
            case Some(dispatcher) => dispatcher
            case None =>
                // 动态创建调度器
                let dispatcher = createDispatcher(name)
                dispatchers.put(name, dispatcher)
                dispatcher
        }
    }

    private func createDispatcher(name: String): Dispatcher {
        let dispatcherConfig = config.getDispatcherConfig(name)

        match (dispatcherConfig.dispatcherType) {
            case "work-stealing" =>
                WorkStealingDispatcher(
                    dispatcherConfig.parallelism,
                    dispatcherConfig.throughput
                )
            case "fork-join" =>
                ForkJoinDispatcher(
                    dispatcherConfig.parallelism,
                    dispatcherConfig.throughput
                )
            case "pinned" =>
                PinnedDispatcher(dispatcherConfig.threadName)
            case _ => defaultDispatcher
        }
    }
}
```

#### **2.2 高性能Fork-Join调度器**
```cangjie
public class ForkJoinDispatcher <: AdvancedDispatcher {
    private let forkJoinPool: ForkJoinPool
    private let throughput: AtomicInt32
    private let metrics: DispatcherMetrics

    public init(parallelism: Int32, throughput: Int32) {
        this.forkJoinPool = ForkJoinPool(parallelism)
        this.throughput = AtomicInt32(throughput)
        this.metrics = DispatcherMetrics()
    }

    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        let task = ForkJoinActorTask(envelope, actorRef, this)
        forkJoinPool.submit(task)
        metrics.incrementTasksSubmitted()
    }

    public func executeBatch(actorRef: ActorRef): Unit {
        let mailbox = actorRef.getMailbox()
        let currentThroughput = throughput.load()

        for (i in 0..currentThroughput) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    try {
                        processMessage(envelope, actorRef)
                        metrics.incrementMessagesProcessed()
                    } catch (e: Exception) {
                        handleActorException(actorRef, e)
                    }
                case None => break
            }
        }
    }
}
```

### **3. 高级邮箱系统**

#### **3.1 邮箱类型系统**
```cangjie
public interface MailboxType {
    func create(owner: ActorRef, system: ActorSystem): Mailbox
    func getCapacity(): Option<Int64>
    func supportsPriority(): Bool
    func supportsStashing(): Bool
}

public class BoundedMailboxType <: MailboxType {
    private let capacity: Int64
    private let pushTimeOut: Duration
    private let dropPolicy: DropPolicy

    public init(capacity: Int64, pushTimeOut: Duration, dropPolicy: DropPolicy) {
        this.capacity = capacity
        this.pushTimeOut = pushTimeOut
        this.dropPolicy = dropPolicy
    }

    public func create(owner: ActorRef, system: ActorSystem): Mailbox {
        BoundedMailbox(capacity, pushTimeOut, dropPolicy, owner)
    }
}

public enum DropPolicy {
    | DropOldest    // 丢弃最旧的消息
    | DropNewest    // 丢弃最新的消息
    | DropCurrent   // 丢弃当前消息
    | Block         // 阻塞发送者
}
```

#### **3.2 优先级邮箱实现**
```cangjie
public class PriorityMailbox <: Mailbox {
    private let priorityQueue: PriorityQueue<PriorityEnvelope>
    private let mutex: Mutex
    private let comparator: (Message, Message) -> Int32

    public init(comparator: (Message, Message) -> Int32) {
        this.comparator = comparator
        this.priorityQueue = PriorityQueue<PriorityEnvelope>(
            { (a, b) => comparator(a.envelope.getMessage(), b.envelope.getMessage()) }
        )
        this.mutex = Mutex()
    }

    public func enqueue(envelope: Envelope): Bool {
        mutex.lock()
        try {
            let priority = calculatePriority(envelope.getMessage())
            let priorityEnvelope = PriorityEnvelope(envelope, priority)
            priorityQueue.offer(priorityEnvelope)
            return true
        } finally {
            mutex.unlock()
        }
    }

    public func dequeue(): Option<Envelope> {
        mutex.lock()
        try {
            match (priorityQueue.poll()) {
                case Some(priorityEnvelope) => Some(priorityEnvelope.envelope)
                case None => None
            }
        } finally {
            mutex.unlock()
        }
    }
}
```

### **4. 配置系统设计**

#### **4.1 配置文件格式**
```hocon
# cactor.conf - CActor配置文件
cactor {
  actor {
    # 默认调度器配置
    default-dispatcher {
      type = "work-stealing"
      parallelism = 8
      throughput = 100
      thread-pool-executor {
        core-pool-size = 8
        max-pool-size = 64
        keep-alive-time = 60s
      }
    }

    # 自定义调度器
    dispatchers {
      blocking-io-dispatcher {
        type = "pinned"
        thread-pool-executor {
          core-pool-size = 20
        }
      }

      high-throughput-dispatcher {
        type = "fork-join"
        parallelism = 16
        throughput = 1000
      }
    }

    # 邮箱配置
    default-mailbox {
      mailbox-type = "unbounded"
    }

    mailboxes {
      bounded-mailbox {
        mailbox-type = "bounded"
        mailbox-capacity = 10000
        mailbox-push-timeout = 10s
        drop-policy = "drop-oldest"
      }

      priority-mailbox {
        mailbox-type = "priority"
        priority-function = "cactor.message.DefaultPriorityFunction"
      }
    }

    # 监督策略配置
    supervision {
      default-strategy = "one-for-one"
      max-retries = 3
      within-time-range = 1m

      strategies {
        restart-strategy {
          directive = "restart"
          max-retries = 5
          within-time-range = 30s
        }

        stop-strategy {
          directive = "stop"
          max-retries = 0
        }
      }
    }
  }

  # 监控配置
  monitoring {
    enabled = true
    metrics-interval = 10s

    prometheus {
      enabled = true
      port = 9090
      path = "/metrics"
    }
  }

  # 集群配置
  cluster {
    enabled = false
    seed-nodes = ["cactor://system@127.0.0.1:2551"]
    port = 2551
  }
}
```

#### **4.2 配置加载器**
```cangjie
public class ConfigurationLoader {
    private let configProviders: Array<ConfigurationProvider>
    private let configCache: ConcurrentHashMap<String, ConfigValue>

    public init() {
        this.configProviders = Array<ConfigurationProvider>()
        this.configCache = ConcurrentHashMap<String, ConfigValue>()

        // 注册配置提供者（按优先级）
        registerProvider(SystemPropertyConfigProvider())    // 系统属性
        registerProvider(EnvironmentConfigProvider())       // 环境变量
        registerProvider(FileConfigProvider("cactor.conf")) // 配置文件
        registerProvider(DefaultConfigProvider())           // 默认配置
    }

    public func loadConfig(): ActorSystemConfig {
        let configMap = HashMap<String, ConfigValue>()

        // 按优先级加载配置
        for (provider in configProviders) {
            let providerConfig = provider.loadConfig()
            for ((key, value) in providerConfig) {
                if (!configMap.containsKey(key)) {
                    configMap.put(key, value)
                }
            }
        }

        return ActorSystemConfig.fromMap(configMap)
    }

    public func watchConfig(path: String, callback: (ConfigValue) -> Unit): Unit {
        for (provider in configProviders) {
            if (provider.supportsWatching()) {
                provider.watchConfig(path, callback)
            }
        }
    }
}
```

## 📊 **性能优化策略**

### **1. 消息传递优化**
```cangjie
// 零拷贝消息传递
public interface ZeroCopyMessage <: Message {
    func getDirectBuffer(): DirectByteBuffer
    func transferOwnership(): DirectByteBuffer
    func getSize(): Int64
}

// 批量消息处理
public class BatchMessageProcessor {
    private let batchSize: Int32
    private let batchTimeout: Duration

    public func processBatch(mailbox: Mailbox, actor: Actor): Int32 {
        let batch = Array<Envelope>(batchSize)
        let count = collectBatch(mailbox, batch)

        if (count > 0) {
            processBatchMessages(batch, count, actor)
        }

        return count
    }
}
```

### **2. 内存池优化**
```cangjie
public class ActorSystemMemoryManager {
    private let actorPool: ObjectPool<Actor>
    private let messagePool: ObjectPool<Message>
    private let envelopePool: ObjectPool<Envelope>
    private let bufferPool: DirectBufferPool

    public func borrowActor<T>(): T where T <: Actor {
        match (actorPool.borrow()) {
            case Some(actor) => actor as T
            case None => createNewActor<T>()
        }
    }

    public func borrowMessage<T>(): T where T <: Message {
        match (messagePool.borrow()) {
            case Some(message) =>
                message.reset()  // 重置消息状态
                message as T
            case None => createNewMessage<T>()
        }
    }
}
```

### **3. NUMA感知调度**
```cangjie
public class NUMADispatcher <: AdvancedDispatcher {
    private let numaTopology: NUMATopology
    private let nodeWorkers: Array<Array<WorkerThread>>

    public func scheduleOnOptimalNode(task: ActorTask): Unit {
        let actorRef = task.getActorRef()
        let preferredNode = getActorNUMANode(actorRef)

        // 尝试在首选NUMA节点上调度
        if (tryScheduleOnNode(task, preferredNode)) {
            return
        }

        // 回退到负载最轻的节点
        let lightestNode = findLightestNode()
        scheduleOnNode(task, lightestNode)
    }

    private func getActorNUMANode(actorRef: ActorRef): Int32 {
        // 基于Actor路径哈希确定NUMA节点
        let hash = actorRef.path.hashCode()
        return hash % numaTopology.getNodeCount()
    }
}
```

这个全面的改造计划将使CActor 9.0成为真正的世界级Actor系统，具备企业级特性和极致性能。

## 🛠️ **详细实施计划**

### **Phase 1: Guardian Actor系统实现 (Week 1-2)**

#### **Day 1-3: 系统Guardian实现**
```bash
# 1. 创建Guardian Actor基础架构
mkdir -p src/core/guardian/
touch src/core/guardian/{system_guardian.cj,user_guardian.cj,guardian_messages.cj}

# 2. 实现SystemGuardian
# - 管理系统级Actor
# - 处理系统消息
# - 实现系统监督策略

# 3. 实现UserGuardian
# - 管理用户Actor
# - 处理用户消息
# - 实现用户监督策略
```

#### **Day 4-7: ActorSystem重构**
```bash
# 1. 重构SimpleActorSystem
# - 集成Guardian Actor
# - 添加配置支持
# - 实现扩展机制

# 2. 创建EnterpriseActorSystem
# - 完整的企业级特性
# - 监控和指标
# - 事件总线

# 3. 向后兼容性保证
# - 保持现有API
# - 添加迁移工具
```

#### **Day 8-10: 配置系统基础**
```bash
# 1. 实现配置加载器
mkdir -p src/core/config/
touch src/core/config/{config_loader.cj,config_provider.cj,actor_system_config.cj}

# 2. 支持多种配置源
# - 配置文件 (HOCON格式)
# - 环境变量
# - 系统属性
# - 默认配置

# 3. 配置验证和错误处理
```

#### **Day 11-14: 测试和验证**
```bash
# 1. Guardian Actor单元测试
# 2. ActorSystem集成测试
# 3. 配置系统测试
# 4. 性能基准测试
```

### **Phase 2: 高性能调度器系统 (Week 3-4)**

#### **Day 15-17: 调度器注册表**
```bash
# 1. 实现DispatcherRegistry
mkdir -p src/runtime/dispatcher/registry/
touch src/runtime/dispatcher/registry/{dispatcher_registry.cj,dispatcher_factory.cj}

# 2. 支持多种调度器类型
# - WorkStealingDispatcher (已有)
# - ForkJoinDispatcher (新增)
# - PinnedDispatcher (新增)
# - CallingThreadDispatcher (新增)

# 3. 动态调度器创建和管理
```

#### **Day 18-21: Fork-Join调度器**
```bash
# 1. 实现ForkJoinDispatcher
touch src/runtime/dispatcher/forkjoin/{fork_join_dispatcher.cj,fork_join_task.cj}

# 2. 优化任务分解和合并
# 3. 实现工作窃取算法
# 4. 添加性能监控
```

#### **Day 22-24: NUMA感知调度**
```bash
# 1. 实现NUMADispatcher
mkdir -p src/runtime/dispatcher/numa/
touch src/runtime/dispatcher/numa/{numa_dispatcher.cj,numa_topology.cj,cpu_affinity.cj}

# 2. CPU亲和性管理
# 3. NUMA拓扑检测
# 4. 负载均衡优化
```

#### **Day 25-28: 调度器性能优化**
```bash
# 1. 批量消息处理优化
# 2. 线程池参数调优
# 3. 内存局部性优化
# 4. 性能基准测试和调优
```

### **Phase 3: 企业级邮箱系统 (Week 5-6)**

#### **Day 29-31: 邮箱类型系统**
```bash
# 1. 实现MailboxType接口
mkdir -p src/runtime/mailbox/types/
touch src/runtime/mailbox/types/{mailbox_type.cj,bounded_mailbox_type.cj,priority_mailbox_type.cj}

# 2. 实现多种邮箱类型
# - UnboundedMailboxType
# - BoundedMailboxType
# - PriorityMailboxType
# - StashingMailboxType

# 3. 邮箱工厂系统
```

#### **Day 32-35: 高级邮箱实现**
```bash
# 1. 实现BoundedMailbox
touch src/runtime/mailbox/bounded/{bounded_mailbox.cj,drop_policy.cj}

# 2. 实现PriorityMailbox
touch src/runtime/mailbox/priority/{priority_mailbox.cj,priority_envelope.cj}

# 3. 实现StashingMailbox
touch src/runtime/mailbox/stashing/{stashing_mailbox.cj,stash_buffer.cj}

# 4. 背压控制机制
```

#### **Day 36-42: 邮箱性能优化**
```bash
# 1. 零拷贝消息传递
# 2. 内存池集成
# 3. 批量操作优化
# 4. 性能测试和调优
```

### **Phase 4: 监督和容错增强 (Week 7-8)**

#### **Day 43-45: 高级监督策略**
```bash
# 1. 扩展SupervisionStrategy
mkdir -p src/core/supervision/advanced/
touch src/core/supervision/advanced/{escalating_strategy.cj,circuit_breaker_strategy.cj}

# 2. 实现升级机制
# 3. 集成断路器模式
# 4. 监督统计和监控
```

#### **Day 46-49: 死亡监视系统**
```bash
# 1. 实现DeathWatch扩展
mkdir -p src/core/deathwatch/
touch src/core/deathwatch/{death_watch.cj,death_watch_extension.cj,terminated_message.cj}

# 2. Actor生命周期监控
# 3. 自动清理机制
# 4. 事件通知系统
```

#### **Day 50-56: 容错测试和优化**
```bash
# 1. 故障注入测试
# 2. 恢复时间测试
# 3. 级联故障测试
# 4. 容错性能优化
```

### **Phase 5: 监控和指标系统 (Week 9-10)**

#### **Day 57-59: 指标收集系统**
```bash
# 1. 实现ActorSystemMetrics
mkdir -p src/integration/monitoring/metrics/
touch src/integration/monitoring/metrics/{actor_system_metrics.cj,metric_collector.cj}

# 2. 核心指标定义
# - Actor数量统计
# - 消息吞吐量
# - 消息延迟分布
# - 邮箱大小统计
# - 调度器利用率

# 3. 实时指标更新
```

#### **Day 60-63: 事件总线系统**
```bash
# 1. 实现EventBus
mkdir -p src/core/eventbus/
touch src/core/eventbus/{event_bus.cj,actor_event_bus.cj,event_types.cj}

# 2. 事件类型定义
# - Actor生命周期事件
# - 系统事件
# - 监督事件
# - 性能事件

# 3. 事件订阅和分发
```

#### **Day 64-70: Prometheus集成**
```bash
# 1. 实现Prometheus扩展
mkdir -p src/integration/monitoring/prometheus/
touch src/integration/monitoring/prometheus/{prometheus_extension.cj,metrics_exporter.cj}

# 2. 指标格式转换
# 3. HTTP端点实现
# 4. 自定义指标支持
```

### **Phase 6: 配置和扩展系统 (Week 11-12)**

#### **Day 71-73: 动态配置系统**
```bash
# 1. 实现热重载配置
touch src/core/config/{hot_reload_config.cj,config_watcher.cj}

# 2. 配置变更通知
# 3. 配置验证机制
# 4. 配置回滚支持
```

#### **Day 74-77: 扩展注册系统**
```bash
# 1. 完善ExtensionRegistry
mkdir -p src/core/extensions/
touch src/core/extensions/{extension_registry.cj,extension_lifecycle.cj}

# 2. 扩展生命周期管理
# 3. 依赖注入支持
# 4. 扩展配置管理
```

#### **Day 78-84: 生产部署准备**
```bash
# 1. 性能调优和优化
# 2. 内存泄漏检测和修复
# 3. 压力测试和稳定性测试
# 4. 文档完善和示例代码
```

## 🎯 **关键性能指标**

### **吞吐量目标**
```cangjie
// 目标性能指标
public struct PerformanceTargets {
    public static let MESSAGE_THROUGHPUT: Int64 = 50_000_000  // 50M msg/s
    public static let ACTOR_CREATION_RATE: Int64 = 100_000    // 100K actors/s
    public static let CONCURRENT_ACTORS: Int64 = 1_000_000    // 1M concurrent actors

    public static let MESSAGE_LATENCY_P99: Duration = Duration.microsecond * 100  // 100μs
    public static let ACTOR_CREATION_LATENCY: Duration = Duration.microsecond * 10  // 10μs
    public static let SYSTEM_STARTUP_TIME: Duration = Duration.second * 1  // 1s
}
```

### **内存效率目标**
```cangjie
public struct MemoryTargets {
    public static let MEMORY_PER_ACTOR: Int64 = 1024        // 1KB per actor
    public static let MESSAGE_OVERHEAD: Int64 = 64          // 64B per message
    public static let SYSTEM_OVERHEAD: Int64 = 10_485_760   // 10MB system overhead
}
```

### **可扩展性目标**
```cangjie
public struct ScalabilityTargets {
    public static let MAX_ACTORS_PER_SYSTEM: Int64 = 10_000_000    // 10M actors
    public static let MAX_CLUSTER_NODES: Int32 = 1000             // 1000 nodes
    public static let MAX_MESSAGES_PER_SECOND: Int64 = 100_000_000 // 100M msg/s
}
```

## 📋 **验收标准详细定义**

### **功能完整性验收**
```bash
# 1. 核心功能测试
./test_core_functionality.sh
# - Actor创建和销毁
# - 消息发送和接收
# - 监督策略执行
# - 配置加载和应用

# 2. 高级功能测试
./test_advanced_features.sh
# - Ask模式
# - 路由器
# - 断路器
# - 背压控制

# 3. 企业级功能测试
./test_enterprise_features.sh
# - 监控指标收集
# - 事件总线
# - 扩展系统
# - 动态配置
```

### **性能验收测试**
```bash
# 1. 吞吐量测试
./benchmark_throughput.sh
# 目标: ≥ 50M msg/s

# 2. 延迟测试
./benchmark_latency.sh
# 目标: P99 ≤ 100μs

# 3. 内存效率测试
./benchmark_memory.sh
# 目标: ≤ 1KB per actor

# 4. 可扩展性测试
./benchmark_scalability.sh
# 目标: 1M+ concurrent actors
```

### **生产就绪验收**
```bash
# 1. 稳定性测试
./test_stability.sh
# - 7x24小时运行测试
# - 内存泄漏检测
# - 故障恢复测试

# 2. 监控系统测试
./test_monitoring.sh
# - 指标收集准确性
# - 告警机制
# - 性能监控

# 3. 配置系统测试
./test_configuration.sh
# - 热重载功能
# - 配置验证
# - 错误处理

# 4. 文档完整性检查
./check_documentation.sh
# - API文档覆盖率 ≥ 95%
# - 示例代码可运行
# - 部署指南完整
```

## 🎉 **预期成果和价值**

### **技术价值**
- **世界级性能**: 达到Akka/Actix级别的性能指标
- **企业级特性**: 完整的生产环境支持能力
- **Cangjie原生**: 充分利用Cangjie语言特性和生态
- **高度可扩展**: 支持大规模分布式部署

### **生态价值**
- **基础设施**: 成为Cangjie生态的核心并发框架
- **开发效率**: 大幅提升并发应用开发效率
- **技术标杆**: 展示Cangjie语言的企业级应用能力
- **社区贡献**: 为开源社区提供高质量Actor实现

### **商业价值**
- **降低成本**: 高性能减少硬件资源需求
- **提升可靠性**: 容错机制保障系统稳定性
- **加速上市**: 简化并发编程，缩短开发周期
- **技术竞争力**: 提升基于Cangjie的产品竞争优势

通过这个全面的改造计划，CActor 9.0将成为真正的世界级Actor系统，为Cangjie语言生态系统提供强大的并发编程基础设施。
