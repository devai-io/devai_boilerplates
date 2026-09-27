//! Minimal, self-contained JWT HS256 sign/verify on top of std.crypto.

const std = @import("std");
const Allocator = std.mem.Allocator;
const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const b64 = std.base64.url_safe_no_pad;

// base64url({"alg":"HS256","typ":"JWT"})
const header_b64 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9";

pub const Claims = struct {
    sub: []const u8,
    iat: i64 = 0,
    exp: i64,
};

pub fn sign(arena: Allocator, sub: []const u8, secret: []const u8, now: i64, ttl_seconds: i64) ![]u8 {
    const payload_json = try std.json.Stringify.valueAlloc(arena, Claims{
        .sub = sub,
        .iat = now,
        .exp = now + ttl_seconds,
    }, .{});

    const payload_b64 = try arena.alloc(u8, b64.Encoder.calcSize(payload_json.len));
    _ = b64.Encoder.encode(payload_b64, payload_json);

    const signing_input = try std.mem.join(arena, ".", &.{ header_b64, payload_b64 });

    var mac: [HmacSha256.mac_length]u8 = undefined;
    HmacSha256.create(&mac, signing_input, secret);
    const sig_b64 = try arena.alloc(u8, b64.Encoder.calcSize(mac.len));
    _ = b64.Encoder.encode(sig_b64, &mac);

    return std.mem.join(arena, ".", &.{ signing_input, sig_b64 });
}

pub const VerifyError = error{ InvalidToken, TokenExpired, OutOfMemory };

pub fn verify(arena: Allocator, token: []const u8, secret: []const u8, now: i64) VerifyError!Claims {
    var parts = std.mem.splitScalar(u8, token, '.');
    const header = parts.next() orelse return error.InvalidToken;
    const payload = parts.next() orelse return error.InvalidToken;
    const signature = parts.next() orelse return error.InvalidToken;
    if (parts.next() != null) return error.InvalidToken;

    // Pin the algorithm: anything but HS256 ("none", RS256, HS512, ...) is rejected.
    const alg = try parseSegment(struct { alg: []const u8 }, arena, header);
    if (!std.mem.eql(u8, alg.alg, "HS256")) return error.InvalidToken;

    var expected: [HmacSha256.mac_length]u8 = undefined;
    HmacSha256.create(&expected, token[0 .. header.len + 1 + payload.len], secret);
    var got: [HmacSha256.mac_length]u8 = undefined;
    const sig_len = b64.Decoder.calcSizeForSlice(signature) catch return error.InvalidToken;
    if (sig_len != got.len) return error.InvalidToken;
    b64.Decoder.decode(&got, signature) catch return error.InvalidToken;
    if (!std.crypto.timing_safe.eql([HmacSha256.mac_length]u8, got, expected))
        return error.InvalidToken;

    const claims = try parseSegment(Claims, arena, payload);
    if (claims.exp <= now) return error.TokenExpired;
    return claims;
}

/// Decodes one base64url token segment and parses its JSON into `T`.
fn parseSegment(comptime T: type, arena: Allocator, segment: []const u8) VerifyError!T {
    const len = b64.Decoder.calcSizeForSlice(segment) catch return error.InvalidToken;
    const json = try arena.alloc(u8, len);
    b64.Decoder.decode(json, segment) catch return error.InvalidToken;
    return std.json.parseFromSliceLeaky(T, arena, json, .{
        .ignore_unknown_fields = true,
    }) catch error.InvalidToken;
}
