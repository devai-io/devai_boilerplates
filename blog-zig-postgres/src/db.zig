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
    author_id: i64,
    created_at: i64, // unix seconds
    updated_at: i64,
};

pub const PostSummary = struct {
    id: i64,
    title: []const u8,
    slug: []const u8,
    excerpt: []const u8,
    published_at: i64,
};

pub const PostUpdate = struct {
    title: ?[]const u8 = null,
    body: ?[]const u8 = null,
    published: ?bool = null,
};

const post_columns =
    "id, title, slug, body, published, author_id, " ++
    "extract(epoch from created_at)::bigint, extract(epoch from updated_at)::bigint";

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
            _ = conn.exec(sql, .{}) catch |err| return logPgError(conn, err);
        }
    }

    pub fn createUser(self: *Db, email: []const u8, password_hash: []const u8) !i64 {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "insert into users (email, password_hash) values ($1, $2) returning id",
            .{ email, password_hash },
        ) catch |err| return conflictOr(conn, err)) orelse return error.Unexpected;
        defer row.deinit() catch {};
        return row.get(i64, 0);
    }

    pub fn getUserByEmail(self: *Db, arena: Allocator, email: []const u8) !?User {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "select id, email, password_hash from users where email = $1",
            .{email},
        ) catch |err| return logPgError(conn, err)) orelse return null;
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
        slug: []const u8,
        body: []const u8,
    ) !Post {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "insert into posts (title, slug, body, author_id) values ($1, $2, $3, $4) " ++
                "returning " ++ post_columns,
            .{ title, slug, body, author_id },
        ) catch |err| return conflictOr(conn, err)) orelse return error.Unexpected;
        defer row.deinit() catch {};
        return readPost(arena, &row);
    }

    pub fn listPublished(self: *Db, arena: Allocator) ![]PostSummary {
        var conn = try self.pool.acquire();
        defer conn.release();
        var result = conn.query(
            "select id, title, slug, left(body, 200), extract(epoch from created_at)::bigint " ++
                "from posts where published order by created_at desc",
            .{},
        ) catch |err| return logPgError(conn, err);
        defer result.deinit();

        var out: std.ArrayList(PostSummary) = .empty;
        while (try result.next()) |row| {
            try out.append(arena, .{
                .id = try row.get(i64, 0),
                .title = try arena.dupe(u8, try row.get([]const u8, 1)),
                .slug = try arena.dupe(u8, try row.get([]const u8, 2)),
                .excerpt = try arena.dupe(u8, try row.get([]const u8, 3)),
                .published_at = try row.get(i64, 4),
            });
        }
        return out.items;
    }

    pub fn getPublishedBySlug(self: *Db, arena: Allocator, slug: []const u8) !?Post {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "select " ++ post_columns ++ " from posts where slug = $1 and published",
            .{slug},
        ) catch |err| return logPgError(conn, err)) orelse return null;
        defer row.deinit() catch {};
        return try readPost(arena, &row);
    }

    /// `id_param` is the raw path segment; anything that is not an integer
    /// simply does not name a post.
    pub fn getPostById(self: *Db, arena: Allocator, id_param: []const u8) !?Post {
        const id = std.fmt.parseInt(i64, id_param, 10) catch return null;
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "select " ++ post_columns ++ " from posts where id = $1",
            .{id},
        ) catch |err| return logPgError(conn, err)) orelse return null;
        defer row.deinit() catch {};
        return try readPost(arena, &row);
    }

    pub fn updatePost(self: *Db, arena: Allocator, id: i64, changes: PostUpdate) !Post {
        var conn = try self.pool.acquire();
        defer conn.release();
        var row = (conn.row(
            "update posts set title = coalesce($2, title), body = coalesce($3, body), " ++
                "published = coalesce($4, published), updated_at = now() " ++
                "where id = $1 returning " ++ post_columns,
            .{ id, changes.title, changes.body, changes.published },
        ) catch |err| return logPgError(conn, err)) orelse return error.NotFound;
        defer row.deinit() catch {};
        return readPost(arena, &row);
    }

    pub fn deletePost(self: *Db, id: i64) !void {
        var conn = try self.pool.acquire();
        defer conn.release();
        _ = conn.exec("delete from posts where id = $1", .{id}) catch |err|
            return logPgError(conn, err);
    }
};

fn readPost(arena: Allocator, row: anytype) !Post {
    return .{
        .id = try row.get(i64, 0),
        .title = try arena.dupe(u8, try row.get([]const u8, 1)),
        .slug = try arena.dupe(u8, try row.get([]const u8, 2)),
        .body = try arena.dupe(u8, try row.get([]const u8, 3)),
        .published = try row.get(bool, 4),
        .author_id = try row.get(i64, 5),
        .created_at = try row.get(i64, 6),
        .updated_at = try row.get(i64, 7),
    };
}

fn conflictOr(conn: *pg.Conn, err: anyerror) anyerror {
    if (conn.err) |pg_err| {
        if (pg_err.isUnique()) return error.Conflict;
        std.log.err("postgres: {s}", .{pg_err.message});
    }
    return err;
}

fn logPgError(conn: *pg.Conn, err: anyerror) anyerror {
    if (conn.err) |pg_err| std.log.err("postgres: {s}", .{pg_err.message});
    return err;
}
