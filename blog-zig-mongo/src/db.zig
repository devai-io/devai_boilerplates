//! MongoDB access through the C driver (libmongoc) via @cImport. Ids are
//! ObjectId hex strings at the API boundary; all strings returned to handlers
//! are duped into the per-request arena.

const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @cImport({
    // Zig 0.16's translate-c can't parse libbson's `_Pragma` warning toggles
    // or glibc's fortified inline wrappers (on in release builds). Neither
    // changes a declaration, so switch both off for the import.
    @cDefine("_Pragma(x)", "");
    @cUndef("_FORTIFY_SOURCE");
    @cInclude("mongoc/mongoc.h");
});

pub const User = struct {
    id: []const u8,
    email: []const u8,
    password_hash: []const u8,
};

pub const Post = struct {
    id: []const u8,
    title: []const u8,
    slug: []const u8,
    body: []const u8,
    published: bool,
    published_at: ?[]const u8, // null until first published
    author_id: []const u8,
    created_at: []const u8, // RFC 3339, UTC
    updated_at: []const u8,
};

pub const Db = struct {
    io: std.Io,
    pool: *c.mongoc_client_pool_t,
    name: [:0]const u8,

    pub fn init(gpa: Allocator, io: std.Io, url: []const u8, name: []const u8) !Db {
        c.mongoc_init();

        const url_z = try gpa.dupeZ(u8, url);
        defer gpa.free(url_z);
        var berr: c.bson_error_t = undefined;
        const uri = c.mongoc_uri_new_with_error(url_z, &berr) orelse {
            std.log.err("invalid MONGO_URL: {s}", .{std.mem.sliceTo(&berr.message, 0)});
            return error.BadMongoUrl;
        };
        defer c.mongoc_uri_destroy(uri);

        // The pool copies the uri and is safe to use from many threads.
        const pool = c.mongoc_client_pool_new(uri) orelse return error.MongoInit;
        var db: Db = .{ .io = io, .pool = pool, .name = try gpa.dupeZ(u8, name) };
        try db.ensureIndexes();
        return db;
    }

    pub fn deinit(self: *Db, gpa: Allocator) void {
        c.mongoc_client_pool_destroy(self.pool);
        gpa.free(self.name);
        c.mongoc_cleanup();
    }

    /// Idempotent, so it runs on every startup.
    fn ensureIndexes(self: *Db) !void {
        try self.command(
            \\{ "createIndexes": "users", "indexes": [
            \\  { "key": { "email": 1 }, "name": "email_unique", "unique": true } ] }
        );
        try self.command(
            \\{ "createIndexes": "posts", "indexes": [
            \\  { "key": { "slug": 1 }, "name": "slug_unique", "unique": true },
            \\  { "key": { "published": 1, "published_at": -1 }, "name": "published_at_recent" } ] }
        );
    }

    fn command(self: *Db, json: [:0]const u8) !void {
        const client = c.mongoc_client_pool_pop(self.pool) orelse return error.DbUnavailable;
        defer c.mongoc_client_pool_push(self.pool, client);
        var berr: c.bson_error_t = undefined;
        const cmd = c.bson_new_from_json(json, -1, &berr) orelse return error.MongoInit;
        defer c.bson_destroy(cmd);
        if (!c.mongoc_client_write_command_with_opts(client, self.name, cmd, null, null, &berr))
            return mongoError(berr);
    }

    /// A pooled client plus a collection handle; release with deinit.
    const Coll = struct {
        pool: *c.mongoc_client_pool_t,
        client: *c.mongoc_client_t,
        coll: *c.mongoc_collection_t,

        fn deinit(self: Coll) void {
            c.mongoc_collection_destroy(self.coll);
            c.mongoc_client_pool_push(self.pool, self.client);
        }
    };

    fn collection(self: *Db, name: [:0]const u8) !Coll {
        const client = c.mongoc_client_pool_pop(self.pool) orelse return error.DbUnavailable;
        return .{
            .pool = self.pool,
            .client = client,
            .coll = c.mongoc_client_get_collection(client, self.name, name) orelse return error.DbUnavailable,
        };
    }

    /// error.Conflict if the email is taken.
    pub fn createUser(self: *Db, arena: Allocator, email: []const u8, password_hash: []const u8) ![]const u8 {
        const h = try self.collection("users");
        defer h.deinit();

        var oid: c.bson_oid_t = undefined;
        c.bson_oid_init(&oid, null);
        const doc = try newDoc();
        defer c.bson_destroy(doc);
        _ = c.bson_append_oid(doc, "_id", -1, &oid);
        appendStr(doc, "email", email);
        appendStr(doc, "password_hash", password_hash);
        _ = c.bson_append_date_time(doc, "created_at", -1, self.nowMillis());

        var berr: c.bson_error_t = undefined;
        if (!c.mongoc_collection_insert_one(h.coll, doc, null, null, &berr)) {
            if (berr.code == duplicate_key) return error.Conflict;
            return mongoError(berr);
        }
        return oidHex(arena, &oid);
    }

    pub fn getUserByEmail(self: *Db, arena: Allocator, email: []const u8) !?User {
        const h = try self.collection("users");
        defer h.deinit();

        const filter = try newDoc();
        defer c.bson_destroy(filter);
        appendStr(filter, "email", email);

        const doc = (try findOne(h.coll, filter)) orelse return null;
        defer c.bson_destroy(doc);
        return .{
            .id = try getOid(arena, doc, "_id"),
            .email = try getStr(arena, doc, "email"),
            .password_hash = try getStr(arena, doc, "password_hash"),
        };
    }

    pub fn createPost(
        self: *Db,
        arena: Allocator,
        author_id: []const u8,
        title: []const u8,
        base_slug: []const u8,
        body: []const u8,
    ) !Post {
        var author: c.bson_oid_t = undefined;
        try parseOid(&author, author_id);
        var oid: c.bson_oid_t = undefined;
        c.bson_oid_init(&oid, null);
        const now = self.nowMillis();

        const h = try self.collection("posts");
        defer h.deinit();

        var n: usize = 1;
        while (true) : (n += 1) {
            const slug = try numberedSlug(arena, base_slug, n);
            const doc = try newDoc();
            defer c.bson_destroy(doc);
            _ = c.bson_append_oid(doc, "_id", -1, &oid);
            appendStr(doc, "title", title);
            appendStr(doc, "slug", slug);
            appendStr(doc, "body", body);
            _ = c.bson_append_bool(doc, "published", -1, false);
            _ = c.bson_append_null(doc, "published_at", -1);
            _ = c.bson_append_oid(doc, "author_id", -1, &author);
            _ = c.bson_append_date_time(doc, "created_at", -1, now);
            _ = c.bson_append_date_time(doc, "updated_at", -1, now);

            var berr: c.bson_error_t = undefined;
            if (!c.mongoc_collection_insert_one(h.coll, doc, null, null, &berr)) {
                if (berr.code == duplicate_key and n < 50) continue;
                return mongoError(berr);
            }
            return .{
                .id = try oidHex(arena, &oid),
                .title = title,
                .slug = slug,
                .body = body,
                .published = false,
                .published_at = null,
                .author_id = author_id,
                .created_at = try rfc3339(arena, now),
                .updated_at = try rfc3339(arena, now),
            };
        }
    }

    /// Saves the post's title, body and published flag. Its slug gets `-2`,
    /// `-3`, ... appended while it collides; `slug`, `updated_at` and, on the
    /// first publish, `published_at` are updated in place.
    pub fn updatePost(self: *Db, arena: Allocator, post: *Post) !void {
        var oid: c.bson_oid_t = undefined;
        try parseOid(&oid, post.id);
        const now = self.nowMillis();
        const first_publish = post.published and post.published_at == null;

        const h = try self.collection("posts");
        defer h.deinit();

        const filter = try newDoc();
        defer c.bson_destroy(filter);
        _ = c.bson_append_oid(filter, "_id", -1, &oid);

        const base_slug = post.slug;
        var n: usize = 1;
        while (true) : (n += 1) {
            const slug = try numberedSlug(arena, base_slug, n);
            const update = try newDoc();
            defer c.bson_destroy(update);
            var set: c.bson_t = undefined;
            _ = c.bson_append_document_begin(update, "$set", -1, &set);
            appendStr(&set, "title", post.title);
            appendStr(&set, "slug", slug);
            appendStr(&set, "body", post.body);
            _ = c.bson_append_bool(&set, "published", -1, post.published);
            if (first_publish) _ = c.bson_append_date_time(&set, "published_at", -1, now);
            _ = c.bson_append_date_time(&set, "updated_at", -1, now);
            _ = c.bson_append_document_end(update, &set);

            var berr: c.bson_error_t = undefined;
            if (!c.mongoc_collection_update_one(h.coll, filter, update, null, null, &berr)) {
                if (berr.code == duplicate_key and n < 50) continue;
                return mongoError(berr);
            }
            post.slug = slug;
            post.updated_at = try rfc3339(arena, now);
            if (first_publish) post.published_at = post.updated_at;
            return;
        }
    }

    pub fn listPublished(self: *Db, arena: Allocator) ![]Post {
        const h = try self.collection("posts");
        defer h.deinit();

        const filter = try newDoc();
        defer c.bson_destroy(filter);
        _ = c.bson_append_bool(filter, "published", -1, true);
        var berr: c.bson_error_t = undefined;
        const opts = c.bson_new_from_json("{ \"sort\": { \"published_at\": -1 } }", -1, &berr) orelse
            return error.OutOfMemory;
        defer c.bson_destroy(opts);

        const cursor = c.mongoc_collection_find_with_opts(h.coll, filter, opts, null) orelse
            return error.DbUnavailable;
        defer c.mongoc_cursor_destroy(cursor);

        var out: std.ArrayList(Post) = .empty;
        var doc: ?*const c.bson_t = null;
        while (c.mongoc_cursor_next(cursor, @ptrCast(&doc))) {
            try out.append(arena, try parsePost(arena, doc.?));
        }
        if (c.mongoc_cursor_error(cursor, &berr)) return mongoError(berr);
        return out.items;
    }

    pub fn getPublishedBySlug(self: *Db, arena: Allocator, slug: []const u8) !?Post {
        const h = try self.collection("posts");
        defer h.deinit();

        const filter = try newDoc();
        defer c.bson_destroy(filter);
        appendStr(filter, "slug", slug);
        _ = c.bson_append_bool(filter, "published", -1, true);

        const doc = (try findOne(h.coll, filter)) orelse return null;
        defer c.bson_destroy(doc);
        return try parsePost(arena, doc);
    }

    /// `id_param` is the raw path segment; anything that is not a 24-char
    /// ObjectId hex string simply does not name a post.
    pub fn getPostById(self: *Db, arena: Allocator, id_param: []const u8) !?Post {
        var oid: c.bson_oid_t = undefined;
        parseOid(&oid, id_param) catch return null;

        const h = try self.collection("posts");
        defer h.deinit();

        const filter = try newDoc();
        defer c.bson_destroy(filter);
        _ = c.bson_append_oid(filter, "_id", -1, &oid);

        const doc = (try findOne(h.coll, filter)) orelse return null;
        defer c.bson_destroy(doc);
        return try parsePost(arena, doc);
    }

    pub fn deletePost(self: *Db, id: []const u8) !void {
        var oid: c.bson_oid_t = undefined;
        try parseOid(&oid, id);

        const h = try self.collection("posts");
        defer h.deinit();

        const filter = try newDoc();
        defer c.bson_destroy(filter);
        _ = c.bson_append_oid(filter, "_id", -1, &oid);

        var berr: c.bson_error_t = undefined;
        if (!c.mongoc_collection_delete_one(h.coll, filter, null, null, &berr))
            return mongoError(berr);
    }

    fn nowMillis(self: *Db) i64 {
        return std.Io.Clock.now(.real, self.io).toMilliseconds();
    }
};

