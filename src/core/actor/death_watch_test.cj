/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - DeathWatch 单元测试
 */
package cactor.core.actor

import std.collection.*
import std.time.*
import cactor.core.message.*

// 测试用的 ActorRef 实现
class DWTestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(system: String, path: String) {
        this.pathValue = ActorPath(system, path)
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, sender: Option<String>): Unit {}

    public func equals(other: ActorRef): Bool {
        this.path.toString() == other.path.toString()
    }

    public func hashCode(): Int32 {
        0
    }
}

// === Terminated 消息测试 ===

@Test
func testTerminated_creation() {
    let subject = DWTestActorRef("test", "/user/actor")
    let terminated = Terminated(subject)

    @Expect(terminated.getExistenceConfirmed(), true)
    @Expect(terminated.getAddressTerminated(), false)
    @Expect(terminated.messageType(), "Terminated")
}

@Test
func testTerminated_withOptions() {
    let subject = DWTestActorRef("test", "/user/actor")
    let terminated = Terminated(subject, existenceConfirmed: true, addressTerminated: true)

    @Expect(terminated.getExistenceConfirmed(), true)
    @Expect(terminated.getAddressTerminated(), true)
}

@Test
func testTerminated_actorRef() {
    let subject = DWTestActorRef("test", "/user/actor")
    let terminated = Terminated(subject)

    @Expect(terminated.actorRef.path.toString(), "cactor://test/user/actor/")
}

// === WatchMessage 测试 ===

@Test
func testWatchMessage_creation() {
    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")
    let msg = WatchMessage(watcher, subject)

    @Expect(msg.watcherRef.path.toString(), "cactor://test/user/watcher/")
    @Expect(msg.subjectRef.path.toString(), "cactor://test/user/subject/")
    @Expect(msg.messageType(), "Watch")
}

// === UnwatchMessage 测试 ===

@Test
func testUnwatchMessage_creation() {
    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")
    let msg = UnwatchMessage(watcher, subject)

    @Expect(msg.watcherRef.path.toString(), "cactor://test/user/watcher/")
    @Expect(msg.subjectRef.path.toString(), "cactor://test/user/subject/")
    @Expect(msg.messageType(), "Unwatch")
}

// === DeathWatchEntry 测试 ===

@Test
func testDeathWatchEntry_creation() {
    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")
    let entry = DeathWatchEntry(watcher, subject)

    @Expect(entry.getWatcher().path.toString(), "cactor://test/user/watcher/")
    @Expect(entry.getSubject().path.toString(), "cactor://test/user/subject/")
    @Expect(entry.isWatching(), true)
    @Expect(entry.getWatchTime() > 0, true)
}

@Test
func testDeathWatchEntry_setTerminated() {
    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")
    let entry = DeathWatchEntry(watcher, subject)

    @Expect(entry.isWatching(), true)

    entry.setTerminated()

    @Expect(entry.isWatching(), false)
}

@Test
func testDeathWatchEntry_getSubjectPath() {
    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")
    let entry = DeathWatchEntry(watcher, subject)

    @Expect(entry.getSubjectPath(), "cactor://test/user/subject/")
}

// === DeathWatchStats 测试 ===

@Test
func testDeathWatchStats_initialization() {
    let stats = DeathWatchStats()

    @Expect(stats.getTotalWatches(), 0)
    @Expect(stats.getTotalTerminations(), 0)
    @Expect(stats.getTotalUnwatches(), 0)
    @Expect(stats.getActiveWatches(), 0)
}

@Test
func testDeathWatchStats_incrementWatch() {
    let stats = DeathWatchStats()
    stats.incrementWatch()
    stats.incrementWatch()

    @Expect(stats.getTotalWatches(), 2)
    @Expect(stats.getActiveWatches(), 2)
}

@Test
func testDeathWatchStats_incrementTermination() {
    let stats = DeathWatchStats()
    stats.incrementWatch()
    stats.incrementTermination()

    @Expect(stats.getTotalWatches(), 1)
    @Expect(stats.getTotalTerminations(), 1)
}

@Test
func testDeathWatchStats_incrementUnwatch() {
    let stats = DeathWatchStats()
    stats.incrementWatch()
    stats.incrementUnwatch()

    @Expect(stats.getTotalWatches(), 1)
    @Expect(stats.getTotalUnwatches(), 1)
    @Expect(stats.getActiveWatches(), 0)
}

// === DefaultDeathWatch 测试 ===

@Test
func testDefaultDeathWatch_initialization() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    @Expect(dw.getWatchCount(), 0)
}

@Test
func testDefaultDeathWatch_watch() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)

    @Expect(dw.getWatchCount(), 1)
    @Expect(dw.isWatching(watcher, subject), true)
}

