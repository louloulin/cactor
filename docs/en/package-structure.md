# CActor Package Structure Design

## 📦 Overall Package Structure

CActor adopts a 6-layer modular architecture with clear responsibilities and boundaries for each layer:

```
src/
├── cactor.cj                    # Main package export file
├── foundation/                  # Foundation Layer
├── core/                       # Core Layer
├── runtime/                    # Runtime Layer
├── patterns/                   # Patterns Layer
├── distribution/               # Distribution Layer
├── integration/                # Integration Layer
├── api/                        # API Layer
├── macros/                     # Macro system
├── config/                     # Configuration files
└── examples/                   # Example code
```

## 🏗️ Detailed Package Structure

### 1. Foundation Layer

```
foundation/
├── pkg.cj                      # Package export file
├── concurrency/                # Concurrency primitives
│   ├── pkg.cj
│   ├── lockfree_queue.cj      # Lock-free queue implementation
│   ├── spsc_queue.cj          # Single Producer Single Consumer queue
│   ├── mpsc_queue.cj          # Multiple Producer Single Consumer queue
│   ├── atomic_operations.cj    # Atomic operations wrapper
│   └── thread_pool.cj         # Thread pool implementation
├── serialization/              # Serialization framework
│   ├── pkg.cj
│   ├── serializer.cj          # Serialization interface
│   ├── json_serializer.cj     # JSON serializer
│   ├── binary_serializer.cj   # Binary serializer
│   └── serialization_manager.cj # Serialization manager
├── network/                    # Network communication
│   ├── pkg.cj
│   ├── network_transport.cj    # Network transport interface
│   ├── tcp_transport.cj       # TCP transport implementation
│   ├── udp_transport.cj       # UDP transport implementation
│   └── connection_pool.cj     # Connection pool
└── memory/                     # Memory management
    ├── pkg.cj
    ├── object_pool.cj         # Object pool
    ├── memory_pool.cj         # Memory pool
    ├── numa_memory_pool.cj    # NUMA-aware memory pool
    └── smart_gc.cj            # Smart garbage collection
```

### 2. Core Layer

```
core/
├── pkg.cj                      # Package export file
├── actor/                      # Actor abstractions
│   ├── pkg.cj
│   ├── actor.cj               # Actor interface
│   ├── actor_ref.cj           # Actor reference
│   ├── actor_path.cj          # Actor path
│   ├── props.cj               # Actor properties
│   └── actor_lifecycle.cj     # Actor lifecycle
├── message/                    # Message abstractions
│   ├── pkg.cj
│   ├── message.cj             # Message interface
│   ├── envelope.cj            # Message envelope
│   ├── string_message.cj      # String message
│   ├── json_message.cj        # JSON message
│   ├── network_message.cj     # Network message
│   ├── zerocopy_message.cj    # Zero-copy message
│   ├── enhanced_message.cj    # Enhanced message
│   └── message_serializer.cj  # Message serializer
├── system/                     # System abstractions
│   ├── pkg.cj
│   ├── actor_system.cj        # Actor system interface
│   ├── system_guardian.cj     # System guardian
│   └── dead_letters.cj        # Dead letter handling
├── context/                    # Context
│   ├── pkg.cj
│   ├── actor_context.cj       # Actor context interface
│   └── context_impl.cj        # Context implementation
├── supervision/                # Supervision strategies
│   ├── pkg.cj
│   ├── supervision_strategy.cj # Supervision strategy
│   ├── supervision_directive.cj # Supervision directive
│   └── fault_handling.cj      # Fault handling
└── config/                     # Core configuration
    ├── pkg.cj
    ├── actor_config.cj        # Actor configuration
    ├── mailbox_config.cj      # Mailbox configuration
    ├── dispatcher_config.cj   # Dispatcher configuration
    └── supervision_config.cj  # Supervision configuration
```

### 3. Runtime Layer

