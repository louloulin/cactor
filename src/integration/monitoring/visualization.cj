/*
 * Copyright (c) 2024. All rights reserved.
 * CActor 3.0 - 可视化监控界面
 * 基于plan3.md设计的实时监控可视化系统
 */
package cactor.integration.monitoring

import std.sync.*
import std.time.*
import std.collection.*
import std.collection.concurrent.*
import cactor.core.actor.*

// 监控数据点
public struct DataPoint {
    public let timestamp: Int64
    public let value: Float64
    public let label: String
    
    public init(timestamp: Int64, value: Float64, label: String) {
        this.timestamp = timestamp
        this.value = value
        this.label = label
    }
    
    public func toString(): String {
        "DataPoint(${timestamp}, ${value}, ${label})"
    }
}

// 时间序列数据
public class TimeSeries {
    public let name: String
    private let dataPoints: ArrayList<DataPoint>
    private let maxPoints: Int64
    private let mutex: ReentrantMutex
    
    public init(name: String, maxPoints: Int64) {
        this.name = name
        this.dataPoints = ArrayList<DataPoint>()
        this.maxPoints = maxPoints
        this.mutex = ReentrantMutex()
    }
    
    public func addDataPoint(value: Float64, label: String): Unit {
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let point = DataPoint(timestamp, value, label)

        mutex.lock()
        if (dataPoints.size >= maxPoints) {
            // 移除最老的数据点 - 简化实现：清空并重新添加
            let newPoints = ArrayList<DataPoint>()
            for (i in 1..dataPoints.size) {
                newPoints.append(dataPoints[i])
            }
            dataPoints.clear()
            for (p in newPoints) {
                dataPoints.append(p)
            }
        }
        dataPoints.append(point)
        mutex.unlock()
    }
    
    public func getDataPoints(): Array<DataPoint> {
        mutex.lock()
        let result = dataPoints.toArray()
        mutex.unlock()
        return result
    }
    
    public func getLatestValue(): Option<Float64> {
        mutex.lock()
        let result = if (dataPoints.size > 0) {
            Some(dataPoints[dataPoints.size - 1].value)
        } else {
            None<Float64>
        }
        mutex.unlock()
        return result
    }
    
    public func clear(): Unit {
        mutex.lock()
        dataPoints.clear()
        mutex.unlock()
    }
    
    public func size(): Int64 {
        mutex.lock()
        let result = dataPoints.size
        mutex.unlock()
        return result
    }
}

// 仪表板组件类型
public enum DashboardComponentType {
    | LineChart
    | BarChart
    | Gauge
    | Table
    | Counter
    
    public func toString(): String {
        match (this) {
            case LineChart => "LineChart"
            case BarChart => "BarChart"
            case Gauge => "Gauge"
            case Table => "Table"
            case Counter => "Counter"
        }
    }
}

// 仪表板组件
public class DashboardComponent {
    public let id: String
    public let title: String
    public let componentType: DashboardComponentType
    private let timeSeries: ArrayList<TimeSeries>
    private let config: HashMap<String, String>
    private let mutex: ReentrantMutex
    
    public init(id: String, title: String, componentType: DashboardComponentType) {
        this.id = id
        this.title = title
        this.componentType = componentType
        this.timeSeries = ArrayList<TimeSeries>()
        this.config = HashMap<String, String>()
        this.mutex = ReentrantMutex()
    }
    
    public func addTimeSeries(series: TimeSeries): Unit {
        mutex.lock()
        timeSeries.append(series)
        mutex.unlock()
    }
    
    public func removeTimeSeries(name: String): Unit {
        mutex.lock()
        let newTimeSeries = ArrayList<TimeSeries>()
        for (series in timeSeries) {
            if (series.name != name) {
                newTimeSeries.append(series)
            }
        }
        timeSeries.clear()
        for (series in newTimeSeries) {
            timeSeries.append(series)
        }
        mutex.unlock()
    }
    
    public func getTimeSeries(): Array<TimeSeries> {
        mutex.lock()
        let result = timeSeries.toArray()
        mutex.unlock()
        return result
    }
    
