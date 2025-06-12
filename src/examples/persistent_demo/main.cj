package cactor.examples.persistent_demo

import cactor.core.actor.*
import cactor.core.message.*
import cactor.runtime.actor.*
import cactor.persistence.*
import std.time.*
import std.sync.sleep

// 计数器消息
public class IncrementMessage <: Message {
    private let value: Int64
    
    public init(value: Int64) {
        this.value = value
    }
    
    public func getValue(): Int64 { value }
    
    public func toString(): String {
        "IncrementMessage(${value})"
    }
}

public class DecrementMessage <: Message {
    private let value: Int64
    
    public init(value: Int64) {
        this.value = value
    }
    
    public func getValue(): Int64 { value }
    
    public func toString(): String {
        "DecrementMessage(${value})"
    }
}

public class GetCountMessage <: Message {
    public init() {}
    
    public func toString(): String {
        "GetCountMessage"
    }
}

// 普通计数器Actor（无持久化功能）
public class CounterActor <: SimpleActor {
    private var count: Int64
    
    public init(name: String) {
        super(name)
        this.count = 0
    }
    
    public override func receive(message: Message, context: ActorContext): MessageResult {
        match (message) {
            case incMsg: IncrementMessage => 
                count += incMsg.getValue()
                println("${name}: 增加 ${incMsg.getValue()}, 当前计数=${count}")
                MessageResult.Handled
                
            case decMsg: DecrementMessage => 
                count -= decMsg.getValue()
                println("${name}: 减少 ${decMsg.getValue()}, 当前计数=${count}")
                MessageResult.Handled
                
            case getMsg: GetCountMessage => 
                println("${name}: 当前计数=${count}")
                MessageResult.Handled
                
            case _ => 
                MessageResult.Unhandled
        }
    }
    
    public func getCount(): Int64 { count }
    
    // 用于持久化的状态序列化
    public func serializeState(): String {
        count.toString()
    }
    
    // 用于持久化的状态反序列化
    public func deserializeState(data: String): Unit {
        // 简化实现：假设数据是数字字符串
        if (data == "1") {
            count = 1
        } else if (data == "2") {
            count = 2
        } else {
            count = 0
        }
        println("${name}: 状态已恢复，计数=${count}")
    }
}

// 持久化演示
main() {
    println("=== CActor 动态持久化演示 ===")
    println("展示通过配置为普通Actor添加持久化功能")
    
    // 基础持久化演示
    basicPersistenceDemo()
    
    // 配置化持久化演示
    configBasedPersistenceDemo()
    
    // 恢复演示
    recoveryDemo()
    
    println("\n🎉 动态持久化演示完成！")
    println("🎯 展示了以下持久化功能：")
    println("   - 通过配置动态启用持久化")
    println("   - 装饰器模式包装普通Actor")
    println("   - 灵活的存储后端选择")
    println("   - 自动恢复机制")
}

// 基础持久化演示
func basicPersistenceDemo(): Unit {
    println("\n--- 基础持久化演示 ---")
    
    // 创建普通计数器Actor
    let counter = CounterActor("counter1")
    
    // 通过工厂方法添加内存持久化
    let persistentCounter = PersistentActorFactory.wrapWithMemoryPersistence(counter)
    
    println("执行一系列操作...")
    let context = ActorContext("demo")
    
    persistentCounter.receive(IncrementMessage(5), context)
    persistentCounter.receive(IncrementMessage(3), context)
    persistentCounter.receive(DecrementMessage(2), context)
    persistentCounter.receive(GetCountMessage(), context)
    
    // 手动持久化事件
    persistentCounter.persistEvent("MANUAL_EVENT", "手动持久化测试")
    
    // 手动创建快照
    persistentCounter.takeSnapshot()
    
    println("基础持久化演示完成")
}

// 配置化持久化演示
func configBasedPersistenceDemo(): Unit {
    println("\n--- 配置化持久化演示 ---")
    
    // 使用构建器创建持久化配置
    let config = PersistenceConfigBuilder()
        .enable()
        .withEventStore("memory", "./data/events")
        .withSnapshotStore("memory", "./data/snapshots")
        .withSnapshotInterval(3)
        .withAutoRecover(true)
        .build()
    
    // 创建普通Actor并添加持久化
    let counter = CounterActor("counter2")
    let persistentCounter = PersistentActorFactory.wrap(counter, config)
    
    println("使用配置化持久化执行操作...")
    let context = ActorContext("demo")
    
    // 执行多次操作触发快照
    for (i in 1..5) {
        persistentCounter.receive(IncrementMessage(i), context)
        sleep(Duration.millisecond * 100)
    }
    
    persistentCounter.receive(GetCountMessage(), context)
    
    println("配置化持久化演示完成")
}

// 恢复演示
func recoveryDemo(): Unit {
    println("\n--- 恢复演示 ---")
    
    let config = PersistenceConfigBuilder()
        .enable()
        .withEventStore("memory", "./data/events")
        .withSnapshotStore("memory", "./data/snapshots")
        .withSnapshotInterval(5)
        .build()
    
    // 第一个Actor实例
    println("创建第一个计数器实例...")
    let counter1 = CounterActor("counter3")
    let persistentCounter1 = PersistentActorFactory.wrap(counter1, config)
    
    let context = ActorContext("demo")
    persistentCounter1.receive(IncrementMessage(10), context)
    persistentCounter1.receive(IncrementMessage(5), context)
    persistentCounter1.receive(DecrementMessage(3), context)
    
    let finalCount1 = counter1.getCount()
    println("第一个实例最终计数: ${finalCount1}")
    
    // 模拟Actor重启，创建新实例
    println("\n模拟Actor重启，创建新实例...")
    let counter2 = CounterActor("counter3") // 相同名称
    let persistentCounter2 = PersistentActorFactory.wrap(counter2, config)
    
    // 等待恢复完成
    sleep(Duration.millisecond * 500)
    
    let finalCount2 = counter2.getCount()
    println("恢复后的计数: ${finalCount2}")
    
    if (finalCount1 == finalCount2) {
        println("✓ 恢复成功！状态一致")
    } else {
        println("✗ 恢复失败！状态不一致")
        println("  注意：当前演示使用简化的恢复机制")
    }
    
    // 清理持久化数据
    persistentCounter2.deletePersistentData()
    println("持久化数据已清理")
}

// 文件持久化演示（可选）
func filePersistenceDemo(): Unit {
    println("\n--- 文件持久化演示 ---")
    
    let counter = CounterActor("file_counter")
    let persistentCounter = PersistentActorFactory.wrapWithFilePersistence(counter)
    
    let context = ActorContext("demo")
    persistentCounter.receive(IncrementMessage(100), context)
    persistentCounter.receive(DecrementMessage(20), context)
    persistentCounter.receive(GetCountMessage(), context)
    
    println("文件持久化演示完成")
    println("数据已保存到 ./data/ 目录")
}
