/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor系统日志集成
 */
package cactor.integration.logging

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.{Message, StringMessage}
import cactor.core.actor.{Actor, ActorRef, ActorPath}

/**
 * Actor日志上下文
 */
public struct ActorLogContext {
    public let actorPath: String
    public let actorType: String
    public let messageType: String
    public let timestamp: DateTime
    
    public init(actorPath: String, actorType: String, messageType: String) {
        this.actorPath = actorPath
        this.actorType = actorType
        this.messageType = messageType
        this.timestamp = DateTime.now()
    }
    
    public func toString(): String {
        "ActorLogContext(path=${actorPath}, type=${actorType}, msg=${messageType})"
    }
}

/**
 * Actor日志事件类型
 */
public enum ActorLogEvent {
    | ActorCreated(String, String)
    | ActorStarted(String)
    | ActorStopped(String)
    | ActorRestarted(String, String)
    | MessageReceived(String, String)
    | MessageSent(String, String, String)
    | MessageProcessed(String, String, Int64)
    | ActorFailed(String, String)
    | SupervisionAction(String, String, String)
    
    public func toString(): String {
        match (this) {
            case ActorCreated(path, actorType) => "Actor创建: ${path} (${actorType})"
            case ActorStarted(path) => "Actor启动: ${path}"
            case ActorStopped(path) => "Actor停止: ${path}"
            case ActorRestarted(path, reason) => "Actor重启: ${path}, 原因: ${reason}"
            case MessageReceived(path, msgType) => "消息接收: ${path} <- ${msgType}"
            case MessageSent(from, to, msgType) => "消息发送: ${from} -> ${to} (${msgType})"
            case MessageProcessed(path, msgType, duration) => "消息处理: ${path} 处理 ${msgType}, 耗时: ${duration}ms"
            case ActorFailed(path, error) => "Actor失败: ${path}, 错误: ${error}"
            case SupervisionAction(supervisor, child, action) => "监督动作: ${supervisor} 对 ${child} 执行 ${action}"
        }
    }
    
    public func getLogLevel(): LogLevel {
        match (this) {
            case ActorCreated(_, _) => LogLevel.DEBUG
            case ActorStarted(_) => LogLevel.INFO
            case ActorStopped(_) => LogLevel.INFO
            case ActorRestarted(_, _) => LogLevel.WARN
            case MessageReceived(_, _) => LogLevel.TRACE
            case MessageSent(_, _, _) => LogLevel.TRACE
            case MessageProcessed(_, _, _) => LogLevel.DEBUG
            case ActorFailed(_, _) => LogLevel.ERROR
            case SupervisionAction(_, _, _) => LogLevel.WARN
        }
    }
}

/**
 * Actor日志记录器
 */
public class ActorLogger {
    private let logger: Logger
    private let actorPath: String
    private let enabledEvents: HashMap<String, Bool>
    
    public init(actorPath: String, loggerName: String) {
        this.actorPath = actorPath
        this.logger = LoggerFactory.getLogger(loggerName)
        this.enabledEvents = HashMap<String, Bool>()
        
        // 默认启用的事件
        enabledEvents["ActorCreated"] = true
        enabledEvents["ActorStarted"] = true
        enabledEvents["ActorStopped"] = true
        enabledEvents["ActorRestarted"] = true
        enabledEvents["ActorFailed"] = true
        enabledEvents["SupervisionAction"] = true
        enabledEvents["MessageReceived"] = false  // 默认关闭，避免日志过多
        enabledEvents["MessageSent"] = false
        enabledEvents["MessageProcessed"] = true
    }
    
    public func logEvent(event: ActorLogEvent): Unit {
        let eventType = getEventType(event)
        match (enabledEvents.get(eventType)) {
            case Some(enabled) => 
                if (enabled) {
                    let level = event.getLogLevel()
                    let message = event.toString()
                    logger.log(level, message)
                }
            case None => 
                // 未配置的事件默认记录
                logger.log(event.getLogLevel(), event.toString())
        }
    }
    
