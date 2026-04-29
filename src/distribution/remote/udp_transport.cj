/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - UDP 传输层实现
 * 提供无连接的 UDP 网络传输
 */
package cactor.distribution.remote

import std.collection.*
import std.sync.*
import std.time.*
import cactor.foundation.network.*

/**
 * UDP 传输层配置
 */
public struct UdpTransportConfig {
    public let host: String
    public let port: Int64
    public let receiveBufferSize: Int64  // 接收缓冲区大小
    public let sendBufferSize: Int64     // 发送缓冲区大小
    public let broadcast: Bool          // 是否启用广播
    public let multicast: Option<String> // 多播地址（可选）
    public let readTimeout: Duration      // 读取超时
    public let writeTimeout: Duration     // 写入超时

    public init(
        host: String,
        port: Int64,
        receiveBufferSize!: Int64 = 65536,
        sendBufferSize!: Int64 = 65536,
        broadcast!: Bool = false,
        multicast!: Option<String> = None,
        readTimeout!: Duration = Duration.second * 10,
        writeTimeout!: Duration = Duration.second * 10
    ) {
        this.host = host
        this.port = port
        this.receiveBufferSize = receiveBufferSize
        this.sendBufferSize = sendBufferSize
        this.broadcast = broadcast
        this.multicast = multicast
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
    }
}

/**
 * UDP 数据包
 */
public struct UdpDatagram {
    public let data: Array<UInt8>
    public let remoteAddress: NetworkAddress
    public let localAddress: NetworkAddress
    public let timestamp: Int64

    public init(
        data: Array<UInt8>,
        remoteAddress: NetworkAddress,
        localAddress: NetworkAddress,
        timestamp!: Int64 = 0
    ) {
        this.data = data
        this.remoteAddress = remoteAddress
        this.localAddress = localAddress
        this.timestamp = if (timestamp == 0) {
            DateTime.now().toUnixTimeStamp()
        } else {
            timestamp
        }
    }
}

/**
 * UDP 数据包事件
 */
public interface UdpDatagramEventHandler {
    /**
     * 接收到数据包事件
     */
    func onDatagramReceived(datagram: UdpDatagram): Unit

    /**
     * 错误事件
     */
    func onError(address: NetworkAddress, error: String): Unit

    /**
     * 发送完成事件
     */
    func onSent(address: NetworkAddress, bytesSent: Int64): Unit
}

/**
 * UDP 套接字
 */
public class UdpSocket {
    private var fd: Int64 = -1  // 文件描述符
    private var boundAddress: Option<NetworkAddress> = None

    public init() { }

    /**
     * 绑定到地址
     */
    public func bind(address: NetworkAddress): Bool {
        // 简化实现
        fd = 1  // 模拟文件描述符
        boundAddress = Some(address)
        return true
    }

    /**
     * 发送数据到指定地址
     */
    public func sendTo(address: NetworkAddress, data: Array<UInt8>): Int64 {
        if (fd < 0) {
            return -1
        }
        // 简化实现，返回发送的字节数
        return Int64(data.size)
    }

    /**
     * 接收数据
     */
    public func receiveFrom(bufferSize: Int64): Option<(Array<UInt8>, NetworkAddress)> {
        if (fd < 0) {
            return None
        }
        // 简化实现，返回空数据
        return None
    }

    /**
     * 加入多播组
     */
    public func joinMulticast(multicastAddress: String): Bool {
        return true
    }

    /**
     * 离开多播组
     */
    public func leaveMulticast(multicastAddress: String): Bool {
        return true
    }

    /**
     * 设置广播模式
     */
    public func setBroadcast(enabled: Bool): Bool {
        return true
    }

    /**
     * 设置选项
     */
    public func setOption(name: String, value: Bool): Bool {
        return true
    }

    /**
     * 关闭
     */
    public func close(): Unit {
        if (fd >= 0) {
            fd = -1
        }
        boundAddress = None
    }

    /**
     * 获取绑定地址
     */
    public func getBoundAddress(): Option<NetworkAddress> {
        return boundAddress
    }
}

/**
 * UDP 端点统计
 */
