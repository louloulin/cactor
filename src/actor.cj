/*
 * 仓颉Actor系统 - Actor核心模块
 * 基于仓颉语言特性实现的Actor模型
 */
package default

import std.sync.*
import std.collection.*
import std.time.*

// Actor状态枚举
public enum ActorState {
    | Starting    // 启动中
    | Running     // 运行中  
    | Stopping    // 停止中
    | Stopped     // 已停止
    
    public func hashCode(): Int32 {
        match (this) {
            case Starting => 0
            case Running => 1
            case Stopping => 2
            case Stopped => 3
        }
    }
    
    public static func fromHashCode(code: Int32): ActorState {
        match (code) {
            case 0 => Starting
            case 1 => Running
            case 2 => Stopping
            case 3 => Stopped
            case _ => Stopped
        }
    }
}

// Actor基础接口
public interface Actor {
    // Actor名称属性
    prop name: String
    
    // Actor描述
    prop description: String
    
    // 生命周期方法
    func started(): Unit {
        // 默认空实现
    }
    
    func stopping(): Bool {
        // 默认返回true表示可以停止
        true
    }
    
    func stopped(): Unit {
        // 默认空实现
    }
}

// 消息基础接口
public interface Message {
    func messageType(): String
    
    func priority(): Int32 {
        0  // 默认优先级
    }
}

// 消息处理结果
public enum MessageResult<T> {
    | Success(T)
    | Error(String)
    | Timeout
}

// Actor上下文
public class ActorContext {
    private let actorName: String
    private let state: AtomicInt32  // 使用原子类型保证线程安全
    private let messageQueue: ArrayList<Message>
    private let stopSignal: AtomicBool
    private let startTime: Int64
    private let queueMutex: ReentrantMutex

    public init(name: String) {
        this.actorName = name
        this.state = AtomicInt32(ActorState.Starting.hashCode())
        this.messageQueue = ArrayList<Message>()
        this.stopSignal = AtomicBool(false)
        this.startTime = 0  // 简化时间处理
        this.queueMutex = ReentrantMutex()
    }
    
    public func getName(): String {
        actorName
    }
    
    public func getState(): ActorState {
        let stateValue = state.load()
        ActorState.fromHashCode(stateValue)
    }
    
    public func setState(newState: ActorState): Unit {
        state.store(newState.hashCode())
    }
    
    public func stop(): Unit {
        stopSignal.store(true)
        setState(ActorState.Stopping)
    }
    
    public func isStopped(): Bool {
        stopSignal.load()
    }
    
    public func sendMessage(message: Message): Bool {
        if (!isStopped()) {
            queueMutex.lock()
            try {
                messageQueue.append(message)
                return true
            } finally {
                queueMutex.unlock()
            }
        } else {
            return false
        }
    }

    public func receiveMessage(): Option<Message> {
        queueMutex.lock()
        try {
            if (messageQueue.isEmpty()) {
                return None
            } else {
                let message = messageQueue[0]
                messageQueue.remove(0)
                return Some(message)
            }
        } finally {
            queueMutex.unlock()
        }
    }

    public func getUptime(): Duration {
        Duration.millisecond * 1000  // 简化实现
    }

    public func getMessageQueueSize(): Int64 {
        queueMutex.lock()
        try {
            return messageQueue.size
        } finally {
            queueMutex.unlock()
        }
    }
}

// Actor引用
public class ActorRef {
    private let actor: Actor
    private let context: ActorContext
    private let running: AtomicBool

    public init(actor: Actor, context: ActorContext) {
        this.actor = actor
        this.context = context
        this.running = AtomicBool(false)
    }

    public func send(message: Message): Bool {
        context.sendMessage(message)
    }

    public func stop(): Unit {
        context.stop()
    }

    public func getName(): String {
        context.getName()
    }

    public func getState(): ActorState {
        context.getState()
    }

    public func isRunning(): Bool {
        running.load()
    }
    
