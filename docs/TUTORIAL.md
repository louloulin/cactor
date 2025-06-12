# CACtor 教程

## 第一章：入门指南

### 1.1 什么是Actor模型？

Actor模型是一种并发计算的数学模型，它将"Actor"作为并发计算的基本单元。每个Actor：

- **封装状态**：拥有私有状态，不与其他Actor共享
- **消息传递**：通过异步消息与其他Actor通信
- **行为定义**：定义如何响应接收到的消息
- **创建Actor**：可以创建新的Actor
- **故障隔离**：一个Actor的失败不会影响其他Actor

### 1.2 为什么选择CACtor？

CACtor 2.0基于仓颉语言实现，具有以下优势：

- **类型安全**：利用仓颉强类型系统，编译时发现错误
- **高性能**：优化的消息传递和内存管理
- **企业级**：完整的监督、路由、断路器等特性
- **分布式**：内置远程通信和集群支持
- **易用性**：简洁的API和丰富的文档

### 1.3 第一个Actor程序

让我们创建一个简单的Hello World Actor：

```cangjie
import cactor.core.actor.{Actor, ActorContext}
import cactor.core.message.{Message, StringMessage}

class HelloActor <: Actor {
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case msg: StringMessage => 
                println("Hello, ${msg.getContent()}!")
            case _ => 
                println("Unknown message type")
        }
    }
}

main(): Int64 {
    let actor = HelloActor()
    let context = MockActorContext()
    
    actor.receive(StringMessage("World"), context)
    actor.receive(StringMessage("CACtor"), context)
    
    return 0
}
```

## 第二章：核心概念

### 2.1 Actor生命周期

Actor有明确的生命周期，包括以下阶段：

```cangjie
class LifecycleActor <: Actor {
    public func preStart(): Unit {
        println("Actor即将启动")
    }
    
    public func postStart(): Unit {
        println("Actor已经启动")
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        // 处理消息
    }
    
    public func preRestart(reason: Exception): Unit {
        println("Actor即将重启: ${reason.message}")
    }
    
    public func postRestart(reason: Exception): Unit {
        println("Actor已经重启")
    }
    
    public func postStop(): Unit {
        println("Actor已经停止")
    }
}
```

### 2.2 消息设计

设计良好的消息是Actor系统的关键：

```cangjie
// 命令消息
public struct CreateUser <: Message {
    public let name: String
    public let email: String
}

public struct DeleteUser <: Message {
    public let userId: String
}

// 事件消息
public struct UserCreated <: Message {
    public let userId: String
    public let timestamp: DateTime
}

// 查询消息
public struct GetUser <: Message {
    public let userId: String
}

public struct UserInfo <: Message {
    public let userId: String
    public let name: String
    public let email: String
}
```

### 2.3 状态管理

Actor应该封装状态并通过消息修改：

```cangjie
class UserManagerActor <: Actor {
    private let users: HashMap<String, User>
    private let userIdCounter: AtomicInt64
    
    public init() {
        this.users = HashMap<String, User>()
        this.userIdCounter = AtomicInt64(0)
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case cmd: CreateUser => 
                createUser(cmd.name, cmd.email)
            case cmd: DeleteUser => 
                deleteUser(cmd.userId)
            case query: GetUser => 
                getUserInfo(query.userId)
            case _ => 
                println("Unknown message")
        }
    }
    
    private func createUser(name: String, email: String): Unit {
        let userId = "user-${userIdCounter.fetchAdd(1)}"
        let user = User(userId, name, email)
        users[userId] = user
        println("Created user: ${userId}")
    }
    
    private func deleteUser(userId: String): Unit {
        match (users.remove(userId)) {
            case Some(user) => 
                println("Deleted user: ${userId}")
            case None => 
                println("User not found: ${userId}")
        }
    }
    
    private func getUserInfo(userId: String): Unit {
        match (users.get(userId)) {
            case Some(user) => 
                println("User info: ${user.toString()}")
            case None => 
                println("User not found: ${userId}")
        }
    }
}
```

## 第三章：高级特性

### 3.1 Ask模式

Ask模式允许同步请求-响应通信：

