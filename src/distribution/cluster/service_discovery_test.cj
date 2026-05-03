/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 服务发现单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === ServiceInstance Tests ===

@Test
func testServiceInstance_creation() {
    let instance = ServiceInstance("test-service", "localhost", 8080)
    @Expect(instance.serviceName, "test-service")
    @Expect(instance.host, "localhost")
    @Expect(instance.port, 8080)
}

@Test
func testServiceInstance_address() {
    let instance = ServiceInstance("test-service", "localhost", 8080)
    @Expect(instance.address(), "localhost:8080")
}

@Test
func testServiceInstance_withMetadata() {
    let instance = ServiceInstance("test-service", "localhost", 8080)
    let withMeta = instance.withMetadata("version", "1.0")
    @Expect(withMeta.metadata.contains("version"), true)
}

@Test
func testServiceInstance_toString() {
    let instance = ServiceInstance("test-service", "localhost", 8080)
    let str = instance.toString()
    @Expect(str.contains("test-service"), true)
    @Expect(str.contains("localhost"), true)
}

// === ServiceRegistry Tests ===

@Test
func testServiceRegistry_register() {
    let registry = ServiceRegistry()
    let instance = ServiceInstance("test-service", "localhost", 8080)
    registry.register(instance)

    let found = registry.find("test-service")
    @Expect(found.size, 1)
}

@Test
func testServiceRegistry_registerMultiple() {
    let registry = ServiceRegistry()
    registry.register(ServiceInstance("test-service", "node1", 8080))
    registry.register(ServiceInstance("test-service", "node2", 8080))
    registry.register(ServiceInstance("test-service", "node3", 8080))

    let found = registry.find("test-service")
    @Expect(found.size, 3)
}

@Test
func testServiceRegistry_unregister() {
    let registry = ServiceRegistry()
    registry.register(ServiceInstance("test-service", "localhost", 8080))
    registry.register(ServiceInstance("test-service", "localhost", 8081))

    registry.unregister("test-service", "localhost", 8080)

    let found = registry.find("test-service")
    @Expect(found.size, 1)
}

@Test
func testServiceRegistry_findNotExists() {
    let registry = ServiceRegistry()
    let found = registry.find("non-existent")
    @Expect(found.size, 0)
}

@Test
func testServiceRegistry_getServiceNames() {
    let registry = ServiceRegistry()
    registry.register(ServiceInstance("service-a", "localhost", 8080))
    registry.register(ServiceInstance("service-b", "localhost", 8081))
    registry.register(ServiceInstance("service-a", "localhost", 8082))

    let names = registry.getServiceNames()
    @Expect(names.size, 2)
}

@Test
func testServiceRegistry_clear() {
    let registry = ServiceRegistry()
    registry.register(ServiceInstance("test-service", "localhost", 8080))
    registry.clear()

    let found = registry.find("test-service")
    @Expect(found.size, 0)
}

// === SimpleServiceDiscovery Tests ===

class TestDiscoveryHandler <: ServiceDiscoveryEventHandler {
    public let registered = ArrayList<String>()
    public let unregistered = ArrayList<String>()
    public let changed = ArrayList<String>()

    public func onServiceRegistered(instance: ServiceInstance): Unit {
        registered.add(instance.serviceName)
    }

    public func onServiceUnregistered(instance: ServiceInstance): Unit {
        unregistered.add(instance.serviceName)
    }

    public func onServicesChanged(serviceName: String): Unit {
        changed.add(serviceName)
    }
}

@Test
func testSimpleServiceDiscovery_register() {
    let discovery = createSimpleServiceDiscovery()
    let instance = ServiceInstance("test-service", "localhost", 8080)

    discovery.register(instance)

    let found = discovery.discover("test-service")
    @Expect(found.size, 1)
}

@Test
func testSimpleServiceDiscovery_unregister() {
    let discovery = createSimpleServiceDiscovery()
    let instance = ServiceInstance("test-service", "localhost", 8080)

    discovery.register(instance)
    discovery.unregister("test-service", "localhost", 8080)

    let found = discovery.discover("test-service")
    @Expect(found.size, 0)
}

@Test
func testSimpleServiceDiscovery_getServiceNames() {
    let discovery = createSimpleServiceDiscovery()
    discovery.register(ServiceInstance("service-a", "localhost", 8080))
    discovery.register(ServiceInstance("service-b", "localhost", 8081))

    let names = discovery.getServiceNames()
    @Expect(names.size, 2)
}

@Test
func testSimpleServiceDiscovery_eventHandler() {
    let discovery = createSimpleServiceDiscovery()
    let handler = TestDiscoveryHandler()
    discovery.setEventHandler(handler)

    let instance = ServiceInstance("test-service", "localhost", 8080)
    discovery.register(instance)

    @Expect(handler.registered.size, 1)
    @Expect(handler.changed.size, 1)
}

// === DnsServiceDiscovery Tests ===

@Test
func testDnsServiceDiscovery_creation() {
    let discovery = createDnsServiceDiscovery("example.com")
    @Expect(discovery.discover("test").size, 0)
}

@Test
func testDnsServiceDiscovery_addFromDns() {
    let discovery = createDnsServiceDiscovery("example.com")
    discovery.addFromDns("api-service", "api1.example.com", 8080)
    discovery.addFromDns("api-service", "api2.example.com", 8080)

    let found = discovery.discover("api-service")
    @Expect(found.size, 2)
}