const duplicate_key = 11000;

fn newDoc() !*c.bson_t {
    return c.bson_new() orelse error.OutOfMemory;
}

/// Runs the query and returns a copy of the first document (caller destroys
/// it), so the cursor can be closed before parsing.
fn findOne(coll: *c.mongoc_collection_t, filter: *const c.bson_t) !?*c.bson_t {
    const cursor = c.mongoc_collection_find_with_opts(coll, filter, null, null) orelse
        return error.DbUnavailable;
    defer c.mongoc_cursor_destroy(cursor);
    var doc: ?*const c.bson_t = null;
    if (c.mongoc_cursor_next(cursor, @ptrCast(&doc))) return c.bson_copy(doc);
    var berr: c.bson_error_t = undefined;
    if (c.mongoc_cursor_error(cursor, &berr)) return mongoError(berr);
    return null;
}

fn parsePost(arena: Allocator, doc: *const c.bson_t) !Post {
    return .{
        .id = try getOid(arena, doc, "_id"),
        .title = try getStr(arena, doc, "title"),
        .slug = try getStr(arena, doc, "slug"),
        .body = try getStr(arena, doc, "body"),
        .published = c.bson_iter_as_bool(&try find(doc, "published")),
        .published_at = try getOptionalDate(arena, doc, "published_at"),
        .author_id = try getOid(arena, doc, "author_id"),
        .created_at = try rfc3339(arena, c.bson_iter_date_time(&try find(doc, "created_at"))),
        .updated_at = try rfc3339(arena, c.bson_iter_date_time(&try find(doc, "updated_at"))),
    };
}

