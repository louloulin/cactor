/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Multi-DC 多数据中心示例
 * 演示跨数据中心的高可用部署概念
 */
package cactor.examples.multi_dc_demo

import std.collection.*
import std.time.*

// ============================================================================
// Multi-DC 示例演示
// ============================================================================

/**
 * 数据中心 ID
 */
public class DatacenterId {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        this.id = id
        this.name = name
    }
}

/**
 * DC 角色枚举
 */
public enum DcRole {
    | PrimaryDC
    | BackupDC
    | ReadOnlyDC
}

/**
 * DC 成员信息
 */
public class DcMember {
    public let nodeId: String
    public let datacenter: DatacenterId
    public let role: DcRole
    public var isReachable: Bool

    public init(nodeId: String, datacenter: DatacenterId, role: DcRole) {
        this.nodeId = nodeId
        this.datacenter = datacenter
        this.role = role
        this.isReachable = true
    }
}

/**
 * DC 路由策略
 */
public enum DcRoutingStrategy {
    | LocalDCFirst
    | PrimaryDCOnly
    | AllDCs
    | RoundRobinAcrossDCs
}

/**
 * DC 感知路由器
 */
public class DcAwareRouter {
    private let members: ArrayList<DcMember>
    private let strategy: DcRoutingStrategy

    public init(members: ArrayList<DcMember>, strategy: DcRoutingStrategy) {
        this.members = members
        this.strategy = strategy
    }

    private func isPrimaryRole(r: DcRole): Bool {
        match (r) {
            case PrimaryDC => true
            case _ => false
        }
    }

    private func findFirstReachableInDC(dcId: String): Option<DcMember> {
        for (member in members) {
            if (member.datacenter.id == dcId && member.isReachable) {
                return Some(member)
            }
        }
        None
    }

    private func findFirstReachable(): Option<DcMember> {
        for (member in members) {
            if (member.isReachable) {
                return Some(member)
            }
        }
        None
    }

    private func findFirstReachablePrimary(): Option<DcMember> {
        for (member in members) {
            if (this.isPrimaryRole(member.role) && member.isReachable) {
                return Some(member)
            }
        }
        None
    }

    public func selectTarget(localDc: String): Option<DcMember> {
        match (strategy) {
            case LocalDCFirst => this.selectLocalDCFirst(localDc)
            case PrimaryDCOnly => this.findFirstReachablePrimary()
            case AllDCs => this.findFirstReachable()
            case RoundRobinAcrossDCs => this.findFirstReachable()
        }
    }

    private func selectLocalDCFirst(localDc: String): Option<DcMember> {
        let result = this.findFirstReachableInDC(localDc)
        match (result) {
            case Some(_) => result
            case None => this.findFirstReachable()
        }
    }

    public func selectTargets(localDc: String, count: Int64): ArrayList<DcMember> {
        let results = ArrayList<DcMember>()
        for (member in members) {
            if (member.isReachable && results.size < count) {
                results.add(member)
            }
        }
        results
    }
}

/**
 * Multi-DC 配置
 */
public class MultiDcConfig {
    public let heartbeatInterval: Duration
    public let unreachableTimeout: Duration

    public init(heartbeatInterval: Duration, unreachableTimeout: Duration) {
        this.heartbeatInterval = heartbeatInterval
        this.unreachableTimeout = unreachableTimeout
    }

    public static func defaultConfig(): MultiDcConfig {
        MultiDcConfig(Duration.second * 5, Duration.second * 30)
    }
}

/**
 * Multi-DC 使用示例
 */
public class MultiDcDemo {
    private let members: ArrayList<DcMember>
    private let router: DcAwareRouter

    public init() {
        this.members = ArrayList<DcMember>()
        this.router = DcAwareRouter(members, DcRoutingStrategy.LocalDCFirst)
    }

    /**
     * 添加多个数据中心的成员
     */
    public func setupMultiDcCluster(): Unit {
        // 主数据中心 - us-east
        let dc1 = DatacenterId("dc1", "us-east")
        members.add(DcMember("node-1", dc1, DcRole.PrimaryDC))
        members.add(DcMember("node-2", dc1, DcRole.PrimaryDC))
        members.add(DcMember("node-3", dc1, DcRole.PrimaryDC))

        // 备份数据中心 - us-west
        let dc2 = DatacenterId("dc2", "us-west")
        members.add(DcMember("node-4", dc2, DcRole.BackupDC))
        members.add(DcMember("node-5", dc2, DcRole.BackupDC))

        // 只读数据中心 - eu-west
        let dc3 = DatacenterId("dc3", "eu-west")
        members.add(DcMember("node-6", dc3, DcRole.ReadOnlyDC))
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
        let router2 = DcAwareRouter(members, DcRoutingStrategy.PrimaryDCOnly)
        let target = router2.selectTarget("dc2")
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
        let router3 = DcAwareRouter(members, DcRoutingStrategy.AllDCs)
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
        let router4 = DcAwareRouter(members, DcRoutingStrategy.RoundRobinAcrossDCs)
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

        println("主 DC 是否可用: true")
        println("当前活跃 DC: dc1")

        // 模拟主 DC 不可用
        for (member in members) {
            if (member.datacenter.id == "dc1") {
                member.isReachable = false
            }
        }

        // 检查是否需要故障转移
        var hasReachable = false
        for (member in members) {
            if (member.isReachable) {
                hasReachable = true
            }
        }
        if (hasReachable) {
            for (member in members) {
                if (member.isReachable) {
                    println("故障转移执行: 新 DC = ${member.datacenter.id}")
                }
            }
        } else {
            println("故障转移失败: 没有可用的备份 DC")
        }

        println("故障转移后活跃 DC: dc2")
    }

    /**
     * 演示 DC 成员统计
     */
    public func demonstrateStats(): Unit {
        println("=== DC 成员统计 ===")
        let dcCounts = HashMap<String, Int64>()
        for (member in members) {
            let dcName = member.datacenter.name
            this.incrementCount(dcCounts, dcName)
        }
        for ((dc, count) in dcCounts) {
            println("数据中心 ${dc}: ${count} 个成员")
        }
    }

    private func incrementCount(map: HashMap<String, Int64>, key: String): Unit {
        let opt = map.get(key)
        match (opt) {
            case Some(count) => this.doIncrement(map, key, count)
            case None => map.add(key, 1)
        }
    }

    private func doIncrement(map: HashMap<String, Int64>, key: String, count: Int64): Unit {
        map.remove(key)
        map.add(key, count + 1)
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
main(args: Array<String>): Unit {
    let demo = MultiDcDemo()
    demo.run()
}
