/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Actor系统实现
 * 高性能Actor系统的核心实现
 */
package cactor.runtime.system

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorSelection, Props, Future, SimpleFuture, Result}
import cactor.core.system.{ActorSystem, Scheduler}
import cactor.core.context.{ActorContext, Cancellable, SimpleCancellable}
import cactor.core.message.{Message, DeadLetter}
import cactor.core.mailbox.{UnboundedMailbox, Mailbox}
import cactor.runtime.actor.{LocalActorRefImpl, AtomicActorState}

/**
 * 高性能Actor系统实现
 * 基于仓颉并发特性的Actor系统
 */
public class ActorSystemImpl <: ActorSystem {
    private let systemName: String
    private let actors: HashMap<String, ActorRef>
    private let actorsMutex: ReentrantMutex
    private let terminated: AtomicBool
    private let scheduler: SchedulerImpl
    private let deadLetters: ActorRef
    private let actorCount: AtomicInt64

    public init(name: String) {
        this.systemName = name
        this.actors = HashMap<String, ActorRef>()
        this.actorsMutex = ReentrantMutex()
        this.terminated = AtomicBool(false)
        this.scheduler = SchedulerImpl()
        this.actorCount = AtomicInt64(0)
        
        // 创建死信处理器
        this.deadLetters = createDeadLetterActor()
    }

    public prop name: String {
        get() { systemName }
    }

    public func actorOf<T>(props: Props<T>, name: String): ActorRef where T <: Actor {
        if (terminated.load()) {
            throw Exception("ActorSystem is terminated")
        }

        actorsMutex.lock()
        try {
            if (actors.containsKey(name)) {
                throw Exception("Actor with name '${name}' already exists")
            }

            let actor = props.create()
            let path = ActorPath(systemName, "/${name}")
            let mailbox = createMailbox(props.getMailboxType())
            let context = createActorContext(path, None)
            
            let actorRef = LocalActorRefImpl(actor, path, mailbox, context)
            actors[name] = actorRef
            actorCount.fetchAdd(1)
            
            // 启动Actor
            actorRef.start()
            
            return actorRef
        } finally {
            actorsMutex.unlock()
        }
    }

    public func actorSelection(path: String): ActorSelection {
        ActorSelectionImpl(path, this)
    }

    public func stop(actor: ActorRef): Unit {
        match (actor) {
            case localRef: LocalActorRefImpl => {
                localRef.stop()
                // 从注册表中移除
                actorsMutex.lock()
                try {
                    let actorName = extractActorName(actor.path.getPath())
                    if (actors.remove(actorName).isSome()) {
                        actorCount.fetchSub(1)
                    }
                } finally {
                    actorsMutex.unlock()
                }
            }
            case _ => {
                // 远程Actor或其他类型
                actor.tell(StopMessage())
            }
        }
    }

    public func terminate(): Unit {
        if (terminated.compareAndSwap(false, true)) {
            // 停止所有Actor
            actorsMutex.lock()
            try {
                for ((name, actorRef) in actors) {
                    stop(actorRef)
                }
                actors.clear()
                actorCount.store(0)
            } finally {
                actorsMutex.unlock()
            }
            
            // 停止调度器
            scheduler.shutdown()
        }
    }

    public func whenTerminated(): Future<Unit> {
        // 简化实现，返回已完成的Future
        SimpleFuture<Unit>(Result.Success(()))
    }

    public func scheduler(): Scheduler {
        scheduler
    }

    public func deadLetters(): ActorRef {
        deadLetters
    }

    /**
     * 查找Actor
     */
    public func findActor(name: String): Option<ActorRef> {
        actorsMutex.lock()
        try {
            return actors.get(name)
        } finally {
            actorsMutex.unlock()
        }
    }

    /**
     * 获取Actor数量
     */
    public func getActorCount(): Int64 {
        actorCount.load()
    }

    /**
     * 创建邮箱
     */
    private func createMailbox(mailboxType: String): Mailbox {
        match (mailboxType) {
            case "bounded" => BoundedMailbox(1000)
            case "priority" => PriorityMailbox()
            case _ => UnboundedMailbox()
        }
    }

    /**
     * 创建Actor上下文
     */
    private func createActorContext(path: ActorPath, parent: Option<ActorRef>): ActorContext {
        ActorContextImpl(path, parent, this)
    }

    /**
     * 创建死信处理器
     */
    private func createDeadLetterActor(): ActorRef {
        let deadLetterActor = DeadLetterActor()
        let path = ActorPath(systemName, "/deadLetters")
        let mailbox = UnboundedMailbox()
        let context = createActorContext(path, None)
        
        LocalActorRefImpl(deadLetterActor, path, mailbox, context)
    }

    /**
     * 从路径中提取Actor名称
     */
    private func extractActorName(path: String): String {
        let lastSlash = path.lastIndexOf("/")
        if (lastSlash >= 0) {
            path.substring(lastSlash + 1)
        } else {
            path
        }
    }
}

