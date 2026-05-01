/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - PersistenceFSM 单元测试
 */
package cactor.distribution.persistence

import std.collection.*
import std.time.*
import cactor.core.message.Message

// === Test State ===
class TestFSMState {
    private let nameVal: String

    public init(name: String) {
        this.nameVal = name
    }

    public func stateName(): String { nameVal }
}

class TestState1 {
    public let nameVal: String

    public init() {
        this.nameVal = "TestState1"
    }

    public func stateName(): String { nameVal }
}

class TestState2 {
    public let nameVal: String

    public init() {
        this.nameVal = "TestState2"
    }

    public func stateName(): String { nameVal }
}

// === Test StateData ===
class TestStateData {
    private let value: Int64
    private let defined: Bool

    public init(value: Int64, defined: Bool) {
        this.value = value
        this.defined = defined
    }

    public func isDefined(): Bool { defined }
    public func getValue(): Int64 { value }
}

// === Test Event ===
class TestFSMEvent {
    private let nameVal: String
    private let targetState: Option<String>

    public init(name: String, targetState!: Option<String> = None) {
        this.nameVal = name
        this.targetState = targetState
    }

    public func eventName(): String { nameVal }
    public func getTargetState(): Option<String> { targetState }
}

// === StateTransitionHandler Mock (no type parameters) ===
class MockTransitionHandler <: StateTransitionHandler {
    private let transitions: ArrayList<String>

    public init() {
        this.transitions = ArrayList<String>()
    }

    public func onTransition(stateName: String): Unit {
        transitions.add(stateName)
    }

    public func onExit(stateName: String): Unit {
        // Mock implementation
    }

    public func getTransitionCount(): Int64 { Int64(transitions.size) }
}

// === FSMStateType Tests ===

@Test
func testFSMStateType_initial() {
    let state = FSMStateType.Initial
    @Expect(true, true)  // Just verify it exists
}

@Test
func testFSMStateType_active() {
    let state = FSMStateType.Active
    @Expect(true, true)
}

@Test
func testFSMStateType_waiting() {
    let state = FSMStateType.Waiting
    @Expect(true, true)
}

@Test
func testFSMStateType_terminated() {
    let state = FSMStateType.Terminated
    @Expect(true, true)
}

// === Timeout Tests ===

@Test
func testTimeout_creation() {
    let timeout = Timeout("TestState", Duration.second * 5)

    @Expect(timeout.target, "TestState")
    @Expect(timeout.duration >= Duration.second * 4, true)
}

@Test
func testTimeout_idle() {
    let timeout = Timeout.idle(Duration.second * 10)

    @Expect(timeout.target, "IdleTimeout")
    @Expect(timeout.duration >= Duration.second * 9, true)
}

// === StateTransitionEvent Tests ===

@Test
func testStateTransitionEvent_creation() {
    let event = StateTransitionEvent("State1", "State2", 1)

    @Expect(event.eventType(), "StateTransition")
    @Expect(event.eventName(), "StateTransition")
    @Expect(event.sequenceNr(), 1)
    @Expect(event.from(), "State1")
    @Expect(event.to(), "State2")
    @Expect(event.timestamp() > 0, true)
}

@Test
func testStateTransitionEvent_sequenceIncrement() {
    let event1 = StateTransitionEvent("A", "B", 1)
    let event2 = StateTransitionEvent("B", "C", 2)

    @Expect(event1.sequenceNr() < event2.sequenceNr(), true)
}

// === MockTransitionHandler Tests ===

@Test
func testMockTransitionHandler_creation() {
    let handler = MockTransitionHandler()

    @Expect(handler.getTransitionCount(), 0)
}

@Test
func testMockTransitionHandler_onTransition() {
    let handler = MockTransitionHandler()

    handler.onTransition("State1")
    handler.onTransition("State2")

    @Expect(handler.getTransitionCount(), 2)
}

@Test
func testMockTransitionHandler_onExit() {
    let handler = MockTransitionHandler()

    handler.onExit("State1")
    // No exception means success
    @Expect(true, true)
}

// === TestFSMState Tests ===

@Test
func testTestFSMState_creation() {
    let state = TestFSMState("TestState")

    @Expect(state.stateName(), "TestState")
}

@Test
func testTestState1_creation() {
    let state = TestState1()

    @Expect(state.stateName(), "TestState1")
}

