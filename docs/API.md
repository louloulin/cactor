# CActor  API 文档

## 核心API

### Actor接口

```cangjie
public interface Actor {
    func receive(message: Message, context: ActorContext): Unit
    func preStart(): Unit
    func postStart(): Unit
    func preRestart(reason: Exception): Unit
    func postRestart(reason: Exception): Unit
    func postStop(): Unit
}
```

#### 方法说明

- **receive**: 处理接收到的消息
- **preStart**: Actor启动前调用
- **postStart**: Actor启动后调用
- **preRestart**: Actor重启前调用
- **postRestart**: Actor重启后调用
- **postStop**: Actor停止后调用

### ActorContext接口

```cangjie
public interface ActorContext {
    func stop(): Unit
    func isStopped(): Bool
}
```

#### 方法说明

- **stop**: 停止当前Actor
- **isStopped**: 检查Actor是否已停止

### Message接口

```cangjie
public interface Message {
    // 标记接口，所有消息都需要实现此接口
}
```

#### 内置消息类型

```cangjie
// 字符串消息
public class StringMessage <: Message {
    public init(content: String)
    public func getContent(): String
}

// Ask请求消息
public class AskRequest <: Message {
    public init(content: String)
    public func getContent(): String
}

// Ask响应消息
public class AskResponse <: Message {
    public init(content: String)
    public func getContent(): String
}
```

## 消息传递API

### Tell模式（异步）

```cangjie
// 发送消息给Actor
actor.tell(message, sender)
```

### Ask模式（同步）

```cangjie
import cactor.pattern.ask.{AskPattern, AskRequest}

let askPattern = AskPattern(timeoutMs)
let request = AskRequest("ping")

match (askPattern.ask(actorRef, request)) {
    case Some(response) => 
        println("收到响应: ${response}")
    case None => 
        println("请求超时")
}
```

## 路由API

### 路由策略

```cangjie
import cactor.routing.*

// 轮询路由
let roundRobinRouter = RoundRobinRouter(workers)

// 随机路由
let randomRouter = RandomRouter(workers)

// 一致性哈希路由
let hashRouter = ConsistentHashRouter(workers)

// 广播路由
let broadcastRouter = BroadcastRouter(workers)
```

### 使用路由

```cangjie
// 选择路由目标
match (router.selectRoutee(routees, message)) {
    case Some(actorRef) => 
        actorRef.tell(message, sender)
    case None => 
        println("没有可用的路由目标")
}
```

## 监督API

### 监督策略

```cangjie
import cactor.supervision.*

// 重启策略
let restartStrategy = OneForOneStrategy(
    maxRetries = 3,
    withinTimeRange = Duration.minute * 1,
    decider = { exception => SupervisionDirective.Restart }
)

// 停止策略
let stopStrategy = OneForOneStrategy(
    maxRetries = 0,
    withinTimeRange = Duration.minute * 1,
    decider = { exception => SupervisionDirective.Stop }
)

// 恢复策略
let resumeStrategy = OneForOneStrategy(
    maxRetries = 5,
    withinTimeRange = Duration.minute * 1,
    decider = { exception => SupervisionDirective.Resume }
)
```

### 监督指令

```cangjie
public enum SupervisionDirective {
    | Restart    // 重启Actor
    | Stop       // 停止Actor
    | Resume     // 恢复Actor
    | Escalate   // 升级到上级监督者
}
```

## 断路器API

### 创建断路器

```cangjie
import cactor.circuit_breaker.*

let config = CircuitBreakerConfig(
    failureThreshold = 5,        // 失败阈值
    timeout = Duration.second * 10,      // 超时时间
    resetTimeout = Duration.second * 30  // 重置超时
)

let circuitBreaker = CircuitBreaker(config)
```

### 使用断路器

