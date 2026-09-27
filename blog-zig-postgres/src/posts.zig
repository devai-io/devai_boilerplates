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
    if (title.len == 0 or std.mem.trim(u8, in.body, " \t\r\n").len == 0)
        return web.sendError(req, .bad_request, "title and body are required");

    const post = try app.db.createPost(arena, author_id, title, try slugify(arena, title), in.body);
    try web.sendJson(req, .created, post, arena);
}

pub fn update(app: *App, arena: Allocator, req: *http.Server.Request, id_param: []const u8) !void {
    const user_id = try auth.requireAuth(app, arena, req);
    const in = try web.parseJson(struct {
        title: ?[]const u8 = null,
        body: ?[]const u8 = null,
        published: ?bool = null,
    }, arena, req);

    const post = try findOwnPost(app, arena, id_param, user_id);

    var title = post.title;
    var slug = post.slug;
    if (in.title) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0) return web.sendError(req, .bad_request, "title cannot be empty");
        // The slug follows the title; an unchanged title keeps its slug.
        if (!std.mem.eql(u8, trimmed, post.title)) {
            title = trimmed;
            slug = try slugify(arena, trimmed);
        }
    }

    const updated = try app.db.updatePost(
        arena,
        post.id,
        title,
        slug,
        in.body orelse post.body,
        in.published orelse post.published,
    );
    try web.sendJson(req, .ok, updated, arena);
}

pub fn delete(app: *App, arena: Allocator, req: *http.Server.Request, id_param: []const u8) !void {
    const user_id = try auth.requireAuth(app, arena, req);
    const post = try findOwnPost(app, arena, id_param, user_id);
    try app.db.deletePost(post.id);
    try req.respond("", .{ .status = .no_content });
}

/// error.NotFound if the post doesn't exist, error.Forbidden if it belongs
/// to someone else.
fn findOwnPost(app: *App, arena: Allocator, id_param: []const u8, user_id: i64) !db.Post {
    const post = (try app.db.getPostById(arena, id_param)) orelse return error.NotFound;
    if (post.author_id != user_id) return error.Forbidden;
    return post;
}

/// Lowercases the title and collapses every non-alphanumeric run into a
/// single dash: "Hello, World!" -> "hello-world".
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
