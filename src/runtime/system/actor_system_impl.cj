/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 简化的Actor系统实现
 * 基于仓颉并发特性的Actor系统
 */
package cactor.runtime.system

import std.sync.*
import std.collection.*

/**
 * 简化的Actor系统实现
 * 基于仓颉并发特性的Actor系统
 */
public class SimpleActorSystem {
    private let systemName: String
    private let terminated: AtomicBool

    public init(name: String) {
        this.systemName = name
        this.terminated = AtomicBool(false)
    }

    public func getName(): String {
        systemName
    }

    public func terminate(): Unit {
        terminated.store(true)
        println("Actor系统 ${systemName} 已终止")
    }

    public func isTerminated(): Bool {
        terminated.load()
    }
}


