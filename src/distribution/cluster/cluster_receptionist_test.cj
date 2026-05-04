/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Cluster Receptionist 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === Helper ===

func createReceptionist(): ClusterReceptionist {
    createClusterReceptionist("node-1", Address("cactor", "receptionist", "host1", 2552))
}

// === ServiceInstance Tests ===

@Test
func testServiceInstance_creation() {
    let instance = ServiceInstance("user-service", "/user/actor1", "node-1", Address("cactor", "test", "host", 2552))
    @Expect(instance.serviceName, "user-service")
    @Expect(instance.actorPath, "/user/actor1")
    @Expect(instance.nodeId, "node-1")
    @Expect(instance.registeredAt > 0, true)
}

@Test
func testServiceInstance_withMetadata() {
    let instance = ServiceInstance("user-service", "/user/actor1", "node-1", Address("cactor", "test", "host", 2552))
        .withMetadata("version", "1.0")
        .withMetadata("env", "production")
    @Expect(instance.getMetadata("version").getOrThrow(), "1.0")
    @Expect(instance.getMetadata("env").getOrThrow(), "production")
}

@Test
func testServiceInstance_instanceId() {
    let instance = ServiceInstance("user-service", "/user/actor1", "node-1", Address("cactor", "test", "host", 2552))
    @Expect(instance.instanceId(), "node-1:/user/actor1")
}

@Test
func testServiceInstance_isFromNode() {
    let instance = ServiceInstance("user-service", "/user/actor1", "node-1", Address("cactor", "test", "host", 2552))
    @Expect(instance.isFromNode("node-1"), true)
    @Expect(instance.isFromNode("node-2"), false)
}

// === RegisterRequest Tests ===

@Test
func testRegisterRequest_creation() {
    let req = RegisterRequest("user-service", "/user/actor1", "node-1", Address("cactor", "test", "host", 2552))
    @Expect(req.serviceName, "user-service")
    @Expect(req.actorPath, "/user/actor1")
}

// === DiscoveryRequest Tests ===

@Test
func testDiscoveryRequest_find() {
    let req = DiscoveryRequest(DiscoveryRequestType.Find, "user-service")
    @Expect(req.requestType, DiscoveryRequestType.Find)
    @Expect(req.serviceName, "user-service")
}

@Test
func testDiscoveryRequest_findAll() {
    let req = DiscoveryRequest(DiscoveryRequestType.FindAll, "user-service")
    @Expect(req.requestType, DiscoveryRequestType.FindAll)
}

// === DiscoveryResponse Tests ===

@Test
func testDiscoveryResponse_creation() {
    let instances = ArrayList<ServiceInstance>()
    let resp = DiscoveryResponse("user-service", instances)
    @Expect(resp.serviceName, "user-service")
    @Expect(resp.instances.size, 0)
}

// === ClusterReceptionist Tests ===

@Test
func testClusterReceptionist_creation() {
    let receptionist = createReceptionist()
    @Expect(receptionist.serviceCount(), 0)
    @Expect(receptionist.totalInstances(), 0)
}

@Test
func testClusterReceptionist_register() {
    let receptionist = createReceptionist()
    let instance = receptionist.register("user-service", "/user/actor1")
    @Expect(instance.serviceName, "user-service")
    @Expect(receptionist.serviceCount(), 1)
    @Expect(receptionist.totalInstances(), 1)
}

@Test
func testClusterReceptionist_registerAll() {
    let receptionist = createReceptionist()
    let registrations = ArrayList<RegisterRequest>()
    registrations.append(RegisterRequest("service-a", "/user/a1", "node-1", Address("cactor", "test", "host", 2552)))
    registrations.append(RegisterRequest("service-a", "/user/a2", "node-1", Address("cactor", "test", "host", 2552)))
    registrations.append(RegisterRequest("service-b", "/user/b1", "node-1", Address("cactor", "test", "host", 2552)))
    let count = receptionist.registerAll(registrations)
    @Expect(count, 3)
    @Expect(receptionist.serviceCount(), 2)
}

@Test
func testClusterReceptionist_unregister() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    let found = receptionist.unregister("user-service", "/user/actor1")
    @Expect(found, true)
    @Expect(receptionist.totalInstances(), 0)
}

@Test
func testClusterReceptionist_unregisterNotFound() {
    let receptionist = createReceptionist()
    let found = receptionist.unregister("user-service", "/user/actor1")
    @Expect(found, false)
}

@Test
func testClusterReceptionist_find() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    receptionist.register("user-service", "/user/actor2")
    let instance = receptionist.find("user-service")
    @Expect(instance.isSome(), true)
}

@Test
func testClusterReceptionist_findNotFound() {
    let receptionist = createReceptionist()
    let instance = receptionist.find("non-existent")
    @Expect(instance.isNone(), true)
}

@Test
func testClusterReceptionist_findAll() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    receptionist.register("user-service", "/user/actor2")
    let instances = receptionist.findAll("user-service")
    @Expect(instances.size, 2)
}

@Test
func testClusterReceptionist_findAllNotFound() {
    let receptionist = createReceptionist()
    let instances = receptionist.findAll("non-existent")
    @Expect(instances.size, 0)
}

@Test
func testClusterReceptionist_findWithPrefix() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    receptionist.register("user-api", "/user/api1")
    receptionist.register("admin-service", "/user/admin1")
    let instances = receptionist.findWithPrefix("user-")
    @Expect(instances.size, 2)
}

@Test
func testClusterReceptionist_count() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    receptionist.register("user-service", "/user/actor2")
    let count = receptionist.count("user-service")
    @Expect(count, 2)
}

