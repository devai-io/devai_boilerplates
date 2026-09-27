//! Drop-in Auth0 access-token verifier: checks RS256 JWTs against your
//! tenant's JWKS using only std, including issuer and audience. See the
//! README next to this file for how to wire it in.

const std = @import("std");
const Allocator = std.mem.Allocator;
const rsa = std.crypto.Certificate.rsa;
const Sha256 = std.crypto.hash.sha2.Sha256;
const b64 = std.base64.url_safe_no_pad;

/// Tolerated clock skew between Auth0 and this server, in seconds.
const leeway = 5;

pub const Verifier = struct {
    gpa: Allocator,
    io: std.Io,
    /// "https://{AUTH0_DOMAIN}/" — Auth0 issues `iss` with a trailing slash.
    issuer: []const u8,
    /// Your API identifier (AUTH0_AUDIENCE).
    audience: []const u8,
    jwks_url: []const u8,
    mutex: std.Io.Mutex = .init,
    keys_arena: std.heap.ArenaAllocator,
    keys: []const Jwk = &.{},
    fetched_at: i64 = 0,

    const Jwk = struct { kid: []const u8, n: []const u8, e: []const u8 };

    /// `domain` is the bare tenant domain, e.g. "your-tenant.us.auth0.com".
    pub fn init(gpa: Allocator, io: std.Io, domain: []const u8, audience: []const u8) !Verifier {
        return .{
            .gpa = gpa,
            .io = io,
            .issuer = try std.fmt.allocPrint(gpa, "https://{s}/", .{domain}),
            .audience = try gpa.dupe(u8, audience),
            .jwks_url = try std.fmt.allocPrint(gpa, "https://{s}/.well-known/jwks.json", .{domain}),
            .keys_arena = .init(gpa),
        };
    }

    pub fn deinit(self: *Verifier) void {
        self.gpa.free(self.issuer);
        self.gpa.free(self.audience);
        self.gpa.free(self.jwks_url);
        self.keys_arena.deinit();
    }

    /// Checks the signature, `exp`, `nbf`, issuer and audience; returns the
    /// Auth0 user id (`sub`, e.g. "auth0|abc123") allocated in `arena`.
    /// Thread-safe.
    pub fn verify(self: *Verifier, arena: Allocator, token: []const u8) ![]const u8 {
        var parts = std.mem.splitScalar(u8, token, '.');
        const header_b64 = parts.next() orelse return error.InvalidToken;
        const payload_b64 = parts.next() orelse return error.InvalidToken;
        const sig_b64 = parts.next() orelse return error.InvalidToken;
        if (parts.next() != null) return error.InvalidToken;

        const header = try parseSegment(struct { alg: []const u8, kid: []const u8 }, arena, header_b64);
        if (!std.mem.eql(u8, header.alg, "RS256")) return error.InvalidToken;

        const jwk = (try self.findKey(arena, header.kid)) orelse blk: {
            // Unknown kid: the tenant may have rotated its keys.
            try self.refresh();
            break :blk (try self.findKey(arena, header.kid)) orelse return error.UnknownKey;
        };
        try verifyRs256(arena, jwk, token[0 .. header_b64.len + 1 + payload_b64.len], sig_b64);

        const claims = try parseSegment(struct {
            sub: []const u8,
            exp: i64,
            nbf: i64 = 0,
            iss: []const u8,
            aud: std.json.Value, // a string or an array of strings
        }, arena, payload_b64);
        const now = std.Io.Clock.now(.real, self.io).toSeconds();
        if (claims.exp + leeway <= now or claims.nbf - leeway > now) return error.TokenExpired;
        if (!std.mem.eql(u8, claims.iss, self.issuer)) return error.WrongIssuer;
        if (!self.audienceMatches(claims.aud)) return error.WrongAudience;
        return claims.sub;
    }

    fn audienceMatches(self: *const Verifier, aud: std.json.Value) bool {
        switch (aud) {
            .string => |s| return std.mem.eql(u8, s, self.audience),
            .array => |list| for (list.items) |item| switch (item) {
                .string => |s| if (std.mem.eql(u8, s, self.audience)) return true,
                else => {},
            },
            else => {},
        }
        return false;
    }

    fn findKey(self: *Verifier, arena: Allocator, kid: []const u8) !?Jwk {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
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

    /// Refetches the JWKS, at most once a minute so tokens with made-up kids
    /// can't turn every request into a call to Auth0.
    fn refresh(self: *Verifier) !void {
        const now = std.Io.Clock.now(.real, self.io).toSeconds();
        {
            self.mutex.lockUncancelable(self.io);
            defer self.mutex.unlock(self.io);
            if (now - self.fetched_at < 60) return;
            self.fetched_at = now;
        }

        var body: std.Io.Writer.Allocating = .init(self.gpa);
        defer body.deinit();
        var client: std.http.Client = .{ .allocator = self.gpa, .io = self.io };
        defer client.deinit();
        const result = client.fetch(.{
            .location = .{ .url = self.jwks_url },
            .response_writer = &body.writer,
        }) catch return error.JwksFetchFailed;
        if (result.status != .ok) return error.JwksFetchFailed;

        var arena: std.heap.ArenaAllocator = .init(self.gpa);
        errdefer arena.deinit();
        const jwks = std.json.parseFromSliceLeaky(struct {
            keys: []const struct { kty: []const u8 = "", kid: []const u8 = "", n: []const u8 = "", e: []const u8 = "" },
        }, arena.allocator(), body.written(), .{ .ignore_unknown_fields = true }) catch
            return error.JwksInvalid;
        var keys: std.ArrayList(Jwk) = .empty;
        for (jwks.keys) |key| {
            if (!std.mem.eql(u8, key.kty, "RSA") or key.kid.len == 0) continue;
            try keys.append(arena.allocator(), .{ .kid = key.kid, .n = key.n, .e = key.e });
        }

        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        self.keys_arena.deinit();
        self.keys_arena = arena;
        self.keys = keys.items;
    }
};

fn verifyRs256(arena: Allocator, jwk: Verifier.Jwk, signing_input: []const u8, sig_b64: []const u8) !void {
    var modulus = try decode(arena, jwk.n);
    while (modulus.len > 0 and modulus[0] == 0) modulus = modulus[1..];
    const exponent = try decode(arena, jwk.e);
    const sig = try decode(arena, sig_b64);
    if (sig.len != modulus.len) return error.InvalidSignature;

    const key = rsa.PublicKey.fromBytes(exponent, modulus) catch return error.InvalidKey;
    switch (modulus.len) {
        inline 256, 384, 512 => |len| rsa.PKCS1v1_5Signature.verify(len, sig[0..len].*, signing_input, key, Sha256) catch
            return error.InvalidSignature,
        else => return error.UnsupportedKeySize,
    }
}

/// Decodes one base64url token segment and parses its JSON into `T`.
fn parseSegment(comptime T: type, arena: Allocator, segment: []const u8) !T {
    return std.json.parseFromSliceLeaky(T, arena, try decode(arena, segment), .{
        .ignore_unknown_fields = true,
    }) catch error.InvalidToken;
}

fn decode(arena: Allocator, s: []const u8) ![]u8 {
    const len = b64.Decoder.calcSizeForSlice(s) catch return error.InvalidToken;
    const out = try arena.alloc(u8, len);
    b64.Decoder.decode(out, s) catch return error.InvalidToken;
    return out;
}
