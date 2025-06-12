/*
 * 仓颉Actor系统 - 乒乓球示例
 * 演示基础的Actor消息传递
 */
package cangjie_actor.examples.ping_pong

import cangjie_actor.*
import std.time.*

// 乒乓球Actor
public class PingPongActor <: Actor {
    private let actorName: String
    private var messageCount: Int64 = 0
    
    public init(name: String) {
        this.actorName = name
    }
    
    public prop name: String {
        get() { actorName }
    }
    
    public prop description: String {
        get() { "Ping-Pong Actor: ${actorName}" }
    }
    
    public func started(): Unit {
        println("${actorName} Actor started")
    }
    
    public func stopped(): Unit {
        println("${actorName} Actor stopped, processed ${messageCount} messages")
    }
    
    public func processMessage(message: Message): Unit {
        messageCount += 1
        
        match (message.messageType()) {
            case "PingMessage" => {
                let pingMsg = message as PingMessage
                println("${actorName} received Ping #${pingMsg.id}")
                
                // 模拟处理时间
                sleep(Duration.millisecond * 100)
                
                // 这里可以发送Pong消息给发送者
                // 在实际实现中需要消息发送者信息
            }
            case "PongMessage" => {
                let pongMsg = message as PongMessage
                println("${actorName} received Pong for #${pongMsg.originalId}")
            }
            case _ => {
                println("${actorName} received unknown message: ${message.messageType()}")
            }
        }
    }
}

// 扩展ActorRef以支持消息处理
extend ActorRef {
    public func processActorMessage(message: Message): Unit {
        // 获取具体的Actor实例并处理消息
        // 这是一个简化的实现，实际中需要更复杂的消息分发机制
        match (this.actor) {
            case pingPongActor is PingPongActor => {
                pingPongActor.processMessage(message)
            }
            case _ => {
                println("Unknown actor type for message processing")
            }
        }
    }
}

// 主函数演示
func main(): Unit {
    println("=== 仓颉Actor系统 - 乒乓球示例 ===")
    
    // 创建运行时
    let runtime = ActorRuntime()
    
    try {
        // 创建两个Actor
        let pingActor = PingPongActor("Ping")
        let pongActor = PingPongActor("Pong")
        
        // 启动Actor
        let pingRef = runtime.spawnActor(pingActor, "ping-actor")
        let pongRef = runtime.spawnActor(pongActor, "pong-actor")
        
        println("Actors started, current count: ${runtime.getActorCount()}")
        
        // 等待Actor启动
        sleep(Duration.millisecond * 100)
        
        // 发送一些消息
        for (i in 1..5) {
            let pingMessage = PingMessage(i)
            pingRef.send(pingMessage)
            
            let pongMessage = PongMessage(i)
            pongRef.send(pongMessage)
            
            sleep(Duration.millisecond * 50)
        }
        
        // 等待消息处理完成
        sleep(Duration.second * 2)
        
        // 停止Actor
        println("Stopping actors...")
        pingRef.stop()
        pongRef.stop()
        
        // 等待Actor停止
        sleep(Duration.millisecond * 500)
        
        println("Final actor count: ${runtime.getActorCount()}")
        
    } catch (e: Exception) {
        println("Error: ${e}")
    } finally {
        // 关闭运行时
        runtime.shutdown()
        println("Runtime shutdown complete")
    }
    
    println("=== 示例结束 ===")
}

// 计算器Actor示例
public class CalculatorActor <: Actor {
    private var value: Int64 = 0
    private let lock: Mutex = Mutex()
    
    public prop name: String {
        get() { "Calculator" }
    }
    
    public prop description: String {
        get() { "Simple calculator actor" }
    }
    
    public func started(): Unit {
        println("Calculator Actor started")
    }
    
    public func stopped(): Unit {
        println("Calculator Actor stopped, final value: ${getValue()}")
    }
    
    public func add(operand: Int64): Int64 {
        lock.lock()
        defer { lock.unlock() }
        value += operand
        return value
    }
    
    public func subtract(operand: Int64): Int64 {
        lock.lock()
        defer { lock.unlock() }
        value -= operand
        return value
    }
    
    public func getValue(): Int64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    
    public func reset(): Unit {
        lock.lock()
        defer { lock.unlock() }
        value = 0
    }
}

// 计算器消息类型
public struct AddMessage <: Message {
    public let operand: Int64
    
    public init(operand: Int64) {
        this.operand = operand
    }
    
    public func messageType(): String {
        "AddMessage"
    }
}

public struct SubtractMessage <: Message {
    public let operand: Int64
    
    public init(operand: Int64) {
        this.operand = operand
    }
    
    public func messageType(): String {
        "SubtractMessage"
    }
}

public struct GetValueMessage <: Message {
    public init() {}
    
    public func messageType(): String {
        "GetValueMessage"
    }
}
