/*
 * CActor 3.0 - 高级宏DSL示例
 * Phase 1: 宏驱动的Actor DSL系统 - 高级功能演示
 */
package cactor.examples

import cactor.macros.*
import cactor.dsl.*
import cactor.core.actor.*
import cactor.core.message.*
import cactor.core.context.*

// 复杂的业务Actor - 用户管理系统
@monitored
struct UserManagerActor {
    var users: HashMap<String, UserInfo> = HashMap<String, UserInfo>()
    var totalUsers: Int64 = 0
    var lastOperationTime: Int64 = 0
    
    @handler
    func createUser(msg: CreateUserMessage): UserCreatedResponse {
        let user = UserInfo(msg.userId, msg.name, msg.email)
        users.put(msg.userId, user)
        totalUsers += 1
        lastOperationTime = getCurrentTimeMillis()
        
        println("用户已创建: ${msg.name} (${msg.userId})")
        return UserCreatedResponse(msg.userId, true)
    }
    
    @handler
    func updateUser(msg: UpdateUserMessage): UserUpdatedResponse {
        match (users.get(msg.userId)) {
            case Some(user) =>
                let updatedUser = UserInfo(msg.userId, msg.newName, msg.newEmail)
                users.put(msg.userId, updatedUser)
                lastOperationTime = getCurrentTimeMillis()
                
                println("用户已更新: ${msg.newName} (${msg.userId})")
                return UserUpdatedResponse(msg.userId, true)
            case None =>
                println("用户不存在: ${msg.userId}")
                return UserUpdatedResponse(msg.userId, false)
        }
    }
    
    @handler
    func deleteUser(msg: DeleteUserMessage): UserDeletedResponse {
        match (users.remove(msg.userId)) {
            case Some(user) =>
                totalUsers -= 1
                lastOperationTime = getCurrentTimeMillis()
                
                println("用户已删除: ${user.name} (${msg.userId})")
                return UserDeletedResponse(msg.userId, true)
            case None =>
                println("用户不存在: ${msg.userId}")
                return UserDeletedResponse(msg.userId, false)
        }
    }
    
    @handler
    func getUser(msg: GetUserMessage): GetUserResponse {
        match (users.get(msg.userId)) {
            case Some(user) =>
                println("获取用户信息: ${user.name} (${msg.userId})")
                return GetUserResponse(Some(user))
            case None =>
                println("用户不存在: ${msg.userId}")
                return GetUserResponse(None<UserInfo>)
        }
    }
    
    @handler
    func getUserStats(msg: GetUserStatsMessage): UserStatsResponse {
        println("用户统计: 总用户数 ${totalUsers}, 最后操作时间 ${lastOperationTime}")
        return UserStatsResponse(totalUsers, users.size, lastOperationTime)
    }
}

// 高性能计算Actor
@monitored
struct ComputeActor {
    var computationCount: Int64 = 0
    var totalComputeTime: Int64 = 0
    
    @handler
    func fibonacci(msg: FibonacciMessage): FibonacciResponse {
        let startTime = getCurrentTimeMillis()
        let result = calculateFibonacci(msg.n)
        let endTime = getCurrentTimeMillis()
        
        computationCount += 1
        totalComputeTime += (endTime - startTime)
        
        println("计算斐波那契数列 F(${msg.n}) = ${result}, 耗时: ${endTime - startTime}ms")
        return FibonacciResponse(msg.n, result)
    }
    
    @handler
    func primeCheck(msg: PrimeCheckMessage): PrimeCheckResponse {
        let startTime = getCurrentTimeMillis()
        let isPrime = checkPrime(msg.number)
        let endTime = getCurrentTimeMillis()
        
        computationCount += 1
        totalComputeTime += (endTime - startTime)
        
        println("质数检查 ${msg.number}: ${isPrime}, 耗时: ${endTime - startTime}ms")
        return PrimeCheckResponse(msg.number, isPrime)
    }
    
    @handler
    func getComputeStats(msg: GetComputeStatsMessage): ComputeStatsResponse {
        let avgTime = if (computationCount > 0) { totalComputeTime / computationCount } else { 0 }
        println("计算统计: 计算次数 ${computationCount}, 平均耗时 ${avgTime}ms")
        return ComputeStatsResponse(computationCount, totalComputeTime, avgTime)
    }
}

// 数据结构定义
public struct UserInfo {
    public let userId: String
    public let name: String
    public let email: String
    
    public init(userId: String, name: String, email: String) {
        this.userId = userId
        this.name = name
        this.email = email
    }
    
    public func toString(): String {
        return "UserInfo(${userId}, ${name}, ${email})"
    }
}

// 用户管理消息类型
public class CreateUserMessage <: Message {
    public let userId: String
    public let name: String
    public let email: String
    
