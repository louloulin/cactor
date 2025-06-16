/*
 * Copyright (c) 2024. All rights reserved.
 * SimpleSupervisionStrategy - 简单监督策略实现
 * 提供基本的Actor监督功能
 */
package cactor.runtime.supervision

import cactor.core.supervision.{SupervisionStrategy, SupervisionDirective, ActorFailure}

/**
 * 简单监督策略
 * 
 * 默认行为：
 * - 对于一般异常：重启Actor
 * - 对于严重异常：停止Actor
 * - 对于系统异常：升级到父Actor
 */
public class SimpleSupervisionStrategy <: SupervisionStrategy {
    private let maxRetries: Int32
    private let timeWindow: Int64  // 时间窗口（纳秒）
    
    public init(maxRetries: Int32 = 3, timeWindowSeconds: Int32 = 60) {
        this.maxRetries = maxRetries
        this.timeWindow = Int64(timeWindowSeconds) * 1000000000  // 转换为纳秒
    }
    
    /**
     * 决定如何处理Actor失败
     */
    public func decide(failure: ActorFailure): SupervisionDirective {
        // 检查失败类型
        let exception = failure.exception
        let exceptionType = exception.getType()
        
        // 根据异常类型决定处理方式
        match (exceptionType) {
            case "NullPointerException" =>
                SupervisionDirective.Restart
            case "IllegalArgumentException" =>
                SupervisionDirective.Restart
            case "RuntimeException" =>
                SupervisionDirective.Restart
            case "OutOfMemoryError" =>
                SupervisionDirective.Stop
            case "StackOverflowError" =>
                SupervisionDirective.Stop
            case "SystemException" =>
                SupervisionDirective.Escalate
            case _ =>
                // 默认重启
                SupervisionDirective.Restart
        }
    }
    
    /**
     * 检查是否应该重启Actor
     */
    public func shouldRestart(failure: ActorFailure): Bool {
        // 简化实现：总是允许重启
        true
    }
    
    /**
     * 获取最大重试次数
     */
    public func getMaxRetries(): Int32 {
        maxRetries
    }
    
    /**
     * 获取时间窗口
     */
    public func getTimeWindow(): Int64 {
        timeWindow
    }
    
    /**
     * 获取策略描述
     */
    public func getDescription(): String {
        "SimpleSupervisionStrategy(maxRetries=${maxRetries}, timeWindow=${timeWindow / 1000000000}s)"
    }
}
