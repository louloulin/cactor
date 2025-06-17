/*
 * Copyright (c) 2024. All rights reserved.
 * ActorLifecycleManager - Actor生命周期管理器
 * 基于plan10.md设计，提供完整的Actor生命周期管理
 */
package cactor.runtime.lifecycle

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, Props}
import cactor.core.message.{Message, SystemMessage}
import cactor.core.context.{ActorContext}
import cactor.runtime.events.{ActorEventBus, ActorLifecycleEvent, ActorStartedEvent, ActorStoppedEvent, ActorRestartedEvent, ActorRegisteredEvent, ActorUnregisteredEvent, ActorStartFailedEvent, ActorStopFailedEvent, ActorRestartFailedEvent}

/**
 * Actor生命周期状态
 */
public enum ActorLifecycleState {
    | Created      // 已创建
    | Starting     // 启动中
    | Running      // 运行中
    | Stopping     // 停止中
    | Stopped      // 已停止
    | Restarting   // 重启中
    | Failed       // 失败状态
}

/**
 * Actor生命周期信息
 */
public struct ActorLifecycleInfo {
    public let actorRef: ActorRef
    public let state: ActorLifecycleState
    public let createdAt: Int64
    public let lastStateChange: Int64
    public let restartCount: Int32
    public let failureReason: Option<Exception>
    
    public init(
        actorRef: ActorRef,
        state: ActorLifecycleState,
        createdAt: Int64,
        lastStateChange: Int64,
        restartCount: Int32,
        failureReason: Option<Exception>
    ) {
        this.actorRef = actorRef
        this.state = state
        this.createdAt = createdAt
        this.lastStateChange = lastStateChange
        this.restartCount = restartCount
        this.failureReason = failureReason
    }
}

/**
 * Actor生命周期管理器
 * 
 * 职责：
 * 1. 管理Actor的完整生命周期
 * 2. 处理Actor启动、停止、重启流程
 * 3. 维护Actor状态信息
 * 4. 发布生命周期事件
 */
public class ActorLifecycleManager {
    private let lifecycleInfos: HashMap<String, ActorLifecycleInfo>
    private let eventBus: ActorEventBus
    private let isRunning: AtomicBool

    public init() {
        this.lifecycleInfos = HashMap<String, ActorLifecycleInfo>()
        this.eventBus = ActorEventBus()
        this.isRunning = AtomicBool(true)
    }
    
    /**
     * 启动Actor
     */
    public func startActor(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        // 更新状态为启动中
        updateActorState(actorRef, ActorLifecycleState.Starting, None<Exception>)
        
        try {
            // 发送启动消息
            actorRef.tell(StartMessage())
            
            // 更新状态为运行中
            updateActorState(actorRef, ActorLifecycleState.Running, None<Exception>)
            
            // 发布启动事件
            eventBus.publish(ActorStartedEvent(actorRef, currentTime))
            
        } catch (e: Exception) {
            // 启动失败，更新状态
            updateActorState(actorRef, ActorLifecycleState.Failed, Some(e))
            eventBus.publish(ActorStartFailedEvent(actorRef, e, currentTime))
            throw e
        }
    }
    
    /**
     * 停止Actor
     */
    public func stopActor(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        // 检查当前状态
        match (getActorState(actorRef)) {
            case Some(info) =>
                match (info.state) {
                    case ActorLifecycleState.Stopped =>
                        return  // 已经停止
                    case _ =>
                        ()  // 继续处理
                }
            case None =>
                return  // Actor不存在
        }
        
        // 更新状态为停止中
        updateActorState(actorRef, ActorLifecycleState.Stopping, None<Exception>)
        
        try {
            // 发送停止消息
            actorRef.tell(StopMessage())
            
            // 更新状态为已停止
            updateActorState(actorRef, ActorLifecycleState.Stopped, None<Exception>)
            
            // 发布停止事件
            eventBus.publish(ActorStoppedEvent(actorRef, currentTime))
            
            // 清理生命周期信息
            lifecycleInfos.remove(path)
            
        } catch (e: Exception) {
            // 停止失败，更新状态
            updateActorState(actorRef, ActorLifecycleState.Failed, Some(e))
            eventBus.publish(ActorStopFailedEvent(actorRef, e, currentTime))
            throw e
        }
    }
    
