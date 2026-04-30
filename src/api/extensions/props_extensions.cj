/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - Props扩展
 * 基于api.md设计，扩展现有Props类，提供类型化配置方法
 */
package cactor.api.extensions

import cactor.core.actor.{Actor, Props, PropsFactory, MailboxSelector, DispatcherSelector}
import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}
import std.time.*

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
        let selector = match (mailboxConfig.getMailboxType()) {
            case "bounded" => MailboxSelector.Bounded(Int64(mailboxConfig.getCapacity()), Duration.second * 5)
            case _ => MailboxSelector.DefaultMailbox
        }
        PropsFactory.create<T>(creator).withMailbox(selector)
    }

    /**
     * 创建Props并配置调度器
     */
    public static func createWithDispatcher<T>(creator: () -> T, dispatcherConfig: DispatcherConfig): Props<T> where T <: Actor {
        let selector = match (dispatcherConfig.getDispatcherType()) {
            case "pinned" => DispatcherSelector.PinnedDispatcher
            case "calling-thread" => DispatcherSelector.CallingThreadDispatcher
            case _ => DispatcherSelector.DefaultDispatcher
        }
        PropsFactory.create<T>(creator).withDispatcher(selector)
    }

    /**
     * 创建Props并配置监督策略
     * 注意：Props.withSupervisorStrategy 在当前版本中不存在
     */
    public static func createWithSupervision<T>(creator: () -> T, supervisionConfig: SupervisionConfig): Props<T> where T <: Actor {
        // Props当前不支持直接配置监督策略，返回不带监督策略的Props
        // 监督策略应该在Guardian或Supervisor中配置
        PropsFactory.create<T>(creator)
    }

    /**
     * 创建完全配置的Props
     */
    public static func createConfigured<T>(creator: () -> T,
                                          mailboxConfig: MailboxConfig,
                                          dispatcherConfig: DispatcherConfig,
                                          supervisionConfig: SupervisionConfig): Props<T> where T <: Actor {
        let mailboxSelector = match (mailboxConfig.getMailboxType()) {
            case "bounded" => MailboxSelector.Bounded(Int64(mailboxConfig.getCapacity()), Duration.second * 5)
            case _ => MailboxSelector.DefaultMailbox
        }
        let dispatcherSelector = match (dispatcherConfig.getDispatcherType()) {
            case "pinned" => DispatcherSelector.PinnedDispatcher
            case "calling-thread" => DispatcherSelector.CallingThreadDispatcher
            case _ => DispatcherSelector.DefaultDispatcher
        }
        PropsFactory.create<T>(creator)
            .withMailbox(mailboxSelector)
            .withDispatcher(dispatcherSelector)
    }
}
