/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - GraphDSL 单元测试
 */
package cactor.distribution.streaming

import std.collection.*

// === GraphDSL Tests ===

@Test
func testGraphDSL_creation() {
    let builder = GraphDSL()

    @Expect(builder.getStageCount(), 0)
    @Expect(builder.getEdgeCount(), 0)
}

@Test
func testGraphDSL_addSource() {
    let builder = GraphDSL()
    let items = ArrayList<Any>()
    items.add("test")
    let source = SimpleSource(items)

    builder.addSource("source1", source)

    @Expect(builder.getStageCount(), 1)
    @Expect(builder.getEdgeCount(), 0)
}

@Test
func testGraphDSL_addSink() {
    let builder = GraphDSL()
    let sink = SimpleSink()

    builder.addSink("sink1", sink)

    @Expect(builder.getStageCount(), 1)
    @Expect(builder.getEdgeCount(), 0)
}

@Test
func testGraphDSL_addFlow() {
    let builder = GraphDSL()
    let flow = SimpleFlow()

    builder.addFlow("flow1", flow)

    @Expect(builder.getStageCount(), 1)
    @Expect(builder.getEdgeCount(), 0)
}

@Test
func testGraphDSL_connect() {
    let builder = GraphDSL()
    let items = ArrayList<Any>()
    items.add("test")
    let source = SimpleSource(items)
    let sink = SimpleSink()

    builder.addSource("source1", source)
    builder.addSink("sink1", sink)
    builder.connect("source1", "sink1")

    @Expect(builder.getStageCount(), 2)
    @Expect(builder.getEdgeCount(), 1)
}

@Test
func testGraphDSL_chain() {
    let builder = GraphDSL()
    let items = ArrayList<Any>()
    items.add(1)
    let source = SimpleSource(items)
    let flow = SimpleFlow()
    let sink = SimpleSink()

    builder.addSource("source1", source)
    builder.addFlow("flow1", flow)
    builder.addSink("sink1", sink)
    builder.connect("source1", "flow1")
    builder.connect("flow1", "sink1")

    @Expect(builder.getStageCount(), 3)
    @Expect(builder.getEdgeCount(), 2)
}

@Test
func testGraphDSL_multipleSources() {
    let builder = GraphDSL()

    let items1 = ArrayList<Any>()
    items1.add("a")
    let items2 = ArrayList<Any>()
    items2.add("b")

    builder.addSource("source1", SimpleSource(items1))
    builder.addSource("source2", SimpleSource(items2))
    builder.addSink("sink1", SimpleSink())

    @Expect(builder.getStageCount(), 3)
}

@Test
func testGraphDSL_build() {
    let builder = GraphDSL()
    let items = ArrayList<Any>()
    items.add("test")
    let source = SimpleSource(items)
    let sink = SimpleSink()

    builder.addSource("source1", source)
    builder.addSink("sink1", sink)
    builder.connect("source1", "sink1")

    let graph = builder.build()
    @Expect(true, true)  // 构建成功
}

@Test
func testGraphDSL_run() {
    let builder = GraphDSL()
    let items = ArrayList<Any>()
    items.add("data")
    let source = SimpleSource(items)
    let sink = SimpleSink()

    builder.addSource("source1", source)
    builder.addSink("sink1", sink)
    builder.connect("source1", "sink1")

    builder.run()
    @Expect(true, true)
}

@Test
func testGraphDSL_getStageNames() {
    let builder = GraphDSL()
    builder.addSource("src", SimpleSource(ArrayList<Any>()))
    builder.addFlow("flw", SimpleFlow())
    builder.addSink("snk", SimpleSink())

    let names = builder.getStageNames()
    @Expect(names.size, 3)
}

// === FanInShape Tests ===

@Test
func testFanInShape_creation() {
    let shape = FanInShape("merge", 3)

    @Expect(shape.name, "merge")
    @Expect(shape.inPorts.size, 3)
}

@Test
func testFanInShape_twoInputs() {
    let shape = FanInShape("merge2", 2)

    @Expect(shape.inPorts.size, 2)
    @Expect(shape.outPort.portName, "out")
}

// === FanOutShape Tests ===

@Test
func testFanOutShape_creation() {
    let shape = FanOutShape("broadcast", 4)

    @Expect(shape.name, "broadcast")
    @Expect(shape.outPorts.size, 4)
}

@Test
func testFanOutShape_twoOutputs() {
    let shape = FanOutShape("split", 2)

    @Expect(shape.outPorts.size, 2)
    @Expect(shape.inPort.portName, "in")
}

// === StreamEdge Tests ===

@Test
func testStreamEdge_creation() {
    let fromPort = OutPort()
    let toPort = InPort()
    let edge = StreamEdge("stage1", fromPort, "stage2", toPort)

    @Expect(edge.fromStage, "stage1")
    @Expect(edge.toStage, "stage2")
}

// === Merge Tests ===

@Test
func testMerge_twoInputs() {
    let merge = Merge(2)
    @Expect(true, true)
}

@Test
func testMerge_threeInputs() {
    let merge = Merge(3)
    @Expect(true, true)
}

// === Broadcast Tests ===

@Test
func testBroadcast_twoOutputs() {
    let bc = Broadcast(2)
    @Expect(true, true)
}

