const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = std.Build.createModule(b, .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .strip = false,
    });

    const exe = b.addExecutable(.{
        .name = "zb",
        .root_module = module,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "run the application");
    run_step.dependOn(&run_cmd.step);

    const tests_module = std.Build.createModule(b, .{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .strip = false,
    });

    const tests = b.addTest(.{
        .root_module = tests_module,
        .target = target,
        .optimize = optimize,
        .name = "Unit Tests",
    });
    tests.test_server_mode = false;

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