    private func getEventType(event: ActorLogEvent): String {
        match (event) {
            case ActorCreated(_, _) => "ActorCreated"
            case ActorStarted(_) => "ActorStarted"
            case ActorStopped(_) => "ActorStopped"
            case ActorRestarted(_, _) => "ActorRestarted"
            case MessageReceived(_, _) => "MessageReceived"
            case MessageSent(_, _, _) => "MessageSent"
            case MessageProcessed(_, _, _) => "MessageProcessed"
            case ActorFailed(_, _) => "ActorFailed"
            case SupervisionAction(_, _, _) => "SupervisionAction"
        }
    }
    
    public func enableEvent(eventType: String): Unit {
        enabledEvents[eventType] = true
    }
    
    public func disableEvent(eventType: String): Unit {
        enabledEvents[eventType] = false
    }
    
    public func trace(message: String): Unit {
        logger.trace("[${actorPath}] ${message}")
    }
    
    public func debug(message: String): Unit {
        logger.debug("[${actorPath}] ${message}")
    }
    
    public func info(message: String): Unit {
        logger.info("[${actorPath}] ${message}")
    }
    
    public func warn(message: String): Unit {
        logger.warn("[${actorPath}] ${message}")
    }
    
    public func error(message: String): Unit {
        logger.error("[${actorPath}] ${message}")
    }
    
    public func fatal(message: String): Unit {
        logger.fatal("[${actorPath}] ${message}")
    }
}

/**
 * 可记录日志的Actor基类
 */
public interface LoggableActor <: Actor {
    func getActorLogger(): ActorLogger
    
    func logMessageReceived(message: Message): Unit {
        let logger = getActorLogger()
        let msgType = getMessageType(message)
        logger.logEvent(ActorLogEvent.MessageReceived(getActorPath(), msgType))
    }
    
    func logMessageProcessed(message: Message, processingTime: Int64): Unit {
        let logger = getActorLogger()
        let msgType = getMessageType(message)
        logger.logEvent(ActorLogEvent.MessageProcessed(getActorPath(), msgType, processingTime))
    }
    
    func logActorStarted(): Unit {
        let logger = getActorLogger()
        logger.logEvent(ActorLogEvent.ActorStarted(getActorPath()))
    }
    
    func logActorStopped(): Unit {
        let logger = getActorLogger()
        logger.logEvent(ActorLogEvent.ActorStopped(getActorPath()))
    }
    
    func logActorFailed(error: String): Unit {
        let logger = getActorLogger()
        logger.logEvent(ActorLogEvent.ActorFailed(getActorPath(), error))
    }
    
    func getMessageType(message: Message): String {
        match (message) {
            case _: StringMessage => "StringMessage"
            case _ => "UnknownMessage"
        }
    }

    func getActorPath(): String {
        "actor-path"  // 简化实现
    }
}

/**
 * 系统日志管理器
 */
public class SystemLogManager {
    private let systemLogger: Logger
    private let actorLoggers: HashMap<String, ActorLogger>
    private let mutex: Mutex
    private let metricsCollector: LogMetricsCollector
    
    public init() {
        this.systemLogger = LoggerFactory.getLogger("cactor.system")
        this.actorLoggers = HashMap<String, ActorLogger>()
        this.mutex = Mutex()
        this.metricsCollector = LogMetricsCollector()
    }
    
    public func getActorLogger(actorPath: String): ActorLogger {
        mutex.lock()
        match (actorLoggers.get(actorPath)) {
            case Some(logger) => 
                mutex.unlock()
                logger
            case None => 
                let logger = ActorLogger(actorPath, "cactor.actor")
                actorLoggers[actorPath] = logger
                mutex.unlock()
                logger
        }
    }
    
    public func logSystemEvent(message: String, level: LogLevel): Unit {
        systemLogger.log(level, message)
        metricsCollector.recordLogEvent(level)
    }
    
    public func configureLogging(config: LoggingConfig): Unit {
        // 设置全局日志级别
        LoggerFactory.setDefaultLevel(config.globalLevel)
        
        // 配置文件输出
        if (config.enableFileLogging) {
            let fileAppender = FileAppender(config.logFile, 100)
            LoggerFactory.configureLogger("cactor", config.globalLevel, [fileAppender])
        }
        
        // 配置异步输出
        if (config.enableAsyncLogging) {
            let consoleAppender = ConsoleAppender()
            let asyncAppender = AsyncAppender(consoleAppender, 1000)
            LoggerFactory.configureLogger("cactor", config.globalLevel, [asyncAppender])
        }
        
        systemLogger.info("日志系统配置完成")
    }
    
