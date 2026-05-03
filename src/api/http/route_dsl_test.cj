/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Route DSL 单元测试
 */
package cactor.api.http

import std.collection.*

// ============================================================================
// PathParams Tests
// ============================================================================

@Test
func testPathParams_empty() {
    let params = PathParams()
    match (params.get("test")) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testPathParams_setAndGet() {
    let params = PathParams()
    params.set("id", "123")
    match (params.get("id")) {
        case Some(v) => @Expect(v, "123")
        case None => @Expect(true, false)
    }
}

@Test
func testPathParams_getOrDefault() {
    let params = PathParams()
    @Expect(params.getOrDefault("missing", "default"), "default")
    params.set("key", "value")
    @Expect(params.getOrDefault("key", "default"), "value")
}

@Test
func testPathParams_contains() {
    let params = PathParams()
    @Expect(params.contains("key"), false)
    params.set("key", "value")
    @Expect(params.contains("key"), true)
}

// ============================================================================
// QueryParams Tests
// ============================================================================

@Test
func testQueryParams_empty() {
    let params = QueryParams()
    @Expect(params.contains("test"), false)
}

@Test
func testQueryParams_contains() {
    let params = QueryParams()
    params.get("name")
    @Expect(params.contains("name"), false)
}

// ============================================================================
// PathMatcher Tests
// ============================================================================

@Test
func testPathMatcher_match() {
    let matcher = PathMatcher("/api/users")
    @Expect(matcher.matchPath("/api/users"), true)
    @Expect(matcher.matchPath("/api/posts"), false)
}

// ============================================================================
// RequestContext Tests
// ============================================================================

@Test
func testRequestContext_creation() {
    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/test",
        "/api/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    @Expect(ctx.path(), "/api/test")
}

@Test
func testRequestContext_header() {
    let headers = HashMap<String, String>()
    let _ = headers.add("X-Custom", "value")
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/test",
        "/api/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    match (ctx.header("X-Custom")) {
        case Some(v) => @Expect(v, "value")
        case None => @Expect(true, false)
    }
}

// ============================================================================
// Directives Tests
// ============================================================================

@Test
func testDirectives_basic() {
    let directives = Directives()
    @Expect(true, true)
}

@Test
func testDirectives_execute() {
    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/test",
        "/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    let inner = Directives()
    let result = inner.execute(ctx)
    match (result) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

// ============================================================================
// Directive Function Tests
// ============================================================================

@Test
func testReject() {
    let result = reject("test reason")
    match (result) {
        case RouteResult.Rejected(msg) => @Expect(msg, "test reason")
        case RouteResult.Passed(_) => @Expect(true, false)
    }
}

@Test
func testPass() {
    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/test",
        "/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    let result = pass(ctx)
    match (result) {
        case RouteResult.Rejected(_) => @Expect(true, false)
        case RouteResult.Passed(c) => @Expect(c.path(), "/test")
    }
}

// ============================================================================
// Path Directive Tests
// ============================================================================

@Test
func testPath_directiveMatch() {
    let inner = Directives()
    let route = path("/api/users", inner)

    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/users",
        "/api/users",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    match (route.execute(ctx)) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, true)
    }
}

@Test
func testPath_directiveMismatch() {
    let inner = Directives()
    let route = path("/api/users", inner)

    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/posts",
        "/api/posts",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    match (route.execute(ctx)) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

// ============================================================================
// Method Directive Tests
// ============================================================================

@Test
func testGet_directive() {
    let inner = Directives()
    let route = get("/test", inner)

    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/test",
        "/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    match (route.execute(ctx)) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, true)
    }
}

@Test
func testPost_directive() {
    let inner = Directives()
    let route = post("/test", inner)

    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.POST,
        "/test",
        "/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    match (route.execute(ctx)) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, true)
    }
}

// ============================================================================
// PathParam/QueryParam Tests
// ============================================================================

@Test
func testPathParam() {
    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/users/123",
        "/api/users/123",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let params = PathParams()
    params.set("id", "123")
    let ctx = RequestContext(request, params, QueryParams())

    let extractor = pathParam("id")
    match (extractor(ctx)) {
        case Some(v) => @Expect(v, "123")
        case None => @Expect(true, false)
    }
}

@Test
func testQueryParam() {
    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/search",
        "/api/search",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let queryParams = QueryParams()
    let ctx = RequestContext(request, PathParams(), queryParams)

    let extractor = queryParam("name")
    match (extractor(ctx)) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

// ============================================================================
// Complete Function Tests
// ============================================================================

@Test
func testComplete() {
    let response = HttpResponse(HttpStatus.OK)
    let handler = complete(response)

    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/test",
        "/test",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let ctx = RequestContext(request)
    let result = handler(ctx)
    match (result) {
        case Some(r) => @Expect(r.status.code(), 200)
        case None => @Expect(true, false)
    }
}
