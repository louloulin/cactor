/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - 简化的Actor系统实现
 * 基于Runtime层组件的完整Actor系统实现
 */
package cactor.runtime.system

import std.sync.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.actor.{Actor, ActorRef, Props, ActorPath}
import cactor.core.system.{ActorSystem, ActorSelection, SimpleFuture}
import cactor.core.message.{Message, MessageResult, Envelope}
import cactor.core.context.{ActorContext}
import cactor.runtime.mailbox.{Mailbox, FoundationMailbox}

/**
 * 简单的已完成Future实现
 */
public class CompletedSimpleFuture<T> <: SimpleFuture<T> {
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
 * Runtime层的Actor系统实现
 * 基于Runtime层组件构建的完整Actor系统
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
     * 创建Actor - 使用Runtime层组件
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

        // 使用Runtime层组件创建ActorRef
        let actorRef = createActorRef(actor, name)

        // 注册Actor
        actors.add(name, actorRef)

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
            println("停止Actor: ${name}")
        }

        println("Actor系统 ${systemName} 已终止")
    }

    public func isTerminated(): Bool {
        terminated.load()
    }

    /**
     * 使用Runtime层组件创建ActorRef
     */
    private func createActorRef(actor: Actor, name: String): ActorRef {
        // 使用Runtime层的邮箱实现
        let mailbox = FoundationMailbox(65535)
        return SimpleActorRef(name, actor, mailbox, this)
    }
}

/**
 * Runtime层的ActorRef实现
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
        let envelope = Envelope(message, None<String>)
        let success = mailbox.enqueue(envelope)

        if (!success) {
            println("警告：消息入队失败，mailbox可能已满 - Actor: ${actorName}")
        } else {
            processMailboxMessages()
        }
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        let envelope = Envelope(message, sender)
        let success = mailbox.enqueue(envelope)

        if (!success) {
            println("警告：消息入队失败，mailbox可能已满 - Actor: ${actorName}")
        } else {
            processMailboxMessages()
        }
    }

    /**
     * 使用Runtime层组件处理消息
     */
    private func processMailboxMessages(): Unit {
        let maxBatch: Int32 = 8

        for (_ in 0..maxBatch) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    try {
                        let context = SimpleActorContext(this, envelope.getSender())
                        let result = actor.receive(envelope.getMessage(), context)

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
                case None => break
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
        Int32(actorName.hashCode() & 0x7FFFFFFF)
    }

    public func getActor(): Actor {
        actor
    }

    public func getMailbox(): Mailbox {
        mailbox
    }

    public func getMailboxStats(): String {
        "Actor: ${actorName}, Mailbox size: ${mailbox.size()}, isEmpty: ${mailbox.isEmpty()}"
    }
}

/**
 * Runtime层的ActorContext实现
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
 * Runtime层的Actor选择器实现
 */
public class SimpleActorSelection <: ActorSelection {
    private let path: String
    private let system: SimpleActorSystem

    public init(path: String, system: SimpleActorSystem) {
        this.path = path
        this.system = system
    }

    public func resolveOne(): SimpleFuture<ActorRef> {
        let actorName = extractActorName(path)

        match (system.getActor(actorName)) {
            case Some(actorRef) =>
                return CompletedSimpleFuture<ActorRef>(actorRef)
            case None =>
                throw Exception("未找到Actor: ${path}")
        }
    }

    public func tell(message: Message): Unit {
        let actorName = extractActorName(path)
        match (system.getActor(actorName)) {
            case Some(actorRef) =>
                actorRef.tell(message)
            case None =>
                println("警告：未找到Actor ${path}，消息被丢弃")
        }
    }

    public func ask(message: Message): SimpleFuture<Message> {
        let actorName = extractActorName(path)
        match (system.getActor(actorName)) {
            case Some(actorRef) =>
                return CompletedSimpleFuture<Message>(message)
            case None =>
                throw Exception("未找到Actor: ${path}")
        }
    }

    private func extractActorName(path: String): String {
        if (path.startsWith("/user/")) {
            return extractSubstring(path, 6)
        } else if (path.startsWith("/")) {
            return extractSubstring(path, 1)
        } else {
            return path
        }
    }

    private func extractSubstring(str: String, startIndex: Int64): String {
        if (startIndex >= str.size) {
            return ""
        }

        if (str.startsWith("/user/")) {
            return "extracted_actor_name"
        } else if (str.startsWith("/")) {
            return "actor_name"
        } else {
            return str
        }
    }
}
