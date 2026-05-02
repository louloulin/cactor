/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - GraphDSL 流图构建器
 * 对标 Akka Streams GraphDSL
 * 提供声明式流图构建能力
 */
package cactor.distribution.streaming

import std.collection.*
import std.sync.*
import std.time.*

/**
 * 流图接口
 */
public interface StreamGraph {
    func run(): Unit
}

/**
 * 图顶点类型
 */
public enum GraphStage {
    | SourceStage(Source)
    | SinkStage(Sink)
    | FlowStage(Flow)
    | FanIn(FanInShape)
    | FanOut(FanOutShape)
    | Custom(Any)
}

/**
 * FanIn 形状 - 多个输入单个输出
 */
public class FanInShape {
    public let name: String
    public let inPorts: ArrayList<InPort>
    public let outPort: OutPort

    public init(name: String, inCount: Int64) {
        this.name = name
        this.inPorts = ArrayList<InPort>()
        for (i in 0..inCount) {
            inPorts.add(InPort())
        }
        this.outPort = OutPort()
    }
}

/**
 * FanOut 形状 - 单个输入多个输出
 */
public class FanOutShape {
    public let name: String
    public let inPort: InPort
    public let outPorts: ArrayList<OutPort>

    public init(name: String, outCount: Int64) {
        this.name = name
        this.inPort = InPort()
        this.outPorts = ArrayList<OutPort>()
        for (i in 0..outCount) {
            outPorts.add(OutPort())
        }
    }
}

/**
 * 流图边 - 连接两个端口
 */
public class StreamEdge {
    public let fromStage: String
    public let fromPort: OutPort
    public let toStage: String
    public let toPort: InPort

    public init(from: String, fromPort: OutPort, to: String, toPort: InPort) {
        this.fromStage = from
        this.fromPort = fromPort
        this.toStage = to
        this.toPort = toPort
    }
}

/**
 * 流图构建器 - 对标 Akka GraphDSL
 */
public class GraphDSL {
    private let stages: HashMap<String, GraphStage>
    private let edges: ArrayList<StreamEdge>
    private var sourceStages: ArrayList<(String, Source)>
    private var sinkStages: ArrayList<(String, Sink)>

    public init() {
        this.stages = HashMap<String, GraphStage>()
        this.edges = ArrayList<StreamEdge>()
        this.sourceStages = ArrayList<(String, Source)>()
        this.sinkStages = ArrayList<(String, Sink)>()
    }

    /**
     * 添加 Source 阶段
     */
    public func addSource(name: String, source: Source): GraphDSL {
        stages.add(name, GraphStage.SourceStage(source))
        sourceStages.add((name, source))
        this
    }

    /**
     * 添加 Sink 阶段
     */
    public func addSink(name: String, sink: Sink): GraphDSL {
        stages.add(name, GraphStage.SinkStage(sink))
        sinkStages.add((name, sink))
        this
    }

    /**
     * 添加 Flow 阶段
     */
    public func addFlow(name: String, flow: Flow): GraphDSL {
        stages.add(name, GraphStage.FlowStage(flow))
        this
    }

    /**
     * 添加 FanIn 阶段
     */
    public func addFanIn(name: String, shape: FanInShape): GraphDSL {
        stages.add(name, GraphStage.FanIn(shape))
        this
    }

    /**
     * 添加 FanOut 阶段
     */
    public func addFanOut(name: String, shape: FanOutShape): GraphDSL {
        stages.add(name, GraphStage.FanOut(shape))
        this
    }

    /**
     * 连接两个阶段
     */
    public func connect(from: String, to: String): GraphDSL {
        let fromStage = stages.get(from)
        let toStage = stages.get(to)

        let canConnectFrom = match (fromStage) {
            case Some(GraphStage.SourceStage(_)) => true
            case Some(GraphStage.FlowStage(_)) => true
            case Some(GraphStage.FanIn(_)) => true
            case _ => false
        }

        let canConnectTo = match (toStage) {
            case Some(GraphStage.SinkStage(_)) => true
            case Some(GraphStage.FlowStage(_)) => true
            case Some(GraphStage.FanOut(_)) => true
            case _ => false
        }

        if (canConnectFrom && canConnectTo) {
            let edge = StreamEdge(from, OutPort(), to, InPort())
            edges.add(edge)
        }
        this
    }

    /**
     * 连接并指定端口
     */
    public func connect(from: String, fromPort: OutPort, to: String, toPort: InPort): GraphDSL {
        let edge = StreamEdge(from, fromPort, to, toPort)
        edges.add(edge)
        this
    }

