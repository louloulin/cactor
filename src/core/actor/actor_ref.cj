/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Actor引用系统
 * 提供与Actor交互的统一接口
 */
package cactor.core.actor

import std.time.*
import cactor.core.message.{Message, Envelope}

/**
 * Actor引用接口
 * 提供与Actor交互的统一接口
 */
public interface ActorRef {
    /**
     * Actor的路径
     */
    prop path: ActorPath

    /**
     * 发送消息给Actor (tell模式)
     * 这是异步的，不等待响应
     * @param message 要发送的消息
     */
    func tell(message: Message): Unit

    /**
     * 发送消息给Actor，指定发送者 (tell模式)
     * @param message 要发送的消息
     * @param sender 发送者的路径
     */
    func tell(message: Message, sender: Option<String>): Unit

    /**
     * 比较两个ActorRef是否相等
     * @param other 另一个ActorRef
     * @return 是否相等
     */
    func equals(other: ActorRef): Bool

    /**
     * 获取哈希码
     * @return 哈希码
     */
    func hashCode(): Int32
}

/**
 * 本地Actor引用接口
 * 表示在同一进程中的Actor
 */
public interface LocalActorRef <: ActorRef {
    /**
     * 获取底层的Actor实例
     * @return Actor实例
     */
    func getActor(): Actor

    /**
     * 暂停Actor的消息处理
     */
    func suspend(): Unit

    /**
     * 恢复Actor的消息处理
     */
    func resume(): Unit

    /**
     * 重启Actor
     * @param cause 重启原因
     */
    func restart(cause: Exception): Unit

    /**
     * 停止Actor
     */
    func stop(): Unit

    /**
     * 获取Actor当前状态
     * @return Actor状态
     */
    func getState(): ActorLifecycleState
}

/**
 * 死信Actor引用接口
 * 用于处理发送给已停止Actor的消息
 */
public interface DeadLetterActorRef <: ActorRef {
    // 标记接口，表示这是一个死信引用
}

/**
 * Actor选择器接口
 * 用于查找和选择Actor
 */
public interface ActorSelection {
    /**
     * 解析选择器，返回单个ActorRef
     * @param timeout 超时时间
     * @return 可能的ActorRef
     */
    func resolveOne(timeout: Duration): Option<ActorRef>

    /**
     * 向选择的所有Actor发送消息
     * @param message 要发送的消息
     */
    func tell(message: Message): Unit

    /**
     * 向选择的所有Actor发送消息，指定发送者
     * @param message 要发送的消息
     * @param sender 发送者路径
     */
    func tell(message: Message, sender: Option<String>): Unit
}

/**
 * Future接口
 * 表示异步计算的结果
 */
public interface Future<T> {
    /**
     * 注册完成回调
     * @param callback 完成时的回调函数
     */
    func onComplete(callback: (Result<T>) -> Unit): Unit

    /**
     * 映射结果
     * @param f 映射函数
     * @return 新的Future
     */
    func map<U>(f: (T) -> U): Future<U>

    /**
     * 平铺映射
     * @param f 映射函数
     * @return 新的Future
     */
    func flatMap<U>(f: (T) -> Future<U>): Future<U>

    /**
     * 错误恢复
     * @param f 恢复函数
     * @return 新的Future
     */
    func recover(f: (Exception) -> T): Future<T>

    /**
     * 检查是否已完成
     * @return 是否已完成
     */
    func isCompleted(): Bool

    /**
     * 获取当前值（如果已完成）
     * @return 可能的结果
     */
    func value(): Option<Result<T>>
}

/**
 * 结果类型
 * 表示操作的成功或失败
 */
public enum Result<T> {
    | Success(T)         // 成功结果
    | Failure(Exception) // 失败结果
}

/**
 * 简化的Future实现
 */
public class SimpleFuture<T> <: Future<T> {
    private let result: Option<Result<T>>
    private let completed: AtomicBool

    public init(result: Result<T>) {
        this.result = Some(result)
        this.completed = AtomicBool(true)
    }

    public init() {
        this.result = None
        this.completed = AtomicBool(false)
    }

    public func onComplete(callback: (Result<T>) -> Unit): Unit {
        match (result) {
            case Some(r) => callback(r)
            case None => {
                // 简化实现，实际需要存储回调并在完成时调用
            }
        }
    }

    public func map<U>(f: (T) -> U): Future<U> {
        match (result) {
            case Some(Result.Success(value)) => {
                try {
                    SimpleFuture<U>(Result.Success(f(value)))
                } catch (e: Exception) {
                    SimpleFuture<U>(Result.Failure(e))
                }
            }
            case Some(Result.Failure(e)) => SimpleFuture<U>(Result.Failure(e))
            case None => SimpleFuture<U>()
        }
    }

    public func flatMap<U>(f: (T) -> Future<U>): Future<U> {
        match (result) {
            case Some(Result.Success(value)) => {
                try {
                    f(value)
                } catch (e: Exception) {
                    SimpleFuture<U>(Result.Failure(e))
                }
            }
            case Some(Result.Failure(e)) => SimpleFuture<U>(Result.Failure(e))
            case None => SimpleFuture<U>()
        }
    }

    public func recover(f: (Exception) -> T): Future<T> {
        match (result) {
            case Some(Result.Failure(e)) => {
                try {
                    SimpleFuture<T>(Result.Success(f(e)))
                } catch (newE: Exception) {
                    SimpleFuture<T>(Result.Failure(newE))
                }
            }
            case _ => this
        }
    }

    public func isCompleted(): Bool {
        completed.load()
    }

    public func value(): Option<Result<T>> {
        result
    }
}
