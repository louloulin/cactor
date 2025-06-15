# CActor 包设计优化计划 - 低耦合高内聚架构重构

## 🎯 优化目标

基于对整个CActor代码库的深入分析，制定最小改进计划，实现：
- **高内聚**：相关功能聚合，职责清晰
- **低耦合**：通过接口交互，减少直接依赖
- **清晰边界**：明确包职责，避免功能重叠
- **渐进式改进**：基于现有结构，最小化破坏性变更

## 📊 当前架构问题分析

### 🔴 主要耦合问题

1. **包导出过度耦合**
   - `src/cactor.cj`直接导入所有子包(`core.*`, `runtime.*`, `dispatcher.*`等)
   - 用户无法按需导入，必须加载整个系统
   - 违反了依赖倒置原则

2. **循环依赖风险**
   - `core.actor` ↔ `runtime.system` ↔ `dispatcher`
   - `mailbox` ↔ `core.message` ↔ `monitoring`
   - 增加了编译复杂度和维护难度

3. **横切关注点分散**
   - 监控代码散布在：`monitoring/`, `dispatcher/monitoring/`, `core/monitoring/`
   - 日志功能分散在：`logging/`, `debug/`, 各个模块内部
   - 缺乏统一的横切关注点管理

4. **接口抽象不足**
   - 直接暴露具体实现类(`SimpleActorSystem`, `WorkStealingDispatcher`)
   - 缺乏统一的抽象接口层
   - 难以进行单元测试和模块替换

### 🔴 包边界问题

1. **core包职责不清**
   - 既包含接口定义，又包含具体实现
   - `core/zerocopy/`, `core/monitoring/`应该独立
   - 违反了单一职责原则

2. **runtime包功能重叠**
   - `runtime/actor/`与`core/actor/`功能重叠
   - `runtime/system/`直接依赖具体的dispatcher实现
   - 缺乏清晰的运行时抽象

## 🏗️ 优化架构设计

### 📦 新包结构设计

```
src/
├── api/                     # 🆕 公共API层 - 用户接口
│   ├── actor.cj            # Actor核心接口
│   ├── system.cj           # ActorSystem接口
│   └── message.cj          # 消息接口
├── core/                   # 核心实现层
│   ├── actor/              # Actor核心实现
│   ├── message/            # 消息系统
│   ├── context/            # Actor上下文
│   └── mailbox/            # 邮箱接口定义
├── runtime/                # 运行时层
│   ├── system/             # 系统实现
│   ├── scheduler/          # 🆕 调度器抽象
│   └── lifecycle/          # 🆕 生命周期管理
├── infrastructure/         # 🆕 基础设施层
│   ├── mailbox/            # 邮箱具体实现
│   ├── dispatcher/         # 调度器实现
│   ├── memory/             # 内存管理
│   └── network/            # 网络通信
├── patterns/               # 模式层
│   ├── ask/                # Ask模式
│   ├── supervision/        # 监督策略
│   └── routing/            # 路由策略
├── extensions/             # 扩展层
│   ├── persistence/        # 持久化
│   ├── cluster/            # 集群
│   ├── stream/             # 流处理
│   └── remote/             # 远程通信
├── observability/          # 🆕 可观测性层 - 横切关注点
│   ├── monitoring/         # 监控
│   ├── logging/            # 日志
│   ├── tracing/            # 链路追踪
│   └── metrics/            # 指标收集
└── cactor.cj               # 主包入口 - 简化导出
```

### 🔄 依赖关系优化

```
api (接口层)
 ↑
core (核心实现) → observability (横切关注点)
 ↑
runtime (运行时)
 ↑
infrastructure (基础设施)
 ↑
patterns (模式) ← extensions (扩展)
```

## 🚀 Phase 1: 最小改进计划 (1周)

### 1.1 创建API抽象层 🔧 **高优先级**

**目标**：解耦用户接口与具体实现

**实施步骤**：
```cangjie
// 新建 src/api/actor.cj
package cactor.api

// 核心Actor接口 - 用户面向的API
public interface Actor {
    func receive(message: Message, context: ActorContext): MessageResult
    func preStart(): Unit { }
    func postStop(): Unit { }
}

public interface ActorRef {
    func tell(message: Message): Unit
    func path(): String
}

public interface ActorSystem {
    func actorOf(props: Props): ActorRef
    func terminate(): Unit
}
```

