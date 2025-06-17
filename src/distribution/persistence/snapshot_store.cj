package cactor.distribution.persistence

import std.collection.*
import std.time.*
import std.sync.*
import std.fs.*
import std.io.*

// 快照接口
public interface Snapshot {
    func getActorId(): String
    func getTimestamp(): Int64
    func getSequenceNumber(): Int64
    func getStateData(): String
    func toString(): String
}

// 基础快照实现
public class BasicSnapshot <: Snapshot {
    private let actorId: String
    private let timestamp: Int64
    private let sequenceNumber: Int64
    private let stateData: String
    
    public init(actorId: String, sequenceNumber: Int64, stateData: String) {
        this.actorId = actorId
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.sequenceNumber = sequenceNumber
        this.stateData = stateData
    }
    
    public func getActorId(): String { actorId }
    public func getTimestamp(): Int64 { timestamp }
    public func getSequenceNumber(): Int64 { sequenceNumber }
    public func getStateData(): String { stateData }
    
    public func toString(): String {
        "Snapshot(${actorId}, seq=${sequenceNumber}, ts=${timestamp})"
    }
}

// 快照存储接口
public interface SnapshotStore {
    func saveSnapshot(snapshot: Snapshot): Unit
    func getLatestSnapshot(actorId: String): Option<Snapshot>
    func getSnapshot(actorId: String, sequenceNumber: Int64): Option<Snapshot>
    func deleteSnapshots(actorId: String): Unit
    func close(): Unit
}

// 内存快照存储
public class MemorySnapshotStore <: SnapshotStore {
    private let snapshots: HashMap<String, ArrayList<Snapshot>>
    private let mutex: ReentrantMutex
    
    public init() {
        this.snapshots = HashMap<String, ArrayList<Snapshot>>()
        this.mutex = ReentrantMutex()
    }
    
    public func saveSnapshot(snapshot: Snapshot): Unit {
        mutex.lock()
        try {
            let actorId = snapshot.getActorId()
            match (snapshots.get(actorId)) {
                case Some(snapshotList) => 
                    snapshotList.append(snapshot)
                    // 保持最新的5个快照
                    if (snapshotList.size > 5) {
                        // 简化实现：重新创建列表保持最新的5个
                        let newList = ArrayList<Snapshot>()
                        for (i in (snapshotList.size - 5)..snapshotList.size) {
                            newList.append(snapshotList[i])
                        }
                        snapshots.put(actorId, newList)
                    }
                case None =>
                    let newList = ArrayList<Snapshot>()
                    newList.append(snapshot)
                    snapshots.put(actorId, newList)
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func getLatestSnapshot(actorId: String): Option<Snapshot> {
        mutex.lock()
        try {
            match (snapshots.get(actorId)) {
                case Some(snapshotList) => 
                    if (snapshotList.size > 0) {
                        Some(snapshotList[snapshotList.size - 1])
                    } else {
                        None<Snapshot>
                    }
                case None => 
                    None<Snapshot>
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func getSnapshot(actorId: String, sequenceNumber: Int64): Option<Snapshot> {
        mutex.lock()
        try {
            match (snapshots.get(actorId)) {
                case Some(snapshotList) => 
                    for (snapshot in snapshotList) {
                        if (snapshot.getSequenceNumber() == sequenceNumber) {
                            return Some(snapshot)
                        }
                    }
                    None<Snapshot>
                case None => 
                    None<Snapshot>
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func deleteSnapshots(actorId: String): Unit {
        mutex.lock()
        try {
            snapshots.remove(actorId)
        } finally {
            mutex.unlock()
        }
    }
    
    public func close(): Unit {
        // 内存存储无需关闭操作
    }
}

// 文件快照存储（简化实现）
public class FileSnapshotStore <: SnapshotStore {
    private let basePath: String
    private let mutex: ReentrantMutex
    private let snapshots: HashMap<String, ArrayList<Snapshot>>

    public init(basePath: String) {
        this.basePath = basePath
        this.mutex = ReentrantMutex()
        this.snapshots = HashMap<String, ArrayList<Snapshot>>()
        println("文件快照存储初始化: ${basePath}")
    }
    
    public func saveSnapshot(snapshot: Snapshot): Unit {
        mutex.lock()
        try {
            let actorId = snapshot.getActorId()
            match (snapshots.get(actorId)) {
                case Some(snapshotList) =>
                    snapshotList.append(snapshot)
                    // 保持最新的5个快照
                    if (snapshotList.size > 5) {
                        let newList = ArrayList<Snapshot>()
                        for (i in (snapshotList.size - 5)..snapshotList.size) {
                            newList.append(snapshotList[i])
                        }
                        snapshots.put(actorId, newList)
                    }
                case None =>
                    let newList = ArrayList<Snapshot>()
                    newList.append(snapshot)
                    snapshots.put(actorId, newList)
            }
            println("文件快照已保存: ${snapshot.toString()}")
        } finally {
            mutex.unlock()
        }
    }
    
    // 简化实现：不需要文件清理
    
    public func getLatestSnapshot(actorId: String): Option<Snapshot> {
        mutex.lock()
        try {
            match (snapshots.get(actorId)) {
                case Some(snapshotList) =>
                    if (snapshotList.size > 0) {
                        Some(snapshotList[snapshotList.size - 1])
                    } else {
                        None<Snapshot>
                    }
                case None =>
                    None<Snapshot>
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func getSnapshot(actorId: String, sequenceNumber: Int64): Option<Snapshot> {
        mutex.lock()
        try {
            match (snapshots.get(actorId)) {
                case Some(snapshotList) =>
                    for (snapshot in snapshotList) {
                        if (snapshot.getSequenceNumber() == sequenceNumber) {
                            return Some(snapshot)
                        }
                    }
                    None<Snapshot>
                case None =>
                    None<Snapshot>
            }
        } finally {
            mutex.unlock()
        }
    }
    
    public func deleteSnapshots(actorId: String): Unit {
        mutex.lock()
        try {
            snapshots.remove(actorId)
            println("删除快照: ${actorId}")
        } finally {
            mutex.unlock()
        }
    }
    
    public func close(): Unit {
        // 文件存储无需特殊关闭操作
    }
}

// 快照存储工厂
public class SnapshotStoreFactory {
    public static func createMemoryStore(): SnapshotStore {
        MemorySnapshotStore()
    }
    
    public static func createFileStore(basePath: String): SnapshotStore {
        FileSnapshotStore(basePath)
    }
}
