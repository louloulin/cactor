/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 远程 Actor 引用实现
 * 提供透明远程 Actor 通信，对标 Akka RemoteActorRef
 */
package cactor.distribution.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath}

/**
 * 远程 Actor 引用状态
 */
public enum RemoteActorRefState {
    | Connected      // 已连接
    | Disconnected   // 已断开
    | Connecting     // 连接中
    | Failed         // 失败

    public func isAvailable(): Bool {
        match (this) {
            case Connected => true
            case _ => false
        }
    }
}

/**
 * 远程 Actor 引用 - 对标 Akka RemoteActorRef
 * 提供跨进程的 Actor 通信能力
 */
public class RemoteActorRef <: ActorRef {
    // 远程地址信息
    private let remoteHost: String
    private let remotePort: Int32
    private let actorPath: ActorPath
    // 代理和状态
    private let proxy: RemoteActorProxy
    private var state: RemoteActorRefState
    // 统计信息
    private var messageCount: Int64
    private var lastMessageTime: Int64
    private let lock: ReentrantReadWriteMutex

    public init(
        host: String,
        port: Int32,
        path: ActorPath,
        proxy: RemoteActorProxy
    ) {
        this.remoteHost = host
        this.remotePort = port
        this.actorPath = path
        this.proxy = proxy
        this.state = RemoteActorRefState.Disconnected
        this.messageCount = 0
        this.lastMessageTime = 0
        this.lock = ReentrantReadWriteMutex()
    }

    // === ActorRef 接口实现 ===

    /**
     * 获取 Actor 路径 (实现 ActorRef 接口)
     */
    public prop path: ActorPath {
        get() { actorPath }
    }

    /**
     * 发送消息给远程 Actor (tell 模式)
     */
    public func tell(message: Message): Unit {
        tell(message, None)
    }

    /**
     * 发送消息给远程 Actor，指定发送者
     */
    public func tell(message: Message, sender: Option<String>): Unit {
        try {
            lock.readMutex.lock()

            // 检查连接状态
            if (!state.isAvailable()) {
                lock.readMutex.unlock()
                return
            }

            let currentMessageCount = messageCount
            lock.readMutex.unlock()

            // 通过代理发送消息
            proxy.tell(actorPath, message)

            // 更新统计
            try {
                lock.writeMutex.lock()
                messageCount = currentMessageCount + 1
                lastMessageTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                lock.writeMutex.unlock()
            } catch (e: Exception) {
                lock.writeMutex.unlock()
            }
        } catch (e: Exception) {
            try {
                lock.writeMutex.lock()
                state = RemoteActorRefState.Failed
                lock.writeMutex.unlock()
            } catch (_: Exception) {
                lock.writeMutex.unlock()
            }
        }
    }

    /**
     * 比较两个 ActorRef 是否相等
     */
    public func equals(other: ActorRef): Bool {
        let otherPath = other.path
        actorPath.toString() == otherPath.toString()
    }

    /**
     * 获取哈希码
     */
    public func hashCode(): Int32 {
        Int32(toString().hashCode())
    }

    // === 远程 Actor 特有方法 ===

    /**
     * 获取远程地址
     */
    public func getRemoteAddress(): (String, Int32) {
        (remoteHost, remotePort)
    }

    /**
     * 获取当前状态
     */
    public func getState(): RemoteActorRefState {
        try {
            lock.readMutex.lock()
            let s = state
            lock.readMutex.unlock()
            return s
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return RemoteActorRefState.Failed
        }
    }

