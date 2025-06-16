# CActor 完整Actor系统实现计划 - plan3.md

## 🎯 总体愿景

基于对Akka、Actix、ProtoActor等世界级Actor框架的深度分析，结合CActor现有代码库的全面审查，制定一个完整的Actor功能实现计划。目标是构建一个高性能、类型安全、功能完整的仓颉语言Actor系统，支持灵活的配置和企业级特性。

## 📊 主流Actor框架核心特性分析

### 🏆 Akka架构精髓
**核心设计原则**:
- **Actor层次结构**: 严格的监督树，每个Actor都有明确的父子关系
- **位置透明**: ActorRef抽象，本地和远程Actor使用相同接口
- **消息驱动**: 纯异步消息传递，无共享状态
- **弹性设计**: Let-it-crash哲学，通过监督策略处理故障
- **配置驱动**: 通过配置文件灵活配置Dispatcher、Mailbox等

**关键配置模式**:
```hocon
akka {
  actor {
    default-dispatcher {
      type = Dispatcher
      executor = "thread-pool-executor"
      thread-pool-executor {
        fixed-pool-size = 16
      }
      throughput = 100
    }
    
    default-mailbox {
      mailbox-type = "akka.dispatch.UnboundedMailbox"
    }
    
    mailbox {
      bounded-mailbox {
        mailbox-type = "akka.dispatch.BoundedMailbox"
        mailbox-capacity = 1000
      }
    }
  }
}
```

### ⚡ Actix架构特色 (Rust)
**核心特性**:
- **类型安全**: 编译时消息类型检查
- **零成本抽象**: 高性能异步运行时
- **监督策略**: 灵活的错误处理和恢复机制
- **背压控制**: 自动流量控制防止系统过载

### 🚀 ProtoActor架构优势
**核心特性**:
- **跨语言**: Go、C#、Java/Kotlin统一API
- **高性能**: 优化的消息传递和内存管理
- **集群支持**: 内置分布式Actor支持
- **简洁API**: 最小化配置，开箱即用

## 🔍 CActor现状分析

### ✅ 已有优势
1. **Foundation层**: 高性能LockFreeQueue，支持百万级操作/秒
2. **Core层**: 完整的Actor接口和生命周期管理
3. **Runtime层**: 基础的Mailbox和Dispatcher实现
4. **工作窃取调度器**: 高性能并发调度
5. **类型安全**: 基于仓颉强类型系统

### ❌ 关键缺陷
1. **配置系统不完整**: 缺乏灵活的Mailbox/Dispatcher配置
2. **Actor创建流程**: 没有完整的配置绑定机制
3. **监督策略**: 缺乏完整的错误处理和恢复机制
4. **路由系统**: 缺乏负载均衡和消息分发
5. **集群支持**: 缺乏分布式Actor支持

## 🎯 完整实现计划

### Phase 1: 核心配置系统重构 (优先级: 🔥 极高)

#### 1.1 Actor配置框架设计
**目标**: 建立完整的Actor配置系统，支持灵活的Mailbox和Dispatcher配置

```cangjie
// src/core/config/actor_config.cj
public interface ActorConfiguration {
    func getMailboxConfig(): MailboxConfig
    func getDispatcherConfig(): DispatcherConfig
    func getSupervisionConfig(): SupervisionConfig
    func getRoutingConfig(): Option<RoutingConfig>
}

public class MailboxConfig {
    public let mailboxType: MailboxType
    public let capacity: Int64
    public let pushTimeout: Duration
    public let stashCapacity: Int64
    
    public enum MailboxType {
        | Unbounded
        | Bounded(capacity: Int64)
        | Priority(comparator: (Message, Message) -> Int32)
        | Stashing(stashCapacity: Int64)
        | Custom(factory: () -> Mailbox)
    }
}

public class DispatcherConfig {
    public let dispatcherType: DispatcherType
    public let throughput: Int32
    public let throughputDeadlineTime: Duration
    public let executorConfig: ExecutorConfig
    
    public enum DispatcherType {
        | ThreadPool(corePoolSize: Int32, maxPoolSize: Int32)
        | WorkStealing(parallelism: Int32)
        | PinnedDispatcher
        | CallingThread
        | Custom(factory: () -> MessageDispatcher)
    }
}
```

#### 1.2 配置驱动的Actor创建
**目标**: 重构ActorSystem.actorOf方法，支持完整的配置绑定

