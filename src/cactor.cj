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

// === 核心API (用户最常用) ===
public import cactor.core.actor.{Actor, ActorRef, Props}
public import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
public import cactor.core.system.{ActorSystem}
public import cactor.core.context.{ActorContext}

// === 系统工厂 (隐藏具体实现) ===
public import cactor.api.public.{CActorFactory, CActorSystemBuilder}

// === 高级功能 (按需导入) ===
// 用户需要时显式导入：
// import cactor.patterns.*      // Ask模式、路由、断路器等
// import cactor.distribution.*  // 远程、集群、持久化等
// import cactor.integration.*   // 监控、日志、配置等