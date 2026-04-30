/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Sharding 单元测试
 */
package cactor.distribution.cluster

import std.collection.HashMap
import std.collection.HashSet
import std.time.*
import cactor.core.message.Message
import cactor.core.actor.ActorPath

// === Test Messages ===

class TestMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestMessage"
    }
}

// === HashShardResolver Tests ===

@Test
func testHashShardResolver_basic() {
    let resolver = HashShardResolver()
    let shardId = resolver.shardId("entity-1", 10)

    @Expect(shardId.size > 0, true)
}

@Test
func testHashShardResolver_consistentHashing() {
    let resolver = HashShardResolver()
    let shardId1 = resolver.shardId("entity-1", 10)
    let shardId2 = resolver.shardId("entity-1", 10)

    // Same entityId should always return same shard
    @Expect(shardId1, shardId2)
}

@Test
func testHashShardResolver_differentEntities() {
    let resolver = HashShardResolver()
    let shardId1 = resolver.shardId("entity-A", 10)
    let shardId2 = resolver.shardId("entity-B", 10)

    // Different entities may or may not be in same shard (depends on hash)
    // Just verify they are valid shard IDs
    @Expect(shardId1.size > 0, true)
    @Expect(shardId2.size > 0, true)
}

@Test
func testHashShardResolver_shardRange() {
    let resolver = HashShardResolver()
    let numberOfShards: Int64 = 10

    // Test multiple entities - verify shard IDs are valid
    for (i in 0..100) {
        let entityId = "entity-${i}"
        let shardId = resolver.shardId(entityId, numberOfShards)
        // Shard ID should be a non-empty string representing 1 to numberOfShards
        @Expect(shardId.size > 0, true)
        // Verify consistency - same entityId always gets same shard
        let shardId2 = resolver.shardId(entityId, numberOfShards)
        @Expect(shardId, shardId2)
    }
}

// === CursorShardResolver Tests ===

@Test
func testCursorShardResolver_roundRobin() {
    let resolver = CursorShardResolver()
    let numberOfShards: Int64 = 3

    let shard1 = resolver.shardId("entity-1", numberOfShards)
    let shard2 = resolver.shardId("entity-2", numberOfShards)
    let shard3 = resolver.shardId("entity-3", numberOfShards)
    let shard4 = resolver.shardId("entity-4", numberOfShards)

    // Round-robin distribution
    @Expect(shard1, "1")
    @Expect(shard2, "2")
    @Expect(shard3, "3")
    @Expect(shard4, "1")
}

@Test
func testCursorShardResolver_entityIdIgnored() {
    let resolver = CursorShardResolver()
    // entityId is ignored in cursor resolver
    let shard1 = resolver.shardId("A", 5)
    let shard2 = resolver.shardId("B", 5)

    @Expect(shard1 != shard2, true)
}

// === RoleShardResolver Tests ===

@Test
func testRoleShardResolver_basic() {
    let resolver = RoleShardResolver(10)
    let shardId = resolver.shardId("entity-1", 10)

    @Expect(shardId.size > 0, true)
}

@Test
func testRoleShardResolver_consistent() {
    let resolver = RoleShardResolver(10)
    let shardId1 = resolver.shardId("entity-X", 10)
    let shardId2 = resolver.shardId("entity-X", 10)

    @Expect(shardId1, shardId2)
}

// === ShardingSettings Tests ===

@Test
func testShardingSettings_defaultCreation() {
    let settings = ShardingSettings("TestEntity")

    @Expect(settings.typeName, "TestEntity")
    @Expect(settings.role, "")
    @Expect(settings.numberOfShards, 10)
    @Expect(settings.rememberEntities, false)
}

@Test
func testShardingSettings_customValues() {
    let settings = ShardingSettings(
        "CustomEntity",
        role: "backend",
        numberOfShards: 20,
        rememberEntities: true,
        rememberEntitiesStartAfter: Duration.second * 10,
        passivationStrategy: PassivationStrategy.Count(100)
    )

    @Expect(settings.typeName, "CustomEntity")
    @Expect(settings.role, "backend")
    @Expect(settings.numberOfShards, 20)
    @Expect(settings.rememberEntities, true)
    @Expect(settings.passivationStrategy.toString().contains("Count"), true)
}

@Test
func testShardingSettings_getDefault() {
    let settings = ShardingSettings.getDefault("DefaultEntity", 15)

    @Expect(settings.typeName, "DefaultEntity")
    @Expect(settings.numberOfShards, 15)
}

