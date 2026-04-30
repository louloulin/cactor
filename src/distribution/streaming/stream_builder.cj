/**
 * 流处理管道构建器
 * 提供流畅的 API 来构建流处理管道
 */

package cactor.distribution.streaming

import cactor.core.actor.{Actor}
import cactor.core.message.{StringMessage}
import cactor.core.system.{ActorSystem}
import std.collection.*
import std.time.*

// 流管道构建器
public class StreamPipelineBuilder {
    private let stages: ArrayList<StreamStage>
    private var sourceStage: Option<StreamSourceStage>
    private var sinkStage: Option<StreamSinkStage>
    
    public init() {
        this.stages = ArrayList<StreamStage>()
        this.sourceStage = None
        this.sinkStage = None
    }
    
    // 设置流源
    public func source(name: String, generateInterval: Duration): StreamPipelineBuilder {
        this.sourceStage = Some(StreamSourceStage(name, generateInterval))
        this
    }
    
    // 添加映射处理
    public func map(name: String, mapFunction: (StreamElement) -> StreamElement): StreamPipelineBuilder {
        let processor = MapProcessor(mapFunction)
        let stage = StreamProcessorStage(name, processor)
        stages.add(stage)
        this
    }
    
    // 添加过滤处理
    public func filter(name: String, filterFunction: (StreamElement) -> Bool): StreamPipelineBuilder {
        let processor = FilterProcessor(filterFunction)
        let stage = StreamProcessorStage(name, processor)
        stages.add(stage)
        this
    }
    
    // 设置流汇聚
    public func sink(name: String): StreamPipelineBuilder {
        this.sinkStage = Some(StreamSinkStage(name))
        this
    }
    
    // 构建流管道
    public func build(): StreamPipeline {
        match (sourceStage) {
            case Some(source) =>
                match (sinkStage) {
                    case Some(sink) =>
                        StreamPipeline(source, stages.toArray(), sink)
                    case None =>
                        throw Exception("流管道必须包含汇聚")
                }
            case None =>
                throw Exception("流管道必须包含源")
        }
    }
}

// 流阶段接口
public interface StreamStage {
    func getName(): String
    func createActor(): Actor
}

// 流源阶段
public class StreamSourceStage <: StreamStage {
    private let name: String
    private let generateInterval: Duration
    
    public init(name: String, generateInterval: Duration) {
        this.name = name
        this.generateInterval = generateInterval
    }
    
    public func getName(): String { name }
    
    public func createActor(): Actor {
        StreamSourceActor(name, generateInterval)
    }
}

// 流处理阶段
public class StreamProcessorStage <: StreamStage {
    private let name: String
    private let processor: StreamProcessor<StreamElement, StreamElement>
    
    public init(name: String, processor: StreamProcessor<StreamElement, StreamElement>) {
        this.name = name
        this.processor = processor
    }
    
    public func getName(): String { name }
    
    public func createActor(): Actor {
        StreamProcessorActor(name, processor)
    }
}

// 流汇聚阶段
public class StreamSinkStage <: StreamStage {
    private let name: String
    
    public init(name: String) {
        this.name = name
    }
    
    public func getName(): String { name }
    
    public func createActor(): Actor {
        StreamSinkActor(name)
    }
}

// 流管道
public class StreamPipeline {
    private let sourceStage: StreamSourceStage
    private let processingStages: Array<StreamStage>
    private let sinkStage: StreamSinkStage
    private var actors: Array<Actor>
    private var isRunning: Bool
    
    public init(sourceStage: StreamSourceStage, 
                processingStages: Array<StreamStage>, 
                sinkStage: StreamSinkStage) {
        this.sourceStage = sourceStage
        this.processingStages = processingStages
        this.sinkStage = sinkStage
        this.actors = Array<Actor>()
        this.isRunning = false
    }
    
