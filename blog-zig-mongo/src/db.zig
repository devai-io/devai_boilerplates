//! MongoDB access through the C driver (libmongoc) via @cImport. Ids are
//! ObjectId hex strings at the API boundary; all strings returned to handlers
//! are duped into the per-request arena.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const c = @cImport({
    @cInclude("mongoc/mongoc.h");
});

pub const User = struct {
    id: []const u8, // ObjectId hex
    email: []const u8,
    password_hash: []const u8,
};

pub const Post = struct {
    id: []const u8,
    title: []const u8,
    slug: []const u8,
    body: []const u8,
    published: bool,
    author_id: []const u8,
    created_at: i64, // unix seconds
    updated_at: i64,
};

pub const PostUpdate = struct {
    title: ?[]const u8 = null,
    body: ?[]const u8 = null,
    published: ?bool = null,
};

pub const Db = struct {
    gpa: Allocator,
    pool: *c.mongoc_client_pool_t,
    db_name: [:0]const u8,

    pub fn init(gpa: Allocator, mongo_url: []const u8, db_name: []const u8) !Db {
        c.mongoc_init();

        const url_z = try gpa.dupeZ(u8, mongo_url);
        defer gpa.free(url_z);

        var berr: c.bson_error_t = undefined;
        const uri = c.mongoc_uri_new_with_error(url_z.ptr, &berr);
        if (uri == null) {
            std.log.err("invalid MONGO_URL: {s}", .{std.mem.sliceTo(&berr.message, 0)});
            return error.BadMongoUrl;
        }
        defer c.mongoc_uri_destroy(uri);

        // The pool copies the uri and is safe to use from many threads.
        const pool = c.mongoc_client_pool_new(uri);
        if (pool == null) return error.MongoInit;

        const name_z = try gpa.dupeZ(u8, db_name);
        errdefer gpa.free(name_z);

        var db: Db = .{ .gpa = gpa, .pool = pool, .db_name = name_z };
        try db.ensureIndexes();
        return db;
    }

    pub fn deinit(self: *Db) void {
        c.mongoc_client_pool_destroy(self.pool);
        self.gpa.free(self.db_name);
        c.mongoc_cleanup();
    }

    fn ensureIndexes(self: *Db) !void {
        const client = c.mongoc_client_pool_pop(self.pool);
        if (client == null) return error.DbUnavailable;
        defer c.mongoc_client_pool_push(self.pool, client);
        try self.runDbCommand(client,
            \\{ "createIndexes": "users", "indexes": [ { "key": { "email": 1 }, "name": "email_unique", "unique": true } ] }
        );
        try self.runDbCommand(client,
            \\{ "createIndexes": "posts", "indexes": [ { "key": { "slug": 1 }, "name": "slug_unique", "unique": true } ] }
        );
    }

    fn runDbCommand(self: *Db, client: [*c]c.mongoc_client_t, json: [:0]const u8) !void {
        var berr: c.bson_error_t = undefined;
        const cmd = c.bson_new_from_json(json.ptr, -1, &berr);
        if (cmd == null) return error.MongoInit;
        defer c.bson_destroy(cmd);
        const database = c.mongoc_client_get_database(client, self.db_name.ptr);
        defer c.mongoc_database_destroy(database);
        if (!c.mongoc_database_write_command_with_opts(database, cmd, null, null, &berr)) {
            std.log.err("mongo: {s}", .{std.mem.sliceTo(&berr.message, 0)});
            return error.MongoInit;
        }
    }

    /// A pooled client plus a collection handle; release with deinit.
    const Coll = struct {
        db: *const Db,
        client: [*c]c.mongoc_client_t,
        coll: [*c]c.mongoc_collection_t,

        fn deinit(self: Coll) void {
            c.mongoc_collection_destroy(self.coll);
            c.mongoc_client_pool_push(self.db.pool, self.client);
        }
    };

    fn collection(self: *const Db, name: [:0]const u8) !Coll {
        const client = c.mongoc_client_pool_pop(self.pool);
        if (client == null) return error.DbUnavailable;
        return .{
            .db = self,
            .client = client,
            .coll = c.mongoc_client_get_collection(client, self.db_name.ptr, name.ptr),
        };
    }

    pub fn createUser(
        self: *Db,
        arena: Allocator,
        email: []const u8,
        password_hash: []const u8,
        now: i64,
    ) ![]const u8 {
        const h = try self.collection("users");
        defer h.deinit();

        var oid: c.bson_oid_t = undefined;
        c.bson_oid_init(&oid, null);

        const doc = c.bson_new();
        defer c.bson_destroy(doc);
        _ = c.bson_append_oid(doc, "_id", -1, &oid);
        appendStr(doc, "email", email);
        appendStr(doc, "password_hash", password_hash);
        _ = c.bson_append_int64(doc, "created_at", -1, now);

        var berr: c.bson_error_t = undefined;
        if (!c.mongoc_collection_insert_one(h.coll, doc, null, null, &berr)) {
            if (berr.code == 11000) return error.Conflict;
            return logMongo(berr);
        }
        return oidHex(arena, &oid);
    }

    pub fn getUserByEmail(self: *Db, arena: Allocator, email: []const u8) !?User {
        const h = try self.collection("users");
        defer h.deinit();

        const filter = c.bson_new();
        defer c.bson_destroy(filter);
        appendStr(filter, "email", email);

        const doc = (try findOne(h.coll, filter, null)) orelse return null;
        defer c.bson_destroy(doc);
        return User{
            .id = (try docOidHex(arena, doc, "_id")) orelse return error.CorruptDoc,
            .email = (try docStr(arena, doc, "email")) orelse return error.CorruptDoc,
            .password_hash = (try docStr(arena, doc, "password_hash")) orelse return error.CorruptDoc,
        };
    }

    pub fn createPost(
        self: *Db,
        arena: Allocator,
        author_id: []const u8,
        title: []const u8,
        slug: []const u8,
        body: []const u8,
        now: i64,
    ) !Post {
        var author_oid: c.bson_oid_t = undefined;
        try oidFromHex(arena, &author_oid, author_id);

        const h = try self.collection("posts");
        defer h.deinit();

        var oid: c.bson_oid_t = undefined;
        c.bson_oid_init(&oid, null);

        const doc = c.bson_new();
        defer c.bson_destroy(doc);
        _ = c.bson_append_oid(doc, "_id", -1, &oid);
        appendStr(doc, "title", title);
        appendStr(doc, "slug", slug);
        appendStr(doc, "body", body);
        _ = c.bson_append_bool(doc, "published", -1, false);
        _ = c.bson_append_oid(doc, "author_id", -1, &author_oid);
        _ = c.bson_append_int64(doc, "created_at", -1, now);
        _ = c.bson_append_int64(doc, "updated_at", -1, now);

        var berr: c.bson_error_t = undefined;
        if (!c.mongoc_collection_insert_one(h.coll, doc, null, null, &berr)) {
            if (berr.code == 11000) return error.Conflict;
            return logMongo(berr);
        }
        return Post{
            .id = try oidHex(arena, &oid),
            .title = title,
            .slug = slug,
            .body = body,
            .published = false,
            .author_id = author_id,
            .created_at = now,
            .updated_at = now,
        };
    }

    pub fn listPublished(self: *Db, arena: Allocator) ![]Post {
        const h = try self.collection("posts");
        defer h.deinit();

        const filter = c.bson_new();
        defer c.bson_destroy(filter);
        _ = c.bson_append_bool(filter, "published", -1, true);

        var berr: c.bson_error_t = undefined;
        const opts = c.bson_new_from_json(
            \\{ "sort": { "created_at": -1 } }
        , -1, &berr);
        defer c.bson_destroy(opts);

        const cursor = c.mongoc_collection_find_with_opts(h.coll, filter, opts, null);
        defer c.mongoc_cursor_destroy(cursor);

        var out: std.ArrayList(Post) = .empty;
        var doc: [*c]const c.bson_t = null;
        while (c.mongoc_cursor_next(cursor, &doc)) {
            try out.append(arena, try parsePost(arena, doc));
        }
        if (c.mongoc_cursor_error(cursor, &berr)) return logMongo(berr);
        return out.items;
    }

    pub fn getPublishedBySlug(self: *Db, arena: Allocator, slug: []const u8) !?Post {
        const h = try self.collection("posts");
        defer h.deinit();

        const filter = c.bson_new();
        defer c.bson_destroy(filter);
        appendStr(filter, "slug", slug);
        _ = c.bson_append_bool(filter, "published", -1, true);

        const doc = (try findOne(h.coll, filter, null)) orelse return null;
        defer c.bson_destroy(doc);
        return try parsePost(arena, doc);
    }

    /// `id_param` is the raw path segment; anything that is not a 24-char
    /// ObjectId hex string simply does not name a post.
    pub fn getPostById(self: *Db, arena: Allocator, id_param: []const u8) !?Post {
        var oid: c.bson_oid_t = undefined;
        oidFromHex(arena, &oid, id_param) catch return null;

        const h = try self.collection("posts");
        defer h.deinit();

        const filter = c.bson_new();
        defer c.bson_destroy(filter);
        _ = c.bson_append_oid(filter, "_id", -1, &oid);

        const doc = (try findOne(h.coll, filter, null)) orelse return null;
        defer c.bson_destroy(doc);
        return try parsePost(arena, doc);
    }

    pub fn updatePost(
        self: *Db,
        arena: Allocator,
        id: []const u8,
        changes: PostUpdate,
        now: i64,
    ) !Post {
        var oid: c.bson_oid_t = undefined;
        try oidFromHex(arena, &oid, id);

        const h = try self.collection("posts");
        defer h.deinit();

        const filter = c.bson_new();
        defer c.bson_destroy(filter);
        _ = c.bson_append_oid(filter, "_id", -1, &oid);

        const update = c.bson_new();
        defer c.bson_destroy(update);
        var set_doc: c.bson_t = undefined;
        _ = c.bson_append_document_begin(update, "$set", -1, &set_doc);
        if (changes.title) |title| appendStr(&set_doc, "title", title);
        if (changes.body) |body| appendStr(&set_doc, "body", body);
        if (changes.published) |published| _ = c.bson_append_bool(&set_doc, "published", -1, published);
        _ = c.bson_append_int64(&set_doc, "updated_at", -1, now);
        _ = c.bson_append_document_end(update, &set_doc);

        var berr: c.bson_error_t = undefined;
        if (!c.mongoc_collection_update_one(h.coll, filter, update, null, null, &berr))
            return logMongo(berr);

        return (try self.getPostById(arena, id)) orelse error.NotFound;
    }

    pub fn deletePost(self: *Db, arena: Allocator, id: []const u8) !void {
        var oid: c.bson_oid_t = undefined;
        try oidFromHex(arena, &oid, id);

        const h = try self.collection("posts");
        defer h.deinit();

        const filter = c.bson_new();
        defer c.bson_destroy(filter);
        _ = c.bson_append_oid(filter, "_id", -1, &oid);

        var berr: c.bson_error_t = undefined;
        if (!c.mongoc_collection_delete_one(h.coll, filter, null, null, &berr))
            return logMongo(berr);
    }
};

