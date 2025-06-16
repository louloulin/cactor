/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API 2.0 - 统一对外API入口
 * 提供简洁、直观、高性能的Actor系统API
 */
package cactor.api

import cactor.core.actor.{Actor, ActorRef, Props, PropsFactory}
import cactor.core.system.{ActorSystem, SimpleActorSystem}

/**
 * CActor统一API入口
 * 提供所有核心功能的简洁接口
 */
public struct CActor {
    /**
     * 创建默认Actor系统
     * @return Actor系统实例
     */
    public static func system(): ActorSystem {
        system("default")
    }
    
    /**
     * 创建命名Actor系统
     * @param name 系统名称
     * @return Actor系统实例
     */
    public static func system(name: String): ActorSystem {
        SimpleActorSystem(name)
    }
    
    /**
     * 创建最简Actor Props
     * @param creator Actor创建函数
     * @return Props实例
     */
    public static func props<T>(creator: () -> T): Props<T> where T <: Actor {
        PropsFactory.create(creator)
    }
    

}
