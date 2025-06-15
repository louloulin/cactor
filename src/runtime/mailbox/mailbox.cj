/*
 * Copyright (c) 2024. All rights reserved.
 * Runtime Layer - 邮箱接口
 * 定义Actor邮箱的基本操作接口
 */
package cactor.runtime.mailbox

import cactor.core.message.Envelope

/**
 * 邮箱接口
 * 负责存储和管理Actor的消息队列
 */
public interface Mailbox {
    /**
     * 将消息入队
     * @param envelope 要入队的消息信封
     * @return 是否成功入队
     */
    func enqueue(envelope: Envelope): Bool

    /**
     * 从队列中取出消息
     * @return 消息信封，如果队列为空则返回None
     */
    func dequeue(): Option<Envelope>

    /**
     * 检查邮箱是否为空
     * @return 是否为空
     */
    func isEmpty(): Bool

    /**
     * 获取邮箱中消息的数量
     * @return 消息数量
     */
    func size(): Int64

    /**
     * 清空邮箱
     */
    func clear(): Unit
}
