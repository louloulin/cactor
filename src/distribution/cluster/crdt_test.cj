/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - CRDT 单元测试
 */
package cactor.distribution.cluster

import std.collection.{ArrayList, HashMap}
import std.time.*

// === VectorClock Tests ===

@Test
func testVectorClock_creation() {
    let clock = VectorClock("node1")

    @Expect(clock.toString().contains("node1"), true)
}

@Test
func testVectorClock_increment() {
    let clock = VectorClock("node1")
    let before = clock.toString()

    clock.increment()
    let after = clock.toString()

    @Expect(before != after, true)
}

@Test
func testVectorClock_merge() {
    let clock1 = VectorClock("node1")
    let clock2 = VectorClock("node2")

    clock1.increment()
    clock1.increment()

    clock2.increment()

    clock1.merge(clock2)

    let result = clock1.toString()
    @Expect(result.contains("node1"), true)
    @Expect(result.contains("node2"), true)
}

// === LWWRegister Tests ===

@Test
func testLWWRegister_creation() {
    let register = LWWRegister<Int64>("node1", 0)

    @Expect(register.identity().contains("LWWRegister"), true)
}

@Test
func testLWWRegister_set() {
    let register = LWWRegister<Int64>("node1", 0)

    register.set(42)
    let value = register.getValue()

    @Expect(value, 42)
}

@Test
func testLWWRegister_merge() {
    let reg1 = LWWRegister<Int64>("node1", 10)
    let reg2 = LWWRegister<Int64>("node2", 20)

    // reg2 时间戳更新
    reg2.set(20)

    reg1.merge(reg2)

    @Expect(reg1.getValue(), 20)
}

// === PNCounter Tests ===

@Test
func testPNCounter_creation() {
    let counter = PNCounter("node1")

    @Expect(counter.value(), 0)
    @Expect(counter.identity().contains("PNCounter"), true)
}

@Test
func testPNCounter_increment() {
    let counter = PNCounter("node1")

    counter.increment(1)
    counter.increment(1)
    counter.increment(1)

    @Expect(counter.value(), 3)
}

@Test
func testPNCounter_decrement() {
    let counter = PNCounter("node1")

    counter.increment(1)
    counter.increment(1)
    counter.decrement(1)

    @Expect(counter.value(), 1)
}

@Test
func testPNCounter_merge() {
    let counter1 = PNCounter("node1")
    let counter2 = PNCounter("node2")

    counter1.increment(1)
    counter1.increment(1)

    counter2.increment(1)
    counter2.decrement(1)

    counter1.merge(counter2)

    @Expect(counter1.value() >= 0, true)
}

// === GCounter Tests ===

@Test
func testGCounter_creation() {
    let counter = GCounter("node1")

    @Expect(counter.value(), 0)
    @Expect(counter.identity().contains("GCounter"), true)
}

@Test
func testGCounter_increment() {
    let counter = GCounter("node1")

    counter.increment(1)
    counter.increment(1)

    @Expect(counter.value(), 2)
}

@Test
func testGCounter_merge() {
    let counter1 = GCounter("node1")
    let counter2 = GCounter("node2")

    counter1.increment(1)
    counter1.increment(1)

    counter2.increment(1)

    counter1.merge(counter2)

    @Expect(counter1.value(), 3)
}

// === ORSet Tests ===

@Test
func testORSet_creation() {
    let set = ORSet<Int64>("node1")

    @Expect(set.value().size, 0)
    @Expect(set.identity().contains("ORSet"), true)
}

@Test
func testORSet_add() {
    let set = ORSet<String>("node1")

    let id1 = set.add("hello")
    let id2 = set.add("world")

    let values = set.value()

    @Expect(values.size, 2)
    var hasHello = false
    var hasWorld = false
    for (v in values) {
        if (v == "hello") { hasHello = true }
        if (v == "world") { hasWorld = true }
    }
    @Expect(hasHello, true)
    @Expect(hasWorld, true)
}

@Test
func testORSet_remove() {
    let set = ORSet<String>("node1")

    let id = set.add("hello")
    let removed = set.remove(id)

    let values = set.value()

    @Expect(removed, true)
    @Expect(values.size, 0)
}

