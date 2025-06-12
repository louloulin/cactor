/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 主包导出
 * 高性能仓颉Actor系统，基于plan2.md设计
 */
package cactor

// 导出核心接口
public import cactor.core.*

// 导出运行时实现
public import cactor.runtime.system.*
public import cactor.runtime.actor.*

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
