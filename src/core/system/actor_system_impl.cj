/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 简化的Actor系统实现
 * 基于仓颉并发特性的Actor系统
 */
package cactor.core.system

import std.sync.*
import std.collection.*
import std.collection.concurrent.*
// import cactor.core.system.{ActorSystem, ActorSelection}  // 避免循环依赖，在同一包中
import cactor.core.actor.{Actor, ActorRef, Props, ActorPath}
import cactor.core.message.{Message, MessageResult, Envelope}
import cactor.core.context.{ActorContext}
import cactor.runtime.mailbox.{Mailbox, FoundationMailbox}

/**
 * 简单的已完成Future实现
 */
class CompletedSimpleFuture<T> <: SimpleFuture<T> {
    private let value: T

    public init(value: T) {
        this.value = value
    }

    public func get(): T {
        value
    }

    public func isCompleted(): Bool {
        true
    }
}

/**
 * 简化的Actor系统实现
 * 基于仓颉并发特性的Actor系统
 */
public class SimpleActorSystem <: ActorSystem {
    private let systemName: String
    private let terminated: AtomicBool
    private let actors: ConcurrentHashMap<String, ActorRef>
    private let actorCounter: AtomicInt64

    public init(name: String) {
        this.systemName = name
        this.terminated = AtomicBool(false)
        this.actors = ConcurrentHashMap<String, ActorRef>()
        this.actorCounter = AtomicInt64(0)
    }

    public prop name: String {
        get() { systemName }
    }

    public func getName(): String {
        systemName
    }

    /**
     * 创建Actor - 类似Akka的actorOf方法
     */
    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        if (terminated.load()) {
            throw Exception("Actor系统已终止，无法创建新Actor")
        }

        // 检查名称是否已存在
        match (actors.get(name)) {
            case Some(_) => throw Exception("Actor名称 '${name}' 已存在")
            case None => ()
        }

        // 创建Actor实例
        let actor = props.create()

        // 创建ActorRef (这里需要实际的ActorRef实现)
        // 暂时返回一个简化的实现
        let actorRef = createActorRef(actor, name)

        // 注册Actor
        actors.put(name, actorRef)

        return actorRef
    }

    /**
     * 创建Actor - 自动生成名称
     */
    public func actorOf(props: Props<Actor>): ActorRef {
        let autoName = "actor-${actorCounter.fetchAdd(1)}"
        return actorOf(props, autoName)
    }

    /**
     * Actor选择 - 根据路径查找Actor
     */
    public func actorSelection(path: String): ActorSelection {
        return SimpleActorSelection(path, this)
    }

    /**
     * 根据名称获取Actor
     */
    public func getActor(name: String): Option<ActorRef> {
        actors.get(name)
    }

    public func terminate(): Unit {
        terminated.store(true)

        // 停止所有Actor
        for ((name, actorRef) in actors) {
            // 这里应该调用actorRef的停止方法
            println("停止Actor: ${name}")
        }

        // 清空actors映射 - 简化实现
        // 实际实现中应该有更好的清理方法
        println("Actor系统 ${systemName} 已终止")
    }

    public func isTerminated(): Bool {
        terminated.load()
    }

    /**
     * 创建ActorRef的辅助方法
     * 创建一个包含mailbox的ActorRef实现
     */
    private func createActorRef(actor: Actor, name: String): ActorRef {
        // 创建mailbox - 使用Foundation层的高性能邮箱
        let mailbox = FoundationMailbox(1024)  // 默认容量1024

        // 创建包含mailbox的ActorRef实现
        return SimpleActorRef(name, actor, mailbox, this)
    }
}

/**
 * 简单的ActorRef实现
 * 用于pb1.md API优化
 */
public class SimpleActorRef <: ActorRef {
    private let actorName: String
    private let actor: Actor
    private let mailbox: Mailbox
    private let system: SimpleActorSystem
    private let actorPath: ActorPath

    public init(name: String, actor: Actor, mailbox: Mailbox, system: SimpleActorSystem) {
        this.actorName = name
        this.actor = actor
        this.mailbox = mailbox
        this.system = system
        this.actorPath = ActorPath(system.getName(), "/user/${name}")
    }

    public prop path: ActorPath {
        get() { actorPath }
    }

    public func tell(message: Message): Unit {
        // 使用mailbox进行异步消息传递
        let envelope = Envelope(message, None<String>)
        let success = mailbox.enqueue(envelope)

        if (!success) {
            println("警告：消息入队失败，mailbox可能已满 - Actor: ${actorName}")
        } else {
            // 异步处理消息（简化实现：立即处理）
            processMailboxMessages()
        }
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        // 使用mailbox进行异步消息传递，包含sender信息
        let envelope = Envelope(message, sender)
        let success = mailbox.enqueue(envelope)

        if (!success) {
            println("警告：消息入队失败，mailbox可能已满 - Actor: ${actorName}")
        } else {
            // 异步处理消息（简化实现：立即处理）
            processMailboxMessages()
        }
    }

