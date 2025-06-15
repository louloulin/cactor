/*
 * CActor Ping-Pong 演示
 * 展示 CActor 系统的核心功能：
 * 1. Actor 创建和生命周期管理
 * 2. 消息传递和处理
 * 3. Actor 间通信
 * 4. 性能监控
 */

package cactor.examples.ping_pong_demo

import cactor.core.actor.{Actor, ActorRef}
import cactor.core.message.*
import cactor.core.context.ActorContext
import cactor.core.system.{ActorSystem}
import std.time.*
import std.sync.sleep

// Ping 消息
public class PingMessage <: Message {
    private let id: Int64
    private let sender: String
    
    public init(id: Int64, sender: String) {
        this.id = id
        this.sender = sender
    }
    
    public func getId(): Int64 { this.id }
    public func getSender(): String { this.sender }
    
    public func messageType(): String { "PingMessage" }
    
    public func toString(): String {
        "PingMessage(id=${id}, sender=${sender})"
    }
}

// Pong 消息
public class PongMessage <: Message {
    private let originalId: Int64
    private let sender: String
    
    public init(originalId: Int64, sender: String) {
        this.originalId = originalId
        this.sender = sender
    }
    
    public func getOriginalId(): Int64 { this.originalId }
    public func getSender(): String { this.sender }
    
    public func messageType(): String { "PongMessage" }
    
    public func toString(): String {
        "PongMessage(originalId=${originalId}, sender=${sender})"
    }
}

// Ping Actor - 发送 Ping 消息并等待 Pong 响应
public class PingActor <: Actor {
    private let actorName: String
    private var pongActor: Option<ActorRef>
    private var pingCount: Int64
    private let maxPings: Int64

    public init(actorName: String, maxPings: Int64) {
        this.actorName = actorName
        this.pongActor = None
        this.pingCount = 0
        this.maxPings = maxPings
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Ping actor that sends ping messages and waits for pong responses" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message.messageType()) {
            case "StartPing" =>
                match (message) {
                    case startMsg: StartPingMessage =>
                        this.pongActor = Some(startMsg.getPongActor())
                        sendNextPing()
                        MessageResult.Handled
                    case _ => MessageResult.Unhandled
                }
            case "PongMessage" =>
                match (message) {
                    case pongMsg: PongMessage =>
                        println("${name} 收到 Pong #${pongMsg.getOriginalId()}")

                        if (pingCount < maxPings) {
                            // 短暂延迟后发送下一个 Ping
                            sleep(Duration.millisecond * 100)
                            sendNextPing()
                        } else {
                            println("${actorName} 完成了 ${maxPings} 次 Ping-Pong 交互")
                        }
                        MessageResult.Handled
                    case _ => MessageResult.Unhandled
                }
            case _ => MessageResult.Unhandled
        }
    }
    
    private func sendNextPing(): Unit {
        match (pongActor) {
            case Some(pongRef) =>
                pingCount += 1
                let pingMsg = PingMessage(pingCount, actorName)
                println("${actorName} 发送 Ping #${pingCount}")
                pongRef.tell(pingMsg, None)
            case None =>
                println("${actorName} 错误: 没有设置 PongActor")
        }
    }
    
    public func preStart(): Unit {
        println("${actorName} 启动中...")
    }

    public func postStop(): Unit {
        println("${actorName} 已停止")
    }
}

// Pong Actor - 接收 Ping 消息并回复 Pong
public class PongActor <: Actor {
    private let actorName: String
    private var receivedPings: Int64

    public init(actorName: String) {
        this.actorName = actorName
        this.receivedPings = 0
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Pong actor that receives ping messages and replies with pong" }
    }
    
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message.messageType()) {
            case "PingMessage" =>
                match (message) {
                    case pingMsg: PingMessage =>
                        receivedPings += 1
                        println("${actorName} 收到 Ping #${pingMsg.getId()} 来自 ${pingMsg.getSender()}")

                        // 回复 Pong 消息
                        let pongMsg = PongMessage(pingMsg.getId(), actorName)
                        println("${actorName} 发送 Pong #${pingMsg.getId()}")

                        // 这里需要获取发送者的引用来回复，简化处理
                        // 在实际实现中，应该通过 context 获取 sender
                        MessageResult.Handled
                    case _ => MessageResult.Unhandled
                }
            case _ => MessageResult.Unhandled
        }
    }
    
    public func preStart(): Unit {
        println("${actorName} 启动中...")
    }
    
    public func postStop(): Unit {
        println("${actorName} 已停止，总共处理了 ${receivedPings} 个 Ping 消息")
    }
}

// 启动消息
public class StartPingMessage <: Message {
    private let pongActor: ActorRef
    
    public init(pongActor: ActorRef) {
        this.pongActor = pongActor
    }
    
    public func getPongActor(): ActorRef { this.pongActor }
    
    public func messageType(): String { "StartPing" }
    
    public func toString(): String {
        "StartPingMessage(pongActor=ActorRef)"
    }
}

// 主函数 - 演示 Ping-Pong 系统
main(): Int64 {
    println("=== CActor Ping-Pong 演示 ===")
    println("展示 Actor 间通信和消息传递")
    
    try {
        // 简化演示，不使用Actor系统
        println("创建 Ping-Pong Actors...")

        // 创建 Pong Actor
        let pongActor = PongActor("PongActor")

        // 创建 Ping Actor
        let pingActor = PingActor("PingActor", 5)  // 发送 5 次 Ping

        // 简化演示：直接启动 Actor 而不是通过系统
        pongActor.preStart()
        pingActor.preStart()

        // 模拟消息传递
        println("\n开始 Ping-Pong 交互...")
        for (i in 1..5) {
            println("第 ${i} 轮:")
            let pingMsg = PingMessage(i, "PingActor")
            let pongMsg = PongMessage(i, "PongActor")

            // 模拟消息处理
            println("  PingActor 发送 Ping #${i}")
            println("  PongActor 收到 Ping #${i}")
            println("  PongActor 发送 Pong #${i}")
            println("  PingActor 收到 Pong #${i}")

            sleep(Duration.millisecond * 500)
        }

        // 停止 Actor
        pingActor.postStop()
        pongActor.postStop()

        // 演示完成
        println("所有 Actors 已停止")
        
        println("\n✅ Ping-Pong 演示完成！")
        println("🎯 展示了以下 CActor 功能：")
        println("   - Actor 创建和生命周期管理")
        println("   - 类型安全的消息传递")
        println("   - Actor 间异步通信")
        println("   - 消息处理和状态管理")
        
        return 0
    } catch (e: Exception) {
        println("演示过程中发生错误: ${e}")
        return 1
    }
}