fn appendStr(doc: *c.bson_t, key: [:0]const u8, value: []const u8) void {
    _ = c.bson_append_utf8(doc, key, -1, value.ptr, @intCast(value.len));
}

fn find(doc: *const c.bson_t, key: [:0]const u8) !c.bson_iter_t {
    var iter: c.bson_iter_t = undefined;
    if (!c.bson_iter_init_find(&iter, doc, key)) return error.CorruptDocument;
    return iter;
}

fn getStr(arena: Allocator, doc: *const c.bson_t, key: [:0]const u8) ![]const u8 {
    var iter = try find(doc, key);
    var len: u32 = 0;
    const ptr = c.bson_iter_utf8(&iter, &len) orelse return error.CorruptDocument;
    return arena.dupe(u8, ptr[0..len]);
}

/// null when the field is missing or not a date (a post never published).
fn getOptionalDate(arena: Allocator, doc: *const c.bson_t, key: [:0]const u8) !?[]const u8 {
    var iter: c.bson_iter_t = undefined;
    if (!c.bson_iter_init_find(&iter, doc, key) or c.bson_iter_type(&iter) != c.BSON_TYPE_DATE_TIME) return null;
    return try rfc3339(arena, c.bson_iter_date_time(&iter));
}

fn getOid(arena: Allocator, doc: *const c.bson_t, key: [:0]const u8) ![]const u8 {
    var iter = try find(doc, key);
    return oidHex(arena, c.bson_iter_oid(&iter) orelse return error.CorruptDocument);
}