@Test
func testDefaultDeathWatch_multipleWatchers() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher1 = DWTestActorRef("test", "/user/watcher1")
    let watcher2 = DWTestActorRef("test", "/user/watcher2")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher1, subject)
    dw.watch(watcher2, subject)

    @Expect(dw.getWatchCount(), 2)

    let watchers = dw.getWatchers(subject)
    @Expect(watchers.size, 2)
}

@Test
func testDefaultDeathWatch_multipleSubjects() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject1 = DWTestActorRef("test", "/user/subject1")
    let subject2 = DWTestActorRef("test", "/user/subject2")

    dw.watch(watcher, subject1)
    dw.watch(watcher, subject2)

    @Expect(dw.getWatchCount(), 2)

    let entries = dw.getWatchEntries(watcher)
    @Expect(entries.size, 2)
}

@Test
func testDefaultDeathWatch_unwatch() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)
    @Expect(dw.isWatching(watcher, subject), true)

    dw.unwatch(watcher, subject)

    @Expect(dw.isWatching(watcher, subject), false)
}

@Test
func testDefaultDeathWatch_unwatchNotWatched() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    // 不先 watch 直接 unwatch，不应该出错
    dw.unwatch(watcher, subject)

    @Expect(dw.isWatching(watcher, subject), false)
}

@Test
func testDefaultDeathWatch_notifyTerminated() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)
    @Expect(dw.isWatching(watcher, subject), true)

    dw.notifyTerminated(subject)

    // subject 终止后，watcher 不再监视它
    @Expect(dw.isWatching(watcher, subject), false)
    @Expect(dw.getWatchCount(), 0)
}

@Test
func testDefaultDeathWatch_getWatchers() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher1 = DWTestActorRef("test", "/user/watcher1")
    let watcher2 = DWTestActorRef("test", "/user/watcher2")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher1, subject)
    dw.watch(watcher2, subject)

    let watchers = dw.getWatchers(subject)
    @Expect(watchers.size, 2)
}

@Test
func testDefaultDeathWatch_getWatchers_afterTermination() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)
    dw.notifyTerminated(subject)

    let watchers = dw.getWatchers(subject)
    @Expect(watchers.size, 0)
}

@Test
func testDefaultDeathWatch_isWatching() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject1 = DWTestActorRef("test", "/user/subject1")
    let subject2 = DWTestActorRef("test", "/user/subject2")

    dw.watch(watcher, subject1)

    @Expect(dw.isWatching(watcher, subject1), true)
    @Expect(dw.isWatching(watcher, subject2), false)
}

@Test
func testDefaultDeathWatch_getStats() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)
    dw.unwatch(watcher, subject)

    let stats = dw.getStats()
    @Expect(stats.getTotalWatches(), 1)
    @Expect(stats.getTotalUnwatches(), 1)
}

@Test
func testDefaultDeathWatch_doubleWatch() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)
    dw.watch(watcher, subject)  // 重复监视

    // 应该只有一条监视记录
    @Expect(dw.getWatchCount(), 1)
}

@Test
func testDefaultDeathWatch_getWatchEntries() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)

    let entries = dw.getWatchEntries(watcher)
    @Expect(entries.size, 1)
    @Expect(entries[0].getSubjectPath(), "cactor://test/user/subject/")
}

@Test
func testDefaultDeathWatch_terminationUpdatesEntryState() {
    DeathWatchSystem.reset()
    let dw = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")

    dw.watch(watcher, subject)

    let entriesBefore = dw.getWatchEntries(watcher)
    @Expect(entriesBefore[0].isWatching(), true)

    dw.notifyTerminated(subject)

    let entriesAfter = dw.getWatchEntries(watcher)
    @Expect(entriesAfter.size, 1)  // 条目还在，但状态变了
    @Expect(entriesAfter[0].isWatching(), false)
}

// === DeathWatchSystem 测试 ===

@Test
func testDeathWatchSystem_reset() {
    DeathWatchSystem.reset()
    let dw1 = DeathWatchSystem.getInstance()

    let watcher = DWTestActorRef("test", "/user/watcher")
    let subject = DWTestActorRef("test", "/user/subject")
    dw1.watch(watcher, subject)
    @Expect(dw1.getWatchCount(), 1)

    DeathWatchSystem.reset()
    let dw2 = DeathWatchSystem.getInstance()

    // 重置后应该是新实例，监视计数为0
    @Expect(dw2.getWatchCount(), 0)
}

// === DeathWatchState 枚举测试 ===

@Test
func testDeathWatchState_values() {
    let watching = DeathWatchState.Watching
    let terminated = DeathWatchState.Terminated

    match (watching) {
        case DeathWatchState.Watching => @Expect(true, true)
        case _ => @Expect(true, false)
    }

    match (terminated) {
        case DeathWatchState.Terminated => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}