    public func setConfig(key: String, value: String): Unit {
        mutex.lock()
        config[key] = value
        mutex.unlock()
    }
    
    public func getConfig(key: String): Option<String> {
        mutex.lock()
        let result = config.get(key)
        mutex.unlock()
        return result
    }
    
    public func renderAsText(): String {
        mutex.lock()
        var output = "=== ${title} (${componentType.toString()}) ===\n"
        
        for (series in timeSeries) {
            output += "时间序列: ${series.name}\n"
            let points = series.getDataPoints()
            let recentPoints = if (points.size > 5) {
                // 只显示最近5个数据点
                let startIndex = points.size - 5
                let result = ArrayList<DataPoint>()
                for (i in startIndex..points.size) {
                    result.append(points[i])
                }
                result.toArray()
            } else {
                points
            }

            for (point in recentPoints) {
                output = output + "  ${point.timestamp}: ${point.value} (${point.label})\n"
            }
        }
        
        mutex.unlock()
        return output
    }
}

// 监控仪表板
public class MonitoringDashboard {
    public let name: String
    private let components: HashMap<String, DashboardComponent>
    private let updateInterval: Int64  // 毫秒
    private let isRunning: AtomicBool
    private let mutex: ReentrantMutex
    
    public init(name: String, updateInterval: Int64) {
        this.name = name
        this.components = HashMap<String, DashboardComponent>()
        this.updateInterval = updateInterval
        this.isRunning = AtomicBool(false)
        this.mutex = ReentrantMutex()
    }
    
    public func addComponent(component: DashboardComponent): Unit {
        mutex.lock()
        components[component.id] = component
        mutex.unlock()
        println("添加仪表板组件: ${component.title}")
    }
    
    public func removeComponent(componentId: String): Unit {
        mutex.lock()
        components.remove(componentId)
        mutex.unlock()
        println("移除仪表板组件: ${componentId}")
    }
    
    public func getComponent(componentId: String): Option<DashboardComponent> {
        mutex.lock()
        let result = components.get(componentId)
        mutex.unlock()
        return result
    }
    
    public func getAllComponents(): Array<DashboardComponent> {
        mutex.lock()
        let result = ArrayList<DashboardComponent>()
        for ((_, component) in components) {
            result.append(component)
        }
        mutex.unlock()
        return result.toArray()
    }
    
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("监控仪表板启动: ${name}")
            // 这里可以启动后台更新线程
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("监控仪表板停止: ${name}")
        }
    }
    
    public func renderDashboard(): String {
        mutex.lock()
        var output = """
        ==========================================
        CActor 监控仪表板: ${name}
        更新时间: ${DateTime.now().toString()}
        ==========================================
        
        """
        
        for ((_, component) in components) {
            output += component.renderAsText()
            output += "\n"
        }
        
        output += "=========================================="
        mutex.unlock()
        return output
    }
    
    public func getComponentCount(): Int64 {
        mutex.lock()
        let count = components.size
        mutex.unlock()
        return count
    }
    
    public func isActive(): Bool {
        isRunning.load()
    }
}

// 监控可视化管理器
public class VisualizationManager {
    private let dashboards: HashMap<String, MonitoringDashboard>
    private let performanceAnalyzer: SystemPerformanceAnalyzer
    private let distributedTracer: DistributedTracer
    private let mutex: ReentrantMutex
    private let isRunning: AtomicBool
    
    public init(performanceAnalyzer: SystemPerformanceAnalyzer, distributedTracer: DistributedTracer) {
        this.dashboards = HashMap<String, MonitoringDashboard>()
        this.performanceAnalyzer = performanceAnalyzer
        this.distributedTracer = distributedTracer
        this.mutex = ReentrantMutex()
        this.isRunning = AtomicBool(false)
        
        // 创建默认仪表板
        createDefaultDashboards()
    }
    
