/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - ActorSystem扩展
 * 基于api.md设计，扩展现有ActorSystem接口，提供极简创建API
 */
package cactor.api.extensions

import cactor.core.actor.{Actor, ActorRef, Props, PropsFactory, MailboxSelector, DispatcherSelector, SupervisorStrategy, DefaultSupervisorStrategy}
import cactor.core.system.{ActorSystem}
import cactor.runtime.system.{SimpleActorSystem}
import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}
import std.time.*

/**
 * 创建默认配置的ActorSystem
 */
public func createDefaultActorSystem(): ActorSystem {
    SimpleActorSystem("default")
}

/**
 * 创建命名的ActorSystem
 */
public func createActorSystem(name: String): ActorSystem {
    SimpleActorSystem(name)
}

public struct ActorSystemExtensions {
    /**
     * 创建默认配置的ActorSystem
     */
    public static func createDefault(): ActorSystem {
        SimpleActorSystem("default")
    }

    /**
     * 创建命名的ActorSystem
     */
    public static func create(name: String): ActorSystem {
        SimpleActorSystem(name)
    }

    /**
     * 最简创建Actor - 直接传入工厂函数
     */
    public static func actorOf<T>(system: ActorSystem, creator: () -> T, name: String): ActorRef where T <: Actor {
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        })
        system.actorOf(props, name)
    }

    /**
     * 自动生成名称的简化创建
     */
    public static func actorOf<T>(system: ActorSystem, creator: () -> T): ActorRef where T <: Actor {
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        })
        system.actorOf(props)
    }

    /**
     * 带邮箱配置的创建
     */
    public static func actorOfWithMailbox<T>(system: ActorSystem, creator: () -> T, name: String, mailboxConfig: MailboxConfig): ActorRef where T <: Actor {
        let mailbox = match (mailboxConfig.getMailboxType()) {
            case "unbounded" => MailboxSelector.Unbounded
            case "bounded" => MailboxSelector.bounded(Int64(mailboxConfig.getCapacity()))
            case "priority" => MailboxSelector.Priority("default")
            case _ => MailboxSelector.defaultMailbox()
        }
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withMailbox(mailbox)
        system.actorOf(props, name)
    }

    /**
     * 带调度器配置的创建
     */
    public static func actorOfWithDispatcher<T>(system: ActorSystem, creator: () -> T, name: String, dispatcherConfig: DispatcherConfig): ActorRef where T <: Actor {
        let dispatcher = match (dispatcherConfig.getDispatcherType()) {
            case "default" => DispatcherSelector.DefaultDispatcher
            case "pinned" => DispatcherSelector.PinnedDispatcher
            case "calling-thread" => DispatcherSelector.CallingThreadDispatcher
            case _ => DispatcherSelector.DefaultDispatcher
        }
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withDispatcher(dispatcher)
        system.actorOf(props, name)
    }

    /**
     * 带监督策略配置的创建
     */
    public static func actorOfWithSupervision<T>(system: ActorSystem, creator: () -> T, name: String, supervisionConfig: SupervisionConfig): ActorRef where T <: Actor {
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withSupervisorStrategy(supervisionConfig.getStrategy())
        system.actorOf(props, name)
    }

    /**
     * 完全配置的创建
     */
    public static func actorOfConfigured<T>(system: ActorSystem,
                                           creator: () -> T,
                                           name: String,
                                           mailboxConfig: MailboxConfig,
                                           dispatcherConfig: DispatcherConfig,
                                           supervisionConfig: SupervisionConfig): ActorRef where T <: Actor {
        let mailbox = match (mailboxConfig.getMailboxType()) {
            case "unbounded" => MailboxSelector.Unbounded
            case "bounded" => MailboxSelector.bounded(Int64(mailboxConfig.getCapacity()))
            case "priority" => MailboxSelector.Priority("default")
            case _ => MailboxSelector.defaultMailbox()
        }
        let dispatcher = match (dispatcherConfig.getDispatcherType()) {
            case "default" => DispatcherSelector.DefaultDispatcher
            case "pinned" => DispatcherSelector.PinnedDispatcher
            case "calling-thread" => DispatcherSelector.CallingThreadDispatcher
            case _ => DispatcherSelector.DefaultDispatcher
        }
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withMailbox(mailbox)
            .withDispatcher(dispatcher)
            .withSupervisorStrategy(supervisionConfig.getStrategy())
        system.actorOf(props, name)
    }

    /**
     * 批量创建Actor
     */
    public static func createActors<T>(system: ActorSystem,
                                      creator: () -> T,
                                      namePrefix: String,
                                      count: Int32): Array<ActorRef> where T <: Actor {
        let actors = Array<ActorRef>(Int64(count), { i =>
            ActorSystemExtensions.actorOf<T>(system, creator, "${namePrefix}-${i}")
        })
        actors
    }
}
