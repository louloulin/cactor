# CActor API Reference

## 🎯 API Overview

CActor provides a clean, type-safe API designed with Akka patterns, tailored for the Cangjie language.

## 📦 Core API

### CActor - Unified Entry Point

```cangjie
import cactor.api.{CActor}

// Create default Actor system
let system = CActor.system()

// Create named Actor system
let system = CActor.system("MySystem")

// Create configured Actor system
let config = CActorRuntimeConfig.createProduction()
let system = CActor.system("MySystem", config)

// Create Actor Props
let props = CActor.props({ => MyActor() })
```

### CActorSystem - Actor System

```cangjie
public class CActorSystem {
    // Create Actor
    public func actorOf(creator: () -> Actor, name: String): ActorRef
    public func actorOf(creator: () -> Actor): ActorRef
    
    // System management
    public func shutdown(): Unit
    public func awaitTermination(): Unit
    public func isTerminated(): Bool
    
    // System information
    public func name(): String
    public func startTime(): DateTime
    public func uptime(): Duration
}
```

### ActorRef - Actor Reference

```cangjie
public interface ActorRef {
    // Message sending
    func tell(message: Message): Unit
    func tell(message: Message, sender: Option<ActorRef>): Unit
    
    // Request-Response (Ask pattern)
    func ask(message: Message): Future<Message>
    func ask(message: Message, timeout: Duration): Future<Message>
    
    // Actor information
    func path(): ActorPath
    func name(): String
    func isTerminated(): Bool
}
```

### Actor - Actor Interface

```cangjie
public interface Actor {
    // Message handling (required)
    func receive(message: Message, context: ActorContext): MessageResult
    
    // Lifecycle hooks (optional)
    func preStart(): Unit { }
    func postStop(): Unit { }
    func preRestart(reason: Exception): Unit { }
    func postRestart(reason: Exception): Unit { }
    
    // Actor properties
    prop name: String { get() }
    prop description: String { get() }
}
```

## 📨 Message System

### Message - Message Interface

```cangjie
public interface Message {
    func messageType(): String
}

// Built-in message types
public class StringMessage <: Message {
    public let content: String
    public init(content: String) { this.content = content }
}

public class IntMessage <: Message {
    public let value: Int64
    public init(value: Int64) { this.value = value }
}

public class JsonMessage <: Message {
    public let data: String
    public init(data: String) { this.data = data }
}
```

### MessageResult - Message Processing Result

```cangjie
public enum MessageResult {
    | Handled      // Message handled
    | Unhandled    // Message not handled
    | Failed       // Processing failed
}
```

### ActorContext - Actor Context

```cangjie
public interface ActorContext {
    // Self reference
    func self(): ActorRef
    func sender(): Option<ActorRef>
    
    // Child Actor management
    func actorOf(creator: () -> Actor, name: String): ActorRef
    func stop(actor: ActorRef): Unit
    
    // Message sending
    func tell(target: ActorRef, message: Message): Unit
    func ask(target: ActorRef, message: Message): Future<Message>
    
    // System access
    func system(): ActorSystem
    func parent(): Option<ActorRef>
    func children(): Array<ActorRef>
}
```

## ⚙️ Configuration API

### MailboxConfig - Mailbox Configuration

```cangjie
public class MailboxConfig {
    // Create unbounded mailbox
    public static func unbounded(): MailboxConfig
    
    // Create bounded mailbox
    public static func bounded(capacity: Int32): MailboxConfig
    
    // Create priority mailbox
    public static func priority(): MailboxConfig
    public static func priority(comparator: (Message, Message) -> Int32): MailboxConfig
    
    // Create Foundation mailbox (high performance)
    public static func foundation(): MailboxConfig
}
```

### DispatcherConfig - Dispatcher Configuration

```cangjie
public class DispatcherConfig {
    // Create thread pool dispatcher
    public static func threadPool(): DispatcherConfig
    public static func threadPool(threads: Int32): DispatcherConfig
    
    // Create work-stealing dispatcher (recommended)
    public static func workStealing(): DispatcherConfig
    public static func workStealing(parallelism: Int32): DispatcherConfig
    
    // Create pinned dispatcher
    public static func pinned(): DispatcherConfig
    
    // Create NUMA-aware dispatcher
    public static func numa(): DispatcherConfig
}
```

### SupervisionConfig - Supervision Configuration