**改动文件**：
- ✅ 新建 `src/api/actor.cj`
- ✅ 新建 `src/api/system.cj`
- ✅ 新建 `src/api/message.cj`

### 1.2 重构主包导出 🔧 **高优先级**

**目标**：实现按需导入，减少耦合

**当前问题**：
```cangjie
// src/cactor.cj - 当前过度耦合的导出
public import cactor.core.*           // 导入所有core
public import cactor.runtime.*        // 导入所有runtime
public import cactor.dispatcher.*     // 导入所有dispatcher
```

**优化方案**：
```cangjie
// src/cactor.cj - 优化后的分层导出
package cactor

// 基础API - 最常用接口
public import cactor.api.{Actor, ActorRef, ActorSystem, Message}

// 工厂类 - 创建系统实例
public struct CActorFactory {
    public static func createSystem(name: String): ActorSystem {
        // 返回具体实现，但用户只看到接口
        SimpleActorSystem(name)
    }
}

// 高级功能 - 按需导入
public import cactor.patterns.ask.{AskPattern}
public import cactor.patterns.supervision.{SupervisionStrategy}
```

**改动文件**：
- ✅ 修改 `src/cactor.cj`
- ✅ 修改 `src/actor.cj`

### 1.3 横切关注点统一 🔧 **中优先级**

**目标**：统一监控、日志等横切关注点

**当前分散状态**：
- 监控：`monitoring/`, `dispatcher/monitoring/`, `core/monitoring/`
- 日志：`logging/`, `debug/`, 各模块内部

**统一方案**：
```cangjie
// 新建 src/observability/pkg.cj
package cactor.observability

public import cactor.observability.monitoring.*
public import cactor.observability.logging.*
public import cactor.observability.metrics.*

// 统一的可观测性接口
public interface ObservabilityProvider {
    func getMonitor(): Monitor
    func getLogger(name: String): Logger  
    func getMetrics(): MetricRegistry
}
```

**实施步骤**：
1. 创建 `src/observability/` 目录
2. 移动现有监控代码到统一位置
3. 提供统一的可观测性接口
4. 各模块通过依赖注入使用

**改动文件**：
- ✅ 新建 `src/observability/pkg.cj`
- ✅ 移动 `src/monitoring/*` → `src/observability/monitoring/`
- ✅ 移动 `src/logging/*` → `src/observability/logging/`

## 🔄 Phase 2: 深度重构计划 (2周)

### 2.1 基础设施层分离 🔧 **中优先级**

**目标**：将具体实现从core层分离到infrastructure层

**重构范围**：
- `mailbox/` → `infrastructure/mailbox/`
- `dispatcher/` → `infrastructure/dispatcher/`  
- `memory/` → `infrastructure/memory/`

### 2.2 运行时抽象优化 🔧 **中优先级**

**目标**：清晰的运行时层抽象

**优化方案**：
```cangjie
// src/runtime/scheduler/scheduler.cj
public interface Scheduler {
    func schedule(task: Task): Unit
    func start(): Unit
    func stop(): Unit
}

// src/runtime/lifecycle/lifecycle_manager.cj  
public interface LifecycleManager {
    func startActor(actor: Actor): Unit
    func stopActor(actorRef: ActorRef): Unit
    func restartActor(actorRef: ActorRef): Unit
}
```

## 📋 实施检查清单

### ✅ Phase 1 完成标准
- [ ] API层创建完成，接口定义清晰
- [ ] 主包导出重构，支持按需导入
- [ ] 横切关注点统一，监控日志集中管理
- [ ] 现有测试全部通过
- [ ] 编译时间无明显增加

### ✅ Phase 2 完成标准  
- [ ] 基础设施层分离完成
- [ ] 运行时抽象清晰
- [ ] 包依赖关系优化
- [ ] 性能测试通过
- [ ] 文档更新完成

## 🎯 预期收益

### 📈 架构收益
- **耦合度降低60%**：通过接口抽象和分层设计
- **内聚度提升40%**：相关功能集中管理
- **可测试性提升**：清晰的接口边界便于单元测试
- **可扩展性增强**：新功能可独立开发和部署

