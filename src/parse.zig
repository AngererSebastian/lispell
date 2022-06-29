const std = @import("std");
const strings = @import("./strings.zig");

const Allocator = std.mem.Allocator;
const Vec = std.ArrayList;
const AstExpr = @import("./ast.zig").AstExpr;


pub const ParseError = error {
    Empty,
    MissingClosingParan,
    InvalidNumber,
    OutOfMemory,
    UnclosedString,
};

fn ParseResult(comptime resultType: type) type {
    return struct {
        result: resultType,
        remaining: []const u8,
    };
}

const AstResult = ParseResult(AstExpr);

pub fn parse_expr(inp: []const u8, allocator: Allocator) ParseError!AstResult {
    const str = strings.trimWhiteSpace(inp);
    std.debug.print("parsing expr: {s}\n", .{str});

    if (str.len == 0) {
        return ParseError.Empty;
    }

    // parse a call expression
    if (str[0] == '(') {
        const end = findClosingParan(str) catch return ParseError.MissingClosingParan;
        var sub = str[1..end];
        const res =  try parseCall(sub, allocator);
        return AstResult {
            .result = res.result,
            .remaining = if (end < str.len)
                            str[end+1..]
                         else ""
        };
    }

    if(str[0] == '"') {
        var sub = str[1..];
        const end = strings.find(sub, '"') catch return ParseError.UnclosedString;

        return AstResult {
            .result = AstExpr { .string = str[1..end + 1]},
            .remaining = str[end+1..]
        };
    }

    const endNumber = findNonNumberChar(str) catch str.len;
    if (endNumber != 0) {
        std.debug.print("parsing {d} chars \"{s}\" as number\n", .{endNumber, str[0..endNumber]});
        const num = std.fmt.parseFloat(f64, str[0..endNumber]) catch return ParseError.InvalidNumber;
        return AstResult {
            .result = AstExpr { .number = num },
            .remaining = str[endNumber..],
        };
    } else {
        std.debug.print("parsing {s} as identifier\n", .{str});
        const identEnd = strings.findWhitespace(str) 
                catch strings.find(str, ')')
                catch str.len;

        return AstResult {
            .result = AstExpr { .ident = str[0..identEnd] },
            .remaining = str[identEnd..],
        };
    }
}

fn parseCall(inp: []const u8, allocator: Allocator) ParseError!AstResult {
    var str = strings.trimWhiteSpace(inp);
    var vec = Vec(AstExpr).init(allocator);

    while (str.len != 0) {
        const r= try parse_expr(str, allocator);
        try vec.append(r.result);
        str = r.remaining;
    }

    return AstResult {
        .result = AstExpr { .call = vec.toOwnedSlice() },
        .remaining = inp
    };
}

fn findNonNumberChar(str: []const u8) strings.FindError!usize {
    var result: usize = 0;

    while(result < str.len 
        and (isNumber(str[result]) 
        or str[result] == '.')) 
        : (result += 1) { }

    if (result < str.len) {
        return result;
    }
    else {
        return strings.FindError.NotFound;
    }
}

fn findClosingParan(str: []const u8) strings.FindError!usize {
    var openings: usize = 0;

    for (str) |c, i| {
        //std.debug.print("c: {c}, openings: {d}\n", .{c, openings});
        switch (c) {
            '(' => openings += 1,
            ')' => {
                openings -= 1;
                if (openings == 0) {
                    return i;
                }
            },

            else => {}
        }
    }

    return strings.FindError.NotFound;
}

fn isNumber(c: u8) bool {
    return c >= '0'
       and c <= '9';
}