```
runtime/
├── pkg.cj                      # Package export file
├── cactor_runtime.cj          # Main runtime manager
├── plan10_cactor_runtime.cj   # Plan10 runtime implementation
├── dispatcher/                 # Dispatcher implementations
│   ├── pkg.cj
│   ├── message_dispatcher.cj   # Dispatcher interface
│   ├── thread_pool_dispatcher.cj # Thread pool dispatcher
│   ├── work_stealing_dispatcher.cj # Work-stealing dispatcher
│   ├── pinned_dispatcher.cj    # Pinned thread dispatcher
│   ├── numa_dispatcher.cj     # NUMA-aware dispatcher
│   ├── batch_processing/      # Batch processing
│   │   ├── batch_processor.cj
│   │   └── batch_config.cj
│   └── advanced/              # Advanced dispatchers
│       ├── foundation_based_dispatcher.cj
│       └── adaptive_dispatcher.cj
├── mailbox/                    # Mailbox implementations
│   ├── pkg.cj
│   ├── mailbox.cj             # Mailbox interface
│   ├── unbounded_mailbox.cj   # Unbounded mailbox
│   ├── bounded_mailbox.cj     # Bounded mailbox
│   ├── priority_mailbox.cj    # Priority mailbox
│   ├── foundation_mailbox.cj  # Foundation mailbox
│   └── mailbox_factory.cj     # Mailbox factory
├── actor/                      # Runtime actors
│   ├── pkg.cj
│   ├── high_performance_actor.cj # High-performance actor
│   └── actor_system_impl.cj   # Actor system implementation
├── context/                    # Runtime context
│   ├── pkg.cj
│   ├── pooled_actor_context.cj # Pooled actor context
│   └── context_factory.cj     # Context factory
├── lifecycle/                  # Lifecycle management
│   ├── pkg.cj
│   ├── lifecycle_manager.cj   # Lifecycle manager
│   └── actor_lifecycle_state.cj # Actor lifecycle state
├── monitoring/                 # Runtime monitoring
│   ├── pkg.cj
│   ├── actor_system_metrics.cj # System metrics
│   └── performance_monitor.cj  # Performance monitor
├── guardian/                   # Guardian implementations
│   ├── pkg.cj
│   ├── runtime_system_guardian.cj # System guardian
│   └── runtime_user_guardian.cj # User guardian
├── registry/                   # Actor registry
│   ├── pkg.cj
│   └── simple_actor_registry.cj # Simple registry
├── supervision/                # Supervision implementation
│   ├── pkg.cj
│   └── supervision_manager.cj  # Supervision manager
├── events/                     # Event system
│   ├── pkg.cj
│   ├── actor_event_bus.cj     # Actor event bus
│   └── simple_actor_event_bus.cj # Simple event bus
└── message/                    # Runtime messages
    ├── pkg.cj
    └── batch_message_processor.cj # Batch message processor
```

### 4. Patterns Layer

```
patterns/
├── pkg.cj                      # Package export file
├── ask/                        # Ask pattern
│   ├── pkg.cj
│   ├── ask_pattern.cj         # Ask pattern implementation
│   ├── ask_future.cj          # Ask future
│   └── ask_timeout.cj         # Ask timeout handling
├── routing/                    # Routing patterns
│   ├── pkg.cj
│   ├── router.cj              # Router interface
│   ├── round_robin_router.cj  # Round-robin router
│   ├── random_router.cj       # Random router
│   ├── consistent_hash_router.cj # Consistent hash router
│   └── advanced/              # Advanced routing
│       ├── advanced_routing.cj
│       └── load_balancer.cj
├── circuit_breaker/            # Circuit breaker pattern
│   ├── pkg.cj
│   ├── circuit_breaker.cj     # Circuit breaker implementation
│   └── circuit_breaker_config.cj # Circuit breaker configuration
├── supervision/                # Supervision patterns
│   ├── pkg.cj
│   ├── supervision_patterns.cj # Supervision patterns
│   └── fault_tolerance.cj     # Fault tolerance
└── backpressure/              # Backpressure patterns
    ├── pkg.cj
    ├── backpressure_strategy.cj # Backpressure strategy
    └── flow_control.cj        # Flow control
```

### 5. Distribution Layer

```
distribution/
├── pkg.cj                      # Package export file
├── remote/                     # Remote communication
│   ├── pkg.cj
│   ├── remote_actor_ref.cj    # Remote actor reference
│   ├── remote_transport.cj    # Remote transport
│   └── remote_deployment.cj   # Remote deployment
├── cluster/                    # Cluster management
│   ├── pkg.cj
│   ├── cluster_manager.cj     # Cluster manager
│   ├── node_discovery.cj      # Node discovery
│   ├── cluster_state.cj       # Cluster state
│   ├── failover.cj            # Failover
│   └── sharding.cj            # Sharding support
├── persistence/                # Persistence
│   ├── pkg.cj
│   ├── persistent_actor.cj    # Persistent actor
│   ├── event_store.cj         # Event store
│   ├── snapshot.cj            # Snapshot mechanism
│   └── recovery.cj            # Recovery mechanism
└── streaming/                  # Stream processing
    ├── pkg.cj
    ├── stream_processing.cj   # Stream processing
    ├── stream_builder.cj      # Stream builder
    └── reactive_streams.cj    # Reactive streams
```

