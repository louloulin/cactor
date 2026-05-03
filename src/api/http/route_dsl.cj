/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - HTTP Route DSL 实现
 * 对标 Akka HTTP Route DSL，提供类型安全的路由定义
 */
package cactor.api.http

import std.collection.*

// ============================================================================
// Route DSL 核心类型
// ============================================================================

/**
 * 路径参数
 */
public class PathParams {
    private let params: HashMap<String, String>

    public init() {
        this.params = HashMap<String, String>()
    }

    public func get(key: String): Option<String> {
        params.get(key)
    }

    public func getOrDefault(key: String, default: String): String {
        match (params.get(key)) {
            case Some(v) => v
            case None => default
        }
    }

    public func contains(key: String): Bool {
        params.contains(key)
    }

    public func set(key: String, value: String): Unit {
        let _ = params.add(key, value)
    }
}

/**
 * 查询参数
 */
public class QueryParams {
    private let params: HashMap<String, String>

    public init() {
        this.params = HashMap<String, String>()
    }

    public init(queryString: String) {
        this.params = HashMap<String, String>()
    }

    public func get(key: String): Option<String> {
        params.get(key)
    }

    public func contains(key: String): Bool {
        params.contains(key)
    }
}

/**
 * 请求上下文
 */
public class RequestContext {
    public let request: HttpRequest
    public let pathParams: PathParams
    public let queryParams: QueryParams

    public init(request: HttpRequest) {
        this.request = request
        this.pathParams = PathParams()
        this.queryParams = QueryParams()
    }

    public init(request: HttpRequest, pathParams: PathParams, queryParams: QueryParams) {
        this.request = request
        this.pathParams = pathParams
        this.queryParams = queryParams
    }

    public func header(name: String): Option<String> {
        request.header(name)
    }

    public func path(): String {
        request.path
    }

    public func method(): HttpMethod {
        request.method
    }
}

// ============================================================================
// Route Matcher
// ============================================================================

/**
 * 路径匹配器
 */
public class PathMatcher {
    private let pattern: String

    public init(pattern: String) {
        this.pattern = pattern
    }

    public func matchPath(path: String): Bool {
        pattern == path
    }
}

// ============================================================================
// Route Result
// ============================================================================

/**
 * 路由结果
 */
public enum RouteResult {
    | Rejected(String)
    | Passed(RequestContext)
}

// ============================================================================
// Directives
// ============================================================================

/**
 * 路由指令链
 */
public class Directives {
    private let directives: ArrayList<(RequestContext) -> RouteResult>
    private let inner: Option<Directives>

    public init() {
        this.directives = ArrayList<(RequestContext) -> RouteResult>()
        this.inner = None
    }

    private init(directives: ArrayList<(RequestContext) -> RouteResult>, inner: Option<Directives>) {
        this.directives = directives
        this.inner = inner
    }

    public func withDirective(directive: (RequestContext) -> RouteResult): Directives {
        let newDirectives = ArrayList<(RequestContext) -> RouteResult>()
        for (d in directives) {
            newDirectives.add(d)
        }
        newDirectives.add(directive)
        Directives(newDirectives, inner)
    }

    public func nested(inner: Directives): Directives {
        Directives(directives, Some(inner))
    }

    public func execute(ctx: RequestContext): Option<HttpResponse> {
        var current = ctx
        for (directive in directives) {
            match (directive(current)) {
                case RouteResult.Rejected(_) =>
                    return None
                case RouteResult.Passed(nextCtx) =>
                    current = nextCtx
            }
        }

        match (inner) {
            case Some(r) => r.execute(current)
            case None => None
        }
    }
}

// ============================================================================
// Directive 工厂函数
// ============================================================================

/**
 * 拒绝请求
 */
public func reject(reason: String): RouteResult {
    RouteResult.Rejected(reason)
}

/**
 * 传递请求
 */
public func pass(ctx: RequestContext): RouteResult {
    RouteResult.Passed(ctx)
}

/**
 * 路径匹配指令
 */
public func path(pattern: String, inner: Directives): Directives {
    let matcher = PathMatcher(pattern)
    let directive: (RequestContext) -> RouteResult = { ctx =>
        if (matcher.matchPath(ctx.request.path)) {
            RouteResult.Passed(ctx)
        } else {
            RouteResult.Rejected("Path mismatch")
        }
    }
    Directives().withDirective(directive).nested(inner)
}

/**
 * GET 方法指令
 */
public func get(pattern: String, inner: Directives): Directives {
    let directive: (RequestContext) -> RouteResult = { ctx =>
        match (ctx.request.method) {
            case HttpMethod.GET =>
                RouteResult.Passed(ctx)
            case _ =>
                RouteResult.Rejected("Method not GET")
        }
    }
    path(pattern, inner.withDirective(directive))
}

/**
 * POST 方法指令
 */
public func post(pattern: String, inner: Directives): Directives {
    let directive: (RequestContext) -> RouteResult = { ctx =>
        match (ctx.request.method) {
            case HttpMethod.POST =>
                RouteResult.Passed(ctx)
            case _ =>
                RouteResult.Rejected("Method not POST")
        }
    }
    path(pattern, inner.withDirective(directive))
}

/**
 * PUT 方法指令
 */
public func put(pattern: String, inner: Directives): Directives {
    let directive: (RequestContext) -> RouteResult = { ctx =>
        match (ctx.request.method) {
            case HttpMethod.PUT =>
                RouteResult.Passed(ctx)
            case _ =>
                RouteResult.Rejected("Method not PUT")
        }
    }
    path(pattern, inner.withDirective(directive))
}

/**
 * DELETE 方法指令
 */
public func delete(pattern: String, inner: Directives): Directives {
    let directive: (RequestContext) -> RouteResult = { ctx =>
        match (ctx.request.method) {
            case HttpMethod.DELETE =>
                RouteResult.Passed(ctx)
            case _ =>
                RouteResult.Rejected("Method not DELETE")
        }
    }
    path(pattern, inner.withDirective(directive))
}

/**
 * Header 匹配指令
 */
public func header(name: String, value: String, inner: Directives): Directives {
    let directive: (RequestContext) -> RouteResult = { ctx =>
        match (ctx.request.header(name)) {
            case Some(v) =>
                if (v == value) {
                    RouteResult.Passed(ctx)
                } else {
                    RouteResult.Rejected("Header value mismatch")
                }
            case None =>
                RouteResult.Rejected("Header not found")
        }
    }
    inner.withDirective(directive)
}

/**
 * 查询参数匹配指令
 */
public func parameter(name: String, inner: Directives): Directives {
    let directive: (RequestContext) -> RouteResult = { ctx =>
        if (ctx.queryParams.contains(name)) {
            RouteResult.Passed(ctx)
        } else {
            RouteResult.Rejected("Parameter not found")
        }
    }
    inner.withDirective(directive)
}

/**
 * 路径参数提取
 */
public func pathParam(name: String): (RequestContext) -> Option<String> {
    { ctx => ctx.pathParams.get(name) }
}

/**
 * 查询参数提取
 */
public func queryParam(name: String): (RequestContext) -> Option<String> {
    { ctx => ctx.queryParams.get(name) }
}

/**
 * 完成请求
 */
public func complete(response: HttpResponse): (RequestContext) -> Option<HttpResponse> {
    { ctx => Some(response) }
}
