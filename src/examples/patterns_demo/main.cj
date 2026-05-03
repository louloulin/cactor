/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 模式演示示例
 * 展示 Stash, Pipe, Routing, Coexistence 模式
 */
package cactor.examples.patterns_demo

import std.time.*
import std.collection.*
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.core.message.{Message, MessageResult}
import cactor.core.context.{ActorContext}
import cactor.patterns.stash.*
import cactor.patterns.pipe.*
import cactor.patterns.routing.*

/**
 * StashPatternDemo - Stash 模式演示
 */
public class StashPatternDemo <: Actor {
    public prop name: String {
        get() { "StashDemo" }
    }

    public prop description: String {
        get() { "展示 Stash 模式的 Actor" }
    }

    private let stashSupport = StashSupport()
    private var isBusy = false
    private let processedMessages = ArrayList<String>()

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case stashMsg: StashDemoMessage =>
                if (this.isBusy) {
                    stashSupport.stashMessage(stashMsg)
                    println("[StashDemo] Actor 忙碌，暂存消息: ${stashMsg.content}")
                } else {
                    this.isBusy = true
                    processMessage(stashMsg)
                }
                MessageResult.Handled
            case unstashMsg: UnstashMessage =>
                unstashAll()
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }

    private func processMessage(msg: StashDemoMessage): Unit {
        println("[StashDemo] 处理消息: ${msg.content}")
        processedMessages.add(msg.content)
        this.isBusy = false

        // 处理下一个暂存消息
        match (stashSupport.unstash()) {
            case Some(nextMsg) =>
                this.isBusy = true
                processMessage(nextMsg as StashDemoMessage)
            case None =>
                println("[StashDemo] 处理完成，共处理 ${processedMessages.size} 条消息")
        }
    }

    private func unstashAll(): Unit {
        match (stashSupport.unstash()) {
            case Some(msg) =>
                processMessage(msg as StashDemoMessage)
            case None =>
                println("[StashDemo] 暂存区为空")
        }
    }
}

/**
 * StashDemoMessage
 */
public class StashDemoMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "StashDemoMessage"
    }
}

/**
 * UnstashMessage
 */
public class UnstashMessage <: Message {
    public init() {}

    public func messageType(): String {
        "UnstashMessage"
    }
}

/**
 * PipePatternDemo - Pipe 模式演示
 */
public class PipePatternDemo {
    public func demonstrate(): Unit {
        println("\n=== Pipe 模式演示 ===")

        // 使用 PipeBuilder 构建 Pipe 操作
        let builder = PipeBuilder()
            .onSuccess({ value, ctx =>
                println("[Pipe] 处理成功结果: ${value}")
            })
            .onFailure({ reason, ctx =>
                println("[Pipe] 处理失败原因: ${reason}")
            })

        // 执行成功路径
        println("\n1. 执行成功路径:")
        builder.executeSuccess("计算结果: 42")

        // 执行失败路径
        println("\n2. 执行失败路径:")
        builder.executeFailure("连接超时")

        // 创建 PipeMessage
        println("\n3. 创建 PipeMessage:")
        let successMsg = PipeMessage.success("异步操作成功")
        let failureMsg = PipeMessage.failure("操作失败")

        println("[Pipe] 成功消息: isSuccess=${successMsg.isSuccess}, value=${successMsg.value}")
        println("[Pipe] 失败消息: isSuccess=${failureMsg.isSuccess}, error=${failureMsg.error}")
    }
}

/**
 * RoutingPatternDemo - 路由模式演示
 */
