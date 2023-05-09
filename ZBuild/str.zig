const std = @import("std");
const mem = std.mem;
/// Copies each T from slices into a new slice that exactly holds all the elements as well as the sentinel.
pub fn bufcat(
    comptime T: type,
    buffer: []T,
    slices: []const []const T,
) []T {
    if (slices.len == 0) return &[0]T{};
    var buf_index: usize = 0;
    for (slices) |slice| {
        if (buffer.len - buf_index < slice.len) @panic("OOM");
        mem.copy(T, buffer[buf_index..], slice);
        buf_index += slice.len;
    }
    return buffer[0..buf_index];
}

pub fn strcat(buffer: []u8, slices: []const []const u8) []u8 {
    return bufcat(u8, buffer, slices);
}

const RootPath = struct {
    buffer: []const u8,
};
