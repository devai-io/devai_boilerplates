const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;
const argon2 = std.crypto.pwhash.argon2;

const jwt = @import("jwt.zig");
const web = @import("web.zig");
const App = @import("main.zig").App;

const token_ttl_seconds: i64 = 7 * 24 * 60 * 60;

const Credentials = struct {
    email: []const u8,
    password: []const u8,
};

pub fn register(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    const creds = try web.parseJson(Credentials, arena, req);
    const email = try normalizeEmail(arena, creds.email);
    if (std.mem.findScalar(u8, email, '@') == null)
        return web.sendError(req, .bad_request, "a valid email is required");
    if (try std.unicode.utf8CountCodepoints(creds.password) < 8)
        return web.sendError(req, .bad_request, "password must be at least 8 characters");

    var hash_buf: [128]u8 = undefined;
    const hash = try argon2.strHash(creds.password, .{
        .allocator = arena,
        .params = argon2.Params.owasp_2id,
    }, &hash_buf, app.io);

    const id = app.db.createUser(arena, email, hash) catch |err| switch (err) {
        error.Conflict => return web.sendError(req, .conflict, "email already registered"),
        else => return err,
    };
    try web.sendJson(req, .created, .{ .id = id, .email = email }, arena);
}

pub fn login(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    const creds = try web.parseJson(Credentials, arena, req);
    const email = try normalizeEmail(arena, creds.email);

    const user = (try app.db.getUserByEmail(arena, email)) orelse
        return web.sendError(req, .unauthorized, "invalid email or password");
    argon2.strVerify(user.password_hash, creds.password, .{ .allocator = arena }, app.io) catch
        return web.sendError(req, .unauthorized, "invalid email or password");

    const token = try jwt.sign(arena, user.id, app.auth_secret, web.nowSeconds(app.io), token_ttl_seconds);
    try web.sendJson(req, .ok, .{ .token = token }, arena);
}

/// Returns the authenticated user id (ObjectId hex), or error.Unauthorized.
/// Call before reading the request body (it reads the Authorization header).
pub fn requireAuth(app: *App, arena: Allocator, req: *http.Server.Request) ![]const u8 {
    const token = web.bearerToken(req) orelse return error.Unauthorized;
    const claims = jwt.verify(arena, token, app.auth_secret, web.nowSeconds(app.io)) catch
        return error.Unauthorized;
    var oid: [12]u8 = undefined;
    _ = std.fmt.hexToBytes(&oid, claims.sub) catch return error.Unauthorized;
    return claims.sub;
}

fn normalizeEmail(arena: Allocator, email: []const u8) ![]const u8 {
    return std.ascii.allocLowerString(arena, std.mem.trim(u8, email, " \t\r\n"));
}
