/*
 * Copyright (c) 2024. All rights reserved.
 * CACtor 2.0 - Ping Pong 示例
 * 展示基础Actor通信功能
 */
package cactor.examples.ping_pong

import std.sync.*
import std.time.*
import cactor.*

/**
 * Ping Actor - 发送ping消息
 */
public class PingActor {
    private let actorName: String
    private let isRunning: AtomicBool
    private var pongActor: Option<PongActor>

    public init(name: String) {
        this.actorName = name
        this.isRunning = AtomicBool(false)
        this.pongActor = None
    }

    public func getName(): String {
        actorName
    }

    public func setPongActor(pong: PongActor): Unit {
        this.pongActor = Some(pong)
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("${actorName} 启动")
            spawn {
                run()
            }
        }
    }

    public func stop(): Unit {
        isRunning.store(false)
        println("${actorName} 停止")
    }

    public func ping(count: Int32): Unit {
        if (isRunning.load()) {
            match (pongActor) {
                case Some(pong) =>
                    println("${actorName} 发送 Ping #${count}")
                    pong.pong(count)
                case None =>
                    println("${actorName} 错误: 没有设置PongActor")
            }
        }
    }

    private func run(): Unit {
        println("${actorName} 开始运行")
        
        // 发送5次ping
        for (i in 1..6) {
            if (!isRunning.load()) {
                break
            }
            ping(Int32(i))
            sleep(Duration.millisecond * 500)
        }
        
        println("${actorName} 完成所有ping")
        stop()
    }
}

/**
 * Pong Actor - 响应ping消息
 */
public class PongActor {
    private let actorName: String
    private let isRunning: AtomicBool
    private var pingActor: Option<PingActor>

    public init(name: String) {
        this.actorName = name
        this.isRunning = AtomicBool(false)
        this.pingActor = None
    }

    public func getName(): String {
        actorName
    }

    public func setPingActor(ping: PingActor): Unit {
        this.pingActor = Some(ping)
    }

    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("${actorName} 启动")
            spawn {
                run()
            }
        }
    }

    public func stop(): Unit {
        isRunning.store(false)
        println("${actorName} 停止")
    }

    public func pong(count: Int32): Unit {
        if (isRunning.load()) {
            println("${actorName} 收到 Ping #${count}, 回复 Pong #${count}")
            
            // 模拟处理时间
            sleep(Duration.millisecond * 100)
            
            if (count < 5) {
                match (pingActor) {
                    case Some(ping) =>
                        // 延迟一点再回复，模拟异步处理
                        spawn {
                            sleep(Duration.millisecond * 200)
                            ping.ping(count + 1)
                        }
                    case None =>
                        println("${actorName} 错误: 没有设置PingActor")
                }
            } else {
                println("${actorName} 完成所有pong")
                stop()
            }
        }
    }

    private func run(): Unit {
        println("${actorName} 开始运行，等待ping消息...")
        
        while (isRunning.load()) {
            sleep(Duration.millisecond * 100)
        }
        
        println("${actorName} 运行结束")
    }
}

/**
 * 主函数 - 演示Ping Pong通信
 */
main() {
    println("=== CACtor 2.0 Ping Pong 示例 ===")
    
    // 创建Actor系统
    let system = CActorSystem.create("ping-pong-system")
    println("Actor系统创建: ${system.getName()}")
    
    // 创建Ping和Pong Actor
    let pingActor = PingActor("PingActor")
    let pongActor = PongActor("PongActor")
    
    // 设置相互引用
    pingActor.setPongActor(pongActor)
    pongActor.setPingActor(pingActor)
    
    // 启动Actor
    pongActor.start()
    sleep(Duration.millisecond * 100)  // 确保pong先启动
    
    pingActor.start()
    
    // 等待通信完成
    println("等待Ping Pong通信完成...")
    sleep(Duration.second * 5)
    
    // 清理
    pingActor.stop()
    pongActor.stop()
    system.terminate()
    
    println("=== Ping Pong 示例完成 ===")
}
