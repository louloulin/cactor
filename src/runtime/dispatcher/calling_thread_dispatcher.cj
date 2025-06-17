/*
 * Copyright (c) 2024. All rights reserved.
 * CallingThreadDispatcher - 调用线程调度器
 * 基于plan10.md设计，在调用线程中直接执行任务（主要用于测试）
 */
package cactor.runtime.dispatcher

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.{Message, Envelope}

/**
 * 调用线程调度器实现
 * 
 * 这个调度器在调用线程中直接执行任务，不使用额外的线程池。
 * 主要用于测试和单线程环境。
 */
public class CallingThreadDispatcher <: Dispatcher {
    private let dispatcherName: String
    private let isRunning: AtomicBool
    private let totalProcessedMessages: AtomicInt64
    private let totalErrors: AtomicInt64
    private let totalLatency: AtomicInt64
    private let startTime: Int64
    
    public init(name: String) {
        this.dispatcherName = name
        this.isRunning = AtomicBool(false)
        this.totalProcessedMessages = AtomicInt64(0)
        this.totalErrors = AtomicInt64(0)
        this.totalLatency = AtomicInt64(0)
        this.startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
    }
    
    public prop name: String {
        get() { dispatcherName }
    }
    
    public prop dispatcherType: DispatcherType {
        get() { DispatcherType.CallingThread }
    }
    
    public prop isRunning: Bool {
        get() { this.isRunning.load() }
    }
    
    /**
     * 分发消息 - 在调用线程中直接执行
     */
    public func dispatch(envelope: Envelope, actorRef: ActorRef): Unit {
        dispatchWithPriority(envelope, actorRef, Priority.Normal)
    }
    
    /**
     * 带优先级的分发 - 在调用线程中直接执行
     */
    public func dispatchWithPriority(envelope: Envelope, actorRef: ActorRef, priority: Priority): Unit {
        if (!isRunning.load()) {
            throw Exception("CallingThreadDispatcher未运行")
        }
        
        let startTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        
        try {
            // 在调用线程中直接执行
            executeInCallingThread(envelope, actorRef)
            
            let endTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
            let latency = endTime - startTime
            
            totalProcessedMessages.fetchAdd(1)
            totalLatency.fetchAdd(latency)
            
        } catch (e: Exception) {
            totalErrors.fetchAdd(1)
            throw e
        }
    }
    
    /**
     * 启动调度器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("CallingThreadDispatcher '${name}' 已启动")
        }
    }
    
    /**
     * 停止调度器
     */
    public func shutdown(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("CallingThreadDispatcher '${name}' 已停止")
        }
    }
    
    /**
     * 获取统计信息
     */
    public func getStats(): DispatcherStats {
        let processedMessages = totalProcessedMessages.load()
        let totalLatencyNanos = totalLatency.load()
        
        let averageLatency = if (processedMessages > 0) {
            Float64(totalLatencyNanos) / Float64(processedMessages) / 1000.0  // 转换为微秒
        } else {
            0.0
        }
        
        let throughput = calculateThroughput(processedMessages)
        
        DispatcherStats(
            dispatcherName,
            DispatcherType.CallingThread,
            1,  // 单线程
            0,  // 无队列
            processedMessages,
            averageLatency,
            throughput,
            totalErrors.load()
        )
    }
    
    /**
     * 在调用线程中执行任务
     */
    private func executeInCallingThread(envelope: Envelope, actorRef: ActorRef): Unit {
        // 直接在当前线程执行Actor消息处理
        actorRef.tell(envelope.getMessage())
    }
    
    /**
     * 计算吞吐量
     */
    private func calculateThroughput(processedMessages: Int64): Float64 {
        let currentTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
        let elapsedSeconds = Float64(currentTime - startTime) / 1_000_000_000.0
        
        if (elapsedSeconds > 0.0) {
            Float64(processedMessages) / elapsedSeconds
        } else {
            0.0
        }
    }
}

/**
 * 调用线程调度器工厂
 */
public class CallingThreadDispatcherFactory {
    /**
     * 创建调用线程调度器
     */
    public static func create(name: String): CallingThreadDispatcher {
        CallingThreadDispatcher(name)
    }
    
    /**
     * 创建默认调用线程调度器
     */
    public static func createDefault(): CallingThreadDispatcher {
        CallingThreadDispatcher("calling-thread-default")
    }
}
