/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - 主包导出
 * 模块化Actor系统，参考Akka和Actix设计
 */
package cactor

// 导出核心接口
public import cactor.core.*

// 导出实现类
public import cactor.impl.*

// 导出工具类
public import cactor.util.*

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
    public static func create(name: String): ActorSystem {
        ActorSystemImpl(name)
    }

    /**
     * 创建默认的Actor系统
     * @return Actor系统实例
     */
    public static func create(): ActorSystem {
        create("default")
    }
}




