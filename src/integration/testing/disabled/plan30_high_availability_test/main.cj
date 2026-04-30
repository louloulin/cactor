/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Phase 3 高可用测试
 * 测试 Split Brain Resolver 和 Cluster Sharding
 */
package cactor.integration.testing.plan30_high_availability_test

import std.collection.*
import std.sync.*
import std.time.*
import cactor.distribution.cluster.*

/**
 * Split Brain Resolver 测试
 */
public class SplitBrainResolverTest {
    private let addr1 = Address("cactor", "system", "node1", 2552)
    private let addr2 = Address("cactor", "system", "node2", 2552)
    private let addr3 = Address("cactor", "system", "node3", 2552)
    private let addr4 = Address("cactor", "system", "node4", 2552)
    private let addr5 = Address("cactor", "system", "node5", 2552)

    public func testKeepMajorityWithMajority(): Bool {
        println("测试: KeepMajority - 有多数节点")
        let resolver = KeepMajorityResolver(SBRConfig.getDefault())

        let allNodes = HashSet<UniqueAddress>()
        allNodes.add(UniqueAddress(addr1, 1))
        allNodes.add(UniqueAddress(addr2, 2))
        allNodes.add(UniqueAddress(addr3, 3))
        allNodes.add(UniqueAddress(addr4, 4))
        allNodes.add(UniqueAddress(addr5, 5))

        // 3个可达，2个不可达
        let unreachable = HashSet<UniqueAddress>()
        unreachable.add(UniqueAddress(addr4, 4))
        unreachable.add(UniqueAddress(addr5, 5))

        let decision = resolver.resolve(allNodes, unreachable, HashSet<UniqueAddress>())

        assert(decision.survivors.size >= 3, "应有至少3个存活节点")
        assert(decision.victims.size == 2, "应有2个下线节点")
        println("  决策: ${decision.toString()}")
        true
    }

    public func testKeepMajorityMinority(): Bool {
        println("测试: KeepMajority - 少数节点")
        let resolver = KeepMajorityResolver(SBRConfig.getDefault())

        let allNodes = HashSet<UniqueAddress>()
        allNodes.add(UniqueAddress(addr1, 1))
        allNodes.add(UniqueAddress(addr2, 2))
        allNodes.add(UniqueAddress(addr3, 3))
        allNodes.add(UniqueAddress(addr4, 4))
        allNodes.add(UniqueAddress(addr5, 5))

        // 只有1个可达
        let reachable = HashSet<UniqueAddress>()
        reachable.add(UniqueAddress(addr1, 1))

        let unreachable = HashSet<UniqueAddress>()
        unreachable.add(UniqueAddress(addr2, 2))
        unreachable.add(UniqueAddress(addr3, 3))
        unreachable.add(UniqueAddress(addr4, 4))
        unreachable.add(UniqueAddress(addr5, 5))

        let decision = resolver.resolve(allNodes, unreachable, HashSet<UniqueAddress>())

        // 少数方应该全部下线
        assert(decision.survivors.size == 0, "少数方应无存活节点")
        println("  决策: ${decision.toString()}")
        true
    }

    public func testKeepOldest(): Bool {
        println("测试: KeepOldest - 保留最老节点")
        let resolver = KeepOldestResolver(SBRConfig.keepOldest())

        let allNodes = HashSet<UniqueAddress>()
        allNodes.add(UniqueAddress(addr1, 1))  // uid=1 最老
        allNodes.add(UniqueAddress(addr2, 2))
        allNodes.add(UniqueAddress(addr3, 3))

        let unreachable = HashSet<UniqueAddress>()
        unreachable.add(UniqueAddress(addr2, 2))
        unreachable.add(UniqueAddress(addr3, 3))

        let decision = resolver.resolve(allNodes, unreachable, HashSet<UniqueAddress>())

        assert(decision.survivors.size == 1, "应有1个存活节点")
        let survivor = decision.survivors.iter().next()
        match (survivor) {
            case Some(s) => assert(s.uid == 1, "最老节点应存活")
            case None => assert(false, "应有存活节点")
        }
        println("  决策: ${decision.toString()}")
        true
    }

    public func testStaticQuorum(): Bool {
        println("测试: StaticQuorum - 静态多数")
        let config = SBRConfig.staticQuorum(3)  // 需要3个节点
        let resolver = StaticQuorumResolver(config, 3)

        let allNodes = HashSet<UniqueAddress>()
        allNodes.add(UniqueAddress(addr1, 1))
        allNodes.add(UniqueAddress(addr2, 2))
        allNodes.add(UniqueAddress(addr3, 3))
        allNodes.add(UniqueAddress(addr4, 4))
        allNodes.add(UniqueAddress(addr5, 5))

        // 4个可达，达到 quorum
        let reachable = HashSet<UniqueAddress>()
        reachable.add(UniqueAddress(addr1, 1))
        reachable.add(UniqueAddress(addr2, 2))
        reachable.add(UniqueAddress(addr3, 3))
        reachable.add(UniqueAddress(addr4, 4))

        let unreachable = HashSet<UniqueAddress>()
        unreachable.add(UniqueAddress(addr5, 5))

        let decision = resolver.resolve(allNodes, unreachable, HashSet<UniqueAddress>())

        assert(decision.survivors.size >= 3, "应达到 quorum")
        println("  决策: ${decision.toString()}")
        true
    }

