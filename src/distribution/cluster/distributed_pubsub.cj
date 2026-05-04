/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Distributed Pub/Sub 集群发布订阅机制
 * 对标 Akka DistributedPubSub
 * 实现集群范围内的发布-订阅消息传递
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 发布订阅消息类型
 * 用于在集群中传递 pub/sub 消息
 */
public enum PubSubMessageType {
    PublishMsg
    SendMsg
    SendToAllMsg
    SubscribeMsg
    UnsubscribeMsg
    PutMsg
    GetMsg
}

/**
 * 发布订阅消息
 */
public class PubSubMessage {
    public let msgType: PubSubMessageType
    public let topic: String
    public let payload: String
    public let sender: String
    public let groupId: Option<String>
    public let allAtOnce: Bool
    public let timestamp: Int64

    public init(msgType: PubSubMessageType, topic: String, payload: String, sender: String, groupId: Option<String>, allAtOnce: Bool) {
        this.msgType = msgType
        this.topic = topic
        this.payload = payload
        this.sender = sender
        this.groupId = groupId
        this.allAtOnce = allAtOnce
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 主题订阅者信息
 */
public class Subscriber {
    public let actorPath: String
    public let nodeId: String
    public let groupId: Option<String>
    public let registeredAt: Int64

    public init(actorPath: String, nodeId: String, groupId: Option<String>) {
        this.actorPath = actorPath
        this.nodeId = nodeId
        this.groupId = groupId
        this.registeredAt = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 主题管理器
 * 管理单个主题的订阅者
 */
public class TopicManager {
    public let topicName: String
    private let subscribers: HashMap<String, Subscriber>
    private let lock: ReentrantMutex

    public init(topicName: String) {
        this.topicName = topicName
        this.subscribers = HashMap<String, Subscriber>()
        this.lock = ReentrantMutex()
    }

    /**
     * 添加订阅者
     */
    public func subscribe(actorPath: String, nodeId: String, groupId: Option<String>): Unit {
        lock.lock()
        let subscriber = Subscriber(actorPath, nodeId, groupId)
        subscribers.add(actorPath, subscriber)
        lock.unlock()
    }

    /**
     * 移除订阅者
     */
    public func unsubscribe(actorPath: String): Unit {
        lock.lock()
        subscribers.remove(actorPath)
        lock.unlock()
    }

    /**
     * 获取所有订阅者
     */
    public func getSubscribers(): ArrayList<Subscriber> {
        lock.lock()
        let result = ArrayList<Subscriber>()
        for ((_, subscriber) in subscribers) {
            result.add(subscriber)
        }
        lock.unlock()
        result
    }

    /**
     * 获取订阅者数量
     */
    public func subscriberCount(): Int64 {
        lock.lock()
        let count = subscribers.size
        lock.unlock()
        count
    }

    /**
     * 检查是否有订阅者
     */
    public func hasSubscribers(): Bool {
        lock.lock()
        let result = subscribers.size > 0
        lock.unlock()
        result
    }

    /**
     * 获取特定组的订阅者
     */
    public func getGroupSubscribers(groupId: String): ArrayList<Subscriber> {
        lock.lock()
        let result = ArrayList<Subscriber>()
        for ((_, subscriber) in subscribers) {
            match (subscriber.groupId) {
                case Some(gid) =>
                    if (gid == groupId) {
                        result.add(subscriber)
                    }
                case None => ()
            }
        }
        lock.unlock()
        result
    }

    /**
     * 清除所有订阅者
     */
    public func clear(): Unit {
        lock.lock()
        subscribers.clear()
        lock.unlock()
    }
}

/**
 * 节点注册信息
 */
public class NodeRegistration {
    public let nodeId: String
    public let address: Address
    public let actorPaths: ArrayList<String>
    public let timestamp: Int64

    public init(nodeId: String, address: Address) {
        this.nodeId = nodeId
        this.address = address
        this.actorPaths = ArrayList<String>()
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /**
     * 注册 Actor 路径
     */
    public func addActorPath(actorPath: String): Unit {
        actorPaths.add(actorPath)
    }

    /**
     * 检查是否包含 Actor 路径
     */
    public func hasActorPath(actorPath: String): Bool {
        actorPaths.contains(actorPath)
    }
}

/**
 * 分布式发布订阅事件处理器
 */
public interface PubSubEventHandler {
    /**
     * 订阅者注册事件
     */
    func onSubscribe(topic: String, actorPath: String, nodeId: String): Unit

    /**
     * 订阅者取消注册事件
     */
    func onUnsubscribe(topic: String, actorPath: String, nodeId: String): Unit

    /**
     * 消息发布事件
     */
    func onPublish(topic: String, payload: String, sender: String): Unit

    /**
     * 节点注册事件
     */
    func onNodeRegistered(nodeId: String, address: Address): Unit

    /**
     * 节点注销事件
     */
    func onNodeUnregistered(nodeId: String): Unit
}

/**
 * DistributedPubSubMediator - 分布式发布订阅中介器
 * 对标 Akka DistributedPubSubMediator
 * 管理集群范围内的发布-订阅消息传递
 */
public class DistributedPubSubMediator {
    private let nodeId: String
    private let topics: HashMap<String, TopicManager>
    private let nodes: HashMap<String, NodeRegistration>
    private let lock: ReentrantReadWriteMutex
    private var eventHandler: Option<PubSubEventHandler>
    private var messageCount: Int64

    public init(nodeId: String) {
        this.nodeId = nodeId
        this.topics = HashMap<String, TopicManager>()
        this.nodes = HashMap<String, NodeRegistration>()
        this.lock = ReentrantReadWriteMutex()
        this.eventHandler = None
        this.messageCount = 0
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: PubSubEventHandler): Unit {
        lock.writeMutex.lock()
        eventHandler = Some(handler)
        lock.writeMutex.unlock()
    }

    /**
     * 注册节点
     */
    public func registerNode(nodeId: String, address: Address): Unit {
        lock.writeMutex.lock()
        let registration = NodeRegistration(nodeId, address)
        nodes.add(nodeId, registration)
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onNodeRegistered(nodeId, address)
            case None => ()
        }
    }

    /**
     * 注销节点
     */
    public func unregisterNode(nodeId: String): Unit {
        lock.writeMutex.lock()
        nodes.remove(nodeId)
        // 清理该节点的所有订阅
        for ((topicName, topicManager) in topics) {
            let subscribers = topicManager.getSubscribers()
            for (sub in subscribers) {
                if (sub.nodeId == nodeId) {
                    topicManager.unsubscribe(sub.actorPath)
                }
            }
        }
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onNodeUnregistered(nodeId)
            case None => ()
        }
    }

    /**
     * 注册 Actor 到节点
     */
    public func put(actorPath: String): Unit {
        lock.writeMutex.lock()
        match (nodes.get(nodeId)) {
            case Some(registration) => registration.addActorPath(actorPath)
            case None => ()
        }
        lock.writeMutex.unlock()
    }

    /**
     * 订阅主题
     */
    public func subscribe(topic: String, actorPath: String, groupId: Option<String>): Unit {
        lock.writeMutex.lock()
        let topicManager = getOrCreateTopic(topic)
        topicManager.subscribe(actorPath, nodeId, groupId)
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onSubscribe(topic, actorPath, nodeId)
            case None => ()
        }
    }

    /**
     * 取消订阅
     */
    public func unsubscribe(topic: String, actorPath: String): Unit {
        lock.writeMutex.lock()
        match (topics.get(topic)) {
            case Some(topicManager) => topicManager.unsubscribe(actorPath)
            case None => ()
        }
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onUnsubscribe(topic, actorPath, nodeId)
            case None => ()
        }
    }

    /**
     * 发布消息到主题
     * 返回所有应该接收消息的订阅者路径
     */
    public func publish(topic: String, payload: String, sender: String): ArrayList<String> {
        lock.writeMutex.lock()
        messageCount += 1
        let receivers = ArrayList<String>()
        match (topics.get(topic)) {
            case Some(topicManager) =>
                let subscribers = topicManager.getSubscribers()
                for (sub in subscribers) {
                    receivers.add(sub.actorPath)
                }
            case None => ()
        }
        lock.writeMutex.unlock()

        match (eventHandler) {
            case Some(handler) => handler.onPublish(topic, payload, sender)
            case None => ()
        }

        receivers
    }

    /**
     * 发送消息到特定 Actor 路径
     * 返回匹配的节点和 Actor 路径
     */
    public func send(actorPath: String, payload: String, sender: String): Option<(String, String)> {
        lock.readMutex.lock()
        var result: Option<(String, String)> = None
        for ((nid, registration) in nodes) {
            if (registration.hasActorPath(actorPath)) {
                result = Some((nid, actorPath))
                break
            }
        }
        lock.readMutex.unlock()
        messageCount += 1
        result
    }

    /**
     * 广播消息到所有节点的所有订阅者
     */
    public func sendToAll(topic: String, payload: String, sender: String): ArrayList<String> {
        lock.readMutex.lock()
        let receivers = ArrayList<String>()
        match (topics.get(topic)) {
            case Some(topicManager) =>
                let subscribers = topicManager.getSubscribers()
                for (sub in subscribers) {
                    receivers.add(sub.actorPath)
                }
            case None => ()
        }
        lock.readMutex.unlock()
        messageCount += 1
        receivers
    }

    /**
     * 获取或创建主题管理器
     */
    private func getOrCreateTopic(topic: String): TopicManager {
        match (topics.get(topic)) {
            case Some(manager) => manager
            case None =>
                let manager = TopicManager(topic)
                topics.add(topic, manager)
                manager
        }
    }

    /**
     * 获取主题数量
     */
    public func topicCount(): Int64 {
        lock.readMutex.lock()
        let count = topics.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取所有主题名称
     */
    public func topicNames(): ArrayList<String> {
        lock.readMutex.lock()
        let names = ArrayList<String>()
        for ((name, _) in topics) {
            names.add(name)
        }
        lock.readMutex.unlock()
        names
    }

    /**
     * 获取节点数量
     */
    public func nodeCount(): Int64 {
        lock.readMutex.lock()
        let count = nodes.size
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取总订阅者数量
     */
    public func totalSubscribers(): Int64 {
        lock.readMutex.lock()
        var total: Int64 = 0
        for ((_, topicManager) in topics) {
            total += topicManager.subscriberCount()
        }
        lock.readMutex.unlock()
        total
    }

    /**
     * 获取消息计数
     */
    public func messageCount(): Int64 {
        lock.readMutex.lock()
        let count = messageCount
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取主题信息
     */
    public func getTopicInfo(topic: String): Option<TopicManager> {
        lock.readMutex.lock()
        let result = topics.get(topic)
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取所有主题快照
     */
    public func getTopicsSnapshot(): ArrayList<(String, Int64)> {
        lock.readMutex.lock()
        let result = ArrayList<(String, Int64)>()
        for ((name, topicManager) in topics) {
            result.add((name, topicManager.subscriberCount()))
        }
        lock.readMutex.unlock()
        result
    }

    /**
     * 检查主题是否存在
     */
    public func hasTopic(topic: String): Bool {
        lock.readMutex.lock()
        let result = topics.get(topic).isSome()
        lock.readMutex.unlock()
        result
    }

    /**
     * 移除主题
     */
    public func removeTopic(topic: String): Unit {
        lock.writeMutex.lock()
        topics.remove(topic)
        lock.writeMutex.unlock()
    }

    /**
     * 检查节点是否已注册
     */
    public func hasNode(nodeId: String): Bool {
        lock.readMutex.lock()
        let result = nodes.get(nodeId).isSome()
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取节点信息
     */
    public func getNode(nodeId: String): Option<NodeRegistration> {
        lock.readMutex.lock()
        let result = nodes.get(nodeId)
        lock.readMutex.unlock()
        result
    }

    /**
     * 获取所有节点 ID
     */
    public func getNodeIds(): ArrayList<String> {
        lock.readMutex.lock()
        let ids = ArrayList<String>()
        for ((id, _) in nodes) {
            ids.add(id)
        }
        lock.readMutex.unlock()
        ids
    }

    /**
     * 获取特定主题的订阅者数量
     */
    public func subscriberCountForTopic(topic: String): Int64 {
        lock.readMutex.lock()
        let count = match (topics.get(topic)) {
            case Some(manager) => manager.subscriberCount()
            case None => 0
        }
        lock.readMutex.unlock()
        count
    }
}

/**
 * 创建分布式发布订阅中介器
 */
public func createDistributedPubSubMediator(nodeId: String): DistributedPubSubMediator {
    DistributedPubSubMediator(nodeId)
}

/**
 * PubSub 配置
 */
public class PubSubConfig {
    public let maxTopics: Int64
    public let maxSubscribersPerTopic: Int64
    public let messageTtlMs: Int64
    public let enableGroupSubscriptions: Bool

    public init(maxTopics: Int64, maxSubscribersPerTopic: Int64, messageTtlMs: Int64, enableGroupSubscriptions: Bool) {
        this.maxTopics = maxTopics
        this.maxSubscribersPerTopic = maxSubscribersPerTopic
        this.messageTtlMs = messageTtlMs
        this.enableGroupSubscriptions = enableGroupSubscriptions
    }
}

/**
 * 创建默认 PubSub 配置
 */
public func createDefaultPubSubConfig(): PubSubConfig {
    PubSubConfig(1000, 10000, 30000, true)
}
