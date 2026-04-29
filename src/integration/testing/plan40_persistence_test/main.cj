/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Phase 4-5 持久化和流处理测试
 */
package cactor.integration.testing.plan40_persistence_test

import std.collection.*
import std.sync.*
import std.time.*
import cactor.distribution.persistence.*
import cactor.distribution.streaming.*

/**
 * 事件溯源测试
 */
public class EventSourcingTest {
    public func testDomainEvent(): Bool {
        println("测试: DomainEvent")
        let event = DomainEvent("UserCreated", "user-123", 1)
        assert(event.eventType() == "UserCreated", "事件类型不匹配")
        assert(event.sequenceNr() == 1, "序列号不匹配")
        assert(event.eventData() == "user-123", "事件数据不匹配")
        true
    }

    public func testSnapshotMetadata(): Bool {
        println("测试: SnapshotMetadata")
        let metadata = SnapshotMetadata("user-1", 100)
        assert(metadata.persistenceId == "user-1", "持久化ID不匹配")
        assert(metadata.sequenceNr == 100, "序列号不匹配")
        assert(metadata.toString() == "user-1-100", "字符串不匹配")
        true
    }

    public func testRecovery(): Bool {
        println("测试: Recovery")
        let recovery = Recovery()
        assert(recovery.fromSnapshot, "默认应从快照恢复")
        assert(recovery.toSequenceNr == Int64.Max, "默认应恢复所有")
        true
    }

    public func testInMemoryJournal(): Bool {
        println("测试: InMemoryJournal")
        let journal = InMemoryJournal()

        // 写入事件
        let event = DomainEvent("TestEvent", "data", 1)
        journal.write("test-1", event)

        // 读取事件
        let events = journal.read("test-1", 1, 10)
        assert(events.size == 1, "应有1个事件")

        // 最高序列号
        let maxSeq = journal.highestSequenceNr("test-1")
        assert(maxSeq == 1, "最高序列号应为1")

        // 存在性
        assert(journal.exists("test-1"), "应存在")

        true
    }

    public func testInMemorySnapshotStore(): Bool {
        println("测试: InMemorySnapshotStore")
        let store = InMemorySnapshotStore()

        // 保存快照
        let metadata = SnapshotMetadata("entity-1", 50)
        store.save(metadata, "state-data")

        // 加载最新
        match (store.loadLatest("entity-1")) {
            case Some((meta, data)) =>
                assert(meta.sequenceNr == 50, "序列号不匹配")
                assert(data == "state-data", "状态数据不匹配")
            case None =>
                assert(false, "应能加载快照")
        }

        true
    }

    public func testPersistenceSystem(): Bool {
        println("测试: PersistenceSystem")
        let system = PersistenceSystem()

        // 创建持久化 Actor
        let actor = system.createPersistentActor("test-actor")

        assert(actor.persistenceId() == "test-actor", "持久化ID不匹配")

        // 获取 Journal 和 SnapshotStore
        let journal = system.journal()
        let snapshotStore = system.snapshotStore()
        assert(journal \!= None, "应有 Journal")
        assert(snapshotStore \!= None, "应有 SnapshotStore")

        true
    }