    public func getMetrics(): LogMetrics {
        metricsCollector.getMetrics()
    }
    
    public func shutdown(): Unit {
        systemLogger.info("关闭日志系统")
        LoggerFactory.shutdown()
    }
}

/**
 * 日志配置
 */
public struct LoggingConfig {
    public let globalLevel: LogLevel
    public let enableFileLogging: Bool
    public let enableAsyncLogging: Bool
    public let logFile: String
    public let maxFileSize: Int64
    public let maxFiles: Int64
    
    public init(globalLevel: LogLevel,
                enableFileLogging: Bool,
                enableAsyncLogging: Bool,
                logFile: String,
                maxFileSize: Int64,
                maxFiles: Int64) {
        this.globalLevel = globalLevel
        this.enableFileLogging = enableFileLogging
        this.enableAsyncLogging = enableAsyncLogging
        this.logFile = logFile
        this.maxFileSize = maxFileSize
        this.maxFiles = maxFiles
    }
}

/**
 * 日志指标收集器
 */
public class LogMetricsCollector {
    private let logCounts: HashMap<String, AtomicInt64>
    private let mutex: Mutex
    
    public init() {
        this.logCounts = HashMap<String, AtomicInt64>()
        this.mutex = Mutex()
        
        // 初始化计数器
        logCounts["TRACE"] = AtomicInt64(0)
        logCounts["DEBUG"] = AtomicInt64(0)
        logCounts["INFO"] = AtomicInt64(0)
        logCounts["WARN"] = AtomicInt64(0)
        logCounts["ERROR"] = AtomicInt64(0)
        logCounts["FATAL"] = AtomicInt64(0)
    }
    
    public func recordLogEvent(level: LogLevel): Unit {
        let levelStr = level.toString()
        match (logCounts.get(levelStr)) {
            case Some(counter) => 
                counter.fetchAdd(1)
            case None => 
                // 不应该发生
                println("未知日志级别: ${levelStr}")
        }
    }
    
    public func getMetrics(): LogMetrics {
        mutex.lock()
        let traceCount = match (logCounts.get("TRACE")) {
            case Some(counter) => counter.load()
            case None => 0
        }
        let debugCount = match (logCounts.get("DEBUG")) {
            case Some(counter) => counter.load()
            case None => 0
        }
        let infoCount = match (logCounts.get("INFO")) {
            case Some(counter) => counter.load()
            case None => 0
        }
        let warnCount = match (logCounts.get("WARN")) {
            case Some(counter) => counter.load()
            case None => 0
        }
        let errorCount = match (logCounts.get("ERROR")) {
            case Some(counter) => counter.load()
            case None => 0
        }
        let fatalCount = match (logCounts.get("FATAL")) {
            case Some(counter) => counter.load()
            case None => 0
        }

        let metrics = LogMetrics(
            traceCount,
            debugCount,
            infoCount,
            warnCount,
            errorCount,
            fatalCount
        )
        mutex.unlock()
        metrics
    }
    
    public func reset(): Unit {
        mutex.lock()
        for ((_, counter) in logCounts) {
            counter.store(0)
        }
        mutex.unlock()
    }
}

/**
 * 日志指标
 */
public struct LogMetrics {
    public let traceCount: Int64
    public let debugCount: Int64
    public let infoCount: Int64
    public let warnCount: Int64
    public let errorCount: Int64
    public let fatalCount: Int64
    
    public init(traceCount: Int64, debugCount: Int64, infoCount: Int64,
                warnCount: Int64, errorCount: Int64, fatalCount: Int64) {
        this.traceCount = traceCount
        this.debugCount = debugCount
        this.infoCount = infoCount
        this.warnCount = warnCount
        this.errorCount = errorCount
        this.fatalCount = fatalCount
    }
    
    public func getTotalCount(): Int64 {
        traceCount + debugCount + infoCount + warnCount + errorCount + fatalCount
    }
    
    public func toString(): String {
        "LogMetrics(total=${getTotalCount()}, trace=${traceCount}, debug=${debugCount}, " +
        "info=${infoCount}, warn=${warnCount}, error=${errorCount}, fatal=${fatalCount})"
    }
}
