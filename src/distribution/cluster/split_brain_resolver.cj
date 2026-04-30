/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Split Brain Resolver 实现
 * 对标 Akka Split Brain Resolver
 * 处理集群脑裂问题，确保在网络分区时集群能安全收敛
 */
package cactor.distribution.cluster

import std.collection.*
import std.sync.*
import std.time.*

/**
 * Split Brain Resolver 策略枚举 - 对标 Akka SBR
 */
public enum SBRStrategy {
    | KeepMajority      // 保留多数节点 (基于节点数量)
    | KeepOldest         // 保留最老节点 (基于节点优先级)
    | KeepReferee       // 保留指定节点 (必须存活)
    | StaticQuorum      // 静态多数 (基于配置的 quorum 大小)
    | DownAll           // 关闭所有节点 (保守策略)
    | KeepMinority      // 保留少数节点 (特殊场景)

    public func toString(): String {
        match (this) {
            case KeepMajority => "KeepMajority"
            case KeepOldest => "KeepOldest"
            case KeepReferee => "KeepReferee"
            case StaticQuorum => "StaticQuorum"
            case DownAll => "DownAll"
            case KeepMinority => "KeepMinority"
        }
    }
}

/**
 * Split Brain Resolver 配置
 */
public struct SBRConfig {
    public let strategy: SBRStrategy
    public let downAllWhenUnreachable: Duration    // 不可达多久后下线节点
    public let stableAfter: Duration              // 集群稳定检测时间
    public let majorityCanSplit: Bool            // 多数方是否可以分裂
    public let refereeCanSplit: Bool             // referee 节点是否可以分裂
    public let downRemovalsEnabled: Bool         // 是否启用下线移除
    public let quitClaimRetries: Int32           // 退出声明重试次数

    public init(
        strategy: SBRStrategy,
        downAllWhenUnreachable!: Duration = Duration.second * 30,
        stableAfter!: Duration = Duration.second * 15,
        majorityCanSplit!: Bool = true,
        refereeCanSplit!: Bool = true,
        downRemovalsEnabled!: Bool = true,
        quitClaimRetries!: Int32 = 3
    ) {
        this.strategy = strategy
        this.downAllWhenUnreachable = downAllWhenUnreachable
        this.stableAfter = stableAfter
        this.majorityCanSplit = majorityCanSplit
        this.refereeCanSplit = refereeCanSplit
        this.downRemovalsEnabled = downRemovalsEnabled
        this.quitClaimRetries = quitClaimRetries
    }

    /**
     * 获取默认配置 (KeepMajority)
     */
    public static func getDefault(): SBRConfig {
        SBRConfig(SBRStrategy.KeepMajority)
    }

    /**
     * 创建 KeepOldest 配置
     */
    public static func keepOldest(stableAfter!: Duration = Duration.second * 15): SBRConfig {
        SBRConfig(SBRStrategy.KeepOldest, stableAfter: stableAfter)
    }

    /**
     * 创建 StaticQuorum 配置
     */
    public static func staticQuorum(
        quorumSize: Int32,
        stableAfter!: Duration = Duration.second * 15
    ): SBRConfig {
        let config = SBRConfig(SBRStrategy.StaticQuorum, stableAfter: stableAfter)
        config
    }

    /**
     * 创建 DownAll 配置 (最保守策略)
     */
    public static func downAll(
        downAllWhenUnreachable!: Duration = Duration.second * 30
    ): SBRConfig {
        SBRConfig(SBRStrategy.DownAll, downAllWhenUnreachable: downAllWhenUnreachable)
    }
}

/**
 * SBR 决策结果
 */
public class SBRDecision {
    public let strategy: SBRStrategy
    public let survivors: HashSet<UniqueAddress>
    public let victims: HashSet<UniqueAddress>
    public let reason: String
    public let timestamp: Int64

