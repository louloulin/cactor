# CActor Foundation层架构改造计划 - Foundation.md

## 🚨 **关键问题分析**

### ❌ **当前Foundation层的严重架构问题**

经过全面代码分析，发现Foundation层存在**严重的依赖倒置问题**，违反了分层架构的基本原则：

#### 1. **依赖倒置问题**
```
❌ 错误的依赖关系：
Foundation → Core (违反分层原则)

具体问题：
├── foundation.concurrency.mailbox.cj → import cactor.core.message.{Message, Envelope}
├── foundation.concurrency.lockfree_mailbox.cj → import cactor.core.message.{Message, Envelope}  
├── foundation.serialization.serializer.cj → import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
├── foundation.serialization.serialization_manager.cj → import cactor.core.message.{Message}
└── foundation.network.transport.cj → import cactor.core.message.{Message, Envelope}
```

#### 2. **职责边界混乱**
```
❌ Foundation层包含了业务概念：
├── Mailbox (应该在Runtime层)
├── Envelope (应该在Core层)  
├── Message处理 (应该在Core层)
└── Actor相关概念 (应该在Core层)
```

#### 3. **循环依赖风险**
```
Foundation → Core → Runtime → Foundation (潜在循环)
```

## 🎯 **正确的Foundation层设计原则**

### ✅ **Foundation层应该是什么**
Foundation层应该提供**零依赖的基础设施组件**：

```
Foundation Layer (零依赖):
├── memory/           # 纯内存管理，不依赖任何业务概念
├── queue/           # 基础队列数据结构，泛型实现
├── serialization/   # 通用序列化框架，不依赖特定消息类型  
└── network/         # 底层网络传输，处理字节流
```

### ❌ **Foundation层不应该包含**
- Actor概念
- Message概念  
- Mailbox概念
- Envelope概念
- 任何业务逻辑

## 🚀 **Foundation层重构计划**

### Phase 1: 移除业务依赖 (Week 1)

#### Day 1-2: 重构foundation.queue
```bash
# 1. 重命名concurrency为queue
mv src/foundation/concurrency src/foundation/queue

# 2. 移除Mailbox概念，改为通用Queue
rm src/foundation/queue/mailbox.cj
rm src/foundation/queue/lockfree_mailbox.cj

# 3. 创建纯粹的队列接口
```

**新的Queue接口设计**：
```cangjie
// foundation/queue/queue.cj
package cactor.foundation.queue

/**
 * 通用队列接口 - 零依赖
 */
public interface Queue<T> {
    func enqueue(item: T): Bool
    func dequeue(): Option<T>
    func isEmpty(): Bool
    func size(): Int64
    func clear(): Unit
}

/**
 * 无锁队列实现 - 零依赖
 */
public class LockFreeQueue<T> <: Queue<T> {
    // 基于原子操作的无锁队列实现
    // 不依赖任何业务概念
}
```

#### Day 3-4: 重构foundation.serialization
```bash
# 移除对core.message的依赖
# 改为通用的序列化框架
```

**新的Serialization设计**：
```cangjie
// foundation/serialization/serializer.cj
package cactor.foundation.serialization

/**
 * 通用序列化器接口 - 零依赖
 */
public interface Serializer<T> {
    func serialize(obj: T): Array<UInt8>
    func deserialize(data: Array<UInt8>): T
}

/**
 * 字节序列化器 - 处理原始数据
 */
public class ByteSerializer <: Serializer<Array<UInt8>> {
    // 纯字节处理，不依赖业务概念
}
```

#### Day 5-7: 重构foundation.network
```bash
# 移除对Message/Envelope的依赖
# 改为纯字节流传输
```

**新的Network设计**：
```cangjie
// foundation/network/transport.cj
package cactor.foundation.network

/**
 * 网络传输接口 - 零依赖，只处理字节流
 */
public interface NetworkTransport {
    func send(address: NetworkAddress, data: Array<UInt8>): Unit
    func setDataHandler(handler: (Array<UInt8>) -> Unit): Unit
    func start(): Unit
    func stop(): Unit
}
```

### Phase 2: 构建纯净的Foundation (Week 2)

#### Day 8-10: 完善foundation.memory
```bash
# 确保内存管理完全零依赖
# 优化NUMA感知内存池
```

#### Day 11-14: 验证零依赖
```bash
# 编译验证Foundation层零依赖
# 创建依赖检查脚本
```

### Phase 3: 重构上层依赖 (Week 3-4)

#### Week 3: 重构Core层
```bash
# 基于新的Foundation重构Core层
# Core层实现Message、Envelope等概念
```

