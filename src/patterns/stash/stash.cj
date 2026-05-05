/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Stash Pattern 实现
 * 允许 Actor 临时存储消息，稍后处理
 */
package cactor.patterns.stash

import std.collection.*
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.Actor

/**
 * StashedMessage - 存储的消息及其元数据
 */
public class StashedMessage {
    public let message: Message
    public let timestamp: Int64

    public init(message: Message) {
        this.message = message
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * StashPolicy - 定义stash行为策略
 */
public enum StashPolicy {
    | Unlimited  // 无限制
    | SizeLimited(Int64)  // 限制最大数量
}

/**
 * StashOverflowBehavior - 溢出行为
 */
public enum StashOverflowBehavior {
    | DropOldest    // 丢弃最旧的
    | DropNewest    // 丢弃最新的
    | ThrowException // 抛出异常
}

/**
 * StashSettings - Stash配置
 */
public class StashSettings {
    public var policy: StashPolicy
    public var overflowBehavior: StashOverflowBehavior

    public init() {
        this.policy = StashPolicy.Unlimited
        this.overflowBehavior = StashOverflowBehavior.ThrowException
    }

    public static func defaultSettings(): StashSettings {
        StashSettings()
    }

    public static func withMaxSize(maxSize: Int64): StashSettings {
        let settings = StashSettings()
        settings.policy = StashPolicy.SizeLimited(maxSize)
        settings
    }
}

/**
 * Stash 接口 - 提供消息暂存功能
 */
public interface Stash {
    func stash(): Unit
    func unstashAll(): Unit
    func unstash(): Option<Message>
    func stashSize(): Int64
    func isStashEmpty(): Bool
}

/**
 * StashSupport - 为 Actor 提供 stash 能力的混入特质
 */
public class StashSupport <: Stash {
    private var stashedMessages: ArrayList<StashedMessage>

    public init() {
        this.stashedMessages = ArrayList<StashedMessage>()
    }

    public func stash(): Unit {
        // 子类应重写此方法来暂存当前正在处理的消息
    }

    public func stashMessage(message: Message): Unit {
        let stashed = StashedMessage(message)
        stashedMessages.add(stashed)
    }

    public func unstashAll(): Unit {
        // 子类应重写此方法来按顺序处理所有暂存的消息
    }

    public func unstash(): Option<Message> {
        if (stashedMessages.isEmpty()) {
            return None
        }
        let msg = stashedMessages[0]
        stashedMessages.remove(0..1)
        Some(msg.message)
    }

    public func stashSize(): Int64 {
        Int64(stashedMessages.size)
    }

    public func isStashEmpty(): Bool {
        stashedMessages.isEmpty()
    }

    public func clearStash(): Unit {
        stashedMessages.clear()
    }

    public func getStashedMessages(): ArrayList<StashedMessage> {
        let copy = ArrayList<StashedMessage>()
        for (msg in stashedMessages) {
            copy.add(msg)
        }
        copy
    }

    public func filterStash(predicate: (Message) -> Bool): Int64 {
        var removed: Int64 = 0
        let toKeep = ArrayList<StashedMessage>()
        for (msg in stashedMessages) {
            if (predicate(msg.message)) {
                toKeep.add(msg)
            } else {
                removed += 1
            }
        }
        stashedMessages = toKeep
        removed
    }
}

/**
 * BoundedStash - 带容量限制的Stash实现
 */
public class BoundedStash <: Stash {
    private var stashedMessages: ArrayList<StashedMessage>
    private var settings: StashSettings

    public init() {
        this.stashedMessages = ArrayList<StashedMessage>()
        this.settings = StashSettings.defaultSettings()
    }

    public static func create(settings: StashSettings): BoundedStash {
        let stash = BoundedStash()
        stash.settings = settings
        stash
    }

    public func stash(): Unit {
        // 由使用方实现
    }

    public func stashMessage(message: Message): Unit {
        match (settings.policy) {
            case StashPolicy.Unlimited =>
                stashedMessages.add(StashedMessage(message))
            case StashPolicy.SizeLimited(maxSize) =>
                if (Int64(stashedMessages.size) >= maxSize) {
                    match (settings.overflowBehavior) {
                        case StashOverflowBehavior.DropOldest =>
                            if (!stashedMessages.isEmpty()) {
                                stashedMessages.remove(0..1)
                            }
                        case StashOverflowBehavior.DropNewest =>
                            // 不添加新消息
                            return
                        case StashOverflowBehavior.ThrowException =>
                            throw Exception("Stash overflow: max size ${maxSize} exceeded")
                    }
                }
                stashedMessages.add(StashedMessage(message))
        }
    }

    public func unstashAll(): Unit {
        // 由使用方实现
    }

    public func unstash(): Option<Message> {
        if (stashedMessages.isEmpty()) {
            return None
        }
        let msg = stashedMessages[0]
        stashedMessages.remove(0..1)
        Some(msg.message)
    }

    public func stashSize(): Int64 {
        Int64(stashedMessages.size)
    }

    public func isStashEmpty(): Bool {
        stashedMessages.isEmpty()
    }

    public func clearStash(): Unit {
        stashedMessages.clear()
    }
}