    /**
     * 设置连接状态
     */
    public func setState(newState: RemoteActorRefState): Unit {
        try {
            lock.writeMutex.lock()
            state = newState
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 获取消息计数
     */
    public func getMessageCount(): Int64 {
        try {
            lock.readMutex.lock()
            let count = messageCount
            lock.readMutex.unlock()
            return count
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return 0
        }
    }

    /**
     * 获取最后消息时间
     */
    public func getLastMessageTime(): Int64 {
        try {
            lock.readMutex.lock()
            let time = lastMessageTime
            lock.readMutex.unlock()
            return time
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return 0
        }
    }

    /**
     * 发送 ask 消息并等待响应
     */
    public func ask(message: Message, timeout!: Duration = Duration.second * 5): Option<Message> {
        try {
            lock.readMutex.lock()
            if (!state.isAvailable()) {
                lock.readMutex.unlock()
                return None
            }
            lock.readMutex.unlock()

            let config = RemoteCallConfig(timeout: timeout.toMilliseconds(), retries: 1)
            let result = proxy.ask(actorPath, message, config: config)

            if (result.success) {
                return result.value
            }
            return None
        } catch (e: Exception) {
            return None
        }
    }

    /**
     * 检查是否可访问
     */
    public func isAvailable(): Bool {
        state.isAvailable()
    }

    /**
     * 转为字符串表示
     */
    public func toString(): String {
        "RemoteActorRef(${actorPath.toString()})"
    }
}

/**
 * 远程 Actor 引用工厂
 */
public class RemoteActorRefFactory {
    private let proxy: RemoteActorProxy

    public init(proxy: RemoteActorProxy) {
        this.proxy = proxy
    }

    /**
     * 创建远程 Actor 引用
     */
    public func create(path: ActorPath): RemoteActorRef {
        let addr = path.getAddress()
        RemoteActorRef(addr.host, addr.port, path, proxy)
    }

    /**
     * 创建远程 Actor 引用 (从字符串路径)
     */
    public func createFromString(pathString: String): RemoteActorRef {
        let path = ActorPathParser.parse(pathString)
        create(path)
    }

    /**
     * 批量创建远程 Actor 引用
     */
    public func createBatch(paths: Array<ActorPath>): Array<RemoteActorRef> {
        let refs = ArrayList<RemoteActorRef>()
        for (path in paths) {
            refs.add(create(path))
        }
        refs.toArray()
    }
}

/**
 * 远程 Actor 代理管理器
 */
public class RemoteActorProxyManager {
    private let proxies: HashMap<String, RemoteActorProxy>
    private let factory: RemoteActorProxyFactory
    private let lock: ReentrantReadWriteMutex

    public init() {
        this.proxies = HashMap<String, RemoteActorProxy>()
        this.factory = RemoteActorProxyFactory()
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 注册代理
     */
    public func registerProxy(nodeId: String, proxy: RemoteActorProxy): Unit {
        try {
            lock.writeMutex.lock()
            proxies.add(nodeId, proxy)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }

    /**
     * 获取代理
     */
    public func getProxy(nodeId: String): Option<RemoteActorProxy> {
        try {
            lock.readMutex.lock()
            let result = proxies.get(nodeId)
            lock.readMutex.unlock()
            return result
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return None
        }
    }

    /**
     * 创建远程引用
     */
    public func createRemoteRef(path: ActorPath): Option<RemoteActorRef> {
        let addr = path.getAddress()
        let nodeId = "${addr.host}:${addr.port}"

        try {
            lock.readMutex.lock()
            match (proxies.get(nodeId)) {
                case Some(proxy) =>
                    lock.readMutex.unlock()
                    let ref = RemoteActorRef(addr.host, addr.port, path, proxy)
                    return Some(ref)
                case None =>
                    lock.readMutex.unlock()
                    return None
            }
        } catch (e: Exception) {
            lock.readMutex.unlock()
            let empty: Option<RemoteActorRef> = None
            return empty
        }
    }

    /**
     * 获取代理数量
     */
    public func getProxyCount(): Int64 {
        try {
            lock.readMutex.lock()
            let count = proxies.size
            lock.readMutex.unlock()
            return Int64(count)
        } catch (e: Exception) {
            lock.readMutex.unlock()
            return 0
        }
    }

    /**
     * 移除代理
     */
    public func removeProxy(nodeId: String): Bool {
        try {
            lock.writeMutex.lock()
            let result = proxies.remove(nodeId)
            lock.writeMutex.unlock()
            match (result) {
                case Some(_) => true
                case None => false
            }
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            return false
        }
    }

    /**
     * 清除所有代理
     */
    public func clear(): Unit {
        try {
            lock.writeMutex.lock()
            proxies.clear()
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            lock.writeMutex.unlock()
        }
    }
}
