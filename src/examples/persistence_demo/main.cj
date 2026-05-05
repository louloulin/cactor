/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Persistence 持久化示例程序
 * 演示事件溯源和持久化功能
 */
package cactor.examples.persistence_demo

import std.collection.*
import std.time.*

// ============================================================================
// Persistence 示例演示
// ============================================================================

/**
 * 账户命令
 */
public enum AccountCommand {
    | Deposit(Int64)
    | Withdraw(Int64)
    | GetBalance
}

/**
 * 账户事件
 */
public enum AccountEvent {
    | Deposited(Int64)
    | Withdrawn(Int64)
    | InsufficientFunds
}

/**
 * 账户状态
 */
public class AccountState {
    public var balance: Int64
    public var transactionCount: Int64

    public init() {
        balance = 0
        transactionCount = 0
    }

    public init(balance: Int64, transactionCount: Int64) {
        this.balance = balance
        this.transactionCount = transactionCount
    }

    public func apply(event: AccountEvent): AccountState {
        match (event) {
            case Deposited(amount) =>
                AccountState(balance + amount, transactionCount + 1)
            case Withdrawn(amount) =>
                AccountState(balance - amount, transactionCount + 1)
            case InsufficientFunds =>
                this
        }
    }
}

/**
 * 账户聚合根
 */
public class AccountAggregate {
    private var state: AccountState
    private let persistenceId: String
    private var uncommittedEvents: ArrayList<AccountEvent>

    public init(persistenceId: String) {
        this.state = AccountState()
        this.persistenceId = persistenceId
        this.uncommittedEvents = ArrayList<AccountEvent>()
    }

    public func deposit(amount: Int64): Unit {
        let event = Deposited(amount)
        uncommittedEvents.add(event)
        state = state.apply(event)
    }

    public func withdraw(amount: Int64): Unit {
        if (state.balance >= amount) {
            let event = Withdrawn(amount)
            uncommittedEvents.add(event)
            state = state.apply(event)
        } else {
            uncommittedEvents.add(InsufficientFunds)
        }
    }

    public func getBalance(): Int64 {
        state.balance
    }

    public func getUncommittedEvents(): ArrayList<AccountEvent> {
        uncommittedEvents
    }

    public func markCommitted(): Unit {
        uncommittedEvents.clear()
    }

    public func getPersistenceId(): String {
        persistenceId
    }

    public func getTransactionCount(): Int64 {
        state.transactionCount
    }
}

/**
 * 演示基本账户聚合
 */
public func demonstrateAccountAggregate(): Unit {
    println("=== 账户聚合演示 ===")

    let account = AccountAggregate("account-1")

    println("初始账户:")
    println("  ID: ${account.getPersistenceId()}")
    println("  余额: ${account.getBalance()}")
    println()

    // 存款
    println("存款 100:")
    account.deposit(100)
    println("  余额: ${account.getBalance()}")
    println("  未提交事件: ${account.getUncommittedEvents().size}")

    // 再存款
    println("存款 200:")
    account.deposit(200)
    println("  余额: ${account.getBalance()}")

    // 取款
    println("取款 50:")
    account.withdraw(50)
    println("  余额: ${account.getBalance()}")

    // 尝试取款超过余额
    println("尝试取款 500 (超过余额):")
    account.withdraw(500)
    println("  余额: ${account.getBalance()} (未变化)")

    // 提交事件
    println("提交事件:")
    account.markCommitted()
    println("  未提交事件数: ${account.getUncommittedEvents().size}")

    println("最终账户:")
    println("  ID: ${account.getPersistenceId()}")
    println("  余额: ${account.getBalance()}")
    println("  交易次数: ${account.getTransactionCount()}")
    println()
}

/**
 * 演示事件历史重放
 */
public func demonstrateEventReplay(): Unit {
    println("=== 事件重放演示 ===")

    // 模拟事件历史
    let events = ArrayList<AccountEvent>()
    events.add(Deposited(100))
    events.add(Deposited(200))
    events.add(Withdrawn(50))
    events.add(Deposited(150))
    events.add(Withdrawn(30))

    println("事件历史:")
    var index = 0
    for (event in events) {
        index += 1
        match (event) {
            case Deposited(amount) => println("  ${index}. 存款 ${amount}")
            case Withdrawn(amount) => println("  ${index}. 取款 ${amount}")
            case InsufficientFunds => println("  ${index}. 余额不足")
        }
    }

    // 重放事件重建状态
    let state = AccountState()
    var currentState = state
    for (event in events) {
        currentState = currentState.apply(event)
    }

    println()
    println("重放后状态:")
    println("  最终余额: ${currentState.balance}")
    println("  交易次数: ${currentState.transactionCount}")
    println()
}

