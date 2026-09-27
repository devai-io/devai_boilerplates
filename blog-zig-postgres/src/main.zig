const std = @import("std");
const http = std.http;
const net = std.Io.net;
const Allocator = std.mem.Allocator;

const auth = @import("auth.zig");
const db = @import("db.zig");
const posts = @import("posts.zig");
const web = @import("web.zig");

pub const App = struct {
    gpa: Allocator,
    io: std.Io,
    db: *db.Db,
    auth_secret: []const u8,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const env = init.environ_map;

    const port = std.fmt.parseInt(u16, env.get("PORT") orelse "8080", 10) catch
        std.process.fatal("PORT must be a number", .{});
    const database_url = env.get("DATABASE_URL") orelse
        "postgres://blog:blog@localhost:5432/blog";
    const auth_secret = env.get("AUTH_SECRET") orelse
        std.process.fatal("AUTH_SECRET is required", .{});

    var database = try db.Db.init(gpa, io, database_url);
    defer database.deinit();

    var app: App = .{
        .gpa = gpa,
        .io = io,
        .db = &database,
        .auth_secret = auth_secret,
    };

    const addr = try net.IpAddress.parse("0.0.0.0", port);
    var server = try addr.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    std.log.info("listening on 0.0.0.0:{d}", .{port});

    while (true) {
        const stream = server.accept(io) catch |err| {
            std.log.warn("accept failed: {t}", .{err});
            continue;
        };
        const thread = std.Thread.spawn(.{}, serveConnection, .{ &app, stream }) catch |err| {
            std.log.warn("thread spawn failed: {t}", .{err});
            stream.close(io);
            continue;
        };
        thread.detach();
    }
}

fn serveConnection(app: *App, stream: net.Stream) void {
    defer stream.close(app.io);

    var recv_buf: [16 * 1024]u8 = undefined;
    var send_buf: [16 * 1024]u8 = undefined;
    var stream_reader = stream.reader(app.io, &recv_buf);
    var stream_writer = stream.writer(app.io, &send_buf);
    var server = http.Server.init(&stream_reader.interface, &stream_writer.interface);

    while (server.reader.state == .ready) {
        var request = server.receiveHead() catch return;

        var arena_state = std.heap.ArenaAllocator.init(app.gpa);
        defer arena_state.deinit();

        handle(app, arena_state.allocator(), &request) catch |err| {
            respondError(&request, err) catch return;
        };
    }
}

/// Handlers either send a full response and return normally, or return an
/// error and let `respondError` produce the JSON error body.
fn handle(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    // The target points into the connection's read buffer, which is reused
    // once the request body is read. Keep our own copy.
    const target = try arena.dupe(u8, req.head.target);
    const path = target[0 .. std.mem.findScalar(u8, target, '?') orelse target.len];
    const method = req.head.method;
    // A POST/PUT/PATCH without Content-Length or Transfer-Encoding has an empty
    // body (RFC 9112); say so explicitly, or std.http asserts when it discards it.
    if (method.requestHasBody() and req.head.transfer_encoding == .none and req.head.content_length == null)
        req.head.content_length = 0;

    if (std.mem.eql(u8, path, "/health")) {
        if (method != .GET) return error.MethodNotAllowed;
        return req.respond("ok", .{
            .extra_headers = &.{.{ .name = "content-type", .value = "text/plain" }},
        });
    }
    if (std.mem.eql(u8, path, "/auth/register")) {
        if (method != .POST) return error.MethodNotAllowed;
        return auth.register(app, arena, req);
    }
    if (std.mem.eql(u8, path, "/auth/login")) {
        if (method != .POST) return error.MethodNotAllowed;
        return auth.login(app, arena, req);
    }

    if (std.mem.eql(u8, path, "/posts")) {
        switch (method) {
            .GET => return posts.list(app, arena, req),
            .POST => return posts.create(app, arena, req),
            else => return error.MethodNotAllowed,
        }
    }
    if (std.mem.startsWith(u8, path, "/posts/")) {
        const param = path["/posts/".len..];
        if (param.len == 0 or std.mem.findScalar(u8, param, '/') != null)
            return error.NotFound;
        switch (method) {
            .GET => return posts.get(app, arena, req, param),
            .PUT => return posts.update(app, arena, req, param),
            .DELETE => return posts.delete(app, arena, req, param),
            else => return error.MethodNotAllowed,
        }
    }

    return error.NotFound;
}

fn respondError(req: *http.Server.Request, err: anyerror) !void {
    switch (err) {
        error.BadRequest => try web.sendError(req, .bad_request, "invalid request body"),
        error.BodyTooLarge => try web.sendError(req, .payload_too_large, "request body too large"),
        error.Unauthorized => try web.sendError(req, .unauthorized, "missing or invalid token"),
        error.Forbidden => try web.sendError(req, .forbidden, "not your post"),
        error.NotFound => try web.sendError(req, .not_found, "not found"),
        error.MethodNotAllowed => try web.sendError(req, .method_not_allowed, "method not allowed"),
        else => {
            std.log.err("internal error: {t}", .{err});
            try web.sendError(req, .internal_server_error, "internal error");
        },
    }
}
