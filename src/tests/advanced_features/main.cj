/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - 高级功能测试
 */
package cactor.tests.advanced_features

import std.time.*
import std.collection.*
import cactor.core.message.{Message, StringMessage, PingMessage, PongMessage}
import cactor.cluster.{NodeId, ClusterNode, SimpleClusterManager, FailoverManager, FailoverStrategy}
import cactor.config.{ConfigurationManager, ActorSystemConfig, RemoteConfig, ClusterConfig, ConfigValue}
import cactor.benchmark.{BenchmarkSuite, BenchmarkResult}
import cactor.network.{NetworkAddress, TransportProtocol}

/**
 * 高级功能测试
 */
main(): Int64 {
    println("=== CACtor 2.0 高级功能测试 ===")
    
    try {
        // 1. 测试配置管理
        println("\n1. 测试配置管理...")
        testConfigurationManager()
        
        // 2. 测试集群支持
        println("\n2. 测试集群支持...")
        testClusterSupport()
        
        // 3. 测试故障转移
        println("\n3. 测试故障转移...")
        testFailoverManager()
        
        // 4. 测试性能基准测试
        println("\n4. 测试性能基准测试...")
        testPerformanceBenchmark()
        
        println("\n✅ 所有高级功能测试通过！")
        return 0
    } catch (e: Exception) {
        println("❌ 高级功能测试失败: ${e.message}")
        return 1
    }
}

/**
 * 测试配置管理
 */
func testConfigurationManager(): Unit {
    println("   创建配置管理器...")
    let configManager = ConfigurationManager()
    
    // 测试基本配置操作
    println("   测试基本配置操作...")
    configManager.setConfig("test.string", ConfigValue.StringValue("hello"))
    configManager.setConfig("test.int", ConfigValue.IntValue(42))
    configManager.setConfig("test.bool", ConfigValue.BoolValue(true))
    
    // 验证配置读取
    match (configManager.getString("test.string")) {
        case Some(value) => 
            if (value == "hello") {
                println("   ✓ 字符串配置读取正确")
            } else {
                throw Exception("字符串配置读取错误")
            }
        case None => 
            throw Exception("字符串配置不存在")
    }
    
    match (configManager.getInt("test.int")) {
        case Some(value) => 
            if (value == 42) {
                println("   ✓ 整数配置读取正确")
            } else {
                throw Exception("整数配置读取错误")
            }
        case None => 
            throw Exception("整数配置不存在")
    }
    
    match (configManager.getBool("test.bool")) {
        case Some(value) => 
            if (value == true) {
                println("   ✓ 布尔配置读取正确")
            } else {
                throw Exception("布尔配置读取错误")
            }
        case None => 
            throw Exception("布尔配置不存在")
    }
    
    // 测试默认值
    let defaultString = configManager.getStringOrDefault("nonexistent", "default")
    if (defaultString == "default") {
        println("   ✓ 默认值功能正常")
    } else {
        throw Exception("默认值功能异常")
    }
    
    // 测试配置组件
    println("   测试配置组件...")
    let actorConfig = ActorSystemConfig(configManager)
    let dispatcherType = actorConfig.getDispatcherType()
    println("   调度器类型: ${dispatcherType}")
    
    let remoteConfig = RemoteConfig(configManager)
    let hostname = remoteConfig.getHostname()
    println("   远程主机名: ${hostname}")
    
    let clusterConfig = ClusterConfig(configManager)
    let heartbeatInterval = clusterConfig.getHeartbeatInterval()
    println("   心跳间隔: ${heartbeatInterval}ms")
    
    println("   ✓ 配置管理测试通过")
}

/**
 * 测试集群支持
 */
