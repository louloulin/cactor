/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - System Guardian实现
 * 系统级Guardian，管理系统Actor和用户Guardian
 * 从Core层移动到Runtime层
 */
package cactor.runtime.guardian

import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props, ActorPath, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult}
import cactor.core.actor.{ActorContext}
import cactor.core.system.{ActorSystem as FullActorSystem}
import cactor.core.supervision.{SupervisionStrategy, DefaultSupervisionStrategy}
import cactor.core.guardian.{GuardianType}

/**
 * Runtime层的系统Guardian实现
 * 管理系统级Actor和用户Guardian
 */
public class RuntimeSystemGuardian <: BaseGuardianActor {
    private let actorSystem: FullActorSystem
    private var userGuardian: Option<ActorRef>
    private let systemActors: HashMap<String, ActorRef>
    private let defaultSupervisionStrategy: SupervisionStrategy
    
    public init(system: FullActorSystem) {
        super(GuardianType.System, None<ActorRef>)
        this.actorSystem = system
        this.userGuardian = None<ActorRef>
        this.systemActors = HashMap<String, ActorRef>()
        this.defaultSupervisionStrategy = DefaultSupervisionStrategy.oneForOne()
    }
    
    /**
     * 创建用户Guardian
     */
    public func createUserGuardian(): ActorRef {
        match (userGuardian) {
            case Some(guardian) => guardian
            case None =>
                let userGuardianFactory = SimpleActorFactory<Actor>({ => createUserGuardianActor(actorSystem) })
                let userGuardianProps = Props<Actor>(userGuardianFactory)
                let guardian = doCreateChild(userGuardianProps, "user")
                userGuardian = Some(guardian)
                guardian
        }
    }
    
    /**
     * 创建系统Actor
     */
    public func createSystemActor(props: Props<Actor>, name: String): ActorRef {
        // 检查是否为系统Actor名称
        if (!isSystemActorName(name)) {
            throw Exception("非法的系统Actor名称: ${name}")
        }
        
        let systemActor = doCreateChild(props, name)
        systemActors.add(name, systemActor)
        
        // 应用系统级监督策略
        supervise(systemActor, createSystemSupervisionStrategy())
        
        return systemActor
    }
    
    /**
     * 获取用户Guardian
     */
    public func getUserGuardian(): Option<ActorRef> {
        userGuardian
    }
    
    /**
     * 获取系统Actor
     */
    public func getSystemActor(name: String): Option<ActorRef> {
        systemActors.get(name)
    }
    
    /**
     * 检查是否为系统Actor名称
     */
    private func isSystemActorName(name: String): Bool {
        name.startsWith("system-") || 
        name == "user" || 
        name == "deadLetters" || 
        name == "eventBus" ||
        name == "scheduler"
    }
    
    /**
     * 创建系统级监督策略
     */
    private func createSystemSupervisionStrategy(): SupervisionStrategy {
        // 系统Actor使用更严格的监督策略
        DefaultSupervisionStrategy.oneForOne()
    }
    
    // 实现抽象方法
    protected func doCreateChild(props: Props<Actor>, name: String): ActorRef {
        // 这里需要与ActorSystem集成来创建Actor
        // 暂时使用简化实现
        let actor = props.create()
        let actorPath = ActorPath("system", "/system/${name}")
        
        // 创建ActorRef（这里需要与Runtime层集成）
        return createActorRef(actor, name, actorPath)
    }
    
    protected func doStopChild(child: ActorRef): Unit {
        // 执行Actor停止逻辑
        println("停止系统Actor: ${child.path.toString()}")
        
        // 从系统Actor列表中移除
        for ((name, actorRef) in systemActors) {
            if (actorRef.equals(child)) {
                systemActors.remove(name)
                break
            }
        }
    }
    
    protected func doRestartChild(child: ActorRef, reason: Exception): Unit {
        println("重启系统Actor: ${child.path.toString()}, 原因: ${reason}")
        
        // 系统Actor重启逻辑
        // 1. 停止当前Actor
        // 2. 重新创建Actor
        // 3. 更新引用
    }
    
    /**
     * 创建ActorRef的临时实现
     * 实际应该与Runtime层集成
     */
    private func createActorRef(actor: Actor, name: String, path: ActorPath): ActorRef {
        // 这是一个简化的实现，实际需要与Runtime层的邮箱和调度器集成
        return SimpleSystemActorRef(name, actor, path)
    }
    
