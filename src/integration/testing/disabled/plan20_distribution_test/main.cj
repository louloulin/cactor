/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 分布式层测试
 * 测试远程传输、集群协议、成员管理功能
 */
package cactor.integration.testing.plan20_distribution_test

import std.collection.*
import std.sync.*
import std.time.*
import cactor.foundation.serialization.*
import cactor.distribution.remote.*
import cactor.distribution.cluster.*

// 使用cluster包的Address类型
let Address = cactor.distribution.cluster.Address

// 简单的断言函数
func assert(condition: Bool, message: String): Unit {
    if (!condition) {
        throw Exception("Assertion failed: ${message}")
    }
}

/**
 * 远程传输测试
 */
public class RemoteTransportTest {
    public func testAddress(): Bool {
        println("测试: RemoteAddress")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let str = addr.toString()
        println("  地址字符串: ${str}")
        assert(str == "cactor://test-system@localhost:2552", "地址字符串不匹配")
        true
    }

    public func testActorPath(): Bool {
        println("测试: ActorPath")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let path = ActorPath(addr, ["user", "actor1"])
        let str = path.toString()
        println("  路径字符串: ${str}")
        assert(str == "cactor://test-system@localhost:2552/user/actor1", "路径字符串不匹配")

        // 测试 parent
        let parent = path.parent()
        assert(parent.name() == "user", "父路径名称不匹配")

        // 测试 child
        let child = path.child("child")
        assert(child.name() == "child", "子路径名称不匹配")

        // 测试 parse
        let parsed = ActorPath.parse("cactor://system@host:8080/user/actor")
        assert(parsed.name() == "actor", "解析路径名称不匹配")

        true
    }

    public func testRemoteEnvelope(): Bool {
        println("测试: RemoteEnvelope")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let recipient = ActorPath(addr, ["user", "actor1"])
        let message = StringMessage("hello")
        let envelope = RemoteEnvelope(recipient, message, None)

        assert(envelope.serializerId == 0, "序列化器ID不匹配")
        assert(envelope.recipient == recipient, "接收者不匹配")

        println("  信封创建成功: ${envelope.toString()}")
        true
    }

    public func testSimpleRemoteTransport(): Bool {
        println("测试: SimpleRemoteTransport")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let transport = SimpleRemoteTransport(addr)

        // 检查初始状态
        assert(!transport.isStarted(), "传输层初始应为未启动")

        // 启动传输层
        let bindFuture = transport.bind()
        bindFuture.get()

        assert(transport.isStarted(), "传输层应已启动")
        println("  传输层地址: ${transport.address().toString()}")

        // 关闭传输层
        let shutdownFuture = transport.shutdown()
        shutdownFuture.get()

        true
    }

    public func testNetworkAddress(): Bool {
        println("测试: NetworkAddress")
        let addr = NetworkAddress("localhost", 8080)
        assert(addr.host == "localhost", "主机名不匹配")
        assert(addr.port == 8080, "端口不匹配")
        assert(addr.toString() == "localhost:8080", "地址字符串不匹配")
        true
    }

    public func testTransportFactory(): Bool {
        println("测试: TransportFactory")
        let addr = NetworkAddress("localhost", 9000)
        let transport = TransportFactory.createTransport(TransportProtocol.TCP, addr)

        assert(transport.getLocalAddress().host == "localhost", "传输层地址主机不匹配")
        assert(transport.getLocalAddress().port == 9000, "传输层地址端口不匹配")
        true
    }

