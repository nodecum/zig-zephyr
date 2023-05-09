const std = @import("std");
const BufStr = @import("BufStr.zig");
//const str = @import("str.zig");
//const cat = str.strcat;
const Build = std.Build;
const RunStep = Build.RunStep;
const s = std.fs.path.sep_str;
const Board = @This();

name: []const u8,
dir: []const u8,
arch: []const u8,

pub fn list(b: *Build, zdir: BufStr) *RunStep {
    const list_boards_script =
        zdir.cat("/scripts/list_boards.py");
    const cmd = b.addSystemCommand(&.{
        "python",
        list_boards_script,
        "--board-root",
        zdir.str(),
        "--arch-root",
        zdir.str(),
    });
    return cmd;
}

pub fn create(
    b: *Build,
    zdir: BufStr,
    board_name: []const u8,
) !Board {
    const archs = [_][]const u8{
        "arm",
        "arm64",
    };
    for (archs) |arch| {
        const dir = zdir.cat_slices(&.{ s ++ "boards" ++ s, arch, s, board_name });
        if (std.fs.accessAbsolute(dir, .{})) |_| {
            return Board{
                .name = board_name,
                .dir = b.dupe(dir),
                .arch = b.dupe(arch),
            };
        } else |_| {}
    }
    std.debug.print(
        "Could not find board: {s}\n in zephyr base:{s}\n",
        .{ zdir.str(), board_name },
    );
    return error.InvalidArgs;
}