```cangjie
// 执行受保护的操作
match (circuitBreaker.call({ => riskyOperation() })) {
    case Some(result) => 
        println("操作成功: ${result}")
    case None => 
        println("断路器开启，操作被拒绝")
}

// 检查断路器状态
match (circuitBreaker.getState()) {
    case CircuitBreakerState.Closed => 
        println("断路器关闭")
    case CircuitBreakerState.Open => 
        println("断路器开启")
    case CircuitBreakerState.HalfOpen => 
        println("断路器半开")
}
```

## 远程通信API

### 远程管理器

```cangjie
import cactor.remote.*
import cactor.network.*

let address = NetworkAddress("localhost", 8080)
let remoteManager = SimpleRemoteManager(address, TransportProtocol.TCP)

// 启动远程服务
remoteManager.start()

// 发送远程消息
let remoteAddress = NetworkAddress("remote-host", 8080)
remoteManager.sendMessage(remoteAddress, message)

// 停止远程服务
remoteManager.stop()
```

### 网络传输

```cangjie
import cactor.network.*

// TCP传输
let tcpTransport = TransportFactory.createTcpTransport(address)

// UDP传输
let udpTransport = TransportFactory.createUdpTransport(address)

// 启动传输
tcpTransport.start()

// 发送数据
tcpTransport.send(data, targetAddress)

// 停止传输
tcpTransport.stop()
```

## 集群API

### 集群管理

```cangjie
import cactor.cluster.*

let clusterConfig = ClusterConfig(
    nodeName = "node1",
    bindAddress = NetworkAddress("localhost", 8080),
    seedNodes = [
        NetworkAddress("seed1", 8080),
        NetworkAddress("seed2", 8080)
    ]
)

let clusterManager = SimpleClusterManager(clusterConfig)

// 启动集群
clusterManager.start()

// 获取集群成员
let members = clusterManager.getMembers()

// 离开集群
clusterManager.leave()
```

### 故障转移

```cangjie
import cactor.cluster.failover.*

let failoverConfig = FailoverConfig(
    heartbeatInterval = Duration.second * 5,
    failureThreshold = 3,
    recoveryTimeout = Duration.second * 30
)

let failoverManager = SimpleFailoverManager(failoverConfig)

// 启动故障转移
failoverManager.start()

// 检查节点状态
let nodeStatus = failoverManager.getNodeStatus(nodeId)
```

## 配置API

### 配置管理

```cangjie
import cactor.config.*

let configManager = ConfigurationManager()

// 设置配置
configManager.setConfig("actor.dispatcher.threads", ConfigValue.IntValue(8))
configManager.setConfig("actor.mailbox.size", ConfigValue.IntValue(1000))

// 获取配置
let threadCount = configManager.getIntOrDefault("actor.dispatcher.threads", 4)
let mailboxSize = configManager.getIntOrDefault("actor.mailbox.size", 100)

// 加载配置文件
configManager.loadFromFile("application.conf")
```

### 配置值类型

```cangjie
public enum ConfigValue {
    | StringValue(String)
    | IntValue(Int64)
    | FloatValue(Float64)
    | BoolValue(Bool)
    | ArrayValue(Array<ConfigValue>)
}
```

## 日志API

### 日志器

```cangjie
import cactor.logging.*

// 获取日志器
let logger = LoggerFactory.getLogger("my.app")

// 记录不同级别的日志
logger.trace("跟踪信息")
logger.debug("调试信息")
logger.info("普通信息")
logger.warn("警告信息")
logger.error("错误信息")
logger.fatal("致命错误")
```

### 日志配置

```cangjie
// 设置全局日志级别
LoggerFactory.setDefaultLevel(LogLevel.INFO)

// 配置日志输出
let config = LoggingConfig(
    LogLevel.DEBUG,
    true,  // 启用文件日志
    true,  // 启用异步日志
    "app.log",
    10485760,  // 10MB
    5
)

let logManager = SystemLogManager()
logManager.configureLogging(config)
```

### Actor日志

