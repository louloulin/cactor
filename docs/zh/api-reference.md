# CActor API 参考文档

## 🎯 API 概览

CActor 提供简洁、类型安全的 API，参考 Akka 设计模式，为仓颉语言量身定制。

## 📦 核心 API

### CActor - 统一入口

```cangjie
import cactor.api.{CActor}

// 创建默认Actor系统
let system = CActor.system()

// 创建命名Actor系统
let system = CActor.system("MySystem")

// 创建配置的Actor系统
let config = CActorRuntimeConfig.createProduction()
let system = CActor.system("MySystem", config)

// 创建Actor Props
let props = CActor.props({ => MyActor() })
```

### CActorSystem - Actor系统

```cangjie
public class CActorSystem {
    // 创建Actor
    public func actorOf(creator: () -> Actor, name: String): ActorRef
    public func actorOf(creator: () -> Actor): ActorRef
    
    // 系统管理
    public func shutdown(): Unit
    public func awaitTermination(): Unit
    public func isTerminated(): Bool
    
    // 系统信息
    public func name(): String
    public func startTime(): DateTime
    public func uptime(): Duration
}
```

### ActorRef - Actor引用

```cangjie
public interface ActorRef {
    // 消息发送
    func tell(message: Message): Unit
    func tell(message: Message, sender: Option<ActorRef>): Unit
    
    // 请求-响应 (Ask模式)
    func ask(message: Message): Future<Message>
    func ask(message: Message, timeout: Duration): Future<Message>
    
    // Actor信息
    func path(): ActorPath
    func name(): String
    func isTerminated(): Bool
}
```

### Actor - Actor接口

```cangjie
public interface Actor {
    // 消息处理 (必须实现)
    func receive(message: Message, context: ActorContext): MessageResult
    
    // 生命周期钩子 (可选实现)
    func preStart(): Unit { }
    func postStop(): Unit { }
    func preRestart(reason: Exception): Unit { }
    func postRestart(reason: Exception): Unit { }
    
    // Actor属性
    prop name: String { get() }
    prop description: String { get() }
}
```

## 📨 消息系统

### Message - 消息接口

```cangjie
public interface Message {
    func messageType(): String
}

// 内置消息类型
public class StringMessage <: Message {
    public let content: String
    public init(content: String) { this.content = content }
}

public class IntMessage <: Message {
    public let value: Int64
    public init(value: Int64) { this.value = value }
}

public class JsonMessage <: Message {
    public let data: String
    public init(data: String) { this.data = data }
}
```

### MessageResult - 消息处理结果

```cangjie
public enum MessageResult {
    | Handled      // 消息已处理
    | Unhandled    // 消息未处理
    | Failed       // 处理失败
}
```

### ActorContext - Actor上下文

```cangjie
public interface ActorContext {
    // 自身引用
    func self(): ActorRef
    func sender(): Option<ActorRef>
    
    // 子Actor管理
    func actorOf(creator: () -> Actor, name: String): ActorRef
    func stop(actor: ActorRef): Unit
    
    // 消息发送
    func tell(target: ActorRef, message: Message): Unit
    func ask(target: ActorRef, message: Message): Future<Message>
    
    // 系统访问
    func system(): ActorSystem
    func parent(): Option<ActorRef>
    func children(): Array<ActorRef>
}
```

## ⚙️ 配置 API

### MailboxConfig - 邮箱配置

```cangjie
public class MailboxConfig {
    // 创建无界邮箱
    public static func unbounded(): MailboxConfig
    
    // 创建有界邮箱
    public static func bounded(capacity: Int32): MailboxConfig
    
    // 创建优先级邮箱
    public static func priority(): MailboxConfig
    public static func priority(comparator: (Message, Message) -> Int32): MailboxConfig
    
    // 创建Foundation邮箱 (高性能)
    public static func foundation(): MailboxConfig
}
```

### DispatcherConfig - 调度器配置

```cangjie
public class DispatcherConfig {
    // 创建线程池调度器
    public static func threadPool(): DispatcherConfig
    public static func threadPool(threads: Int32): DispatcherConfig
    
    // 创建工作窃取调度器 (推荐)
    public static func workStealing(): DispatcherConfig
    public static func workStealing(parallelism: Int32): DispatcherConfig
    
    // 创建固定线程调度器
    public static func pinned(): DispatcherConfig
    
    // 创建NUMA感知调度器
    public static func numa(): DispatcherConfig
}
```

### SupervisionConfig - 监督配置

