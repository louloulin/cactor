/*
 * Copyright (c) 2024. All rights reserved.
 * CActor Plan8 基础性能压测系统
 */
package cactor.integration.testing.plan8_performance_benchmark

import std.time.*
import std.sync.*
import cactor.core.actor.{Actor, ActorRef, Props, SimpleActorFactory}
import cactor.core.system.{ActorSystem}
import cactor.runtime.system.{SimpleActorSystem}
import cactor.core.message.{Message, StringMessage, MessageResult}
import cactor.core.context.ActorContext

/**
 * 简化的性能测试Actor
 */
public class Plan8BenchmarkActor <: Actor {
    private let processedCount: AtomicUInt64

    public init() {
        this.processedCount = AtomicUInt64(0)
    }

    public prop name: String {
        get() { "Plan8BenchmarkActor" }
    }

    public prop description: String {
        get() { "Plan8高性能基准测试Actor" }
    }

    public func receive(message: Message, context: ActorContext): MessageResult {
        // 简单计数处理
        processedCount.fetchAdd(1)
        MessageResult.Handled
    }

    public func getProcessedCount(): UInt64 {
        processedCount.load()
    }
}

main(): Int64 {
    println("🎯 CActor Plan8 基础性能压测")

    let system = SimpleActorSystem("plan8-benchmark")
    let props = Props<Actor>(SimpleActorFactory<Actor>({ => Plan8BenchmarkActor() }))
    let actorRef = system.actorOf(props, "benchmark-actor")

    let startTime = DateTime.now()
    let messageCount = 10000  // 1万条消息测试

    println("开始发送 ${messageCount} 条消息...")

    for (i in 0..messageCount) {
        let message = StringMessage("test-${i}")
        actorRef.tell(message)
    }

    // 等待处理
    let waitStart = DateTime.now()
    while ((DateTime.now() - waitStart).toMilliseconds() < 2000) {
        // 等待2秒
    }

    let endTime = DateTime.now()
    let durationMs = (endTime - startTime).toMilliseconds()

    println("\n📊 测试结果:")
    println("   消息数: ${messageCount}")
    println("   时长: ${durationMs} ms")

    if (durationMs > 0) {
        let throughput = (messageCount * 1000) / durationMs
        println("   吞吐量: ${throughput} msg/s")

        if (throughput >= 10000000) {
            println("达到10M+ msg/s目标!")
        } else {
            println("当前: ${throughput} msg/s，目标: 10M msg/s")
        }
    }

    system.terminate()
    println("🎉 测试完成!")

    return 0
}