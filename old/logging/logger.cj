/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 日志系统实现
 */
package cactor.logging

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 日志级别
 */
public enum LogLevel {
    | TRACE
    | DEBUG
    | INFO
    | WARN
    | ERROR
    | FATAL
    
    public func toInt(): Int64 {
        match (this) {
            case TRACE => 0
            case DEBUG => 1
            case INFO => 2
            case WARN => 3
            case ERROR => 4
            case FATAL => 5
        }
    }
    
    public func toString(): String {
        match (this) {
            case TRACE => "TRACE"
            case DEBUG => "DEBUG"
            case INFO => "INFO"
            case WARN => "WARN"
            case ERROR => "ERROR"
            case FATAL => "FATAL"
        }
    }
    
    public func shouldLog(currentLevel: LogLevel): Bool {
        this.toInt() >= currentLevel.toInt()
    }
}

/**
 * 日志记录
 */
public struct LogRecord {
    public let timestamp: DateTime
    public let level: LogLevel
    public let logger: String
    public let message: String
    public let thread: String
    
    public init(level: LogLevel, logger: String, message: String, thread: String) {
        this.timestamp = DateTime.now()
        this.level = level
        this.logger = logger
        this.message = message
        this.thread = thread
    }
    
    public func toString(): String {
        let timeStr = formatTimestamp(timestamp)
        "${timeStr} [${thread}] ${level.toString()} ${logger} - ${message}"
    }
    
    private func formatTimestamp(dt: DateTime): String {
        // 简化的时间格式化
        "2024-12-12 ${dt.toUnixTimeStamp().toMilliseconds() % 86400000 / 3600000}:${(dt.toUnixTimeStamp().toMilliseconds() % 3600000) / 60000}:${(dt.toUnixTimeStamp().toMilliseconds() % 60000) / 1000}"
    }
}

/**
 * 日志输出器接口
 */
public interface LogAppender {
    func append(record: LogRecord): Unit
    func flush(): Unit
    func close(): Unit
}

/**
 * 控制台日志输出器
 */
public class ConsoleAppender <: LogAppender {
    private let mutex: ReentrantMutex
    
    public init() {
        this.mutex = ReentrantMutex()
    }
    
    public func append(record: LogRecord): Unit {
        mutex.lock()
        println(record.toString())
        mutex.unlock()
    }
    
    public func flush(): Unit {
        // 控制台输出无需刷新
    }
    
    public func close(): Unit {
        // 控制台输出无需关闭
    }
}

/**
 * 文件日志输出器
 */
public class FileAppender <: LogAppender {
    private let filename: String
    private let mutex: ReentrantMutex
    private let buffer: ArrayList<String>
    private let maxBufferSize: Int64
    
    public init(filename: String, maxBufferSize: Int64) {
        this.filename = filename
        this.mutex = ReentrantMutex()
        this.buffer = ArrayList<String>()
        this.maxBufferSize = maxBufferSize
    }
    
    public func append(record: LogRecord): Unit {
        mutex.lock()
        buffer.append(record.toString())
        
        if (buffer.size >= maxBufferSize) {
            flushBuffer()
        }
        mutex.unlock()
    }
    
    public func flush(): Unit {
        mutex.lock()
        flushBuffer()
        mutex.unlock()
    }
    
    private func flushBuffer(): Unit {
        // 简化的文件写入实现
        println("写入日志文件 ${filename}:")
        for (line in buffer) {
            println("  ${line}")
        }
        buffer.clear()
    }
    
    public func close(): Unit {
        flush()
    }
}

/**
 * 异步日志输出器
 */
public class AsyncAppender <: LogAppender {
    private let targetAppender: LogAppender
    private let queue: ArrayList<LogRecord>
    private let mutex: ReentrantMutex
    private let isRunning: AtomicBool
    private let maxQueueSize: Int64
    
    public init(targetAppender: LogAppender, maxQueueSize: Int64) {
        this.targetAppender = targetAppender
        this.queue = ArrayList<LogRecord>()
        this.mutex = ReentrantMutex()
        this.isRunning = AtomicBool(true)
        this.maxQueueSize = maxQueueSize
        
        // 启动后台处理线程
        startBackgroundThread()
    }
    
    public func append(record: LogRecord): Unit {
        mutex.lock()
        if (queue.size < maxQueueSize) {
            queue.append(record)
        } else {
            // 队列满时丢弃最旧的记录
            // 简化实现：清空队列重新添加
            let newQueue = ArrayList<LogRecord>()
            for (i in 1..queue.size) {
                newQueue.append(queue[i])
            }
            queue.clear()
            for (record in newQueue) {
                queue.append(record)
            }
            queue.append(record)
        }
        mutex.unlock()
    }
    