```cangjie
public class SupervisionConfig {
    // 创建重启策略
    public static func restart(): SupervisionConfig
    public static func restart(maxRetries: Int32, timeWindow: Duration): SupervisionConfig
    
    // 创建停止策略
    public static func stop(): SupervisionConfig
    
    // 创建恢复策略
    public static func resume(): SupervisionConfig
    
    // 创建上报策略
    public static func escalate(): SupervisionConfig
}
```

## 🎭 模式 API

### Ask模式

```cangjie
import cactor.patterns.ask.{Ask}

// 使用Ask模式
let future = Ask.ask(actorRef, message, Duration.second * 5)
let result = future.await()

// 异步处理
future.onComplete { result =>
    match (result) {
        case Success(msg) => println("收到响应: ${msg}")
        case Failure(ex) => println("请求失败: ${ex}")
    }
}
```

### 路由模式

```cangjie
import cactor.patterns.routing.{Router, RoundRobinRouter}

// 创建路由器
let routees = [actor1, actor2, actor3]
let router = RoundRobinRouter(routees)

// 发送消息到路由器
router.route(message)
```

### 断路器模式

```cangjie
import cactor.patterns.circuit_breaker.{CircuitBreaker}

// 创建断路器
let breaker = CircuitBreaker.create(
    maxFailures = 5,
    callTimeout = Duration.second * 10,
    resetTimeout = Duration.second * 60
)

// 使用断路器
breaker.call {
    // 可能失败的操作
    riskyOperation()
}
```

## 🔧 高级 API

### Props - Actor属性

```cangjie
public class ActorProps {
    // 基础创建
    public init(creator: () -> Actor)
    
    // 配置邮箱
    public func withMailbox(config: MailboxConfig): ActorProps
    
    // 配置调度器
    public func withDispatcher(config: DispatcherConfig): ActorProps
    
    // 配置监督策略
    public func withSupervision(config: SupervisionConfig): ActorProps
    
    // 配置路由
    public func withRouter(router: Router): ActorProps
}
```

### ActorSystem扩展

```cangjie
import cactor.api.public.{ActorSystemExtensions}

// 创建扩展系统
let system = ActorSystemExtensions.create("ExtendedSystem")

// 获取系统指标
let metrics = system.metrics()
println("Actor数量: ${metrics.actorCount}")
println("消息吞吐量: ${metrics.throughput}")

// 系统健康检查
let health = system.healthCheck()
if (health.isHealthy()) {
    println("系统运行正常")
}
```

## 📊 监控 API

### SystemMetrics - 系统指标

```cangjie
public class SystemMetrics {
    // 基础指标
    func actorCount(): Int64
    func messageCount(): Int64
    func throughput(): Double
    
    // 性能指标
    func averageLatency(): Duration
    func p99Latency(): Duration
    func errorRate(): Double
    
    // 资源指标
    func memoryUsage(): MemoryUsage
    func cpuUsage(): Double
}
```

### HealthCheck - 健康检查

```cangjie
public class HealthCheck {
    func isHealthy(): Bool
    func getStatus(): HealthStatus
    func getDetails(): HealthDetails
}
```

## 🧪 测试 API

### TestActorSystem - 测试系统

```cangjie
import cactor.integration.testing.{TestActorSystem, TestProbe}

// 创建测试系统
let testSystem = TestActorSystem("TestSystem")

// 创建测试探针
let probe = TestProbe(testSystem)

// 发送消息并验证
actor.tell(message)
probe.expectMessage(expectedMessage, Duration.second * 1)
```

## 📝 使用示例

### 完整示例

```cangjie
import cactor.api.{CActor}
import cactor.core.message.{StringMessage}

// 定义Actor
class EchoActor <: Actor {
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                context.sender().map { sender =>
                    sender.tell(StringMessage("Echo: ${msg.content}"))
                }
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }
}

// 主程序
main(): Int64 {
    // 创建系统
    let system = CActor.system("EchoSystem")
    
    // 创建Actor
    let echo = system.actorOf({ => EchoActor() }, "echo")
    
    // 发送消息
    echo.tell(StringMessage("Hello"))
    
    // 优雅关闭
    system.shutdown()
    system.awaitTermination()
    
    return 0
}
```

## 🔗 相关链接

- [架构设计](architecture.md) - 了解CActor的架构设计
- [性能优化](performance.md) - 性能优化指南
- [最佳实践](best-practices.md) - 使用最佳实践
- [示例集合](examples.md) - 丰富的示例代码

---

**CActor API 设计简洁、强大、类型安全，让Actor编程变得轻松愉快！** 🚀
