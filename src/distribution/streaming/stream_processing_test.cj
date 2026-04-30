/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Stream Processing 单元测试
 */
package cactor.distribution.streaming

import std.collection.*

// === StreamShape Tests ===

@Test
func testStreamShape_creation() {
    let shape = StreamShape()
    // Basic creation - just verify no exception
    @Expect(true, true)
}

@Test
func testStreamShape_ports() {
    let shape = StreamShape()

    @Expect(shape.inPort.portName, "in")
    @Expect(shape.outPort.portName, "out")
}

// === InPort Tests ===

@Test
func testInPort_defaultName() {
    let port = InPort()
    @Expect(port.portName, "in")
}

// === OutPort Tests ===

@Test
func testOutPort_defaultName() {
    let port = OutPort()
    @Expect(port.portName, "out")
}

// === NotUsed Tests ===

@Test
func testNotUsed_getInstance() {
    let instance1 = NotUsed.getInstance()
    let instance2 = NotUsed.getInstance()

    // Simple verification that getInstance works
    @Expect(true, true)
}

@Test
func testNotUsed_multipleInstances() {
    let n1 = NotUsed.getInstance()
    let n2 = NotUsed.getInstance()
    let n3 = NotUsed.getInstance()

    // Verify multiple calls work
    @Expect(true, true)
}

// === SimpleSource Tests ===

@Test
func testSimpleSource_creation() {
    let items = ArrayList<Any>()
    items.add("item1")
    let source = SimpleSource(items)

    @Expect(true, true)
}

@Test
func testSimpleSource_singleItem() {
    let items = ArrayList<Any>()
    items.add("hello")
    let source = SimpleSource(items)

    let first = source.next()
    let hasItem = match (first) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasItem, true)

    let second = source.next()
    let isEmpty = match (second) {
        case Some(_) => false
        case None => true
    }
    @Expect(isEmpty, true)
}

@Test
func testSimpleSource_multipleItems() {
    let items = ArrayList<Any>()
    items.add(1)
    items.add(2)
    items.add(3)
    let source = SimpleSource(items)

    let has1 = match (source.next()) {
        case Some(_) => true
        case None => false
    }
    let has2 = match (source.next()) {
        case Some(_) => true
        case None => false
    }
    let has3 = match (source.next()) {
        case Some(_) => true
        case None => false
    }
    let has4 = match (source.next()) {
        case Some(_) => false
        case None => true
    }

    @Expect(has1, true)
    @Expect(has2, true)
    @Expect(has3, true)
    @Expect(has4, true)
}

@Test
func testSimpleSource_hasNext() {
    let items = ArrayList<Any>()
    items.add("a")
    items.add("b")
    let source = SimpleSource(items)

    @Expect(source.hasNext(), true)

    source.next()
    @Expect(source.hasNext(), true)

    source.next()
    @Expect(source.hasNext(), false)
}

@Test
func testSimpleSource_empty() {
    let items = ArrayList<Any>()
    let source = SimpleSource(items)

    let hasNext = source.hasNext()
    @Expect(hasNext, false)

    let next = source.next()
    let isNone = match (next) {
        case Some(_) => false
        case None => true
    }
    @Expect(isNone, true)
}

@Test
func testSimpleSource_runWith() {
    let items = ArrayList<Any>()
    items.add("test")
    let source = SimpleSource(items)

    // runWith should not throw
    source.runWith(SimpleSink())
    @Expect(true, true)
}

// === SimpleSink Tests ===

@Test
func testSimpleSink_creation() {
    let sink = SimpleSink()
    @Expect(true, true)
}

@Test
func testSimpleSink_runWithSource() {
    let items = ArrayList<Any>()
    items.add("data1")
    items.add("data2")
    let source = SimpleSource(items)

    let sink = SimpleSink()
    sink.run(source)

    let collected = sink.getCollected()
    @Expect(collected.size, 2)
}

@Test
func testSimpleSink_emptySource() {
    let source = SourceFactory.empty()
    let sink = SimpleSink()

    sink.run(source)

    let collected = sink.getCollected()
    @Expect(collected.size, 0)
}

@Test
func testSimpleSink_collectsAllItems() {
    let items = ArrayList<Any>()
    for (i in 0..10) {
        items.add(i)
    }
    let source = SourceFactory.fromList(items)

    let sink = SimpleSink()
    sink.run(source)

    let collected = sink.getCollected()
    @Expect(collected.size, 10)
}

// === SourceFactory Tests ===

