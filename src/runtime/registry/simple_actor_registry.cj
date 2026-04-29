/*
 * Copyright (c) 2024. All rights reserved.
 * SimpleActorRegistry - 简化的Actor注册表
 * 基于plan10.md设计，提供基本的Actor注册和查找服务
 */
package cactor.runtime.registry

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath}

/**
 * 简化的Actor注册信息
 */
public struct SimpleActorRegistryEntry {
    public let actorRef: ActorRef
    public let registeredAt: Int64
    public let parentPath: Option<String>
    
    public init(actorRef: ActorRef, registeredAt: Int64, parentPath: Option<String>) {
        this.actorRef = actorRef
        this.registeredAt = registeredAt
        this.parentPath = parentPath
    }
}

/**
 * 简化的Actor注册表
 * 
 * 职责：
 * 1. 维护Actor的注册信息
 * 2. 提供基本的Actor查找服务
 * 3. 支持Actor路径解析
 */
public class SimpleActorRegistry {
    // 主要存储：路径 -> ActorRef
    private let pathToActor: HashMap<String, SimpleActorRegistryEntry>
    
    // 名称索引：名称 -> 路径
    private let nameToPath: HashMap<String, String>
    
    // 统计信息
    private let totalActors: AtomicInt64
    private let registrationCount: AtomicInt64
    
    public init() {
        this.pathToActor = HashMap<String, SimpleActorRegistryEntry>()
        this.nameToPath = HashMap<String, String>()
        this.totalActors = AtomicInt64(0)
        this.registrationCount = AtomicInt64(0)
    }
    
    /**
     * 注册Actor
     */
    public func register(actorRef: ActorRef, parentPath: Option<String>): Unit {
        let path = actorRef.path.toString()
        let name = extractActorName(path)
        let currentTime = getCurrentTimeNanos()
        
        // 检查是否已经注册
        match (pathToActor.get(path)) {
            case Some(existing) =>
                return  // 已经注册，忽略
            case None =>
                ()  // 继续注册
        }
        
        // 创建注册条目
        let entry = SimpleActorRegistryEntry(actorRef, currentTime, parentPath)
        
        // 主要存储
        pathToActor.add(path, entry)
        nameToPath.add(name, path)
        
        // 更新统计
        totalActors.fetchAdd(1)
        registrationCount.fetchAdd(1)
    }
    
    /**
     * 注销Actor
     */
    public func unregister(actorRef: ActorRef): Unit {
        let path = actorRef.path.toString()
        unregisterByPath(path)
    }
    
    /**
     * 通过路径注销Actor
     */
    public func unregisterByPath(path: String): Unit {
        match (pathToActor.get(path)) {
            case Some(entry) =>
                let name = extractActorName(path)
                
                // 移除主要存储
                pathToActor.remove(path)
                nameToPath.remove(name)
                
                // 更新统计
                totalActors.fetchAdd(-1)
                
            case None =>
                ()  // Actor未注册，忽略
        }
    }
    
    /**
     * 通过路径查找Actor
     */
    public func findByPath(path: String): Option<ActorRef> {
        match (pathToActor.get(path)) {
            case Some(entry) =>
                Some(entry.actorRef)
            case None =>
                None<ActorRef>
        }
    }
    
    /**
     * 通过名称查找Actor
     */
    public func findByName(name: String): Option<ActorRef> {
        match (nameToPath.get(name)) {
            case Some(path) =>
                findByPath(path)
            case None =>
                None<ActorRef>
        }
    }
    
    /**
     * 检查Actor是否已注册
     */
    public func isRegistered(actorRef: ActorRef): Bool {
        let path = actorRef.path.toString()
        match (pathToActor.get(path)) {
            case Some(entry) =>
                true
            case None =>
                false
        }
    }
    
    /**
     * 获取注册的Actor总数
     */
    public func getTotalActorCount(): Int64 {
        totalActors.load()
    }
    
    /**
     * 获取注册次数
     */
    public func getRegistrationCount(): Int64 {
        registrationCount.load()
    }
    
    /**
     * 获取所有注册的Actor
     */
    public func getAllActors(): Array<ActorRef> {
        let result = ArrayList<ActorRef>()
        for ((path, entry) in pathToActor) {
            result.add(entry.actorRef)
        }
        result.toArray()
    }
    
    /**
     * 清空注册表
     */
    public func clear(): Unit {
        pathToActor.clear()
        nameToPath.clear()
        totalActors.store(0)
    }
    
    /**
     * 打印注册表统计信息
     */
    public func printStats(): Unit {
        println("=== SimpleActorRegistry统计信息 ===")
        println("总Actor数量: ${getTotalActorCount()}")
        println("注册次数: ${getRegistrationCount()}")
        println("路径索引大小: ${countPathToActor()}")
        println("名称索引大小: ${countNameToPath()}")
    }

    private func countPathToActor(): Int32 {
        var count = 0
        for ((_, _) in pathToActor) {
            count += 1
        }
        Int32(count)
    }

    private func countNameToPath(): Int32 {
        var count = 0
        for ((_, _) in nameToPath) {
            count += 1
        }
        Int32(count)
    }
    
    /**
     * 从路径中提取Actor名称
     */
    private func extractActorName(path: String): String {
        // 简化实现：直接返回路径作为名称
        path
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }
}
