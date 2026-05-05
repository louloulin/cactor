/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 服务发现单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === ServiceEndpoint Tests ===

@Test
func testServiceEndpoint_creation() {
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)
    @Expect(endpoint.serviceName, "test-service")
    @Expect(endpoint.host, "localhost")
    @Expect(endpoint.port, 8080)
}

@Test
func testServiceEndpoint_address() {
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)
    @Expect(endpoint.address(), "localhost:8080")
}

@Test
func testServiceEndpoint_withMetadata() {
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)
    let withMeta = endpoint.withMetadata("version", "1.0")
    @Expect(withMeta.metadata.contains("version"), true)
}

@Test
func testServiceEndpoint_toString() {
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)
    let str = endpoint.toString()
    @Expect(str.contains("test-service"), true)
    @Expect(str.contains("localhost"), true)
}

// === ServiceRegistry Tests ===

@Test
func testServiceRegistry_register() {
    let registry = ServiceRegistry()
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)
    registry.register(endpoint)

    let found = registry.find("test-service")
    @Expect(found.size, 1)
}

@Test
func testServiceRegistry_registerMultiple() {
    let registry = ServiceRegistry()
    registry.register(ServiceEndpoint("test-service", "node1", 8080))
    registry.register(ServiceEndpoint("test-service", "node2", 8080))
    registry.register(ServiceEndpoint("test-service", "node3", 8080))

    let found = registry.find("test-service")
    @Expect(found.size, 3)
}

@Test
func testServiceRegistry_unregister() {
    let registry = ServiceRegistry()
    registry.register(ServiceEndpoint("test-service", "localhost", 8080))
    registry.register(ServiceEndpoint("test-service", "localhost", 8081))

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
    registry.register(ServiceEndpoint("service-a", "localhost", 8080))
    registry.register(ServiceEndpoint("service-b", "localhost", 8081))
    registry.register(ServiceEndpoint("service-a", "localhost", 8082))

    let names = registry.getServiceNames()
    @Expect(names.size, 2)
}

@Test
func testServiceRegistry_clear() {
    let registry = ServiceRegistry()
    registry.register(ServiceEndpoint("test-service", "localhost", 8080))
    registry.clear()

    let found = registry.find("test-service")
    @Expect(found.size, 0)
}

// === SimpleServiceDiscovery Tests ===

class TestDiscoveryHandler <: ServiceDiscoveryEventHandler {
    public let registered = ArrayList<String>()
    public let unregistered = ArrayList<String>()
    public let changed = ArrayList<String>()

    public func onServiceRegistered(instance: ServiceEndpoint): Unit {
        registered.add(instance.serviceName)
    }

    public func onServiceUnregistered(instance: ServiceEndpoint): Unit {
        unregistered.add(instance.serviceName)
    }

    public func onServicesChanged(serviceName: String): Unit {
        changed.add(serviceName)
    }
}

@Test
func testSimpleServiceDiscovery_register() {
    let discovery = createSimpleServiceDiscovery()
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)

    discovery.register(endpoint)

    let found = discovery.discover("test-service")
    @Expect(found.size, 1)
}

@Test
func testSimpleServiceDiscovery_unregister() {
    let discovery = createSimpleServiceDiscovery()
    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)

    discovery.register(endpoint)
    discovery.unregister("test-service", "localhost", 8080)

    let found = discovery.discover("test-service")
    @Expect(found.size, 0)
}

@Test
func testSimpleServiceDiscovery_getServiceNames() {
    let discovery = createSimpleServiceDiscovery()
    discovery.register(ServiceEndpoint("service-a", "localhost", 8080))
    discovery.register(ServiceEndpoint("service-b", "localhost", 8081))

    let names = discovery.getServiceNames()
    @Expect(names.size, 2)
}

@Test
func testSimpleServiceDiscovery_eventHandler() {
    let discovery = createSimpleServiceDiscovery()
    let handler = TestDiscoveryHandler()
    discovery.setEventHandler(handler)

    let endpoint = ServiceEndpoint("test-service", "localhost", 8080)
    discovery.register(endpoint)

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