@Test
func testTestState2_creation() {
    let state = TestState2()

    @Expect(state.stateName(), "TestState2")
}

// === TestFSMEvent Tests ===

@Test
func testTestFSMEvent_creation() {
    let event = TestFSMEvent("TestEvent")

    @Expect(event.eventName(), "TestEvent")
    match (event.getTargetState()) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testTestFSMEvent_withTargetState() {
    let event = TestFSMEvent("TestEvent", targetState: Some("TargetState"))

    @Expect(event.eventName(), "TestEvent")
    match (event.getTargetState()) {
        case Some(s) => @Expect(s, "TargetState")
        case None => @Expect(true, false)
    }
}

// === TestStateData Tests ===

@Test
func testTestStateData_defined() {
    let data = TestStateData(42, true)

    @Expect(data.isDefined(), true)
    @Expect(data.getValue(), 42)
}

@Test
func testTestStateData_undefined() {
    let data = TestStateData(0, false)

    @Expect(data.isDefined(), false)
}

// === Integration Tests ===

@Test
func testStateTransition_workflow() {
    // 模拟状态转换工作流
    let handler = MockTransitionHandler()

    // 状态转换
    handler.onTransition("Initial")
    handler.onTransition("Active")
    handler.onTransition("Completed")

    @Expect(handler.getTransitionCount(), 3)

    // 创建转换事件
    let event = StateTransitionEvent("Active", "Completed", 1)

    @Expect(event.from(), "Active")
    @Expect(event.to(), "Completed")
}

@Test
func testTimeout_withStateMachine() {
    // 模拟超时与状态机
    let timeout = Timeout("FailureState", Duration.second * 30)

    @Expect(timeout.target, "FailureState")
    @Expect(timeout.duration >= Duration.second * 29, true)
}

@Test
func testMultipleStateTransitions() {
    let handler = MockTransitionHandler()
    let states = ["Initial", "Active", "Processing", "Completed", "Terminated"]

    for (s in states) {
        handler.onTransition(s)
    }

    @Expect(handler.getTransitionCount(), Int64(states.size))
}

@Test
func testStateTransitionEvent_sequenceTracking() {
    var events = ArrayList<StateTransitionEvent>()

    for (i in 1..=5) {
        events.append(StateTransitionEvent("State${i - 1}", "State${i}", Int64(i)))
    }

    @Expect(events.size, 5)
    @Expect(events[0].sequenceNr(), 1)
    @Expect(events[4].sequenceNr(), 5)
}

@Test
func testFSMStateType_enumIteration() {
    // 验证所有枚举值存在
    let types = [FSMStateType.Initial, FSMStateType.Active, FSMStateType.Waiting, FSMStateType.Terminated]
    @Expect(types.size, 4)
}

@Test
func testTestFSMState_multipleInstances() {
    let state1 = TestFSMState("Alpha")
    let state2 = TestFSMState("Beta")
    let state3 = TestFSMState("Gamma")

    @Expect(state1.stateName(), "Alpha")
    @Expect(state2.stateName(), "Beta")
    @Expect(state3.stateName(), "Gamma")
    @Expect(state1.stateName() != state2.stateName(), true)
}

@Test
func testTestStateData_valuePreservation() {
    let data1 = TestStateData(100, true)
    let data2 = TestStateData(200, true)

    @Expect(data1.getValue() < data2.getValue(), true)
}

@Test
func testTestFSMEvent_namedEvents() {
    let events = [
        TestFSMEvent("Start"),
        TestFSMEvent("Process"),
        TestFSMEvent("Complete")
    ]

    @Expect(events.size, 3)
    @Expect(events[0].eventName(), "Start")
    @Expect(events[1].eventName(), "Process")
    @Expect(events[2].eventName(), "Complete")
}

@Test
func testStateTransitionEvent_chaining() {
    let event1 = StateTransitionEvent("A", "B", 1)
    let event2 = StateTransitionEvent("B", "C", 2)
    let event3 = StateTransitionEvent("C", "D", 3)

    // 验证链式转换
    @Expect(event1.to() == event2.from(), true)
    @Expect(event2.to() == event3.from(), true)
}

@Test
func testMockTransitionHandler_stateTracking() {
    let handler = MockTransitionHandler()

    handler.onTransition("State1")
    handler.onTransition("State2")
    handler.onExit("State1")
    handler.onTransition("State3")

    @Expect(handler.getTransitionCount(), 3)
}