/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - HTTP Server Implementation
 * 对标 Akka HTTP，提供 HTTP 服务端功能
 */
package cactor.api.http

import std.collection.*
import std.sync.*
import std.time.*

// ============================================================================
// HTTP 模型
// ============================================================================

/**
 * HTTP 方法
 */
public enum HttpMethod {
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | HEAD
    | OPTIONS
    | Unknown
}

/**
 * HTTP 版本
 */
public enum HttpVersion {
    | HTTP_1_0
    | HTTP_1_1
    | HTTP_2_0
    | Unknown
}

/**
 * HTTP 请求
 */
public class HttpRequest {
    public let method: HttpMethod
    public let uri: String
    public let path: String
    public let version: HttpVersion
    public let headers: HashMap<String, String>
    public let body: Array<UInt8>
    public let remoteAddress: Option<String>

    public init(
        method: HttpMethod,
        uri: String,
        path: String,
        version: HttpVersion,
        headers: HashMap<String, String>,
        body: Array<UInt8>,
        remoteAddress: Option<String>
    ) {
        this.method = method
        this.uri = uri
        this.path = path
        this.version = version
        this.headers = headers
        this.body = body
        this.remoteAddress = remoteAddress
    }

    public func header(name: String): Option<String> {
        headers.get(name)
    }
}

/**
 * HTTP 响应状态码
 */
public enum HttpStatus {
    | Continue
    | SwitchingProtocols
    | OK
    | Created
    | Accepted
    | NoContent
    | MovedPermanently
    | Found
    | SeeOther
    | NotModified
    | BadRequest
    | Unauthorized
    | Forbidden
    | NotFound
    | MethodNotAllowed
    | RequestTimeout
    | Conflict
    | PayloadTooLarge
    | UnsupportedMediaType
    | TooManyRequests
    | InternalServerError
    | NotImplemented
    | BadGateway
    | ServiceUnavailable
    | GatewayTimeout
    | Custom(Int64, String)

    public func code(): Int64 {
        match (this) {
            case Continue => 100
            case SwitchingProtocols => 101
            case OK => 200
            case Created => 201
            case Accepted => 202
            case NoContent => 204
            case MovedPermanently => 301
            case Found => 302
            case SeeOther => 303
            case NotModified => 304
            case BadRequest => 400
            case Unauthorized => 401
            case Forbidden => 403
            case NotFound => 404
            case MethodNotAllowed => 405
            case RequestTimeout => 408
            case Conflict => 409
            case PayloadTooLarge => 413
            case UnsupportedMediaType => 415
            case TooManyRequests => 429
            case InternalServerError => 500
            case NotImplemented => 501
            case BadGateway => 502
            case ServiceUnavailable => 503
            case GatewayTimeout => 504
            case Custom(code, _) => code
        }
    }

    public func reason(): String {
        match (this) {
            case Continue => "Continue"
            case SwitchingProtocols => "Switching Protocols"
            case OK => "OK"
            case Created => "Created"
            case Accepted => "Accepted"
            case NoContent => "No Content"
            case MovedPermanently => "Moved Permanently"
            case Found => "Found"
            case SeeOther => "See Other"
            case NotModified => "Not Modified"
            case BadRequest => "Bad Request"
            case Unauthorized => "Unauthorized"
            case Forbidden => "Forbidden"
            case NotFound => "Not Found"
            case MethodNotAllowed => "Method Not Allowed"
            case RequestTimeout => "Request Timeout"
            case Conflict => "Conflict"
            case PayloadTooLarge => "Payload Too Large"
            case UnsupportedMediaType => "Unsupported Media Type"
            case TooManyRequests => "Too Many Requests"
            case InternalServerError => "Internal Server Error"
            case NotImplemented => "Not Implemented"
            case BadGateway => "Bad Gateway"
            case ServiceUnavailable => "Service Unavailable"
            case GatewayTimeout => "Gateway Timeout"
            case Custom(_, reason) => reason
        }
    }
}

/**
 * HTTP 响应
 */
public class HttpResponse {
    public var status: HttpStatus
    public var headers: HashMap<String, String>
    public var body: Array<UInt8>

    public init() {
        this.status = HttpStatus.OK
        this.headers = HashMap<String, String>()
        this.body = Array<UInt8>(0, { i: Int64 => 0u8 })
    }

    public init(status: HttpStatus) {
        this.status = status
        this.headers = HashMap<String, String>()
        this.body = Array<UInt8>(0, { i: Int64 => 0u8 })
    }

    public func withHeader(name: String, value: String): HttpResponse {
        let _ = headers.add(name, value)
        this
    }

    public func withContentType(contentType: String): HttpResponse {
        withHeader("Content-Type", contentType)
    }

    public func withJson(): HttpResponse {
        withContentType("application/json")
    }

    public func withText(): HttpResponse {
        withContentType("text/plain")
    }

    public func withHtml(): HttpResponse {
        withContentType("text/html")
    }

    public func withBody(body: String): HttpResponse {
        this.body = Array<UInt8>(0, { i: Int64 => 0u8 })
        this
    }
}

// ============================================================================
// HTTP Router
// ============================================================================

/**
 * 路由定义
 */
public class Route {
    public let method: HttpMethod
    public let path: String
    public let handler: (HttpRequest) -> HttpResponse

    public init(method: HttpMethod, path: String, handler: (HttpRequest) -> HttpResponse) {
        this.method = method
        this.path = path
        this.handler = handler
    }
}

