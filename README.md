# CACtor - 仓颉Actor系统

基于仓颉编程语言实现的模块化Actor系统，参考Akka和Actix框架设计，提供高性能、类型安全的并发编程框架。

## 项目概述

CACtor是一个完全模块化的Actor系统实现，采用现代化的架构设计：

- **核心模块** (`cactor.core`): 定义Actor系统的基础接口和抽象
- **实现模块** (`cactor.impl`): 提供具体的Actor系统实现
- **工具模块** (`cactor.util`): 包含辅助类和工具函数
- **示例模块** (`cactor.examples`): 展示各种使用场景

## 架构特性

### 1. 模块化设计
- **分层架构**: 核心接口与实现分离
- **可扩展性**: 支持自定义实现和扩展
- **松耦合**: 模块间依赖清晰，易于维护

### 2. 类型安全
- **强类型系统**: 利用仓颉的类型系统确保编译时安全
- **接口约束**: 明确的接口定义和实现契约
- **泛型支持**: 类型化Actor和消息处理

### 3. 高性能并发
- **轻量级Actor**: 基于仓颉的spawn机制
- **异步消息传递**: Tell和Ask模式支持
- **并发安全**: 原子操作和互斥锁保护

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

### 1. 定义Actor

```cangjie
import cactor.*

// 定义一个简单的计算器Actor
public class CalculatorActor <: UntypedActor {
    private var result: Int64 = 0

    public prop name: String {
        get() { "Calculator" }
    }

    public prop description: String {
        get() { "Simple calculator actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message.messageType()) {
            case "AddMessage" => {
                match (message) {
                    case addMsg: AddMessage => {
                        result += addMsg.getValue()
                        println("Result: ${result}")
                        MessageResult.Handled
                    }
                    case _ => MessageResult.Unhandled
                }
            }
            case _ => MessageResult.Unhandled
        }
    }
}
```

### 2. 定义消息类型

```cangjie
public struct AddMessage <: UserMessage {
    private let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func messageType(): String { "AddMessage" }
    public func getValue(): Int64 { value }
}
```

### 3. 创建和使用Actor系统

```cangjie
// 创建Actor系统
let system = CActorSystem.create("my-system")

// 创建Actor
let props = PropsFactory.create<CalculatorActor>(() => CalculatorActor())
let calculatorRef = system.actorOf(props, "calculator")

// 发送消息
calculatorRef.tell(AddMessage(10))
calculatorRef.tell(AddMessage(20))

// 关闭系统
system.terminate()
```

## 项目结构

```
cactor/
├── src/
│   ├── actor.cj              # 主包导出
│   ├── core/                 # 核心接口模块
│   │   ├── pkg.cj            # 核心包导出
│   │   ├── actor/            # Actor相关接口
│   │   │   ├── actor.cj      # Actor基础接口
│   │   │   └── actor_ref.cj  # Actor引用接口
│   │   ├── message/          # 消息系统
│   │   │   └── message.cj    # 消息接口和实现
│   │   ├── context/          # Actor上下文
│   │   │   └── actor_context.cj
│   │   ├── system/           # Actor系统
│   │   │   └── actor_system.cj
│   │   └── mailbox/          # 邮箱系统
│   │       └── mailbox.cj
│   ├── impl/                 # 具体实现模块
│   │   ├── pkg.cj            # 实现包导出
│   │   ├── actor/            # Actor实现
│   │   │   └── local_actor_ref.cj
│   │   └── system/           # 系统实现
│   │       └── actor_system_impl.cj
│   └── util/                 # 工具模块
│       └── simple_types.cj   # 辅助类型
├── examples/
│   ├── modular_demo.cj       # 模块化设计演示
│   └── ping_pong.cj          # 乒乓球示例
├── tests/
│   └── simple_test.cj        # 基础测试
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
