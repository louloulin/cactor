/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - 本地Actor引用实现
 */
package cactor.impl.actor

import std.sync.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorState, LocalActorRef}
import cactor.core.message.{Message, StopMessage}
import cactor.core.mailbox.{Mailbox, Envelope}
import cactor.core.context.ActorContext

/**
 * 本地Actor引用实现
 */
public class LocalActorRefImpl <: LocalActorRef {
    private let actor: Actor
    private let actorPath: ActorPath
    private let mailbox: Mailbox
    private let context: ActorContext
    private let state: AtomicInt32
    private let running: AtomicBool

    public init(actor: Actor, path: ActorPath, mailbox: Mailbox, context: ActorContext) {
        this.actor = actor
        this.actorPath = path
        this.mailbox = mailbox
        this.context = context
        this.state = AtomicInt32(ActorState.Created.hashCode())
        this.running = AtomicBool(false)
    }

    public prop path: ActorPath {
        get() { actorPath }
    }

    public func tell(message: Message): Unit {
        tell(message, None)
    }

    public func tell(message: Message, sender: Option<ActorRef>): Unit {
        if (!mailbox.isClosed()) {
            mailbox.enqueue(message, sender)
        }
    }

    public func ask<T>(message: Message, timeout: Duration): Future<T> {
        // 简化实现，实际需要创建临时Actor来处理响应
        throw Exception("Ask pattern not implemented yet")
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case localRef: LocalActorRefImpl => 
                actorPath.equals(localRef.actorPath)
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        actorPath.hashCode()
    }

    public func getActor(): Actor {
        actor
    }

    public func suspend(): Unit {
        // 实现暂停逻辑
        setState(ActorState.Stopping)
    }

    public func resume(): Unit {
        // 实现恢复逻辑
        setState(ActorState.Running)
    }

    public func restart(cause: Exception): Unit {
        setState(ActorState.Restarting)
        try {
            actor.preRestart(cause)
            // 清空邮箱中的用户消息，保留系统消息
            clearUserMessages()
            actor.postRestart(cause)
            setState(ActorState.Running)
        } catch (e: Exception) {
            setState(ActorState.Failed)
            throw e
        }
    }

    public func stop(): Unit {
        tell(StopMessage())
    }

    public func getState(): ActorState {
        ActorState.fromHashCode(state.load())
    }

    /**
     * 启动Actor
     */
    public func start(): Unit {
        if (running.compareAndSwap(false, true)) {
            setState(ActorState.Starting)
            spawn {
                run()
            }
        }
    }

    /**
     * Actor主运行循环
     */
    private func run(): Unit {
        try {
            setState(ActorState.Running)
            actor.preStart()
            actor.postStart()

            while (!mailbox.isClosed() && getState() != ActorState.Stopped) {
                match (mailbox.dequeue()) {
                    case Some(envelope) => {
                        processMessage(envelope)
                    }
                    case None => {
                        // 没有消息，短暂休眠
                        sleep(Duration.millisecond)
                    }
                }
            }
        } catch (e: Exception) {
            setState(ActorState.Failed)
            handleFailure(e)
        } finally {
            setState(ActorState.Stopping)
            actor.preStop()
            mailbox.close()
            setState(ActorState.Stopped)
            actor.postStop()
            running.store(false)
        }
    }

    /**
     * 处理单个消息
     */
    private func processMessage(envelope: Envelope): Unit {
        let message = envelope.getMessage()
        
        // 设置当前发送者到上下文
        // context.setSender(envelope.getSender())
        
        try {
            match (message.messageType()) {
                case "StopMessage" => {
                    setState(ActorState.Stopping)
                    mailbox.close()
                }
                case _ => {
                    // 调用Actor的消息处理逻辑
                    match (actor) {
                        case typedActor: TypedActor<Message> => {
                            typedActor.receive(message, context)
                        }
                        case untypedActor: UntypedActor => {
                            untypedActor.receive(message, context)
                        }
                        case _ => {
                            // 默认处理
                        }
                    }
                }
            }
        } catch (e: Exception) {
            handleFailure(e)
        }
    }

    /**
     * 处理Actor失败
     */
    private func handleFailure(cause: Exception): Unit {
        setState(ActorState.Failed)
        // 通知监督者
        // context.parent().tell(FailureMessage(cause, context.self()))
    }

    /**
     * 清空用户消息，保留系统消息
     */
    private func clearUserMessages(): Unit {
        // 简化实现，实际需要区分系统消息和用户消息
        // mailbox.clear()
    }

    /**
     * 设置Actor状态
     */
    private func setState(newState: ActorState): Unit {
        state.store(newState.hashCode())
    }
}

/**
 * ActorState的扩展方法
 */
extension ActorState {
    public func hashCode(): Int32 {
        match (this) {
            case Created => 0
            case Starting => 1
            case Running => 2
            case Stopping => 3
            case Stopped => 4
            case Failed => 5
            case Restarting => 6
        }
    }
    
    public static func fromHashCode(code: Int32): ActorState {
        match (code) {
            case 0 => Created
            case 1 => Starting
            case 2 => Running
            case 3 => Stopping
            case 4 => Stopped
            case 5 => Failed
            case 6 => Restarting
            case _ => Stopped
        }
    }
}
