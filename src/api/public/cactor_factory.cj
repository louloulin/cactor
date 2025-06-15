/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - 统一工厂接口
 * 提供简洁的Actor系统创建接口，隐藏实现细节
 */
package cactor.api.public

import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.system.{ActorSystem}
import cactor.core.message.{Message}

/**
 * CActor系统工厂
 * 提供统一的Actor系统创建接口
 */
public struct CActorFactory {
    /**
     * 创建默认Actor系统
     */
    public static func createSystem(): ActorSystem {
        createSystem("default")
    }
    
    /**
     * 创建命名Actor系统
     */
    public static func createSystem(name: String): ActorSystem {
        // 这里需要引用具体的实现类
        // 暂时返回一个简单的实现
        throw Exception("Not implemented yet")
    }
    
    /**
     * 创建Actor Props
     */
    public static func createProps<T>(creator: () -> T): Props<T> where T <: Actor {
        Props.create(creator)
    }
}

/**
 * CActor系统构建器
 * 提供流式API构建Actor系统
 */
public class CActorSystemBuilder {
    private var systemName: String = "default"
    private var dispatcherType: String = "default"
    private var mailboxType: String = "unbounded"
    
    public init() {}
    
    public func withName(name: String): CActorSystemBuilder {
        this.systemName = name
        this
    }
    
    public func withDispatcher(dispatcher: String): CActorSystemBuilder {
        this.dispatcherType = dispatcher
        this
    }
    
    public func withMailbox(mailbox: String): CActorSystemBuilder {
        this.mailboxType = mailbox
        this
    }
    
    public func build(): ActorSystem {
        CActorFactory.createSystem(systemName)
    }
}