/**
 * Actor选择器实现
 */
class ActorSelectionImpl <: ActorSelection {
    private let path: String
    private let system: ActorSystemImpl

    public init(path: String, system: ActorSystemImpl) {
        this.path = path
        this.system = system
    }

    public func resolveOne(timeout: Duration): Option<ActorRef> {
        // 简化实现，只支持根级Actor查找
        if (path.startsWith("/")) {
            let actorName = path.substring(1)
            return system.findActor(actorName)
        }
        return None
    }

    public func tell(message: Message): Unit {
        tell(message, None)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        match (resolveOne(Duration.second)) {
            case Some(actorRef) => actorRef.tell(message, sender)
            case None => {
                // 发送到死信
                let senderPath = sender.getOrElse("unknown")
                system.deadLetters().tell(DeadLetter(message, senderPath, path))
            }
        }
    }
}

/**
 * 调度器实现
 */
class SchedulerImpl <: Scheduler {
    private let shutdown: AtomicBool

    public init() {
        this.shutdown = AtomicBool(false)
    }

    public func schedule(initialDelay: Duration, interval: Duration, receiver: ActorRef, message: Message): Cancellable {
        let cancellable = SimpleCancellable()
        
        if (!shutdown.load()) {
            spawn {
                sleep(initialDelay)
                while (!shutdown.load() && !cancellable.isCancelled()) {
                    receiver.tell(message)
                    sleep(interval)
                }
            }
        }
        
        cancellable
    }

    public func scheduleOnce(delay: Duration, receiver: ActorRef, message: Message): Cancellable {
        let cancellable = SimpleCancellable()
        
        if (!shutdown.load()) {
            spawn {
                sleep(delay)
                if (!shutdown.load() && !cancellable.isCancelled()) {
                    receiver.tell(message)
                }
            }
        }
        
        cancellable
    }

    public func shutdown(): Unit {
        shutdown.store(true)
    }
}

/**
 * Actor上下文实现
 */
class ActorContextImpl <: ActorContext {
    private let actorPath: ActorPath
    private let parentRef: Option<ActorRef>
    private let actorSystem: ActorSystem
    private var currentSender: Option<String>

    public init(path: ActorPath, parent: Option<ActorRef>, system: ActorSystem) {
        this.actorPath = path
        this.parentRef = parent
        this.actorSystem = system
        this.currentSender = None
    }

    public func self(): ActorRef {
        // 简化实现，需要从系统中查找自己
        let actorName = extractActorName(actorPath.getPath())
        match (actorSystem.actorSelection("/${actorName}").resolveOne(Duration.second)) {
            case Some(ref) => ref
            case None => throw Exception("Cannot find self actor reference")
        }
    }

    public func sender(): Option<String> {
        currentSender
    }

    public func system(): ActorSystem {
        actorSystem
    }

    public func parent(): Option<ActorRef> {
        parentRef
    }

    public func actorOf<T>(props: Props<T>, name: String): ActorRef where T <: Actor {
        // 创建子Actor
        let childPath = actorPath.child(name)
        actorSystem.actorOf(props, childPath.getPath())
    }

    public func actorSelection(path: String): ActorSelection {
        actorSystem.actorSelection(path)
    }

    public func stop(actor: ActorRef): Unit {
        actorSystem.stop(actor)
    }

    public func watch(actor: ActorRef): Unit {
        // 简化实现
        // actor.tell(WatchMessage(actorPath.toString()))
    }

    public func unwatch(actor: ActorRef): Unit {
        // 简化实现
        // actor.tell(UnwatchMessage(actorPath.toString()))
    }

    public func scheduleOnce(delay: Duration, message: Message, target: ActorRef): Unit {
        actorSystem.scheduler().scheduleOnce(delay, target, message)
    }

    public func schedule(initialDelay: Duration, interval: Duration, message: Message, target: ActorRef): Unit {
        actorSystem.scheduler().schedule(initialDelay, interval, target, message)
    }

    /**
     * 设置当前发送者
     */
    public func setSender(sender: Option<String>): Unit {
        this.currentSender = sender
    }

    /**
     * 从路径中提取Actor名称
     */
    private func extractActorName(path: String): String {
        let lastSlash = path.lastIndexOf("/")
        if (lastSlash >= 0) {
            path.substring(lastSlash + 1)
        } else {
            path
        }
    }
}

/**
 * 死信Actor实现
 */
class DeadLetterActor <: Actor {
    public prop name: String {
        get() { "deadLetters" }
    }

    public prop description: String {
        get() { "Dead letter handler" }
    }

    // 简化的消息处理，实际需要实现receive方法
    public func handleDeadLetter(deadLetter: DeadLetter): Unit {
        println("DeadLetter: ${deadLetter.getMessage().messageType()} from ${deadLetter.getSender()} to ${deadLetter.getRecipient()}")
    }
}
