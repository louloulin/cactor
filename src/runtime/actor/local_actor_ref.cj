/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 本地Actor引用实现
 * 基于仓颉语言特性的高性能Actor实现
 */
package cactor.runtime.actor

import std.sync.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, ActorLifecycleState, LocalActorRef}
import cactor.core.message.{Message, Envelope, MessageResult, StopMessage}
import cactor.core.mailbox.Mailbox
import cactor.core.context.ActorContext

/**
 * 原子状态管理
 * 使用位操作压缩状态信息，提高性能
 */
public class AtomicActorState {
    // 状态位布局: [63-32: 消息计数] [31-16: 错误计数] [15-0: 状态标志]
    private let packedState: AtomicInt64
    
    private static let MESSAGE_COUNT_SHIFT: Int32 = 32
    private static let ERROR_COUNT_SHIFT: Int32 = 16
    private static let STATE_MASK: Int64 = 0xFFFF
    
    public init() {
        this.packedState = AtomicInt64(ActorLifecycleState.Created.toInt64())
    }
    
    public func incrementMessageCount(): Int64 {
        let increment = Int64(1) << MESSAGE_COUNT_SHIFT
        let newState = packedState.fetchAdd(increment)
        (newState + increment) >> MESSAGE_COUNT_SHIFT
    }
    
    public func getMessageCount(): Int64 {
        packedState.load() >> MESSAGE_COUNT_SHIFT
    }
    
    public func incrementErrorCount(): Int64 {
        let increment = Int64(1) << ERROR_COUNT_SHIFT
        let newState = packedState.fetchAdd(increment)
        ((newState + increment) >> ERROR_COUNT_SHIFT) & 0xFFFF
    }
    
    public func getErrorCount(): Int64 {
        (packedState.load() >> ERROR_COUNT_SHIFT) & 0xFFFF
    }
    
    public func compareAndSetState(expected: ActorLifecycleState,
                                  desired: ActorLifecycleState): Bool {
        let currentPacked = packedState.load()
        let currentState = currentPacked & STATE_MASK

        if (currentState == expected.toInt64()) {
            // 简化实现：清除状态位并设置新状态
            let clearedPacked = currentPacked - currentState
            let newPacked = clearedPacked | desired.toInt64()
            return packedState.compareAndSwap(currentPacked, newPacked)
        }

        return false
    }
    
    public func getState(): ActorLifecycleState {
        let state = packedState.load() & STATE_MASK
        ActorLifecycleState.fromInt64(state)
    }
}

/**
 * 本地Actor引用实现
 * 高性能的Actor实现，充分利用仓颉的并发特性
 */
public class LocalActorRefImpl <: LocalActorRef {
    private let actor: Actor
    private let actorPath: ActorPath
    private let mailbox: Mailbox
    private let context: ActorContext
    private let atomicState: AtomicActorState
    private let running: AtomicBool

    public init(actor: Actor, path: ActorPath, mailbox: Mailbox, context: ActorContext) {
        this.actor = actor
        this.actorPath = path
        this.mailbox = mailbox
        this.context = context
        this.atomicState = AtomicActorState()
        this.running = AtomicBool(false)
    }

    public prop path: ActorPath {
        get() { actorPath }
    }

    public func tell(message: Message): Unit {
        tell(message, None)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        if (!mailbox.isClosed()) {
            let envelope = Envelope(message, sender)
            if (mailbox.enqueue(envelope)) {
                atomicState.incrementMessageCount()
            }
        }
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
        atomicState.compareAndSetState(ActorLifecycleState.Running, ActorLifecycleState.Stopping)
    }

    public func resume(): Unit {
        atomicState.compareAndSetState(ActorLifecycleState.Stopping, ActorLifecycleState.Running)
    }

