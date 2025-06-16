# CActor API 设计改造计划 v2.0

## 🎯 **全面架构分析**

### CActor现有架构优势：
1. **完整的Actor模型实现** - 包含Actor、ActorRef、ActorSystem、消息系统
2. **高性能基础设施** - 无锁队列、对象池、批处理邮箱
3. **企业级特性** - 监督策略、路由系统、断路器、Ask模式
4. **分布式能力** - 远程通信、集群支持、序列化框架
5. **丰富的运行时** - 多种调度器、邮箱类型、性能监控

### 当前API存在的问题：

1. **API复杂度高**：
   - 配置创建需要多个步骤和工厂类
   - 缺乏Akka风格的简洁API
   - 没有充分利用Cangjie的函数式特性

2. **DSL支持不足**：
   - 缺乏尾随lambda的DSL风格
   - 没有利用Cangjie的pipeline操作符
   - 配置方式过于命令式

3. **类型安全可提升**：
   - 泛型使用不够充分
   - 缺乏类型化Actor支持
   - 消息类型安全性可以增强

4. **开发体验待优化**：
   - 样板代码过多
   - 缺乏便利的工厂方法
   - 错误处理不够优雅

## 🚀 **设计目标**

### 参考Akka + 利用Cangjie特性：
1. **极简API**：像Akka一样简洁优雅
2. **函数式DSL**：充分利用Cangjie的尾随lambda和pipeline
3. **类型安全**：强化类型系统的使用
4. **高性能**：保持现有的高性能特性
5. **向后兼容**：不破坏现有功能

## 📋 **全新API设计方案**

### 1. **ActorSystem API** - 极简创建和管理

#### 当前方式（复杂）：
```cangjie
let coreSystem = SimpleActorSystem("system")
let props = Props<MyActor>(SimpleActorFactory<MyActor>({ => MyActor() }))
    .withDispatcher("thread-pool")
    .withMailbox("bounded")
let actorRef = coreSystem.actorOf(props, "my-actor")
```

#### 新设计（极简）：
```cangjie
// 方式1: 最简创建
let system = ActorSystem("production")
let actorRef = system.actorOf({ => MyActor() }, "my-actor")

// 方式2: 链式配置
let actorRef = system.actorOf(
    Props({ => MyActor() })
        .withMailbox("bounded")
        .withDispatcher("work-stealing")
        .withSupervision("restart"),
    "my-actor"
)

// 方式3: DSL风格（利用尾随lambda）
let actorRef = system.actorOf("my-actor") {
    factory { MyActor() }
    mailbox { bounded(1000) }
    dispatcher { workStealing(parallelism = 4) }
    supervision { restart(maxRetries = 3, backoff = 1.seconds) }
}

// 方式4: Pipeline风格（利用Cangjie pipeline操作符）
let actorRef = { => MyActor() }
    |> Props.create
    |> { it => it.withMailbox("bounded") }
    |> { it => it.withDispatcher("work-stealing") }
    |> { it => system.actorOf(it, "my-actor") }
```

### 2. **Props配置API** - 函数式配置系统

#### 新Props设计（基于现有core.actor.Props增强）：
```cangjie
// 基础Props - 保持向后兼容
public struct Props<T> where T <: Actor {
    // 现有API保持不变
    public static func create(factory: () -> T): Props<T>
    public func withMailbox(mailboxType: String): Props<T>
    public func withDispatcher(dispatcher: String): Props<T>
    public func withSupervisionStrategy(strategy: String): Props<T>
}

// 新增便利API
extend Props<T> where T <: Actor {
    // 类型化配置
    public func withMailbox(config: MailboxConfig): Props<T>
    public func withDispatcher(config: DispatcherConfig): Props<T>
    public func withSupervision(config: SupervisionConfig): Props<T>
    public func withRouter(config: RouterConfig): Props<T>

    // DSL配置方法
    public func configure(block: (PropsBuilder<T>) -> Unit): Props<T>
}

// 使用示例
let props = Props.create({ => MyActor() })
    .withMailbox(Mailbox.bounded(1000))
    .withDispatcher(Dispatcher.workStealing(parallelism = 4))
    .withSupervision(Supervision.restart(maxRetries = 3))
```

