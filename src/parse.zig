const std = @import("std");
const util = @import("./util.zig");
const strings = @import("./strings.zig");
const String = @import("./deps/zig-string/zig-string.zig").String;

const Allocator = std.mem.Allocator;
const Vec = std.ArrayList;

pub const AstExpr = union(enum) {
    number: f64,
    string: []const u8,
    ident: []const u8,
    call: Vec(AstExpr),
    quoted: []AstExpr,

    pub fn deinit(self: AstExpr, allocator: Allocator) void {
        switch (self) {
            .number => {},
            .string => {},
            .ident => {},
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

pub fn parse_expr(inp: []const u8, allocator: Allocator) ParseError!AstExpr {
    const str = strings.trimWhiteSpace(inp);
    std.debug.print("parsing: |{s}|\n", .{str});

    if (str.len == 0) {
        return ParseError.Empty;
    }

    const len = str.len;

    // parse a call expression
    if (str[0] == '(') {

        std.debug.print("len: {d}, [len - 1]: {c}\n", .{len, inp[len - 1]});
        return if (inp[len - 1] == ')') {
            var sub = inp[1..len-1];
            return try parseCall(sub, allocator);
        }
        else ParseError.MissingClosingParan;
    }

    if(str[0] == '"') {
        var sub = str[1..];
        //const end = subStr.find(&[_]u8{'"'}) orelse return ParseError.UnclosedString;
        const end = strings.find(sub, '"');

        return AstExpr { .string = str[1..end + 1]};
    }

    if (std.fmt.parseFloat(f64, str)) |f| {
        return AstExpr { .number = f };
    } else |_| {
        return AstExpr { .ident = str };
    }
}

fn parseCall(inp: []const u8, allocator: Allocator) ParseError!AstExpr {
    std.debug.print("parsing call\n", .{});
    var vec = Vec(AstExpr).init(allocator);
    var split = strings.split(inp, ' ');

    while (split.split) |e| {
        std.debug.print("parsing item\n", .{});
        const expr = try parse_expr(e, allocator);
        try vec.append(expr);
        split = strings.splitWhiteSpace(split.rest);
    }

    return AstExpr {.call = vec};
}