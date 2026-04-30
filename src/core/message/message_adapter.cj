/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 消息适配器
 * 对标 Akka MessageAdapter
 * 提供消息类型转换功能
 */
package cactor.core.message

import std.collection.*

/**
 * 消息适配器函数类型
 * 将原消息转换为目标类型的消息
 */
public type MessageAdapter<Source, Target> = (Source) -> Target

/**
 * 消息适配器注册信息
 */
public class MessageAdapterRegistration<Source, Target> {
    public let adapter: MessageAdapter<Source, Target>
    public let manifest: String
    public let targetManifest: String

    public init(adapter: MessageAdapter<Source, Target>, manifest: String, targetManifest: String) {
        this.adapter = adapter
        this.manifest = manifest
        this.targetManifest = targetManifest
    }
}

/**
 * 消息适配器管理接口
 */
public interface MessageAdapterRegistry {
    func register<Source, Target>(
        adapter: MessageAdapter<Source, Target>,
        manifest: String,
        targetManifest: String
    ): Unit

    func adapt(message: Message): Message

    func adapterCount(): Int64

    func clear(): Unit
}

/**
 * 简单消息适配器注册表
 * 不使用泛型避免类型擦除问题
 */
public class SimpleMessageAdapterRegistry <: MessageAdapterRegistry {
    private let registry: ArrayList<MessageAdapterRegistration<Any, Any>>
    private let manifestMap: HashMap<String, Int64>

    public init() {
        this.registry = ArrayList<MessageAdapterRegistration<Any, Any>>()
        this.manifestMap = HashMap<String, Int64>()
    }

    public func register<Source, Target>(
        adapter: MessageAdapter<Source, Target>,
        manifest: String,
        targetManifest: String
    ): Unit {
        let wrapper: MessageAdapter<Any, Any> = { source =>
            let src = matchWithCast<Source>(source)
            adapter(src)
        }
        let registration = MessageAdapterRegistration<Any, Any>(wrapper, manifest, targetManifest)
        registry.add(registration)
        manifestMap.add(manifest, registry.size - 1)
    }

    public func adapt(message: Message): Message {
        let msgType = message.messageType()
        match (manifestMap.get(msgType)) {
            case Some(index) =>
                let registration = registry[index]
                let adapted = registration.adapter(message)
                matchWithCast<Message>(adapted)
            case None =>
                message
        }
    }

    public func adapterCount(): Int64 {
        registry.size
    }

    public func clear(): Unit {
        registry.clear()
        manifestMap.clear()
    }

    public func getAdapter(manifest: String): Option<MessageAdapterRegistration<Any, Any>> {
        match (manifestMap.get(manifest)) {
            case Some(index) => Some(registry[index])
            case None => None
        }
    }
}

/**
 * 类型转换辅助函数
 */
private func matchWithCast<T>(value: Any): T {
    match (value) {
        case v: T => v
        case _ => throw Exception("Type cast failed")
    }
}

/**
 * Actor 消息适配器混入接口
 */
public interface MessageAdapterSupport {
    func getAdapterRegistry(): MessageAdapterRegistry
    func adapter<Source, Target>(
        adapter: MessageAdapter<Source, Target>,
        manifest: String,
        targetManifest: String
    ): Unit
}

/**
 * 消息类型标识生成器
 */
public class MessageTypeTag<T> {
    public let typeName: String

    public init(typeName: String) {
        this.typeName = typeName
    }

    public static func of<T>(typeName: String): MessageTypeTag<T> {
        MessageTypeTag<T>(typeName)
    }
}

/**
 * TypedMessage - 带有类型信息的包装消息
 */
public class TypedMessage<T> <: Message {
    public let payload: T
    public let typeTag: String

    public init(payload: T, typeTag: String) {
        this.payload = payload
        this.typeTag = typeTag
    }

    public func messageType(): String {
        typeTag
    }

    public func getPayload(): T {
        payload
    }
}

/**
 * 消息适配器辅助函数
 */
public struct MessageAdapters {
    /**
     * 创建类型安全的适配器
     */
    public static func adapt<Source, Target>(
        fn: (Source) -> Target
    ): MessageAdapter<Source, Target> {
        fn
    }
}
