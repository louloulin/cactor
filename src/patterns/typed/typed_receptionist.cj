/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Typed Receptionist 实现
 * 对标 Akka Typed Receptionist 动态服务发现
 */
package cactor.patterns.typed

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, Props, ActorContext, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult}
import cactor.core.system.{ActorSystem}

/**
 * ReceptionistCommand - Receptionist 命令类型
 */
public interface ReceptionistCommand {
    func commandType(): String
}

/**
 * RegisterService - 注册服务命令
 */
public class RegisterService <: Message & ReceptionistCommand {
    public let serviceKey: String
    public let serviceRef: ActorRef

    public init(serviceKey: String, serviceRef: ActorRef) {
        this.serviceKey = serviceKey
        this.serviceRef = serviceRef
    }

    public func commandType(): String {
        "RegisterService"
    }

    public func messageType(): String {
        "RegisterService"
    }
}

/**
 * DeregisterService - 注销服务命令
 */
public class DeregisterService <: Message & ReceptionistCommand {
    public let serviceKey: String

    public init(serviceKey: String) {
        this.serviceKey = serviceKey
    }

    public func commandType(): String {
        "DeregisterService"
    }

    public func messageType(): String {
        "DeregisterService"
    }
}

/**
 * FindService - 查找服务命令
 */
public class FindService <: Message & ReceptionistCommand {
    public let serviceKey: String
    public let replyTo: ActorRef

    public init(serviceKey: String, replyTo: ActorRef) {
        this.serviceKey = serviceKey
        this.replyTo = replyTo
    }

    public func commandType(): String {
        "FindService"
    }

    public func messageType(): String {
        "FindService"
    }
}

/**
 * FindServices - 查找所有匹配的服务
 */
public class FindServices <: Message & ReceptionistCommand {
    public let serviceKey: String
    public let replyTo: ActorRef

    public init(serviceKey: String, replyTo: ActorRef) {
        this.serviceKey = serviceKey
        this.replyTo = replyTo
    }

    public func commandType(): String {
        "FindServices"
    }

    public func messageType(): String {
        "FindServices"
    }
}

/**
 * ServiceRegistered - 服务注册成功响应
 */
public class ServiceRegistered <: Message {
    public let serviceRef: ActorRef
    public let serviceKey: String

    public init(serviceRef: ActorRef, serviceKey: String) {
        this.serviceRef = serviceRef
        this.serviceKey = serviceKey
    }

    public func messageType(): String {
        "ServiceRegistered"
    }
}

/**
 * ServiceDeregistered - 服务注销响应
 */
public class ServiceDeregistered <: Message {
    public let serviceKey: String

    public init(serviceKey: String) {
        this.serviceKey = serviceKey
    }

    public func messageType(): String {
        "ServiceDeregistered"
    }
}

/**
 * ServiceFound - 服务查找成功响应（单个）
 */
public class ServiceFound <: Message {
    public let serviceRef: ActorRef
    public let serviceKey: String

    public init(serviceRef: ActorRef, serviceKey: String) {
        this.serviceRef = serviceRef
        this.serviceKey = serviceKey
    }

    public func messageType(): String {
        "ServiceFound"
    }
}

/**
 * ServiceNotFound - 服务未找到响应
 */
public class ServiceNotFound <: Message {
    public let serviceKey: String

    public init(serviceKey: String) {
        this.serviceKey = serviceKey
    }

    public func messageType(): String {
        "ServiceNotFound"
    }
}

/**
 * ServicesFound - 服务列表响应
 */
public class ServicesFound <: Message {
    public let serviceRefs: ArrayList<ActorRef>
    public let serviceKey: String

    public init(serviceRefs: ArrayList<ActorRef>, serviceKey: String) {
        this.serviceRefs = serviceRefs
        this.serviceKey = serviceKey
    }

    public func messageType(): String {
        "ServicesFound"
    }

    public func getServices(): Array<ActorRef> {
        serviceRefs.toArray()
    }
}

/**
 * ReceptionistEntry - 服务条目
 */
class ReceptionistEntry {
    public let serviceRef: ActorRef
    public let registeredAt: Int64