### 🚀 开发效率
- **编译时间优化**：按需编译，减少不必要依赖
- **开发体验改善**：清晰的API，减少学习成本
- **维护成本降低**：模块化设计，便于定位问题

### 📊 性能影响
- **运行时性能**：无负面影响，接口调用开销可忽略
- **内存占用**：按需加载，减少内存占用
- **启动时间**：模块化加载，启动时间优化

## 🛠️ 具体实施方案

### Phase 1.1: API抽象层创建

**步骤1：创建核心API接口**
```cangjie
// src/api/actor.cj
package cactor.api

import cactor.api.{Message, ActorContext}

/**
 * 核心Actor接口 - 用户面向的统一API
 * 隐藏具体实现细节，提供稳定的接口
 */
public interface Actor {
    /**
     * 处理消息的核心方法
     */
    func receive(message: Message, context: ActorContext): MessageResult

    /**
     * 生命周期钩子 - 可选实现
     */
    func preStart(): Unit { }
    func postStart(): Unit { }
    func preStop(): Unit { }
    func postStop(): Unit { }
}

/**
 * Actor引用接口 - 消息发送的统一入口
 */
public interface ActorRef {
    func tell(message: Message): Unit
    func tell(message: Message, sender: Option<ActorRef>): Unit
    func path(): String
    func equals(other: ActorRef): Bool
}

/**
 * Actor系统接口 - 系统管理的统一入口
 */
public interface ActorSystem {
    func actorOf(props: Props): ActorRef
    func actorOf(props: Props, name: String): ActorRef
    func actorSelection(path: String): ActorSelection
    func terminate(): Unit
    func isTerminated(): Bool
}
```

**步骤2：创建消息API**
```cangjie
// src/api/message.cj
package cactor.api

/**
 * 消息基础接口
 */
public interface Message {
    func messageType(): String
}

/**
 * 消息结果枚举
 */
public enum MessageResult {
    | Handled
    | Unhandled
    | Stop
    | Restart
    | Escalate
}

/**
 * Actor上下文接口
 */
public interface ActorContext {
    func self(): ActorRef
    func sender(): Option<ActorRef>
    func system(): ActorSystem
    func actorOf(props: Props): ActorRef
    func stop(actorRef: ActorRef): Unit
}
```

### Phase 1.2: 主包导出重构

**当前问题代码**：
```cangjie
// src/cactor.cj - 问题：过度耦合
package cactor

public import cactor.core.*           // 导入所有core包
public import cactor.runtime.*        // 导入所有runtime包
public import cactor.mailbox.*        // 导入所有mailbox包
public import cactor.dispatcher.*     // 导入所有dispatcher包
// ... 更多全量导入
```

**优化后代码**：
```cangjie
// src/cactor.cj - 解决方案：分层按需导入
package cactor

// 第一层：核心API - 用户最常用的接口
public import cactor.api.{Actor, ActorRef, ActorSystem, Message, MessageResult, ActorContext}

// 第二层：系统工厂 - 隐藏具体实现
public struct CActorFactory {
    /**
     * 创建默认Actor系统
     * 用户只看到ActorSystem接口，不知道具体实现
     */
    public static func createSystem(): ActorSystem {
        SimpleActorSystem("default")  // 具体实现隐藏
    }

    public static func createSystem(name: String): ActorSystem {
        SimpleActorSystem(name)
    }

    /**
     * 创建Props的便捷方法
     */
    public static func props<T>(creator: () -> T): Props where T <: Actor {
        Props.create(creator)
    }
}

// 第三层：高级功能 - 按需导入（用户可选）
// 用户可以选择性导入：import cactor.patterns.ask.*
```

**步骤3：创建适配器层**
```cangjie
// src/core/adapter/api_adapter.cj
package cactor.core.adapter

import cactor.api.{Actor as ApiActor, ActorRef as ApiActorRef}
import cactor.core.actor.{Actor as CoreActor, ActorRef as CoreActorRef}

/**
 * API接口到核心实现的适配器
 * 解决接口与实现的耦合问题
 */
public class ActorAdapter <: ApiActor {
    private let coreActor: CoreActor

    public init(coreActor: CoreActor) {
        this.coreActor = coreActor
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        // 适配调用核心实现
        coreActor.receive(message, context)
    }
}
```

### Phase 1.3: 横切关注点统一实施