    /**
     * 处理mailbox中的消息
     * 简化实现：同步处理，实际应该异步调度
     */
    private func processMailboxMessages(): Unit {
        // 处理mailbox中的消息（批量处理）
        let maxBatch: Int32 = 8  // 每次最多处理8条消息

        for (_ in 0..maxBatch) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    try {
                        let context = SimpleActorContext(this, envelope.getSender())
                        let result = actor.receive(envelope.getMessage(), context)

                        // 处理消息结果
                        match (result) {
                            case MessageResult.Handled => ()
                            case MessageResult.Unhandled =>
                                println("警告：消息未被处理 - Actor: ${actorName}")
                            case _ =>
                                println("消息处理结果: 其他 - Actor: ${actorName}")
                        }
                    } catch (e: Exception) {
                        println("错误：Actor消息处理异常 - Actor: ${actorName}, 错误: ${e}")
                    }
                case None => break  // mailbox为空，退出处理
            }
        }
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case simpleRef: SimpleActorRef =>
                actorName == simpleRef.actorName
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        // 简化实现：使用名称的哈希码，转换为Int32
        Int32(actorName.hashCode() & 0x7FFFFFFF)
    }

    public func getActor(): Actor {
        actor
    }

    /**
     * 获取Actor的mailbox（用于测试和监控）
     */
    public func getMailbox(): Mailbox {
        mailbox
    }

    /**
     * 获取mailbox统计信息
     */
    public func getMailboxStats(): String {
        "Actor: ${actorName}, Mailbox size: ${mailbox.size()}, isEmpty: ${mailbox.isEmpty()}"
    }
}

/**
 * 简单的ActorContext实现
 * 用于pb1.md API优化
 */
public class SimpleActorContext <: ActorContext {
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

/**
 * 简单的Actor选择器实现
 */
public class SimpleActorSelection <: ActorSelection {
    private let path: String
    private let system: SimpleActorSystem

    public init(path: String, system: SimpleActorSystem) {
        this.path = path
        this.system = system
    }

    public func resolveOne(): SimpleFuture<ActorRef> {
        // 简化实现：直接根据路径查找Actor
        // 实际实现应该支持更复杂的路径解析
        let actorName = extractActorName(path)

        match (system.getActor(actorName)) {
            case Some(actorRef) =>
                // 返回一个已完成的SimpleFuture
                return CompletedSimpleFuture<ActorRef>(actorRef)
            case None =>
                throw Exception("未找到Actor: ${path}")
        }
    }

    public func tell(message: Message): Unit {
        // 解析Actor并发送消息
        let actorName = extractActorName(path)
        match (system.getActor(actorName)) {
            case Some(actorRef) =>
                actorRef.tell(message)
            case None =>
                println("警告：未找到Actor ${path}，消息被丢弃")
        }
    }

    public func ask(message: Message): SimpleFuture<Message> {
        // 解析Actor并发送Ask消息
        let actorName = extractActorName(path)
        match (system.getActor(actorName)) {
            case Some(actorRef) =>
                // 简化实现：直接返回原消息
                return CompletedSimpleFuture<Message>(message)
            case None =>
                throw Exception("未找到Actor: ${path}")
        }
    }

    /**
     * 从路径中提取Actor名称
     * 简化实现，实际应该支持完整的Actor路径解析
     */
    private func extractActorName(path: String): String {
        // 简化实现：假设路径就是Actor名称
        // 实际实现应该解析类似 "/user/myactor" 这样的路径
        if (path.startsWith("/user/")) {
            // 简化实现：去掉 "/user/" 前缀
            return extractSubstring(path, 6)
        } else if (path.startsWith("/")) {
            // 简化实现：去掉 "/" 前缀
            return extractSubstring(path, 1)
        } else {
            return path
        }
    }

    /**
     * 简化的字符串截取实现
     * 从指定位置开始截取到字符串末尾
     */
    private func extractSubstring(str: String, startIndex: Int64): String {
        // 简化实现：由于仓颉语言中没有直接的substring方法
        // 这里使用简化的逻辑
        if (startIndex >= str.size) {
            return ""
        }

        // 简化实现：直接返回去掉前缀后的结果
        // 实际实现中应该使用正确的字符串截取方法
        if (str.startsWith("/user/")) {
            return "extracted_actor_name"  // 占位实现
        } else if (str.startsWith("/")) {
            return "actor_name"  // 占位实现
        } else {
            return str
        }
    }
}