    /**
     * 重启Actor
     */
    public func restartActor(actorRef: ActorRef, reason: Exception): Unit {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        // 更新状态为重启中
        updateActorState(actorRef, ActorLifecycleState.Restarting, Some(reason))
        
        try {
            // 先停止Actor
            actorRef.tell(StopMessage())
            
            // 等待一小段时间确保停止完成
            // Thread.sleep(Duration.millisecond * 10)  // 简化实现，跳过sleep
            
            // 重新启动Actor
            actorRef.tell(StartMessage())
            
            // 更新状态为运行中，增加重启计数
            incrementRestartCount(actorRef)
            updateActorState(actorRef, ActorLifecycleState.Running, None<Exception>)
            
            // 发布重启事件
            eventBus.publish(ActorRestartedEvent(actorRef, reason, currentTime))
            
        } catch (e: Exception) {
            // 重启失败，更新状态
            updateActorState(actorRef, ActorLifecycleState.Failed, Some(e))
            eventBus.publish(ActorRestartFailedEvent(actorRef, e, currentTime))
            throw e
        }
    }
    
    /**
     * 注册Actor
     */
    public func registerActor(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        let info = ActorLifecycleInfo(
            actorRef,
            ActorLifecycleState.Created,
            currentTime,
            currentTime,
            0,
            None<Exception>
        )
        
        lifecycleInfos.put(path, info)
        eventBus.publish(ActorRegisteredEvent(actorRef, currentTime))
    }
    
    /**
     * 注销Actor
     */
    public func unregisterActor(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        lifecycleInfos.remove(path)
        eventBus.publish(ActorUnregisteredEvent(actorRef, getCurrentTimeNanos()))
    }
    
    /**
     * 获取Actor状态
     */
    public func getActorState(actorRef: ActorRef): Option<ActorLifecycleInfo> {
        let path = actorRef.path.toString()
        lifecycleInfos.get(path)
    }
    
    /**
     * 获取所有Actor状态
     */
    public func getAllActorStates(): ArrayList<ActorLifecycleInfo> {
        let states = ArrayList<ActorLifecycleInfo>()
        for ((path, info) in lifecycleInfos) {
            states.append(info)
        }
        states
    }
    
    /**
     * 获取运行中的Actor数量
     */
    public func getRunningActorCount(): Int32 {
        var count: Int32 = 0
        for ((path, info) in lifecycleInfos) {
            match (info.state) {
                case ActorLifecycleState.Running =>
                    count += 1
                case _ =>
                    ()
            }
        }
        count
    }
    
    /**
     * 获取事件总线
     */
    public func getEventBus(): ActorEventBus {
        eventBus
    }
    
    /**
     * 关闭生命周期管理器
     */
    public func shutdown(): Unit {
        isRunning.store(false)
        lifecycleInfos.clear()
    }
    
    // 私有辅助方法
    private func updateActorState(actorRef: ActorRef, newState: ActorLifecycleState, failureReason: Option<Exception>): Unit {
        let path = actorRef.path.toString()
        let currentTime = getCurrentTimeNanos()
        
        match (lifecycleInfos.get(path)) {
            case Some(oldInfo) =>
                let newInfo = ActorLifecycleInfo(
                    actorRef,
                    newState,
                    oldInfo.createdAt,
                    currentTime,
                    oldInfo.restartCount,
                    failureReason
                )
                lifecycleInfos.put(path, newInfo)
            case None =>
                let newInfo = ActorLifecycleInfo(
                    actorRef,
                    newState,
                    currentTime,
                    currentTime,
                    0,
                    failureReason
                )
                lifecycleInfos.put(path, newInfo)
        }
    }
    
    private func incrementRestartCount(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        match (lifecycleInfos.get(path)) {
            case Some(oldInfo) =>
                let newInfo = ActorLifecycleInfo(
                    oldInfo.actorRef,
                    oldInfo.state,
                    oldInfo.createdAt,
                    oldInfo.lastStateChange,
                    oldInfo.restartCount + 1,
                    oldInfo.failureReason
                )
                lifecycleInfos.put(path, newInfo)
            case None =>
                // Actor不存在，忽略
                ()
        }
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }
}

/**
 * 生命周期相关的系统消息
 */
public struct StartMessage <: SystemMessage {
    public init() {}
    
    public func messageType(): String {
        "StartMessage"
    }
}

public struct StopMessage <: SystemMessage {
    public init() {}
    
    public func messageType(): String {
        "StopMessage"
    }
}
