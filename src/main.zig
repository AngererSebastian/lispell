const std = @import("std");
const parse = @import("./parse.zig");
const cells = @import("./cells.zig");
var allocator = std.heap.page_allocator;

pub fn main() anyerror!void {
    var args = std.process.args();
    _ = args.skip();
    const file_name = args.next() orelse return;

    var content = try std.fs.cwd().readFileAlloc(allocator, file_name, 4098);
    defer allocator.free(content);

    const table = try cells.Table.from(content, allocator);

    const out = try table.format(allocator);
    defer allocator.free(out);

    std.debug.print("\nOutput: \n------------\n{s}", .{out});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