    private func createDefaultDashboards(): Unit {
        // 系统概览仪表板
        let systemDashboard = MonitoringDashboard("系统概览", 5000)
        
        // Actor性能组件
        let actorComponent = DashboardComponent("actor_perf", "Actor性能", DashboardComponentType.LineChart)
        let actorSeries = TimeSeries("活跃Actor数量", 100)
        actorComponent.addTimeSeries(actorSeries)
        systemDashboard.addComponent(actorComponent)
        
        // 消息处理组件
        let messageComponent = DashboardComponent("message_perf", "消息处理性能", DashboardComponentType.BarChart)
        let messageSeries = TimeSeries("消息处理延迟", 100)
        messageComponent.addTimeSeries(messageSeries)
        systemDashboard.addComponent(messageComponent)
        
        // 系统资源组件
        let resourceComponent = DashboardComponent("system_resources", "系统资源", DashboardComponentType.Gauge)
        let memorySeries = TimeSeries("内存使用率", 100)
        resourceComponent.addTimeSeries(memorySeries)
        systemDashboard.addComponent(resourceComponent)
        
        addDashboard(systemDashboard)
        
        // 分布式追踪仪表板
        let tracingDashboard = MonitoringDashboard("分布式追踪", 3000)
        
        let traceComponent = DashboardComponent("trace_overview", "追踪概览", DashboardComponentType.Table)
        let traceSeries = TimeSeries("活跃Span数量", 50)
        traceComponent.addTimeSeries(traceSeries)
        tracingDashboard.addComponent(traceComponent)
        
        addDashboard(tracingDashboard)
    }
    
    public func addDashboard(dashboard: MonitoringDashboard): Unit {
        mutex.lock()
        dashboards[dashboard.name] = dashboard
        mutex.unlock()
        println("添加监控仪表板: ${dashboard.name}")
    }
    
    public func removeDashboard(name: String): Unit {
        mutex.lock()
        match (dashboards.get(name)) {
            case Some(dashboard) =>
                dashboard.stop()
                dashboards.remove(name)
                println("移除监控仪表板: ${name}")
            case None =>
                println("仪表板不存在: ${name}")
        }
        mutex.unlock()
    }
    
    public func getDashboard(name: String): Option<MonitoringDashboard> {
        mutex.lock()
        let result = dashboards.get(name)
        mutex.unlock()
        return result
    }
    
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("可视化管理器启动")
            
            // 启动所有仪表板
            mutex.lock()
            for ((_, dashboard) in dashboards) {
                dashboard.start()
            }
            mutex.unlock()
        }
    }
    
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("可视化管理器停止")
            
            // 停止所有仪表板
            mutex.lock()
            for ((_, dashboard) in dashboards) {
                dashboard.stop()
            }
            mutex.unlock()
        }
    }
    
    public func updateMetrics(): Unit {
        // 更新系统指标到仪表板
        let actorCount = Float64(performanceAnalyzer.getActiveActorCount())
        let spanCount = Float64(distributedTracer.getActiveSpanCount())
        
        // 更新系统概览仪表板
        match (getDashboard("系统概览")) {
            case Some(dashboard) =>
                match (dashboard.getComponent("actor_perf")) {
                    case Some(component) =>
                        let series = component.getTimeSeries()
                        if (series.size > 0) {
                            series[0].addDataPoint(actorCount, "活跃Actor")
                        }
                    case None =>
                        println("Actor性能组件不存在")
                }
            case None =>
                println("系统概览仪表板不存在")
        }
        
        // 更新分布式追踪仪表板
        match (getDashboard("分布式追踪")) {
            case Some(dashboard) =>
                match (dashboard.getComponent("trace_overview")) {
                    case Some(component) =>
                        let series = component.getTimeSeries()
                        if (series.size > 0) {
                            series[0].addDataPoint(spanCount, "活跃Span")
                        }
                    case None =>
                        println("追踪概览组件不存在")
                }
            case None =>
                println("分布式追踪仪表板不存在")
        }
    }
    
    public func renderAllDashboards(): String {
        var output = ""
        
        mutex.lock()
        for ((_, dashboard) in dashboards) {
            output += dashboard.renderDashboard()
            output += "\n\n"
        }
        mutex.unlock()
        
        return output
    }
    
    public func getDashboardCount(): Int64 {
        mutex.lock()
        let count = dashboards.size
        mutex.unlock()
        return count
    }
    
    public func isActive(): Bool {
        isRunning.load()
    }
}