    // 重写Actor属性
    public prop name: String {
        get() { "system" }
    }
    
    public prop description: String {
        get() { "Runtime System Guardian - manages system actors and user guardian" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case systemMsg: CreateSystemActorMessage =>
                try {
                    createSystemActor(systemMsg.getProps(), systemMsg.getName())
                    MessageResult.Handled
                } catch (e: Exception) {
                    println("创建系统Actor失败: ${e}")
                    MessageResult.Unhandled
                }
            case _ => 
                // 委托给基类处理
                super.receive(message, context)
        }
    }
}

/**
 * 创建系统Actor的消息
 */
public class CreateSystemActorMessage <: Message {
    private let props: Props<Actor>
    private let actorName: String
    
    public init(props: Props<Actor>, name: String) {
        this.props = props
        this.actorName = name
    }
    
    public func getProps(): Props<Actor> { props }
    public func getName(): String { actorName }
    
    public func getType(): String { "CreateSystemActor" }
    public func getPayload(): String { "CreateSystemActor(${actorName})" }
    public func messageType(): String { "CreateSystemActor" }
}

/**
 * 简化的系统ActorRef实现
 * 实际应该使用Runtime层的实现
 */
public class SimpleSystemActorRef <: ActorRef {
    private let actorName: String
    private let actor: Actor
    private let actorPath: ActorPath
    
    public init(name: String, actor: Actor, path: ActorPath) {
        this.actorName = name
        this.actor = actor
        this.actorPath = path
    }
    
    public prop path: ActorPath {
        get() { actorPath }
    }
    
    public func tell(message: Message): Unit {
        // 简化实现：直接调用Actor的receive方法
        let context = SimpleSystemActorContext(this)
        actor.receive(message, context)
    }
    
    public func tell(message: Message, sender: Option<String>): Unit {
        let context = SimpleSystemActorContext(this)
        actor.receive(message, context)
    }
    
    public func equals(other: ActorRef): Bool {
        match (other) {
            case systemRef: SimpleSystemActorRef =>
                actorName == systemRef.actorName && actorPath.toString() == systemRef.actorPath.toString()
            case _ => false
        }
    }
    
    public func hashCode(): Int32 {
        Int32(actorName.hashCode() & 0x7FFFFFFF)
    }
}

/**
 * 简化的系统ActorContext实现
 */
public class SimpleSystemActorContext <: ActorContext {
    private let selfRef: ActorRef
    private let currentSender: ActorRef

    public init(self: ActorRef) {
        this.selfRef = self
        this.currentSender = self
    }

    public func sender(): ActorRef {
        currentSender
    }

    public func self(): ActorRef {
        selfRef
    }

    public func parent(): ActorRef {
        selfRef
    }

    public func children(): Array<ActorRef> {
        Array<ActorRef>()
    }

    public func child(name: String): Option<ActorRef> {
        None
    }

    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        selfRef
    }

    public func actorOf(props: Props<Actor>): ActorRef {
        selfRef
    }

    public func watch(actorRef: ActorRef): Unit {
        ()
    }

    public func unwatch(actorRef: ActorRef): Unit {
        ()
    }

    public func getActorSystem() {
        // Simplified - returns a dummy system
        // This should be fixed with proper system reference
        throw Exception("SimpleSystemActorContext.getActorSystem not implemented")
    }

    public func setReceiveTimeout(timeout: Duration): Unit {
        ()
    }

    public func receiveTimeout(): Duration {
        Duration.second * 0
    }

    public func stop(): Unit {
        ()
    }

    public func stop(actorRef: ActorRef): Unit {
        ()
    }
}

/**
 * 创建用户Guardian Actor的工厂函数
 * 避免循环依赖
 */
func createUserGuardianActor(system: FullActorSystem): Actor {
    // 暂时返回一个简化的Guardian实现
    // 实际应该返回RuntimeUserGuardian，但为了避免循环依赖，使用简化实现
    SimpleUserGuardianActor(system)
}

/**
 * 简化的用户Guardian实现
 * 避免循环依赖
 */
class SimpleUserGuardianActor <: Actor {
    private let actorSystem: FullActorSystem

    public init(system: FullActorSystem) {
        this.actorSystem = system
    }

    public prop name: String {
        get() { "user" }
    }

    public prop description: String {
        get() { "Simple User Guardian Actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        // 简化实现
        MessageResult.Handled
    }
}
