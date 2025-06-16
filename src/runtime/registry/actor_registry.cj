/*
 * Copyright (c) 2024. All rights reserved.
 * ActorRegistry - Actor注册表
 * 基于plan10.md设计，提供高性能的Actor注册和查找服务
 */
package cactor.runtime.registry

import std.sync.*
import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.core.system.{ActorSelection}

/**
 * Actor注册信息
 */
public struct ActorRegistryEntry {
    public let actorRef: ActorRef
    public let registeredAt: Int64
    public let parentPath: Option<String>
    public let children: HashSet<String>
    
    public init(actorRef: ActorRef, registeredAt: Int64, parentPath: Option<String>) {
        this.actorRef = actorRef
        this.registeredAt = registeredAt
        this.parentPath = parentPath
        this.children = HashSet<String>()
    }
}

/**
 * Actor注册表
 * 
 * 职责：
 * 1. 维护Actor的注册信息和层次结构
 * 2. 提供高性能的Actor查找服务
 * 3. 支持Actor路径解析和选择
 * 4. 维护父子关系和层次结构
 */
public class ActorRegistry {
    // 主要存储：路径 -> ActorRef
    private let pathToActor: ConcurrentHashMap<String, ActorRegistryEntry>
    
    // 反向索引：ActorRef -> 路径
    private let actorToPath: ConcurrentHashMap<ActorRef, String>
    
    // 名称索引：名称 -> 路径集合（支持同名Actor）
    private let nameToPath: ConcurrentHashMap<String, HashSet<String>>
    
    // 父子关系索引
    private let parentToChildren: ConcurrentHashMap<String, HashSet<String>>
    private let childToParent: ConcurrentHashMap<String, String>
    
    // 统计信息
    private let totalActors: AtomicInt64
    private let registrationCount: AtomicInt64
    
    // 读写锁，支持高并发读取
    private let registryLock: RwLock
    
    public init() {
        this.pathToActor = ConcurrentHashMap<String, ActorRegistryEntry>()
        this.actorToPath = ConcurrentHashMap<ActorRef, String>()
        this.nameToPath = ConcurrentHashMap<String, HashSet<String>>()
        this.parentToChildren = ConcurrentHashMap<String, HashSet<String>>()
        this.childToParent = ConcurrentHashMap<String, String>()
        this.totalActors = AtomicInt64(0)
        this.registrationCount = AtomicInt64(0)
        this.registryLock = RwLock()
    }
    
    /**
     * 注册Actor
     */
    public func register(actorRef: ActorRef, parentPath: Option<String> = None<String>): Unit {
        let path = actorRef.path.toString()
        let name = actorRef.path.name
        let currentTime = getCurrentTimeNanos()
        
        registryLock.lockWrite()
        try {
            // 检查是否已经注册
            if (pathToActor.containsKey(path)) {
                return  // 已经注册，忽略
            }
            
            // 创建注册条目
            let entry = ActorRegistryEntry(actorRef, currentTime, parentPath)
            
            // 主要存储
            pathToActor.put(path, entry)
            actorToPath.put(actorRef, path)
            
            // 名称索引
            match (nameToPath.get(name)) {
                case Some(paths) =>
                    paths.put(path)
                case None =>
                    let newPaths = HashSet<String>()
                    newPaths.put(path)
                    nameToPath.put(name, newPaths)
            }
            
            // 父子关系
            match (parentPath) {
                case Some(parent) =>
                    childToParent.put(path, parent)
                    match (parentToChildren.get(parent)) {
                        case Some(children) =>
                            children.put(path)
                        case None =>
                            let newChildren = HashSet<String>()
                            newChildren.put(path)
                            parentToChildren.put(parent, newChildren)
                    }
                case None =>
                    // 根级Actor，无父Actor
            }
            
            // 更新统计
            totalActors.fetchAdd(1)
            registrationCount.fetchAdd(1)
            
        } finally {
            registryLock.unlockWrite()
        }
    }
    
    /**
     * 注销Actor
     */
    public func unregister(actorRef: ActorRef): Unit {
        let path = actorToPath.get(actorRef)
        match (path) {
            case Some(actorPath) =>
                unregisterByPath(actorPath)
            case None =>
                // Actor未注册，忽略
        }
    }
    
    /**
     * 通过路径注销Actor
     */
    public func unregisterByPath(path: String): Unit {
        registryLock.lockWrite()
        try {
            match (pathToActor.get(path)) {
                case Some(entry) =>
                    let actorRef = entry.actorRef
                    let name = actorRef.path.name
                    
                    // 移除主要存储
                    pathToActor.remove(path)
                    actorToPath.remove(actorRef)
                    
                    // 移除名称索引
                    match (nameToPath.get(name)) {
                        case Some(paths) =>
                            paths.remove(path)
                            if (paths.isEmpty()) {
                                nameToPath.remove(name)
                            }
                        case None =>
                            // 索引不一致，忽略
                    }
                    
                    // 移除父子关系
                    match (childToParent.get(path)) {
                        case Some(parent) =>
                            childToParent.remove(path)
                            match (parentToChildren.get(parent)) {
                                case Some(children) =>
                                    children.remove(path)
                                    if (children.isEmpty()) {
                                        parentToChildren.remove(parent)
                                    }
                                case None =>
                                    // 索引不一致，忽略
                            }
                        case None =>
                            // 根级Actor，无父Actor
                    }
                    
                    // 递归注销所有子Actor
                    match (parentToChildren.get(path)) {
                        case Some(children) =>
                            for (childPath in children) {
                                unregisterByPath(childPath)
                            }
                        case None =>
                            // 无子Actor
                    }
                    
                    // 更新统计
                    totalActors.fetchAdd(-1)
                    
                case None =>
                    // Actor未注册，忽略
            }
        } finally {
            registryLock.unlockWrite()
        }
    }
    