    private func startBackgroundThread(): Unit {
        spawn {
            while (isRunning.load()) {
                processQueue()
                
                // 简化的等待实现
                let startTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                while (DateTime.now().toUnixTimeStamp().toMilliseconds() - startTime < 100) {
                    // 等待100毫秒
                }
            }
        }
    }
    
    private func processQueue(): Unit {
        mutex.lock()
        let recordsToProcess = ArrayList<LogRecord>()
        for (record in queue) {
            recordsToProcess.append(record)
        }
        queue.clear()
        mutex.unlock()
        
        // 处理记录
        for (record in recordsToProcess) {
            targetAppender.append(record)
        }
    }
    
    public func flush(): Unit {
        processQueue()
        targetAppender.flush()
    }
    
    public func close(): Unit {
        isRunning.store(false)
        flush()
        targetAppender.close()
    }
}

/**
 * 日志器
 */
public class Logger {
    private let name: String
    private let level: LogLevel
    private let appenders: ArrayList<LogAppender>
    private let mutex: ReentrantMutex
    
    public init(name: String, level: LogLevel) {
        this.name = name
        this.level = level
        this.appenders = ArrayList<LogAppender>()
        this.mutex = ReentrantMutex()
    }
    
    public func addAppender(appender: LogAppender): Unit {
        mutex.lock()
        appenders.append(appender)
        mutex.unlock()
    }
    
    public func removeAppender(appender: LogAppender): Unit {
        mutex.lock()
        // 简化的移除实现：清空所有appender
        appenders.clear()
        mutex.unlock()
        println("移除日志输出器")
    }
    
    public func log(level: LogLevel, message: String): Unit {
        if (level.shouldLog(this.level)) {
            let record = LogRecord(level, name, message, getCurrentThreadName())
            
            mutex.lock()
            for (appender in appenders) {
                try {
                    appender.append(record)
                } catch (e: Exception) {
                    println("日志输出器异常: ${e.message}")
                }
            }
            mutex.unlock()
        }
    }
    
    public func trace(message: String): Unit {
        log(LogLevel.TRACE, message)
    }
    
    public func debug(message: String): Unit {
        log(LogLevel.DEBUG, message)
    }
    
    public func info(message: String): Unit {
        log(LogLevel.INFO, message)
    }
    
    public func warn(message: String): Unit {
        log(LogLevel.WARN, message)
    }
    
    public func error(message: String): Unit {
        log(LogLevel.ERROR, message)
    }
    
    public func fatal(message: String): Unit {
        log(LogLevel.FATAL, message)
    }
    
    private func getCurrentThreadName(): String {
        // 简化的线程名获取
        "Thread-${DateTime.now().toUnixTimeStamp().toMilliseconds() % 1000}"
    }
    
    public func flush(): Unit {
        mutex.lock()
        for (appender in appenders) {
            appender.flush()
        }
        mutex.unlock()
    }
    
    public func close(): Unit {
        mutex.lock()
        for (appender in appenders) {
            appender.close()
        }
        mutex.unlock()
    }
}

/**
 * 日志工厂
 */
public class LoggerFactory {
    private static let loggers: HashMap<String, Logger> = HashMap<String, Logger>()
    private static let mutex: ReentrantMutex = ReentrantMutex()
    private static var defaultLevel: LogLevel = LogLevel.INFO
    
    public static func getLogger(name: String): Logger {
        mutex.lock()
        match (loggers.get(name)) {
            case Some(logger) => 
                mutex.unlock()
                logger
            case None => 
                let logger = Logger(name, defaultLevel)
                
                // 添加默认的控制台输出器
                logger.addAppender(ConsoleAppender())
                
                loggers[name] = logger
                mutex.unlock()
                logger
        }
    }
    
    public static func setDefaultLevel(level: LogLevel): Unit {
        mutex.lock()
        defaultLevel = level
        mutex.unlock()
    }
    
    public static func configureLogger(name: String, level: LogLevel, appenders: Array<LogAppender>): Unit {
        let logger = getLogger(name)
        
        // 清除现有输出器
        logger.close()
        
        // 添加新的输出器
        for (appender in appenders) {
            logger.addAppender(appender)
        }
    }
    
    public static func shutdown(): Unit {
        mutex.lock()
        for ((_, logger) in loggers) {
            logger.close()
        }
        loggers.clear()
        mutex.unlock()
    }
}
