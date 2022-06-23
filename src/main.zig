const std = @import("std");
const parse = @import("./parse.zig");
const String = @import("../deps/zig-string/zig-string.zig").String;
const allocator = std.heap.page_allocator; 

pub fn main() anyerror!void {
    var args = std.process.args();
    _ = args.skip();
    const file_name = if (args.next(allocator)) |file| 
        try file
     else {
        return;
    }; 
    defer allocator.free(file_name);

    std.log.info("The filename is {s}", .{file_name});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
