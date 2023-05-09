const std = @import("std");
const mem = std.mem;
const BufStr = @This();

buffer: []u8,
head_index: usize = 0,

pub fn str(self: BufStr) []u8 {
    return self.buffer[0..self.head_index];
}

pub fn create(buffer: []u8, head: []const u8) BufStr {
    var bs = BufStr{ .buffer = buffer };
    const s = bs.cat(head);
    bs.head_index = s.len;
    return bs;
}

pub fn cat(self: BufStr, s: []const u8) []u8 {
    return cat_slices(self, &.{s});
}

pub fn cat_slices(self: BufStr, slices: []const []const u8) []u8 {
    var buf_index: usize = self.head_index;
    for (slices) |slice| {
        if (self.buffer.len - buf_index < slice.len) @panic("OOM");
        mem.copy(u8, self.buffer[buf_index..], slice);
        buf_index += slice.len;
    }
    return self.buffer[0..buf_index];
}
