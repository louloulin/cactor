/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API 2.0 - 参考Akka设计的统一对外API入口
 * 提供简洁、直观、高性能的Actor系统API
 * 按照plan10.md要求，不直接导出core层，使用CActorRuntime
 */
package cactor.api

import cactor.core.actor.{Actor, ActorRef, PropsFactory}
import cactor.runtime.{CActorRuntimeConfig}

/**
 * CActor - 参考Akka设计的统一API入口
 * 提供所有核心功能的简洁接口，隐藏实现细节
 */
public struct CActor {
    /**
     * 创建默认Actor系统 - 参考Akka的ActorSystem.create()
     */
    public static func system(): CActorSystem {
        system("default")
    }

    /**
     * 创建命名Actor系统 - 参考Akka的ActorSystem.create(name)
     */
    public static func system(name: String): CActorSystem {
        CActorSystemFactory.create(name)
    }

    /**
     * 创建配置的Actor系统
     */
    public static func system(name: String, config: CActorRuntimeConfig): CActorSystem {
        CActorSystemFactory.create(name, config)
    }

    /**
     * 创建Actor Props - 参考Akka的Props.create()
     */
    public static func props(creator: () -> Actor): ActorProps {
        ActorProps(creator)
    }
}

/**
 * ActorProps - 简化的Props包装器
 * 隐藏Props的复杂性，提供简洁的接口
 */
public struct ActorProps {
    private let creator: () -> Actor

    public init(creator: () -> Actor) {
        this.creator = creator
    }

    /**
     * 获取Actor创建函数
     */
    public func getCreator(): () -> Actor {
        creator
    }
}