@Test
func testShardingSettings_withCustomResolver() {
    let resolver = CursorShardResolver()
    let settings = ShardingSettings("TestEntity", shardResolver: resolver)

    // Custom resolver should be set
    let shardId = settings.shardResolver.shardId("test", 10)
    @Expect(shardId.size > 0, true)
}

// === PassivationStrategy Tests ===

@Test
func testPassivationStrategy_values() {
    let idle = PassivationStrategy.Idle
    let count = PassivationStrategy.Count(50)
    let time = PassivationStrategy.Time(Duration.minute)
    let idleOrCount = PassivationStrategy.IdleOrCount(100, Duration.second * 30)
    let idleOrTime = PassivationStrategy.IdleOrTime(Duration.minute * 5)

    @Expect(idle.toString(), "Idle")
    @Expect(count.toString().contains("50"), true)
    @Expect(time.toString().contains("Time"), true)
}

@Test
func testPassivationStrategy_getDefault() {
    let strategy = PassivationStrategy.getDefault()
    let str = strategy.toString()

    @Expect(str.contains("IdleOrTime"), true)
}

// === ShardEnvelope Tests ===

@Test
func testShardEnvelope_creation() {
    let msg = TestMessage("hello")
    let envelope = ShardEnvelope("entity-123", msg)

    @Expect(envelope.entityId, "entity-123")
    match (envelope.message) {
        case m: TestMessage => @Expect(m.content, "hello")
        case _ => @Expect(false, true)
    }
}

// === ShardRegionState Tests ===

@Test
func testShardRegionState_creation() {
    let state = ShardRegionState("shard-1")

    @Expect(state.shardId, "shard-1")
    @Expect(state.entityIds.size(), 0)
    @Expect(state.totalEntityCount, 0)
    @Expect(state.avgEntityCountPerShard, 0.0)
}

@Test
func testShardRegionState_addEntity() {
    let state = ShardRegionState("shard-1")
    state.entityIds.add("entity-A")
    state.entityIds.add("entity-B")
    state.totalEntityCount = 2

    @Expect(state.entityIds.size(), 2)
    @Expect(state.totalEntityCount, 2)
}

// === ShardingStats Tests ===

@Test
func testShardingStats_creation() {
    let regions = HashMap<String, ShardRegionState>()
    let state = ShardRegionState("shard-1")
    state.entityIds.add("entity-A")
    state.totalEntityCount = 1
    regions.add("shard-1", state)

    let stats = ShardingStats(regions, 10, 1, 0.1)

    let regionsCount = stats.regions.size
    @Expect(regionsCount, 1)
    @Expect(stats.totalShards, 10)
    @Expect(stats.totalEntities, 1)
}

@Test
func testShardingStats_avgEntities() {
    let regions = HashMap<String, ShardRegionState>()

    // Add 3 shards with 6 entities total
    for (i in 1..=3) {
        let state = ShardRegionState("shard-${i}")
        state.entityIds.add("entity-${i}-1")
        state.entityIds.add("entity-${i}-2")
        state.totalEntityCount = 2
        regions.add("shard-${i}", state)
    }

    let stats = ShardingStats(regions, 3, 6, 2.0)

    let regionsCount = stats.regions.size
    @Expect(regionsCount, 3)
    @Expect(stats.totalShards, 3)
    @Expect(stats.totalEntities, 6)
    @Expect(stats.avgEntitiesPerShard, 2.0)
}

// === SimpleShard Tests ===

@Test
func testSimpleShard_shardId() {
    let settings = ShardingSettings("TestEntity", numberOfShards: 10)
    let shard = SimpleShard("shard-5", settings)

    @Expect(shard.shardId(), "shard-5")
}

@Test
func testSimpleShard_entityCount() {
    let settings = ShardingSettings("TestEntity", numberOfShards: 10)
    let shard = SimpleShard("shard-1", settings)

    @Expect(shard.entityCount(), 0)
}

@Test
func testSimpleShard_addEntity() {
    let settings = ShardingSettings("TestEntity", numberOfShards: 10)
    let shard = SimpleShard("shard-1", settings)

    let ref = shard.addEntity("entity-1")

    @Expect(shard.entityCount(), 1)
    match (ref) {
        case r: EntityRefImpl => @Expect(r.getEntityId(), "entity-1")
        case _ => @Expect(false, true)
    }
}

@Test
func testSimpleShard_addMultipleEntities() {
    let settings = ShardingSettings("TestEntity", numberOfShards: 10)
    let shard = SimpleShard("shard-1", settings)

    shard.addEntity("entity-A")
    shard.addEntity("entity-B")
    shard.addEntity("entity-C")

    @Expect(shard.entityCount(), 3)
}