    public init(
        strategy: SBRStrategy,
        survivors: HashSet<UniqueAddress>,
        victims: HashSet<UniqueAddress>,
        reason: String
    ) {
        this.strategy = strategy
        this.survivors = survivors
        this.victims = victims
        this.reason = reason
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func isSurvivor(address: UniqueAddress): Bool {
        survivors.contains(address)
    }

    public func isVictim(address: UniqueAddress): Bool {
        victims.contains(address)
    }

    public func toString(): String {
        "SBRDecision(${strategy.toString()}, survivors=${survivors.size()}, victims=${victims.size()}, reason=${reason})"
    }
}

/**
 * Split Brain Resolver 接口 - 对标 Akka SplitBrainResolver
 */
public interface SplitBrainResolver {
    /**
     * 解析脑裂场景，返回存活的节点
     * @param allNodes 所有节点
     * @param unreachableNodes 不可达节点
     * @param downedNodes 已下线节点
     * @return SBR 决策
     */
    func resolve(
        allNodes: HashSet<UniqueAddress>,
        unreachableNodes: HashSet<UniqueAddress>,
        downedNodes: HashSet<UniqueAddress>
    ): SBRDecision

    /**
     * 获取当前配置
     * @return 配置
     */
    func getConfig(): SBRConfig

    /**
     * 检查是否需要执行 SBR
     * @param unreachableNodes 不可达节点
     * @return 是否需要
     */
    func shouldResolve(unreachableNodes: HashSet<UniqueAddress>): Bool
}

/**
 * Keep Majority 策略实现
 * 保留多数节点方，少数方节点下线
 */
public class KeepMajorityResolver <: SplitBrainResolver {
    private let config: SBRConfig
    private let nodePriority: HashMap<UniqueAddress, Int64>

    public init(config: SBRConfig) {
        this.config = config
        this.nodePriority = HashMap<UniqueAddress, Int64>()
    }

    public func setNodePriority(address: UniqueAddress, priority: Int64): Unit {
        nodePriority[address] = priority
    }

    public func resolve(
        allNodes: HashSet<UniqueAddress>,
        unreachableNodes: HashSet<UniqueAddress>,
        downedNodes: HashSet<UniqueAddress>
    ): SBRDecision {
        // 计算可达节点 (all - unreachable - downed)
        let reachable = HashSet<UniqueAddress>()
        for (node in allNodes.toArray()) {
            if (!unreachableNodes.contains(node) && !downedNodes.contains(node)) {
                reachable.add(node)
            }
        }

        let reachableCount = reachable.size()
        let totalCount = allNodes.size()
        let halfCount = totalCount / 2

        // 检查是否需要分裂
        if (reachableCount > halfCount) {
            // 多数方，保留所有可达节点，下线不可达节点
            let survivors = reachable
            let victims = unreachableNodes
            return SBRDecision(
                config.strategy,
                survivors,
                victims,
                "KeepMajority: ${reachableCount}/${totalCount} nodes are reachable"
            )
        } else if (reachableCount == halfCount) {
            // 刚好一半，检查节点优先级
            if (config.majorityCanSplit) {
                // 优先级最高的节点存活
                let highest = findHighestPriority(reachable)
                let survivors = HashSet<UniqueAddress>()
                survivors.add(highest)
                let victims = HashSet<UniqueAddress>()
                for (node in reachable.toArray()) {
                    if (!node.equals(highest)) {
                        victims.add(node)
                    }
                }
                for (node in unreachableNodes.toArray()) {
                    victims.add(node)
                }
                return SBRDecision(
                    config.strategy,
                    survivors,
                    victims,
                    "KeepMajority: Tie at ${reachableCount}/${totalCount}, highest priority wins"
                )
            }
        }

        // 少数方，所有节点都下线 (DownAll 行为)
        let survivors = HashSet<UniqueAddress>()
        let victims = allNodes
        SBRDecision(
            config.strategy,
            survivors,
            victims,
            "KeepMajority: ${reachableCount}/${totalCount} not enough, down all"
        )
    }