### 3. **配置DSL API** - 基于Cangjie函数式特性和现有runtime

#### Mailbox配置（基于现有runtime.mailbox）：
```cangjie
// 基于现有的runtime.mailbox包装
public struct MailboxConfig {
    // 静态工厂方法
    public static func unbounded(): MailboxConfig
    public static func bounded(capacity: Int32): MailboxConfig
    public static func priority<T>(comparator: (T, T) -> Int32): MailboxConfig
    public static func ringBuffer(capacity: Int32): MailboxConfig
    public static func batching(batchSize: Int32): MailboxConfig

    // DSL配置（利用尾随lambda）
    public static func configure(block: (MailboxBuilder) -> Unit): MailboxConfig
}

// 使用示例
let mailbox1 = MailboxConfig.bounded(1000)
let mailbox2 = MailboxConfig.configure { builder =>
    builder.type("bounded")
    builder.capacity(1000)
    builder.overflow("drop-oldest")
}
```

#### Dispatcher配置（基于现有runtime.dispatcher）：
```cangjie
// 基于现有的runtime.dispatcher包装
public struct DispatcherConfig {
    // 静态工厂方法
    public static func threadPool(size: Int32 = 4): DispatcherConfig
    public static func workStealing(parallelism: Int32 = 8): DispatcherConfig
    public static func pinned(): DispatcherConfig
    public static func callingThread(): DispatcherConfig

    // DSL配置
    public static func configure(block: (DispatcherBuilder) -> Unit): DispatcherConfig
}

// 使用示例
let dispatcher1 = DispatcherConfig.workStealing(parallelism = 4)
let dispatcher2 = DispatcherConfig.configure { builder =>
    builder.type("work-stealing")
    builder.parallelism(4)
    builder.throughput(100)
}
```

### 4. **Actor行为API** - 类型化Actor和行为组合

#### 当前方式（基于现有core.actor.Actor）：
```cangjie
public class MyActor <: Actor {
    public prop name: String { get() { "MyActor" } }
    public prop description: String { get() { "我的Actor" } }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                println("收到: ${msg.getContent()}")
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }
}
```

#### 新设计（类型化和函数式）：
```cangjie
// 方式1: 类型化Actor（新增）
public interface TypedActor<T> where T <: Message {
    func receive(message: T, context: TypedActorContext<T>): Behavior<T>
}

class EchoActor <: TypedActor<StringMessage> {
    public func receive(message: StringMessage, context: TypedActorContext<StringMessage>): Behavior<StringMessage> {
        println("Echo: ${message.getContent()}")
        context.sender()?.tell(message)
        Behaviors.same()  // 保持相同行为
    }
}

// 方式2: 函数式Actor（新增）
let functionalActor = Behaviors.receive<StringMessage> { message, context =>
    println("函数式处理: ${message.getContent()}")
    Behaviors.same()
}

// 方式3: 行为组合（新增）
let composedBehavior = Behaviors.setup<StringMessage> { context =>
    Behaviors.receive { message, _ =>
        match (message.getContent()) {
            case "stop" => Behaviors.stopped()
            case content =>
                println("处理: ${content}")
                Behaviors.same()
        }
    }
}

// 方式4: DSL风格Actor定义
let dslActor = actor<StringMessage> {
    onMessage { message, context =>
        println("DSL处理: ${message.getContent()}")
        same()
    }
    onSignal { signal, context =>
        match (signal) {
            case PostStop => println("Actor停止")
            case _ => ()
        }
        same()
    }
}
```

### 5. **消息发送API** - 基于现有ActorRef增强

#### Tell模式（基于现有ActorRef.tell）：
```cangjie
// 现有API保持不变
actorRef.tell(message)

// 新增便利方法
extend ActorRef {
    // 操作符重载（如果Cangjie支持）
    public func !(message: Message): Unit { tell(message) }

    // 类型化发送
    public func tell<T>(message: T): Unit where T <: Message

    // 带发送者的便利方法
    public func tell(message: Message, from: ActorRef): Unit
}

// 使用示例
actorRef.tell(StringMessage("hello"))
actorRef ! StringMessage("hello")  // 如果支持操作符重载
```