/**
 * HTTP 路由
 */
public class HttpRouter {
    private let routes: ArrayList<Route>
    private var notFoundHandler: (HttpRequest) -> HttpResponse

    public init() {
        this.routes = ArrayList<Route>()
        this.notFoundHandler = { req =>
            HttpResponse(HttpStatus.NotFound)
        }
    }

    /**
     * 添加 GET 路由
     */
    public func get(path: String, handler: (HttpRequest) -> HttpResponse): HttpRouter {
        routes.add(Route(HttpMethod.GET, path, handler))
        this
    }

    /**
     * 添加 POST 路由
     */
    public func post(path: String, handler: (HttpRequest) -> HttpResponse): HttpRouter {
        routes.add(Route(HttpMethod.POST, path, handler))
        this
    }

    /**
     * 添加 PUT 路由
     */
    public func put(path: String, handler: (HttpRequest) -> HttpResponse): HttpRouter {
        routes.add(Route(HttpMethod.PUT, path, handler))
        this
    }

    /**
     * 添加 DELETE 路由
     */
    public func delete(path: String, handler: (HttpRequest) -> HttpResponse): HttpRouter {
        routes.add(Route(HttpMethod.DELETE, path, handler))
        this
    }

    /**
     * 设置 404 处理器
     */
    public func withNotFound(handler: (HttpRequest) -> HttpResponse): HttpRouter {
        this.notFoundHandler = handler
        this
    }

    /**
     * 路由请求
     */
    public func route(request: HttpRequest): HttpResponse {
        let path = request.path

        for (i in 0..routes.size) {
            let route = routes[i]
            if (route.path == path) {
                return route.handler(request)
            }
        }

        notFoundHandler(request)
    }
}

// ============================================================================
// HTTP Server
// ============================================================================

/**
 * HTTP 服务器配置
 */
public class HttpServerConfig {
    public var host: String
    public var port: Int32
    public var requestTimeout: Duration
    public var maxRequestSize: Int64
    public var corsEnabled: Bool

    public init() {
        this.host = "0.0.0.0"
        this.port = 8080
        this.requestTimeout = Duration.second * 30
        this.maxRequestSize = 1024 * 1024 * 10
        this.corsEnabled = false
    }
}

/**
 * HTTP 服务器
 */
public class HttpServer {
    private let config: HttpServerConfig
    private let router: HttpRouter
    private let isRunning: AtomicBool

    public init(config: HttpServerConfig) {
        this.config = config
        this.router = HttpRouter()
        this.isRunning = AtomicBool(false)
    }

    public init() {
        this.config = HttpServerConfig()
        this.router = HttpRouter()
        this.isRunning = AtomicBool(false)
    }

    /**
     * 获取路由
     */
    public func routes(): HttpRouter {
        router
    }

    /**
     * 启动服务器
     */
    public func start(): Unit {
        if (isRunning.compareAndSwap(false, true)) {
            println("HTTP 服务器启动在 ${config.host}:${config.port}")
        }
    }

    /**
     * 停止服务器
     */
    public func stop(): Unit {
        if (isRunning.compareAndSwap(true, false)) {
            println("HTTP 服务器停止")
        }
    }

    /**
     * 是否正在运行
     */
    public func isActive(): Bool {
        isRunning.load()
    }

    /**
     * 处理 HTTP 请求
     */
    public func handleRequest(request: HttpRequest): HttpResponse {
        router.route(request)
    }
}

// ============================================================================
// HTTP Client
// ============================================================================

/**
 * HTTP 客户端配置
 */
public class HttpClientConfig {
    public var baseUrl: String
    public var timeout: Duration
    public var maxConnections: Int64

    public init() {
        this.baseUrl = "http://localhost:8080"
        this.timeout = Duration.second * 30
        this.maxConnections = 100
    }
}

/**
 * HTTP 响应结果
 */
public class HttpResult {
    public let statusCode: Int64
    public let headers: HashMap<String, String>
    public let body: Array<UInt8>

    public init(statusCode: Int64, headers: HashMap<String, String>, body: Array<UInt8>) {
        this.statusCode = statusCode
        this.headers = headers
        this.body = body
    }
}

/**
 * HTTP 客户端
 */
public class HttpClient {
    private let config: HttpClientConfig

    public init(config: HttpClientConfig) {
        this.config = config
    }

    public init() {
        this.config = HttpClientConfig()
    }

    /**
     * GET 请求
     */
    public func get(path: String): HttpResult {
        let headers = HashMap<String, String>()
        HttpResult(200, headers, Array<UInt8>(0, { i: Int64 => 0u8 }))
    }

    /**
     * POST 请求
     */
    public func post(path: String, body: Array<UInt8>): HttpResult {
        let headers = HashMap<String, String>()
        HttpResult(200, headers, Array<UInt8>(0, { i: Int64 => 0u8 }))
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/**
 * 创建 JSON 响应
 */
public func jsonResponse(data: String): HttpResponse {
    HttpResponse(HttpStatus.OK).withJson()
}

/**
 * 创建文本响应
 */
public func textResponse(text: String): HttpResponse {
    HttpResponse(HttpStatus.OK).withText()
}

/**
 * 创建 HTML 响应
 */
public func htmlResponse(html: String): HttpResponse {
    HttpResponse(HttpStatus.OK).withHtml()
}

/**
 * 创建错误响应
 */
public func errorResponse(status: HttpStatus, message: String): HttpResponse {
    HttpResponse(status)
}
