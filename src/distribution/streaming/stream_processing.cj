/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 流处理实现
 * 对标 Akka Streams
 */
package cactor.distribution.streaming

import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorContext}
import cactor.core.message.{Message, MessageResult}

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

    public func runWith(_sink: Sink): Any {
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

/**
 * StreamElement - 流处理元素类型
 */
public class StreamElement {
    public let data: Any
    public let timestamp: Int64

    public init(data: Any) {
        this.data = data
        this.timestamp = 0
    }

    public init(data: Any, timestamp: Int64) {
        this.data = data
        this.timestamp = timestamp
    }
}

/**
 * StreamProcessor - 流处理器接口
 */
public interface StreamProcessor<Input, Output> {
    func process(input: Input): Option<Output>
}

/**
 * MapProcessor - 映射处理器
 */
public class MapProcessor <: StreamProcessor<StreamElement, StreamElement> {
    private let mapFunc: (StreamElement) -> StreamElement

    public init(mapFunc: (StreamElement) -> StreamElement) {
        this.mapFunc = mapFunc
    }

    public func process(input: StreamElement): Option<StreamElement> {
        Some(mapFunc(input))
    }
}

/**
 * FilterProcessor - 过滤处理器
 */
public class FilterProcessor <: StreamProcessor<StreamElement, StreamElement> {
    private let filterFunc: (StreamElement) -> Bool

    public init(filterFunc: (StreamElement) -> Bool) {
        this.filterFunc = filterFunc
    }

    public func process(input: StreamElement): Option<StreamElement> {
        if (filterFunc(input)) {
            Some(input)
        } else {
            None
        }
    }
}

/**
 * StreamControlMessage - 流控制消息
 */
public class StreamControlMessage <: Message {
    private let command: String

    public init(command: String) {
        this.command = command
    }

    public func getCommand(): String {
        command
    }

    public func getType(): String {
        "StreamControl"
    }

    public func getPayload(): String {
        "StreamControl(${command})"
    }

    public func messageType(): String {
        "StreamControl"
    }
}

/**
 * StreamSourceActor - 流源Actor
 */
public class StreamSourceActor <: Actor {
    private let actorName: String
    private let interval: Duration

    public init(name: String, interval: Duration) {
        this.actorName = name
        this.interval = interval
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Stream source actor: ${actorName}" }
    }

    public func receive(_message: Message, _context: ActorContext): MessageResult {
        MessageResult.Unhandled
    }
}

/**
 * StreamProcessorActor - 流处理Actor
 */
public class StreamProcessorActor <: Actor {
    private let actorName: String
    private let processor: StreamProcessor<StreamElement, StreamElement>

    public init(name: String, processor: StreamProcessor<StreamElement, StreamElement>) {
        this.actorName = name
        this.processor = processor
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Stream processor actor: ${actorName}" }
    }

    public func receive(_message: Message, _context: ActorContext): MessageResult {
        MessageResult.Unhandled
    }
}

/**
 * StreamSinkActor - 流汇聚Actor
 */
public class StreamSinkActor <: Actor {
    private let actorName: String
    private var receivedCount: Int64 = 0

    public init(name: String) {
        this.actorName = name
    }

    public prop name: String {
        get() { actorName }
    }

    public prop description: String {
        get() { "Stream sink actor: ${actorName}" }
    }

    public func receive(_message: Message, _context: ActorContext): MessageResult {
        receivedCount += 1
        MessageResult.Handled
    }

    public func getReceivedCount(): Int64 {
        receivedCount
    }
}
