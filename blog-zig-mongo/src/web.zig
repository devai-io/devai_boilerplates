//! Small helpers shared by all handlers: JSON in/out, body reading, and the
//! Authorization header. No framework, just std.http plumbing.

const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;

pub const max_body_len = 1 << 20; // 1 MiB

pub fn sendJson(req: *http.Server.Request, status: http.Status, value: anytype, arena: Allocator) !void {
    const body = try std.json.Stringify.valueAlloc(arena, value, .{});
    try req.respond(body, .{
        .status = status,
        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
    });
}

pub fn sendError(req: *http.Server.Request, status: http.Status, message: []const u8) !void {
    var buf: [256]u8 = undefined;
    var aw: std.Io.Writer = .fixed(&buf);
    std.json.Stringify.value(.{ .@"error" = message }, .{}, &aw) catch return error.WriteFailed;
    try req.respond(aw.buffered(), .{
        .status = status,
        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
    });
}

pub fn readBody(req: *http.Server.Request, arena: Allocator) ![]u8 {
    var transfer_buf: [4096]u8 = undefined;
    const reader = req.readerExpectContinue(&transfer_buf) catch return error.BadRequest;
    return reader.allocRemaining(arena, .limited(max_body_len)) catch |err| switch (err) {
        error.StreamTooLong => error.BodyTooLarge,
        error.OutOfMemory => error.OutOfMemory,
        error.ReadFailed => error.BadRequest,
    };
}

/// Read the request body and parse it as JSON into `T`. Unknown fields are
/// ignored; missing fields without defaults make this a 400.
pub fn parseJson(comptime T: type, arena: Allocator, req: *http.Server.Request) !T {
    const body = try readBody(req, arena);
    return std.json.parseFromSliceLeaky(T, arena, body, .{
        .ignore_unknown_fields = true,
    }) catch error.BadRequest;
}

/// Must be called before the body is read: header slices point into the head
/// buffer. Verify/copy the token before touching the body.
pub fn bearerToken(req: *http.Server.Request) ?[]const u8 {
    var it = req.iterateHeaders();
    while (it.next()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "authorization")) continue;
        if (header.value.len > 7 and std.ascii.eqlIgnoreCase(header.value[0..7], "Bearer "))
            return std.mem.trim(u8, header.value[7..], " ");
        return null;
    }
    return null;
}

pub fn nowSeconds(io: std.Io) i64 {
    return std.Io.Clock.now(.real, io).toSeconds();
}
