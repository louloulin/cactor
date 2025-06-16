/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API 2.0 - ActorRef增强API
 * 为ActorRef添加便利的消息发送方法
 */
package cactor.api

import cactor.core.actor.{ActorRef}
import cactor.core.message.{Message}

/**
 * ActorRef增强API
 * 提供更便利的消息发送方法
 */

/**
 * 类型安全的消息发送
 * @param actorRef Actor引用
 * @param message 消息
 */
public func send<T>(actorRef: ActorRef, message: T): Unit where T <: Message {
    actorRef.tell(message)
}

/**
 * 批量消息发送
 * @param actorRef Actor引用
 * @param messages 消息数组
 */
public func sendBatch(actorRef: ActorRef, messages: Array<Message>): Unit {
    for (message in messages) {
        actorRef.tell(message)
    }
}

/**
 * 条件消息发送
 * @param actorRef Actor引用
 * @param message 消息
 * @param condition 条件函数
 */
public func sendIf(actorRef: ActorRef, message: Message, condition: () -> Bool): Unit {
    if (condition()) {
        actorRef.tell(message)
    }
}

/**
 * 带发送者的消息发送
 * @param actorRef Actor引用
 * @param message 消息
 * @param sender 发送者路径
 */
public func sendFrom(actorRef: ActorRef, message: Message, sender: String): Unit {
    actorRef.tell(message, Some(sender))
}

/**
 * 广播消息到多个ActorRef
 * @param actorRefs Actor引用数组
 * @param message 消息
 */
public func broadcast(actorRefs: Array<ActorRef>, message: Message): Unit {
    for (actorRef in actorRefs) {
        actorRef.tell(message)
    }
}

/**
 * 获取Actor路径字符串
 * @param actorRef Actor引用
 * @return 路径字符串
 */
public func getPathString(actorRef: ActorRef): String {
    actorRef.path.toString()
}
