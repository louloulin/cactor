/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - Actor系统实现
 */
package cactor.impl.system

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorSelection}
import cactor.core.context.Props
import cactor.core.system.{ActorSystem, Scheduler, EventStream, ActorSystemSettings}
import cactor.core.mailbox.{UnboundedMailbox}
import cactor.impl.actor.LocalActorRefImpl

/**
 * Actor系统实现
 */
public class ActorSystemImpl <: ActorSystem {
    private let systemName: String
    private let actors: HashMap<String, ActorRef>
    private let actorsMutex: ReentrantMutex
    private let terminated: AtomicBool
    private let scheduler: SchedulerImpl
    private let eventStream: EventStreamImpl
    private let deadLetters: ActorRef
    private let settings: ActorSystemSettingsImpl

    public init(name: String) {
        this.systemName = name
        this.actors = HashMap<String, ActorRef>()
        this.actorsMutex = ReentrantMutex()
        this.terminated = AtomicBool(false)
        this.scheduler = SchedulerImpl()
        this.eventStream = EventStreamImpl()
        this.settings = ActorSystemSettingsImpl()
        
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
            let mailbox = UnboundedMailbox()
            let context = createActorContext(path, None)
            
            let actorRef = LocalActorRefImpl(actor, path, mailbox, context)
            actors[name] = actorRef
            
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
                    actors.remove(actorName)
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
            } finally {
                actorsMutex.unlock()
            }
            
            // 停止调度器
            scheduler.shutdown()
        }
    }

    public func whenTerminated(): Future<Unit> {
        // 简化实现
        SimpleFuture<Unit>(Result.Success(()))
    }

    public func scheduler(): Scheduler {
        scheduler
    }

    public func eventStream(): EventStream {
        eventStream
    }

    public func deadLetters(): ActorRef {
        deadLetters
    }

    public func settings(): ActorSystemSettings {
        settings
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
 * 简化的Actor选择器实现
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

    public func tell(message: Message, sender: Option<ActorRef>): Unit {
        match (resolveOne(Duration.second)) {
            case Some(actorRef) => actorRef.tell(message, sender)
            case None => {
                // 发送到死信
                system.deadLetters().tell(DeadLetter(message, 
                    sender.map(_.path.toString()).getOrElse("unknown"),
                    path))
            }
        }
    }
}

/**
 * 简化的调度器实现
 */
class SchedulerImpl <: Scheduler {
    private let shutdown: AtomicBool

    public init() {
        this.shutdown = AtomicBool(false)
    }

    public func schedule(initialDelay: Duration, interval: Duration, receiver: ActorRef, message: Message): Cancellable {
        SimpleCancellable()
    }

    public func scheduleOnce(delay: Duration, receiver: ActorRef, message: Message): Cancellable {
        if (!shutdown.load()) {
            spawn {
                sleep(delay)
                if (!shutdown.load()) {
                    receiver.tell(message)
                }
            }
        }
        SimpleCancellable()
    }

    public func scheduleWithFixedDelay(initialDelay: Duration, interval: Duration, runnable: () -> Unit): Cancellable {
        SimpleCancellable()
    }

    public func shutdown(): Unit {
        shutdown.store(true)
    }
}

/**
 * 简化的事件流实现
 */
class EventStreamImpl <: EventStream {
    private let subscribers: HashMap<String, ArrayList<ActorRef>>
    private let mutex: ReentrantMutex

    public init() {
        this.subscribers = HashMap<String, ArrayList<ActorRef>>()
        this.mutex = ReentrantMutex()
    }

    public func subscribe(subscriber: ActorRef, eventType: String): Unit {
        mutex.lock()
        try {
            match (subscribers.get(eventType)) {
                case Some(list) => list.append(subscriber)
                case None => {
                    let list = ArrayList<ActorRef>()
                    list.append(subscriber)
                    subscribers[eventType] = list
                }
            }
        } finally {
            mutex.unlock()
        }
    }

    public func unsubscribe(subscriber: ActorRef, eventType: String): Unit {
        mutex.lock()
        try {
            match (subscribers.get(eventType)) {
                case Some(list) => {
                    // 移除订阅者
                    for (i in 0..list.size) {
                        if (list[i].equals(subscriber)) {
                            list.remove(i)
                            break
                        }
                    }
                }
                case None => {}
            }
        } finally {
            mutex.unlock()
        }
    }

    public func publish(event: Message): Unit {
        let eventType = event.messageType()
        mutex.lock()
        try {
            match (subscribers.get(eventType)) {
                case Some(list) => {
                    for (subscriber in list) {
                        subscriber.tell(event)
                    }
                }
                case None => {}
            }
        } finally {
            mutex.unlock()
        }
    }
}

/**
 * 简化的系统设置实现
 */
class ActorSystemSettingsImpl <: ActorSystemSettings {
    private let config: HashMap<String, String>

    public init() {
        this.config = HashMap<String, String>()
        // 设置默认配置
        config["cactor.default-dispatcher"] = "default"
        config["cactor.default-mailbox"] = "unbounded"
    }

    public func getString(key: String): Option<String> {
        config.get(key)
    }

    public func getInt(key: String): Option<Int32> {
        match (config.get(key)) {
            case Some(value) => {
                try {
                    Some(value.toInt32())
                } catch (e: Exception) {
                    None
                }
            }
            case None => None
        }
    }

    public func getBool(key: String): Option<Bool> {
        match (config.get(key)) {
            case Some(value) => {
                if (value == "true") Some(true)
                else if (value == "false") Some(false)
                else None
            }
            case None => None
        }
    }

    public func getDuration(key: String): Option<Duration> {
        // 简化实现
        None
    }
}