    public func testDownAll(): Bool {
        println("测试: DownAll - 全部下线")
        let resolver = DownAllResolver(SBRConfig.downAll())

        let allNodes = HashSet<UniqueAddress>()
        allNodes.add(UniqueAddress(addr1, 1))
        allNodes.add(UniqueAddress(addr2, 2))

        let unreachable = HashSet<UniqueAddress>()
        unreachable.add(UniqueAddress(addr2, 2))

        let decision = resolver.resolve(allNodes, unreachable, HashSet<UniqueAddress>())

        assert(decision.survivors.size == 0, "不应有存活节点")
        assert(decision.victims.size == 2, "所有节点都应下线")
        println("  决策: ${decision.toString()}")
        true
    }

    public func testSBRDecision(): Bool {
        println("测试: SBRDecision")
        let survivors = HashSet<UniqueAddress>()
        survivors.add(UniqueAddress(addr1, 1))

        let victims = HashSet<UniqueAddress>()
        victims.add(UniqueAddress(addr2, 2))

        let decision = SBRDecision(SBRStrategy.KeepMajority, survivors, victims, "test reason")

        assert(decision.strategy == SBRStrategy.KeepMajority, "策略不匹配")
        assert(decision.isSurvivor(UniqueAddress(addr1, 1)), "addr1 应该是存活者")
        assert(decision.isVictim(UniqueAddress(addr2, 2)), "addr2 应该是受害者")
        assert(!decision.isSurvivor(UniqueAddress(addr2, 2)), "addr2 不应该是存活者")
        println("  决策: ${decision.toString()}")
        true
    }

    public func testSBRStateTracker(): Bool {
        println("测试: SBRStateTracker")
        let tracker = SBRStateTracker()

        let node1 = UniqueAddress(addr1, 1)
        let node2 = UniqueAddress(addr2, 2)

        // 标记不可达
        tracker.markUnreachable(node1)
        tracker.markUnreachable(node2)

        let unreachable = tracker.getUnreachableNodes()
        assert(unreachable.size == 2, "应有2个不可达节点")

        // 标记恢复
        tracker.markReachable(node1)
        let afterRecover = tracker.getUnreachableNodes()
        assert(afterRecover.size == 1, "恢复后应有1个不可达节点")

        // 标记下线
        tracker.markDown(node2, "test down")
        let downed = tracker.getDownedNodes()
        assert(downed.size == 1, "应有1个已下线节点")

        println("  状态追踪正常")
        true
    }

    public func run(): Unit {
        println("\n=== Split Brain Resolver 测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testKeepMajorityWithMajority", testKeepMajorityWithMajority),
            ("testKeepMajorityMinority", testKeepMajorityMinority),
            ("testKeepOldest", testKeepOldest),
            ("testStaticQuorum", testStaticQuorum),
            ("testDownAll", testDownAll),
            ("testSBRDecision", testSBRDecision),
            ("testSBRStateTracker", testSBRStateTracker)
        ]

        for ((name, test) in tests) {
            try {
                if (test()) {
                    println("[PASS] ${name}")
                    passed += 1
                } else {
                    println("[FAIL] ${name}")
                    failed += 1
                }
            } catch (e: Exception) {
                println("[ERROR] ${name}: ${e.message}")
                failed += 1
            }
        }

