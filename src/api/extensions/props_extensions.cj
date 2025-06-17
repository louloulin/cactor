/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - Props扩展
 * 基于api.md设计，扩展现有Props类，提供类型化配置方法
 */
package cactor.api.extensions

import cactor.core.actor.{Actor, Props, PropsFactory}
import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}

/**
 * Props扩展 - 添加类型化配置方法
 * 基于现有Props增强，提供更简洁的API
 * 注意：Cangjie的extend语法不支持泛型约束，所以我们使用静态方法
 */

/**
 * Props便利工厂方法
 */
public struct PropsExtensions {
    /**
     * 创建Props并配置邮箱
     */
    public static func createWithMailbox<T>(creator: () -> T, mailboxConfig: MailboxConfig): Props<T> where T <: Actor {
        PropsFactory.create<T>(creator).withMailbox(mailboxConfig.getMailboxType())
    }

    /**
     * 创建Props并配置调度器
     */
    public static func createWithDispatcher<T>(creator: () -> T, dispatcherConfig: DispatcherConfig): Props<T> where T <: Actor {
        PropsFactory.create<T>(creator).withDispatcher(dispatcherConfig.getDispatcherType())
    }

    /**
     * 创建Props并配置监督策略
     */
    public static func createWithSupervision<T>(creator: () -> T, supervisionConfig: SupervisionConfig): Props<T> where T <: Actor {
        PropsFactory.create<T>(creator).withSupervisionStrategy(supervisionConfig.getStrategyType())
    }

    /**
     * 创建完全配置的Props
     */
    public static func createConfigured<T>(creator: () -> T,
                                          mailboxConfig: MailboxConfig,
                                          dispatcherConfig: DispatcherConfig,
                                          supervisionConfig: SupervisionConfig): Props<T> where T <: Actor {
        PropsFactory.create<T>(creator)
            .withMailbox(mailboxConfig.getMailboxType())
            .withDispatcher(dispatcherConfig.getDispatcherType())
            .withSupervisionStrategy(supervisionConfig.getStrategyType())
    }
}
