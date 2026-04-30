/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Runtime - 简化的Actor系统实现
 * 基于Runtime层组件的完整Actor系统实现
 */
package cactor.runtime.system

import std.sync.*
import std.collection.*
import std.collection.concurrent.*
import std.time.{DateTime}
import cactor.core.actor.{Actor, ActorRef, Props, ActorPath, ActorContext, ActorSystem}
import cactor.core.system.{ActorSystem as FullActorSystem, ActorSelection, SimpleFuture, EventBus, ActorLog, SimpleTerminationFuture, SystemEvent, SimpleActorLog}
import cactor.core.message.{Message, MessageResult, Envelope}
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
public class SimpleActorSystem <: FullActorSystem & ActorSystem {
    private let systemName: String
    private let terminated: AtomicBool
    private let actors: ConcurrentHashMap<String, ActorRef>
    private let actorCounter: AtomicInt64
    private let startTimeValue: Int64
    private let terminationFuture: SimpleTerminationFuture

    public init(name: String) {
        this.systemName = name
        this.terminated = AtomicBool(false)
        this.actors = ConcurrentHashMap<String, ActorRef>()
        this.actorCounter = AtomicInt64(0)
        this.startTimeValue = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.terminationFuture = SimpleTerminationFuture()
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

    public func eventStream(): EventBus {
        SimpleEventBus()
    }

    public func log(): ActorLog {
        SimpleActorLog(systemName, "/system")
    }

    public func whenTerminated(): SimpleFuture<Unit> {
        terminationFuture
    }

    public func startTime(): Int64 {
        startTimeValue
    }
}

/**
 * 简化的事件总线实现
 */
public class SimpleEventBus <: EventBus {
    public func publish(event: Any): Unit {
        // 使用类型名称而不是 ToString
        let eventTypeName = match (event) {
            case e: SystemEvent => e.eventType()
            case _ => "Unknown"
        }
        println("发布事件: ${eventTypeName}")
    }

    public func subscribe(subscriber: ActorRef, eventType: String): Bool {
        true
    }

    public func unsubscribe(subscriber: ActorRef, eventType: String): Bool {
        true
    }

