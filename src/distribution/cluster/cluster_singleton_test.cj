/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - ClusterSingleton 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*
import cactor.core.message.*

// === Test Helper ===

class TestMember <: Member {
    private let uniqueAddress: UniqueAddress
    private let roles: Set<MemberRole>
    private var status: MemberStatus

    public init(uniqueAddress: UniqueAddress, roles: Set<MemberRole>) {
        this.uniqueAddress = uniqueAddress
        this.roles = roles
        this.status = MemberStatus.Up
    }

    public func address(): Address {
        uniqueAddress.address
    }

    public func getStatus(): MemberStatus {
        status
    }

    public func getRoles(): Set<MemberRole> {
        roles
    }

    public func getUniqueAddress(): UniqueAddress {
        uniqueAddress
    }

    public func hasRole(role: String): Bool {
        roles.contains(MemberRole(role))
    }

    public func priority(): Int64 {
        uniqueAddress.uid
    }

    public func updateStatus(newStatus: MemberStatus): Unit {
        status = newStatus
    }
}

// === ClusterSingletonSettings Tests ===

@Test
func testClusterSingletonSettings_creation() {
    let settings = ClusterSingletonSettings("mySingleton")
    @Expect(settings.singletonName, "mySingleton")
    @Expect(settings.role, None)
    @Expect(settings.minNrOfMembers, 1)
}

@Test
func testClusterSingletonSettings_withRole() {
    let settings = ClusterSingletonSettings("worker", role: Some("backend"))
    @Expect(settings.singletonName, "worker")
    match (settings.role) {
        case Some(r) => @Expect(r, "backend")
        case None => @Expect(false, true)
    }
}

@Test
func testClusterSingletonSettings_withMinNrOfMembers() {
    let settings = ClusterSingletonSettings("singleton", minNrOfMembers: 3)
    @Expect(settings.minNrOfMembers, 3)
}

@Test
func testClusterSingletonSettings_withCustomTimeout() {
    let timeout = Duration.second * 20
    let settings = ClusterSingletonSettings("singleton", maxInitializationTimeout: timeout)
    @Expect(settings.maxInitializationTimeout, timeout)
}

@Test
func testClusterSingletonSettings_withProxyBufferSize() {
    let settings = ClusterSingletonSettings("singleton", proxyBufferSize: 500)
    @Expect(settings.proxyBufferSize, 500)
}

@Test
func testClusterSingletonSettings_defaultSettings() {
    let settings = ClusterSingletonSettings.defaultSettings("defaultSingleton")
    @Expect(settings.singletonName, "defaultSingleton")
    @Expect(settings.role, None)
    @Expect(settings.minNrOfMembers, 1)
}

@Test
func testClusterSingletonSettings_withRoleStatic() {
    let settings = ClusterSingletonSettings.withRole("roleSingleton", "worker")
    @Expect(settings.singletonName, "roleSingleton")
    match (settings.role) {
        case Some(r) => @Expect(r, "worker")
        case None => @Expect(false, true)
    }
}

// === SingletonInstance Tests ===

@Test
func testSingletonInstance_creation() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let actorRef = TestActorRef("/user/singleton")
    let instance = SingletonInstance(actorRef, uniqueAddr, 1)

    match (instance.actorRef) {
        case ref: TestActorRef => @Expect(ref.path.toString(), "/user/singleton")
        case _ => @Expect(false, true)
    }
    @Expect(instance.ownerAddress.uid, 1)
    @Expect(instance.version, 1)
}

// === SingletonStatus Tests ===

@Test
func testSingletonStatus_values() {
    let statuses = [
        SingletonStatus.Initializing,
        SingletonStatus.Active,
        SingletonStatus.Migrating,
        SingletonStatus.Stopping,
        SingletonStatus.Terminated
    ]
    @Expect(Int64(statuses.size), 5)
}

@Test
func testSingletonStatus_isActive() {
    let active = SingletonStatus.Active
    let inactive = SingletonStatus.Initializing

    @Expect(active.isActive(), true)
    @Expect(inactive.isActive(), false)
}