```cangjie
// src/core/system/actor_system_impl.cj
public class ActorSystemImpl <: ActorSystem {
    private let configManager: ConfigurationManager
    private let dispatcherRegistry: DispatcherRegistry
    private let mailboxRegistry: MailboxRegistry
    
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        // 1. 解析Actor配置
        let config = resolveActorConfig(props, name)
        
        // 2. 创建Mailbox
        let mailbox = createMailbox(config.getMailboxConfig())
        
        // 3. 获取Dispatcher
        let dispatcher = getDispatcher(config.getDispatcherConfig())
        
        // 4. 创建Actor实例
        let actor = props.create()
        
        // 5. 创建ActorCell (Actor运行时容器)
        let actorCell = ActorCell(actor, mailbox, dispatcher, config, self)
        
        // 6. 创建ActorRef
        let actorRef = LocalActorRef(actorCell, ActorPath(name))
        
        // 7. 启动Actor
        actorCell.start()
        
        return actorRef
    }
}
```

### Phase 2: 高级Mailbox系统 (优先级: 🔥 高)

#### 2.1 多种Mailbox实现
```cangjie
// src/runtime/mailbox/advanced/
public class UnboundedMailbox <: Mailbox {
    private let queue: LockFreeQueue<Envelope>
    // 无界队列，基于Foundation层LockFreeQueue
}

public class BoundedMailbox <: Mailbox {
    private let queue: LockFreeQueue<Envelope>
    private let capacity: Int64
    private let pushTimeout: Duration
    // 有界队列，支持背压控制
}

public class PriorityMailbox <: Mailbox {
    private let priorityQueue: PriorityQueue<Envelope>
    private let comparator: (Message, Message) -> Int32
    // 优先级队列，支持消息优先级
}

public class StashingMailbox <: Mailbox {
    private let normalQueue: Queue<Envelope>
    private let stashQueue: Queue<Envelope>
    private let stashCapacity: Int64
    // 支持消息暂存的邮箱
}
```

#### 2.2 Mailbox工厂系统
```cangjie
// src/runtime/mailbox/factory/mailbox_factory.cj
public interface MailboxFactory {
    func createMailbox(config: MailboxConfig): Mailbox
}

public class DefaultMailboxFactory <: MailboxFactory {
    public func createMailbox(config: MailboxConfig): Mailbox {
        match (config.mailboxType) {
            case MailboxType.Unbounded =>
                UnboundedMailbox()
            case MailboxType.Bounded(capacity) =>
                BoundedMailbox(capacity, config.pushTimeout)
            case MailboxType.Priority(comparator) =>
                PriorityMailbox(comparator)
            case MailboxType.Stashing(stashCapacity) =>
                StashingMailbox(config.capacity, stashCapacity)
            case MailboxType.Custom(factory) =>
                factory()
        }
    }
}
```

### Phase 3: 高级Dispatcher系统 (优先级: 🔥 高)

#### 3.1 多种Dispatcher实现
```cangjie
// src/runtime/dispatcher/advanced/
public interface MessageDispatcher {
    func dispatch(actorCell: ActorCell): Unit
    func schedule(actorCell: ActorCell): Unit
    func shutdown(): Unit
    func getConfig(): DispatcherConfig
}

public class ThreadPoolDispatcher <: MessageDispatcher {
    private let executor: ThreadPoolExecutor
    private let throughput: Int32
    // 基于线程池的调度器
}

public class WorkStealingDispatcher <: MessageDispatcher {
    private let workers: Array<WorkerThread>
    private let globalQueue: Queue<ActorCell>
    // 工作窃取调度器 (已有，需要增强)
}

public class PinnedDispatcher <: MessageDispatcher {
    private let dedicatedThread: Thread
    // 专用线程调度器，用于关键Actor
}
```

#### 3.2 Dispatcher注册和管理
```cangjie
// src/runtime/dispatcher/registry/dispatcher_registry.cj
public class DispatcherRegistry {
    private let dispatchers: HashMap<String, MessageDispatcher>
    private let defaultDispatcher: MessageDispatcher
    
    public func getDispatcher(name: String): MessageDispatcher {
        match (dispatchers.get(name)) {
            case Some(dispatcher) => dispatcher
            case None => defaultDispatcher
        }
    }
    
    public func registerDispatcher(name: String, dispatcher: MessageDispatcher): Unit {
        dispatchers.put(name, dispatcher)
    }
}
```

### Phase 4: 监督策略系统 (优先级: 🔥 中高)

