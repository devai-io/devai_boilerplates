const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // System requirement: mongo-c-driver 1.x (found via pkg-config as
    // libmongoc-1.0 / libbson-1.0). See README.
    mod.linkSystemLibrary("mongoc-1.0", .{});
    mod.linkSystemLibrary("bson-1.0", .{});

    const exe = b.addExecutable(.{ .name = "blog", .root_module = mod });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the blog server");
    run_step.dependOn(&run_cmd.step);
}
