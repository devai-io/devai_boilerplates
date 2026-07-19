//! Drop-in Auth0 access-token verifier: validates RS256 JWTs against your
//! tenant's JWKS using only std.crypto, and checks issuer + audience. See the
//! README next to this file for how to wire it in (drop into src/ as auth0.zig).

const std = @import("std");
const Allocator = std.mem.Allocator;
const rsa = std.crypto.Certificate.rsa;
const Sha256 = std.crypto.hash.sha2.Sha256;
const b64 = std.base64.url_safe_no_pad;

pub const Verifier = struct {
    gpa: Allocator,
    io: std.Io,
    /// "https://{AUTH0_DOMAIN}/" — Auth0 issues `iss` with a trailing slash.
    issuer: []const u8,
    /// Your API identifier (AUTH0_AUDIENCE).
    audience: []const u8,
    jwks_url: []const u8,
    mutex: std.Thread.Mutex = .{},
    keys_arena: std.heap.ArenaAllocator,
    keys: []const Jwk = &.{},

    const Jwk = struct { kid: []const u8, n: []const u8, e: []const u8 };

    /// `domain` is the bare tenant domain, e.g. "your-tenant.us.auth0.com".
    /// The returned Verifier borrows nothing; strings are duped into `gpa`.
    pub fn init(gpa: Allocator, io: std.Io, domain: []const u8, audience: []const u8) !Verifier {
        return .{
            .gpa = gpa,
            .io = io,
            .issuer = try std.fmt.allocPrint(gpa, "https://{s}/", .{domain}),
            .audience = try gpa.dupe(u8, audience),
            .jwks_url = try std.fmt.allocPrint(gpa, "https://{s}/.well-known/jwks.json", .{domain}),
            .keys_arena = std.heap.ArenaAllocator.init(gpa),
        };
    }

    pub fn deinit(self: *Verifier) void {
        self.gpa.free(self.issuer);
        self.gpa.free(self.audience);
        self.gpa.free(self.jwks_url);
        self.keys_arena.deinit();
    }

    /// Validates signature, expiry, issuer and audience; returns the Auth0
    /// user id (`sub`, e.g. "auth0|abc123") allocated in `arena`. Thread-safe.
    pub fn verify(self: *Verifier, arena: Allocator, token: []const u8) ![]const u8 {
        var parts = std.mem.splitScalar(u8, token, '.');
        const header_b64 = parts.next() orelse return error.InvalidToken;
        const payload_b64 = parts.next() orelse return error.InvalidToken;
        const sig_b64 = parts.next() orelse return error.InvalidToken;
        if (parts.next() != null) return error.InvalidToken;

        const header = std.json.parseFromSliceLeaky(struct {
            alg: []const u8 = "",
            kid: []const u8 = "",
        }, arena, try decodeB64(arena, header_b64), .{
            .ignore_unknown_fields = true,
        }) catch return error.InvalidToken;
        if (!std.mem.eql(u8, header.alg, "RS256")) return error.InvalidToken;

        const jwk = (try self.findKey(arena, header.kid)) orelse blk: {
            // Unknown kid: the tenant may have rotated keys. Refetch once.
            try self.refresh();
            break :blk (try self.findKey(arena, header.kid)) orelse return error.UnknownKey;
        };

        const signing_input = token[0 .. header_b64.len + 1 + payload_b64.len];
        try verifyRs256(arena, jwk, signing_input, sig_b64);

        const payload = std.json.parseFromSliceLeaky(
            std.json.Value,
            arena,
            try decodeB64(arena, payload_b64),
            .{},
        ) catch return error.InvalidToken;
        const claims = switch (payload) {
            .object => |o| o,
            else => return error.InvalidToken,
        };

        const exp = switch (claims.get("exp") orelse return error.InvalidToken) {
            .integer => |v| v,
            else => return error.InvalidToken,
        };
        if (exp <= std.Io.Clock.now(.real, self.io).toSeconds()) return error.TokenExpired;

        const iss = switch (claims.get("iss") orelse return error.InvalidToken) {
            .string => |s| s,
            else => return error.InvalidToken,
        };
        if (!std.mem.eql(u8, iss, self.issuer)) return error.WrongIssuer;

        // `aud` may be a single string or an array of strings.
        const aud_ok = switch (claims.get("aud") orelse return error.InvalidToken) {
            .string => |s| std.mem.eql(u8, s, self.audience),
            .array => |arr| blk: {
                for (arr.items) |item| switch (item) {
                    .string => |s| if (std.mem.eql(u8, s, self.audience)) break :blk true,
                    else => {},
                };
                break :blk false;
            },
            else => false,
        };
        if (!aud_ok) return error.WrongAudience;

        const sub = switch (claims.get("sub") orelse return error.InvalidToken) {
            .string => |s| s,
            else => return error.InvalidToken,
        };
        return arena.dupe(u8, sub);
    }

    fn findKey(self: *Verifier, arena: Allocator, kid: []const u8) !?Jwk {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.keys) |key| {
            if (!std.mem.eql(u8, key.kid, kid)) continue;
            // Copy out so a concurrent refresh can't free it under us.
            return .{
                .kid = try arena.dupe(u8, key.kid),
                .n = try arena.dupe(u8, key.n),
                .e = try arena.dupe(u8, key.e),
            };
        }
        return null;
    }

    fn refresh(self: *Verifier) !void {
        var body: std.Io.Writer.Allocating = .init(self.gpa);
        defer body.deinit();
        var client: std.http.Client = .{ .allocator = self.gpa, .io = self.io };
        defer client.deinit();
        const result = client.fetch(.{
            .location = .{ .url = self.jwks_url },
            .response_writer = &body.writer,
        }) catch return error.JwksFetchFailed;
        if (result.status != .ok) return error.JwksFetchFailed;

        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.keys_arena.reset(.free_all);
        const aa = self.keys_arena.allocator();

        const jwks = std.json.parseFromSliceLeaky(struct {
            keys: []const struct {
                kty: []const u8 = "",
                kid: []const u8 = "",
                n: []const u8 = "",
                e: []const u8 = "",
            },
        }, aa, body.written(), .{ .ignore_unknown_fields = true }) catch
            return error.JwksInvalid;

        var list: std.ArrayList(Jwk) = .empty;
        for (jwks.keys) |key| {
            if (!std.mem.eql(u8, key.kty, "RSA")) continue;
            if (key.kid.len == 0 or key.n.len == 0 or key.e.len == 0) continue;
            try list.append(aa, .{ .kid = key.kid, .n = key.n, .e = key.e });
        }
        self.keys = list.items;
    }
};