    public func getConfig(): SBRConfig {
        config
    }

    public func shouldResolve(unreachableNodes: HashSet<UniqueAddress>): Bool {
        unreachableNodes.size() > 0
    }

    private func findHighestPriority(nodes: HashSet<UniqueAddress>): UniqueAddress {
        var highest: Option<UniqueAddress> = None
        var maxPriority: Int64 = -1

        for (node in nodes.toArray()) {
            let priority = match (nodePriority.get(node)) {
                case Some(p) => p
                case None => node.uid  // 使用 uid 作为默认优先级
            }
            if (priority > maxPriority) {
                maxPriority = priority
                highest = Some(node)
            }
        }

        match (highest) {
            case Some(addr) => addr
            case None =>
                // fallback: 返回任意节点
                let arr = nodes.toArray()
                if (arr.size > 0) {
                    arr[0]
                } else {
                    UniqueAddress(Address("", "", "", 0), 0)
                }
        }
    }
}

/**
 * Keep Oldest 策略实现
 * 保留最早加入的节点 (拥有最低 uid)
 */
public class KeepOldestResolver <: SplitBrainResolver {
    private let config: SBRConfig

    public init(config: SBRConfig) {
        this.config = config
    }

    public func resolve(
        allNodes: HashSet<UniqueAddress>,
        unreachableNodes: HashSet<UniqueAddress>,
        downedNodes: HashSet<UniqueAddress>
    ): SBRDecision {
        // 找出最老的节点 (uid 最小)
        var oldest: Option<UniqueAddress> = None
        var minUid: Int64 = Int64.Max

        for (node in allNodes.toArray()) {
            if (node.uid < minUid) {
                minUid = node.uid
                oldest = Some(node)
            }
        }

        match (oldest) {
            case Some(oldestNode) =>
                // 检查最老节点是否可达
                if (!unreachableNodes.contains(oldestNode) && !downedNodes.contains(oldestNode)) {
                    // 保留最老节点，下线其他所有节点
                    let survivors = HashSet<UniqueAddress>()
                    survivors.add(oldestNode)

                    let victims = HashSet<UniqueAddress>()
                    for (node in allNodes.toArray()) {
                        if (!node.equals(oldestNode)) {
                            victims.add(node)
                        }
                    }

                    return SBRDecision(
                        config.strategy,
                        survivors,
                        victims,
                        "KeepOldest: Oldest node ${oldestNode} survives"
                    )
                } else {
                    // 最老节点不可达，下线所有
                    let survivors = HashSet<UniqueAddress>()
                    let victims = allNodes
                    return SBRDecision(
                        config.strategy,
                        survivors,
                        victims,
                        "KeepOldest: Oldest node unreachable, down all"
                    )
                }
            case None =>
                let survivors = HashSet<UniqueAddress>()
                let victims = allNodes
                return SBRDecision(config.strategy, survivors, victims, "KeepOldest: No nodes")
        }
    }

    public func getConfig(): SBRConfig {
        config
    }

    public func shouldResolve(unreachableNodes: HashSet<UniqueAddress>): Bool {
        unreachableNodes.size() > 0
    }
}

/**
 * Static Quorum 策略实现
 * 节点数 >= quorum 时保留，否则全部下线
 */
public class StaticQuorumResolver <: SplitBrainResolver {
    private let config: SBRConfig
    private let quorumSize: Int32

    public init(config: SBRConfig, quorumSize: Int32) {
        this.config = config
        this.quorumSize = quorumSize
    }