    /**
     * 通过路径查找Actor
     */
    public func findByPath(path: String): Option<ActorRef> {
        registryLock.lockRead()
        try {
            match (pathToActor.get(path)) {
                case Some(entry) =>
                    Some(entry.actorRef)
                case None =>
                    None<ActorRef>
            }
        } finally {
            registryLock.unlockRead()
        }
    }
    
    /**
     * 通过名称查找Actor（返回第一个匹配的）
     */
    public func findByName(name: String): Option<ActorRef> {
        registryLock.lockRead()
        try {
            match (nameToPath.get(name)) {
                case Some(paths) =>
                    if (!paths.isEmpty()) {
                        let firstPath = paths.iterator().next()
                        match (pathToActor.get(firstPath)) {
                            case Some(entry) =>
                                Some(entry.actorRef)
                            case None =>
                                None<ActorRef>
                        }
                    } else {
                        None<ActorRef>
                    }
                case None =>
                    None<ActorRef>
            }
        } finally {
            registryLock.unlockRead()
        }
    }
    
    /**
     * 通过名称查找所有Actor
     */
    public func findAllByName(name: String): Array<ActorRef> {
        let result = Array<ActorRef>()
        
        registryLock.lockRead()
        try {
            match (nameToPath.get(name)) {
                case Some(paths) =>
                    for (path in paths) {
                        match (pathToActor.get(path)) {
                            case Some(entry) =>
                                result.append(entry.actorRef)
                            case None =>
                                // 索引不一致，忽略
                        }
                    }
                case None =>
                    // 无匹配的Actor
            }
        } finally {
            registryLock.unlockRead()
        }
        
        result
    }
    
    /**
     * 获取Actor的子Actor
     */
    public func getChildren(actorRef: ActorRef): Array<ActorRef> {
        let result = Array<ActorRef>()
        
        match (actorToPath.get(actorRef)) {
            case Some(path) =>
                registryLock.lockRead()
                try {
                    match (parentToChildren.get(path)) {
                        case Some(children) =>
                            for (childPath in children) {
                                match (pathToActor.get(childPath)) {
                                    case Some(entry) =>
                                        result.append(entry.actorRef)
                                    case None =>
                                        // 索引不一致，忽略
                                }
                            }
                        case None =>
                            // 无子Actor
                    }
                } finally {
                    registryLock.unlockRead()
                }
            case None =>
                // Actor未注册
        }
        
        result
    }
    
    /**
     * 获取Actor的父Actor
     */
    public func getParent(actorRef: ActorRef): Option<ActorRef> {
        match (actorToPath.get(actorRef)) {
            case Some(path) =>
                registryLock.lockRead()
                try {
                    match (childToParent.get(path)) {
                        case Some(parentPath) =>
                            match (pathToActor.get(parentPath)) {
                                case Some(entry) =>
                                    Some(entry.actorRef)
                                case None =>
                                    None<ActorRef>
                            }
                        case None =>
                            None<ActorRef>
                    }
                } finally {
                    registryLock.unlockRead()
                }
            case None =>
                None<ActorRef>
        }
    }
    
    /**
     * 检查Actor是否已注册
     */
    public func isRegistered(actorRef: ActorRef): Bool {
        actorToPath.containsKey(actorRef)
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
        let result = Array<ActorRef>()
        
        registryLock.lockRead()
        try {
            for ((path, entry) in pathToActor) {
                result.append(entry.actorRef)
            }
        } finally {
            registryLock.unlockRead()
        }
        
        result
    }
    
    /**
     * 清空注册表
     */
    public func clear(): Unit {
        registryLock.lockWrite()
        try {
            pathToActor.clear()
            actorToPath.clear()
            nameToPath.clear()
            parentToChildren.clear()
            childToParent.clear()
            totalActors.store(0)
        } finally {
            registryLock.unlockWrite()
        }
    }
    
    /**
     * 打印注册表统计信息
     */
    public func printStats(): Unit {
        println("=== ActorRegistry统计信息 ===")
        println("总Actor数量: ${getTotalActorCount()}")
        println("注册次数: ${getRegistrationCount()}")
        println("路径索引大小: ${pathToActor.size()}")
        println("名称索引大小: ${nameToPath.size()}")
        println("父子关系索引大小: ${parentToChildren.size()}")
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }
}
