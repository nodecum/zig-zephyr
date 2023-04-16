const builtin = @import("builtin");
const std = @import("std");

const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mecha_module = b.createModule(.{
        .source_file = .{ .path = "libs/mecha/mecha.zig" },
    });

    const test_step = b.step("test", "Run all tests in all modes.");

    const kconfig_tests = b.addTest(.{
        .root_source_file = .{ .path = "tools/kconfig.zig" },
        .optimize = optimize,
        .target = target,
    });
    kconfig_tests.addModule("mecha", mecha_module);
    test_step.dependOn(&kconfig_tests.run().step);

    const exe = b.addExecutable(.{
        .name = "kconfig",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "tools/kconfig.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("mecha", mecha_module);
    exe.install();
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(test_step);
    b.default_step.dependOn(all_step);
}

fn sdkPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("suffix must be an absolute path");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}