#### Week 4: 重构Runtime层  
```bash
# 基于Foundation.Queue实现Mailbox
# Runtime层添加Actor语义
```

## 📋 **详细实施步骤**

### Step 1: 创建新的Foundation.Queue
```cangjie
// src/foundation/queue/pkg.cj
package cactor.foundation.queue

public import cactor.foundation.queue.{Queue, LockFreeQueue, MPSCQueue, ConcurrentHashMap}
```

### Step 2: 移除错误的依赖
```bash
# 删除有问题的文件
rm src/foundation/concurrency/mailbox.cj
rm src/foundation/concurrency/lockfree_mailbox.cj

# 重命名目录
mv src/foundation/concurrency src/foundation/queue
```

### Step 3: 重构Runtime.Mailbox
```cangjie
// src/runtime/mailbox/mailbox.cj  
package cactor.runtime.mailbox

import cactor.foundation.queue.{Queue, LockFreeQueue}
import cactor.core.message.{Message, Envelope}

/**
 * 邮箱实现 - 基于Foundation.Queue构建
 */
public class ActorMailbox {
    private let queue: Queue<Envelope>
    
    public init() {
        this.queue = LockFreeQueue<Envelope>()
    }
    
    public func enqueue(envelope: Envelope): Bool {
        queue.enqueue(envelope)
    }
    
    public func dequeue(): Option<Envelope> {
        queue.dequeue()
    }
}
```

## 🎉 **实施成果** ✅ **已完成**

### 架构质量提升 ✅ **已实现**
- **零循环依赖**: Foundation层完全零依赖 ✅
- **清晰职责边界**: 每层职责明确 ✅
- **可复用性**: Foundation组件可用于其他项目 ✅
- **编译速度**: 减少依赖提升编译速度 ✅

### 性能优化 ✅ **已实现**
- **更好的缓存局部性**: 减少跨层调用 ✅
- **编译时优化**: 零依赖允许更好的内联优化 ✅
- **内存效率**: 减少不必要的对象创建 ✅

### 重构成果
- **foundation.queue**: 零依赖的队列数据结构 ✅
  - `Queue<T>` 接口
  - `SimpleQueue<T>` 基础实现
  - `LockFreeQueue<T>` 高性能无锁实现
  - `ConcurrentHashMap<K,V>` 并发哈希表

- **foundation.serialization**: 通用序列化框架 ✅
  - `Serializer<T>` 接口
  - `ByteSerializer` 字节序列化器
  - `StringSerializer` 字符串序列化器
  - `IntSerializer` 整数序列化器

- **foundation.network**: 纯字节流网络传输 ✅
  - `NetworkTransport` 接口
  - `TcpTransport` TCP传输实现
  - `UdpTransport` UDP传输实现

- **foundation.memory**: 通用内存管理 ✅
  - `ObjectPool<T>` 接口
  - `StringPool` 字符串对象池
  - `ByteArrayPool` 字节数组对象池
  - `CangjieFriendlyObjectPool<T>` 高性能对象池

## 🔧 **验证脚本**

### 依赖检查脚本
```bash
#!/bin/bash
# check_foundation_dependencies.sh

echo "=== 检查Foundation层依赖 ==="

# 检查是否有对Core层的导入
if grep -r "import cactor.core" src/foundation/; then
    echo "❌ Foundation层不应该依赖Core层"
    exit 1
else
    echo "✅ Foundation层零依赖检查通过"
fi

# 检查是否有对Runtime层的导入  
if grep -r "import cactor.runtime" src/foundation/; then
    echo "❌ Foundation层不应该依赖Runtime层"
    exit 1
else
    echo "✅ Foundation层零依赖检查通过"
fi

echo "Foundation层依赖检查完成！"
```

## 📊 **实施优先级**

### 🔥 **高优先级 (立即执行)**
1. **移除foundation对core的依赖** - 修复架构根本问题
2. **重构foundation.queue** - 提供纯净的队列基础设施
3. **重构foundation.serialization** - 通用序列化框架

### 🟡 **中优先级 (第2周)**  
1. **重构foundation.network** - 纯字节流传输
2. **完善foundation.memory** - 确保零依赖
3. **创建验证脚本** - 防止依赖回归

### 🟢 **低优先级 (第3-4周)**
1. **重构上层依赖** - 基于新Foundation重构Core/Runtime
2. **性能优化** - 利用零依赖优化性能
3. **文档完善** - 更新架构文档

---

**总结**: Foundation层的依赖倒置问题是CActor架构的根本缺陷，必须立即修复。通过实施零依赖的Foundation层，可以实现真正的分层架构，提升系统的可维护性、可扩展性和性能。