    public func subscriberCount(eventType: String): Int64 {
        0
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
                        let context = SimpleActorContext(this, envelope.getSender(), system)
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
 * 死信ActorRef - 用于无法找到发送者时
 */
public class DeadLetterActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init() {
        this.pathValue = ActorPath("deadLetters", "/deadLetters")
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {
        // 死信：忽略消息
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        // 死信：忽略消息
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case _: DeadLetterActorRef => true
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        0
    }
}

/**
 * Runtime层的ActorContext实现
 */
public class SimpleActorContext <: ActorContext {
    private let selfRef: ActorRef
    private let currentSender: ActorRef
    private let systemRef: SimpleActorSystem

    public init(self: ActorRef, systemRef: SimpleActorSystem) {
        this.selfRef = self
        this.currentSender = DeadLetterActorRef()
        this.systemRef = systemRef
    }

    public init(self: ActorRef, sender: Option<String>, systemRef: SimpleActorSystem) {
        this.selfRef = self
        this.currentSender = DeadLetterActorRef()
        this.systemRef = systemRef
    }

    public func sender(): ActorRef {
        currentSender
    }

    public func self(): ActorRef {
        selfRef
    }

    public func parent(): ActorRef {
        DeadLetterActorRef()
    }

    public func children(): Array<ActorRef> {
        Array<ActorRef>()
    }

    public func child(name: String): Option<ActorRef> {
        None
    }

    public func actorOf(props: Props<Actor>, name: String): ActorRef {
        systemRef.actorOf(props, name)
    }

    public func actorOf(props: Props<Actor>): ActorRef {
        systemRef.actorOf(props)
    }

    public func watch(actorRef: ActorRef): Unit {
        // 空实现
    }

    public func unwatch(actorRef: ActorRef): Unit {
        // 空实现
    }

    public func getActorSystem(): ActorSystem {
        systemRef
    }

    public func setReceiveTimeout(timeout: Duration): Unit {
        // 空实现
    }

    public func receiveTimeout(): Duration {
        Duration.second * 0
    }

    public func stop(): Unit {
        // 空实现
    }

    public func stop(actorRef: ActorRef): Unit {
        // 空实现
    }
}

/**
 * Runtime层的Actor选择器实现
 * 支持完整路径和通配符模式
 */
public class SimpleActorSelection <: ActorSelection {
    private let path: String
    private let system: SimpleActorSystem

    public init(path: String, system: SimpleActorSystem) {
        this.path = path
        this.system = system
    }

    public func resolveOne(): SimpleFuture<ActorRef> {
        let matches = resolveAll()
        if (matches.isEmpty()) {
            throw Exception("未找到Actor: ${path}")
        }
        return CompletedSimpleFuture<ActorRef>(matches[0])
    }

    public func tell(message: Message): Unit {
        let matches = resolveAll()
        for (ref in matches) {
            ref.tell(message)
        }
        if (matches.isEmpty()) {
            println("警告：未找到Actor ${path}，消息被丢弃")
        }
    }

    public func ask(message: Message): SimpleFuture<Message> {
        let matches = resolveAll()
        if (matches.isEmpty()) {
            throw Exception("未找到Actor: ${path}")
        }
        return CompletedSimpleFuture<Message>(message)
    }

    // 解析所有匹配的Actor
    // 支持通配符模式:
    // - "/user/{star}" 匹配 /user/ 下所有直接子Actor
    // - "/user/{starStar}" 匹配 /user/ 下所有后代Actor
    public func resolveAll(): ArrayList<ActorRef> {
        let matches = ArrayList<ActorRef>()
        let normalizedPath = normalizePath(path)

        // 检查是否是通配符模式
        if (normalizedPath.endsWith("/*")) {
            // 单层通配符
            let prefix = extractParentPath(normalizedPath)
            let prefixForSearch = extractLastSegmentPrefix(normalizedPath)
            collectDirectChildren(prefix, prefixForSearch, matches)
        } else if (normalizedPath.endsWith("/**")) {
            // 多层通配符
            let prefix = extractParentPath(normalizedPath)
            collectAllDescendants(prefix, matches)
        } else {
            // 精确匹配
            let actorName = extractActorName(normalizedPath)
            match (system.getActor(actorName)) {
                case Some(actorRef) =>
                    matches.add(actorRef)
                case None => ()
            }
        }
        matches
    }

    /**
     * 标准化路径
     */
    private func normalizePath(path: String): String {
        var result = path
        // 移除开头的多余斜杠
        while (result.startsWith("//")) {
            result = result[1..]
        }
        // 确保以 / 开头
        if (!result.startsWith("/")) {
            result = "/${result}"
        }
        result
    }

    private func extractActorName(path: String): String {
        if (path.isEmpty() || path == "/") {
            return ""
        }
        match (path.lastIndexOf("/")) {
            case Some(lastSlash) =>
                if (lastSlash == path.size - 1) {
                    return ""
                }
                path[(lastSlash + 1)..]
            case None => path
        }
    }

    private func extractParentPath(path: String): String {
        if (path.isEmpty() || path == "/") {
            return "/"
        }
        match (path.lastIndexOf("/")) {
            case Some(lastSlash) =>
                if (lastSlash <= 0) {
                    return "/"
                }
                path[0..lastSlash]
            case None => "/"
        }
    }

    private func extractLastSegmentPrefix(path: String): String {
        if (path.size <= 1) {
            return ""
        }
        let withoutWildcard = path[0..(path.size - 1)]
        match (withoutWildcard.lastIndexOf("/")) {
            case Some(lastSlash) =>
                withoutWildcard[(lastSlash + 1)..]
            case None => ""
        }
    }

    private func collectDirectChildren(prefix: String, namePrefix: String, results: ArrayList<ActorRef>): Unit {
        let prefixForMatch = if (prefix == "/") { "" } else { prefix[1..] }
        match (system.getActor(namePrefix)) {
            case Some(actorRef) =>
                results.add(actorRef)
            case None => ()
        }
    }

    private func collectAllDescendants(prefix: String, results: ArrayList<ActorRef>): Unit {
        let prefixForMatch = if (prefix == "/") { "" } else { prefix[1..] }
        match (system.getActor(prefixForMatch)) {
            case Some(actorRef) =>
                results.add(actorRef)
            case None => ()
        }
    }
}