#### Ask模式（基于现有patterns.AskPattern增强）：
```cangjie
// 现有API保持不变
let askPattern = AskPattern(timeoutMs = 5000)
let response = askPattern.ask(actorRef, request)

// 新增便利API
extend ActorRef {
    // 简化的ask方法
    public func ask<T>(message: Message, timeout: Duration = 5.seconds): Future<T>

    // 类型化ask
    public func ask<TReq, TResp>(message: TReq, timeout: Duration = 5.seconds): Future<TResp>
        where TReq <: Message, TResp <: Message

    // 操作符风格（如果支持）
    public func ?<T>(message: Message): Future<T>
}

// 使用示例
// 方式1: 简化ask
let future = actorRef.ask<StringMessage>(PingMessage(), timeout = 3.seconds)
future.onComplete { result =>
    match (result) {
        case Success(response) => println("收到: ${response.getContent()}")
        case Failure(error) => println("错误: ${error}")
    }
}

// 方式2: 操作符风格
let response = actorRef ? PingMessage()

// 方式3: 同步ask（阻塞）
let response = actorRef.askSync<StringMessage>(PingMessage(), timeout = 3.seconds)
```

### 6. **监督和生命周期API** - 基于现有supervision增强

#### 监督策略（基于现有core.supervision）：
```cangjie
// 现有API保持不变
let strategy = SupervisionConfig.createDefaultWithName("strategy")

// 新增DSL API
public struct SupervisionConfig {
    public static func restart(maxRetries: Int32 = 3, backoff: Duration = 1.seconds): SupervisionConfig
    public static func stop(): SupervisionConfig
    public static func escalate(): SupervisionConfig
    public static func resume(): SupervisionConfig

    // DSL配置
    public static func configure(block: (SupervisionBuilder) -> Unit): SupervisionConfig
}

// 使用示例
let supervision1 = SupervisionConfig.restart(maxRetries = 5, backoff = 2.seconds)
let supervision2 = SupervisionConfig.configure { builder =>
    builder.onException<IllegalArgumentException> { restart(maxRetries = 3) }
    builder.onException<RuntimeException> { escalate() }
    builder.onException<Exception> { stop() }
}
```

#### Actor生命周期钩子：
```cangjie
// 新增生命周期接口
public interface ActorLifecycle {
    func preStart(context: ActorContext): Unit { }
    func postStop(context: ActorContext): Unit { }
    func preRestart(reason: Exception, message: Option<Message>, context: ActorContext): Unit { }
    func postRestart(reason: Exception, context: ActorContext): Unit { }
}

// 在Actor中使用
class MyActor <: Actor, ActorLifecycle {
    public func preStart(context: ActorContext): Unit {
        println("Actor启动: ${context.self().path()}")
    }

    public func postStop(context: ActorContext): Unit {
        println("Actor停止: ${context.self().path()}")
    }

    // ... 其他方法
}
```

### 7. **路由和分布式API** - 基于现有routing和remote

#### 路由配置（基于现有routing）：
```cangjie
// 基于现有routing包装
public struct RouterConfig {
    public static func roundRobin(routees: Int32): RouterConfig
    public static func random(routees: Int32): RouterConfig
    public static func broadcast(): RouterConfig
    public static func consistentHashing<T>(hashFunction: (T) -> Int32): RouterConfig

    // DSL配置
    public static func configure(block: (RouterBuilder) -> Unit): RouterConfig
}

// 使用示例
let router = system.actorOf(
    Props({ => WorkerActor() })
        .withRouter(RouterConfig.roundRobin(routees = 5)),
    "worker-pool"
)
```

#### 远程通信（基于现有remote）：
```cangjie
// 远程ActorRef
let remoteRef = system.actorSelection("akka://RemoteSystem@host:port/user/remote-actor")

// 远程部署
let remoteProps = Props({ => RemoteActor() })
    .withDeploy(Deploy.remote("akka://RemoteSystem@host:port"))

let remoteActor = system.actorOf(remoteProps, "remote-deployed")
```

## � **实现计划和优先级**

