const std = @import("std");
const util = @import("./util.zig");
const String = @import("./deps/zig-string/zig-string.zig").String;

const Allocator = std.mem.Allocator;
const Vec = std.ArrayList;

pub const AstExpr = union(enum) {
    number: f64,
    string: []u8,
    ident: []u8,
    call: Vec(AstExpr),
    quoted: []AstExpr,

    pub fn deinit(self: AstExpr, allocator: Allocator) void {
        switch (self) {
            .number => {},
            .string => |s| allocator.free(s),
            .ident => |i| allocator.free(i),
            .call => |c| {
                var i: u32 = 0;
                while (i <= c.items.len) : (i += 1) {
                    c.items[i].deinit(allocator);
                }
                c.deinit();
            },
            .quoted => |c| {
                for (c) |e| {
                    e.deinit(allocator);
                }
                allocator.free(c);
            },
        }
    }

    pub fn print(self: AstExpr) void {
        const p = std.debug.print;
        switch (self) {
            .number => |n| p("number: {d}", .{n}),
            .string => |s| p("string: {s}", .{s}),
            .ident => |i| p("ident: {s}", .{i}),
            .call => |asts| {
                if (asts.items.len == 0) {
                    return;
                }

                p("function: ", .{});
                print(asts.items[0]);

                var i: u32 = 1;

                while (i <= asts.items.len) : (i += 1) {
                    p(" - ", .{});
                    print(asts.items[i]);
                }
            },
            .quoted => |asts| {
                p("list: ", .{});

                var i: u32 = 0;

                while (i <= asts.len) : (i += 1) {
                    p(" - ", .{});
                    print(asts[i]);
                }
            }
        }
    }
};

const ParseError = error {
    Empty,
    MissingClosingParan,
    UnclosedString,
} || String.Error;

pub fn parse_expr(inp: *String, allocator: Allocator) ParseError!AstExpr {
    inp.trim(" ");

    if (inp.isEmpty()) {
        return ParseError.Empty;
    }

    var str = inp.buffer orelse return ParseError.Empty;
    const len = str.len;

    // parse a call expression
    if (str[0] == '(') {
        return if (str[len - 1] == ')') {
            var sub = str[1..len-1];
            const subStr = util.StrFromU8(sub, inp.allocator);
            return try parseCall(subStr, allocator);
        }
        else ParseError.MissingClosingParan;
    }

    if(str[0] == '"') {
        var sub = str[1..];
        const subStr = util.StrFromU8(sub, inp.allocator);
        const end = subStr.find(&[_]u8{'"'}) orelse return ParseError.UnclosedString;

        return AstExpr { .string = str[1..end + 1]};
    }

    if (std.fmt.parseFloat(f64, str)) |f| {
        return AstExpr { .number = f };
    } else |_| {
        return AstExpr { .ident = str };
    }
}

fn parseCall(inp: String, allocator: Allocator) ParseError!AstExpr {
    var block: u64 = 0;
    var vec = Vec(AstExpr).init(allocator);

    while (try inp.splitToString(" ", block)) |*e| {
        const expr = try parse_expr(e, allocator);
        try vec.append(expr);
        block += 1;
    }

    return AstExpr {.call = vec};
}