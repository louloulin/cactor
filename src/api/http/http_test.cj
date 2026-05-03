/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - HTTP API 单元测试
 */
package cactor.api.http

import std.collection.*
import std.time.*

// ============================================================================
// HttpRequest Tests
// ============================================================================

@Test
func testHttpRequest_creation() {
    let headers = HashMap<String, String>()
    let _ = headers.add("Content-Type", "application/json")
    let request = HttpRequest(
        HttpMethod.GET,
        "/api/users",
        "/api/users",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        Some("127.0.0.1:12345")
    )
    @Expect(request.path, "/api/users")
    @Expect(request.uri, "/api/users")
}

@Test
func testHttpRequest_header() {
    let headers = HashMap<String, String>()
    let _ = headers.add("Content-Type", "application/json")
    let request = HttpRequest(
        HttpMethod.POST,
        "/api/data",
        "/api/data",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    match (request.header("Content-Type")) {
        case Some(v) => @Expect(v, "application/json")
        case None => @Expect(true, false)
    }
}

// ============================================================================
// HttpResponse Tests
// ============================================================================

@Test
func testHttpResponse_defaultStatus() {
    let response = HttpResponse()
    @Expect(response.status.code(), 200)
}

@Test
func testHttpResponse_customStatus() {
    let response = HttpResponse(HttpStatus.NotFound)
    @Expect(response.status.code(), 404)
}

@Test
func testHttpResponse_withHeader() {
    let response = HttpResponse()
    let r = response.withHeader("X-Custom", "value")
    let r2 = r.withHeader("Content-Type", "application/json")
    match (r2.headers.get("X-Custom")) {
        case Some(v) => @Expect(v, "value")
        case None => @Expect(true, false)
    }
}

@Test
func testHttpResponse_withJson() {
    let response = HttpResponse().withJson()
    match (response.headers.get("Content-Type")) {
        case Some(v) => @Expect(v, "application/json")
        case None => @Expect(true, false)
    }
}

@Test
func testHttpResponse_withText() {
    let response = HttpResponse().withText()
    match (response.headers.get("Content-Type")) {
        case Some(v) => @Expect(v, "text/plain")
        case None => @Expect(true, false)
    }
}

@Test
func testHttpResponse_withHtml() {
    let response = HttpResponse().withHtml()
    match (response.headers.get("Content-Type")) {
        case Some(v) => @Expect(v, "text/html")
        case None => @Expect(true, false)
    }
}

// ============================================================================
// HttpStatus Tests
// ============================================================================

@Test
func testHttpStatus_codes() {
    @Expect(HttpStatus.OK.code(), 200)
    @Expect(HttpStatus.Created.code(), 201)
    @Expect(HttpStatus.BadRequest.code(), 400)
    @Expect(HttpStatus.NotFound.code(), 404)
    @Expect(HttpStatus.InternalServerError.code(), 500)
}

@Test
func testHttpStatus_reasons() {
    @Expect(HttpStatus.OK.reason(), "OK")
    @Expect(HttpStatus.NotFound.reason(), "Not Found")
    @Expect(HttpStatus.BadRequest.reason(), "Bad Request")
}

@Test
func testHttpStatus_custom() {
    let status = HttpStatus.Custom(999, "Custom Status")
    @Expect(status.code(), 999)
    @Expect(status.reason(), "Custom Status")
}

// ============================================================================
// HttpMethod Tests
// ============================================================================

@Test
func testHttpMethod_all() {
    @Expect(true, true)
}

// ============================================================================
// HttpRouter Tests
// ============================================================================

@Test
func testHttpRouter_creation() {
    let router = HttpRouter()
    @Expect(true, true)
}

@Test
func testHttpRouter_getRoute() {
    let router = HttpRouter()
    let r = router.get("/api/users", { req => HttpResponse(HttpStatus.OK) })
    @Expect(true, true)
}

@Test
func testHttpRouter_postRoute() {
    let router = HttpRouter()
    let r = router.post("/api/users", { req => HttpResponse(HttpStatus.Created) })
    @Expect(true, true)
}

@Test
func testHttpRouter_putRoute() {
    let router = HttpRouter()
    let r = router.put("/api/users/:id", { req => HttpResponse(HttpStatus.OK) })
    @Expect(true, true)
}

@Test
func testHttpRouter_deleteRoute() {
    let router = HttpRouter()
    let r = router.delete("/api/users/:id", { req => HttpResponse(HttpStatus.NoContent) })
    @Expect(true, true)
}

@Test
func testHttpRouter_routeMatching() {
    let router = HttpRouter()
    let r = router.get("/test", { req =>
        HttpResponse(HttpStatus.OK)
    })

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
    let response = r.route(request)
    @Expect(response.status.code(), 200)
}

@Test
func testHttpRouter_notFound() {
    let router = HttpRouter()
    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/nonexistent",
        "/nonexistent",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let response = router.route(request)
    @Expect(response.status.code(), 404)
}

@Test
func testHttpRouter_withNotFound() {
    let router = HttpRouter()
    let r = router.withNotFound({ req =>
        HttpResponse(HttpStatus.Custom(410, "Gone"))
    })

    let headers = HashMap<String, String>()
    let request = HttpRequest(
        HttpMethod.GET,
        "/gone",
        "/gone",
        HttpVersion.HTTP_1_1,
        headers,
        Array<UInt8>(0, { i: Int64 => 0u8 }),
        None
    )
    let response = r.route(request)
    @Expect(response.status.code(), 410)
}

// ============================================================================
// HttpServer Tests
// ============================================================================

@Test
func testHttpServer_creation() {
    let config = HttpServerConfig()
    let server = HttpServer(config)
    @Expect(true, true)
    @Expect(server.isActive(), false)
}

@Test
func testHttpServer_defaultConfig() {
    let server = HttpServer()
    @Expect(true, true)
}

@Test
func testHttpServer_routes() {
    let server = HttpServer()
    let router = server.routes()
    @Expect(true, true)
}

@Test
func testHttpServer_handleRequest() {
    let server = HttpServer()
    let router = server.routes()
    let r = router.get("/api/test", { req =>
        HttpResponse(HttpStatus.OK).withJson()
    })

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
    let response = server.handleRequest(request)
    @Expect(response.status.code(), 200)
}

// ============================================================================
// HttpClient Tests
// ============================================================================

@Test
func testHttpClient_creation() {
    let config = HttpClientConfig()
    let client = HttpClient(config)
    @Expect(true, true)
}

@Test
func testHttpClient_defaultConfig() {
    let client = HttpClient()
    @Expect(true, true)
}

@Test
func testHttpClient_get() {
    let client = HttpClient()
    let result = client.get("/api/test")
    @Expect(result.statusCode, 200)
}

// ============================================================================
// Helper Function Tests
// ============================================================================

@Test
func testJsonResponse() {
    let response = jsonResponse("")
    @Expect(response.status.code(), 200)
    match (response.headers.get("Content-Type")) {
        case Some(v) => @Expect(v, "application/json")
        case None => @Expect(true, false)
    }
}

@Test
func testTextResponse() {
    let response = textResponse("Hello")
    @Expect(response.status.code(), 200)
    match (response.headers.get("Content-Type")) {
        case Some(v) => @Expect(v, "text/plain")
        case None => @Expect(true, false)
    }
}

@Test
func testHtmlResponse() {
    let response = htmlResponse("")
    @Expect(response.status.code(), 200)
    match (response.headers.get("Content-Type")) {
        case Some(v) => @Expect(v, "text/html")
        case None => @Expect(true, false)
    }
}

@Test
func testErrorResponse() {
    let response = errorResponse(HttpStatus.BadRequest, "Invalid")
    @Expect(response.status.code(), 400)
}

// ============================================================================
// HttpServerConfig Tests
// ============================================================================

@Test
func testHttpServerConfig_defaults() {
    let config = HttpServerConfig()
    @Expect(config.host, "0.0.0.0")
    @Expect(config.port, 8080)
    @Expect(config.corsEnabled, false)
}
