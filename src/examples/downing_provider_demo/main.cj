/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - DowningProvider 示例程序
 * 展示集群宕机处理机制的多种策略
 */
package cactor.examples.downing_provider_demo

import std.collection.*
import std.time.*

import cactor.distribution.cluster.*

/**
 * 演示处理器
 */
public class DemoDowningHandler <: DowningProvider {
    public let decisions = ArrayList<DowningDecision>()

    public func handleUnreachable(members: ArrayList<MemberInfo2>): DowningDecision {
        let decision = downAllImpl(members)
        decisions.add(decision)
        decision
    }

    public func handleMemberChange(members: ArrayList<MemberInfo2>): DowningDecision {
        DowningDecision(ArrayList<MemberInfo2>(), "demo-handler")
    }

    public func name(): String {
        "demo-downing"
    }

    private func downAllImpl(members: ArrayList<MemberInfo2>): DowningDecision {
        let toDown = ArrayList<MemberInfo2>()
        for (member in members) {
            match (member.reachability) {
                case DowningReachability.Unreachable =>
                    toDown.add(member.withReachability(DowningReachability.Down))
                case _ => ()
            }
        }
        DowningDecision(toDown, "demo-down-all")
    }
}

/**
 * 创建成员信息
 */
public func createMemberInfo(nodeId: String, host: String, port: Int32, reachability: DowningReachability): MemberInfo2 {
    let addr = Address("cactor", "demo", host, port)
    let member = MemberInfo2(nodeId, addr)
    member.reachability = reachability
    member
}

/**
 * 运行 AutoDowningProvider 演示
 */
public func runAutoDowningDemo(): Unit {
    println("=== Auto Downing Provider Demo ===")
    let provider = createAutoDowningProvider(Duration.second * 5)

    let members = ArrayList<MemberInfo2>()
    members.add(createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable))

    let decision = provider.handleUnreachable(members)
    println("All reachable: decision size = ${decision.size()}")

    // 添加不可达节点
    members.add(createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable))
    let decision2 = provider.handleUnreachable(members)
    println("One unreachable: decision size = ${decision2.size()}")

    println()
}

/**
 * 运行 Majority Downing Provider 演示
 */
public func runMajorityDowningDemo(): Unit {
    println("=== Majority Downing Provider Demo ===")
    let selfAddr = Address("cactor", "demo", "localhost", 2552)
    let provider = createMajorityDowningProvider(selfAddr)

    // 5 节点，3 可达，2 不可达
    let members = ArrayList<MemberInfo2>()
    members.add(createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-3", "host3", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-4", "host4", 2552, DowningReachability.Unreachable))
    members.add(createMemberInfo("node-5", "host5", 2552, DowningReachability.Unreachable))

    let decision = provider.handleUnreachable(members)
    println("Majority partition (3/5): decision size = ${decision.size()}, reason = ${decision.reason}")

    // 少数派场景：2 可达，3 不可达
    let members2 = ArrayList<MemberInfo2>()
    members2.add(createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable))
    members2.add(createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable))
    members2.add(createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable))
    members2.add(createMemberInfo("node-4", "host4", 2552, DowningReachability.Unreachable))
    members2.add(createMemberInfo("node-5", "host5", 2552, DowningReachability.Unreachable))

    let decision2 = provider.handleUnreachable(members2)
    println("Minority partition (2/5): decision size = ${decision2.size()}, reason = ${decision2.reason}")

    println()
}

/**
 * 运行 StaticQuorum Downing Provider 演示
 */
public func runStaticQuorumDowningDemo(): Unit {
    println("=== Static Quorum Downing Provider Demo ===")
    let provider = createStaticQuorumDowningProvider(3)

    // 3 可达 >= quorum 3，无操作
    let members = ArrayList<MemberInfo2>()
    members.add(createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable))

    let decision = provider.handleUnreachable(members)
    println("Above quorum (3 >= 3): decision size = ${decision.size()}")

    // 2 可达 < quorum 3，下线不可达
    let members2 = ArrayList<MemberInfo2>()
    members2.add(createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable))
    members2.add(createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable))
    members2.add(createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable))
    members2.add(createMemberInfo("node-4", "host4", 2552, DowningReachability.Unreachable))

    let decision2 = provider.handleUnreachable(members2)
    println("Below quorum (2 < 3): decision size = ${decision2.size()}, reason = ${decision2.reason}")

    println()
}

/**
 * 运行 KeepOldest Downing Provider 演示
 */
public func runKeepOldestDowningDemo(): Unit {
    println("=== Keep Oldest Downing Provider Demo ===")
    let provider = KeepOldestDowningProvider(true)

    let members = ArrayList<MemberInfo2>()
    let m1 = createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable)
    m1.upTimestamp = 1000  // 最老
    let m2 = createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable)
    m2.upTimestamp = 2000
    let m3 = createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable)
    m3.upTimestamp = 3000
    members.add(m1)
    members.add(m2)
    members.add(m3)

    let decision = provider.handleUnreachable(members)
    println("Oldest reachable: decision size = ${decision.size()}, reason = ${decision.reason}")
    println("Only non-oldest unreachable node is marked down")

    // 最老节点不可达场景
    let provider2 = KeepOldestDowningProvider(true)
    let m1b = createMemberInfo("node-1", "host1", 2552, DowningReachability.Unreachable)
    m1b.upTimestamp = 1000  // 最老，但不可达
    let m2b = createMemberInfo("node-2", "host2", 2552, DowningReachability.Reachable)
    m2b.upTimestamp = 2000
    let m3b = createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable)
    m3b.upTimestamp = 3000
    let members2 = ArrayList<MemberInfo2>()
    members2.add(m1b)
    members2.add(m2b)
    members2.add(m3b)

    let decision2 = provider2.handleUnreachable(members2)
    println("Oldest unreachable (downIfOldest=true): decision size = ${decision2.size()}")

    println()
}

/**
 * 运行 DownAll Downing Provider 演示
 */
public func runDownAllDowningDemo(): Unit {
    println("=== Down All Downing Provider Demo ===")
    let provider = DownAllDowningProvider()

    let members = ArrayList<MemberInfo2>()
    members.add(createMemberInfo("node-1", "host1", 2552, DowningReachability.Reachable))
    members.add(createMemberInfo("node-2", "host2", 2552, DowningReachability.Unreachable))
    members.add(createMemberInfo("node-3", "host3", 2552, DowningReachability.Unreachable))

    let decision = provider.handleUnreachable(members)
    println("Down all unreachable: decision size = ${decision.size()}")

    println()
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    println("CActor DowningProvider Demo")
    println("============================")
    println()

    runAutoDowningDemo()
    runMajorityDowningDemo()
    runStaticQuorumDowningDemo()
    runKeepOldestDowningDemo()
    runDownAllDowningDemo()

    println("=== Demo Complete ===")
}
