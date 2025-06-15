/**
 * CActor 流处理演示
 * 展示基于 Actor 模型的流处理能力
 */

package cactor.examples.stream_demo

import cactor.*
import cactor.stream.*
import std.time.*
import std.sync.sleep

main() {
    println("=== CActor 流处理演示 ===")
    println("展示基于 Actor 模型的流处理能力")
    
    try {
        // 基础流处理演示
        basicStreamProcessingDemo()
        
        sleep(Duration.second * 2)
        
        // 复杂流处理管道演示
        complexStreamPipelineDemo()
        
        sleep(Duration.second * 2)
        
        // 流处理性能演示
        streamPerformanceDemo()
        
        println("\n🎉 流处理演示完成！")
        println("🎯 展示了以下 CActor 流处理功能：")
        println("   - 基于 Actor 的流处理架构")
        println("   - 流畅的管道构建 API")
        println("   - 映射和过滤操作")
        println("   - 流控制和生命周期管理")
        println("   - 流处理性能监控")
        
    } catch (e: Exception) {
        println("演示过程中发生错误: ${e}")
    }
}

// 基础流处理演示
func basicStreamProcessingDemo(): Unit {
    println("\n--- 基础流处理演示 ---")
    
    // 创建流处理组件
    let sourceActor = StreamSourceActor("DataSource", Duration.millisecond * 200)
    let mapProcessor = MapProcessor { element =>
        BasicStreamElement(element.getKey(), "mapped-${element.getValue()}")
    }
    let processorActor = StreamProcessorActor("MapProcessor", mapProcessor)
    let sinkActor = StreamSinkActor("DataSink")
    
    // 启动 Actor
    sourceActor.preStart()
    processorActor.preStart()
    sinkActor.preStart()
    
    // 模拟流处理（简化版本）
    println("开始基础流处理...")
    
    // 生成一些测试数据
    for (i in 1..5) {
        let element = BasicStreamElement("key-${i}", "value-${i}")
        let streamMsg = StreamMessage(element)
        
        // 模拟处理流程
        println("源: 生成 ${element.toString()}")

        match (mapProcessor.process(element)) {
            case Some(mappedElement) =>
                println("处理器: 映射 ${element.toString()} -> ${mappedElement.toString()}")
                println("汇聚: 收集 ${mappedElement.toString()}")
            case None =>
                println("处理器: 过滤掉 ${element.toString()}")
        }
        
        sleep(Duration.millisecond * 100)
    }
    
    // 停止 Actor
    sourceActor.postStop()
    processorActor.postStop()
    sinkActor.postStop()
    
    println("基础流处理演示完成")
}

// 复杂流处理管道演示
func complexStreamPipelineDemo(): Unit {
    println("\n--- 复杂流处理管道演示 ---")
    
    // 使用流畅 API 构建管道
    let pipeline = StreamPipelineBuilder()
        .source("NumberSource", Duration.millisecond * 150)
        .filter("EvenFilter") { element =>
            // 过滤偶数（基于 key 的长度）
            let key = element.getKey()
            (key.size % 2) == 0
        }
        .map("UppercaseMapper") { element =>
            BasicStreamElement(element.getKey(), "UPPER-${element.getValue()}")
        }
        .map("PrefixMapper") { element =>
            BasicStreamElement("processed-${element.getKey()}", "RESULT: ${element.getValue()}")
        }
        .sink("ResultSink")
        .build()
    
    // 启动管道
    pipeline.start()
    
    // 运行一段时间
    println("管道运行中...")
    sleep(Duration.second * 3)
    
    // 获取统计信息
    let stats = pipeline.getStatistics()
    println(stats.toString())
    
    // 停止管道
    pipeline.stop()
    
    println("复杂流处理管道演示完成")
}

// 流处理性能演示
func streamPerformanceDemo(): Unit {
    println("\n--- 流处理性能演示 ---")
    
    let startTime = DateTime.now()
    
    // 创建高频流处理管道
    let highFrequencyPipeline = StreamPipelineBuilder()
        .source("HighFreqSource", Duration.millisecond * 10)
        .filter("ValidDataFilter") { element =>
            // 模拟数据验证
            element.getValue().size > 0
        }
        .map("TimestampMapper") { element =>
            let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
            BasicStreamElement(element.getKey(), "${element.getValue()}-${timestamp}")
        }
        .map("CompressionMapper") { element =>
            // 模拟数据压缩
            BasicStreamElement(element.getKey(), "compressed[${element.getValue()}]")
        }
        .sink("PerformanceSink")
        .build()
    
    // 启动高频管道
    highFrequencyPipeline.start()
    
    // 运行性能测试
    println("高频流处理运行中...")
    sleep(Duration.second * 2)
    
    // 获取性能统计
    let perfStats = highFrequencyPipeline.getStatistics()
    println("性能统计:")
    println(perfStats.toString())
    
    // 停止管道
    highFrequencyPipeline.stop()
    
    let endTime = DateTime.now()
    let duration = endTime.toUnixTimeStamp().toMilliseconds() - startTime.toUnixTimeStamp().toMilliseconds()
    
    println("性能演示完成，总耗时: ${duration}ms")
}

// 自定义聚合处理器
class AggregateProcessor <: StreamProcessor<StreamElement, StreamElement> {
    private var sum: Int64 = 0
    private var count: Int64 = 0

    public func process(element: StreamElement): Option<StreamElement> {
        try {
            // 简化处理：使用字符串长度作为数值
            let value = element.getValue().size
            sum += value
            count += 1

            let avgValue = if (count > 0) { sum / count } else { 0 }
            Some(BasicStreamElement("aggregate", "avg=${avgValue},count=${count}"))
        } catch (e: Exception) {
            None<StreamElement>
        }
    }
}

// 自定义流处理器演示
func customProcessorDemo(): Unit {
    println("\n--- 自定义流处理器演示 ---")

    // 创建自定义聚合处理器
    let aggregateProcessor = AggregateProcessor()

    let customPipeline = StreamPipelineBuilder()
        .source("NumberSource", Duration.millisecond * 100)
        .map("NumberGenerator") { element =>
            // 生成随机数值
            let randomValue = (DateTime.now().toUnixTimeStamp().toMilliseconds() % 100).toString()
            BasicStreamElement(element.getKey(), randomValue)
        }
        .sink("AggregateSink")
        .build()

    customPipeline.start()
    sleep(Duration.second * 2)
    customPipeline.stop()

    println("自定义流处理器演示完成")
}