@Test
func testSingletonStatus_canMigrate() {
    let active = SingletonStatus.Active
    let migrating = SingletonStatus.Migrating
    let terminated = SingletonStatus.Terminated

    @Expect(active.canMigrate(), true)
    @Expect(migrating.canMigrate(), true)
    @Expect(terminated.canMigrate(), false)
}

// === Singleton Manager Messages Tests ===

@Test
func testSingletonGetInstance_messageType() {
    let msg = SingletonGetInstance()
    @Expect(msg.messageType(), "SingletonGetInstance")
}

@Test
func testSingletonInstanceResponse_creation() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let actorRef = TestActorRef("/user/singleton")
    let instance = SingletonInstance(actorRef, uniqueAddr, 1)

    let response = SingletonInstanceResponse(Some(instance), SingletonStatus.Active)
    match (response.instance) {
        case Some(i) => @Expect(i.version, 1)
        case None => @Expect(false, true)
    }
    @Expect(response.status.isActive(), true)
}

@Test
func testSingletonInstanceResponse_withNone() {
    let response = SingletonInstanceResponse(None, SingletonStatus.Initializing)
    @Expect(response.instance, None)
    @Expect(response.status.isActive(), false)
}

@Test
func testBecomeSingleton_messageType() {
    let actorRef = TestActorRef("/user/singleton")
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let msg = BecomeSingleton(actorRef, uniqueAddr)

    @Expect(msg.messageType(), "BecomeSingleton")
}

@Test
func testReleaseSingleton_messageType() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let msg = ReleaseSingleton(uniqueAddr)

    @Expect(msg.messageType(), "ReleaseSingleton")
}

@Test
func testElectSingleton_messageType() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr1 = UniqueAddress(address, 1)
    let uniqueAddr2 = UniqueAddress(address, 2)
    let candidates = [uniqueAddr1, uniqueAddr2]

    let msg = ElectSingleton(candidates)
    @Expect(msg.messageType(), "ElectSingleton")
    @Expect(Int64(msg.candidates.size), 2)
}

@Test
func testElectionResult_messageType() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let result = ElectionResult(Some(uniqueAddr), 5)

    @Expect(result.messageType(), "ElectionResult")
    match (result.winner) {
        case Some(w) => @Expect(w.uid, 1)
        case None => @Expect(false, true)
    }
    @Expect(result.version, 5)
}

@Test
func testElectionResult_noWinner() {
    let result = ElectionResult(None, 1)
    @Expect(result.winner, None)
    @Expect(result.version, 1)
}

// === ClusterSingletonManager Tests ===

@Test
func testClusterSingletonManager_initialization() {
    let settings = ClusterSingletonSettings("testSingleton")
    let manager = ClusterSingletonManager(settings)

    @Expect(manager.name, "testSingleton")
    @Expect(manager.getStatus(), SingletonStatus.Initializing)
    @Expect(manager.getCurrentInstance(), None)
    @Expect(manager.getVersion(), 0)
}

@Test
func testClusterSingletonManager_initialState() {
    let settings = ClusterSingletonSettings("initTest")
    let manager = ClusterSingletonManager(settings)

    @Expect(manager.getMemberCount(), 0)
}

@Test
func testClusterSingletonManager_getCurrentInstance_none() {
    let settings = ClusterSingletonSettings("noInstance")
    let manager = ClusterSingletonManager(settings)

    let instance = manager.getCurrentInstance()
    match (instance) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}

// === ClusterSingletonProxy Tests ===

@Test
func testClusterSingletonProxy_initialization() {
    let settings = ClusterSingletonSettings("proxyTest")
    let proxy = ClusterSingletonProxy("/user/singletonManager", settings)

    @Expect(proxy.name, "SingletonProxy-proxyTest")
    @Expect(proxy.getSingletonStatus(), SingletonStatus.Initializing)
    @Expect(proxy.getSingletonRef(), None)
    @Expect(proxy.getBufferSize(), 0)
}