fn verifyRs256(arena: Allocator, jwk: Verifier.Jwk, signing_input: []const u8, sig_b64: []const u8) !void {
    var modulus = try decodeB64(arena, jwk.n);
    while (modulus.len > 0 and modulus[0] == 0) modulus = modulus[1..];
    const exponent = try decodeB64(arena, jwk.e);
    const sig = try decodeB64(arena, sig_b64);
    if (sig.len != modulus.len) return error.InvalidSignature;

    const key = rsa.PublicKey.fromBytes(exponent, modulus) catch return error.InvalidKey;
    switch (modulus.len) {
        256 => rsa.PKCS1v1_5Signature.verify(256, sig[0..256].*, signing_input, key, Sha256) catch
            return error.InvalidSignature,
        384 => rsa.PKCS1v1_5Signature.verify(384, sig[0..384].*, signing_input, key, Sha256) catch
            return error.InvalidSignature,
        512 => rsa.PKCS1v1_5Signature.verify(512, sig[0..512].*, signing_input, key, Sha256) catch
            return error.InvalidSignature,
        else => return error.UnsupportedKeySize,
    }
}

fn decodeB64(arena: Allocator, s: []const u8) ![]u8 {
    const len = b64.Decoder.calcSizeForSlice(s) catch return error.InvalidToken;
    const out = try arena.alloc(u8, len);
    b64.Decoder.decode(out, s) catch return error.InvalidToken;
    return out;
}