```cangjie
public class SupervisionConfig {
    // Create restart strategy
    public static func restart(): SupervisionConfig
    public static func restart(maxRetries: Int32, timeWindow: Duration): SupervisionConfig
    
    // Create stop strategy
    public static func stop(): SupervisionConfig
    
    // Create resume strategy
    public static func resume(): SupervisionConfig
    
    // Create escalate strategy
    public static func escalate(): SupervisionConfig
}
```

## 🎭 Pattern API

### Ask Pattern

```cangjie
import cactor.patterns.ask.{Ask}

// Use Ask pattern
let future = Ask.ask(actorRef, message, Duration.second * 5)
let result = future.await()

// Async handling
future.onComplete { result =>
    match (result) {
        case Success(msg) => println("Received response: ${msg}")
        case Failure(ex) => println("Request failed: ${ex}")
    }
}
```

### Routing Pattern

```cangjie
import cactor.patterns.routing.{Router, RoundRobinRouter}

// Create router
let routees = [actor1, actor2, actor3]
let router = RoundRobinRouter(routees)

// Send message to router
router.route(message)
```

### Circuit Breaker Pattern

```cangjie
import cactor.patterns.circuit_breaker.{CircuitBreaker}

// Create circuit breaker
let breaker = CircuitBreaker.create(
    maxFailures = 5,
    callTimeout = Duration.second * 10,
    resetTimeout = Duration.second * 60
)

// Use circuit breaker
breaker.call {
    // Potentially failing operation
    riskyOperation()
}
```

## 🔧 Advanced API

### Props - Actor Properties

```cangjie
public class ActorProps {
    // Basic creation
    public init(creator: () -> Actor)
    
    // Configure mailbox
    public func withMailbox(config: MailboxConfig): ActorProps
    
    // Configure dispatcher
    public func withDispatcher(config: DispatcherConfig): ActorProps
    
    // Configure supervision strategy
    public func withSupervision(config: SupervisionConfig): ActorProps
    
    // Configure routing
    public func withRouter(router: Router): ActorProps
}
```

### ActorSystem Extensions

```cangjie
import cactor.api.public.{ActorSystemExtensions}

// Create extended system
let system = ActorSystemExtensions.create("ExtendedSystem")

// Get system metrics
let metrics = system.metrics()
println("Actor count: ${metrics.actorCount}")
println("Message throughput: ${metrics.throughput}")

// System health check
let health = system.healthCheck()
if (health.isHealthy()) {
    println("System is healthy")
}
```

## 📊 Monitoring API

### SystemMetrics - System Metrics

```cangjie
public class SystemMetrics {
    // Basic metrics
    func actorCount(): Int64
    func messageCount(): Int64
    func throughput(): Double
    
    // Performance metrics
    func averageLatency(): Duration
    func p99Latency(): Duration
    func errorRate(): Double
    
    // Resource metrics
    func memoryUsage(): MemoryUsage
    func cpuUsage(): Double
}
```

### HealthCheck - Health Check

```cangjie
public class HealthCheck {
    func isHealthy(): Bool
    func getStatus(): HealthStatus
    func getDetails(): HealthDetails
}
```

## 🧪 Testing API

### TestActorSystem - Test System

```cangjie
import cactor.integration.testing.{TestActorSystem, TestProbe}

// Create test system
let testSystem = TestActorSystem("TestSystem")

// Create test probe
let probe = TestProbe(testSystem)

// Send message and verify
actor.tell(message)
probe.expectMessage(expectedMessage, Duration.second * 1)
```

## 📝 Usage Examples

### Complete Example

```cangjie
import cactor.api.{CActor}
import cactor.core.message.{StringMessage}

// Define Actor
class EchoActor <: Actor {
    public func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case msg: StringMessage =>
                context.sender().map { sender =>
                    sender.tell(StringMessage("Echo: ${msg.content}"))
                }
                MessageResult.Handled
            case _ => MessageResult.Unhandled
        }
    }
}

// Main program
main(): Int64 {
    // Create system
    let system = CActor.system("EchoSystem")
    
    // Create Actor
    let echo = system.actorOf({ => EchoActor() }, "echo")
    
    // Send message
    echo.tell(StringMessage("Hello"))
    
    // Graceful shutdown
    system.shutdown()
    system.awaitTermination()
    
    return 0
}
```

## 🔗 Related Links

- [Architecture Design](architecture.md) - Learn about CActor's architecture
- [Performance Optimization](performance.md) - Performance optimization guide
- [Best Practices](best-practices.md) - Usage best practices
- [Examples Collection](examples.md) - Rich example code

---

**CActor API is designed to be clean, powerful, and type-safe, making Actor programming enjoyable!** 🚀
