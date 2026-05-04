/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Multi-DC 多数据中心示例
 * 演示跨数据中心的高可用部署
 */
package cactor.examples

import std.collection.*
import std.time.*
import cactor.distribution.cluster.*

// ============================================================================
// Multi-DC 示例演示
// ============================================================================

/**
 * Multi-DC 使用示例
 */
public class MultiDcDemo {
    private let manager: DcMembershipManager
    private let router: DcAwareRouter

    public init() {
        let config = MultiDcConfig.defaultConfig()
        this.manager = DcMembershipManager(config)
        this.router = DcAwareRouter(manager, DcRoutingStrategy.LocalDCFirst)
    }

    /**
     * 添加多个数据中心的成员
     */
    public func setupMultiDcCluster(): Unit {
        // 主数据中心 - us-east
        let dc1 = DatacenterId("dc1", "us-east")
        manager.addMember("node-1", dc1, DcRole.PrimaryDC)
        manager.addMember("node-2", dc1, DcRole.PrimaryDC)
        manager.addMember("node-3", dc1, DcRole.PrimaryDC)

        // 备份数据中心 - us-west
        let dc2 = DatacenterId("dc2", "us-west")
        manager.addMember("node-4", dc2, DcRole.BackupDC)
        manager.addMember("node-5", dc2, DcRole.BackupDC)

        // 只读数据中心 - eu-west
        let dc3 = DatacenterId("dc3", "eu-west")
        manager.addMember("node-6", dc3, DcRole.ReadOnlyDC)

        // 更新心跳
        manager.updateHeartbeat("node-1")
        manager.updateHeartbeat("node-2")
        manager.updateHeartbeat("node-3")
        manager.updateHeartbeat("node-4")
        manager.updateHeartbeat("node-5")
        manager.updateHeartbeat("node-6")
    }

    /**
     * 演示 LocalDCFirst 策略
     */
    public func demonstrateLocalDcFirst(): Unit {
        println("=== LocalDCFirst 策略 ===")
        let target = router.selectTarget("dc1")
        match (target) {
            case Some(t) =>
                println("选择的节点: ${t.nodeId} (DC: ${t.datacenter.name})")
            case None =>
                println("没有可用的节点")
        }
    }

    /**
     * 演示 PrimaryDCOnly 策略
     */
    public func demonstratePrimaryDcOnly(): Unit {
        println("=== PrimaryDCOnly 策略 ===")
        let router2 = DcAwareRouter(manager, DcRoutingStrategy.PrimaryDCOnly)
        let target = router2.selectTarget("dc2")  // 请求来自 dc2，但只选择主 DC
        match (target) {
            case Some(t) =>
                println("选择的节点: ${t.nodeId} (DC: ${t.datacenter.name})")
            case None =>
                println("没有可用的节点")
        }
    }

    /**
     * 演示 AllDCs 策略
     */
    public func demonstrateAllDCs(): Unit {
        println("=== AllDCs 策略 ===")
        let router3 = DcAwareRouter(manager, DcRoutingStrategy.AllDCs)
        let target = router3.selectTarget("dc1")
        match (target) {
            case Some(t) =>
                println("选择的节点: ${t.nodeId} (DC: ${t.datacenter.name})")
            case None =>
                println("没有可用的节点")
        }
    }

    /**
     * 演示跨 DC 轮询策略
     */
    public func demonstrateRoundRobin(): Unit {
        println("=== RoundRobinAcrossDCs 策略 ===")
        let router4 = DcAwareRouter(manager, DcRoutingStrategy.RoundRobinAcrossDCs)
        // 选择多个目标
        let targets = router4.selectTargets("dc1", 3)
        for (target in targets) {
            println("选择的节点: ${target.nodeId} (DC: ${target.datacenter.name})")
        }
    }

    /**
     * 演示故障转移
     */
    public func demonstrateFailover(): Unit {
        println("=== DC 故障转移演示 ===")
        let failoverManager = DcFailoverManager(
            MultiDcConfig.defaultConfig(),
            manager
        )

        println("主 DC 是否可用: ${failoverManager.isPrimaryDCAvailable()}")
        println("当前活跃 DC: ${failoverManager.getActiveDC()}")

        // 模拟主 DC 不可用
        manager.markUnreachable("node-1")
        manager.markUnreachable("node-2")
        manager.markUnreachable("node-3")

        // 检查是否需要故障转移
        if (failoverManager.shouldFailover()) {
            match (failoverManager.executeFailover()) {
                case Some(newDc) =>
                    println("故障转移执行: 新 DC = ${newDc}")
                case None =>
                    println("故障转移失败: 没有可用的备份 DC")
            }
        }

        println("故障转移后活跃 DC: ${failoverManager.getActiveDC()}")
    }

    /**
     * 演示 DC 成员统计
     */
    public func demonstrateStats(): Unit {
        println("=== DC 成员统计 ===")
        let dcs = manager.getDatacenters()
        for (dc in dcs) {
            let count = manager.getMemberCount(dc)
            println("数据中心 ${dc}: ${count} 个成员")
        }
    }

    /**
     * 运行所有演示
     */
    public func run(): Unit {
        println("========================================")
        println("   CActor Multi-DC 多数据中心演示")
        println("========================================")

        setupMultiDcCluster()
        demonstrateStats()
        demonstrateLocalDcFirst()
        demonstratePrimaryDcOnly()
        demonstrateAllDCs()
        demonstrateRoundRobin()
        demonstrateFailover()

        println("========================================")
        println("   Multi-DC 演示完成!")
        println("========================================")
    }
}

/**
 * 主函数
 */
public func main(): Unit {
    let demo = MultiDcDemo()
    demo.run()
}