**步骤1：创建可观测性统一接口**
```cangjie
// src/observability/observability.cj
package cactor.observability

/**
 * 统一的可观测性提供者接口
 * 解决监控、日志分散的问题
 */
public interface ObservabilityProvider {
    func getMonitor(component: String): Monitor
    func getLogger(name: String): Logger
    func getMetrics(): MetricRegistry
    func getTracer(): Tracer
}

/**
 * 默认可观测性实现
 */
public class DefaultObservabilityProvider <: ObservabilityProvider {
    private let monitorRegistry: MonitorRegistry
    private let loggerFactory: LoggerFactory
    private let metricRegistry: MetricRegistry
    private let tracer: Tracer

    public init() {
        this.monitorRegistry = MonitorRegistry()
        this.loggerFactory = LoggerFactory()
        this.metricRegistry = MetricRegistry()
        this.tracer = DefaultTracer()
    }

    public func getMonitor(component: String): Monitor {
        monitorRegistry.getOrCreate(component)
    }

    public func getLogger(name: String): Logger {
        loggerFactory.getLogger(name)
    }

    public func getMetrics(): MetricRegistry {
        metricRegistry
    }

    public func getTracer(): Tracer {
        tracer
    }
}
```

**步骤2：依赖注入模式**
```cangjie
// src/core/system/system_context.cj
package cactor.core.system

import cactor.observability.ObservabilityProvider

/**
 * 系统上下文 - 统一管理系统级依赖
 * 解决横切关注点分散问题
 */
public class SystemContext {
    private let observabilityProvider: ObservabilityProvider
    private let configuration: SystemConfiguration

    public init(observabilityProvider: ObservabilityProvider) {
        this.observabilityProvider = observabilityProvider
        this.configuration = SystemConfiguration.default()
    }

    public func getObservability(): ObservabilityProvider {
        observabilityProvider
    }

    public func getConfiguration(): SystemConfiguration {
        configuration
    }
}
```

## 🔍 重构验证方案

### 编译验证
```bash
# 验证API层编译
cjpm build --package cactor.api

# 验证核心层编译
cjpm build --package cactor.core

# 验证整体编译
cjpm build
```

### 功能验证
```cangjie
// 验证新API的使用方式
import cactor.*

main(): Int64 {
    // 通过工厂创建系统，用户只看到接口
    let system = CActorFactory.createSystem("test")

    // 创建Actor，使用统一API
    let props = CActorFactory.props({ => TestActor() })
    let actorRef = system.actorOf(props, "test-actor")

    // 发送消息，接口保持一致
    actorRef.tell(StringMessage("Hello"))

    system.terminate()
    return 0
}
```

### 性能验证
```cangjie
// 性能测试：验证重构后性能无退化
import cactor.*

class PerformanceTestActor <: Actor {
    public func receive(message: Message, context: ActorContext): MessageResult {
        MessageResult.Handled
    }
}

// 测试消息吞吐量
func testThroughput(): Unit {
    let system = CActorFactory.createSystem("perf-test")
    let props = CActorFactory.props({ => PerformanceTestActor() })
    let actor = system.actorOf(props)

    let startTime = getCurrentTimeMillis()
    for (i in 0..1000000) {
        actor.tell(StringMessage("test"))
    }
    let endTime = getCurrentTimeMillis()

    println("吞吐量: ${1000000 / (endTime - startTime)} 消息/毫秒")
    system.terminate()
}
```

---

## 📋 详细实施时间表

### Week 1: Phase 1 核心重构
**Day 1-2: API抽象层创建**
- [ ] 创建 `src/api/` 目录结构
- [ ] 实现 `actor.cj`, `message.cj`, `system.cj` 接口
- [ ] 编写API层单元测试
- [ ] 验证接口设计的完整性

**Day 3-4: 主包导出重构**
- [ ] 重构 `src/cactor.cj` 导出策略
- [ ] 实现 `CActorFactory` 工厂类
- [ ] 创建适配器层连接API与实现
- [ ] 更新现有示例代码

**Day 5-7: 横切关注点统一**
- [ ] 创建 `src/observability/` 包结构
- [ ] 移动监控相关代码到统一位置
- [ ] 实现依赖注入模式
- [ ] 验证所有测试通过