public struct UdpEndpointStats {
    public let address: NetworkAddress
    public let packetsSent: Int64
    public let packetsReceived: Int64
    public let bytesSent: Int64
    public let bytesReceived: Int64
    public let lastActivity: Int64
    public let isActive: Bool

    public init(
        address: NetworkAddress,
        packetsSent!: Int64 = 0,
        packetsReceived!: Int64 = 0,
        bytesSent!: Int64 = 0,
        bytesReceived!: Int64 = 0,
        lastActivity!: Int64 = 0,
        isActive!: Bool = true
    ) {
        this.address = address
        this.packetsSent = packetsSent
        this.packetsReceived = packetsReceived
        this.bytesSent = bytesSent
        this.bytesReceived = bytesReceived
        this.lastActivity = lastActivity
        this.isActive = isActive
    }
}

/**
 * UDP 传输层
 */
public class UdpTransport {
    private let config: UdpTransportConfig
    private var socket: UdpSocket
    private var eventHandler: Option<UdpDatagramEventHandler>
    private var isRunning: Bool
    private var receiveTask: Option<Future<Unit>>
    private let endpoints: HashMap<String, UdpEndpointStats>
    private let lock: ReentrantReadWriteMutex

    public init(config: UdpTransportConfig) {
        this.config = config
        this.socket = UdpSocket()
        this.eventHandler = None
        this.isRunning = false
        this.receiveTask = None
        this.endpoints = HashMap<String, UdpEndpointStats>()
        this.lock = ReentrantReadWriteMutex()
    }

    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: UdpDatagramEventHandler): Unit {
        try {
            lock.writeMutex.lock()
            eventHandler = Some(handler)
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 启动传输层
     */
    public func start(): Bool {
        try {
            lock.writeMutex.lock()
            

            if (isRunning) {
                return true
            }

            // 创建并绑定套接字
            let address = NetworkAddress(config.host, config.port)
            if (!socket.bind(address)) {
                return false
            }

            // 设置广播模式
            if (config.broadcast) {
                socket.setBroadcast(true)
            }

            // 加入多播组
            match (config.multicast) {
                case Some(maddr) =>
                    socket.joinMulticast(maddr)
                case None => ()
            }

            isRunning = true

            // 启动接收任务
            receiveTask = Some(spawn {
                this.receiveLoop()
            })

            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * 停止传输层
     */
    public func stop(): Unit {
        try {
            lock.writeMutex.lock()
            isRunning = false
            receiveTask = None
            socket.close()
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 接收循环
     */
    private func receiveLoop(): Unit {
        while (isRunning) {
            try {
                match (socket.receiveFrom(config.receiveBufferSize)) {
                    case Some((data, remoteAddr)) =>
                        let localAddr = socket.getBoundAddress().getOrThrow()
                        let datagram = UdpDatagram(data, remoteAddr, localAddr)

                        // 更新统计
                        updateEndpointStats(remoteAddr, received: Int64(data.size))

                        // 触发事件
                        match (eventHandler) {
                            case Some(handler) => handler.onDatagramReceived(datagram)
                            case None => ()
                        }
                    case None =>
                        ()
                }
            } catch (e: Exception) {
                match (eventHandler) {
                    case Some(handler) => handler.onError(NetworkAddress("unknown", 0), e.getMessage())
                    case None => ()
                }
                ()
            }
        }
    }

    /**
     * 发送数据到指定地址
     */
    public func sendTo(address: NetworkAddress, data: Array<UInt8>): Bool {
        try {
            lock.readMutex.lock()
            if (!isRunning) {
                lock.readMutex.unlock()
                return false
            }
            lock.readMutex.unlock()

            let sent = socket.sendTo(address, data)
            if (sent > 0) {
                // 更新统计
                updateEndpointStats(address, sent: sent)

                match (eventHandler) {
                    case Some(handler) => handler.onSent(address, sent)
                    case None => ()
                }
                return true
            }
            return false
        } catch (e: Exception) {
            match (eventHandler) {
                case Some(handler) => handler.onError(address, e.getMessage())
                case None => ()
            }
            return false
        }
    }

    /**
     * 广播数据
     */
    public func broadcast(data: Array<UInt8>, broadcastAddress: NetworkAddress): Bool {
        if (!config.broadcast) {
            return false
        }
        return sendTo(broadcastAddress, data)
    }

    /**
     * 发送数据到多个地址
     */
    public func multicast(addresses: Array<NetworkAddress>, data: Array<UInt8>): Int64 {
        var successCount: Int64 = 0
        for (addr in addresses) {
            if (sendTo(addr, data)) {
                successCount += 1
            }
        }
        return successCount
    }

    /**
     * 更新端点统计
     */
    private func updateEndpointStats(
        address: NetworkAddress,
        sent!: Int64 = 0,
        received!: Int64 = 0
    ): Unit {
        try {
            lock.writeMutex.lock()
            let addrKey = address.toString()
            match (endpoints.get(addrKey)) {
                case Some(stats) =>
                    let updated = UdpEndpointStats(
                        address,
                        packetsSent: stats.packetsSent + if (sent > 0) { 1 } else { 0 },
                        packetsReceived: stats.packetsReceived + if (received > 0) { 1 } else { 0 },
                        bytesSent: stats.bytesSent + sent,
                        bytesReceived: stats.bytesReceived + received,
                        lastActivity: DateTime.now().toUnixTimeStamp(),
                        isActive: true
                    )
                    endpoints.add(addrKey, updated)
                case None =>
                    let stats = UdpEndpointStats(
                        address,
                        packetsSent: if (sent > 0) { 1 } else { 0 },
                        packetsReceived: if (received > 0) { 1 } else { 0 },
                        bytesSent: sent,
                        bytesReceived: received,
                        lastActivity: DateTime.now().toUnixTimeStamp(),
                        isActive: true
                    )
                    endpoints.add(addrKey, stats)
            }
            lock.writeMutex.unlock()
        } catch (e: Exception) {
            // ignore
        }
    }

    /**
     * 获取端点统计
     */
    public func getEndpointStats(address: NetworkAddress): Option<UdpEndpointStats> {
        try {
            lock.readMutex.lock()
            
            return endpoints.get(address.toString())
        } catch (e: Exception) {
            return None
        }
    }

    /**
     * 获取所有端点统计
     */
    public func getAllEndpointStats(): Array<UdpEndpointStats> {
        try {
            lock.readMutex.lock()
            
            let result = ArrayList<UdpEndpointStats>()
            for ((_, stats) in endpoints) {
                result.add(stats)
            }
            return result.toArray()
        } catch (e: Exception) {
            return Array<UdpEndpointStats>()
        }
    }

    /**
     * 获取总发送字节数
     */
    public func getTotalBytesSent(): Int64 {
        try {
            lock.readMutex.lock()
            
            var total: Int64 = 0
            for ((_, stats) in endpoints) {
                total += stats.bytesSent
            }
            return total
        } catch (e: Exception) {
            return 0
        }
    }

    /**
     * 获取总接收字节数
     */
    public func getTotalBytesReceived(): Int64 {
        try {
            lock.readMutex.lock()
            
            var total: Int64 = 0
            for ((_, stats) in endpoints) {
                total += stats.bytesReceived
            }
            return total
        } catch (e: Exception) {
            return 0
        }
    }

    /**
     * 获取活跃端点数
     */
    public func getActiveEndpointCount(): Int64 {
        try {
            lock.readMutex.lock()
            
            var count: Int64 = 0
            for ((_, stats) in endpoints) {
                if (stats.isActive) {
                    count += 1
                }
            }
            return count
        } catch (e: Exception) {
            return 0
        }
    }

    /**
     * 检查是否运行中
     */
    public func isActive(): Bool {
        try {
            lock.readMutex.lock()
            return isRunning
        } catch (e: Exception) {
            return false
        }
    }
}

/**
 * 创建 UDP 传输层
 */
public func createUdpTransport(host: String, port: Int64): UdpTransport {
    let config = UdpTransportConfig(host, port)
    return UdpTransport(config)
}

/**
 * 创建 UDP 广播传输层
 */
public func createUdpBroadcastTransport(host: String, port: Int64): UdpTransport {
    let config = UdpTransportConfig(host, port, broadcast: true)
    return UdpTransport(config)
}