/// Runs the query and returns a copy of the first document (caller destroys),
/// so the cursor can be closed before parsing.
fn findOne(
    coll: [*c]c.mongoc_collection_t,
    filter: [*c]const c.bson_t,
    opts: [*c]const c.bson_t,
) !?*c.bson_t {
    const cursor = c.mongoc_collection_find_with_opts(coll, filter, opts, null);
    defer c.mongoc_cursor_destroy(cursor);
    var doc: [*c]const c.bson_t = null;
    if (c.mongoc_cursor_next(cursor, &doc)) return c.bson_copy(doc);
    var berr: c.bson_error_t = undefined;
    if (c.mongoc_cursor_error(cursor, &berr)) return logMongo(berr);
    return null;
}

fn parsePost(arena: Allocator, doc: [*c]const c.bson_t) !Post {
    return .{
        .id = (try docOidHex(arena, doc, "_id")) orelse return error.CorruptDoc,
        .title = (try docStr(arena, doc, "title")) orelse return error.CorruptDoc,
        .slug = (try docStr(arena, doc, "slug")) orelse return error.CorruptDoc,
        .body = (try docStr(arena, doc, "body")) orelse return error.CorruptDoc,
        .published = docBool(doc, "published") orelse false,
        .author_id = (try docOidHex(arena, doc, "author_id")) orelse return error.CorruptDoc,
        .created_at = docInt(doc, "created_at") orelse 0,
        .updated_at = docInt(doc, "updated_at") orelse 0,
    };
}