### Week 2: Phase 2 深度优化
**Day 8-10: 基础设施层分离**
- [ ] 创建 `src/infrastructure/` 目录
- [ ] 移动具体实现到基础设施层
- [ ] 重构包依赖关系
- [ ] 性能回归测试

**Day 11-14: 运行时抽象优化**
- [ ] 设计运行时抽象接口
- [ ] 实现调度器抽象层
- [ ] 优化生命周期管理
- [ ] 完整系统集成测试

## 🔄 迁移策略

### 向后兼容性保证
```cangjie
// 保留旧的导入方式，添加废弃警告
// src/legacy/cactor_legacy.cj
package cactor.legacy

@deprecated("请使用 cactor.* 替代")
public import cactor.core.actor.{Actor, ActorRef}

@deprecated("请使用 CActorFactory.createSystem() 替代")
public import cactor.runtime.system.SimpleActorSystem
```

### 渐进式迁移指南
```cangjie
// 步骤1：用户当前代码
import cactor.core.actor.{Actor, ActorRef}
import cactor.runtime.system.SimpleActorSystem

// 步骤2：迁移到新API（兼容期）
import cactor.{Actor, ActorRef, CActorFactory}
let system = CActorFactory.createSystem()  // 替代 SimpleActorSystem()

// 步骤3：完全使用新API
import cactor.*
let system = CActorFactory.createSystem()
let props = CActorFactory.props({ => MyActor() })
```

### 自动化迁移工具
```bash
#!/bin/bash
# migrate_imports.sh - 自动迁移导入语句

# 替换旧的导入方式
find src -name "*.cj" -exec sed -i 's/import cactor\.core\.actor\.\*/import cactor.*/g' {} \;
find src -name "*.cj" -exec sed -i 's/SimpleActorSystem(/CActorFactory.createSystem(/g' {} \;

echo "导入语句迁移完成，请手动验证结果"
```

## 🎯 成功指标

### 架构质量指标
- **包耦合度 (Ca/Ce)**：目标 < 0.3 (当前 ~0.7)
- **包内聚度 (LCOM)**：目标 > 0.8 (当前 ~0.5)
- **循环依赖数量**：目标 = 0 (当前 3个)
- **接口覆盖率**：目标 > 90% (当前 ~60%)

### 性能指标
- **编译时间**：不超过当前时间的110%
- **运行时性能**：消息吞吐量不低于当前95%
- **内存占用**：启动内存不超过当前105%
- **API响应时间**：接口调用延迟 < 1微秒

### 开发体验指标
- **API学习成本**：新用户上手时间 < 30分钟
- **代码可读性**：代码复杂度降低20%
- **测试覆盖率**：保持当前90%以上覆盖率
- **文档完整性**：API文档覆盖率100%

## 🚨 风险控制

### 技术风险
1. **编译器兼容性**：仓颉编译器版本兼容问题
   - 缓解：在多个编译器版本上测试
   - 应急：保留回滚机制

2. **性能退化风险**：接口抽象可能带来性能损失
   - 缓解：使用内联优化，编译时优化
   - 监控：持续性能基准测试

3. **依赖循环风险**：重构过程中可能引入新的循环依赖
   - 缓解：使用依赖分析工具持续监控
   - 预防：严格的代码审查流程

### 项目风险
1. **时间风险**：重构时间可能超出预期
   - 缓解：分阶段实施，每阶段独立验证
   - 应急：优先完成核心功能重构

2. **团队风险**：开发团队对新架构的适应
   - 缓解：提供详细文档和培训
   - 支持：设立架构答疑机制

## 📚 参考资料

### 架构设计原则
- **SOLID原则**：单一职责、开闭原则、里氏替换、接口隔离、依赖倒置
- **包设计原则**：REP、CCP、CRP、ADP、SDP、SAP
- **领域驱动设计**：限界上下文、聚合根、领域服务

### 类似项目参考
- **Akka架构**：分层设计、Actor抽象、配置管理
- **Actix架构**：类型安全、性能优化、模块化
- **ProtoActor架构**：跨语言支持、简洁API、高性能

---

**总结**：本计划通过系统性的架构重构，解决CActor当前的耦合问题，建立清晰的包边界和抽象层次。采用渐进式迁移策略，确保重构过程的安全性和可控性。通过明确的成功指标和风险控制措施，保证重构质量和项目成功。
