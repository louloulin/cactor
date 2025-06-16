/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - ActorSystem扩展
 * 基于api.md设计，扩展现有ActorSystem接口，提供极简创建API
 */
package cactor.api.extensions

import cactor.core.actor.{Actor, ActorRef, Props, PropsFactory}
import cactor.core.system.{ActorSystem, SimpleActorSystem}
import cactor.api.config.{MailboxConfig, DispatcherConfig, SupervisionConfig}

/**
 * ActorSystem扩展 - 添加极简创建方法
 * 基于现有ActorSystem增强，提供更简洁的API
 */
/**
 * ActorSystem扩展 - 添加便利方法
 * 注意：由于Cangjie的extend语法限制，我们将扩展方法移到静态工厂类中
 */

/**
 * ActorSystem便利工厂方法
 * 改为普通函数避免静态方法链接问题
 */

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
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withMailbox(mailboxConfig.getMailboxType())
        system.actorOf(props, name)
    }

    /**
     * 带调度器配置的创建
     */
    public static func actorOfWithDispatcher<T>(system: ActorSystem, creator: () -> T, name: String, dispatcherConfig: DispatcherConfig): ActorRef where T <: Actor {
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withDispatcher(dispatcherConfig.getDispatcherType())
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
        }).withSupervisionStrategy(supervisionConfig.getStrategyType())
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
        let props = PropsFactory.create<Actor>({ =>
            let actor = creator()
            match (actor as Actor) {
                case Some(a) => a
                case None => throw Exception("Actor类型转换失败")
            }
        }).withMailbox(mailboxConfig.getMailboxType())
            .withDispatcher(dispatcherConfig.getDispatcherType())
            .withSupervisionStrategy(supervisionConfig.getStrategyType())
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