fn appendStr(doc: [*c]c.bson_t, key: [:0]const u8, value: []const u8) void {
    _ = c.bson_append_utf8(doc, key.ptr, -1, value.ptr, @intCast(value.len));
}

fn docStr(arena: Allocator, doc: [*c]const c.bson_t, key: [:0]const u8) !?[]const u8 {
    var iter: c.bson_iter_t = undefined;
    if (!c.bson_iter_init_find(&iter, doc, key.ptr)) return null;
    var len: u32 = 0;
    const ptr = c.bson_iter_utf8(&iter, &len);
    if (ptr == null) return null;
    return try arena.dupe(u8, ptr[0..len]);
}

fn docInt(doc: [*c]const c.bson_t, key: [:0]const u8) ?i64 {
    var iter: c.bson_iter_t = undefined;
    if (!c.bson_iter_init_find(&iter, doc, key.ptr)) return null;
    return c.bson_iter_as_int64(&iter);
}

fn docBool(doc: [*c]const c.bson_t, key: [:0]const u8) ?bool {
    var iter: c.bson_iter_t = undefined;
    if (!c.bson_iter_init_find(&iter, doc, key.ptr)) return null;
    return c.bson_iter_bool(&iter);
}

fn docOidHex(arena: Allocator, doc: [*c]const c.bson_t, key: [:0]const u8) !?[]const u8 {
    var iter: c.bson_iter_t = undefined;
    if (!c.bson_iter_init_find(&iter, doc, key.ptr)) return null;
    const oid = c.bson_iter_oid(&iter);
    if (oid == null) return null;
    return try oidHex(arena, oid);
}

fn oidHex(arena: Allocator, oid: [*c]const c.bson_oid_t) ![]const u8 {
    var buf: [25]u8 = undefined;
    c.bson_oid_to_string(oid, &buf);
    return arena.dupe(u8, buf[0..24]);
}

fn oidFromHex(arena: Allocator, oid: *c.bson_oid_t, hex: []const u8) !void {
    if (!c.bson_oid_is_valid(hex.ptr, hex.len)) return error.InvalidId;
    const hex_z = try arena.dupeZ(u8, hex);
    c.bson_oid_init_from_string(oid, hex_z.ptr);
}

fn logMongo(berr: c.bson_error_t) anyerror {
    std.log.err("mongo: {s}", .{std.mem.sliceTo(&berr.message, 0)});
    return error.DbError;
}