@Test
func testClusterSingletonProxy_bufferInitialState() {
    let settings = ClusterSingletonSettings("bufferTest")
    let proxy = ClusterSingletonProxy("/user/singletonManager", settings)

    @Expect(proxy.getBufferSize(), 0)
}

// === SingletonManagerFactory Tests ===

@Test
func testSingletonManagerFactory_create() {
    let settings = ClusterSingletonSettings("factorySingleton")
    let manager = SingletonManagerFactory.create(settings)

    @Expect(manager.name, "factorySingleton")
}

@Test
func testSingletonManagerFactory_createProxy() {
    let settings = ClusterSingletonSettings("factoryProxy")
    let proxy = SingletonManagerFactory.createProxy("/user/manager", settings)

    @Expect(proxy.getSingletonStatus(), SingletonStatus.Initializing)
}

@Test
func testSingletonManagerFactory_createSettings() {
    let settings = SingletonManagerFactory.createSettings("fromFactory")
    @Expect(settings.singletonName, "fromFactory")
}

// === MemberEvent Tests ===

@Test
func testMemberEvent_MemberUp() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let member = TestMember(uniqueAddr, HashSet<MemberRole>())

    let event = MemberEvent(member, MemberEventType.MemberUp)
    @Expect(event.messageType(), "MemberUp")
}

@Test
func testMemberEvent_MemberLeft() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let member = TestMember(uniqueAddr, HashSet<MemberRole>())

    let event = MemberEvent(member, MemberEventType.MemberLeft)
    @Expect(event.messageType(), "MemberLeft")
}

@Test
func testMemberEvent_MemberDown() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)

    let event = MemberEvent(uniqueAddr, MemberEventType.MemberDown)
    @Expect(event.messageType(), "MemberDown")
}

@Test
func testMemberEvent_MemberExited() {
    let address = Address("cactor", "localhost", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let member = TestMember(uniqueAddr, HashSet<MemberRole>())

    let event = MemberEvent(member, MemberEventType.MemberExited)
    @Expect(event.messageType(), "MemberExited")
}

// === Envelope Tests ===

@Test
func testEnvelope_creation() {
    let actorRef = TestActorRef("/user/sender")
    let msg = StringMessage("hello")
    let envelope = Envelope(msg, actorRef)

    match (envelope.message) {
        case s: StringMessage => @Expect(s.content, "hello")
        case _ => @Expect(false, true)
    }
}

// === Address and UniqueAddress Tests ===

@Test
func testAddress_creation() {
    let address = Address("cactor", "node1.local", 2552)
    @Expect(address.protocol, "cactor")
    @Expect(address.system, "node1.local")
    @Expect(address.port, 2552)
}

@Test
func testUniqueAddress_creation() {
    let address = Address("cactor", "node1", 2552)
    let uniqueAddr = UniqueAddress(address, 12345)

    @Expect(uniqueAddr.address.protocol, "cactor")
    @Expect(uniqueAddr.uid, 12345)
}

@Test
func testUniqueAddress_toString() {
    let address = Address("cactor", "node1", 2552)
    let uniqueAddr = UniqueAddress(address, 1)
    let str = uniqueAddr.toString()

    @Expect(str.contains("cactor"), true)
    @Expect(str.contains("1"), true)
}

@Test
func testUniqueAddress_equals() {
    let address1 = Address("cactor", "node1", 2552)
    let address2 = Address("cactor", "node1", 2552)
    let uniqueAddr1 = UniqueAddress(address1, 1)
    let uniqueAddr2 = UniqueAddress(address2, 1)
    let uniqueAddr3 = UniqueAddress(address2, 2)

    @Expect(uniqueAddr1.equals(uniqueAddr2), true)
    @Expect(uniqueAddr1.equals(uniqueAddr3), false)
}

// === Test ActorRef ===

class TestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(pathStr: String) {
        this.pathValue = ActorPath("test", pathStr)
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}

    public func tell(message: Message, sender: Option<String>): Unit {}

    public func equals(other: ActorRef): Bool {
        pathValue.toString() == other.path.toString()
    }

    public func hashCode(): Int32 { 0 }
}