/**
 * 演示快照
 */
public func demonstrateSnapshot(): Unit {
    println("=== 快照演示 ===")

    let account = AccountAggregate("account-snapshot")

    // 执行一系列操作
    account.deposit(100)
    account.deposit(200)
    account.deposit(300)

    // 模拟保存快照
    println("保存快照前的状态:")
    println("  ID: ${account.getPersistenceId()}")
    println("  余额: ${account.getBalance()}")
    println("  交易次数: ${account.getTransactionCount()}")

    // 创建快照数据
    let snapshotData = "(balance=${account.getBalance()}, txns=${account.getTransactionCount()})"
    println()
    println("快照数据: ${snapshotData}")

    // 模拟从快照恢复
    println()
    println("从快照恢复:")
    println("  恢复后 ID: ${account.getPersistenceId()}")
    println("  恢复后余额: ${account.getBalance()}")

    println()
}

/**
 * Journal 配置
 */
public class JournalConfig {
    public let directory: String
    public let maxMessageSize: Int64
    public let async: Bool
    public let batchSize: Int64

    public init(directory: String, maxMessageSize: Int64, async: Bool, batchSize: Int64) {
        this.directory = directory
        this.maxMessageSize = maxMessageSize
        this.async = async
        this.batchSize = batchSize
    }
}

/**
 * Snapshot 配置
 */
public class SnapshotConfig {
    public let directory: String
    public let snapshotEveryNEvents: Int64
    public let keepNSnapshots: Int64

    public init(directory: String, snapshotEveryNEvents: Int64, keepNSnapshots: Int64) {
        this.directory = directory
        this.snapshotEveryNEvents = snapshotEveryNEvents
        this.keepNSnapshots = keepNSnapshots
    }
}

/**
 * 演示持久化配置
 */
public func demonstratePersistenceConfig(): Unit {
    println("=== 持久化配置演示 ===")

    // Journal 配置
    let journalConfig = JournalConfig(
        "/data/journal",
        1000,    // max message size
        true,     // async
        100       // batch size
    )
    println("Journal 配置:")
    println("  路径: ${journalConfig.directory}")
    println("  最大消息大小: ${journalConfig.maxMessageSize}")
    println("  异步模式: ${journalConfig.async}")
    println()

    // Snapshot 配置
    let snapshotConfig = SnapshotConfig(
        "/data/snapshots",
        100,     // snapshot every N events
        3        // keep N snapshots
    )
    println("Snapshot 配置:")
    println("  路径: ${snapshotConfig.directory}")
    println("  快照频率: 每 ${snapshotConfig.snapshotEveryNEvents} 个事件")
    println("  保留快照数: ${snapshotConfig.keepNSnapshots}")
    println()
}

/**
 * 演示 PersistenceFSM
 */
public func demonstratePersistenceFSM(): Unit {
    println("=== PersistenceFSM 演示 ===")

    // 简单的状态机
    let states = ArrayList<String>()
    states.add("Idle")
    states.add("Processing")
    states.add("Completed")
    states.add("Failed")
    let currentState = "Idle"

    println("FSM 初始状态: ${currentState}")
    println()

    // 模拟状态转换
    println("状态转换:")
    println("  Idle -> Processing (接收到命令)")
    println("  Processing -> Completed (处理成功)")
    println("  Processing -> Failed (处理失败)")

    // FSM 事件
    println()
    println("FSM 事件:")
    println("  - StateTransition(from, to, data)")
    println("  - StateTimeout(state)")
    println("  - StateRestored(snapshot)")
    println()
}

/**
 * 运行所有演示
 */
main(args: Array<String>): Unit {
    println("========================================")
    println("   CActor Persistence 持久化演示")
    println("========================================")
    println()

    demonstrateAccountAggregate()
    demonstrateEventReplay()
    demonstrateSnapshot()
    demonstratePersistenceConfig()
    demonstratePersistenceFSM()

    println("========================================")
    println("   Persistence 演示完成!")
    println("========================================")
}