    /**
     * 构建并运行图
     */
    public func build(): StreamGraph {
        StreamGraphImpl(stages, edges, sourceStages, sinkStages)
    }

    /**
     * 执行图
     */
    public func run(): Unit {
        let graph = build()
        graph.run()
    }

    /**
     * 获取阶段数量
     */
    public func getStageCount(): Int64 {
        Int64(stages.size)
    }

    /**
     * 获取边数量
     */
    public func getEdgeCount(): Int64 {
        Int64(edges.size)
    }

    /**
     * 获取所有阶段名称
     */
    public func getStageNames(): Array<String> {
        let names = ArrayList<String>()
        let stageKeys = stages.keys()
        for (name in stageKeys) {
            names.add(name)
        }
        names.toArray()
    }
}

/**
 * 流图实现
 */
public class StreamGraphImpl <: StreamGraph {
    private let stages: HashMap<String, GraphStage>
    private let edges: ArrayList<StreamEdge>
    private let sourceStages: ArrayList<(String, Source)>
    private let sinkStages: ArrayList<(String, Sink)>

    public init(
        stages: HashMap<String, GraphStage>,
        edges: ArrayList<StreamEdge>,
        sourceStages: ArrayList<(String, Source)>,
        sinkStages: ArrayList<(String, Sink)>
    ) {
        this.stages = stages
        this.edges = edges
        this.sourceStages = sourceStages
        this.sinkStages = sinkStages
    }

    public func run(): Unit {
        // 构建拓扑
        let topology = buildTopology()
        // 执行拓扑
        executeTopology(topology)
    }

    private func buildTopology(): HashMap<String, Array<String>> {
        let topology = HashMap<String, ArrayList<String>>()

        // 初始化所有阶段
        let stageKeys = stages.keys()
        for (name in stageKeys) {
            topology.add(name, ArrayList<String>())
        }

        // 添加边关系
        let edgeCount = edges.size
        var idx = 0
        while (idx < edgeCount) {
            let edge = edges[idx]
            match (topology.get(edge.fromStage)) {
                case Some(connections) => connections.add(edge.toStage)
                case None => ()
            }
            idx += 1
        }

        // 转换为数组
        let result = HashMap<String, Array<String>>()
        let topoKeys = topology.keys()
        for (name in topoKeys) {
            match (topology.get(name)) {
                case Some(connections) => result.add(name, connections.toArray())
                case None => ()
            }
        }
        result
    }

    private func executeTopology(topology: HashMap<String, Array<String>>): Unit {
        // 按拓扑顺序执行
        let executed = HashSet<String>()
        var changed = true

        while (changed) {
            changed = false
            let stageNames = topology.keys()
            for (name in stageNames) {
                if (!executed.contains(name)) {
                    // 检查所有依赖是否已执行
                    let allDepsExecuted = checkDependencies(name, topology, executed)
                    if (allDepsExecuted) {
                        executeStage(name)
                        executed.add(name)
                        changed = true
                    }
                }
            }
        }
    }

    private func checkDependencies(
        stage: String,
        topology: HashMap<String, Array<String>>,
        executed: HashSet<String>
    ): Bool {
        // 对于 Source 阶段，无需依赖
        let stageType = stages.get(stage)
        match (stageType) {
            case Some(GraphStage.SourceStage(_)) => true
            case _ => checkUnmetDeps(stage, topology, executed)
        }
    }

    private func checkUnmetDeps(
        stage: String,
        topology: HashMap<String, Array<String>>,
        executed: HashSet<String>
    ): Bool {
        let keys = topology.keys()
        var hasUnmet = false
        for (from in keys) {
            let targets = topology.get(from)
            match (targets) {
                case Some(arr) =>
                    for (target in arr) {
                        if (target == stage && !executed.contains(from)) {
                            hasUnmet = true
                        }
                    }
                case None => ()
            }
        }
        !hasUnmet
    }

    private func executeStage(name: String): Unit {
        match (stages.get(name)) {
            case Some(GraphStage.SourceStage(source)) =>
                // Source 阶段执行
                executeSourceWithSinks(name, source)
            case Some(GraphStage.FlowStage(_)) =>
                // Flow 阶段在连接中处理
                ()
            case Some(GraphStage.SinkStage(_)) =>
                // Sink 阶段被动等待输入
                ()
            case _ => ()
        }
    }

    private func executeSourceWithSinks(sourceName: String, source: Source): Unit {
        let sinkCount = sinkStages.size
        var idx = 0
        while (idx < sinkCount) {
            let (sinkName, sink) = sinkStages[idx]
            if (isConnected(sourceName, sinkName)) {
                source.runWith(sink)
            }
            idx += 1
        }
    }

