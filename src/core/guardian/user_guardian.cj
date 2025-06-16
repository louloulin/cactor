/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Core - User Guardian实现
 * 用户级Guardian，管理用户创建的Actor
 */
package cactor.core.guardian

import std.sync.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, Props, ActorPath}
import cactor.core.message.{Message, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.core.supervision.{SupervisionStrategy, DefaultSupervisionStrategy, SupervisionDirective, ActorFailure}
import cactor.core.system.{ActorSystem}

/**
 * 用户Guardian实现
 * 管理用户创建的Actor
 */
public class UserGuardian <: BaseGuardianActor {
    private let actorSystem: ActorSystem
    private let userActors: HashMap<String, ActorRef>
    private let defaultSupervisionStrategy: SupervisionStrategy
    private let actorPathPrefix: String
    
    public init(system: ActorSystem) {
        super(GuardianType.User, None<ActorRef>)  // 用户Guardian通常没有父Guardian
        this.actorSystem = system
        this.userActors = HashMap<String, ActorRef>()
        this.defaultSupervisionStrategy = DefaultSupervisionStrategy.oneForOne()
        this.actorPathPrefix = "/user"
    }
    
    /**
     * 创建用户Actor
     */
    public func createUserActor(props: Props<Actor>, name: String): ActorRef {
        // 验证用户Actor名称
        if (!isValidUserActorName(name)) {
            throw Exception("非法的用户Actor名称: ${name}")
        }
        
        let userActor = doCreateChild(props, name)
        userActors.put(name, userActor)
        
        // 应用用户级监督策略
        let supervisionStrategy = defaultSupervisionStrategy  // 简化实现，使用默认策略
        supervise(userActor, supervisionStrategy)
        
        return userActor
    }
    
    /**
     * 获取用户Actor
     */
    public func getUserActor(name: String): Option<ActorRef> {
        userActors.get(name)
    }
    
    /**
     * 获取所有用户Actor
     */
    public func getAllUserActors(): Array<ActorRef> {
        let actorList = ArrayList<ActorRef>()
        for ((_, actorRef) in userActors) {
            actorList.append(actorRef)
        }
        return actorList.toArray()
    }
    
    /**
     * 处理Actor失败
     */
    public func handleActorFailure(failure: ActorFailure): Unit {
        let childPath = failure.actor.path.toString()
        
        match (supervisionStrategies.get(childPath)) {
            case Some(strategy) =>
                let directive = strategy.decide(failure)
                executeSupervisionDirective(failure.actor, directive, failure.cause)
            case None =>
                // 使用默认策略
                let directive = defaultSupervisionStrategy.decide(failure)
                executeSupervisionDirective(failure.actor, directive, failure.cause)
        }
    }
    
    /**
     * 执行监督指令
     */
    private func executeSupervisionDirective(actor: ActorRef, directive: SupervisionDirective, cause: Exception): Unit {
        match (directive) {
            case SupervisionDirective.Resume =>
                println("恢复Actor: ${actor.path.toString()}")
                // 恢复Actor执行
                
            case SupervisionDirective.Restart =>
                println("重启Actor: ${actor.path.toString()}")
                restartChild(actor, cause)
                
            case SupervisionDirective.Stop =>
                println("停止Actor: ${actor.path.toString()}")
                stopChild(actor)
                
            case SupervisionDirective.Escalate =>
                println("升级失败到系统Guardian: ${actor.path.toString()}")
                // 将失败升级到系统Guardian
                escalateFailure(actor, cause)
        }
    }
    
    /**
     * 升级失败到系统Guardian
     */
    private func escalateFailure(actor: ActorRef, cause: Exception): Unit {
        // 创建升级失败消息并发送给系统Guardian
        // 这里需要与ActorSystem集成
        println("升级失败: Actor=${actor.path.toString()}, 原因=${cause}")
    }
    
    /**
     * 验证用户Actor名称
     */
    private func isValidUserActorName(name: String): Bool {
        // 用户Actor名称不能以system-开头
        !name.startsWith("system-") && 
        !name.isEmpty() && 
        name.size <= 100 &&
        isValidActorNameCharacters(name)
    }
    
    /**
     * 验证Actor名称字符
     */
    private func isValidActorNameCharacters(name: String): Bool {
        // 简化实现：只检查长度和基本字符
        return name.size > 0 && name.size <= 100
    }
    
    // 实现抽象方法
    protected func doCreateChild(props: Props<Actor>, name: String): ActorRef {
        let actor = props.create()
        let actorPath = ActorPath("user-system", "${actorPathPrefix}/${name}")
        
        // 创建用户ActorRef
        return createUserActorRef(actor, name, actorPath)
    }
    
    protected func doStopChild(child: ActorRef): Unit {
        println("停止用户Actor: ${child.path.toString()}")
        
        // 从用户Actor列表中移除
        for ((name, actorRef) in userActors) {
            if (actorRef.equals(child)) {
                userActors.remove(name)
                break
            }
        }
        
        // 执行Actor停止逻辑
        child.tell(StopMessage())
    }
    
    protected func doRestartChild(child: ActorRef, reason: Exception): Unit {
        println("重启用户Actor: ${child.path.toString()}, 原因: ${reason}")
        
        // 用户Actor重启逻辑
        // 1. 保存Actor状态
        // 2. 停止当前Actor
        // 3. 重新创建Actor
        // 4. 恢复Actor状态
        
        // 发送重启消息
        child.tell(RestartMessage(reason))
    }
    
    /**
     * 创建用户ActorRef
     */
    private func createUserActorRef(actor: Actor, name: String, path: ActorPath): ActorRef {
        // 这里应该与Runtime层集成，使用真正的邮箱和调度器
        return SimpleUserActorRef(name, actor, path)
    }
    
    // 重写Actor属性
    public prop name: String {
        get() { "user" }
    }
    
    public prop description: String {
        get() { "User Guardian - manages user-created actors" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case userMsg: CreateUserActorMessage =>
                try {
                    createUserActor(userMsg.getProps(), userMsg.getName())
                    MessageResult.Handled
                } catch (e: Exception) {
                    println("创建用户Actor失败: ${e}")
                    MessageResult.Unhandled
                }
            case failureMsg: ActorFailureMessage =>
                try {
                    handleActorFailure(failureMsg.getFailure())
                    MessageResult.Handled
                } catch (e: Exception) {
                    println("处理Actor失败异常: ${e}")
                    MessageResult.Unhandled
                }
            case _ => 
                // 委托给基类处理
                super.receive(message, context)
        }
    }
}

/**
 * 创建用户Actor的消息
 */
public class CreateUserActorMessage <: Message {
    private let props: Props<Actor>
    private let actorName: String
    
    public init(props: Props<Actor>, name: String) {
        this.props = props
        this.actorName = name
    }
    
    public func getProps(): Props<Actor> { props }
    public func getName(): String { actorName }
    
    public func getType(): String { "CreateUserActor" }
    public func getPayload(): String { "CreateUserActor(${actorName})" }
    public func messageType(): String { "CreateUserActor" }
}

/**
 * Actor失败消息
 */
public class ActorFailureMessage <: Message {
    private let failure: ActorFailure
    
    public init(failure: ActorFailure) {
        this.failure = failure
    }
    
    public func getFailure(): ActorFailure { failure }
    
    public func getType(): String { "ActorFailure" }
    public func getPayload(): String { "ActorFailure(${failure.actor.path.toString()})" }
    public func messageType(): String { "ActorFailure" }
}

/**
 * 停止消息
 */
public class StopMessage <: Message {
    public func getType(): String { "Stop" }
    public func getPayload(): String { "Stop" }
    public func messageType(): String { "Stop" }
}

/**
 * 重启消息
 */
public class RestartMessage <: Message {
    private let reason: Exception
    
    public init(reason: Exception) {
        this.reason = reason
    }
    
    public func getReason(): Exception { reason }
    
    public func getType(): String { "Restart" }
    public func getPayload(): String { "Restart(${reason})" }
    public func messageType(): String { "Restart" }
}

/**
 * 简化的用户ActorRef实现
 */
public class SimpleUserActorRef <: ActorRef {
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
        let context = SimpleUserActorContext(this)
        actor.receive(message, context)
    }
    
    public func tell(message: Message, sender: Option<String>): Unit {
        let context = SimpleUserActorContext(this, sender)
        actor.receive(message, context)
    }
    
    public func equals(other: ActorRef): Bool {
        match (other) {
            case userRef: SimpleUserActorRef =>
                actorName == userRef.actorName && actorPath.toString() == userRef.actorPath.toString()
            case _ => false
        }
    }
    
    public func hashCode(): Int32 {
        Int32(actorName.hashCode() & 0x7FFFFFFF)
    }
}

/**
 * 简化的用户ActorContext实现
 */
public class SimpleUserActorContext <: ActorContext {
    private let selfRef: ActorRef
    private let currentSender: Option<String>
    
    public init(self: ActorRef) {
        this.selfRef = self
        this.currentSender = None<String>
    }
    
    public init(self: ActorRef, sender: Option<String>) {
        this.selfRef = self
        this.currentSender = sender
    }
    
    public func sender(): Option<String> {
        currentSender
    }
}
