/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - File Watch 示例
 * 演示文件系统监控功能
 */
package cactor.examples.file_watch_demo

import std.collection.*
import std.time.*
import std.sync.*

// ============================================================================
// 文件监控事件类型
// ============================================================================

/**
 * 文件系统事件类型
 */
public enum FileEventType {
    | Created
    | Modified
    | Deleted
    | Renamed
    | PermissionChanged
}

/**
 * 文件系统事件
 */
public class FileEvent {
    public let eventType: FileEventType
    public let path: String
    public let oldPath: Option<String>
    public let timestamp: Int64

    public init(eventType: FileEventType, path: String) {
        this.eventType = eventType
        this.path = path
        this.oldPath = None
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public init(eventType: FileEventType, path: String, oldPath: String) {
        this.eventType = eventType
        this.path = path
        this.oldPath = Some(oldPath)
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func getOldPathOrDefault(): String {
        match (oldPath) {
            case Some(p) => p
            case None => "?"
        }
    }
}

/**
 * 文件事件处理器
 */
public interface FileEventHandler {
    func handle(event: FileEvent): Unit
}

/**
 * 简单文件事件处理器
 */
public class SimpleFileEventHandler <: FileEventHandler {
    private var events: ArrayList<FileEvent>

    public init() {
        this.events = ArrayList<FileEvent>()
    }

    public func handle(event: FileEvent): Unit {
        events.add(event)
        println("  [文件事件] ${event.path}")
    }

    public func getEvents(): ArrayList<FileEvent> {
        events
    }
}

// ============================================================================
// 文件监控器接口
// ============================================================================

/**
 * 文件监控器接口
 */
public interface FileWatcher {
    func start(): Unit
    func stop(): Unit
    func watch(path: String): Unit
    func unwatch(path: String): Unit
    func onEvent(handler: FileEventHandler): FileWatcher
    func isWatching(): Bool
}

/**
 * 模拟文件监控器
 * 在实际实现中会使用操作系统级文件监控 API
 */
public class SimulatedFileWatcher <: FileWatcher {
    private let watchPaths: ArrayList<String>
    private var isActive: Bool
    private var handlers: ArrayList<FileEventHandler>
    private let lock: Mutex

    public init() {
        this.watchPaths = ArrayList<String>()
        this.isActive = false
        this.handlers = ArrayList<FileEventHandler>()
        this.lock = Mutex()
    }

    public func start(): Unit {
        lock.lock()
        isActive = true
        lock.unlock()
        println("文件监控器已启动")
    }

    public func stop(): Unit {
        lock.lock()
        isActive = false
        lock.unlock()
        println("文件监控器已停止")
    }

    public func watch(path: String): Unit {
        lock.lock()
        try {
            if (!watchPaths.contains(path)) {
                watchPaths.add(path)
                println("开始监控路径: ${path}")
            }
        } finally {
            lock.unlock()
        }
    }

    public func unwatch(path: String): Unit {
        lock.lock()
        try {
            let remaining = ArrayList<String>()
            for (p in watchPaths) {
                if (p != path) {
                    remaining.add(p)
                }
            }
            watchPaths.clear()
            for (p in remaining) {
                watchPaths.add(p)
            }
            println("停止监控路径: ${path}")
        } finally {
            lock.unlock()
        }
    }

    public func onEvent(handler: FileEventHandler): FileWatcher {
        lock.lock()
        handlers.add(handler)
        lock.unlock()
        this
    }

    public func isWatching(): Bool {
        lock.lock()
        let result = isActive
        lock.unlock()
        result
    }

    /**
     * 模拟触发文件事件（用于演示）
     */
    public func simulateEvent(event: FileEvent): Unit {
        lock.lock()
        let snapshot = handlers
        lock.unlock()

        for (handler in snapshot) {
            handler.handle(event)
        }
    }

    public func getWatchedPaths(): ArrayList<String> {
        lock.lock()
        let result = ArrayList<String>()
        for (p in watchPaths) {
            result.add(p)
        }
        lock.unlock()
        result
    }
}

// ============================================================================
// 示例演示
// ============================================================================

/**
 * 演示基本文件监控
 */
public func demonstrateBasicWatching(): Unit {
    println("=== 基本文件监控演示 ===")

    let watcher = SimulatedFileWatcher()
    let handler = SimpleFileEventHandler()

    // 设置事件处理器
    watcher.onEvent(handler)

    // 启动监控
    watcher.start()

    // 添加监控路径
    watcher.watch("/var/log/app.log")
    watcher.watch("/etc/config.json")

    // 模拟文件事件
    watcher.simulateEvent(FileEvent(FileEventType.Created, "/var/log/app.log"))
    watcher.simulateEvent(FileEvent(FileEventType.Modified, "/etc/config.json"))

    println("收到事件数: ${handler.getEvents().size}")
    println()
}

/**
 * 演示多个监控路径
 */
public func demonstrateMultiplePaths(): Unit {
    println("=== 多路径监控演示 ===")

    let watcher = SimulatedFileWatcher()
    let handler = SimpleFileEventHandler()

    watcher.onEvent(handler)
    watcher.start()

    // 监控多个路径
    let paths = ArrayList<String>()
    paths.add("/data/file1.txt")
    paths.add("/data/file2.txt")
    paths.add("/data/file3.txt")

    for (path in paths) {
        watcher.watch(path)
    }

    println("监控路径数: ${watcher.getWatchedPaths().size}")

    // 模拟多个事件
    watcher.simulateEvent(FileEvent(FileEventType.Modified, "/data/file1.txt"))
    watcher.simulateEvent(FileEvent(FileEventType.Modified, "/data/file2.txt"))
    watcher.simulateEvent(FileEvent(FileEventType.Deleted, "/data/file3.txt"))

    println("总事件数: ${handler.getEvents().size}")
    println()
}

/**
 * 演示添加/移除监控路径
 */
public func demonstrateDynamicWatching(): Unit {
    println("=== 动态添加/移除监控演示 ===")

    let watcher = SimulatedFileWatcher()
    let handler = SimpleFileEventHandler()

    watcher.onEvent(handler)
    watcher.start()

    // 开始监控
    watcher.watch("/tmp/file1.txt")
    println("初始监控路径: ${watcher.getWatchedPaths().size}")

    // 添加新路径
    watcher.watch("/tmp/file2.txt")
    println("添加后监控路径: ${watcher.getWatchedPaths().size}")

    // 移除路径
    watcher.unwatch("/tmp/file1.txt")
    println("移除后监控路径: ${watcher.getWatchedPaths().size}")

    println()
}

/**
 * 演示事件类型
 */
public func demonstrateEventTypes(): Unit {
    println("=== 文件事件类型演示 ===")

    let watcher = SimulatedFileWatcher()
    let handler = SimpleFileEventHandler()

    watcher.onEvent(handler)
    watcher.start()

    let paths = ArrayList<String>()
    paths.add("/app/log.txt")
    paths.add("/app/config.json")
    paths.add("/app/data.db")
    paths.add("/app/newname.txt")

    // 模拟各种类型的事件
    watcher.simulateEvent(FileEvent(FileEventType.Created, paths[0]))
    watcher.simulateEvent(FileEvent(FileEventType.Modified, paths[0]))
    watcher.simulateEvent(FileEvent(FileEventType.Modified, paths[1]))
    watcher.simulateEvent(FileEvent(FileEventType.PermissionChanged, paths[1]))
    watcher.simulateEvent(FileEvent(FileEventType.Deleted, paths[2]))
    watcher.simulateEvent(FileEvent(FileEventType.Renamed, paths[3], "/app/oldname.txt"))

    println("事件统计:")
    println("  总事件数: ${handler.getEvents().size}")

    // 打印所有事件
    println("  所有事件:")
    for (e in handler.getEvents()) {
        println("    ${e.path}")
    }
    println()
}

/**
 * 演示停止/恢复监控
 */
public func demonstrateStartStop(): Unit {
    println("=== 启动/停止监控演示 ===")

    let watcher = SimulatedFileWatcher()
    let handler = SimpleFileEventHandler()

    watcher.onEvent(handler)
    watcher.watch("/app/file.txt")

    println("初始状态: ${watcher.isWatching()}")

    watcher.start()
    println("启动后: ${watcher.isWatching()}")

    // 模拟事件
    watcher.simulateEvent(FileEvent(FileEventType.Modified, "/app/file.txt"))

    watcher.stop()
    println("停止后: ${watcher.isWatching()}")

    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor File Watch 文件监控演示")
    println("========================================")
    println()

    demonstrateBasicWatching()
    demonstrateMultiplePaths()
    demonstrateDynamicWatching()
    demonstrateEventTypes()
    demonstrateStartStop()

    println("========================================")
    println("   File Watch 演示完成!")
    println("========================================")
}