@Test
func testClusterReceptionist_countNotFound() {
    let receptionist = createReceptionist()
    let count = receptionist.count("non-existent")
    @Expect(count, 0)
}

@Test
func testClusterReceptionist_updateMetadata() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    let updated = receptionist.updateMetadata("user-service", "/user/actor1", "version", "2.0")
    @Expect(updated, true)
    let instance = receptionist.find("user-service")
    match (instance) {
        case Some(inst) => @Expect(inst.getMetadata("version").getOrThrow(), "2.0")
        case None => ()
    }
}

@Test
func testClusterReceptionist_getServiceNames() {
    let receptionist = createReceptionist()
    receptionist.register("service-a", "/user/a1")
    receptionist.register("service-b", "/user/b1")
    receptionist.register("service-c", "/user/c1")
    let names = receptionist.getServiceNames()
    @Expect(names.size, 3)
}

@Test
func testClusterReceptionist_hasService() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    @Expect(receptionist.hasService("user-service"), true)
    @Expect(receptionist.hasService("non-existent"), false)
}

@Test
func testClusterReceptionist_hasInstance() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    @Expect(receptionist.hasInstance("user-service", "/user/actor1"), true)
    @Expect(receptionist.hasInstance("user-service", "/user/actor2"), false)
}

@Test
func testClusterReceptionist_getRegistrationCount() {
    let receptionist = createReceptionist()
    receptionist.register("service-a", "/user/a1")
    receptionist.register("service-b", "/user/b1")
    @Expect(receptionist.getRegistrationCount(), 2)
}

@Test
func testClusterReceptionist_getDiscoveryCount() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    receptionist.find("user-service")
    receptionist.findAll("user-service")
    @Expect(receptionist.getDiscoveryCount(), 2)
}

@Test
func testClusterReceptionist_getLocalInstances() {
    let receptionist = createClusterReceptionist("node-1", Address("cactor", "test", "host1", 2552))
    receptionist.register("service-a", "/user/a1")
    receptionist.register("service-b", "/user/b1")
    let local = receptionist.getLocalInstances()
    @Expect(local.size, 2)
}

@Test
func testClusterReceptionist_getRemoteInstances() {
    let receptionist = createReceptionist()
    // Only local instances, no remote
    receptionist.register("service-a", "/user/a1")
    let remote = receptionist.getRemoteInstances()
    @Expect(remote.size, 0)
}

@Test
func testClusterReceptionist_multipleRegistrationsSameService() {
    let receptionist = createReceptionist()
    receptionist.register("user-service", "/user/actor1")
    receptionist.register("user-service", "/user/actor2")
    receptionist.register("user-service", "/user/actor3")
    @Expect(receptionist.count("user-service"), 3)
}

@Test
func testClusterReceptionist_getNodeId() {
    let receptionist = createReceptionist()
    @Expect(receptionist.getNodeId(), "node-1")
}

// === ReceptionistEventHandler Tests ===

class TestReceptionistHandler <: ReceptionistEventHandler {
    public let registeredEvents = ArrayList<String>()
    public let unregisteredEvents = ArrayList<(String, String)>()
    public let updatedEvents = ArrayList<String>()
    public let discoveryEvents = ArrayList<String>()

    public func onServiceRegistered(serviceName: String, instance: ServiceInstance): Unit {
        registeredEvents.add(serviceName)
    }

    public func onServiceUnregistered(serviceName: String, actorPath: String): Unit {
        unregisteredEvents.add((serviceName, actorPath))
    }

    public func onServiceUpdated(serviceName: String, instance: ServiceInstance): Unit {
        updatedEvents.add(serviceName)
    }

    public func onDiscovery(serviceName: String, instances: ArrayList<ServiceInstance>): Unit {
        discoveryEvents.add(serviceName)
    }
}

@Test
func testClusterReceptionist_eventHandler_registered() {
    let receptionist = createReceptionist()
    let handler = TestReceptionistHandler()
    receptionist.setEventHandler(handler)
    receptionist.register("user-service", "/user/actor1")
    @Expect(handler.registeredEvents.size, 1)
    @Expect(handler.registeredEvents[0], "user-service")
}

@Test
func testClusterReceptionist_eventHandler_unregistered() {
    let receptionist = createReceptionist()
    let handler = TestReceptionistHandler()
    receptionist.setEventHandler(handler)
    receptionist.register("user-service", "/user/actor1")
    receptionist.unregister("user-service", "/user/actor1")
    @Expect(handler.unregisteredEvents.size, 1)
    @Expect(handler.unregisteredEvents[0].get<0>(), "user-service")
}

@Test
func testClusterReceptionist_eventHandler_discovery() {
    let receptionist = createReceptionist()
    let handler = TestReceptionistHandler()
    receptionist.setEventHandler(handler)
    receptionist.register("user-service", "/user/actor1")
    receptionist.find("user-service")
    @Expect(handler.discoveryEvents.size >= 1, true)
}

// === ReceptionistConfig Tests ===

@Test
func testReceptionistConfig_creation() {
    let config = ReceptionistConfig(
        10000,
        1000,
        Duration.minute,
        Duration.minute * 5,
        true
    )
    @Expect(config.maxServices, 10000)
    @Expect(config.maxInstancesPerService, 1000)
    @Expect(config.enableReplication, true)
}

@Test
func testCreateDefaultReceptionistConfig() {
    let config = createDefaultReceptionistConfig()
    @Expect(config.maxServices, 10000)
    @Expect(config.enableReplication, true)
}