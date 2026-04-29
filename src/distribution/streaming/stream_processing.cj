/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 流处理实现
 * 对标 Akka Streams
 */
package cactor.distribution.streaming

import std.collection.*

/**
 * 流形状
 */
public class StreamShape {
    public let inPort: InPort
    public let outPort: OutPort

    public init() {
        this.inPort = InPort()
        this.outPort = OutPort()
    }
}

/**
 * 输入端口
 */
public class InPort {
    public let portName: String

    public init() {
        this.portName = "in"
    }
}

/**
 * 输出端口
 */
public class OutPort {
    public let portName: String

    public init() {
        this.portName = "out"
    }
}

/**
 * NotUsed 类型
 */
public class NotUsed {
    private static var instance: NotUsed = NotUsed()

    private init() {}

    public static func getInstance(): NotUsed {
        instance
    }
}

/**
 * Source 接口 - 对标 Akka Source
 */
public interface Source {
    func runWith(sink: Sink): Any
}

/**
 * Sink 接口 - 对标 Akka Sink
 */
public interface Sink {
    func run(source: Source): Any
}

/**
 * Flow 接口 - 对标 Akka Flow
 */
public interface Flow {
    func runWith(source: Source, sink: Sink): Any
}

/**
 * 简单 Source 实现
 */
public class SimpleSource <: Source {
    private let items: ArrayList<Any>
    private var index: Int64

    public init(items: ArrayList<Any>) {
        this.items = items
        this.index = 0
    }

    public func runWith(sink: Sink): Any {
        NotUsed.getInstance()
    }

    public func next(): Option<Any> {
        if (index < items.size) {
            let item = items[index]
            index += 1
            Some(item)
        } else {
            None
        }
    }

    public func hasNext(): Bool {
        index < items.size
    }
}

/**
 * Source 工厂
 */
public class SourceFactory {
    public static func single(element: Any): SimpleSource {
        let items = ArrayList<Any>()
        items.add(element)
        SimpleSource(items)
    }

    public static func empty(): SimpleSource {
        SimpleSource(ArrayList<Any>())
    }

    public static func fromList(items: ArrayList<Any>): SimpleSource {
        SimpleSource(items)
    }
}

/**
 * 简单 Sink 实现
 */
public class SimpleSink <: Sink {
    private let collected: ArrayList<Any>

    public init() {
        this.collected = ArrayList<Any>()
    }

    public func run(source: Source): Any {
        match (source) {
            case ss: SimpleSource =>
                while (ss.hasNext()) {
                    match (ss.next()) {
                        case Some(item) => collected.add(item)
                        case None => ()
                    }
                }
            case _ => ()
        }
        NotUsed.getInstance()
    }

    public func getCollected(): ArrayList<Any> {
        collected
    }
}

/**
 * Sink 工厂
 */
public class SinkFactory {
    public static func collect(): SimpleSink {
        SimpleSink()
    }

    public static func foreach(): SimpleSink {
        SimpleSink()
    }
}

/**
 * 简单 Flow 实现
 */
public class SimpleFlow <: Flow {
    public init() {}

    public func runWith(source: Source, sink: Sink): Any {
        sink.run(source)
    }
}

/**
 * Flow 工厂
 */
public class FlowFactory {
    public static func identity(): SimpleFlow {
        SimpleFlow()
    }
}

/**
 * 回压策略
 */
public enum BackoffStrategy {
    | Buffer(Int64)
    | DropNew
    | DropOld
    | DropHead
    | DropTail
    | Fail
}

/**
 * 缓冲配置
 */
public struct BufferConfig {
    public let size: Int64
    public let overflowStrategy: BackoffStrategy

    public init(size!: Int64 = 16, overflowStrategy!: BackoffStrategy = BackoffStrategy.Buffer(16)) {
        this.size = size
        this.overflowStrategy = overflowStrategy
    }
}

/**
 * 分组策略
 */
public enum Grouping {
    | Broadcast
    | Balance
    | RoundRobin
    | Random
    | ConsistentHashing(Int64)
}

/**
 * 合并策略
 */
public enum MergeStrategy {
    | Prefer
    | Strict
    | FanOut
}