    // 启动流管道
    public func start(): Unit {
        if (isRunning) {
            println("流管道已经在运行中")
            return
        }
        
        println("启动流处理管道...")
        
        // 创建所有 Actor
        let allStages = ArrayList<StreamStage>()
        allStages.add(sourceStage)
        for (stage in processingStages) {
            allStages.add(stage)
        }
        allStages.add(sinkStage)
        
        let actorList = ArrayList<Actor>()
        for (stage in allStages) {
            let actor = stage.createActor()
            actorList.add(actor)
            actor.preStart()
        }
        
        actors = actorList.toArray()
        
        // 模拟连接管道（在实际实现中应该通过 ActorRef）
        connectPipeline()
        
        // 启动流源
        if (actors.size > 0) {
            match (actors[0]) {
                case sourceActor: StreamSourceActor =>
                    let startMsg = StreamControlMessage("START")
                    // 在实际实现中，这里应该通过 ActorRef 发送消息
                    println("发送启动消息到流源")
                case _ =>
                    println("第一个Actor不是StreamSourceActor")
            }
        }
        
        isRunning = true
        println("流处理管道已启动")
    }
    
    // 停止流管道
    public func stop(): Unit {
        if (!isRunning) {
            println("流管道未在运行")
            return
        }
        
        println("停止流处理管道...")
        
        // 停止流源
        if (actors.size > 0) {
            match (actors[0]) {
                case sourceActor: StreamSourceActor =>
                    let stopMsg = StreamControlMessage("STOP")
                    // 在实际实现中，这里应该通过 ActorRef 发送消息
                    println("发送停止消息到流源")
                case _ =>
                    println("第一个Actor不是StreamSourceActor")
            }
        }
        
        // 停止所有 Actor
        for (actor in actors) {
            actor.postStop()
        }
        
        isRunning = false
        println("流处理管道已停止")
    }
    
    // 连接管道各阶段
    private func connectPipeline(): Unit {
        println("连接流处理管道各阶段...")
        
        // 在实际实现中，这里应该设置 ActorRef 连接
        for (i in 0..(actors.size - 1)) {
            let currentStage = getStageNameByIndex(i)
            let nextStage: Option<String> = if (i + 1 < actors.size) {
                Some(getStageNameByIndex(i + 1))
            } else {
                None<String>
            }

            match (nextStage) {
                case Some(next) =>
                    println("连接 ${currentStage} -> ${next}")
                case None =>
                    println("${currentStage} 是最后一个阶段")
            }
        }
    }
    
    private func getStageNameByIndex(index: Int64): String {
        if (index == 0) {
            sourceStage.getName()
        } else if (index <= processingStages.size) {
            processingStages[index - 1].getName()
        } else {
            sinkStage.getName()
        }
    }
    
    // 获取管道统计信息
    public func getStatistics(): StreamPipelineStatistics {
        let stats = StreamPipelineStatistics()
        
        // 收集各阶段统计信息
        for (actor in actors) {
            match (actor) {
                case sourceActor: StreamSourceActor =>
                    stats.setSourceStats("运行中")
                case processorActor: StreamProcessorActor =>
                    stats.addProcessorStats(processorActor.name, "运行中")
                case sinkActor: StreamSinkActor =>
                    stats.setSinkStats("运行中", sinkActor.getReceivedCount())
                case _ =>
                    println("未知Actor类型")
            }
        }
        
        stats
    }
}

// 流管道统计信息
public class StreamPipelineStatistics {
    private var sourceStatus: String
    private let processorStats: HashMap<String, String>
    private var sinkStatus: String
    private var sinkReceivedCount: Int64
    
    public init() {
        this.sourceStatus = "未知"
        this.processorStats = HashMap<String, String>()
        this.sinkStatus = "未知"
        this.sinkReceivedCount = 0
    }
    
    public func setSourceStats(status: String): Unit {
        this.sourceStatus = status
    }
    
    public func addProcessorStats(name: String, status: String): Unit {
        processorStats[name] = status
    }
    
    public func setSinkStats(status: String, receivedCount: Int64): Unit {
        this.sinkStatus = status
        this.sinkReceivedCount = receivedCount
    }
    
    public func toString(): String {
        let sb = StringBuilder()
        sb.append("=== 流管道统计信息 ===\n")
        sb.append("源状态: ${sourceStatus}\n")
        
        for ((name, status) in processorStats) {
            sb.append("处理器 ${name}: ${status}\n")
        }
        
        sb.append("汇聚状态: ${sinkStatus}\n")
        sb.append("汇聚接收数量: ${sinkReceivedCount}\n")
        
        sb.toString()
    }
}
