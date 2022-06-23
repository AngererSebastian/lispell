const std = @import("std");
const String = @import("./deps/zig-string/zig-string.zig").String;
const Allocator = std.mem.Allocator;

// Safety: from needs to be allocated by the same Allocator
pub fn StrFromU8(from: []u8, allocator: *Allocator) String {
    return .{
        .buffer = from,
        .allocator = allocator,
        .size = from.len
    };
}