    public func resolve(
        allNodes: HashSet<UniqueAddress>,
        unreachableNodes: HashSet<UniqueAddress>,
        downedNodes: HashSet<UniqueAddress>
    ): SBRDecision {
        // 计算可达节点数
        var reachableCount = 0
        for (node in allNodes.toArray()) {
            if (!unreachableNodes.contains(node) && !downedNodes.contains(node)) {
                reachableCount += 1
            }
        }

        if (reachableCount >= Int64(quorumSize)) {
            // 达到 quorum，保留可达节点
            let survivors = HashSet<UniqueAddress>()
            for (node in allNodes.toArray()) {
                if (!unreachableNodes.contains(node) && !downedNodes.contains(node)) {
                    survivors.add(node)
                }
            }
            let victims = unreachableNodes
            return SBRDecision(
                config.strategy,
                survivors,
                victims,
                "StaticQuorum: ${reachableCount}/${quorumSize} >= quorum, keep all reachable"
            )
        } else {
            // 未达到 quorum，下线所有
            let survivors = HashSet<UniqueAddress>()
            let victims = allNodes
            return SBRDecision(
                config.strategy,
                survivors,
                victims,
                "StaticQuorum: ${reachableCount}/${quorumSize} < quorum, down all"
            )
        }
    }

    public func getConfig(): SBRConfig {
        config
    }

    public func shouldResolve(unreachableNodes: HashSet<UniqueAddress>): Bool {
        unreachableNodes.size() > 0
    }
}

/**
 * Down All 策略实现
 * 保守策略：检测到脑裂时关闭所有节点
 */
public class DownAllResolver <: SplitBrainResolver {
    private let config: SBRConfig

    public init(config: SBRConfig) {
        this.config = config
    }

    public func resolve(
        allNodes: HashSet<UniqueAddress>,
        unreachableNodes: HashSet<UniqueAddress>,
        downedNodes: HashSet<UniqueAddress>
    ): SBRDecision {
        // 关闭所有节点
        let survivors = HashSet<UniqueAddress>()
        let victims = allNodes
        SBRDecision(
            config.strategy,
            survivors,
            victims,
            "DownAll: Network partition detected, shutting down all nodes"
        )
    }

    public func getConfig(): SBRConfig {
        config
    }

    public func shouldResolve(unreachableNodes: HashSet<UniqueAddress>): Bool {
        unreachableNodes.size() > 0
    }
}

/**
 * Keep Referee 策略实现
 * 保留 referee 节点，其他节点按多数决定
 */
public class KeepRefereeResolver <: SplitBrainResolver {
    private let config: SBRConfig
    private let referee: UniqueAddress

    public init(config: SBRConfig, referee: UniqueAddress) {
        this.config = config
        this.referee = referee
    }

    public func resolve(
        allNodes: HashSet<UniqueAddress>,
        unreachableNodes: HashSet<UniqueAddress>,
        downedNodes: HashSet<UniqueAddress>
    ): SBRDecision {
        // 检查 referee 是否可达
        let refereeReachable = !unreachableNodes.contains(referee) && !downedNodes.contains(referee)

        if (refereeReachable) {
            // Referee 可达，保留 referee 和所有可达节点
            let survivors = HashSet<UniqueAddress>()
            survivors.add(referee)
            for (node in allNodes.toArray()) {
                if (!unreachableNodes.contains(node) && !downedNodes.contains(node) && !node.equals(referee)) {
                    survivors.add(node)
                }
            }
            let victims = unreachableNodes
            return SBRDecision(
                config.strategy,
                survivors,
                victims,
                "KeepReferee: Referee ${referee} is reachable"
            )
        } else if (!config.refereeCanSplit) {
            // Referee 不可达且不允许分裂，下线所有
            let survivors = HashSet<UniqueAddress>()
            let victims = allNodes
            return SBRDecision(
                config.strategy,
                survivors,
                victims,
                "KeepReferee: Referee unreachable, down all"
            )
        } else {
            // Referee 不可达但允许分裂，使用 KeepMajority
            let totalCount = allNodes.size()
            var reachableCount = 0
            for (node in allNodes.toArray()) {
                if (!unreachableNodes.contains(node) && !downedNodes.contains(node)) {
                    reachableCount += 1
                }
            }

            if (reachableCount > totalCount / 2) {
                let survivors = HashSet<UniqueAddress>()
                for (node in allNodes.toArray()) {
                    if (!unreachableNodes.contains(node) && !downedNodes.contains(node)) {
                        survivors.add(node)
                    }
                }
                let victims = unreachableNodes
                return SBRDecision(
                    config.strategy,
                    survivors,
                    victims,
                    "KeepReferee: Referee unreachable but majority wins"
                )
            } else {
                let survivors = HashSet<UniqueAddress>()
                let victims = allNodes
                return SBRDecision(
                    config.strategy,
                    survivors,
                    victims,
                    "KeepReferee: No majority, down all"
                )
            }
        }
    }