### 6. Integration Layer

```
integration/
├── pkg.cj                      # Package export file
├── monitoring/                 # Monitoring integration
│   ├── pkg.cj
│   ├── metrics.cj             # Metrics collection
│   ├── distributed_tracing.cj # Distributed tracing
│   ├── memory_monitor.cj      # Memory monitoring
│   └── performance_analyzer.cj # Performance analyzer
├── logging/                    # Logging integration
│   ├── pkg.cj
│   ├── actor_logger.cj        # Actor logger
│   └── structured_logging.cj  # Structured logging
├── configuration/              # Configuration management
│   ├── pkg.cj
│   ├── config_manager.cj      # Configuration manager
│   └── hot_reload.cj          # Hot reload
└── testing/                    # Testing framework
    ├── pkg.cj
    ├── test_actor_system.cj   # Test actor system
    ├── test_probe.cj          # Test probe
    ├── simple_benchmark.cj    # Simple benchmark
    ├── simple_benchmark_test/ # Benchmark test
    ├── plan10_comprehensive_test/ # Comprehensive test
    ├── plan10_cactor_runtime_test/ # Runtime test
    └── plan10_api_test/       # API test
```

### 7. API Layer

```
api/
├── pkg.cj                      # Package export file
├── cactor.cj                  # Unified API entry
├── cactor_system_api.cj       # Actor system API
├── config/                     # API configuration
│   ├── pkg.cj
│   ├── mailbox_config_api.cj  # Mailbox configuration API
│   ├── dispatcher_config_api.cj # Dispatcher configuration API
│   └── supervision_config_api.cj # Supervision configuration API
└── public/                     # Public APIs
    ├── pkg.cj
    ├── cactor_factory.cj      # CActor factory
    └── cactor_system_builder.cj # System builder
```

### 8. Other Modules

```
macros/                         # Macro system
├── actor_dsl_macros.cj        # Actor DSL macros

config/                         # Configuration files
└── file/
    ├── config_loader.cj       # Configuration loader
    └── actor_system_config.cj # System configuration

examples/                       # Example code
├── hello_world/               # Basic examples
├── api_demo/                  # API demonstration
├── benchmark_demo/            # Performance examples
├── advanced_dispatcher_examples/ # Advanced dispatcher examples
├── advanced_mailbox_examples/ # Advanced mailbox examples
└── configuration_usage_test/  # Configuration usage test
```

## 🔗 Package Dependencies

### Dependency Hierarchy

```
API Layer
    ↓ (depends on)
Integration Layer
    ↓ (depends on)
Distribution Layer
    ↓ (depends on)
Patterns Layer
    ↓ (depends on)
Runtime Layer
    ↓ (depends on)
Core Layer
    ↓ (depends on)
Foundation Layer
```

### Package Import Rules

1. **Downward Dependencies**: Upper layers can import lower layer packages
2. **No Upward Dependencies**: Lower layers cannot import upper layer packages
3. **Same Layer Dependencies**: Packages within the same layer can import each other
4. **API Isolation**: Users only import API layer, not directly using Core layer

## 📋 Package Responsibilities

### Foundation Layer
- **Responsibility**: Provide infrastructure and utilities
- **Characteristics**: Zero dependencies, can be used independently
- **Contains**: Concurrency primitives, serialization, network, memory management

### Core Layer
- **Responsibility**: Define core abstractions and interfaces
- **Characteristics**: Pure abstractions, no concrete implementations
- **Contains**: Actor, message, system, context abstractions

### Runtime Layer
- **Responsibility**: Provide high-performance execution engine
- **Characteristics**: Concrete implementations, performance optimized
- **Contains**: Dispatchers, mailboxes, lifecycle management

### Patterns Layer
- **Responsibility**: Implement common Actor patterns
- **Characteristics**: Optional features, use as needed
- **Contains**: Ask, routing, circuit breaker, backpressure

### Distribution Layer
- **Responsibility**: Provide distributed capabilities
- **Characteristics**: Enterprise-grade features
- **Contains**: Remote communication, cluster, persistence, stream processing

### Integration Layer
- **Responsibility**: Provide integration and tooling
- **Characteristics**: Development and operations support
- **Contains**: Monitoring, logging, configuration, testing

### API Layer
- **Responsibility**: Provide unified external interface
- **Characteristics**: Simple and easy to use, hide complexity
- **Contains**: Unified API, configuration API, public API

---

**CActor package structure design ensures clear separation of concerns and high modularity!** 🚀
