/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor - 模块化设计演示
 */
package cactor.examples.modular_demo

import cactor.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*
import cactor.impl.system.*
import cactor.util.*

/**
 * 简单的计算器Actor
 */
public class CalculatorActor <: UntypedActor {
    private var result: Int64 = 0

    public prop name: String {
        get() { "Calculator" }
    }

    public prop description: String {
        get() { "Simple calculator actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message.messageType()) {
            case "AddMessage" => {
                match (message) {
                    case addMsg: AddMessage => {
                        result += addMsg.getValue()
                        println("Calculator: ${addMsg.getValue()} added, result = ${result}")
                        // 发送结果回复
                        match (context.sender()) {
                            case Some(sender) => {
                                sender.tell(ResultMessage(result))
                            }
                            case None => {}
                        }
                        MessageResult.Handled
                    }
                    case _ => MessageResult.Unhandled
                }
            }
            case "SubtractMessage" => {
                match (message) {
                    case subMsg: SubtractMessage => {
                        result -= subMsg.getValue()
                        println("Calculator: ${subMsg.getValue()} subtracted, result = ${result}")
                        match (context.sender()) {
                            case Some(sender) => {
                                sender.tell(ResultMessage(result))
                            }
                            case None => {}
                        }
                        MessageResult.Handled
                    }
                    case _ => MessageResult.Unhandled
                }
            }
            case "GetResultMessage" => {
                println("Calculator: current result = ${result}")
                match (context.sender()) {
                    case Some(sender) => {
                        sender.tell(ResultMessage(result))
                    }
                    case None => {}
                }
                MessageResult.Handled
            }
            case _ => {
                println("Calculator: Unknown message type: ${message.messageType()}")
                MessageResult.Unhandled
            }
        }
    }
}

/**
 * 客户端Actor
 */
public class ClientActor <: UntypedActor {
    private let calculatorRef: Option<ActorRef>

    public init(calculatorRef: Option<ActorRef>) {
        this.calculatorRef = calculatorRef
    }

    public prop name: String {
        get() { "Client" }
    }

    public prop description: String {
        get() { "Calculator client actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message.messageType()) {
            case "StartCalculation" => {
                println("Client: Starting calculation...")
                match (calculatorRef) {
                    case Some(calc) => {
                        calc.tell(AddMessage(10), Some(context.self()))
                        calc.tell(AddMessage(20), Some(context.self()))
                        calc.tell(SubtractMessage(5), Some(context.self()))
                        calc.tell(GetResultMessage(), Some(context.self()))
                    }
                    case None => {
                        println("Client: No calculator reference!")
                    }
                }
                MessageResult.Handled
            }
            case "ResultMessage" => {
                match (message) {
                    case resultMsg: ResultMessage => {
                        println("Client: Received result: ${resultMsg.getValue()}")
                    }
                    case _ => {}
                }
                MessageResult.Handled
            }
            case _ => {
                println("Client: Unknown message: ${message.messageType()}")
                MessageResult.Unhandled
            }
        }
    }
}

/**
 * 计算消息类型
 */
public struct AddMessage <: UserMessage {
    private let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func messageType(): String {
        "AddMessage"
    }

    public func getValue(): Int64 {
        value
    }
}

public struct SubtractMessage <: UserMessage {
    private let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func messageType(): String {
        "SubtractMessage"
    }

    public func getValue(): Int64 {
        value
    }
}

public struct GetResultMessage <: UserMessage {
    public init() {}

    public func messageType(): String {
        "GetResultMessage"
    }
}

public struct ResultMessage <: UserMessage {
    private let value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func messageType(): String {
        "ResultMessage"
    }

    public func getValue(): Int64 {
        value
    }
}

public struct StartCalculationMessage <: UserMessage {
    public init() {}

    public func messageType(): String {
        "StartCalculation"
    }
}

/**
 * 主函数演示
 */
main(): Int64 {
    println("=== CACtor模块化设计演示 ===")
    
    try {
        // 创建Actor系统
        let system = CActorSystem.create("demo-system")
        println("✓ Actor系统已创建: ${system.name}")

        // 创建计算器Actor
        let calculatorProps = PropsFactory.create<CalculatorActor>(() => CalculatorActor())
        let calculatorRef = system.actorOf(calculatorProps, "calculator")
        println("✓ 计算器Actor已创建")

        // 创建客户端Actor
        let clientProps = PropsFactory.create<ClientActor>(() => ClientActor(Some(calculatorRef)))
        let clientRef = system.actorOf(clientProps, "client")
        println("✓ 客户端Actor已创建")

        // 启动计算
        clientRef.tell(StartCalculationMessage())
        println("✓ 计算已启动")

        // 等待一段时间让消息处理完成
        sleep(Duration.second * 2)

        // 关闭系统
        system.terminate()
        println("✓ Actor系统已关闭")

        println("\n=== 演示完成 ===")
        return 0

    } catch (e: Exception) {
        println("❌ 演示失败: ${e.message}")
        return 1
    }
}
