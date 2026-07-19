const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pg = b.dependency("pg", .{ .target = target, .optimize = optimize });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "pg", .module = pg.module("pg") },
        },
    });
    // Makes `@embedFile("schema.sql")` work from src/ even though the file
    // lives at the repository root.
    mod.addAnonymousImport("schema.sql", .{ .root_source_file = b.path("schema.sql") });

    const exe = b.addExecutable(.{ .name = "blog", .root_module = mod });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the blog server");
    run_step.dependOn(&run_cmd.step);
}