    public func run(): Unit {
        if (!running.compareAndSwap(false, true)) {
            return  // 已经在运行
        }

        try {
            context.setState(ActorState.Running)
            actor.started()

            while (!context.isStopped()) {
                match (context.receiveMessage()) {
                    case Some(message) => processMessage(message)
                    case None => sleep(Duration.millisecond)
                }
            }

            // 询问Actor是否可以停止
            if (actor.stopping()) {
                context.setState(ActorState.Stopped)
            }
        } finally {
            actor.stopped()
            running.store(false)
        }
    }
    
    private func processMessage(message: Message): Unit {
        if (message.messageType() == "StopMessage") {
            context.stop()
        } else {
            // 处理其他消息类型
            // 这里需要根据具体的Actor类型进行消息分发
            // 在具体的Actor实现中重写此方法
        }
    }
}

// 具体消息类型示例
public struct PingMessage <: Message {
    public let id: Int64
    public let timestamp: Int64

    public init(id: Int64) {
        this.id = id
        this.timestamp = 0  // 简化时间戳处理
    }

    public func messageType(): String {
        "PingMessage"
    }
}

public struct PongMessage <: Message {
    public let originalId: Int64
    public let responseTime: Int64

    public init(originalId: Int64) {
        this.originalId = originalId
        this.responseTime = 0  // 简化时间戳处理
    }

    public func messageType(): String {
        "PongMessage"
    }
}

// 停止消息
public struct StopMessage <: Message {
    public init() {}

    public func messageType(): String {
        "StopMessage"
    }

    public func priority(): Int32 {
        1000  // 高优先级
    }
}

// Actor运行时管理器
public class ActorRuntime {
    private let actors: HashMap<String, ActorRef>
    private let isShutdown: AtomicBool
    private let maxActors: Int64
    private let actorCount: AtomicInt64
    private let actorsMutex: ReentrantMutex

    public init(maxActors: Int64) {
        this.actors = HashMap<String, ActorRef>()
        this.isShutdown = AtomicBool(false)
        this.maxActors = maxActors
        this.actorCount = AtomicInt64(0)
        this.actorsMutex = ReentrantMutex()
    }

    public init() {
        this.actors = HashMap<String, ActorRef>()
        this.isShutdown = AtomicBool(false)
        this.maxActors = 1000
        this.actorCount = AtomicInt64(0)
        this.actorsMutex = ReentrantMutex()
    }

    public func spawnActor<T>(actor: T, name: String): ActorRef where T <: Actor {
        if (isShutdown.load()) {
            throw Exception("Actor runtime is shutdown")
        }

        if (actorCount.load() >= maxActors) {
            throw Exception("Maximum number of actors reached: ${maxActors}")
        }

        let context = ActorContext(name)
        let actorRef = ActorRef(actor, context)

        actorsMutex.lock()
        try {
            actors[name] = actorRef
        } finally {
            actorsMutex.unlock()
        }
        actorCount.fetchAdd(1)

        // 在新线程中启动Actor
        spawn {
            actorRef.run()
            // Actor停止后从注册表中移除
            actorsMutex.lock()
            try {
                actors.remove(name)
            } finally {
                actorsMutex.unlock()
            }
            actorCount.fetchSub(1)
        }

        return actorRef
    }

    public func find(name: String): Option<ActorRef> {
        actorsMutex.lock()
        try {
            return actors.get(name)
        } finally {
            actorsMutex.unlock()
        }
    }

    public func getActorCount(): Int64 {
        actorCount.load()
    }

    public func getAllActorNames(): Array<String> {
        actorsMutex.lock()
        try {
            let names = ArrayList<String>()
            for ((name, _) in actors) {
                names.append(name)
            }
            return names.toArray()
        } finally {
            actorsMutex.unlock()
        }
    }

    public func shutdown(): Unit {
        isShutdown.store(true)

        // 停止所有Actor
        actorsMutex.lock()
        try {
            for ((name, actorRef) in actors) {
                actorRef.stop()
            }
        } finally {
            actorsMutex.unlock()
        }

        // 等待所有Actor停止
        while (actorCount.load() > 0) {
            sleep(Duration.millisecond * 10)
        }
    }
}

// 全局运行时实例
public let globalActorRuntime = ActorRuntime()