#### 4.1 监督策略接口
```cangjie
// src/core/supervision/supervision_strategy.cj
public interface SupervisionStrategy {
    func decide(failure: Exception, child: ActorRef): SupervisionDirective
}

public enum SupervisionDirective {
    | Resume          // 恢复Actor，忽略异常
    | Restart         // 重启Actor
    | Stop            // 停止Actor
    | Escalate        // 向上级监督者报告
}

public class OneForOneStrategy <: SupervisionStrategy {
    private let maxRetries: Int32
    private let withinTimeRange: Duration
    private let decider: (Exception) -> SupervisionDirective
}

public class AllForOneStrategy <: SupervisionStrategy {
    // 一个子Actor失败时，重启所有子Actor
}
```

### Phase 5: 路由系统 (优先级: 🔥 中)

#### 5.1 路由器实现
```cangjie
// src/patterns/routing/router.cj
public interface Router {
    func route(message: Message, routees: Array<ActorRef>): Array<ActorRef>
}

public class RoundRobinRouter <: Router {
    private let counter: AtomicInt64
    // 轮询路由
}

public class RandomRouter <: Router {
    // 随机路由
}

public class ConsistentHashingRouter <: Router {
    private let hashFunction: (Message) -> Int64
    // 一致性哈希路由
}

public class BroadcastRouter <: Router {
    // 广播路由，发送给所有routee
}
```

### Phase 6: 配置文件支持 (优先级: 🔥 中)

#### 6.1 配置文件格式
```toml
# cactor.toml
[actor]
default-dispatcher = "default-thread-pool"
default-mailbox = "unbounded"

[dispatchers.default-thread-pool]
type = "thread-pool"
core-pool-size = 8
max-pool-size = 16
throughput = 100

[dispatchers.work-stealing]
type = "work-stealing"
parallelism = 8
throughput = 50

[mailboxes.unbounded]
type = "unbounded"

[mailboxes.bounded]
type = "bounded"
capacity = 1000
push-timeout = "10s"

[mailboxes.priority]
type = "priority"
capacity = 1000
```

#### 6.2 配置加载器
```cangjie
// src/integration/configuration/config_loader.cj
public class ConfigLoader {
    public static func loadFromFile(path: String): ActorSystemConfig {
        // 解析TOML配置文件
        // 创建ActorSystemConfig实例
    }
    
    public static func loadFromString(config: String): ActorSystemConfig {
        // 从字符串解析配置
    }
}
```

## 🚀 实现优先级和时间线

### 第一阶段 (2周): 核心配置系统 ✅ **已完成**
- [x] ActorConfiguration接口设计 ✅
- [x] MailboxConfig和DispatcherConfig实现 ✅
- [x] SupervisionConfig和RoutingConfig实现 ✅
- [x] 多种邮箱类型支持 (Unbounded, Bounded, Priority, Stashing) ✅
- [x] 多种调度器类型支持 (ThreadPool, WorkStealing, Pinned) ✅
- [x] 预定义配置模板 (Default, HighPerformance, Batching, Critical) ✅
- [x] ConfigurationManager配置管理 ✅
- [x] ActorConfigurationBuilder流式API ✅
- [ ] 重构ActorSystem.actorOf方法 (待实现)
- [ ] 基础配置绑定机制 (待实现)

### 第二阶段 (2周): 高级Mailbox系统 ✅ **已完成**
- [x] 基于Foundation队列的高性能邮箱实现 ✅
- [x] FoundationUnboundedMailbox - 基于LockFreeQueue的无界邮箱 ✅
- [x] FoundationBoundedMailbox - 基于LockFreeQueue的有界邮箱 ✅
- [x] SPSCMailbox - 基于SPSCQueue的单生产者单消费者邮箱 ✅
- [x] MPSCMailbox - 基于MPSCQueue的多生产者单消费者邮箱 ✅
- [x] FoundationPriorityMailbox - 基于双队列的优先级邮箱 ✅
- [x] FoundationStashingMailbox - 基于双队列的暂存邮箱 ✅
- [x] DefaultAdvancedMailboxFactory - 高级邮箱工厂系统 ✅
- [x] 使用模式优化 (SPSC/MPSC/HighThroughput/LowLatency) ✅
- [x] MailboxFactoryRegistry - 工厂注册表管理 ✅
- [x] 配置验证和统计功能 ✅
- [x] Mailbox性能测试和验证 ✅

