/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 7.0 - 主包导出
 * 基于6层架构的高性能Actor系统
 *
 * 架构层次：
 * 1. Foundation Layer - 基础设施层
 * 2. Core Layer - 核心层
 * 3. Runtime Layer - 运行时层
 * 4. Patterns Layer - 模式层
 * 5. Distribution Layer - 分布式层
 * 6. Integration Layer - 集成层
 * 7. API Layer - API层
 */
package cactor

// === 统一API层 (不导出core层) ===
// 按照plan10.md要求，只使用API层接口，不直接导出core层
public import cactor.api.{CActor, CActorSystem, CActorSystemFactory, ActorProps}
public import cactor.api.public.{CActorFactory, CActorSystemBuilder}
public import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}

// === 高级功能 (按需导入) ===
// 用户需要时显式导入：
// import cactor.patterns.*      // Ask模式、路由、断路器等
// import cactor.distribution.*  // 远程、集群、持久化等
// import cactor.integration.*   // 监控、日志、配置等