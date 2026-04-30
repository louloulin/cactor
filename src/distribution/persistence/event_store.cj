package cactor.distribution.persistence

import std.collection.*
import std.time.*
import std.sync.*
import std.fs.*
import std.io.*

// 事件接口
public interface Event {
    func getEventId(): String
    func getActorId(): String
    func getTimestamp(): Int64
    func getEventType(): String
    func getEventData(): String
    func toString(): String
}

// 基础事件实现
public class BasicEvent <: Event {
    private let eventId: String
    private let actorId: String
    private let timestamp: Int64
    private let eventType: String
    private let eventData: String
    
    public init(eventId: String, actorId: String, eventType: String, eventData: String) {
        this.eventId = eventId
        this.actorId = actorId
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.eventType = eventType
        this.eventData = eventData
    }
    
    public func getEventId(): String { eventId }
    public func getActorId(): String { actorId }
    public func getTimestamp(): Int64 { timestamp }
    public func getEventType(): String { eventType }
    public func getEventData(): String { eventData }
    
    public func toString(): String {
        "Event(${eventId}, ${actorId}, ${eventType}, ${timestamp})"
    }
}

// 事件存储接口
public interface EventStore {
    func saveEvent(event: Event): Unit
    func getEvents(actorId: String): Array<Event>
    func getEventsAfter(actorId: String, timestamp: Int64): Array<Event>
    func deleteEvents(actorId: String): Unit
    func close(): Unit
}

// 内存事件存储
public class MemoryEventStore <: EventStore {
    private let events: HashMap<String, ArrayList<Event>>
    private let mutex: Mutex
    
    public init() {
        this.events = HashMap<String, ArrayList<Event>>()
        this.mutex = Mutex()
    }
    
    public func saveEvent(event: Event): Unit {
        mutex.lock()
        try {
            let actorId = event.getActorId()
            match (events.get(actorId)) {
                case Some(eventList) => 
                    eventList.add(event)
                case None =>
                    let newList = ArrayList<Event>()
                    newList.add(event)
                    events.add(actorId, newList)
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func getEvents(actorId: String): Array<Event> {
        mutex.lock()
        try {
            match (events.get(actorId)) {
                case Some(eventList) =>
                    let result = ArrayList<Event>()
                    for (event in eventList) {
                        result.add(event)
                    }
                    result.toArray()
                case None =>
                    Array<Event>()
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func getEventsAfter(actorId: String, timestamp: Int64): Array<Event> {
        mutex.lock()
        try {
            match (events.get(actorId)) {
                case Some(eventList) =>
                    let result = ArrayList<Event>()
                    for (event in eventList) {
                        if (event.getTimestamp() > timestamp) {
                            result.add(event)
                        }
                    }
                    result.toArray()
                case None =>
                    Array<Event>()
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func deleteEvents(actorId: String): Unit {
        mutex.lock()
        try {
            events.remove(actorId)
        } finally {
            mutex.unlock()
        }
    }
    
    public func close(): Unit {
        // 内存存储无需关闭操作
    }
}

// 文件事件存储
public class FileEventStore <: EventStore {
    private let basePath: String
    private let mutex: Mutex
    
    public init(basePath: String) {
        this.basePath = basePath
        this.mutex = Mutex()
        // 确保目录存在
        try {
            Directory.create(basePath, recursive: true)
        } catch (e: Exception) {
            println("创建事件存储目录失败: ${e}")
        }
    }
    
    public func saveEvent(event: Event): Unit {
        mutex.lock()
        try {
            // 简化实现：只打印事件信息
            // 在实际实现中，这里会将事件写入文件
            println("保存事件到文件: ${event.toString()}")
        } finally {
            mutex.unlock()
        }
    }
    
    public func getEvents(actorId: String): Array<Event> {
        mutex.lock()
        try {
            // 简化实现：返回空数组
            // 在实际实现中，这里会从文件读取事件
            println("从文件读取事件: ${actorId}")
            Array<Event>()
        } finally {
            mutex.unlock()
        }
    }
    
    public func getEventsAfter(actorId: String, timestamp: Int64): Array<Event> {
        // 简化实现：返回空数组
        println("获取时间戳${timestamp}之后的事件: ${actorId}")
        Array<Event>()
    }
    
    public func deleteEvents(actorId: String): Unit {
        mutex.lock()
        try {
            // 简化实现：只打印删除信息
            println("删除事件文件: ${actorId}")
        } finally {
            mutex.unlock()
        }
    }
    
    public func close(): Unit {
        // 文件存储无需特殊关闭操作
    }
}

// 事件存储工厂
public class EventStoreFactory {
    public static func createMemoryStore(): EventStore {
        MemoryEventStore()
    }
    
    public static func createFileStore(basePath: String): EventStore {
        FileEventStore(basePath)
    }
}