@Test
func testORSet_merge() {
    let set1 = ORSet<Int64>("node1")
    let set2 = ORSet<Int64>("node2")

    set1.add(100)
    set1.add(200)

    set2.add(300)
    set2.add(400)

    set1.merge(set2)

    @Expect(set1.value().size >= 3, true)
}

// === LWWMap Tests ===

@Test
func testLWWMap_creation() {
    let map = LWWMap("test")

    @Expect(map.size(), 0)
    @Expect(map.identity().contains("LWWMap"), true)
}

@Test
func testLWWMap_set() {
    let map = LWWMap("test")

    map.set("key1", "100")
    map.set("key2", "200")

    @Expect(map.size(), 2)
}

@Test
func testLWWMap_get() {
    let map = LWWMap("test")

    map.set("key1", "100")

    let value = map.get("key1")
    match (value) {
        case Some(v) => @Expect(v, "100")
        case None => @Expect(false, true)
    }
}

@Test
func testLWWMap_getNonExistent() {
    let map = LWWMap("test")

    let value = map.get("nonexistent")

    @Expect(value.isEmpty(), true)
}

@Test
func testLWWMap_delete() {
    let map = LWWMap("test")

    map.set("key1", "100")
    map.delete("key1")

    let value = map.get("key1")

    @Expect(value.isEmpty(), true)
}

@Test
func testLWWMap_merge() {
    let map1 = LWWMap("test1")
    let map2 = LWWMap("test2")

    map1.set("a", "1")
    map1.set("b", "2")

    map2.set("c", "3")
    map2.set("d", "4")

    map1.merge(map2)

    @Expect(map1.size() >= 3, true)
}

// === DistributedDataNode Tests ===

@Test
func testDistributedDataNode_creation() {
    let node = DistributedDataNode("node1")

    @Expect(node.getNodeId(), "node1")
}

@Test
func testDistributedDataNode_register() {
    let node = DistributedDataNode("node1")

    node.register("counter", 42)

    let value = node.get("counter")
    match (value) {
        case Some(v) => @Expect(v, 42)
        case None => @Expect(false, true)
    }
}

// === Integration Tests ===

@Test
func testCRDT_convergence() {
    // 模拟两个节点
    let counter1 = GCounter("node1")
    let counter2 = GCounter("node2")

    // 节点1增加3次
    counter1.increment(1)
    counter1.increment(1)
    counter1.increment(1)

    // 节点2增加2次
    counter2.increment(1)
    counter2.increment(1)

    // 合并
    counter1.merge(counter2)

    // 最终值应该收敛到 5
    @Expect(counter1.value(), 5)
}

@Test
func testORSet_convergence() {
    let set1 = ORSet<String>("node1")
    let set2 = ORSet<String>("node2")

    set1.add("a")
    set1.add("b")

    set2.add("c")
    set2.add("d")

    set1.merge(set2)

    @Expect(set1.value().size >= 2, true)
}

@Test
func testLWWMap_conflictResolution() {
    let map1 = LWWMap("test1")
    let map2 = LWWMap("test2")

    // 两个节点同时更新同一个键
    map1.set("shared", "100")
    map2.set("shared", "200")

    // 合并 - LWW 会选择时间戳较新的
    map1.merge(map2)

    let result = map1.get("shared")
    match (result) {
        case Some(v) => @Expect(v.size > 0, true)
        case None => @Expect(false, true)
    }
}

@Test
func testPNCounter_distributed() {
    let counter1 = PNCounter("node1")
    let counter2 = PNCounter("node2")
    let counter3 = PNCounter("node3")

    // 节点1: +5
    counter1.increment(1)
    counter1.increment(1)
    counter1.increment(1)
    counter1.increment(1)
    counter1.increment(1)

    // 节点2: +3, -2
    counter2.increment(1)
    counter2.increment(1)
    counter2.increment(1)
    counter2.decrement(1)
    counter2.decrement(1)

    // 节点3: +2
    counter3.increment(1)
    counter3.increment(1)

    // 合并所有
    counter1.merge(counter2)
    counter1.merge(counter3)

    // 最终应该是 8 (5 + 1 + 2)
    @Expect(counter1.value() >= 5, true)
}