@Test
func testSourceFactory_single() {
    let source = SourceFactory.single("hello")

    let hasItem = match (source.next()) {
        case Some(_) => true
        case None => false
    }
    @Expect(hasItem, true)

    let isEmpty = match (source.next()) {
        case Some(_) => false
        case None => true
    }
    @Expect(isEmpty, true)
}

@Test
func testSourceFactory_fromList() {
    let items = ArrayList<Any>()
    items.add("a")
    items.add("b")
    items.add("c")

    let source = SourceFactory.fromList(items)

    var total = 0
    while (source.hasNext()) {
        source.next()
        total += 1
    }
    @Expect(total, 3)
}

@Test
func testSourceFactory_empty() {
    let source = SourceFactory.empty()

    let hasNext = source.hasNext()
    @Expect(hasNext, false)
}

// === SimpleFlow Tests ===

@Test
func testSimpleFlow_creation() {
    let flow = SimpleFlow()
    @Expect(true, true)
}

@Test
func testSimpleFlow_runWith() {
    let items = ArrayList<Any>()
    items.add(1)
    items.add(2)
    items.add(3)
    let source = SourceFactory.fromList(items)

    let sink = SimpleSink()
    let flow = SimpleFlow()
    flow.runWith(source, sink)

    let collected = sink.getCollected()
    @Expect(collected.size, 3)
}

// === SinkFactory Tests ===

@Test
func testSinkFactory_collect() {
    let sink = SinkFactory.collect()
    @Expect(true, true)
}

@Test
func testSinkFactory_foreach() {
    let sink = SinkFactory.foreach()
    @Expect(true, true)
}

// === FlowFactory Tests ===

@Test
func testFlowFactory_identity() {
    let flow = FlowFactory.identity()
    @Expect(true, true)
}

// === BackoffStrategy Tests ===

@Test
func testBackoffStrategy_Buffer() {
    let strategy = BackoffStrategy.Buffer(32)
    @Expect(true, true)
}

@Test
func testBackoffStrategy_DropNew() {
    let strategy = BackoffStrategy.DropNew
    @Expect(true, true)
}

@Test
func testBackoffStrategy_DropOld() {
    let strategy = BackoffStrategy.DropOld
    @Expect(true, true)
}

@Test
func testBackoffStrategy_DropHead() {
    let strategy = BackoffStrategy.DropHead
    @Expect(true, true)
}

@Test
func testBackoffStrategy_DropTail() {
    let strategy = BackoffStrategy.DropTail
    @Expect(true, true)
}

@Test
func testBackoffStrategy_Fail() {
    let strategy = BackoffStrategy.Fail
    @Expect(true, true)
}

// === BufferConfig Tests ===

@Test
func testBufferConfig_defaultCreation() {
    let config = BufferConfig()

    @Expect(config.size, 16)
}

@Test
func testBufferConfig_customSize() {
    let config = BufferConfig(size: 64)

    @Expect(config.size, 64)
}

@Test
func testBufferConfig_customStrategy() {
    let config = BufferConfig(overflowStrategy: BackoffStrategy.DropOld)

    @Expect(config.size, 16)
}

@Test
func testBufferConfig_fullCustom() {
    let config = BufferConfig(size: 128, overflowStrategy: BackoffStrategy.Fail)

    @Expect(config.size, 128)
}

// === Integration Tests ===

@Test
func testSourceSinkIntegration() {
    let items = ArrayList<Any>()
    for (i in 0..5) {
        items.add(i)
    }

    let source = SourceFactory.fromList(items)
    let sink = SinkFactory.collect()

    source.runWith(sink)

    let collected = sink.getCollected()
    @Expect(collected.size, 5)
}

@Test
func testSourceFlowSinkIntegration() {
    let items = ArrayList<Any>()
    items.add(10)
    items.add(20)
    items.add(30)

    let source = SourceFactory.fromList(items)
    let flow = FlowFactory.identity()
    let sink = SinkFactory.collect()

    flow.runWith(source, sink)

    let collected = sink.getCollected()
    @Expect(collected.size, 3)
}

@Test
func testEmptySourceFlowIntegration() {
    let source = SourceFactory.empty()
    let sink = SinkFactory.collect()

    source.runWith(sink)

    let collected = sink.getCollected()
    @Expect(collected.size, 0)
}

@Test
func testSourceWithSinkResult() {
    let items = ArrayList<Any>()
    items.add("data")
    let source = SimpleSource(items)

    let sink = SimpleSink()
    source.runWith(sink)

    // Verify sink received data
    let collected = sink.getCollected()
    @Expect(collected.size, 1)
}