        println("\nSBR 测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * Cluster Sharding 测试
 */
public class ClusterShardingTest {
    public func testHashShardResolver(): Bool {
        println("测试: HashShardResolver")
        let resolver = HashShardResolver()

        // 相同实体ID应得到相同分片
        let shard1 = resolver.shardId("entity-1", 10)
        let shard2 = resolver.shardId("entity-1", 10)
        assert(shard1 == shard2, "相同实体应得到相同分片")

        // 不同实体可能得到不同分片
        let shard3 = resolver.shardId("entity-2", 10)
        println("  entity-1 -> shard ${shard1}, entity-2 -> shard ${shard3}")

        // 分片ID应在有效范围内
        let shardNum = Int64.parse(shard1)
        assert(shardNum >= 1 && shardNum <= 10, "分片ID应在1-10范围内")

        true
    }

    public func testCursorShardResolver(): Bool {
        println("测试: CursorShardResolver")
        let resolver = CursorShardResolver()

        // 游标策略应轮流分配
        var shards = ArrayList<String>()
        for (i in 0..10) {
            shards.add(resolver.shardId("entity-${i}", 5))
        }

        // 验证分配
        println("  分配的分片: ${shards.toArray()}")
        assert(shards.size == 10, "应有10个分配")

        true
    }

    public func testShardingSettings(): Bool {
        println("测试: ShardingSettings")
        let settings = ShardingSettings.getDefault("User", 20)

        assert(settings.typeName == "User", "类型名不匹配")
        assert(settings.numberOfShards == 20, "分片数不匹配")
        assert(!settings.rememberEntities, "默认不应记住实体")

        true
    }

    public func testSimpleShard(): Bool {
        println("测试: SimpleShard")
        let settings = ShardingSettings.getDefault("Test", 5)
        let shard = SimpleShard("1", settings)

        // 添加实体
        let ref1 = shard.addEntity("entity-1")
        let ref2 = shard.addEntity("entity-2")

        assert(shard.entityCount() == 2, "应有2个实体")

        // 获取实体列表
        let ids = shard.getEntityIds()
        assert(ids.size == 2, "实体ID列表大小应为2")

        // 移除实体
        shard.removeEntity("entity-1")
        assert(shard.entityCount() == 1, "移除后应有1个实体")

        true
    }

    public func testSimpleShardRegion(): Bool {
        println("测试: SimpleShardRegion")
        let settings = ShardingSettings.getDefault("User", 10)
        let addr = Address("cactor", "system", "localhost", 2552)
        let path = ActorPath(addr.system, "/user")
        let region = SimpleShardRegion(settings, path)

        // 初始化
        region.initialize()

        // 获取实体引用
        let ref1 = region.entityRefFor("user-1")
        let ref2 = region.entityRefFor("user-2")
        let ref3 = region.entityRefFor("user-3")

        // 获取统计
        let stats = region.getStats()
        assert(stats.totalEntities >= 1, "应有至少1个实体")

        println("  分片统计: ${stats.totalShards} shards, ${stats.totalEntities} entities")

        // 关闭
        region.shutdown()

        true
    }

    public func testClusterSharding(): Bool {
        println("测试: ClusterSharding")
        let settings = ShardingSettings.getDefault("Order", numberOfShards: 15)
        let sharding = ClusterSharding(settings)

        // 启动
        let region = sharding.start()

        // 创建多个实体
        for (i in 0..50) {
            let ref = region.entityRefFor("order-${i}")
            assert(ref != None, "应能获取实体引用")
        }

        // 获取统计
        match (sharding.getStats("Order")) {
            case Some(stats) =>
                println("  Order 分片: ${stats.totalShards} shards, ${stats.totalEntities} entities")
                assert(stats.totalEntities == 50, "应有50个实体")
            case None =>
                assert(false, "应能获取统计")
        }

        // 关闭
        sharding.shutdown()

        true
    }

    public func testClusterShardingFactory(): Bool {
        println("测试: ClusterShardingFactory")
        let sharding = ClusterShardingFactory.createHashSharded("Product", numberOfShards: 20)

        let region = sharding.start()

        // 创建实体
        for (i in 0..100) {
            region.entityRefFor("product-${i}")
        }

        match (sharding.getStats("Product")) {
            case Some(stats) =>
                println("  Product 分片: ${stats.totalShards} shards, ${stats.totalEntities} entities")
                assert(stats.totalEntities == 100, "应有100个实体")
            case None =>
                assert(false, "应能获取统计")
        }

        sharding.shutdown()
        true
    }

    public func testEntityRef(): Bool {
        println("测试: EntityRefImpl")
        let addr = Address("cactor", "system", "localhost", 2552)
        let path = ActorPath(addr, ["sharding", "User"])
        let ref = EntityRefImpl("User", "user-123", "5", path)

        assert(ref.getEntityId() == "user-123", "实体ID不匹配")
        assert(ref.getShardId() == "5", "分片ID不匹配")

        // tell 方法不应抛出异常
        ref.tell(StringMessage("test"))

        true
    }

    public func run(): Unit {
        println("\n=== Cluster Sharding 测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testHashShardResolver", testHashShardResolver),
            ("testCursorShardResolver", testCursorShardResolver),
            ("testShardingSettings", testShardingSettings),
            ("testSimpleShard", testSimpleShard),
            ("testSimpleShardRegion", testSimpleShardRegion),
            ("testClusterSharding", testClusterSharding),
            ("testClusterShardingFactory", testClusterShardingFactory),
            ("testEntityRef", testEntityRef)
        ]

        for ((name, test) in tests) {
            try {
                if (test()) {
                    println("[PASS] ${name}")
                    passed += 1
                } else {
                    println("[FAIL] ${name}")
                    failed += 1
                }
            } catch (e: Exception) {
                println("[ERROR] ${name}: ${e.message}")
                failed += 1
            }
        }

        println("\nCluster Sharding 测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("CActor Phase 3 高可用测试套件")
    println("========================================")

    let sbrTest = SplitBrainResolverTest()
    sbrTest.run()

    let shardingTest = ClusterShardingTest()
    shardingTest.run()

    println("\n========================================")
    println("Phase 3 测试完成")
    println("========================================")
}
