/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Actor系统接口
 * 管理整个Actor系统的生命周期和配置
 */
package cactor.core.system

import std.time.*
import std.sync.*


/**
 * 简化的Actor系统接口
 * 管理整个Actor系统的生命周期和配置
 */
public interface ActorSystem {
    /**
     * 系统名称
     */
    prop name: String

    /**
     * 终止Actor系统
     * 这将停止所有Actor并释放资源
     */
    func terminate(): Unit
}

/**
 * 简化的调度器接口
 * 提供定时任务调度功能
 */
public interface Scheduler {
    /**
     * 停止调度器
     */
    func shutdown(): Unit
}

/**
 * 可取消的任务接口
 */
public interface Cancellable {
    /**
     * 取消任务
     * @return 是否成功取消
     */
    func cancel(): Bool

    /**
     * 检查任务是否已取消
     * @return 是否已取消
     */
    func isCancelled(): Bool
}

/**
 * 简化的Cancellable实现
 */
public class SimpleCancellable <: Cancellable {
    private let cancelled: AtomicBool

    public init() {
        this.cancelled = AtomicBool(false)
    }

    public func cancel(): Bool {
        cancelled.compareAndSwap(false, true)
    }

    public func isCancelled(): Bool {
        cancelled.load()
    }
}