    public init(serviceRef: ActorRef) {
        this.serviceRef = serviceRef
        this.registeredAt = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * ReceptionistActor - 服务注册中心 Actor
 * 管理所有注册的服务，支持动态发现
 */
public class ReceptionistActor <: Actor {
    private let services: HashMap<String, ArrayList<ReceptionistEntry>>
    private let listeners: ArrayList<ActorRef>
    private let mutex: Mutex

    public init() {
        this.services = HashMap<String, ArrayList<ReceptionistEntry>>()
        this.listeners = ArrayList<ActorRef>()
        this.mutex = Mutex()
    }

    public prop name: String {
        get() { "receptionist" }
    }

    public prop description: String {
        get() { "Typed Receptionist Actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case reg: RegisterService =>
                handleRegister(reg.serviceKey, reg.serviceRef)
                MessageResult.Handled
            case dereg: DeregisterService =>
                handleDeregister(dereg.serviceKey)
                MessageResult.Handled
            case find: FindService =>
                handleFindService(find.serviceKey, find.replyTo)
                MessageResult.Handled
            case finds: FindServices =>
                handleFindServices(finds.serviceKey, finds.replyTo)
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }

    private func handleRegister(key: String, serviceRef: ActorRef): Unit {
        mutex.lock()
        try {
            let entries = services.get(key)
            match (entries) {
                case Some(list) =>
                    list.add(ReceptionistEntry(serviceRef))
                case None =>
                    let newList = ArrayList<ReceptionistEntry>()
                    newList.add(ReceptionistEntry(serviceRef))
                    services.add(key, newList)
            }
            // 通知所有监听者
            for (listener in listeners) {
                listener.tell(ServiceRegistered(serviceRef, key))
            }
        } finally {
            mutex.unlock()
        }
    }

    private func handleDeregister(key: String): Unit {
        mutex.lock()
        try {
            services.remove(key)
            // 通知所有监听者
            for (listener in listeners) {
                listener.tell(ServiceDeregistered(key))
            }
        } finally {
            mutex.unlock()
        }
    }

    private func handleFindService(key: String, replyTo: ActorRef): Unit {
        mutex.lock()
        let entries = services.get(key)
        mutex.unlock()

        match (entries) {
            case Some(list) =>
                if (list.size > 0) {
                    replyTo.tell(ServiceFound(list[0].serviceRef, key))
                } else {
                    replyTo.tell(ServiceNotFound(key))
                }
            case None =>
                replyTo.tell(ServiceNotFound(key))
        }
    }

    private func handleFindServices(key: String, replyTo: ActorRef): Unit {
        mutex.lock()
        let entries = services.get(key)
        mutex.unlock()

        match (entries) {
            case Some(list) =>
                let refs = ArrayList<ActorRef>()
                for (entry in list) {
                    refs.add(entry.serviceRef)
                }
                replyTo.tell(ServicesFound(refs, key))
            case None =>
                let emptyRefs = ArrayList<ActorRef>()
                replyTo.tell(ServicesFound(emptyRefs, key))
        }
    }

    public func preStart(): Unit {}

    public func postStart(): Unit {}

    public func preStop(): Unit {}

    public func postStop(): Unit {}

    public func preRestart(reason: Exception): Unit {}

    public func postRestart(reason: Exception): Unit {}

    public func create(): Unit {}
}

/**
 * TypedReceptionist - Typed Receptionist 客户端
 * 提供服务注册和发现的 API
 */
public class TypedReceptionist {
    private let system: ActorSystem
    private let receptionistRef: ActorRef

    public init(system: ActorSystem) {
        this.system = system
        // 创建或获取 receptionist actor
        let factory = SimpleActorFactory<Actor>({ => ReceptionistActor() })
        let props = Props<Actor>(factory)
        this.receptionistRef = system.actorOf(props, "receptionist")
    }

    /**
     * 注册服务
     */
    public func register(serviceRef: ActorRef, key: String): Unit {
        let registerMsg = RegisterService(key, serviceRef)
        receptionistRef.tell(registerMsg)
    }

    /**
     * 注销服务
     */
    public func deregister(key: String): Unit {
        let deregisterMsg = DeregisterService(key)
        receptionistRef.tell(deregisterMsg)
    }

    /**
     * 查找单个服务（同步）
     */
    public func find(key: String, replyTo: ActorRef): Unit {
        let findMsg = FindService(key, replyTo)
        receptionistRef.tell(findMsg)
    }

    /**
     * 查找所有匹配的服务
     */
    public func findAll(key: String, replyTo: ActorRef): Unit {
        let findMsg = FindServices(key, replyTo)
        receptionistRef.tell(findMsg)
    }

    /**
     * 创建服务键
     */
    public static func serviceKey(typeName: String, id: String): String {
        "service://${id}/${typeName}"
    }
}