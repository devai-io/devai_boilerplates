const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;
const argon2 = std.crypto.pwhash.argon2;

const jwt = @import("jwt.zig");
const web = @import("web.zig");
const App = @import("main.zig").App;

pub const token_ttl_seconds: i64 = 7 * 24 * 60 * 60; // 7 days

const Credentials = struct {
    email: []const u8,
    password: []const u8,
};

pub fn register(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    const creds = try web.parseJson(Credentials, arena, req);
    if (creds.email.len < 3 or std.mem.findScalar(u8, creds.email, '@') == null)
        return web.sendError(req, .unprocessable_entity, "invalid email");
    if (creds.password.len < 8)
        return web.sendError(req, .unprocessable_entity, "password must be at least 8 characters");

    var hash_buf: [128]u8 = undefined;
    const hash = argon2.strHash(creds.password, .{
        .allocator = arena,
        .params = argon2.Params.owasp_2id,
    }, &hash_buf, app.io) catch return error.HashFailed;

    const id = try app.db.createUser(arena, creds.email, hash, web.nowSeconds(app.io));
    try web.sendJson(req, .created, .{ .id = id, .email = creds.email }, arena);
}

pub fn login(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    const creds = try web.parseJson(Credentials, arena, req);

    const user = (try app.db.getUserByEmail(arena, creds.email)) orelse
        return web.sendError(req, .unauthorized, "invalid credentials");

    argon2.strVerify(user.password_hash, creds.password, .{ .allocator = arena }, app.io) catch
        return web.sendError(req, .unauthorized, "invalid credentials");

    const token = try jwt.sign(arena, user.id, app.auth_secret, web.nowSeconds(app.io), token_ttl_seconds);
    try web.sendJson(req, .ok, .{ .token = token }, arena);
}

/// Returns the authenticated user id (ObjectId hex), or error.Unauthorized.
/// Call before reading the request body (it reads the Authorization header).
pub fn requireAuth(app: *App, arena: Allocator, req: *http.Server.Request) ![]const u8 {
    const token = web.bearerToken(req) orelse return error.Unauthorized;
    const claims = jwt.verify(arena, token, app.auth_secret, web.nowSeconds(app.io)) catch
        return error.Unauthorized;
    return claims.sub;
}
