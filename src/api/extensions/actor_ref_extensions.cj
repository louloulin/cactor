/*
 * Copyright (c) 2024. All rights reserved.
 * CActor API - ActorRef扩展
 * 基于api.md设计，扩展现有ActorRef接口，提供便利的tell/ask方法
 */
package cactor.api.extensions

import cactor.core.actor.{ActorRef}
import cactor.core.message.{Message}

/**
 * ActorRef扩展 - 添加便利的消息发送方法
 * 由于Cangjie不允许扩展接口，使用静态方法
 */

/**
 * ActorRef便利工厂方法
 */
public struct ActorRefExtensions {
    /**
     * 带发送者的便利方法
     */
    public static func tellFrom(actorRef: ActorRef, message: Message, from: ActorRef): Unit {
        actorRef.tell(message, Some(from.path.toString()))
    }

    /**
     * 获取Actor路径字符串
     */
    public static func getPathString(actorRef: ActorRef): String {
        actorRef.path.toString()
    }

    /**
     * 批量发送消息
     */
    public static func tellBatch(actorRef: ActorRef, messages: Array<Message>): Unit {
        for (message in messages) {
            actorRef.tell(message)
        }
    }

    /**
     * 广播消息到多个ActorRef
     */
    public static func broadcast(actorRefs: Array<ActorRef>, message: Message): Unit {
        for (actorRef in actorRefs) {
            actorRef.tell(message)
        }
    }

    /**
     * 条件发送消息
     */
    public static func tellIf(actorRef: ActorRef, message: Message, condition: () -> Bool): Unit {
        if (condition()) {
            actorRef.tell(message)
        }
    }
}
