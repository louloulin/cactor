/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Event Bus 事件总线
 * 对标 Akka EventBus
 * 提供发布-订阅模式的事件分发机制
 */
package cactor.patterns.eventbus

import std.collection.*
import std.sync.*

/**
 * 事件分类标签
 * 用于事件分类和订阅过滤
 */
public interface EventClassifier {
    func classify(): String
}

/**
 * 订阅者标识
 */
public class SubscriberId {
    public let id: String

    public init(id: String) {
        this.id = id
    }

    public func equals(other: SubscriberId): Bool {
        this.id == other.id
    }
}

/**
 * 事件订阅者接口
 */
public interface Subscriber {
    /**
     * 处理接收到的事件
     */
    func notify(event: Event): Unit

    /**
     * 获取订阅者 ID
     */
    func subscriberId(): SubscriberId
}

/**
 * 简单订阅者适配器
 */
public class SimpleSubscriber <: Subscriber {
    private let sid: SubscriberId
    private let handler: (Event) -> Unit

    public init(id: String, handler: (Event) -> Unit) {
        this.sid = SubscriberId(id)
        this.handler = handler
    }

    public func notify(event: Event): Unit {
        handler(event)
    }

    public func subscriberId(): SubscriberId {
        sid
    }
}

/**
 * 事件封装
 */
public class Event {
    public let data: Any
    public let timestamp: Int64
    public let source: Option<String>

    public init(data: Any) {
        this.data = data
        this.timestamp = 0  // DateTime.now().toUnixTimeStamp()
        this.source = None
    }

    public init(data: Any, source: String) {
        this.data = data
        this.timestamp = 0
        this.source = Some(source)
    }
}

/**
 * 事件总线接口
 * 对标 Akka EventBus
 */
public interface EventBus {
    /**
     * 发布事件
     */
    func publish(event: Event): Unit

    /**
     * 订阅事件分类
     */
    func subscribe(subscriber: Subscriber, classifier: String): Bool

    /**
     * 取消订阅
     */
    func unsubscribe(subscriber: Subscriber, classifier: String): Bool

    /**
     * 取消订阅者的所有订阅
     */
    func unsubscribeAll(subscriber: Subscriber): Unit
}

/**
 * 分类器类型别名
 */
public type Classifier = String

/**
 * 事件映射表
 */
public type SubscriberMap = HashMap<Classifier, ArrayList<Subscriber>>

/**
 * 简单事件总线实现
 * 基于分类的事件发布-订阅
 */
public class SubclassificationBasedEventBus <: EventBus {
    private let subscriberMap: SubscriberMap
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.subscriberMap = HashMap<Classifier, ArrayList<Subscriber>>()
        this.lock = ReentrantReadWriteMutex()
    }

    public func publish(event: Event): Unit {
        lock.readMutex.lock()
        let allClassifiers = getAllClassifiers()
        lock.readMutex.unlock()

        for (classifier in allClassifiers) {
            deliverToSubscribers(event, classifier)
        }
    }

    public func publishToClassifier(event: Event, classifier: String): Unit {
        deliverToSubscribers(event, classifier)
    }

    public func subscribe(subscriber: Subscriber, classifier: String): Bool {
        lock.writeMutex.lock()
        defer { lock.writeMutex.unlock() }

        match (subscriberMap.get(classifier)) {
            case Some(list) =>
                // 检查是否已存在
                for (s in list) {
                    if (s.subscriberId().equals(subscriber.subscriberId())) {
                        return false
                    }
                }
                list.add(subscriber)
                true
            case None =>
                let newList = ArrayList<Subscriber>()
                newList.add(subscriber)
                subscriberMap.add(classifier, newList)
                true
        }
    }

    public func unsubscribe(subscriber: Subscriber, classifier: String): Bool {
        lock.writeMutex.lock()
        defer { lock.writeMutex.unlock() }

        match (subscriberMap.get(classifier)) {
            case Some(list) =>
                let sid = subscriber.subscriberId()
                let result = list.size
                let remaining = ArrayList<Subscriber>()
                for (s in list) {
                    if (!s.subscriberId().equals(sid)) {
                        remaining.add(s)
                    }
                }
                subscriberMap.remove(classifier)
                if (remaining.size > 0) {
                    subscriberMap.add(classifier, remaining)
                }
                list.size != remaining.size
            case None =>
                false
        }
    }

    public func unsubscribeAll(subscriber: Subscriber): Unit {
        lock.writeMutex.lock()
        defer { lock.writeMutex.unlock() }

        let sid = subscriber.subscriberId()
        let newMap = HashMap<Classifier, ArrayList<Subscriber>>()

        for ((classifier, list) in subscriberMap) {
            let remaining = ArrayList<Subscriber>()
            for (s in list) {
                if (!s.subscriberId().equals(sid)) {
                    remaining.add(s)
                }
            }
            if (remaining.size > 0) {
                newMap.add(classifier, remaining)
            }
        }
        subscriberMap.clear()
        for ((k, v) in newMap) {
            subscriberMap.add(k, v)
        }
    }

    /**
     * 获取所有分类器
     */
    private func getAllClassifiers(): ArrayList<Classifier> {
        let result = ArrayList<Classifier>()
        for ((classifier, _) in subscriberMap) {
            result.add(classifier)
        }
        result
    }

    /**
     * 向订阅者发送事件
     */
    private func deliverToSubscribers(event: Event, classifier: String): Unit {
        lock.readMutex.lock()
        let subscribers = match (subscriberMap.get(classifier)) {
            case Some(list) => list
            case None =>
                lock.readMutex.unlock()
                return
        }

        // 复制订阅者列表以避免在通知时修改
        let snapshot = ArrayList<Subscriber>()
        for (s in subscribers) {
            snapshot.add(s)
        }
        lock.readMutex.unlock()

        for (subscriber in snapshot) {
            subscriber.notify(event)
        }
    }

    /**
     * 获取订阅者数量
     */
    public func getSubscriberCount(classifier: String): Int64 {
        lock.readMutex.lock()
        let count = match (subscriberMap.get(classifier)) {
            case Some(list) => list.size
            case None => 0
        }
        lock.readMutex.unlock()
        count
    }

    /**
     * 获取分类器列表
     */
    public func getClassifiers(): ArrayList<String> {
        lock.readMutex.lock()
        let result = ArrayList<String>()
        for ((classifier, _) in subscriberMap) {
            result.add(classifier)
        }
        lock.readMutex.unlock()
        result
    }
}

