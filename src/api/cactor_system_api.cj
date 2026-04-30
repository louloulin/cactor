/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - 参考Akka设计的统一Actor系统API
 * 按照plan10.md要求，提供统一的ActorSystem API，不直接导出core层
 * 设计理念：简洁、类型安全、隐藏实现细节
 */
package cactor.api

import cactor.core.actor.{Actor, ActorRef, Props, PropsFactory, MailboxSelector, DispatcherSelector}
import cactor.core.config.{MailboxConfig as CoreMailboxConfig, DispatcherConfig as CoreDispatcherConfig, SupervisionConfig as CoreSupervisionConfig, MailboxType, DispatcherType}
import cactor.runtime.{CActorRuntime, CActorRuntimeConfig}
import std.time.*

/**
 * CActorSystem - 参考Akka设计的统一Actor系统API
 * 提供类型安全、简洁的Actor创建接口
 */
public class CActorSystem {
    private let runtime: CActorRuntime

    public init(name: String) {
        let config = CActorRuntimeConfig.createDefault()
        this.runtime = CActorRuntime(name, config)
        runtime.start()
    }

    public init(name: String, config: CActorRuntimeConfig) {
        this.runtime = CActorRuntime(name, config)
        runtime.start()
    }

    /**
     * 创建Actor - 参考Akka的actorOf方法
     * 使用类型擦除来处理泛型问题
     */
    public func actorOf(creator: () -> Actor, name: String): ActorRef {
        let props = PropsFactory.create(creator)
        runtime.actorOf(props, name)
    }

    /**
     * 创建Actor（自动命名）- 参考Akka的actorOf方法
     */
    public func actorOf(creator: () -> Actor): ActorRef {
        let props = PropsFactory.create(creator)
        runtime.actorOf(props)
    }

    /**
     * 使用ActorProps创建Actor
     */
    public func actorOf(actorProps: ActorProps, name: String): ActorRef {
        let creator = actorProps.getCreator()
        actorOf(creator, name)
    }

    /**
     * 使用ActorProps创建Actor（自动命名）
     */
    public func actorOf(actorProps: ActorProps): ActorRef {
        let creator = actorProps.getCreator()
        actorOf(creator)
    }

    /**
     * 使用Props创建Actor - 支持完整配置传递（类似Akka）
     */
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        runtime.actorOf(props, name)
    }

    /**
     * 使用Props创建Actor（自动命名）- 支持完整配置传递
     */
    public func actorOf(props: Props<Actor>): ActorRef {
        runtime.actorOf(props)
    }

    /**
     * 使用邮箱配置创建Actor - 类似Akka的withMailbox
     */
    public func actorOfWithMailbox(creator: () -> Actor, name: String, mailboxConfig: CoreMailboxConfig): ActorRef {
        let selector = match (mailboxConfig.mailboxType) {
            case MailboxType.Unbounded => MailboxSelector.DefaultMailbox
            case MailboxType.Bounded => MailboxSelector.Bounded(mailboxConfig.capacity, mailboxConfig.pushTimeout)
            case MailboxType.Priority => MailboxSelector.Priority("default")
            case _ => MailboxSelector.DefaultMailbox
        }
        let props = PropsFactory.create(creator).withMailbox(selector)
        runtime.actorOf(props, name)
    }

    /**
     * 使用调度器配置创建Actor - 类似Akka的withDispatcher
     */
    public func actorOfWithDispatcher(creator: () -> Actor, name: String, dispatcherConfig: CoreDispatcherConfig): ActorRef {
        let selector = match (dispatcherConfig.dispatcherType) {
            case DispatcherType.PinnedDispatcher => DispatcherSelector.PinnedDispatcher
            case DispatcherType.CallingThread => DispatcherSelector.CallingThreadDispatcher
            case _ => DispatcherSelector.DefaultDispatcher
        }
        let props = PropsFactory.create(creator).withDispatcher(selector)
        runtime.actorOf(props, name)
    }

    /**
     * 使用完整配置创建Actor - 类似Akka的完整配置方式
     */
    public func actorOfConfigured(creator: () -> Actor,
                                 name: String,
                                 mailboxConfig: CoreMailboxConfig,
                                 dispatcherConfig: CoreDispatcherConfig,
                                 supervisionConfig: CoreSupervisionConfig): ActorRef {
        let mailboxSelector = match (mailboxConfig.mailboxType) {
            case MailboxType.Unbounded => MailboxSelector.DefaultMailbox
            case MailboxType.Bounded => MailboxSelector.Bounded(mailboxConfig.capacity, mailboxConfig.pushTimeout)
            case MailboxType.Priority => MailboxSelector.Priority("default")
            case _ => MailboxSelector.DefaultMailbox
        }
        let dispatcherSelector = match (dispatcherConfig.dispatcherType) {
            case DispatcherType.PinnedDispatcher => DispatcherSelector.PinnedDispatcher
            case DispatcherType.CallingThread => DispatcherSelector.CallingThreadDispatcher
            case _ => DispatcherSelector.DefaultDispatcher
        }
        let props = PropsFactory.create(creator)
            .withMailbox(mailboxSelector)
            .withDispatcher(dispatcherSelector)
        runtime.actorOf(props, name)
    }

    /**
     * 获取系统名称
     */
    public func getName(): String {
        runtime.getRuntimeStats().systemName
    }

    /**
     * 终止系统 - 参考Akka的terminate方法
     */
    public func terminate(): Unit {
        runtime.shutdown()
    }

    /**
     * 检查是否已终止
     */
    public func isTerminated(): Bool {
        !runtime.getRuntimeStats().isRunning
    }

    /**
     * 获取底层运行时（用于高级功能）
     */
    public func getRuntime(): CActorRuntime {
        runtime
    }
}



/**
 * CActorSystem工厂方法 - 参考Akka的ActorSystem.create()
 */
public struct CActorSystemFactory {
    /**
     * 创建默认的CActorRuntime系统
     */
    public static func create(): CActorSystem {
        create("default")
    }

    /**
     * 创建命名的CActorRuntime系统
     */
    public static func create(name: String): CActorSystem {
        CActorSystem(name)
    }

    /**
     * 创建配置的CActorRuntime系统
     */
    public static func create(name: String, config: CActorRuntimeConfig): CActorSystem {
        CActorSystem(name, config)
    }
}