### 🎯 **Phase 1: 核心API增强** (优先级: 最高)
1. **扩展现有Props** - 添加类型化配置方法
2. **增强ActorRef** - 添加便利的tell/ask方法
3. **配置工厂** - 创建MailboxConfig、DispatcherConfig工厂
4. **向后兼容** - 确保现有API继续工作

### 🎯 **Phase 2: DSL和函数式API** (优先级: 高)
1. **尾随lambda支持** - 利用Cangjie的DSL特性
2. **Pipeline操作符** - 支持函数式配置流
3. **Builder模式** - 提供流畅的配置体验
4. **类型化Actor** - 新增TypedActor接口

### 🎯 **Phase 3: 高级特性** (优先级: 中)
1. **Behavior系统** - 支持行为组合和切换
2. **生命周期钩子** - 增强Actor生命周期管理
3. **操作符重载** - 如果Cangjie支持的话
4. **异步增强** - 改进Future/Promise集成

### 🎯 **Phase 4: 企业级特性** (优先级: 中低)
1. **监督策略DSL** - 更灵活的监督配置
2. **路由增强** - 更多路由策略和配置
3. **远程通信优化** - 简化远程Actor使用
4. **集群支持** - 分布式Actor系统

## 📝 **具体改造步骤**

### 步骤1: 扩展现有Props（基于src/core/actor/actor.cj）
```cangjie
// 在现有Props<T>基础上添加
extend Props<T> where T <: Actor {
    // 类型化配置方法
    public func withMailbox(config: MailboxConfig): Props<T>
    public func withDispatcher(config: DispatcherConfig): Props<T>
    public func withSupervision(config: SupervisionConfig): Props<T>

    // DSL配置方法
    public func configure(block: (PropsBuilder<T>) -> Unit): Props<T>
}
```

### 步骤2: 创建配置工厂（新文件: src/api/config_factories.cj）
```cangjie
// 基于现有runtime包装
public struct MailboxConfig {
    public static func unbounded(): MailboxConfig
    public static func bounded(capacity: Int32): MailboxConfig
    public static func priority<T>(comparator: (T, T) -> Int32): MailboxConfig
}

public struct DispatcherConfig {
    public static func threadPool(size: Int32 = 4): DispatcherConfig
    public static func workStealing(parallelism: Int32 = 8): DispatcherConfig
    public static func pinned(): DispatcherConfig
}
```

### 步骤3: 增强ActorRef（基于src/core/actor/actor.cj）
```cangjie
// 在现有ActorRef基础上添加
extend ActorRef {
    // 类型化tell
    public func tell<T>(message: T): Unit where T <: Message

    // 简化ask
    public func ask<T>(message: Message, timeout: Duration = 5.seconds): Future<T>

    // 同步ask
    public func askSync<T>(message: Message, timeout: Duration = 5.seconds): T
}
```

## 🎯 **预期效果**

### 改造前后对比：

#### 创建Actor（改造前）：
```cangjie
let mailboxConfig = MailboxConfig.createUnboundedWithName("high-throughput-mailbox")
let dispatcherConfig = DispatcherConfig.createWorkStealingWithName("high-throughput-dispatcher")
let supervisionConfig = SupervisionConfig.createDefaultWithName("high-throughput-supervision")
let config = ActorConfigurationImpl("config", "desc", mailboxConfig, dispatcherConfig, supervisionConfig, None)
let actor = HighThroughputActor("actor-1")
```

#### 创建Actor（改造后）：
```cangjie
let system = ActorSystem.create("production")
let actorRef = system.actorOf(
    Props.create<HighThroughputActor>()
        .withMailbox(Mailbox.unbounded())
        .withDispatcher(Dispatcher.workStealing()),
    "high-throughput"
)
```

**代码减少70%，可读性提升300%！**

## 🚀 **下一步行动**

1. **立即开始**：重构ActorSystem和Props
2. **并行开发**：配置DSL和简化API
3. **测试验证**：确保新API的正确性
4. **文档更新**：提供完整的使用示例
5. **迁移指南**：帮助现有代码迁移

**🎉 目标：让CActor的API像Akka一样优雅简洁，同时充分利用Cangjie语言的函数式特性！**