    public func restart(cause: Exception): Unit {
        if (atomicState.compareAndSetState(ActorLifecycleState.Running, ActorLifecycleState.Restarting)) {
            try {
                actor.preRestart(cause)
                // 清空邮箱中的用户消息，保留系统消息
                clearUserMessages()
                actor.postRestart(cause)
                atomicState.compareAndSetState(ActorLifecycleState.Restarting, ActorLifecycleState.Running)
            } catch (e: Exception) {
                atomicState.compareAndSetState(ActorLifecycleState.Restarting, ActorLifecycleState.Failed)
                throw e
            }
        }
    }

    public func stop(): Unit {
        tell(StopMessage())
    }

    public func getState(): ActorLifecycleState {
        atomicState.getState()
    }

    /**
     * 启动Actor
     * 使用仓颉的spawn创建轻量级线程
     */
    public func start(): Unit {
        if (running.compareAndSwap(false, true)) {
            if (atomicState.compareAndSetState(ActorLifecycleState.Created, ActorLifecycleState.Starting)) {
                spawn {
                    run()
                }
            }
        }
    }

    /**
     * Actor主运行循环
     * 高性能的消息处理循环
     */
    private func run(): Unit {
        try {
            atomicState.compareAndSetState(ActorLifecycleState.Starting, ActorLifecycleState.Running)
            actor.preStart()
            actor.postStart()

            while (!mailbox.isClosed()) {
                match (mailbox.dequeue()) {
                    case Some(envelope) => processMessage(envelope)
                    case None => sleep(Duration.microsecond * 100)
                }
            }
        } catch (e: Exception) {
            atomicState.compareAndSetState(getState(), ActorLifecycleState.Failed)
            atomicState.incrementErrorCount()
            handleFailure(e)
        } finally {
            atomicState.compareAndSetState(getState(), ActorLifecycleState.Stopping)
            actor.preStop()
            mailbox.close()
            atomicState.compareAndSetState(ActorLifecycleState.Stopping, ActorLifecycleState.Stopped)
            actor.postStop()
            running.store(false)
        }
    }

    /**
     * 处理单个消息
     * 支持类型化和非类型化Actor
     */
    private func processMessage(envelope: Envelope): Unit {
        let message = envelope.getMessage()
        
        try {
            if (message.messageType() == "StopMessage") {
                atomicState.compareAndSetState(ActorLifecycleState.Running, ActorLifecycleState.Stopping)
                mailbox.close()
            } else {
                // 调用Actor的消息处理逻辑
                handleActorMessage(message)
            }
        } catch (e: Exception) {
            atomicState.incrementErrorCount()
            handleFailure(e)
        }
    }

    /**
     * 处理Actor消息
     * 简化的消息分发机制
     */
    private func handleActorMessage(message: Message): Unit {
        // 这里需要根据具体的Actor类型进行消息分发
        // 由于仓颉的类型系统限制，我们使用简化的处理方式
        
        // 对于实际的Actor实现，需要在Actor中定义receive方法
        // 这里只是一个占位符实现
        println("Processing message: ${message.messageType()}")
    }

    /**
     * 处理Actor失败
     */
    private func handleFailure(cause: Exception): Unit {
        atomicState.compareAndSetState(getState(), ActorLifecycleState.Failed)
        // 通知监督者
        // context.parent().tell(FailureMessage(cause, context.self()))
        println("Actor failed: ${cause.message}")
    }

    /**
     * 清空用户消息，保留系统消息
     */
    private func clearUserMessages(): Unit {
        // 简化实现，实际需要区分系统消息和用户消息
        // 这里暂时不清空，让消息继续处理
    }

    /**
     * 获取性能指标
     */
    public func getMetrics(): ActorMetrics {
        ActorMetrics(
            atomicState.getMessageCount(),
            atomicState.getErrorCount(),
            mailbox.size(),
            getState()
        )
    }
}

/**
 * Actor性能指标
 */
public struct ActorMetrics {
    public let messageCount: Int64
    public let errorCount: Int64
    public let queueSize: Int64
    public let state: ActorLifecycleState

    public init(messageCount: Int64, errorCount: Int64, queueSize: Int64, state: ActorLifecycleState) {
        this.messageCount = messageCount
        this.errorCount = errorCount
        this.queueSize = queueSize
        this.state = state
    }
}