    public init(userId: String, name: String, email: String) {
        this.userId = userId
        this.name = name
        this.email = email
    }
    
    public func getMessageType(): String { return "createuser" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class UpdateUserMessage <: Message {
    public let userId: String
    public let newName: String
    public let newEmail: String
    
    public init(userId: String, newName: String, newEmail: String) {
        this.userId = userId
        this.newName = newName
        this.newEmail = newEmail
    }
    
    public func getMessageType(): String { return "updateuser" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class DeleteUserMessage <: Message {
    public let userId: String
    
    public init(userId: String) {
        this.userId = userId
    }
    
    public func getMessageType(): String { return "deleteuser" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class GetUserMessage <: Message {
    public let userId: String
    
    public init(userId: String) {
        this.userId = userId
    }
    
    public func getMessageType(): String { return "getuser" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class GetUserStatsMessage <: Message {
    public init() {}
    
    public func getMessageType(): String { return "getuserstats" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

// 计算消息类型
public class FibonacciMessage <: Message {
    public let n: Int64
    
    public init(n: Int64) {
        this.n = n
    }
    
    public func getMessageType(): String { return "fibonacci" }
    public func getPriority(): Int32 { return 2 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class PrimeCheckMessage <: Message {
    public let number: Int64
    
    public init(number: Int64) {
        this.number = number
    }
    
    public func getMessageType(): String { return "primecheck" }
    public func getPriority(): Int32 { return 2 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class GetComputeStatsMessage <: Message {
    public init() {}
    
    public func getMessageType(): String { return "getcomputestats" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

// 响应消息类型（简化定义）
public class UserCreatedResponse <: Message {
    public let userId: String
    public let success: Bool
    
    public init(userId: String, success: Bool) {
        this.userId = userId
        this.success = success
    }
    
    public func getMessageType(): String { return "usercreatedresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class UserUpdatedResponse <: Message {
    public let userId: String
    public let success: Bool
    
    public init(userId: String, success: Bool) {
        this.userId = userId
        this.success = success
    }
    
    public func getMessageType(): String { return "userupdatedresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class UserDeletedResponse <: Message {
    public let userId: String
    public let success: Bool
    
    public init(userId: String, success: Bool) {
        this.userId = userId
        this.success = success
    }
    
    public func getMessageType(): String { return "userdeletedresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class GetUserResponse <: Message {
    public let user: Option<UserInfo>
    
    public init(user: Option<UserInfo>) {
        this.user = user
    }
    
    public func getMessageType(): String { return "getuserresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class UserStatsResponse <: Message {
    public let totalUsers: Int64
    public let activeUsers: Int64
    public let lastOperationTime: Int64
    
    public init(totalUsers: Int64, activeUsers: Int64, lastOperationTime: Int64) {
        this.totalUsers = totalUsers
        this.activeUsers = activeUsers
        this.lastOperationTime = lastOperationTime
    }
    
    public func getMessageType(): String { return "userstatsresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class FibonacciResponse <: Message {
    public let n: Int64
    public let result: Int64
    
    public init(n: Int64, result: Int64) {
        this.n = n
        this.result = result
    }
    
    public func getMessageType(): String { return "fibonacciresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class PrimeCheckResponse <: Message {
    public let number: Int64
    public let isPrime: Bool
    
    public init(number: Int64, isPrime: Bool) {
        this.number = number
        this.isPrime = isPrime
    }
    
    public func getMessageType(): String { return "primecheckresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

public class ComputeStatsResponse <: Message {
    public let computationCount: Int64
    public let totalComputeTime: Int64
    public let averageComputeTime: Int64
    
    public init(computationCount: Int64, totalComputeTime: Int64, averageComputeTime: Int64) {
        this.computationCount = computationCount
        this.totalComputeTime = totalComputeTime
        this.averageComputeTime = averageComputeTime
    }
    
    public func getMessageType(): String { return "computestatsresponse" }
    public func getPriority(): Int32 { return 1 }
    public func getTimestamp(): Int64 { return getCurrentTimeMillis() }
}

// 辅助计算函数
func calculateFibonacci(n: Int64): Int64 {
    if (n <= 1) {
        return n
    }
    return calculateFibonacci(n - 1) + calculateFibonacci(n - 2)
}

func checkPrime(n: Int64): Bool {
    if (n <= 1) {
        return false
    }
    if (n <= 3) {
        return true
    }
    if (n % 2 == 0 || n % 3 == 0) {
        return false
    }
    
    var i = 5
    while (i * i <= n) {
        if (n % i == 0 || n % (i + 2) == 0) {
            return false
        }
        i += 6
    }
    return true
}

func getCurrentTimeMillis(): Int64 {
    // 简化实现，实际应该调用系统时间API
    return 1000
}
