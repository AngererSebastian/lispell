const std = @import("std");
const parse = @import("./parse.zig");
const util = @import("./util.zig");
const String = @import("./deps/zig-string/zig-string.zig").String;
var allocator = std.heap.page_allocator; 

pub fn main() anyerror!void {
    var args = std.process.args();
    _ = args.skip();
    const file_name = if (args.next(allocator)) |file| 
        try file
     else {
        return;
    }; 
    defer allocator.free(file_name);

    var content = try std.fs.cwd().readFileAlloc(allocator, file_name, 4098);
    defer allocator.free(content);

    var string = String.init(&allocator);
    //const string = util.StrFromU8(content, @as(*@TypeOf(allocator), &allocator));
    const ast = try parse.parse_expr(&string, allocator);
    ast.print();
    defer ast.deinit(allocator);
    std.log.info("The filename is {s}", .{file_name});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
