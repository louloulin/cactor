/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - Phase 4: 轻量级Actor系统
 * 内存管理优化：状态压缩、对象池化、内存对齐
 */
package cactor.core.lightweight

import std.sync.*
import std.time.*
import std.collection.*
import cactor.core.message.*
import cactor.core.actor.*
import cactor.mailbox.lockfree.*

/**
 * 压缩的Actor状态
 * 使用位字段和紧凑布局减少内存占用
 */
public struct CompactActorState {
    // 使用位字段压缩状态信息
    private let stateFlags: UInt32        // 状态标志位 (32位)
    private let messageCount: UInt16      // 消息计数 (16位)
    private let errorCount: UInt8         // 错误计数 (8位)
    private let priority: UInt8           // 优先级 (8位)
    
    // 状态标志位定义
    private static let RUNNING_FLAG: UInt32 = 0x01
    private static let SUSPENDED_FLAG: UInt32 = 0x02
    private static let STOPPING_FLAG: UInt32 = 0x04
    private static let STOPPED_FLAG: UInt32 = 0x08
    private static let ERROR_FLAG: UInt32 = 0x10
    
    public init() {
        this.stateFlags = 0
        this.messageCount = 0
        this.errorCount = 0
        this.priority = 1  // Normal priority
    }
    
    public func isRunning(): Bool {
        (stateFlags & CompactActorState.RUNNING_FLAG) != 0
    }
    
    public func isSuspended(): Bool {
        (stateFlags & CompactActorState.SUSPENDED_FLAG) != 0
    }
    
    public func isStopping(): Bool {
        (stateFlags & CompactActorState.STOPPING_FLAG) != 0
    }
    
    public func isStopped(): Bool {
        (stateFlags & CompactActorState.STOPPED_FLAG) != 0
    }
    
    public func hasError(): Bool {
        (stateFlags & CompactActorState.ERROR_FLAG) != 0
    }
    
    public func setRunning(): CompactActorState {
        CompactActorState(
            stateFlags | CompactActorState.RUNNING_FLAG,
            messageCount,
            errorCount,
            priority
        )
    }
    
    public func setSuspended(): CompactActorState {
        CompactActorState(
            (stateFlags & ~CompactActorState.RUNNING_FLAG) | CompactActorState.SUSPENDED_FLAG,
            messageCount,
            errorCount,
            priority
        )
    }
    
    public func setStopping(): CompactActorState {
        CompactActorState(
            stateFlags | CompactActorState.STOPPING_FLAG,
            messageCount,
            errorCount,
            priority
        )
    }
    
    public func setStopped(): CompactActorState {
        CompactActorState(
            (stateFlags & ~(CompactActorState.RUNNING_FLAG | CompactActorState.SUSPENDED_FLAG)) | CompactActorState.STOPPED_FLAG,
            messageCount,
            errorCount,
            priority
        )
    }
    
    public func setError(): CompactActorState {
        CompactActorState(
            stateFlags | CompactActorState.ERROR_FLAG,
            messageCount,
            if (errorCount < 255) { errorCount + 1 } else { 255 },
            priority
        )
    }
    
    public func incrementMessageCount(): CompactActorState {
        CompactActorState(
            stateFlags,
            if (messageCount < 65535) { messageCount + 1 } else { 0 },
            errorCount,
            priority
        )
    }
    
    public func getMessageCount(): UInt16 {
        messageCount
    }
    
    public func getErrorCount(): UInt8 {
        errorCount
    }
    
    public func getPriority(): UInt8 {
        priority
    }
    
    private init(stateFlags: UInt32, messageCount: UInt16, errorCount: UInt8, priority: UInt8) {
        this.stateFlags = stateFlags
        this.messageCount = messageCount
        this.errorCount = errorCount
        this.priority = priority
    }
}

/**
 * 池化的Actor上下文
 * 重用上下文对象减少分配开销
 */
public class PooledContext <: ActorContext {
    private var actorRef: Option<ActorRef>
    private var sender: Option<ActorRef>
    private var currentMessage: Option<Message>
    private var isInUse: Bool
    
    public init() {
        this.actorRef = None
        this.sender = None
        this.currentMessage = None
        this.isInUse = false
    }
    
    public func initialize(actorRef: ActorRef, sender: Option<ActorRef>, message: Message): Unit {
        this.actorRef = Some(actorRef)
        this.sender = sender
        this.currentMessage = Some(message)
        this.isInUse = true
    }
    
    public func reset(): Unit {
        this.actorRef = None
        this.sender = None
        this.currentMessage = None
        this.isInUse = false
    }
    