@Test
func testSimpleShard_removeEntity() {
    let settings = ShardingSettings("TestEntity", numberOfShards: 10)
    let shard = SimpleShard("shard-1", settings)

    shard.addEntity("entity-1")
    shard.addEntity("entity-2")
    @Expect(shard.entityCount(), 2)

    shard.removeEntity("entity-1")
    @Expect(shard.entityCount(), 1)
}

@Test
func testSimpleShard_getEntityIds() {
    let settings = ShardingSettings("TestEntity", numberOfShards: 10)
    let shard = SimpleShard("shard-1", settings)

    shard.addEntity("entity-A")
    shard.addEntity("entity-B")

    let ids = shard.getEntityIds()
    @Expect(ids.size, 2)
}

@Test
func testSimpleShard_shardIdForEntity() {
    let resolver = HashShardResolver()
    let settings = ShardingSettings("TestEntity", numberOfShards: 10, shardResolver: resolver)
    let shard = SimpleShard("shard-1", settings)

    let entityShardId = shard.shardIdForEntity("test-entity")
    @Expect(entityShardId.size > 0, true)
}

// === EntityRefImpl Tests ===

@Test
func testEntityRefImpl_creation() {
    let path = ActorPath("test", "/user/shard")
    let ref = EntityRefImpl("TestEntity", "entity-123", "shard-5", path)

    @Expect(ref.getEntityId(), "entity-123")
    @Expect(ref.getShardId(), "shard-5")
}

@Test
func testEntityRefImpl_tell() {
    let path = ActorPath("test", "/user/shard")
    let ref = EntityRefImpl("TestEntity", "entity-1", "shard-1", path)
    let msg = TestMessage("test")

    // tell should not throw
    ref.tell(msg)
    @Expect(true, true)
}

@Test
func testEntityRefImpl_ask() {
    let path = ActorPath("test", "/user/shard")
    let ref = EntityRefImpl("TestEntity", "entity-1", "shard-1", path)
    let msg = TestMessage("test")

    let response = ref.ask(msg, Duration.second)

    // Simplified implementation returns None
    match (response) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}

// === ShardCommand Tests ===

@Test
func testShardCommand_Add() {
    let cmd = ShardCommand.Add("entity-1", EntityRefImpl("T", "e1", "s1", ActorPath("test", "/u")))

    match (cmd) {
        case ShardCommand.Add(id, _) => @Expect(id, "entity-1")
        case _ => @Expect(false, true)
    }
}

@Test
func testShardCommand_Remove() {
    let cmd = ShardCommand.Remove("entity-2")

    match (cmd) {
        case ShardCommand.Remove(id) => @Expect(id, "entity-2")
        case _ => @Expect(false, true)
    }
}

@Test
func testShardCommand_Passivate() {
    let cmd = ShardCommand.Passivate("entity-3")

    match (cmd) {
        case ShardCommand.Passivate(id) => @Expect(id, "entity-3")
        case _ => @Expect(false, true)
    }
}

@Test
func testShardCommand_GetEntityIds() {
    let cmd = ShardCommand.GetEntityIds

    match (cmd) {
        case ShardCommand.GetEntityIds => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testShardCommand_GetStats() {
    let cmd = ShardCommand.GetStats

    match (cmd) {
        case ShardCommand.GetStats => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

// === Integration Tests ===

@Test
func testShardResolver_consistency() {
    let hashResolver = HashShardResolver()
    let cursorResolver = CursorShardResolver()

    // Hash resolver should be consistent
    let hash1 = hashResolver.shardId("entity-1", 10)
    let hash2 = hashResolver.shardId("entity-1", 10)
    @Expect(hash1, hash2)

    // Cursor resolver should cycle through
    let cursor1 = cursorResolver.shardId("entity-A", 3)
    let cursor2 = cursorResolver.shardId("entity-B", 3)
    let cursor3 = cursorResolver.shardId("entity-C", 3)
    @Expect(cursor1 != cursor2, true)
    @Expect(cursor2 != cursor3, true)
}

@Test
func testShardingFlow_endToEnd() {
    // Create settings
    let settings = ShardingSettings("UserEntity", numberOfShards: 5)

    // Create shard
    let shard = SimpleShard("shard-1", settings)

    // Add entities
    let ref1 = shard.addEntity("user-1")
    let ref2 = shard.addEntity("user-2")
    let ref3 = shard.addEntity("user-3")

    // Verify entities
    @Expect(shard.entityCount(), 3)

    // Get entity IDs
    let ids = shard.getEntityIds()
    @Expect(ids.size, 3)

    // Remove one entity
    shard.removeEntity("user-2")
    @Expect(shard.entityCount(), 2)
}
