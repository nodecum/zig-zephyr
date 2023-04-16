const mecha = @import("mecha");
const std = @import("std");
const testing = std.testing;

pub fn toString(allocator: std.mem.Allocator, tuple: anytype) mecha.Error![]const u8 {
    var i: usize = 0;
    inline for (tuple) |t|
        i += t.len;
    var buf = try allocator.alloc(u8, i);
    i = 0;
    inline for (tuple) |t| {
        const s = t.len;
        std.mem.copy(u8, buf[i .. i + s], t);
        i += s;
    }
    return buf[0..];
}

test "convert" {
    var buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();
    const parser1 = comptime mecha.convert(toString, mecha.combine(.{
        mecha.asStr(mecha.string("123")),
        mecha.asStr(mecha.string("456")),
    }));
    try expectResult([]const u8, .{ .value = "123456" }, parser1(allocator, "123456"));
}

// parse an unset config key
const unsetConfig = mecha.convert(toString, mecha.combine(.{
    mecha.mapConst(".", mecha.string("# CONFIG_")),
    mecha.many(
        mecha.ascii.not(mecha.ascii.char(' ')),
        .{ .min = 1, .collect = false },
    ),
    mecha.mapConst("=false,", mecha.string(" is not set")),
}));

test "unsetConfig" {
    var buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();
    //    const allocator = testing.failing_allocator;
    try expectResult(
        mecha.ParserResult(@TypeOf(unsetConfig)),
        .{ .value = ".FOO=false,", .rest = "" },
        unsetConfig(allocator, "# CONFIG_FOO is not set"),
    );
}
// parse a seted config key
const setConfig = mecha.convert(toString, mecha.combine(.{
    mecha.mapConst(".", mecha.string("CONFIG_")),
    mecha.many(
        mecha.ascii.not(mecha.ascii.char('=')),
        .{ .min = 1, .collect = false },
    ),
    mecha.asStr(mecha.ascii.char('=')),
    mecha.oneOf(.{
        mecha.mapConst(
            @as([]const u8, "true"),
            mecha.combine(.{
                mecha.ascii.char('y'),
                mecha.eos,
            }),
        ),
        mecha.rest,
    }),
    mecha.mapConst(",", mecha.noop),
}));

test "setConfig" {
    var buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    //const allocator = testing.failing_allocator;
    try expectResult(
        mecha.ParserResult(@TypeOf(setConfig)),
        .{ .value = ".FOO=true,", .rest = "" },
        setConfig(allocator, "CONFIG_FOO=y"),
    );
    try expectResult(
        mecha.ParserResult(@TypeOf(setConfig)),
        .{ .value = ".FOO=0x200,", .rest = "" },
        setConfig(allocator, "CONFIG_FOO=0x200"),
    );
    try expectResult(
        mecha.ParserResult(@TypeOf(setConfig)),
        .{ .value = ".FOO=\"yes\",", .rest = "" },
        setConfig(allocator, "CONFIG_FOO=\"yes\""),
    );
}

// parse a commented line
const comment = mecha.convert(toString, mecha.combine(.{
    mecha.mapConst("//", mecha.ascii.char('#')),
    mecha.rest,
}));

// empty line
const emptyLine = mecha.convert(toString, mecha.combine(.{
    mecha.mapConst("", mecha.discard(mecha.many(mecha.oneOf(.{
        mecha.utf8.char(0x0020),
        mecha.utf8.char(0x000A),
        mecha.utf8.char(0x000D),
        mecha.utf8.char(0x0009),
    }), .{ .collect = false }))),
}));

const configLine = mecha.oneOf(.{
    unsetConfig,
    setConfig,
    comment,
    emptyLine,
});

test "configLine" {
    var buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    try expectResult(
        []const u8,
        .{ .value = ".FOO=true,", .rest = "" },
        configLine(allocator, "CONFIG_FOO=y"),
    );
    try expectResult(
        []const u8,
        .{ .value = "// une comment", .rest = "" },
        configLine(allocator, "# une comment"),
    );
}

pub fn expectResult(
    comptime T: type,
    m_expect: mecha.Error!mecha.Result(T),
    m_actual: mecha.Error!mecha.Result(T),
) !void {
    const expect = m_expect catch |err| {
        try testing.expectError(err, m_actual);
        return;
    };
    const actual = try m_actual;
    try testing.expectEqualStrings(expect.rest, actual.rest);
    try expectEqualValues(expect.value, actual.value);
}

fn expectEqualValues(
    expect: anytype,
    actual: anytype,
) !void {
    const T = @TypeOf(actual);
    switch (T) {
        []const u8 => try testing.expectEqualStrings(expect, actual),
        else => switch (@typeInfo(T)) {
            .Struct => |s| inline for (s.fields) |field| {
                try expectEqualValues(
                    @field(expect, field.name),
                    @field(actual, field.name),
                );
            },
            else => try testing.expectEqual(expect, actual),
        },
    }
}

pub fn translateKConfig(in_fn: []const u8, out_fn: []const u8) !void {
    var buf: [1024]u8 = undefined;
    std.debug.print("in_fn: {s}\n", .{in_fn});

    const cwd = std.fs.cwd();
    std.debug.print("path: {s}\n", .{try cwd.realpath(".", &buf)});
    const in_file = cwd.openFile(in_fn, .{ .mode = .read_only }) catch |err| {
        std.debug.print("error opening file{s}:\n {s}\n", .{
            in_fn,
            @errorName(err),
        });
        return;
    };
    defer in_file.close();
    const out_file = cwd.createFile(out_fn, .{ .read = true, .truncate = true }) catch |err| {
        std.debug.print("error opening file{s}:\n {s}\n", .{
            out_fn,
            @errorName(err),
        });
        return;
    };
    defer out_file.close();

    var in_buf_reader = std.io.bufferedReader(in_file.reader());
    var in_stream = in_buf_reader.reader();

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const out_writer = out_file.writer();
    var lineNr: usize = 1;
    try out_writer.print("const config = .{{\n", .{});
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        defer lineNr += 1;
        if (configLine(allocator, line)) |res| {
            defer allocator.free(res.value);
            try out_writer.print("{s}\n", .{res.value});
        } else |err| {
            std.debug.print(
                "parse error at line {d}:\n{s}\n",
                .{ lineNr, @errorName(err) },
            );
        }
    }
    try out_writer.print("}};\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("usage: kconfig <.config-input-file> <zig-output-file>\n", .{});
        return;
    }
    try translateKConfig(args[1], args[2]);

    //std.debug.print("Arguments: {s}\n", .{args});

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    //std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    //const allocator = testing.failing_allocator;
    //const res = setConfig(allocator, "CONFIG_FOO=y");
    //const exp = .{ .value = .{ .@"0" = "FOO", .@"1" = "true" }, .rest = {} };
    //try stdout.print("Parse Result an expected:\n{any}\n", .{res});

    //   try bw.flush(); // don't forget to flush!
}