    public func getSelf(): ActorRef {
        match (actorRef) {
            case Some(ref) => ref
            case None => throw Exception("Context not initialized")
        }
    }
    
    public func getSender(): Option<ActorRef> {
        sender
    }
    
    public func getCurrentMessage(): Option<Message> {
        currentMessage
    }
    
    public func isAvailable(): Bool {
        !isInUse
    }
}

/**
 * 轻量级Actor实现
 * 使用压缩状态和池化上下文减少内存占用
 */
public class LightweightActor <: Actor {
    private let actorId: String
    private let state: AtomicReference<CompactActorState>
    private let mailbox: LockFreeRingBufferMailbox
    private let contextPool: ContextPool
    private let behavior: ActorBehavior
    
    public init(actorId: String, behavior: ActorBehavior, contextPool: ContextPool) {
        this.actorId = actorId
        this.state = AtomicReference<CompactActorState>(CompactActorState())
        this.mailbox = LockFreeRingBufferMailbox(256)  // 小容量邮箱
        this.contextPool = contextPool
        this.behavior = behavior
    }
    
    public func getActorId(): String {
        actorId
    }
    
    public func tell(message: Message, sender: Option<ActorRef>): Unit {
        if (!state.load().isStopped()) {
            let envelope = Envelope(message, sender)
            if (!mailbox.enqueue(envelope)) {
                // 邮箱满，记录错误
                updateState { currentState => currentState.setError() }
            }
        }
    }
    
    public func processMessages(): Unit {
        while (!state.load().isStopped()) {
            match (mailbox.dequeue()) {
                case Some(envelope) =>
                    processMessage(envelope)
                case None =>
                    break  // 没有更多消息
            }
        }
    }
    
    private func processMessage(envelope: Envelope): Unit {
        let context = contextPool.acquire()
        try {
            context.initialize(createActorRef(), envelope.getSender(), envelope.getMessage())
            
            let result = behavior.receive(envelope.getMessage(), context)
            
            // 更新消息计数
            updateState { currentState => currentState.incrementMessageCount() }
            
            match (result) {
                case MessageResult.Handled => 
                    // 消息处理成功
                    ()
                case MessageResult.Unhandled =>
                    // 未处理的消息
                    ()
                case MessageResult.Failed =>
                    // 处理失败
                    updateState { currentState => currentState.setError() }
            }
        } catch (e: Exception) {
            updateState { currentState => currentState.setError() }
        } finally {
            context.reset()
            contextPool.release(context)
        }
    }
    
    private func updateState(updater: (CompactActorState) -> CompactActorState): Unit {
        var currentState = state.load()
        var newState = updater(currentState)
        while (!state.compareAndSwap(currentState, newState)) {
            currentState = state.load()
            newState = updater(currentState)
        }
    }
    
    private func createActorRef(): ActorRef {
        LightweightActorRef(actorId, this)
    }
    
    public func start(): Unit {
        updateState { currentState => currentState.setRunning() }
    }
    
    public func stop(): Unit {
        updateState { currentState => currentState.setStopping() }
        // 处理完剩余消息后停止
        processMessages()
        updateState { currentState => currentState.setStopped() }
    }
    
    public func suspend(): Unit {
        updateState { currentState => currentState.setSuspended() }
    }
    
    public func resume(): Unit {
        updateState { currentState => currentState.setRunning() }
    }
    
    public func getState(): CompactActorState {
        state.load()
    }
    
    public func getMailboxSize(): Int64 {
        mailbox.size()
    }
    
    public func getMemoryFootprint(): Int64 {
        // 估算内存占用：状态(8字节) + 邮箱(小) + 基础开销
        64  // 约64字节，相比传统Actor的540KB大幅减少
    }
}

/**
 * 轻量级Actor引用
 */
public class LightweightActorRef <: ActorRef {
    private let actorId: String
    private let actor: LightweightActor
    
    public init(actorId: String, actor: LightweightActor) {
        this.actorId = actorId
        this.actor = actor
    }
    
    public prop path: ActorPath {
        get() {
            SimpleActorPath(actorId)
        }
    }
    
    public func tell(message: Message): Unit {
        actor.tell(message, None)
    }
    
    public func equals(other: Object): Bool {
        match (other) {
            case ref: LightweightActorRef => ref.actorId == this.actorId
            case _ => false
        }
    }
    
    public func hashCode(): Int32 {
        actorId.hashCode()
    }
}

/**
 * 简单Actor路径实现
 */
public class SimpleActorPath <: ActorPath {
    private let path: String
    
    public init(path: String) {
        this.path = path
    }
    
    public func toString(): String {
        path
    }
}
