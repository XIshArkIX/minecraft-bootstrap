const std = @import("std");

const Client = std.http.Client;
const http = std.http;
const Uri = std.Uri;
const Allocator = std.mem.Allocator;

const HttpRequest = @This();

pub const HttpResponse = struct {
    status: http.Status,
    body: []const u8,
};

allocator: Allocator,
client: std.http.Client,

pub fn init(allocator: Allocator) !HttpRequest {
    var client = Client{ .allocator = allocator };
    try client.initDefaultProxies(allocator);

    return HttpRequest{
        .allocator = allocator,
        .client = client,
    };
}

pub fn deinit(self: *HttpRequest) void {
    self.client.deinit();
}

/// Blocking GET request with auto-expanding memory for response body
pub fn get(self: *HttpRequest, url: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.GET, url, headers, null);
}

/// Blocking POST request with auto-expanding memory for response body
pub fn post(self: *HttpRequest, url: []const u8, body: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.POST, url, headers, body);
}

/// Custom request with any HTTP method and auto-expanding memory for response body
pub fn request(
    self: *HttpRequest,
    method: http.Method,
    url: []const u8,
    headers: []http.Header,
    body: ?[]const u8,
) !HttpResponse {
    const uri = try Uri.parse(url);

    var req = try self.client.request(method, uri, .{
        .extra_headers = headers,
    });
    defer req.deinit();

    // Send the request
    if (body) |request_body| {
        try req.sendBodyComplete(@constCast(request_body));
    } else {
        try req.sendBodiless();
    }

    // Receive the response head
    var redirect_buffer: [1024]u8 = undefined;
    const response = try req.receiveHead(&redirect_buffer);

    // Create an auto-expanding buffer for the response body
    var response_buffer = std.ArrayList(u8).empty;
    defer response_buffer.deinit(self.allocator);

    // Read the response body directly into our ArrayList
    var reader = req.reader.bodyReader(&.{}, response.head.transfer_encoding, response.head.content_length);

    // Use the appendRemaining method to read all remaining data into our ArrayList
    try reader.appendRemainingUnlimited(self.allocator, &response_buffer);

    // Get the response body and transfer ownership
    const response_body = try self.allocator.dupe(u8, response_buffer.items);

    return HttpResponse{
        .status = response.head.status,
        .body = response_body,
    };
}

/// PUT request with auto-expanding memory for response body
pub fn put(self: *HttpRequest, url: []const u8, body: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.PUT, url, headers, body);
}

/// DELETE request with auto-expanding memory for response body
pub fn delete(self: *HttpRequest, url: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.DELETE, url, headers, null);
}

/// HEAD request (no response body)
pub fn head(self: *HttpRequest, url: []const u8, headers: []http.Header) !HttpResponse {
    const uri = try Uri.parse(url);

    var req = try self.client.request(.HEAD, uri, .{
        .extra_headers = headers,
    });
    defer req.deinit();

    try req.sendBodiless();

    // Receive the response head
    var redirect_buffer: [1024]u8 = undefined;
    const response = try req.receiveHead(&redirect_buffer);

    // HEAD requests typically don't have a body, but we'll return an empty one
    const response_body = try self.allocator.dupe(u8, "");

    return HttpResponse{
        .status = response.head.status,
        .body = response_body,
    };
}

/// PATCH request with auto-expanding memory for response body
pub fn patch(self: *HttpRequest, url: []const u8, body: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.PATCH, url, headers, body);
}

/// OPTIONS request with auto-expanding memory for response body
pub fn options(self: *HttpRequest, url: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.OPTIONS, url, headers, null);
}

/// TRACE request with auto-expanding memory for response body
pub fn trace(self: *HttpRequest, url: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.TRACE, url, headers, null);
}

/// CONNECT request with auto-expanding memory for response body
pub fn connect(self: *HttpRequest, url: []const u8, headers: []http.Header) !HttpResponse {
    return self.request(.CONNECT, url, headers, null);
}

test "HttpRequest initialization and cleanup" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();
}

test "GET request to httpbin" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    const response = try http_req.get("http://httpbin.org/get", &.{});
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
    try std.testing.expect(response.body.len > 0);
}

test "POST request to httpbin" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    const test_data = "Hello, World!";
    const response = try http_req.post("http://httpbin.org/post", test_data, &.{});
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
    try std.testing.expect(response.body.len > 0);
}

test "PUT request to httpbin" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    const test_data = "Updated data";
    const response = try http_req.put("http://httpbin.org/put", test_data, &.{});
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
    try std.testing.expect(response.body.len > 0);
}

test "DELETE request to httpbin" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    const response = try http_req.delete("http://httpbin.org/delete", &.{});
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
}

test "HEAD request to httpbin" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    const response = try http_req.head("http://httpbin.org/get", &.{});
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
}

test "Custom request method" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    const response = try http_req.request(.GET, "http://httpbin.org/get", &.{}, null);
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
    try std.testing.expect(response.body.len > 0);
}

test "Request with custom headers" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    var headers = [_]http.Header{
        .{ .name = "User-Agent", .value = "Zig-HTTP-Client/1.0" },
        .{ .name = "Accept", .value = "application/json" },
    };

    const response = try http_req.get("http://httpbin.org/headers", &headers);
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
    try std.testing.expect(response.body.len > 0);
}

test "Large response handling" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    // Request a larger response to test memory expansion
    const response = try http_req.get("http://httpbin.org/bytes/10000", &.{});
    defer allocator.free(response.body);

    try std.testing.expectEqual(http.Status.ok, response.status);
    try std.testing.expect(response.body.len >= 10000);
}

test "Error handling for invalid URL" {
    const allocator = std.testing.allocator;
    var http_req = try init(allocator);
    defer http_req.deinit();

    // This should fail with an invalid URL
    const response = http_req.get("invalid-url", &.{});
    try std.testing.expectError(error.InvalidFormat, response);
}