    public func getConfig(): SBRConfig {
        config
    }

    public func shouldResolve(unreachableNodes: HashSet<UniqueAddress>): Bool {
        unreachableNodes.size() > 0
    }
}

/**
 * Split Brain Resolver 工厂
 */
public class SBRResolverFactory {
    /**
     * 创建 KeepMajority Resolver
     */
    public static func createKeepMajority(): SplitBrainResolver {
        KeepMajorityResolver(SBRConfig.getDefault())
    }

    public static func createKeepMajority(config: SBRConfig): SplitBrainResolver {
        KeepMajorityResolver(config)
    }

    /**
     * 创建 KeepOldest Resolver
     */
    public static func createKeepOldest(): SplitBrainResolver {
        KeepOldestResolver(SBRConfig.keepOldest())
    }

    public static func createKeepOldest(config: SBRConfig): SplitBrainResolver {
        KeepOldestResolver(config)
    }

    /**
     * 创建 StaticQuorum Resolver
     */
    public static func createStaticQuorum(quorumSize: Int32): SplitBrainResolver {
        StaticQuorumResolver(SBRConfig.staticQuorum(quorumSize), quorumSize)
    }

    /**
     * 创建 DownAll Resolver
     */
    public static func createDownAll(): SplitBrainResolver {
        DownAllResolver(SBRConfig.downAll())
    }

    /**
     * 创建 KeepReferee Resolver
     */
    public static func createKeepReferee(referee: UniqueAddress): SplitBrainResolver {
        KeepRefereeResolver(SBRConfig.getDefault(), referee)
    }

    /**
     * 根据策略名称创建 Resolver
     */
    public static func createByStrategy(
        strategy: SBRStrategy,
        options: SBRCreateOptions
    ): SplitBrainResolver {
        match (strategy) {
            case SBRStrategy.KeepMajority =>
                createKeepMajority()
            case SBRStrategy.KeepOldest =>
                createKeepOldest()
            case SBRStrategy.StaticQuorum =>
                let quorum = if (options.quorumSize > 0) { options.quorumSize } else { Int32(1) }
                createStaticQuorum(quorum)
            case SBRStrategy.DownAll =>
                createDownAll()
            case SBRStrategy.KeepReferee =>
                if (options.refereeDefined) {
                    createKeepReferee(options.referee)
                } else {
                    createKeepMajority()  // fallback
                }
            case SBRStrategy.KeepMinority =>
                createKeepMajority()  // 简化实现
        }
    }
}

/**
 * SBR 创建选项
 */
public struct SBRCreateOptions {
    public let quorumSize: Int32
    public let refereeDefined: Bool
    public let referee: UniqueAddress

    public init(
        quorumSize!: Int32 = 0,
        referee!: UniqueAddress = UniqueAddress(Address("", "", "", 0), 0),
        refereeDefined!: Bool = false
    ) {
        this.quorumSize = quorumSize
        this.referee = referee
        this.refereeDefined = refereeDefined
    }
}

/**
 * SBR 事件类型
 */
public interface SBREvent {
    func eventType(): String
}

/**
 * SBR 触发事件
 */
public class SBRSplitDetected <: SBREvent {
    public let unreachableNodes: HashSet<UniqueAddress>
    public let timestamp: Int64

