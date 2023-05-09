const std = @import("std");
const cat = @import("str.zig").strcat;
//const cat = str.strcat;
const BufStr = @import("BufStr.zig");
const join = std.fs.path.join;
const concat = std.mem.concat;
const Build = std.Build;
const RunStep = Build.RunStep;
const Board = @import("Board.zig");
const DeviceTree = @This();
const s = std.fs.path.sep_str;

cpp: *RunStep,
def: *RunStep,
kconf: *RunStep,
dtzig: *RunStep,

pub fn create(b: *Build, zdir: BufStr, board: Board) DeviceTree {
    const cpp = b.addSystemCommand(&.{
        b.zig_exe,
        "cc",
        "-xassembler-with-cpp",
        "-nostdinc",
    });
    const cpp_ = StepAdapter.create(cpp);
    var buf: [128]u8 = undefined;
    // TODO add revision overlays if exist
    cpp.addArg("-isystem");
    cpp_.addDir(zdir.cat("/include"));
    cpp.addArg("-isystem");
    cpp_.addDir(zdir.cat("/include/zephyr"));
    cpp.addArg("-isystem");
    cpp_.addDir(zdir.cat("/dts/common"));
    cpp.addArg("-isystem");
    cpp_.addDir(zdir.cat_slices(&.{ "/dts/", board.arch }));
    cpp.addArg("-isystem");
    cpp_.addDir(zdir.cat("/dts"));
    cpp.addArg("-include");
    cpp_.addFile(cat(&buf, &.{ board.dir, s, board.name, ".dts" })); // dts_files
    // TODO add shields and overlays
    cpp.addArg("-undef"); // NOSYSDEF_CFLAG
    cpp.addArg("-D__DTS__");
    // DTS_EXTRA_CPPFLAGS is not defined
    cpp.addArg("-E"); //   Stop after preprocessing
    cpp.addArg("-MD"); //  Generate a dependency file as a side-effect
    cpp.addArg("-MF"); //
    const deps = cpp.addOutputFileArg("zephyr.dts.d"); // DTS_DEPS
    cpp.addArg("-o");
    const post_cpp = cpp.addOutputFileArg("zephyr.dts.pre"); // DTS_POST_CPP
    cpp_.addFile(zdir.cat("/misc/empty_file.c"));

    _ = deps;

    // GEN_DEFINES
    const def = b.addSystemCommand(&.{"python"});
    const def_ = StepAdapter.create(def);
    def_.addFile(zdir.cat("/scripts/dts/gen_defines.py"));
    def.addArg("--dts");
    def.addFileSourceArg(post_cpp);
    def.addArg("--dtc-flags");
    def.addArg("'-Wno-simple_bus_reg'");
    def.addArg("--bindings-dirs");
    def_.addDir(zdir.cat("/dts/bindings"));
    def.addArg("--header-out");
    const generated_h = def.addOutputFileArg("devicetree_generated.h");
    def.addArg("--dts-out");
    const zephyr_dts = def.addOutputFileArg("zephyr.dts");
    def.addArg("--edt-pickle-out");
    const edt_pickle = def.addOutputFileArg("edt.pickle");
    def.addArg("--vendor-prefixes");
    def_.addFile(zdir.cat("/dts/bindings/vendor-prefixes.txt"));

    def.step.dependOn(&cpp.step);

    const kconf = b.addSystemCommand(&.{"python"});
    const kconf_ = StepAdapter.create(kconf);
    kconf_.addFile(zdir.cat("/scripts/dts/gen_driver_kconfig_dts.py"));
    kconf.addArg("--kconfig-out");
    const kconfig = kconf.addOutputFileArg("Kconfig.dts");
    kconf.addArg("--bindings-dirs");
    kconf_.addDir(zdir.cat("/dts/bindings"));

    kconf.step.dependOn(&def.step);

    const dtzig = b.addSystemCommand(&.{"python"});
    const dtzig_ = StepAdapter.create(dtzig);
    dtzig_.addFile("gen_dts_zig.py");
    dtzig.addArg("--edt-lib");
    dtzig_.addDir(zdir.cat("/scripts/dts/python-devicetree/src"));
    dtzig.addArg("--edt-pickle");
    dtzig.addFileSourceArg(edt_pickle);
    dtzig.addArg("--zig-out");
    const generated_zig = dtzig.addOutputFileArg("devicetree_generated.zig");

    dtzig.step.dependOn(&def.step);

    _ = generated_h;
    _ = generated_zig;
    _ = zephyr_dts;
    //_ = edt_pickle;
    _ = kconfig;

    //const edt_lib = try join(a, &.{ zephyr_base, "scripts/dts/python-devicetree/src" });
    // };

    return DeviceTree{ .cpp = cpp, .def = def, .kconf = kconf, .dtzig = dtzig };
}

const StepAdapter = struct {
    runStep: *RunStep,
    pub fn create(runStep: *RunStep) StepAdapter {
        return StepAdapter{ .runStep = runStep };
    }
    pub fn addDir(self: StepAdapter, str: []const u8) void {
        self.runStep.addDirectorySourceArg(.{ .path = str });
    }
    pub fn addFile(self: StepAdapter, str: []const u8) void {
        self.runStep.addFileSourceArg(.{ .path = str });
    }
};