### 第三阶段 (2周): 高级Dispatcher系统 ✅ **已完成**
- [x] 基于现有组件的高级调度器实现 ✅
- [x] AdvancedWorkStealingDispatcher - 基于WorkStealingDispatcher的高级工作窃取调度器 ✅
- [x] UltraHighPerformanceDispatcher - 基于OptimizedWorkStealingDispatcher的超高性能调度器 ✅
- [x] ThreadPoolDispatcher - 基于LockFreeQueue的线程池调度器 ✅
- [x] PinnedDispatcher - 专用线程调度器，保证低延迟 ✅
- [x] CallingThreadDispatcher - 调用线程调度器，零延迟处理 ✅
- [x] DefaultAdvancedDispatcherFactory - 高级调度器工厂系统 ✅
- [x] 性能配置文件优化 (UltraHighThroughput/UltraLowLatency/CriticalMission等) ✅
- [x] DispatcherFactoryRegistry - 工厂注册表管理 ✅
- [x] AdvancedMessageDispatcher统一接口设计 ✅
- [x] 配置验证和统计功能 ✅
- [x] 性能优化和调优验证 ✅

### 第四阶段 (1周): Actor DSL宏系统 ✅ **已完成**
- [x] 基于仓颉语言宏系统的Actor DSL实现 ✅
- [x] @actor_def - Actor定义宏，自动生成Actor基础结构 ✅
- [x] @message_handler - 消息处理器宏，自动生成消息分发逻辑 ✅
- [x] @perf_monitor/@batch_perf_monitor - 性能监控宏 ✅
- [x] @log_info/@log_debug/@log_error/@log_with_time - 日志宏系统 ✅
- [x] @repeat_times/@repeat_while - 代码生成宏 ✅
- [x] @state_machine - 状态机宏，简化状态转换逻辑 ✅
- [x] @safe_execute/@retry_execute - 错误处理宏 ✅
- [x] 宏系统辅助函数 (getCurrentTimeMillis, generateUniqueId等) ✅
- [x] 完整的DSL宏测试验证 ✅

### 第五阶段 (1周): 监督策略 ✅ **已完成**
- [x] 基于现有监督策略组件的高级监督系统 ✅
- [x] SupervisionStrategy接口和SupervisionDirective枚举 ✅
- [x] OneForOneStrategy - 一对一监督策略 ✅
- [x] OneForAllStrategy - 一对全监督策略 ✅
- [x] AdvancedSupervisionStrategyFactory - 高级策略工厂 ✅
- [x] BackoffSupervisionStrategy - 渐进式退避策略 ✅
- [x] CircuitBreakerSupervisionStrategy - 电路熔断策略 ✅
- [x] AdvancedSupervisor - 高级监督者实现 ✅
- [x] SupervisionMetrics - 监督指标收集和统计 ✅
- [x] 异常类型决策和失败历史记录管理 ✅
- [x] 错误处理和恢复机制完整实现 ✅

### 第五阶段 (1周): 路由系统
- [ ] Router接口和基础实现
- [ ] RoundRobinRouter、RandomRouter
- [ ] ConsistentHashingRouter

### 第六阶段 (1周): 配置文件支持
- [ ] TOML配置文件解析
- [ ] ConfigLoader实现
- [ ] 配置验证和错误处理

## 📋 验收标准

### 功能完整性
- [ ] 支持至少4种Mailbox类型 (Unbounded, Bounded, Priority, Stashing)
- [ ] 支持至少3种Dispatcher类型 (ThreadPool, WorkStealing, Pinned)
- [ ] 支持完整的监督策略 (Resume, Restart, Stop, Escalate)
- [ ] 支持至少4种路由策略 (RoundRobin, Random, ConsistentHashing, Broadcast)
- [ ] 支持配置文件驱动的Actor系统创建

### 性能指标
- [ ] Mailbox操作性能: >100万 ops/s
- [ ] 消息传递延迟: <1ms (P99)
- [ ] 系统吞吐量: >50万 msg/s
- [ ] 内存使用优化: <10MB基础内存占用

### 易用性
- [ ] 简洁的API设计，学习成本低
- [ ] 完整的文档和示例
- [ ] 良好的错误信息和调试支持
- [ ] 向后兼容现有代码

## 🎯 最终目标

构建一个世界级的仓颉语言Actor系统，具备：
1. **企业级功能**: 完整的配置、监督、路由支持
2. **高性能**: 百万级消息处理能力
3. **类型安全**: 编译时错误检查
4. **易用性**: 简洁的API和丰富的文档
5. **可扩展性**: 支持自定义Mailbox、Dispatcher、Router
6. **生产就绪**: 完整的测试覆盖和性能验证

通过这个计划，CActor将成为仓颉语言生态中最完整、最高性能的Actor系统实现。
