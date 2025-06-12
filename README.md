# 仓颉Actor系统

基于仓颉编程语言实现的Actor模型系统，提供高性能、类型安全的并发编程框架。

## 项目概述

本项目实现了一个简化但功能完整的Actor系统，包括：

- **Actor接口**: 定义Actor的基本行为和生命周期
- **消息系统**: 类型安全的消息传递机制
- **Actor上下文**: 管理Actor的状态和消息队列
- **运行时系统**: 负责Actor的创建、调度和生命周期管理
- **并发安全**: 基于仓颉的原子类型和同步原语

## 核心特性

### 1. 类型安全
- 编译时类型检查
- 强类型消息系统
- 接口约束

### 2. 高性能并发
- 基于仓颉的轻量级线程(spawn)
- 原子操作保证线程安全
- 互斥锁保护共享状态

### 3. 易用的API
- 简洁的Actor定义
- 直观的消息传递
- 灵活的生命周期管理

## 核心概念

### Actor
Actor是系统中的基本计算单元，封装状态和行为：

```cangjie
public interface Actor {
    prop name: String
    prop description: String
    
    func started(): Unit
    func stopping(): Bool
    func stopped(): Unit
}
```

### Message
消息是Actor间通信的载体：

```cangjie
public interface Message {
    func messageType(): String
    func priority(): Int32
}
```

### ActorContext
Actor的执行上下文，管理状态和消息队列：

```cangjie
public class ActorContext {
    func getName(): String
    func getState(): ActorState
    func sendMessage(message: Message): Bool
    func receiveMessage(): Option<Message>
}
```

### ActorRuntime
Actor系统的运行时管理器：

```cangjie
public class ActorRuntime {
    func spawnActor<T>(actor: T, name: String): ActorRef where T <: Actor
    func find(name: String): Option<ActorRef>
    func shutdown(): Unit
}
```

## 快速开始

### 1. 创建Actor

```cangjie
public class CalculatorActor <: Actor {
    private var value: Int64 = 0
    
    public prop name: String {
        get() { "Calculator" }
    }
    
    public prop description: String {
        get() { "Simple calculator actor" }
    }
    
    public func add(operand: Int64): Int64 {
        value += operand
        return value
    }
}
```

### 2. 定义消息

```cangjie
public struct AddMessage <: Message {
    public let operand: Int64
    
    public func messageType(): String {
        "AddMessage"
    }
}
```

### 3. 启动Actor系统

```cangjie
func main(): Unit {
    let runtime = ActorRuntime()
    
    // 创建并启动Actor
    let calculator = CalculatorActor()
    let actorRef = runtime.spawnActor(calculator, "calculator")
    
    // 发送消息
    let message = AddMessage(10)
    actorRef.send(message)
    
    // 清理
    runtime.shutdown()
}
```

## 项目结构

```
cangjie-actor/
├── src/
│   └── actor.cj              # 核心Actor系统实现
├── examples/
│   └── ping_pong.cj          # 乒乓球示例
├── tests/
│   └── actor_tests.cj        # 单元测试
├── cjpm.toml                 # 项目配置
└── README.md                 # 项目说明
```

## 构建和运行

### 构建项目

```bash
cjpm build
```

### 运行示例

```bash
# 运行乒乓球示例
cjpm run cangjie_actor.examples.ping_pong

# 运行测试
cjpm run cangjie_actor.tests.actor_tests
```

## 示例

### 乒乓球Actor

演示基础的Actor消息传递：

```cangjie
public class PingPongActor <: Actor {
    public func processMessage(message: Message): Unit {
        match (message.messageType()) {
            case "PingMessage" => {
                println("Received Ping")
                // 发送Pong响应
            }
            case "PongMessage" => {
                println("Received Pong")
            }
        }
    }
}
```

### 计算器Actor

演示有状态的Actor：

```cangjie
public class CalculatorActor <: Actor {
    private var value: Int64 = 0
    private let lock: Mutex = Mutex()
    
    public func add(operand: Int64): Int64 {
        lock.lock()
        defer { lock.unlock() }
        value += operand
        return value
    }
}
```

## 设计原则

1. **类型安全**: 所有消息和Actor都有明确的类型定义
2. **线程安全**: 使用原子类型和锁保证并发安全
3. **性能优化**: 利用仓颉的零成本抽象和高效并发机制
4. **易于扩展**: 通过接口和继承支持自定义行为
5. **错误处理**: 完善的异常处理和错误恢复机制

## 性能特性

- **轻量级线程**: 基于仓颉的spawn机制，创建成本低
- **无锁数据结构**: 使用原子类型和并发集合
- **内存效率**: 值类型优化，减少堆分配
- **高吞吐量**: 支持大量并发Actor

## 未来计划

- [ ] 消息序列化支持
- [ ] 远程Actor通信
- [ ] 监督策略实现
- [ ] 性能监控和指标
- [ ] 集群支持
- [ ] 持久化机制

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 许可证

MIT License

## 参考

- [Rust Actix框架](https://actix.rs/)
- [仓颉编程语言官方文档](https://cangjie-lang.cn/)
- [Actor模型理论](https://en.wikipedia.org/wiki/Actor_model)
