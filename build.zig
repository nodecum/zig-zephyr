const builtin = @import("builtin");
const std = @import("std");
const ZBuild = @import("ZBuild.zig");
const Build = std.build.Builder;

const s = std.fs.path.sep_str;

fn root_dir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}

const project_binary_dir = root_dir() ++ s ++ "zbuild";
// dts.cmake sets this
const binary_dir_include = project_binary_dir ++ s ++ "include";
const binary_dir_include_generated = binary_dir_include ++ s ++ "generated";

pub fn build(b: *Build) !void {
    const zbuild = try ZBuild.create(b, .{
        .zephyr_base = "/home/robert/prog/zephyrproject/zephyr",
        .board = "adafruit_feather_nrf52840",
    });

    _ = zbuild;
    //const optimize = b.standardOptimizeOption(.{});
    //const target = b.standardTargetOptions(.{});

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    //if (b.args) |args| {
    //    run_cmd.addArgs(args);
    //}

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    //const run_step = b.step("run", "Run the app");
    //run_step.dependOn(&run_cmd.step);

    //const all_step = b.step("all", "Build everything and runs all tests");
    //all_step.dependOn(test_step);
    //b.default_step.dependOn(all_step);
}