fn oidHex(arena: Allocator, oid: *const c.bson_oid_t) ![]const u8 {
    var buf: [25]u8 = undefined;
    c.bson_oid_to_string(oid, &buf);
    return arena.dupe(u8, buf[0..24]);
}

fn parseOid(oid: *c.bson_oid_t, hex: []const u8) !void {
    if (!c.bson_oid_is_valid(hex.ptr, hex.len)) return error.InvalidId;
    var buf: [25]u8 = undefined;
    @memcpy(buf[0..24], hex);
    buf[24] = 0;
    c.bson_oid_init_from_string(oid, &buf);
}

/// `base`, then `base-2`, `base-3`, ... for retries after a slug collision.
fn numberedSlug(arena: Allocator, base: []const u8, n: usize) ![]const u8 {
    if (n == 1) return base;
    return std.fmt.allocPrint(arena, "{s}-{d}", .{ base, n });
}

fn rfc3339(arena: Allocator, millis: i64) ![]const u8 {
    const t: std.time.epoch.EpochSeconds = .{ .secs = @intCast(@divFloor(millis, 1000)) };
    const date = t.getEpochDay().calculateYearDay();
    const month_day = date.calculateMonthDay();
    const time = t.getDaySeconds();
    return std.fmt.allocPrint(arena, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        date.year,              month_day.month.numeric(), month_day.day_index + 1,
        time.getHoursIntoDay(), time.getMinutesIntoHour(), time.getSecondsIntoMinute(),
    });
}

fn mongoError(berr: c.bson_error_t) anyerror {
    std.log.err("mongo: {s}", .{std.mem.sliceTo(&berr.message, 0)});
    return error.DbError;
}