    public func run(): Unit {
        println("\n=== 远程传输层测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testAddress", testAddress),
            ("testActorPath", testActorPath),
            ("testRemoteEnvelope", testRemoteEnvelope),
            ("testSimpleRemoteTransport", testSimpleRemoteTransport),
            ("testNetworkAddress", testNetworkAddress),
            ("testTransportFactory", testTransportFactory)
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

        println("\n远程传输测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * 集群协议测试
 */
public class ClusterProtocolTest {
    public func testMemberStatus(): Bool {
        println("测试: MemberStatus")
        let statuses = [
            (MemberStatus.Joining, 0),
            (MemberStatus.WeaklyUp, 1),
            (MemberStatus.Up, 2),
            (MemberStatus.Leaving, 3),
            (MemberStatus.Exiting, 4),
            (MemberStatus.Down, 5),
            (MemberStatus.Removed, 6)
        ]

        for ((status, expected) in statuses) {
            assert(status.toInt64() == expected, "状态值不匹配: ${status}")
        }

        // 测试 fromInt64
        assert(MemberStatus.fromInt64(0) == MemberStatus.Joining, "fromInt64 失败")
        assert(MemberStatus.fromInt64(99) == MemberStatus.Removed, "未知值应返回 Removed")

        // 测试 isAtLeast
        assert(MemberStatus.Up.isAtLeast(MemberStatus.Joining), "isAtLeast 失败")
        assert(!MemberStatus.Joining.isAtLeast(MemberStatus.Up), "isAtLeast 失败")

        // 测试 isActive
        assert(MemberStatus.Up.isActive(), "Up 应为活跃")
        assert(MemberStatus.WeaklyUp.isActive(), "WeaklyUp 应为活跃")
        assert(!MemberStatus.Down.isActive(), "Down 不应为活跃")

        true
    }

    public func testMemberRole(): Bool {
        println("测试: MemberRole")
        let role1 = MemberRole("worker")
        let role2 = MemberRole("worker")
        let role3 = MemberRole("frontend")

        assert(role1.name() == "worker", "角色名称不匹配")
        assert(role1.equals(role2), "相同角色应相等")
        assert(!role1.equals(role3), "不同角色应不相等")
        assert(role1.hashCode() == role2.hashCode(), "相同角色哈希应相等")

        true
    }

    public func testUniqueAddress(): Bool {
        println("测试: UniqueAddress")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let uid = 12345
        let unique = UniqueAddress(addr, uid)

        assert(unique.address == addr, "地址不匹配")
        assert(unique.uid == uid, "UID 不匹配")
        assert(unique.toString() == "cactor://test-system@localhost:2552:12345", "字符串不匹配")

        let unique2 = UniqueAddress(addr, uid)
        assert(unique.equals(unique2), "相同唯一地址应相等")

        true
    }

    public func testMemberImpl(): Bool {
        println("测试: MemberImpl")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let unique = UniqueAddress(addr, 12345)
        let roles = HashSet<MemberRole>()
        roles.add(MemberRole("worker"))

        let member = MemberImpl(unique, roles)

        assert(member.address() == addr, "地址不匹配")
        assert(member.status() == MemberStatus.Joining, "初始状态应为 Joining")
        assert(member.uniqueAddress() == unique, "唯一地址不匹配")
        assert(member.hasRole("worker"), "应包含 worker 角色")
        assert(!member.hasRole("frontend"), "不应包含 frontend 角色")
        assert(member.priority() == 12345, "优先级不匹配")

        true
    }

    public func testClusterState(): Bool {
        println("测试: ClusterState")
        let state = ClusterMembershipState()

        assert(state.memberCount() == 0, "初始成员数应为 0")
        assert(state.activeMemberCount() == 0, "初始活跃成员数应为 0")

        // 创建成员
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let unique = UniqueAddress(addr, 1)
        let roles = HashSet<MemberRole>()
        roles.add(MemberRole("worker"))
        let member = MemberImpl(unique, roles)

        state.members.add(unique, member)

        assert(state.memberCount() == 1, "成员数应为 1")
        assert(state.getMember(unique) != None, "应能找到成员")

        true
    }

    public func testReachability(): Bool {
        println("测试: Reachability")
        let reachability = Reachability()

        let addr = Address("cactor", "test-system", "localhost", 2552)
        let unique = UniqueAddress(addr, 1)

        // 默认可达
        assert(reachability.isReachable(unique), "默认应可达")
        assert(!reachability.isUnreachable(unique), "默认不应不可达")

        true
    }

    public func testClusterEvents(): Bool {
        println("测试: ClusterEvents")
        let addr = Address("cactor", "test-system", "localhost", 2552)
        let unique = UniqueAddress(addr, 1)
        let roles = HashSet<MemberRole>()
        let member = MemberImpl(unique, roles)

        let joined = MemberJoined(member)
        assert(joined.eventType() == "MemberJoined", "事件类型不匹配")

        let up = MemberUp(member)
        assert(up.eventType() == "MemberUp", "事件类型不匹配")

        let left = MemberLeft(member)
        assert(left.eventType() == "MemberLeft", "事件类型不匹配")

        let exited = MemberExited(member)
        assert(exited.eventType() == "MemberExited", "事件类型不匹配")

        let removed = MemberRemoved(member)
        assert(removed.eventType() == "MemberRemoved", "事件类型不匹配")

        let leader = LeaderChanged(Some(addr))
        assert(leader.eventType() == "LeaderChanged", "事件类型不匹配")

        true
    }

    public func run(): Unit {
        println("\n=== 集群协议测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testMemberStatus", testMemberStatus),
            ("testMemberRole", testMemberRole),
            ("testUniqueAddress", testUniqueAddress),
            ("testMemberImpl", testMemberImpl),
            ("testClusterState", testClusterState),
            ("testReachability", testReachability),
            ("testClusterEvents", testClusterEvents)
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

        println("\n集群协议测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * 序列化测试
 */
public class SerializationTest {
    public func testSerializationManager(): Bool {
        println("测试: SerializationManager")
        let manager = SerializationManager()

        // 测试字节数组序列化
        let originalBytes = Array<UInt8>([1, 2, 3, 4, 5])
        let serialized = manager.serializeBytes(originalBytes)
        let deserialized = manager.deserializeBytes(serialized)
        assert(deserialized == originalBytes, "字节序列化失败")

        // 测试字符串序列化
        let originalStr = "Hello, CActor!"
        let strSerialized = manager.serializeString(originalStr)
        let strDeserialized = manager.deserializeString(strSerialized)
        assert(strDeserialized == originalStr, "字符串序列化失败")

        // 测试整数序列化
        let originalInt: Int64 = 123456789
        let intSerialized = manager.serializeInt(originalInt)
        let intDeserialized = manager.deserializeInt(intSerialized)
        assert(intDeserialized == originalInt, "整数序列化失败")

        // 测试支持类型
        let types = manager.getSupportedTypes()
        assert(types.contains("bytes"), "应支持 bytes")
        assert(types.contains("string"), "应支持 string")
        assert(types.contains("int64"), "应支持 int64")

        true
    }

    public func testSerializationConfig(): Bool {
        println("测试: SerializationConfig")
        let config = SerializationConfig("protobuf", true, 1024 * 1024 * 10)

        assert(config.defaultFormat == "protobuf", "默认格式不匹配")
        assert(config.enableCompression, "应启用压缩")
        assert(config.maxMessageSize == 1024 * 1024 * 10, "最大消息大小不匹配")

        let defaultConfig = SerializationConfig.getDefault()
        assert(defaultConfig.defaultFormat == "json", "默认格式应为 json")
        assert(!defaultConfig.enableCompression, "默认不应启用压缩")
        assert(defaultConfig.maxMessageSize == 1024 * 1024, "默认最大消息大小应为 1MB")

        true
    }

    public func testSerializationStats(): Bool {
        println("测试: SerializationStats")
        let stats = SerializationStats()

        assert(stats.getSerializedCount() == 0, "初始序列化计数应为 0")
        assert(stats.getDeserializedCount() == 0, "初始反序列化计数应为 0")
        assert(stats.getErrorCount() == 0, "初始错误计数应为 0")

        // 记录序列化
        stats.recordSerialization(100)
        stats.recordSerialization(200)
        assert(stats.getSerializedCount() == 2, "序列化计数应为 2")
        assert(stats.getTotalSerializedBytes() == 300, "总序列化字节应为 300")

        // 记录反序列化
        stats.recordDeserialization(150)
        assert(stats.getDeserializedCount() == 1, "反序列化计数应为 1")
        assert(stats.getTotalDeserializedBytes() == 150, "总反序列化字节应为 150")

        // 记录错误
        stats.recordError()
        assert(stats.getErrorCount() == 1, "错误计数应为 1")

        // 平均大小
        let avgSer = stats.getAverageSerializedSize()
        assert(avgSer == 150.0, "平均序列化大小应为 150")

        // 重置
        stats.reset()
        assert(stats.getSerializedCount() == 0, "重置后序列化计数应为 0")

        true
    }

    public func testGlobalSerializationManager(): Bool {
        println("测试: GlobalSerializationManager")

        // 获取单例
        let instance1 = GlobalSerializationManager.getInstance()
        let instance2 = GlobalSerializationManager.getInstance()
        assert(instance1 == instance2, "单例应返回相同实例")

        // 创建自定义管理器
        let customManager = SerializationManager()
        GlobalSerializationManager.setInstance(customManager)

        let instance3 = GlobalSerializationManager.getInstance()
        assert(instance3 == customManager, "应返回自定义管理器")

        // 重置
        GlobalSerializationManager.reset()

        let instance4 = GlobalSerializationManager.getInstance()
        assert(instance4 != customManager, "重置后应返回新实例")

        true
    }

    public func run(): Unit {
        println("\n=== 序列化测试 ===")
        var passed = 0
        var failed = 0

        let tests = [
            ("testSerializationManager", testSerializationManager),
            ("testSerializationConfig", testSerializationConfig),
            ("testSerializationStats", testSerializationStats),
            ("testGlobalSerializationManager", testGlobalSerializationManager)
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

        println("\n序列化测试结果: ${passed} passed, ${failed} failed")
    }
}

/**
 * 主函数
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("CActor 分布式层测试套件")
    println("========================================")

    let remoteTest = RemoteTransportTest()
    remoteTest.run()

    let clusterTest = ClusterProtocolTest()
    clusterTest.run()

    let serializationTest = SerializationTest()
    serializationTest.run()

    println("\n========================================")
    println("测试完成")
    println("========================================")
}
