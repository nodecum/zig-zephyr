const std = @import("std");
// const yaml = @import("libs/zig-yaml/src/yaml.zig");
const BufStr = @import("ZBuild/BufStr.zig");
const fs = std.fs;
const Build = std.Build;
const RunStep = Build.RunStep;
const ZBuild = @This();

const Board = @import("ZBuild/Board.zig");
const DeviceTree = @import("ZBuild/DeviceTree.zig");

const s = fs.path.sep_str;

//build: *Build,

//config_file: []const u8,
//zephyr_base: []const u8,
//board_name: []const u8,

pub const Options = struct {
    //config_file: ?[]const u8 = null,
    zephyr_base: ?[]const u8 = null,
    board: ?[]const u8 = null,
};

pub fn create(b: *Build, options: Options) !ZBuild {
    //const self = try b.allocator.create(ZBuild);
    //const config_file = options.config_file orelse
    //    build.option([]const u8, "config_file", "Configuration YAML File") orelse "config.yaml";
    //readToEndAlloc
    //const cfg_str = try fs.cwd().readFileAlloc(build.allocator, config_file, 2048);

    const try_zephyr_base = options.zephyr_base orelse
        b.option([]const u8, "zephyr_base", "Path to Base of Zephyr") orelse "";
    // check if the given path exists, transform it to an absolute path
    const zephyr_base = std.fs.cwd().realpathAlloc(b.allocator, try_zephyr_base) catch |err| {
        std.debug.print(
            "Could not find the given Zephyr base directory\n{s}\n error:{s}\n",
            .{ try_zephyr_base, @errorName(err) },
        );
        return error.InvalidArgs;
    };
    var zdir_buf: [128]u8 = undefined;
    const zdir = BufStr.create(&zdir_buf, zephyr_base);
    const board_name = options.board orelse
        b.option(
        []const u8,
        "board",
        "Target Board for which we building the Application",
    ) orelse "";

    const board = try Board.create(b, zdir, board_name);

    const listBoards = Board.list(b, zdir);
    const listBoardsTrigger = b.step("boards", "print available boards");
    listBoardsTrigger.dependOn(&listBoards.step);

    const dt = DeviceTree.create(b, zdir, board);

    const dtTriggerStep = b.step("dt", "build device tree");
    dtTriggerStep.dependOn(&dt.kconf.step);
    dtTriggerStep.dependOn(&dt.dtzig.step);
    return ZBuild{};
}
