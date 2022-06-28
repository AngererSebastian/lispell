const std = @import("std");
const astT = @import("./ast.zig");
const AstExpr = astT.AstExpr;
const TakeError = astT.TakeError;

const Type = enum {
    number,
    string,
    boolean,
    function,
};
const Value = union(Type) {
    number: f64,
    string: []const u8,
    boolean: bool,
    function: Function,

    pub fn print(self: Value) void {
        switch (self) {
            .number => |n| std.debug.print("{d}", .{n}),
            .string => |s| std.debug.print("\"{s}\"", .{s}),
            .boolean => |b| std.debug.print("{b}", .{b}),
            .function => std.debug.print("function", .{}),
        }
    }

    fn get_number(self: Value) TakeError!f64 {
        switch (self) {
            .number => |n| return n,
            else => return TakeError.TypeMismatch,
        }
    }
};

const ExecError = error {
    UnknownFunction,
    TypeMismatch,
};

const Function = struct {
    args: []struct {name: []const u8, type: Type},
    body: []const AstExpr,
};

pub fn exec(ast: *const AstExpr) ExecError!Value {
    switch (ast.*) {
        .number => |n| return Value {.number = n },
        .string => |s| return Value {.string = s },
        .call => |cs| {
            if (cs.len == 0){ 
                return ExecError.UnknownFunction;
            }

            const fun = cs[0];

            return runBuiltins(fun, cs[1..]);
        },
        else => return ExecError.UnknownFunction,
    }
}

pub fn runBuiltins(function: AstExpr, args: []AstExpr) ExecError!Value {
    const fun = function.get_ident() catch return ExecError.UnknownFunction;

    if (std.mem.eql(u8, "+", fun)) {
        var sum: f64 = 0;

        for (args) |*a| {
            const val = try exec(a);
            sum += try val.get_number();
        }
        return Value { .number = sum };
    } else if (std.mem.eql(u8, "-", fun)) {
        if (args.len == 0) {
            return ExecError.TypeMismatch;
        }

        const r = try exec(&args[0]);
        var first: f64 = try r.get_number();

        for (args[1..]) |*a| {
            const val = try exec(a);
            first -= try val.get_number();
        }

        return Value { .number = first };
    }

    return ExecError.UnknownFunction;
}