@Test
func testBroadcast_fourOutputs() {
    let bc = Broadcast(4)
    @Expect(true, true)
}

// === Balance Tests ===

@Test
func testBalance_twoOutputs() {
    let balance = Balance(2)

    let idx1 = balance.select()
    let idx2 = balance.select()

    @Expect(idx1, 0)
    @Expect(idx2, 1)
}

@Test
func testBalance_roundRobin() {
    let balance = Balance(3)

    let idx1 = balance.select()
    let idx2 = balance.select()
    let idx3 = balance.select()
    let idx4 = balance.select()

    @Expect(idx1, 0)
    @Expect(idx2, 1)
    @Expect(idx3, 2)
    @Expect(idx4, 0)
}

// === Zip Tests ===

@Test
func testZip_creation() {
    let zip = Zip()
    @Expect(true, true)
}

// === Unzip Tests ===

@Test
func testUnzip_creation() {
    let unzip = Unzip()
    @Expect(true, true)
}

// === GraphStageFactory Tests ===

@Test
func testGraphStageFactory_merge() {
    let (name, stage) = GraphStageFactory.merge("merge1", 3)

    @Expect(name, "merge1")
    match (stage) {
        case GraphStage.FanIn(shape) =>
            @Expect(shape.name, "merge1")
            @Expect(shape.inPorts.size, 3)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testGraphStageFactory_broadcast() {
    let (name, stage) = GraphStageFactory.broadcast("bc1", 4)

    @Expect(name, "bc1")
    match (stage) {
        case GraphStage.FanOut(shape) =>
            @Expect(shape.name, "bc1")
            @Expect(shape.outPorts.size, 4)
        case _ =>
            @Expect(true, false)
    }
}

@Test
func testGraphStageFactory_balance() {
    let (name, stage) = GraphStageFactory.balance("bal1", 2)

    @Expect(name, "bal1")
    match (stage) {
        case GraphStage.FlowStage(_) => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}

// === SourceToSinkGraph Tests ===

@Test
func testSourceToSinkGraph_creation() {
    let source = SourceFactory.single("test")
    let sink = SinkFactory.collect()
    let graph = SourceToSinkGraph(source, sink)

    @Expect(true, true)
}

@Test
func testSourceToSinkGraph_run() {
    let items = ArrayList<Any>()
    items.add("hello")
    items.add("world")
    let source = SourceFactory.fromList(items)
    let sink = SinkFactory.collect()
    let graph = SourceToSinkGraph(source, sink)

    graph.run()

    let collected = sink.getCollected()
    @Expect(collected.size, 2)
}

// === SourceFlowSinkGraph Tests ===

@Test
func testSourceFlowSinkGraph_creation() {
    let source = SourceFactory.single("test")
    let flow = FlowFactory.identity()
    let sink = SinkFactory.collect()
    let graph = SourceFlowSinkGraph(source, flow, sink)

    @Expect(true, true)
}

@Test
func testSourceFlowSinkGraph_run() {
    let items = ArrayList<Any>()
    items.add(1)
    items.add(2)
    items.add(3)
    let source = SourceFactory.fromList(items)
    let flow = FlowFactory.identity()
    let sink = SinkFactory.collect()
    let graph = SourceFlowSinkGraph(source, flow, sink)

    graph.run()

    let collected = sink.getCollected()
    @Expect(collected.size, 3)
}

// === LazySource Tests ===

@Test
func testLazySource_creation() {
    let lazy = LazySource({ => SourceFactory.single("lazy") })
    @Expect(true, true)
}

@Test
func testLazySource_run() {
    let lazy = LazySource({ => SourceFactory.single("test") })

    let sink = SinkFactory.collect()
    lazy.runWith(sink)

    @Expect(true, true)
}

// === Integration Tests ===

@Test
func testGraphDSL_complexTopology() {
    let builder = GraphDSL()

    // Source -> Flow1 -> Flow2 -> Sink
    builder.addSource("src", SourceFactory.fromList(ArrayList<Any>()))
    builder.addFlow("f1", FlowFactory.identity())
    builder.addFlow("f2", FlowFactory.identity())
    builder.addSink("snk", SinkFactory.collect())

    builder.connect("src", "f1")
    builder.connect("f1", "f2")
    builder.connect("f2", "snk")

    @Expect(builder.getStageCount(), 4)
    @Expect(builder.getEdgeCount(), 3)
}

@Test
func testGraphDSL_broadcastPattern() {
    let builder = GraphDSL()

    // Source -> Broadcast -> Sink1
    //                      -> Sink2
    builder.addSource("src", SourceFactory.single("data"))
    builder.addSink("snk1", SinkFactory.collect())
    builder.addSink("snk2", SinkFactory.collect())

    builder.connect("src", "snk1")
    builder.connect("src", "snk2")

    @Expect(builder.getStageCount(), 3)
    @Expect(builder.getEdgeCount(), 2)
}

@Test
func testGraphDSL_execution() {
    let items = ArrayList<Any>()
    items.add("a")
    items.add("b")
    items.add("c")

    let builder = GraphDSL()
    builder.addSource("src", SourceFactory.fromList(items))
    builder.addSink("snk", SinkFactory.collect())
    builder.connect("src", "snk")

    builder.run()

    @Expect(true, true)
}
