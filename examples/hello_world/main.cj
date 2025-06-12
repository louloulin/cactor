/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Hello World 示例
 * 
 * 这个示例展示了如何创建一个简单的Actor并发送消息
 */
package cactor.examples.hello_world

import std.time.*
import cactor.core.message.{Message, StringMessage}
import cactor.core.actor.{Actor, ActorContext}
import cactor.runtime.SimpleActorSystem
import cactor.logging.{LoggerFactory, LogLevel}

/**
 * Hello World Actor
 * 接收字符串消息并打印问候语
 */
public class HelloWorldActor <: Actor {
    private let name: String
    private let messageCount: AtomicInt64
    
    public init(name: String) {
        this.name = name
        this.messageCount = AtomicInt64(0)
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case msg: StringMessage => 
                let count = messageCount.fetchAdd(1) + 1
                let content = msg.getContent()
                println("🎭 Actor[${name}] 收到第${count}条消息: ${content}")
                
                // 如果收到"goodbye"消息，回复并停止
                if (content.toLowerCase() == "goodbye") {
                    println("👋 Actor[${name}] 说再见！")
                    context.stop()
                }
            case _ => 
                println("⚠️ Actor[${name}] 收到未知消息类型")
        }
    }
    
    public func preStart(): Unit {
        println("🚀 Actor[${name}] 启动了！")
    }
    
    public func postStop(): Unit {
        println("🛑 Actor[${name}] 停止了！总共处理了${messageCount.load()}条消息")
    }
}

/**
 * 聊天室Actor
 * 管理多个用户Actor并转发消息
 */
public class ChatRoomActor <: Actor {
    private let users: ArrayList<String>
    private let logger = LoggerFactory.getLogger("ChatRoom")
    
    public init() {
        this.users = ArrayList<String>()
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case msg: StringMessage => 
                let content = msg.getContent()
                
                if (content.startsWith("join:")) {
                    let userName = content.substring(5)
                    users.append(userName)
                    logger.info("用户 ${userName} 加入聊天室，当前用户数: ${users.size}")
                    println("📢 欢迎 ${userName} 加入聊天室！")
                } else if (content.startsWith("leave:")) {
                    let userName = content.substring(6)
                    // 简化的移除实现
                    let newUsers = ArrayList<String>()
                    for (user in users) {
                        if (user != userName) {
                            newUsers.append(user)
                        }
                    }
                    users.clear()
                    for (user in newUsers) {
                        users.append(user)
                    }
                    logger.info("用户 ${userName} 离开聊天室，当前用户数: ${users.size}")
                    println("👋 ${userName} 离开了聊天室")
                } else if (content.startsWith("msg:")) {
                    let message = content.substring(4)
                    logger.info("广播消息: ${message}")
                    println("💬 聊天室广播: ${message}")
                } else {
                    println("❓ 聊天室收到未知命令: ${content}")
                }
            case _ => 
                println("⚠️ 聊天室收到未知消息类型")
        }
    }
    
    public func preStart(): Unit {
        println("🏠 聊天室开启了！")
    }
    
    public func postStop(): Unit {
        println("🏠 聊天室关闭了！")
    }
}

/**
 * 计数器Actor
 * 演示状态管理和原子操作
 */
public class CounterActor <: Actor {
    private let counter: AtomicInt64
    private let maxCount: Int64
    
    public init(maxCount: Int64) {
        this.counter = AtomicInt64(0)
        this.maxCount = maxCount
    }
    
    public func receive(message: Message, context: ActorContext): Unit {
        match (message) {
            case msg: StringMessage => 
                let command = msg.getContent()
                
                if (command == "increment") {
                    let newValue = counter.fetchAdd(1) + 1
                    println("📈 计数器增加到: ${newValue}")
                    
                    if (newValue >= maxCount) {
                        println("🎯 计数器达到最大值 ${maxCount}，停止Actor")
                        context.stop()
                    }
                } else if (command == "decrement") {
                    let newValue = counter.fetchAdd(-1) - 1
                    println("📉 计数器减少到: ${newValue}")
                } else if (command == "get") {
                    println("📊 当前计数器值: ${counter.load()}")
                } else if (command == "reset") {
                    counter.store(0)
                    println("🔄 计数器重置为: 0")
                } else {
                    println("❓ 未知命令: ${command}")
                }
            case _ => 
                println("⚠️ 计数器收到未知消息类型")
        }
    }
}

/**
 * 主函数 - Hello World 示例
 */