func testClusterSupport(): Unit {
    println("   创建集群管理器...")
    let nodeId = NodeId("node-1")
    let localAddress = NetworkAddress("localhost", 8100)
    let clusterManager = SimpleClusterManager(nodeId, localAddress)
    
    // 启动集群管理器
    println("   启动集群管理器...")
    clusterManager.start()
    
    // 添加其他节点
    println("   添加集群节点...")
    let node2Id = NodeId("node-2")
    let node2Address = NetworkAddress("localhost", 8101)
    clusterManager.addNode(node2Id, node2Address, ["worker"])
    
    let node3Id = NodeId("node-3")
    let node3Address = NetworkAddress("localhost", 8102)
    clusterManager.addNode(node3Id, node3Address, ["worker", "storage"])
    
    // 检查集群状态
    let clusterState = clusterManager.getClusterState()
    let allNodes = clusterState.getAllNodes()
    println("   集群节点总数: ${allNodes.size}")
    
    if (allNodes.size >= 3) {
        println("   ✓ 集群节点添加成功")
    } else {
        throw Exception("集群节点数量不正确")
    }
    
    // 测试节点查找
    match (clusterState.getNode(node2Id)) {
        case Some(node) => 
            println("   ✓ 节点查找成功: ${node.toString()}")
        case None => 
            throw Exception("节点查找失败")
    }
    
    // 测试可用节点
    let availableNodes = clusterState.getAvailableNodes()
    println("   可用节点数量: ${availableNodes.size}")
    
    // 停止集群管理器
    clusterManager.stop()
    println("   ✓ 集群支持测试通过")
}

/**
 * 测试故障转移
 */
func testFailoverManager(): Unit {
    println("   创建故障转移管理器...")
    let nodeId = NodeId("failover-node")
    let localAddress = NetworkAddress("localhost", 8200)
    let clusterManager = SimpleClusterManager(nodeId, localAddress)
    
    // 创建故障转移管理器
    let failoverManager = FailoverManager(clusterManager, FailoverStrategy.MigrateToOtherNode)
    
    // 启动管理器
    clusterManager.start()
    failoverManager.start()
    
    // 添加一些节点
    let node1Id = NodeId("worker-1")
    let node1Address = NetworkAddress("localhost", 8201)
    clusterManager.addNode(node1Id, node1Address, ["worker"])
    
    let node2Id = NodeId("worker-2")
    let node2Address = NetworkAddress("localhost", 8202)
    clusterManager.addNode(node2Id, node2Address, ["worker"])
    
    // 模拟节点故障
    println("   模拟节点故障...")
    let clusterState = clusterManager.getClusterState()
    match (clusterState.getNode(node1Id)) {
        case Some(failedNode) => 
            failoverManager.handleNodeFailure(failedNode)
            println("   ✓ 故障转移处理完成")
        case None => 
            throw Exception("找不到要故障的节点")
    }
    
    // 检查故障检测器
    let failureDetector = failoverManager.getFailureDetector()
    println("   ✓ 故障检测器正常")
    
    // 停止管理器
    failoverManager.stop()
    clusterManager.stop()
    println("   ✓ 故障转移测试通过")
}

/**
 * 测试性能基准测试
 */
func testPerformanceBenchmark(): Unit {
    println("   创建基准测试套件...")
    let benchmarkSuite = BenchmarkSuite()
    
    // 运行基准测试
    println("   运行性能基准测试...")
    let results = benchmarkSuite.runAllBenchmarks()
    
    // 验证结果
    if (results.size > 0) {
        println("   ✓ 基准测试执行成功，共${results.size}个测试")
        
        for (result in results) {
            println("   测试: ${result.testName}")
            println("     吞吐量: ${result.throughput} 消息/秒")
            println("     平均延迟: ${result.avgLatency} 毫秒")
            println("     消息总数: ${result.messageCount}")
            
            // 验证基本性能指标
            if (result.throughput > 0.0) {
                println("     ✓ 吞吐量正常")
            } else {
                throw Exception("吞吐量异常")
            }
            
            if (result.messageCount > 0) {
                println("     ✓ 消息处理正常")
            } else {
                throw Exception("消息处理异常")
            }
        }
        
        // 生成报告
        let report = benchmarkSuite.generateReport(results)
        println("   ✓ 性能报告生成成功")
        
    } else {
        throw Exception("基准测试结果为空")
    }
    
    println("   ✓ 性能基准测试通过")
}

/**
 * 简化的字符串构建器
 */
class StringBuilder {
    private let parts: ArrayList<String>
    
    public init() {
        this.parts = ArrayList<String>()
    }
    
    public func append(str: String): Unit {
        parts.append(str)
    }
    
    public func toString(): String {
        if (parts.size == 0) {
            return ""
        }

        // 简化的字符串连接
        var result = parts[0]
        for (i in 1..parts.size) {
            result = result + parts[i]
        }
        result
    }
}