    public init(unreachableNodes: HashSet<UniqueAddress>) {
        this.unreachableNodes = unreachableNodes
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func eventType(): String {
        "SBRSplitDetected"
    }
}

/**
 * SBR 决策事件
 */
public class SBRDecisionMade <: SBREvent {
    public let decision: SBRDecision
    public let timestamp: Int64

    public init(decision: SBRDecision) {
        this.decision = decision
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func eventType(): String {
        "SBRDecisionMade"
    }
}

/**
 * SBR 节点下线事件
 */
public class SBRNodeDown <: SBREvent {
    public let node: UniqueAddress
    public let reason: String
    public let timestamp: Int64

    public init(node: UniqueAddress, reason: String) {
        this.node = node
        this.reason = reason
        this.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    public func eventType(): String {
        "SBRNodeDown"
    }
}

/**
 * SBR 事件监听器
 */
public interface SBREventListener {
    func onSBREvent(event: SBREvent): Unit
}

/**
 * SBR 状态追踪器
 */
public class SBRStateTracker {
    private let unreachableSince: HashMap<UniqueAddress, Int64>
    private let downedNodes: HashSet<UniqueAddress>
    private let listeners: ArrayList<SBREventListener>
    private let mutex: Mutex

    public init() {
        this.unreachableSince = HashMap<UniqueAddress, Int64>()
        this.downedNodes = HashSet<UniqueAddress>()
        this.listeners = ArrayList<SBREventListener>()
        this.mutex = Mutex()
    }

    /**
     * 标记节点不可达
     */
    public func markUnreachable(node: UniqueAddress): Unit {
        mutex.lock()
        if (!unreachableSince.contains(node)) {
            unreachableSince[node] = DateTime.now().toUnixTimeStamp().toMilliseconds()
            let unreachableSet = HashSet<UniqueAddress>()
            unreachableSet.add(node)
            publishEvent(SBRSplitDetected(unreachableSet))
        }
        mutex.unlock()
    }

    /**
     * 标记节点恢复可达
     */
    public func markReachable(node: UniqueAddress): Unit {
        mutex.lock()
        unreachableSince.remove(node)
        mutex.unlock()
    }

    /**
     * 标记节点已下线
     */
    public func markDown(node: UniqueAddress, reason: String): Unit {
        mutex.lock()
        unreachableSince.remove(node)
        downedNodes.add(node)
        publishEvent(SBRNodeDown(node, reason))
        mutex.unlock()
    }

    /**
     * 获取不可达节点集合
     */
    public func getUnreachableNodes(): HashSet<UniqueAddress> {
        mutex.lock()
        let result = HashSet<UniqueAddress>()
        for ((node, _) in unreachableSince) {
            result.add(node)
        }
        mutex.unlock()
        result
    }

    /**
     * 获取已下线节点集合
     */
    public func getDownedNodes(): HashSet<UniqueAddress> {
        mutex.lock()
        let result = HashSet<UniqueAddress>()
        for (node in downedNodes.toArray()) {
            result.add(node)
        }
        mutex.unlock()
        result
    }

    /**
     * 检查节点不可达时长
     */
    public func getUnreachableDuration(node: UniqueAddress): Duration {
        mutex.lock()
        let since = match (unreachableSince.get(node)) {
            case Some(ts) => ts
            case None => DateTime.now().toUnixTimeStamp().toMilliseconds()
        }
        mutex.unlock()
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        Duration.millisecond * (now - since)
    }

    /**
     * 添加事件监听器
     */
    public func addListener(listener: SBREventListener): Unit {
        mutex.lock()
        listeners.add(listener)
        mutex.unlock()
    }

    private func publishEvent(event: SBREvent): Unit {
        for (listener in listeners) {
            try {
                listener.onSBREvent(event)
            } catch (e: Exception) {
                // ignore
            }
        }
    }
}