public class RoutingPatternDemo {
    public func demonstrate(): Unit {
        println("\n=== 路由模式演示 ===")

        // 创建模拟 ActorRef
        let ref1 = MockRouteeRef("routee-1")
        let ref2 = MockRouteeRef("routee-2")
        let ref3 = MockRouteeRef("routee-3")

        // 测试 RoundRobin 路由
        println("\n1. RoundRobin 路由:")
        let roundRobinRouter = RouterFactory.roundRobin()
        roundRobinRouter.addRoutee(ref1)
        roundRobinRouter.addRoutee(ref2)
        roundRobinRouter.addRoutee(ref3)

        let routees = roundRobinRouter.getRoutees()
        println("[RoundRobin] 路由目标数: ${routees.size}")

        // 测试 Broadcast 路由
        println("\n2. Broadcast 路由:")
        let broadcastRouter = RouterFactory.broadcast()
        broadcastRouter.addRoutee(ref1)
        broadcastRouter.addRoutee(ref2)

        let broadcastRoutees = broadcastRouter.getRoutees()
        println("[Broadcast] 路由目标数: ${broadcastRoutees.size}")

        // 测试 RecipientList
        println("\n3. RecipientList:")
        let recipientList = RecipientList()
        recipientList.addRecipient(ref1)
        recipientList.addRecipient(ref2)
        println("[RecipientList] 接收者数量: ${recipientList.size()}")

        // 测试 ScatterGather
        println("\n4. ScatterGatherFirstCompleted:")
        let sg = ScatterGatherFirstCompleted()
        sg.withTimeout(Duration.second * 1)
        println("[ScatterGather] 超时设置: ${Duration.second * 1}")
    }
}

/**
 * CoexistencePatternDemo - Coexistences 模式演示
 */
public class CoexistencePatternDemo {
    public func demonstrate(): Unit {
        println("\n=== Coexistences 模式演示 ===")

        // 演示 TypeAdapter
        println("\n1. TypeAdapter:")
        let adapter = MessageAdapter(
            toUntyped: { msg => msg },
            toTyped: { msg => msg }
        )
        println("[TypeAdapter] 适配器创建成功")

        // 演示 MixedMessageRouter
        println("\n2. MixedMessageRouter:")
        let router = MixedMessageRouter()
        let mockRef = MockRouteeRef("typed-target")
        router.addRoute("TestMessage", mockRef)
        let routes = router.getRoutes()
        println("[MixedMessageRouter] 路由规则数: ${routes.size}")

        // 演示 SystemCoordinator
        println("\n3. SystemCoordinator:")
        let coordinator = SystemCoordinator()
        let systems = coordinator.listSystems()
        println("[SystemCoordinator] 注册系统数: ${systems.size}")

        // 演示 CoexistenceConfig
        println("\n4. CoexistenceConfig:")
        let config = CoexistenceConfig.defaultConfig()
        println("[Config] 跨系统通信: ${config.enableCrossSystem}")
        println("[Config] 最大重试次数: ${config.maxRetries}")
    }
}

/**
 * MockRouteeRef - 用于演示的 Mock ActorRef
 */
class MockRouteeRef <: ActorRef {
    private let name: String
    private let mockPath: ActorPath
    private let sentMessages: ArrayList<Message>

    public init(name: String) {
        this.name = name
        this.mockPath = ActorPath("mock", "/${name}")
        this.sentMessages = ArrayList<Message>()
    }

    public prop path: ActorPath {
        get() { mockPath }
    }

    public func tell(message: Message): Unit {
        sentMessages.add(message)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        sentMessages.add(message)
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case mock: MockRouteeRef => name == mock.name
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        name.hashCode()
    }

    public func getSentMessages(): ArrayList<Message> {
        sentMessages
    }
}

/**
 * 主演示函数
 */
main(args: Array<String>): Unit {
    println("=".repeat(50))
    println("CActor 模式演示")
    println("=".repeat(50))

    // Stash 模式演示
    let stashDemo = StashPatternDemo()
    println("\n[StashDemo] 创建成功")

    // Pipe 模式演示
    let pipeDemo = PipePatternDemo()
    pipeDemo.demonstrate()

    // Routing 模式演示
    let routingDemo = RoutingPatternDemo()
    routingDemo.demonstrate()

    // Coexistences 模式演示
    let coexistenceDemo = CoexistencePatternDemo()
    coexistenceDemo.demonstrate()

    println("\n" + "=".repeat(50))
    println("CActor 模式演示完成!")
    println("=".repeat(50))
}
