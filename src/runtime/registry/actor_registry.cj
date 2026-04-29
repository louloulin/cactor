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
    private let pathToActor: HashMap<String, ActorRegistryEntry>

    // 反向索引：Actor路径字符串 -> 路径（简化实现，避免ActorRef作为键）
    private let actorPathToPath: HashMap<String, String>

    // 名称索引：名称 -> 路径集合（支持同名Actor）
    private let nameToPath: HashMap<String, HashSet<String>>

    // 父子关系索引
    private let parentToChildren: HashMap<String, HashSet<String>>
    private let childToParent: HashMap<String, String>

    // 统计信息
    private let totalActors: AtomicInt64
    private let registrationCount: AtomicInt64

    // 互斥锁
    private let registryLock: ReentrantMutex
    
    public init() {
        this.pathToActor = HashMap<String, ActorRegistryEntry>()
        this.actorPathToPath = HashMap<String, String>()
        this.nameToPath = HashMap<String, HashSet<String>>()
        this.parentToChildren = HashMap<String, HashSet<String>>()
        this.childToParent = HashMap<String, String>()
        this.totalActors = AtomicInt64(0)
        this.registrationCount = AtomicInt64(0)
        this.registryLock = ReentrantMutex()
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
        let entry = ActorRegistryEntry(actorRef, currentTime, parentPath)

        // 主要存储
        pathToActor.add(path, entry)
        actorPathToPath.add(actorRef.path.toString(), path)

        // 名称索引
        match (nameToPath.get(name)) {
            case Some(paths) =>
                paths.add(path)
            case None =>
                let newPaths = HashSet<String>()
                newPaths.add(path)
                nameToPath.add(name, newPaths)
        }

        // 父子关系
        match (parentPath) {
            case Some(parent) =>
                childToParent.add(path, parent)
                match (parentToChildren.get(parent)) {
                    case Some(children) =>
                        children.add(path)
                    case None =>
                        let newChildren = HashSet<String>()
                        newChildren.add(path)
                        parentToChildren.add(parent, newChildren)
                }
            case None =>
                ()  // 根级Actor，无父Actor
        }

        // 更新统计
        totalActors.fetchAdd(1)
        registrationCount.fetchAdd(1)
    }
    
    /**
     * 注销Actor
     */
    public func unregister(actorRef: ActorRef): Unit {
        let path = actorPathToPath.get(actorRef.path.toString())
        match (path) {
            case Some(actorPath) =>
                unregisterByPath(actorPath)
            case None =>
                // Actor未注册，忽略
                ()
        }
    }
    
    /**
     * 通过路径注销Actor
     */
    public func unregisterByPath(path: String): Unit {
        registryLock.lock()
        try {
            match (pathToActor.get(path)) {
                case Some(entry) =>
                    let actorRef = entry.actorRef
                    let name = extractActorName(path)
                    
                    // 移除主要存储
                    pathToActor.remove(path)
                    actorPathToPath.remove(actorRef.path.toString())
                    
                    // 移除名称索引
                    match (nameToPath.get(name)) {
                        case Some(paths) =>
                            paths.remove(path)
                            if (paths.isEmpty()) {
                                nameToPath.remove(name)
                            }
                        case None =>
                            // 索引不一致，忽略
                            ()
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
                                    ()
                            }
                        case None =>
                            // 根级Actor，无父Actor
                            ()
                    }
                    
                    // 递归注销所有子Actor
                    match (parentToChildren.get(path)) {
                        case Some(children) =>
                            for (childPath in children) {
                                unregisterByPath(childPath)
                            }
                        case None =>
                            // 无子Actor
                            ()
                    }
                    
                    // 更新统计
                    totalActors.fetchAdd(-1)
                    
                case None =>
                    // Actor未注册，忽略
                    ()
            }
        } finally {
            registryLock.unlock()
        }
    }
    
    /**
     * 通过路径查找Actor
     */
    public func findByPath(path: String): Option<ActorRef> {
        registryLock.lock()
        try {
            match (pathToActor.get(path)) {
                case Some(entry) =>
                    Some(entry.actorRef)
                case None =>
                    None<ActorRef>
            }
        } finally {
            registryLock.unlock()
        }
    }
    
    /**
     * 通过名称查找Actor（返回第一个匹配的）
     */
    public func findByName(name: String): Option<ActorRef> {
        registryLock.lock()
        try {
            match (nameToPath.get(name)) {
                case Some(paths) =>
                    if (!paths.isEmpty()) {
                        // 简化实现：获取第一个路径
                        for (path in paths) {
                            match (pathToActor.get(path)) {
                                case Some(entry) =>
                                    return Some(entry.actorRef)
                                case None =>
                                    ()
                            }
                        }
                        None<ActorRef>
                    } else {
                        None<ActorRef>
                    }
                case None =>
                    None<ActorRef>
            }
        } finally {
            registryLock.unlock()
        }
    }
    
    /**
     * 通过名称查找所有Actor
     */
    public func findAllByName(name: String): Array<ActorRef> {
        let result = ArrayList<ActorRef>()

        registryLock.lock()
        try {
            match (nameToPath.get(name)) {
                case Some(paths) =>
                    for (path in paths) {
                        match (pathToActor.get(path)) {
                            case Some(entry) =>
                                result.add(entry.actorRef)
                            case None =>
                                // 索引不一致，忽略
                                ()
                        }
                    }
                case None =>
                    // 无匹配的Actor
                    ()
            }
        } finally {
            registryLock.unlock()
        }

        result.toArray()
    }
    
    /**
     * 获取Actor的子Actor
     */
    public func getChildren(actorRef: ActorRef): Array<ActorRef> {
        let result = ArrayList<ActorRef>()

        match (actorPathToPath.get(actorRef.path.toString())) {
            case Some(path) =>
                registryLock.lock()
                try {
                    match (parentToChildren.get(path)) {
                        case Some(children) =>
                            for (childPath in children) {
                                match (pathToActor.get(childPath)) {
                                    case Some(entry) =>
                                        result.add(entry.actorRef)
                                    case None =>
                                        // 索引不一致，忽略
                                        ()
                                }
                            }
                        case None =>
                            // 无子Actor
                            ()
                    }
                } finally {
                    registryLock.unlock()
                }
            case None =>
                // Actor未注册
                ()
        }

        result.toArray()
    }
    
    /**
     * 获取Actor的父Actor
     */
    public func getParent(actorRef: ActorRef): Option<ActorRef> {
        match (actorPathToPath.get(actorRef.path.toString())) {
            case Some(path) =>
                registryLock.lock()
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
                    registryLock.unlock()
                }
            case None =>
                None<ActorRef>
        }
    }
    
    /**
     * 检查Actor是否已注册
     */
    public func isRegistered(actorRef: ActorRef): Bool {
        match (actorPathToPath.get(actorRef.path.toString())) {
            case Some(_) => true
            case None => false
        }
    }

    /**
     * 检查名称是否已被占用 - Plan10.md要求
     */
    public func isNameTaken(name: String): Bool {
        match (nameToPath.get(name)) {
            case Some(_) => true
            case None => false
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

        registryLock.lock()
        try {
            for ((path, entry) in pathToActor) {
                result.add(entry.actorRef)
            }
        } finally {
            registryLock.unlock()
        }

        result.toArray()
    }
    
    /**
     * 清空注册表
     */
    public func clear(): Unit {
        registryLock.lock()
        try {
            pathToActor.clear()
            actorPathToPath.clear()
            nameToPath.clear()
            parentToChildren.clear()
            childToParent.clear()
            totalActors.store(0)
        } finally {
            registryLock.unlock()
        }
    }
    
    /**
     * 打印注册表统计信息
     */
    public func printStats(): Unit {
        println("=== ActorRegistry统计信息 ===")
        println("总Actor数量: ${getTotalActorCount()}")
        println("注册次数: ${getRegistrationCount()}")
        println("路径索引大小: ${countPathToActor()}")
        println("名称索引大小: ${countNameToPath()}")
        println("父子关系索引大小: ${countParentToChildren()}")
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

    private func countParentToChildren(): Int32 {
        var count = 0
        for ((_, _) in parentToChildren) {
            count += 1
        }
        Int32(count)
    }
    
    private func getCurrentTimeNanos(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() * 1000000
    }

    /**
     * 从路径中提取Actor名称
     */
    private func extractActorName(path: String): String {
        // 简化实现：直接返回路径作为名称
        // 在实际实现中，应该解析路径并提取最后一部分
        path
    }
}
