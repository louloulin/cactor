/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 主包导出
 * 高性能仓颉Actor系统，优化的API设计
 */
package cactor

// 导出最常用的核心接口，简化用户导入
public import cactor.core.actor.{Actor, ActorRef, Props}
public import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
public import cactor.core.system.{ActorSystem, ActorSelection}
public import cactor.core.context.{ActorContext}
public import cactor.runtime.system.{SimpleActorSystem, SimpleActorSelection}

// 导出高级功能（直接导入具体类，避免循环依赖）
public import cactor.pattern.ask.{AskMessage, AskResponse, AskFuture, AskPatternManager}
public import cactor.supervision.{SupervisionStrategy, SupervisionDirective, OneForOneStrategy, OneForAllStrategy}
public import cactor.monitoring.{PerformanceMonitor, MonitoringStats, MetricRegistry}

/**
 * CACtor系统工厂类
 * 提供创建Actor系统的便捷方法
 */
public struct CActorSystem {
    /**
     * 创建新的Actor系统
     * @param name 系统名称
     * @return Actor系统实例
     */
    public static func create(name: String): SimpleActorSystem {
        SimpleActorSystem(name)
    }

    /**
     * 创建默认的Actor系统
     * @return Actor系统实例
     */
    public static func create(): SimpleActorSystem {
        create("default")
    }
}