```cangjie
import cactor.pattern.ask.{AskPattern, AskRequest, AskResponse}

class CalculatorActor <: Actor {
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case req: AskRequest => 
                let content = req.getContent()
                if (content.startsWith("add:")) {
                    let numbers = parseNumbers(content.substring(4))
                    let result = numbers[0] + numbers[1]
                    // 在实际实现中，这里会发送响应给发送者
                    println("计算结果: ${result}")
                }
            case _ => 
                println("Unknown message")
        }
    }
    
    private func parseNumbers(str: String): Array<Int64> {
        // 简化的数字解析
        [1, 2]  // 返回示例数据
    }
}

// 使用Ask模式
func useAskPattern(): Unit {
    let calculator = CalculatorActor()
    let askPattern = AskPattern(5000)  // 5秒超时
    let request = AskRequest("add:10,20")
    
    // 在实际实现中，这里会等待响应
    calculator.receive(request, MockActorContext())
}
```

### 3.2 监督策略

监督策略定义了如何处理子Actor的失败：

```cangjie
import cactor.supervision.*

class SupervisorActor <: Actor {
    private let strategy: SupervisionStrategy
    
    public init() {
        this.strategy = OneForOneStrategy(
            maxRetries = 3,
            withinTimeRange = Duration.minute * 1,
            decider = { exception => 
                match (exception) {
                    case _: IllegalArgumentException => SupervisionDirective.Restart
                    case _: NullPointerException => SupervisionDirective.Stop
                    case _ => SupervisionDirective.Escalate
                }
            }
        )
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        // 处理消息和监督逻辑
    }
}
```

### 3.3 路由

路由允许将消息分发给多个Actor：

```cangjie
import cactor.routing.*

class WorkerPoolManager {
    private let workers: Array<WorkerActor>
    private let router: Router
    
    public init(workerCount: Int64) {
        let workerList = ArrayList<WorkerActor>()
        for (i in 0..workerCount) {
            workerList.append(WorkerActor("worker-${i}"))
        }
        this.workers = workerList.toArray()
        this.router = RoundRobinRouter(workers)
    }
    
    public func distributeWork(message: Message): Unit {
        match (router.selectRoutee(workers, message)) {
            case Some(worker) => 
                worker.receive(message, MockActorContext())
            case None => 
                println("No available worker")
        }
    }
}
```

## 第四章：分布式系统

### 4.1 远程通信

CACtor支持透明的远程Actor通信：

```cangjie
import cactor.remote.*
import cactor.network.*

// 启动远程服务
func startRemoteService(): Unit {
    let address = NetworkAddress("localhost", 8080)
    let remoteManager = SimpleRemoteManager(address, TransportProtocol.TCP)
    
    remoteManager.start()
    println("远程服务启动在 ${address.toString()}")
}

// 发送远程消息
func sendRemoteMessage(): Unit {
    let remoteAddress = NetworkAddress("remote-host", 8080)
    let message = StringMessage("Hello from remote!")
    
    // 在实际实现中，这里会通过网络发送消息
    println("发送远程消息到 ${remoteAddress.toString()}")
}
```

### 4.2 集群管理

集群功能允许多个节点协同工作：

```cangjie
import cactor.cluster.*

func setupCluster(): Unit {
    let config = ClusterConfig(
        nodeName = "node1",
        bindAddress = NetworkAddress("localhost", 8080),
        seedNodes = [
            NetworkAddress("seed1", 8080),
            NetworkAddress("seed2", 8080)
        ]
    )
    
    let clusterManager = SimpleClusterManager(config)
    clusterManager.start()
    
    println("集群节点启动: ${config.nodeName}")
}
```

### 4.3 故障转移

故障转移确保系统的高可用性：

```cangjie
import cactor.cluster.failover.*

func setupFailover(): Unit {
    let config = FailoverConfig(
        heartbeatInterval = Duration.second * 5,
        failureThreshold = 3,
        recoveryTimeout = Duration.second * 30
    )
    
    let failoverManager = SimpleFailoverManager(config)
    failoverManager.start()
    
    println("故障转移管理器启动")
}
```

## 第五章：性能优化

### 5.1 内存管理

使用对象池减少GC压力：

```cangjie
import cactor.memory.*

func useObjectPool(): Unit {
    let pool = ObjectPool<StringBuilder>(
        capacity = 100,
        factory = { => StringBuilder() },
        resetFunc = { sb => sb.clear() },
        warmupSize = 10
    )
    
    // 获取对象
    let sb = pool.acquire()
    sb.append("Hello, ")
    sb.append("World!")
    
    // 使用完毕后释放
    pool.release(sb)
}
```

### 5.2 批处理

批处理可以提高消息处理效率：

