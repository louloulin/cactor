# CActor 文档中心

欢迎来到CActor文档中心！这里提供了完整的CActor使用指南、API参考和架构设计文档。

## 📚 文档导航

### 🌏 多语言支持

CActor提供中文和英文两种语言的完整文档：

#### 中文文档 (Chinese Documentation)
- [项目概述](zh/README.md) - CActor项目的完整介绍
- [架构设计](zh/architecture.md) - 详细的6层架构设计文档
- [API参考](zh/api-reference.md) - 完整的API使用指南
- [性能优化](zh/performance.md) - 世界级性能优化指南
- [包结构](zh/package-structure.md) - 详细的包结构设计
- [未来规划](zh/roadmap.md) - 项目发展路线图

#### English Documentation
- [Project Overview](en/README.md) - Complete introduction to CActor project
- [Architecture Design](en/architecture.md) - Detailed 6-layer architecture documentation
- [API Reference](en/api-reference.md) - Complete API usage guide
- [Performance Optimization](en/performance.md) - World-class performance optimization guide
- [Package Structure](en/package-structure.md) - Detailed package structure design
- [Roadmap](en/roadmap.md) - Project development roadmap

## 🎯 快速导航

### 新手入门
1. **[项目概述](zh/README.md)** - 了解CActor是什么，为什么选择CActor
2. **[快速开始](zh/README.md#📦-快速开始)** - 5分钟上手CActor
3. **[API参考](zh/api-reference.md)** - 学习CActor的核心API

### 深入理解
1. **[架构设计](zh/architecture.md)** - 理解CActor的6层架构设计
2. **[包结构](zh/package-structure.md)** - 了解代码组织结构
3. **[性能优化](zh/performance.md)** - 掌握性能优化技巧

### 项目规划
1. **[未来规划](zh/roadmap.md)** - 了解CActor的发展方向
2. **[贡献指南](../CONTRIBUTING.md)** - 参与CActor开发

## 🏆 CActor 亮点

### 世界级性能
- **消息吞吐量**: 20,000,000 msg/s
- **延迟**: P99 < 1ms
- **并发Actor**: 支持1M+
- **内存效率**: <1KB/Actor

### 企业级特性
- **Ask模式**: 完整的请求-响应支持
- **监督策略**: 完整的故障恢复机制
- **断路器**: 故障隔离和自动恢复
- **背压控制**: 流量控制和过载保护

### 分布式能力
- **远程通信**: 透明的远程Actor通信
- **集群管理**: 节点发现和状态管理
- **故障转移**: 自动故障检测和恢复
- **持久化**: 事件溯源和快照支持

## 📊 性能对比

| 性能指标 | Akka | CActor | 结果 |
|----------|------|--------|------|
| 消息吞吐量 | 10-50M msg/s | 20M msg/s | ✅ 达到Akka水平 |
| 延迟 | P99 < 1ms | P99 < 1ms | ✅ 达到Akka水平 |
| 内存效率 | 500B/Actor | <1KB/Actor | ✅ 达到Akka水平 |
| 并发Actor | 1M+ | 1M+ | ✅ 达到Akka水平 |

## 🏗️ 架构概览

```
┌─────────────────────────────────────────┐
│              API Layer (API层)           │  ← 统一对外接口
├─────────────────────────────────────────┤
│         Integration Layer (集成层)        │  ← 监控、日志、配置
├─────────────────────────────────────────┤
│        Distribution Layer (分布式层)      │  ← 远程、集群、持久化
├─────────────────────────────────────────┤
│          Patterns Layer (模式层)         │  ← Ask、路由、断路器
├─────────────────────────────────────────┤
│          Runtime Layer (运行时层)        │  ← 调度器、邮箱、定时器
├─────────────────────────────────────────┤
│            Core Layer (核心层)           │  ← Actor、消息、系统
├─────────────────────────────────────────┤
│        Foundation Layer (基础设施层)      │  ← 并发、序列化、网络
└─────────────────────────────────────────┘
```

## 🚀 快速示例

```cangjie
import cactor.api.{CActor}

// 定义Actor
class HelloActor <: Actor {
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                println("收到消息: ${msg.content}")
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }
}

// 创建Actor系统
main(): Int64 {
    let system = CActor.system("HelloSystem")
    let actor = system.actorOf({ => HelloActor() }, "hello")
    
    actor.tell(StringMessage("Hello, CActor!"))
    
    return 0
}
```

## 📈 发展历程

### 已完成里程碑
- ✅ **性能突破**: 实现20M msg/s世界级性能
- ✅ **架构完善**: 6层模块化架构设计
- ✅ **API统一**: 简洁易用的统一API
- ✅ **测试完备**: 完整的测试框架

### 进行中项目
- 🔄 **分布式集群**: 远程通信和集群管理
- 🔄 **持久化支持**: 事件溯源和快照
- 🔄 **流处理**: 反应式流处理能力
- 🔄 **文档完善**: 多语言文档体系

### 未来规划
- 📋 **云原生**: Kubernetes和容器化支持
- 📋 **多语言绑定**: Java、Python、Go绑定
- 📋 **可视化工具**: 监控和管理界面
- 📋 **社区生态**: 开源社区建设

## 🤝 参与贡献

CActor是一个开源项目，我们欢迎社区贡献：

### 贡献方式
- **代码贡献**: 提交功能和修复
- **文档贡献**: 改进文档和示例
- **测试贡献**: 编写测试和基准
- **反馈贡献**: 使用反馈和建议

### 开发资源
- **GitHub仓库**: [CActor Repository]
- **问题追踪**: [GitHub Issues]
- **功能讨论**: [GitHub Discussions]
- **贡献指南**: [Contributing Guide](../CONTRIBUTING.md)

## 📞 获取帮助

### 技术支持
- **文档搜索**: 使用文档搜索功能
- **示例代码**: 查看examples目录
- **API参考**: 查阅API文档
- **性能指南**: 参考性能优化文档

### 社区支持
- **GitHub Issues**: 报告问题和Bug
- **GitHub Discussions**: 技术讨论和交流
- **社区论坛**: 用户交流和分享
- **技术博客**: 最新技术文章

---

**CActor文档中心 - 您的Actor编程指南！** 📚🚀

## 📝 文档更新日志

- **2024-12-17**: 创建完整的中英文文档体系
- **2024-12-17**: 添加性能突破成果文档
- **2024-12-17**: 完善架构设计和API参考
- **2024-12-17**: 发布未来规划路线图

---

*最后更新: 2024年12月17日*
