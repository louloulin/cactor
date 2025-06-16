/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API 2.0 - ActorSystem增强API
 * 为ActorSystem添加便利的spawn方法
 */
package cactor.api

import cactor.core.actor.{Actor, ActorRef}
import cactor.core.system.{ActorSystem}

/**
 * ActorSystem增强API
 * 提供更简洁的Actor创建方法
 */

/**
 * 最简Actor创建
 * @param system Actor系统
 * @param creator Actor创建函数
 * @param name Actor名称
 * @return Actor引用
 */
public func createActor<T>(system: ActorSystem, creator: () -> T, name: String): ActorRef where T <: Actor {
    system.actorOf(CActor.props(creator), name)
}

/**
 * 自动命名Actor创建
 * @param system Actor系统
 * @param creator Actor创建函数
 * @return Actor引用
 */
public func createActor<T>(system: ActorSystem, creator: () -> T): ActorRef where T <: Actor {
    system.actorOf(CActor.props(creator))
}

/**
 * 配置化Actor创建
 * @param system Actor系统
 * @param creator Actor创建函数
 * @param name Actor名称
 * @param config Actor配置
 * @return Actor引用
 */
public func createActorWithConfig<T>(system: ActorSystem, creator: () -> T, name: String, config: ActorConfig): ActorRef where T <: Actor {
    system.actorOf(CActor.props(creator, config), name)
}

/**
 * 高性能Actor创建
 * @param system Actor系统
 * @param creator Actor创建函数
 * @param name Actor名称
 * @return Actor引用
 */
public func createHighPerformanceActor<T>(system: ActorSystem, creator: () -> T, name: String): ActorRef where T <: Actor {
    createActorWithConfig(system, creator, name, ActorConfig.highPerformance())
}

/**
 * 低延迟Actor创建
 * @param system Actor系统
 * @param creator Actor创建函数
 * @param name Actor名称
 * @return Actor引用
 */
public func createLowLatencyActor<T>(system: ActorSystem, creator: () -> T, name: String): ActorRef where T <: Actor {
    createActorWithConfig(system, creator, name, ActorConfig.lowLatency())
}

/**
 * 批处理Actor创建
 * @param system Actor系统
 * @param creator Actor创建函数
 * @param name Actor名称
 * @return Actor引用
 */
public func createBatchingActor<T>(system: ActorSystem, creator: () -> T, name: String): ActorRef where T <: Actor {
    createActorWithConfig(system, creator, name, ActorConfig.batching())
}