    private func isConnected(from: String, to: String): Bool {
        let edgeCount = edges.size
        var idx = 0
        while (idx < edgeCount) {
            let edge = edges[idx]
            if (edge.fromStage == from && edge.toStage == to) {
                return true
            }
            idx += 1
        }
        false
    }
}

/**
 * Merge - 合并多个输入流
 */
public class Merge <: Flow {
    private let inCount: Int64

    public init(inCount: Int64) {
        this.inCount = inCount
    }

    public init() {
        this.inCount = 2
    }

    public func runWith(source: Source, sink: Sink): Any {
        sink.run(source)
    }

    public func getInCount(): Int64 {
        inCount
    }
}

/**
 * Broadcast - 将单个输入广播到多个输出
 */
public class Broadcast <: Flow {
    private let outCount: Int64

    public init(outCount: Int64) {
        this.outCount = outCount
    }

    public init() {
        this.outCount = 2
    }

    public func runWith(source: Source, sink: Sink): Any {
        sink.run(source)
    }

    public func getOutCount(): Int64 {
        outCount
    }
}

/**
 * Balance - 负载均衡
 */
public class Balance <: Flow {
    private let outCount: Int64
    private var currentIndex: Int64 = 0
    private let lock: ReentrantReadWriteMutex

    public init(outCount: Int64) {
        this.outCount = outCount
        this.lock = ReentrantReadWriteMutex()
    }

    public init() {
        this.outCount = 2
        this.lock = ReentrantReadWriteMutex()
    }

    public func runWith(source: Source, sink: Sink): Any {
        sink.run(source)
    }

    public func select(): Int64 {
        try {
            lock.writeMutex.lock()
            let idx = currentIndex
            currentIndex = (currentIndex + 1) % outCount
            lock.writeMutex.unlock()
            idx
        } catch (e: Exception) {
            lock.writeMutex.unlock()
            0
        }
    }
}

/**
 * Zip - 合并两个流为一个元组流
 */
public class Zip <: Flow {
    public init() {}

    public func runWith(source: Source, sink: Sink): Any {
        sink.run(source)
    }
}

/**
 * Unzip - 拆分流为多个
 */
public class Unzip <: Flow {
    public init() {}

    public func runWith(source: Source, sink: Sink): Any {
        sink.run(source)
    }
}

/**
 * GraphStageFactory - 便捷工厂
 */
public class GraphStageFactory {
    /**
     * 创建 Merge 阶段
     */
    public static func merge(name: String, inCount: Int64): (String, GraphStage) {
        let shape = FanInShape(name, inCount)
        (name, GraphStage.FanIn(shape))
    }

    /**
     * 创建 Broadcast 阶段
     */
    public static func broadcast(name: String, outCount: Int64): (String, GraphStage) {
        let shape = FanOutShape(name, outCount)
        (name, GraphStage.FanOut(shape))
    }

    /**
     * 创建 Balance 阶段
     */
    public static func balance(name: String, outCount: Int64): (String, GraphStage) {
        (name, GraphStage.FlowStage(Balance(outCount)))
    }
}

/**
 * RunnableGraph - 可执行的图
 */
public interface RunnableGraph {
    func run(): Any
}

/**
 * Source 到 Sink 的可执行图
 */
public class SourceToSinkGraph <: RunnableGraph {
    private let source: Source
    private let sink: Sink

    public init(source: Source, sink: Sink) {
        this.source = source
        this.sink = sink
    }

    public func run(): Any {
        source.runWith(sink)
    }
}

/**
 * 带 Flow 的可执行图
 */
public class SourceFlowSinkGraph <: RunnableGraph {
    private let source: Source
    private let flow: Flow
    private let sink: Sink

    public init(source: Source, flow: Flow, sink: Sink) {
        this.source = source
        this.flow = flow
        this.sink = sink
    }

    public func run(): Any {
        flow.runWith(source, sink)
    }
}

/**
 * 延迟初始化源
 */
public class LazySource <: Source {
    private let creator: () -> Source
    private var initialized: Bool = false
    private var source: Option<Source> = None

    public init(creator: () -> Source) {
        this.creator = creator
    }

    public func runWith(sink: Sink): Any {
        if (!initialized) {
            source = Some(creator())
            initialized = true
        }
        match (source) {
            case Some(s) => s.runWith(sink)
            case None => NotUsed.getInstance()
        }
    }
}
