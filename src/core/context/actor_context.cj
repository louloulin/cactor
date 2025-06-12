/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor上下文
 * 提供Actor运行时的环境和服务
 */
package cactor.core.context

import std.time.*

/**
 * 简化的Actor上下文接口
 * 提供Actor运行时的基础服务
 */
public interface ActorContext {
    /**
     * 获取当前消息的发送者
     * @return 发送者的路径，如果没有则为None
     */
    func sender(): Option<String>
}