```cangjie
import cactor.logging.*

// Actor日志器
let actorLogger = ActorLogger("/user/my-actor", "my.app")

// 记录Actor事件
actorLogger.logEvent(ActorLogEvent.ActorStarted("/user/my-actor"))
actorLogger.logEvent(ActorLogEvent.MessageReceived("/user/my-actor", "StringMessage"))

// 直接日志记录
actorLogger.info("Actor处理消息")
actorLogger.error("Actor处理失败")
```

## 调试API

### 性能分析

```cangjie
import cactor.debug.*

let profiler = PerformanceProfiler(1000)

// 启用性能分析
profiler.enable()

// 记录性能样本
profiler.recordSample("/user/actor", "processMessage", 5)

// 生成性能报告
let report = profiler.getReport()
println("性能报告: ${report.toString()}")

// 清除数据
profiler.clear()
```

### 消息跟踪

```cangjie
let tracer = MessageTracer(1000)

// 启用消息跟踪
tracer.enable()

// 跟踪消息
tracer.traceMessage("StringMessage", "/user/sender", "/user/receiver", 5, "SUCCESS")

// 获取跟踪记录
let traces = tracer.getTraces()
let actorTraces = tracer.getTracesByActor("/user/sender")
```

### 系统诊断

```cangjie
let diagnostics = SystemDiagnostics()

// 启用诊断功能
diagnostics.enableProfiling()
diagnostics.enableTracing()

// 记录Actor状态
let snapshot = ActorSnapshot("/user/actor", "MyActor", "RUNNING", 100, DateTime.now(), 1024)
diagnostics.recordActorSnapshot(snapshot)

// 获取系统快照
let systemSnapshot = diagnostics.getSystemSnapshot()

// 生成诊断报告
let report = diagnostics.diagnoseSystem()
diagnostics.printDiagnostics()
```

## 内存管理API

### 对象池

```cangjie
import cactor.memory.*

// 创建对象池
let pool = ObjectPool<String>(
    capacity = 100,
    factory = { => "default" },
    resetFunc = { obj => },
    warmupSize = 10
)

// 获取对象
let obj = pool.acquire()

// 释放对象
pool.release(obj)

// 获取统计信息
let stats = pool.getStatistics()
println("池统计: ${stats.toString()}")
```

### 内存监控

```cangjie
let memoryMonitor = MemoryMonitor()

// 启动监控
memoryMonitor.start()

// 获取内存使用情况
let usage = memoryMonitor.getMemoryUsage()
println("内存使用: ${usage}bytes")

// 停止监控
memoryMonitor.stop()
```

## 序列化API

### JSON序列化

```cangjie
import cactor.serialization.*

let jsonSerializer = JsonSerializer()

// 序列化
let data = "Hello, World!"
let serialized = jsonSerializer.serialize(data)

// 反序列化
let deserialized = jsonSerializer.deserialize(serialized)
```

### 二进制序列化

```cangjie
let binarySerializer = BinarySerializer()

// 序列化
let serialized = binarySerializer.serialize(data)

// 反序列化
let deserialized = binarySerializer.deserialize(serialized)
```

## 监控API

### 指标收集

```cangjie
import cactor.monitoring.*

let metricsCollector = MetricsCollector()

// 记录计数器
metricsCollector.incrementCounter("messages.processed")

// 记录计时器
metricsCollector.recordTimer("message.processing.time", 5)

// 记录仪表盘
metricsCollector.recordGauge("active.actors", 100)

// 获取指标
let metrics = metricsCollector.getMetrics()
```

### 健康检查

```cangjie
let healthChecker = HealthChecker()

// 添加健康检查
healthChecker.addCheck("database", { => checkDatabase() })
healthChecker.addCheck("cache", { => checkCache() })

// 执行健康检查
let healthStatus = healthChecker.checkHealth()
println("健康状态: ${healthStatus.toString()}")
```
