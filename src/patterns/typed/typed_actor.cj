/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - TypedActor 类型安全的Actor实现
 * 对标 Akka Typed Actor
 */
package cactor.patterns.typed

import std.collection.*
import std.sync.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, Props, SimpleActorFactory, ActorContext}
import cactor.core.message.{Message, Envelope, MessageResult}
import cactor.core.system.{ActorSystem}

/*
 * TypedActor 消息信封
 * 用于封装类型化的消息
 */
public class TypedEnvelope <: Message {
    private let message: Message
    private let protocolType: String

    public init(message: Message, protocolType: String) {
        this.message = message
        this.protocolType = protocolType
    }

    public func messageType(): String {
        "TypedEnvelope[${protocolType}]"
    }

    public func getMessage(): Message { message }

    public func getProtocolType(): String { protocolType }
}

/*
 * TypedActorRef - 类型安全的Actor引用
 * 提供强类型的方法调用而非消息传递
 */
public interface TypedActorRef<T> {
    /**
     * 发送类型化消息
     */
    func tell(message: T): Unit

    /**
     * 获取底层Actor引用
     */
    func underlyingRef(): ActorRef

    /**
     * 获取Actor路径
     */
    func path(): ActorPath
}

/*
 * ActorProtocol - Actor协议定义接口
 * 定义Actor必须处理的命令类型
 */
public interface ActorProtocol<Command> {
    /**
     * 获取协议名称
     */
    func protocolName(): String
}

/*
 * ActorBehaviorHandler - 行为处理器
 * 处理特定命令类型
 */
public interface ActorBehaviorHandler {
    /**
     * 处理消息
     */
    func handleMessage(message: Message): Unit

    /**
     * 获取当前处理的状态
     */
    func currentState(): String
}

/*
 * TypedActorImpl - TypedActor实现
 * 内部使用标准Actor实现，但提供类型安全的接口
 */
public class TypedActorImpl<Command> <: Actor & ActorProtocol<Command> {
    private let actorName: String
    private let behaviorHandler: ActorBehaviorHandler
    private let protoName: String
    private var messageCount: Int64 = 0

    public init(name: String, behavior: ActorBehaviorHandler, protoName: String) {
        this.actorName = name
        this.behaviorHandler = behavior
        this.protoName = protoName
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "TypedActor[${protoName}]: ${actorName}" }
    }

    public func protocolName(): String { protoName }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case te: TypedEnvelope =>
                // Verify protocol type matches
                if (te.getProtocolType() == protoName) {
                    behaviorHandler.handleMessage(te.getMessage())
                    messageCount += 1
                    MessageResult.Handled
                } else {
                    MessageResult.Unhandled
                }
            case _ =>
                MessageResult.Unhandled
        }
    }

    public func preStart(): Unit {}

    public func postStart(): Unit {}

    public func preStop(): Unit {}

    public func postStop(): Unit {}

    public func preRestart(reason: Exception): Unit {}

    public func postRestart(reason: Exception): Unit {}

    public func create(): Unit {}

    public func getMessageCount(): Int64 { messageCount }

    public func getHandlerState(): String { behaviorHandler.currentState() }
}

/*
 * TypedActorRefImpl - TypedActorRef实现
 */
public class TypedActorRefImpl<Command> <: TypedActorRef<Command> {
    private let ref: ActorRef
    private let protocolName: String

    public init(ref: ActorRef, protocolName: String) {
        this.ref = ref
        this.protocolName = protocolName
    }

    public func tell(message: Command): Unit {
        match (message) {
            case msg: Message =>
                let envelope = TypedEnvelope(msg, protocolName)
                ref.tell(envelope)
            case _ =>
                throw Exception("TypedActor: message must implement Message interface")
        }
    }

    public func underlyingRef(): ActorRef { ref }

    public func path(): ActorPath { ref.path }
}

/*
 * TypedActor 工厂
 * 用于创建类型安全的TypedActor实例
 */
public class TypedActor {
    private let system: ActorSystem

    public init(system: ActorSystem) {
        this.system = system
    }

    /**
     * 创建TypedActor
     * @param protocolName 协议名称
     * @param behavior 行为处理器
     * @param name Actor名称
     * @return TypedActorRef<Command>
     */
    public func of<Command>(
        protocolName: String,
        behavior: ActorBehaviorHandler,
        name: String
    ): TypedActorRef<Command> {
        let actor = TypedActorImpl<Command>(name, behavior, protocolName)
        let factory = SimpleActorFactory<Actor>({ => actor })
        let props = Props<Actor>(factory)
        let ref = system.actorOf(props, name)
        TypedActorRefImpl<Command>(ref, protocolName)
    }

    /**
     * 创建TypedActor（自动命名）
     */
    public func of<Command>(
        protocolName: String,
        behavior: ActorBehaviorHandler
    ): TypedActorRef<Command> {
        let actor = TypedActorImpl<Command>("typed-actor", behavior, protocolName)
        let factory = SimpleActorFactory<Actor>({ => actor })
        let props = Props<Actor>(factory)
        let ref = system.actorOf(props)
        TypedActorRefImpl<Command>(ref, protocolName)
    }
}
