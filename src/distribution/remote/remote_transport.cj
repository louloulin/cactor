/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 远程传输层
 * 对标 Akka Remoting/RemoteTransport
 */
package cactor.distribution.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.ActorRef

/**
 * 远程地址 - 对标 Akka Address
 */
public struct Address {
    public let protocol: String  // "cactor"
    public let system: String    // Actor系统名称
    public let host: String     // 主机名/IP
    public let port: Int32      // 端口

    public init(protocol: String, system: String, host: String, port: Int32) {
        this.protocol = protocol
        this.system = system
        this.host = host
        this.port = port
    }

    public func toString(): String {
        "${protocol}://${system}@${host}:${port}"
    }

    public func hasHost(): Bool {
        host.size > 0
    }
}

/**
 * 远程消息信封 - 对标 Akka RemoteEnvelope
 */
public class RemoteEnvelope {
    public let recipient: ActorPath
    public let message: Message
    public let senderOption: Option<ActorPath>
    public let serializerId: Int32
    public let manifest: Option<String>

    public init(
        recipient: ActorPath,
        message: Message,
        senderOption: Option<ActorPath>,
        serializerId: Int32,
        manifest: Option<String>
    ) {
        this.recipient = recipient
        this.message = message
        this.senderOption = senderOption
        this.serializerId = serializerId
        this.manifest = manifest
    }

    public static func create(
        recipient: ActorPath,
        message: Message,
        senderOption: Option<ActorPath>
    ): RemoteEnvelope {
        RemoteEnvelope(recipient, message, senderOption, 0, None)
    }

    public func toString(): String {
        let senderStr = match (senderOption) {
            case Some(path) => path.toString()
            case None => "None"
        }
        "RemoteEnvelope(to=${recipient.toString()}, from=${senderStr})"
    }
}

/**
 * Actor路径 - 远程版本
 */
public class ActorPath {
    public let address: Address
    public let elements: Array<String>

    public init(address: Address, elements: Array<String>) {
        this.address = address
        this.elements = elements
    }

    public static func parse(path: String): ActorPath {
        ActorPath(Address("cactor", "system", "localhost", 0), Array<String>())
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append(address.toString())
        for (elem in elements) {
            sb.append("/")
            sb.append(elem)
        }
        sb.toString()
    }

    public func parent(): ActorPath {
        if (elements.size <= 1) {
            return ActorPath(address, Array<String>())
        }
        let newElements = Array<String>(Int64(elements.size - 1), { i => elements[Int64(i)] })
        ActorPath(address, newElements)
    }

    public func child(name: String): ActorPath {
        let newElements = Array<String>(Int64(elements.size + 1), { i =>
            if (Int64(i) < Int64(elements.size)) {
                elements[Int64(i)]
            } else {
                name
            }
        })
        ActorPath(address, newElements)
    }

    public func name(): String {
        if (elements.size == 0) {
            return ""
        }
        elements[elements.size - 1]
    }
}

/**
 * 远程传输层接口 - 对标 Akka RemoteTransport
 */
public interface RemoteTransport {
    func address(): Address
    func bind(): Unit
    func send(address: Address, envelope: RemoteEnvelope): Unit
    func receive(): RemoteMessageStream
    func shutdown(): Unit
    func isStarted(): Bool
}

/**
 * 远程消息流
 */
public interface RemoteMessageStream {
    func next(): Option<RemoteEnvelope>
    func close(): Unit
}

/**
 * 远程Actor引用
 */
public interface RemoteActorRef <: ActorRef {
    func address(): Address
    func actorPath(): ActorPath
}

/**
 * 简单远程消息流
 */
public class SimpleRemoteMessageStream <: RemoteMessageStream {
    private let queue: ArrayList<RemoteEnvelope>
    private var headIndex: Int64 = 0
    private let mutex: Mutex
    private var closed: Bool

    public init() {
        this.queue = ArrayList<RemoteEnvelope>()
        this.mutex = Mutex()
        this.closed = false
    }

    public func enqueue(envelope: RemoteEnvelope): Unit {
        mutex.lock()
        queue.add(envelope)
        mutex.unlock()
    }

    public func next(): Option<RemoteEnvelope> {
        mutex.lock()
        let result: Option<RemoteEnvelope> = if (headIndex < queue.size) {
            let item = queue[headIndex]
            headIndex += 1
            Some(item)
        } else {
            None
        }
        mutex.unlock()
        result
    }

    public func close(): Unit {
        mutex.lock()
        closed = true
        mutex.unlock()
    }
}

/**
 * 简单远程传输实现
 */
public class SimpleRemoteTransport <: RemoteTransport {
    private let localAddress: Address
    private let messageStream: SimpleRemoteMessageStream
    private let started: AtomicBool
    private let terminated: AtomicBool

    public init(localAddress: Address) {
        this.localAddress = localAddress
        this.messageStream = SimpleRemoteMessageStream()
        this.started = AtomicBool(false)
        this.terminated = AtomicBool(false)
    }

    public func address(): Address {
        localAddress
    }

    public func bind(): Unit {
        if (started.compareAndSwap(false, true)) {
            println("远程传输层启动: ${localAddress.toString()}")
        }
    }

    public func send(address: Address, envelope: RemoteEnvelope): Unit {
        if (!started.load()) {
            println("远程传输层未启动")
            return
        }
        // 简化实现：仅记录日志
        println("发送消息到 ${address.toString()}")
    }

    public func receive(): RemoteMessageStream {
        messageStream
    }

    public func shutdown(): Unit {
        if (terminated.compareAndSwap(false, true)) {
            messageStream.close()
            println("远程传输层关闭")
        }
    }

    public func isStarted(): Bool {
        started.load()
    }
}