    public func run(): Unit {
        println("\n=== 事件溯源测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testDomainEvent", testDomainEvent),
            ("testSnapshotMetadata", testSnapshotMetadata),
            ("testRecovery", testRecovery),
            ("testInMemoryJournal", testInMemoryJournal),
            ("testInMemorySnapshotStore", testInMemorySnapshotStore),
            ("testPersistenceSystem", testPersistenceSystem)
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

        println("\n事件溯源测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * 流处理测试
 */
public class StreamProcessingTest {
    public func testNotUsed(): Bool {
        println("测试: NotUsed")
        let instance1 = NotUsed.getInstance()
        let instance2 = NotUsed.getInstance()
        assert(instance1 === instance2, "应为单例")
        true
    }

    public func testStreamShape(): Bool {
        println("测试: StreamShape")
        let shape = StreamShape[Int, String]()
        assert(shape.inPort \!= None, "应有输入端口")
        assert(shape.outPort \!= None, "应有输出端口")
        true
    }

    public func testSourceSingle(): Bool {
        println("测试: Source.single")
        let source = SourceFactory.single(42)
        assert(source \!= None, "应有 Source")

        let sink = SinkFactory.count[Int]()
        let result = source.runWith(sink)
        assert(result == 1, "应有1个元素")
        true
    }

    public func testSourceRange(): Bool {
        println("测试: Source.range")
        let source = SourceFactory.range(1, 6)
        let sink = SinkFactory.toArray[Int64]()
        let result = source.runWith(sink)
        assert(result.size == 5, "应有5个元素")
        true
    }

    public func testSourceMap(): Bool {
        println("测试: Source.map")
        let source = SourceFactory.range(1, 5)
        let mapped = source.map({ (x: Int64) => x * 2 })
        let sink = SinkFactory.toArray[Int64]()
        let result = mapped.runWith(sink)
        assert(result.size == 4, "应有4个元素")
        true
    }

    public func testSourceFilter(): Bool {
        println("测试: Source.filter")
        let source = SourceFactory.range(1, 10)
        let filtered = source.filter({ (x: Int64) => x % 2 == 0 })
        let sink = SinkFactory.toArray[Int64]()
        let result = filtered.runWith(sink)
        assert(result.size == 4, "应有4个偶数")
        true
    }

    public func testSinkFold(): Bool {
        println("测试: Sink.fold")
        let source = SourceFactory.range(1, 6)
        let sink = SinkFactory.fold[Int64, Int64](0, { (acc, x) => acc + x })
        let result = source.runWith(sink)
        assert(result == 15, "求和应为15 (1+2+3+4+5)")
        true
    }

    public func testSinkForeach(): Bool {
        println("测试: Sink.foreach")
        var count = 0
        let source = SourceFactory.range(1, 5)
        let sink = SinkFactory.foreach[Int64]({ (x: Int64) => count += 1 })
        source.runWith(sink)
        assert(count == 4, "应处理4个元素")
        true
    }

    public func testFlowIdentity(): Bool {
        println("测试: Flow.identity")
        let flow = FlowFactory.identity[Int64]()
        let source = SourceFactory.range(1, 5)
        let result = source.via(flow).runWith(SinkFactory.toArray[Int64]())
        assert(result.size == 4, "应有4个元素")
        true
    }

    public func testFlowMap(): Bool {
        println("测试: Flow.map")
        let flow = FlowFactory.map[Int64, String]({ (x: Int64) => "num-${x}" })
        let source = SourceFactory.range(1, 4)
        let result = source.via(flow).runWith(SinkFactory.toArray[String]())
        assert(result.size == 3, "应有3个元素")
        true
    }

    public func testFlowFilter(): Bool {
        println("测试: Flow.filter")
        let flow = FlowFactory.filter[Int64]({ (x: Int64) => x > 5 })
        let source = SourceFactory.range(1, 11)
        let result = source.via(flow).runWith(SinkFactory.toArray[Int64]())
        assert(result.size == 5, "应有5个大于5的元素")
        true
    }

    public func testBroadcast(): Bool {
        println("测试: Broadcast")
        let broadcast = Broadcast[Int64](3)
        let shape = broadcast.shape()
        assert(shape \!= None, "应有形状")
        true
    }

    public func testMerge(): Bool {
        println("测试: Merge")
        let merge = Merge[Int64]()
        let shape = merge.shape()
        assert(shape \!= None, "应有形状")
        true
    }

    public func testBackoffStrategy(): Bool {
        println("测试: BackoffStrategy")
        assert(BackoffStrategy.None.toString() == "None", "策略名称不匹配")
        assert(BackoffStrategy.Buffer(10).toString() == "Buffer(10)", "Buffer名称不匹配")
        true
    }

    public func testSupervisionStrategy(): Bool {
        println("测试: SupervisionStrategy")
        assert(SupervisionStrategy.Resume.toString() == "Resume", "策略名称不匹配")
        assert(SupervisionStrategy.Stop.toString() == "Stop", "策略名称不匹配")
        true
    }

    public func run(): Unit {
        println("\n=== 流处理测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testNotUsed", testNotUsed),
            ("testStreamShape", testStreamShape),
            ("testSourceSingle", testSourceSingle),
            ("testSourceRange", testSourceRange),
            ("testSourceMap", testSourceMap),
            ("testSourceFilter", testSourceFilter),
            ("testSinkFold", testSinkFold),
            ("testSinkForeach", testSinkForeach),
            ("testFlowIdentity", testFlowIdentity),
            ("testFlowMap", testFlowMap),
            ("testFlowFilter", testFlowFilter),
            ("testBroadcast", testBroadcast),
            ("testMerge", testMerge),
            ("testBackoffStrategy", testBackoffStrategy),
            ("testSupervisionStrategy", testSupervisionStrategy)
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

        println("\n流处理测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * 主函数
 */
public main(args: Array<String>): Unit {
    println("========================================")
    println("CActor Phase 4-5 持久化和流处理测试套件")
    println("========================================")

    let esTest = EventSourcingTest()
    esTest.run()

    let streamTest = StreamProcessingTest()
    streamTest.run()

    println("\n========================================")
    println("Phase 4-5 测试完成")
    println("========================================")
}
