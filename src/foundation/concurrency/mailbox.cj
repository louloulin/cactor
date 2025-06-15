/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Foundation - 基础邮箱接口
 */
package cactor.foundation.concurrency

import cactor.core.message.{Message}

/**
 * 基础邮箱接口
 * Foundation层的简化版本，避免循环依赖
 */
public interface Mailbox {
    /**
     * 发送消息到邮箱
     */
    func enqueue(message: Message): Bool
    
    /**
     * 从邮箱取出消息
     */
    func dequeue(): Option<Message>
    
    /**
     * 检查邮箱是否为空
     */
    func isEmpty(): Bool
    
    /**
     * 获取邮箱中消息数量
     */
    func size(): Int64
    
    /**
     * 关闭邮箱
     */
    func close(): Unit
}
