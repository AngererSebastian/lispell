const std = @import("std");
const util = @import("./util.zig");
const String = @import("../deps/zig-string/zig-string.zig").String;

const Allocator = std.mem.Allocator;
const Vec = std.ArrayList;

const AstExpr = union(enum) {
    number: f64,
    string: []u8,
    ident: []u8,
    call: Vec(AstExpr),
    quoted: []AstExpr,

    pub fn deinit(self: AstExpr, allocator: Allocator) void {
        switch (self) {
            .string => |*s| allocator.free(s),
            .ident => |*i| allocator.free(i),
            .call => |*c| {
                for (c) |n| {
                    n.deinit(allocator);
                }
                allocator.free(c);
            },
            .quoted => |*c| {
                for (c) |n| {
                    n.deinit(allocator);
                }
                allocator.free(c);
            },
        }
    }
};

const ParseError = error {
    Empty,
    MissingClosingParan,
    UnclosedString,
};

pub fn parse_expr(inp: String, allocator: Allocator) ParseError!AstExpr {
    inp.trim(" ");

    if (inp.isEmpty()) {
        return ParseError.Empty;
    }

    const str = inp.str();
    const len = str.len;

    // parse a call expression
    if (str[0] == '(') {
        return if (str[len - 1] == ')') {
            const sub = str[1..len-1];
            const subStr = util.StrFromU8(sub, inp.allocator);
            parseCall(subStr);
        }
        else ParseError.MissingClosingParan;
    }

    if(str[0] == '"') {
        const sub = str[1..];
        const subStr = util.StrFromU8(sub, inp.allocator);
        const end = subStr.find([]u8{'"'}) orelse return ParseError.UnclosedString;

        return AstExpr { .string = str[1..end + 1]};
    }

    if (std.fmt.parseFloat(f64, str)) |f| {
        return AstExpr { .number = f };
    }


}

fn parseCall(inp: String, allocator: Allocator) ParseError!AstExpr {
    var block = 0;
    var vec = Vec(AstExpr).init(allocator);

    while (inp.splitToString(" ", block)) |e| {
        const expr = parse_expr(e, allocator);
        vec.insert(expr);
        block += 1;
    }

    return AstExpr {.call = vec};
}