main(): Int64 {
    println("🌟 === CActor Hello World 示例 ===")
    
    try {
        // 1. 基础Hello World演示
        println("\n1️⃣ 基础Hello World演示")
        testBasicHelloWorld()
        
        // 2. 聊天室演示
        println("\n2️⃣ 聊天室演示")
        testChatRoom()
        
        // 3. 计数器演示
        println("\n3️⃣ 计数器演示")
        testCounter()
        
        // 4. 多Actor协作演示
        println("\n4️⃣ 多Actor协作演示")
        testMultiActorCollaboration()
        
        println("\n🎉 所有示例运行完成！")
        return 0
    } catch (e: Exception) {
        println("❌ 示例运行失败: ${e.message}")
        return 1
    }
}

/**
 * 基础Hello World测试
 */
func testBasicHelloWorld(): Unit {
    println("   创建Hello World Actor...")
    let helloActor = HelloWorldActor("Alice")
    
    // 模拟Actor系统
    let context = MockActorContext()
    
    // 发送一些消息
    println("   发送问候消息...")
    helloActor.preStart()
    helloActor.receive(StringMessage("Hello, CACtor!"), context)
    helloActor.receive(StringMessage("How are you?"), context)
    helloActor.receive(StringMessage("Nice to meet you!"), context)
    helloActor.receive(StringMessage("goodbye"), context)
    helloActor.postStop()
    
    println("   ✅ 基础Hello World演示完成")
}

/**
 * 聊天室测试
 */
func testChatRoom(): Unit {
    println("   创建聊天室...")
    let chatRoom = ChatRoomActor()
    let context = MockActorContext()
    
    chatRoom.preStart()
    
    // 用户加入
    println("   用户加入聊天室...")
    chatRoom.receive(StringMessage("join:Alice"), context)
    chatRoom.receive(StringMessage("join:Bob"), context)
    chatRoom.receive(StringMessage("join:Charlie"), context)
    
    // 发送消息
    println("   发送聊天消息...")
    chatRoom.receive(StringMessage("msg:大家好！"), context)
    chatRoom.receive(StringMessage("msg:今天天气真好"), context)
    
    // 用户离开
    println("   用户离开聊天室...")
    chatRoom.receive(StringMessage("leave:Bob"), context)
    chatRoom.receive(StringMessage("msg:Bob离开了"), context)
    
    chatRoom.postStop()
    println("   ✅ 聊天室演示完成")
}

/**
 * 计数器测试
 */
func testCounter(): Unit {
    println("   创建计数器Actor...")
    let counter = CounterActor(5)
    let context = MockActorContext()
    
    // 测试计数器操作
    println("   测试计数器操作...")
    counter.receive(StringMessage("get"), context)
    counter.receive(StringMessage("increment"), context)
    counter.receive(StringMessage("increment"), context)
    counter.receive(StringMessage("get"), context)
    counter.receive(StringMessage("decrement"), context)
    counter.receive(StringMessage("get"), context)
    counter.receive(StringMessage("reset"), context)
    counter.receive(StringMessage("get"), context)
    
    // 测试达到最大值
    println("   测试达到最大值...")
    for (i in 0..6) {
        counter.receive(StringMessage("increment"), context)
    }
    
    println("   ✅ 计数器演示完成")
}

/**
 * 多Actor协作测试
 */
func testMultiActorCollaboration(): Unit {
    println("   创建多个Actor...")
    let alice = HelloWorldActor("Alice")
    let bob = HelloWorldActor("Bob")
    let counter = CounterActor(3)
    let chatRoom = ChatRoomActor()
    
    let context = MockActorContext()
    
    // 启动所有Actor
    println("   启动所有Actor...")
    alice.preStart()
    bob.preStart()
    chatRoom.preStart()
    
    // 模拟协作场景
    println("   模拟协作场景...")
    chatRoom.receive(StringMessage("join:Alice"), context)
    chatRoom.receive(StringMessage("join:Bob"), context)
    
    alice.receive(StringMessage("Hello from Alice!"), context)
    bob.receive(StringMessage("Hello from Bob!"), context)
    
    counter.receive(StringMessage("increment"), context)
    chatRoom.receive(StringMessage("msg:计数器增加了"), context)
    
    counter.receive(StringMessage("increment"), context)
    counter.receive(StringMessage("increment"), context)
    
    alice.receive(StringMessage("goodbye"), context)
    bob.receive(StringMessage("goodbye"), context)
    
    // 停止所有Actor
    println("   停止所有Actor...")
    alice.postStop()
    bob.postStop()
    chatRoom.postStop()
    
    println("   ✅ 多Actor协作演示完成")
}

/**
 * 模拟Actor上下文
 */
public class MockActorContext <: ActorContext {
    private let stopped: AtomicBool
    
    public init() {
        this.stopped = AtomicBool(false)
    }
    
    public func stop(): Unit {
        stopped.store(true)
        println("🛑 Actor上下文请求停止")
    }
    
    public func isStopped(): Bool {
        stopped.load()
    }
}
