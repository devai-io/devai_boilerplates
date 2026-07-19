const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;

const auth = @import("auth.zig");
const db = @import("db.zig");
const web = @import("web.zig");
const App = @import("main.zig").App;

pub fn list(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    const summaries = try app.db.listPublished(arena);
    try web.sendJson(req, .ok, summaries, arena);
}

pub fn get(app: *App, arena: Allocator, req: *http.Server.Request, slug: []const u8) !void {
    const post = (try app.db.getPublishedBySlug(arena, slug)) orelse return error.NotFound;
    try web.sendJson(req, .ok, post, arena);
}

pub fn create(app: *App, arena: Allocator, req: *http.Server.Request) !void {
    const author_id = try auth.requireAuth(app, arena, req);
    const in = try web.parseJson(struct {
        title: []const u8,
        body: []const u8,
    }, arena, req);

    const title = std.mem.trim(u8, in.title, " \t\r\n");
    if (title.len == 0)
        return web.sendError(req, .unprocessable_entity, "title is required");

    const slug = try slugify(arena, title);
    const post = try app.db.createPost(arena, author_id, title, slug, in.body);
    try web.sendJson(req, .created, post, arena);
}

pub fn update(app: *App, arena: Allocator, req: *http.Server.Request, id_param: []const u8) !void {
    const author_id = try auth.requireAuth(app, arena, req);
    const changes = try web.parseJson(db.PostUpdate, arena, req);

    const existing = (try app.db.getPostById(arena, id_param)) orelse return error.NotFound;
    if (existing.author_id != author_id) return error.Forbidden;

    const post = try app.db.updatePost(arena, existing.id, changes);
    try web.sendJson(req, .ok, post, arena);
}

pub fn delete(app: *App, arena: Allocator, req: *http.Server.Request, id_param: []const u8) !void {
    const author_id = try auth.requireAuth(app, arena, req);

    const existing = (try app.db.getPostById(arena, id_param)) orelse return error.NotFound;
    if (existing.author_id != author_id) return error.Forbidden;

    try app.db.deletePost(existing.id);
    try req.respond("", .{ .status = .no_content });
}

/// Lowercased ASCII alphanumerics, everything else collapsed to single dashes.
fn slugify(arena: Allocator, title: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var pending_dash = false;
    for (title) |raw| {
        const ch = std.ascii.toLower(raw);
        if (std.ascii.isAlphanumeric(ch)) {
            if (pending_dash and out.items.len > 0) try out.append(arena, '-');
            pending_dash = false;
            try out.append(arena, ch);
        } else {
            pending_dash = true;
        }
    }
    if (out.items.len == 0) try out.appendSlice(arena, "post");
    return out.items;
}