/**
 * 集群事件类型
 */
public enum ClusterEventType {
    | MemberJoined
    | MemberUp
    | MemberLeft
    | MemberRemoved
    | MemberUnreachable
    | MemberReachable
    | LeaderChanged
    | RoleMemberChanged
    | DataCenterChanged
}

/**
 * 集群事件
 */
public class ClusterEvent <: EventClassifier {
    public let eventType: ClusterEventType
    public let nodeId: String
    public let timestamp: Int64
    public let metadata: HashMap<String, String>

    public init(eventType: ClusterEventType, nodeId: String) {
        this.eventType = eventType
        this.nodeId = nodeId
        this.timestamp = 0
        this.metadata = HashMap<String, String>()
    }

    public func classify(): String {
        match (eventType) {
            case MemberJoined => "cluster.member.joined"
            case MemberUp => "cluster.member.up"
            case MemberLeft => "cluster.member.left"
            case MemberRemoved => "cluster.member.removed"
            case MemberUnreachable => "cluster.member.unreachable"
            case MemberReachable => "cluster.member.reachable"
            case LeaderChanged => "cluster.leader.changed"
            case RoleMemberChanged => "cluster.role.changed"
            case DataCenterChanged => "cluster.datacenter.changed"
        }
    }

    public func toString(): String {
        "ClusterEvent(${eventType}, node=${nodeId})"
    }
}

/**
 * 集群事件总线
 * 专门用于集群事件的分发
 */
public class ClusterEventBus <: SubclassificationBasedEventBus {
    /**
     * 订阅成员变更事件
     */
    public func subscribeToMemberChanges(subscriber: Subscriber): Bool {
        let result1 = subscribe(subscriber, "cluster.member.joined")
        let result2 = subscribe(subscriber, "cluster.member.up")
        let result3 = subscribe(subscriber, "cluster.member.left")
        let result4 = subscribe(subscriber, "cluster.member.removed")
        result1 || result2 || result3 || result4
    }

    /**
     * 订阅可达性变更事件
     */
    public func subscribeToReachabilityChanges(subscriber: Subscriber): Bool {
        let result1 = subscribe(subscriber, "cluster.member.unreachable")
        let result2 = subscribe(subscriber, "cluster.member.reachable")
        result1 || result2
    }

    /**
     * 订阅领导者变更事件
     */
    public func subscribeToLeaderChanges(subscriber: Subscriber): Bool {
        subscribe(subscriber, "cluster.leader.changed")
    }

    /**
     * 发布成员加入事件
     */
    public func publishMemberJoined(nodeId: String): Unit {
        let event = ClusterEvent(ClusterEventType.MemberJoined, nodeId)
        publishToClassifier(Event(event), event.classify())
    }

    /**
     * 发布成员上线事件
     */
    public func publishMemberUp(nodeId: String): Unit {
        let event = ClusterEvent(ClusterEventType.MemberUp, nodeId)
        publishToClassifier(Event(event), event.classify())
    }

    /**
     * 发布成员不可达事件
     */
    public func publishMemberUnreachable(nodeId: String): Unit {
        let event = ClusterEvent(ClusterEventType.MemberUnreachable, nodeId)
        publishToClassifier(Event(event), event.classify())
    }

    /**
     * 发布领导者变更事件
     */
    public func publishLeaderChanged(nodeId: String): Unit {
        let event = ClusterEvent(ClusterEventType.LeaderChanged, nodeId)
        publishToClassifier(Event(event), event.classify())
    }
}

/**
 * 事件总线工厂
 */
public class EventBusFactory {
    /**
     * 创建简单事件总线
     */
    public static func createEventBus(): SubclassificationBasedEventBus {
        SubclassificationBasedEventBus()
    }

    /**
     * 创建集群事件总线
     */
    public static func createClusterEventBus(): ClusterEventBus {
        ClusterEventBus()
    }
}
