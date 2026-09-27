//! Postgres access via pg.zig. All strings returned to handlers are duped
//! into the per-request arena so they outlive the connection's row buffers.

const std = @import("std");
const pg = @import("pg");
const Allocator = std.mem.Allocator;

const schema = @embedFile("schema.sql");

pub const User = struct {
    id: i64,
    email: []const u8,
    password_hash: []const u8,
};

pub const Post = struct {
    id: i64,
    title: []const u8,
    slug: []const u8,
    body: []const u8,
    published: bool,
    published_at: ?[]const u8, // null until first published
    author_id: i64,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const PostSummary = struct {
    id: i64,
    title: []const u8,
    slug: []const u8,
    excerpt: []const u8,
    published_at: ?[]const u8,
};

fn rfc3339(comptime column: []const u8) []const u8 {
    return "to_char(" ++ column ++ " at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";
}

const post_columns = "id, title, slug, body, published, author_id, " ++
    rfc3339("created_at") ++ ", " ++ rfc3339("updated_at") ++ ", " ++ rfc3339("published_at");

// left() counts characters, not bytes, so the excerpt never splits a UTF-8 sequence.
const summary_columns = "id, title, slug, left(body, 200), " ++ rfc3339("published_at");

pub const Db = struct {
    pool: *pg.Pool,

    pub fn init(gpa: Allocator, io: std.Io, database_url: []const u8) !Db {
        const uri = std.Uri.parse(database_url) catch return error.BadDatabaseUrl;
        const pool = try pg.Pool.initUri(io, gpa, uri, .{ .size = 5 });
        errdefer pool.deinit();
        var db: Db = .{ .pool = pool };
        try db.ensureSchema();
        return db;
    }

    pub fn deinit(self: *Db) void {
        self.pool.deinit();
    }

    /// Applies schema.sql statement by statement. Everything in it is
    /// `if not exists`, so this is safe to run on every startup.
    fn ensureSchema(self: *Db) !void {
        var conn = try self.pool.acquire();
        defer conn.release();
        var statements = std.mem.splitScalar(u8, schema, ';');
        while (statements.next()) |statement| {
            const sql = std.mem.trim(u8, statement, " \t\r\n");
            if (sql.len == 0) continue;
            _ = conn.exec(sql, .{}) catch |err| return pgError(conn, err);
        }
    }

    /// error.Conflict if the email is taken.
    pub fn createUser(self: *Db, email: []const u8, password_hash: []const u8) !i64 {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "insert into users (email, password_hash) values ($1, $2) returning id",
            .{ email, password_hash },
        ) catch |err| return pgError(conn, err)) orelse return error.Unexpected;
        defer row.deinit() catch {};
        return row.get(i64, 0);
    }

    pub fn getUserByEmail(self: *Db, arena: Allocator, email: []const u8) !?User {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "select id, email, password_hash from users where email = $1",
            .{email},
        ) catch |err| return pgError(conn, err)) orelse return null;
        defer row.deinit() catch {};
        return .{
            .id = try row.get(i64, 0),
            .email = try arena.dupe(u8, try row.get([]const u8, 1)),
            .password_hash = try arena.dupe(u8, try row.get([]const u8, 2)),
        };
    }

    pub fn createPost(
        self: *Db,
        arena: Allocator,
        author_id: i64,
        title: []const u8,
        base_slug: []const u8,
        body: []const u8,
    ) !Post {
        var n: usize = 1;
        while (true) : (n += 1) {
            const slug = try numberedSlug(arena, base_slug, n);
            const post = self.postRow(
                arena,
                "insert into posts (title, slug, body, author_id) values ($1, $2, $3, $4) " ++
                    "returning " ++ post_columns,
                .{ title, slug, body, author_id },
            ) catch |err| {
                if (err == error.Conflict and n < 50) continue;
                return err;
            };
            return post orelse error.Unexpected;
        }
    }

    pub fn updatePost(
        self: *Db,
        arena: Allocator,
        id: i64,
        title: []const u8,
        base_slug: []const u8,
        body: []const u8,
        published: bool,
    ) !Post {
        var n: usize = 1;
        while (true) : (n += 1) {
            const slug = try numberedSlug(arena, base_slug, n);
            const post = self.postRow(
                arena,
                // published_at is stamped the first time the post is published, then kept.
                "update posts set title = $2, slug = $3, body = $4, published = $5, " ++
                    "published_at = coalesce(published_at, case when $5 then now() end), " ++
                    "updated_at = now() where id = $1 returning " ++ post_columns,
                .{ id, title, slug, body, published },
            ) catch |err| {
                if (err == error.Conflict and n < 50) continue;
                return err;
            };
            return post orelse error.NotFound;
        }
    }

    pub fn listPublished(self: *Db, arena: Allocator) ![]PostSummary {
        var conn = try self.pool.acquire();
        defer conn.release();
        var result = conn.query(
            "select " ++ summary_columns ++ " from posts where published order by published_at desc",
            .{},
        ) catch |err| return pgError(conn, err);
        defer result.deinit();

        var out: std.ArrayList(PostSummary) = .empty;
        while (try result.next()) |row| {
            try out.append(arena, .{
                .id = try row.get(i64, 0),
                .title = try arena.dupe(u8, try row.get([]const u8, 1)),
                .slug = try arena.dupe(u8, try row.get([]const u8, 2)),
                .excerpt = try arena.dupe(u8, try row.get([]const u8, 3)),
                .published_at = try dupeOptional(arena, try row.get(?[]const u8, 4)),
            });
        }
        return out.items;
    }

    pub fn getPublishedBySlug(self: *Db, arena: Allocator, slug: []const u8) !?Post {
        return self.postRow(
            arena,
            "select " ++ post_columns ++ " from posts where slug = $1 and published",
            .{slug},
        );
    }

    /// `id_param` is the raw path segment; anything that is not an integer
    /// simply does not name a post.
    pub fn getPostById(self: *Db, arena: Allocator, id_param: []const u8) !?Post {
        const id = std.fmt.parseInt(i64, id_param, 10) catch return null;
        return self.postRow(arena, "select " ++ post_columns ++ " from posts where id = $1", .{id});
    }

    pub fn deletePost(self: *Db, id: i64) !void {
        var conn = try self.pool.acquire();
        defer conn.release();
        _ = conn.exec("delete from posts where id = $1", .{id}) catch |err|
            return pgError(conn, err);
    }

    /// Runs a query returning at most one post (selected with post_columns).
    fn postRow(self: *Db, arena: Allocator, sql: []const u8, args: anytype) !?Post {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(sql, args) catch |err| return pgError(conn, err)) orelse return null;
        defer row.deinit() catch {};
        return .{
            .id = try row.get(i64, 0),
            .title = try arena.dupe(u8, try row.get([]const u8, 1)),
            .slug = try arena.dupe(u8, try row.get([]const u8, 2)),
            .body = try arena.dupe(u8, try row.get([]const u8, 3)),
            .published = try row.get(bool, 4),
            .author_id = try row.get(i64, 5),
            .created_at = try arena.dupe(u8, try row.get([]const u8, 6)),
            .updated_at = try arena.dupe(u8, try row.get([]const u8, 7)),
            .published_at = try dupeOptional(arena, try row.get(?[]const u8, 8)),
        };
    }
};

fn dupeOptional(arena: Allocator, value: ?[]const u8) !?[]const u8 {
    return if (value) |v| try arena.dupe(u8, v) else null;
}

/// `base`, then `base-2`, `base-3`, ... for retries after a slug collision.
fn numberedSlug(arena: Allocator, base: []const u8, n: usize) ![]const u8 {
    if (n == 1) return base;
    return std.fmt.allocPrint(arena, "{s}-{d}", .{ base, n });
}

/// Unique violations become error.Conflict; anything else is logged.
fn pgError(conn: *pg.Conn, err: anyerror) anyerror {
    if (conn.err) |pg_err| {
        if (pg_err.isUnique()) return error.Conflict;
        std.log.err("postgres: {s}", .{pg_err.message});
    }
    return err;
}