```cangjie
import cactor.mailbox.batching.*

class BatchProcessorActor <: Actor {
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case batch: MessageBatch => 
                processBatch(batch.getMessages())
            case single: Message => 
                processSingle(single)
        }
    }
    
    private func processBatch(messages: Array<Message>): Unit {
        println("批处理 ${messages.size} 条消息")
        for (message in messages) {
            // 处理单个消息
        }
    }
    
    private func processSingle(message: Message): Unit {
        println("处理单个消息")
    }
}
```

### 5.3 性能监控

监控系统性能以识别瓶颈：

```cangjie
import cactor.monitoring.*
import cactor.debug.*

func monitorPerformance(): Unit {
    let diagnostics = SystemDiagnostics()
    diagnostics.enableProfiling()
    diagnostics.enableTracing()
    
    // 执行一些操作...
    
    let report = diagnostics.diagnoseSystem()
    println("性能报告: ${report.toString()}")
}
```

## 第六章：测试

### 6.1 单元测试

测试单个Actor的行为：

```cangjie
func testCalculatorActor(): Unit {
    let calculator = CalculatorActor()
    let context = MockActorContext()
    
    // 测试加法
    let addRequest = AskRequest("add:10,20")
    calculator.receive(addRequest, context)
    
    // 验证结果（在实际测试中会有断言）
    println("计算器测试完成")
}
```

### 6.2 集成测试

测试多个Actor的协作：

```cangjie
func testActorCollaboration(): Unit {
    let supervisor = SupervisorActor()
    let worker1 = WorkerActor("worker1")
    let worker2 = WorkerActor("worker2")
    
    // 模拟协作场景
    supervisor.receive(StringMessage("start"), MockActorContext())
    worker1.receive(StringMessage("work"), MockActorContext())
    worker2.receive(StringMessage("work"), MockActorContext())
    
    println("协作测试完成")
}
```

### 6.3 性能测试

测试系统的性能指标：

```cangjie
func performanceTest(): Unit {
    let startTime = DateTime.now()
    
    // 执行大量操作
    for (i in 0..10000) {
        let actor = HelloActor()
        actor.receive(StringMessage("test"), MockActorContext())
    }
    
    let endTime = DateTime.now()
    let duration = endTime.toUnixTimeStamp().toMilliseconds() - startTime.toUnixTimeStamp().toMilliseconds()
    
    println("性能测试完成，耗时: ${duration}ms")
}
```

## 第七章：最佳实践

### 7.1 消息设计原则

1. **不可变性**：消息应该是不可变的
2. **序列化友好**：消息应该易于序列化
3. **语义清晰**：消息名称应该表达明确的意图
4. **版本兼容**：考虑消息的向后兼容性

### 7.2 Actor设计原则

1. **单一职责**：每个Actor应该有明确的职责
2. **无状态共享**：不要在Actor之间共享可变状态
3. **错误隔离**：使用监督策略处理错误
4. **响应式**：Actor应该快速响应消息

### 7.3 系统架构原则

1. **分层设计**：使用分层的Actor层次结构
2. **松耦合**：Actor之间通过消息松耦合
3. **可扩展性**：设计支持水平扩展的架构
4. **容错性**：使用监督和故障转移机制

## 第八章：故障排除

### 8.1 常见问题

**问题1：消息丢失**
- 检查Actor是否正确启动
- 验证消息路由配置
- 检查网络连接（远程消息）

**问题2：性能问题**
- 使用性能分析工具
- 检查消息积压情况
- 优化消息处理逻辑

**问题3：内存泄漏**
- 检查对象池使用
- 验证Actor生命周期管理
- 监控内存使用情况

### 8.2 调试技巧

1. **启用日志**：使用详细的日志记录
2. **性能分析**：使用内置的性能分析工具
3. **消息跟踪**：启用消息跟踪功能
4. **系统诊断**：定期生成系统诊断报告

### 8.3 监控和告警

设置适当的监控和告警机制：

```cangjie
import cactor.monitoring.*

func setupMonitoring(): Unit {
    let metricsCollector = MetricsCollector()
    
    // 设置告警阈值
    metricsCollector.setThreshold("error.rate", 0.05)  // 5%错误率
    metricsCollector.setThreshold("response.time", 1000)  // 1秒响应时间
    
    // 定期检查指标
    // 在实际实现中，这里会有定时任务
    println("监控系统已设置")
}
```

---

这个教程涵盖了CACtor 2.0的主要概念和用法。通过学习这些内容，您应该能够构建高性能、可扩展的Actor系统。

更多详细信息请参考：
- [API文档](API.md)
- [示例代码](../examples/)
- [性能指南](PERFORMANCE.md)
