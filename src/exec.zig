const std = @import("std");
const astT = @import("./ast.zig");
const AstExpr = astT.AstExpr;
const TakeError = astT.TakeError;
const Value = @import("./cells.zig").Value;

pub const EvalError = error {
    UnknownFunction,
    TypeMismatch,
    InvalidArgumentLength,
};

pub fn evaluate(ast: *const AstExpr) EvalError!Value {
    switch (ast.*) {
        .number => |n| return Value {.number = n },
        .string => |s| return Value {.string = s },
        .call => |cs| {
            if (cs.len == 0){ 
                return EvalError.UnknownFunction;
            }

            const fun = cs[0];

            return evalBuiltins(fun, cs[1..]);
        },
        else => return EvalError.UnknownFunction,
    }
}

// runs builtin commands/functions (+ - * == if)
pub fn evalBuiltins(function: AstExpr, args: []AstExpr) EvalError!Value {
    const fun = function.get_ident() catch return EvalError.UnknownFunction;

        // + operator
    if (std.mem.eql(u8, "+", fun)) {
        var sum: f64 = 0;

        for (args) |*a| {
            const val = try evaluate(a);
            sum += try val.get_number();
        }
        return Value { .number = sum };
        // - operator
    } else if (std.mem.eql(u8, "-", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try evaluate(&args[0]);
        var first: f64 = try r.get_number();

        for (args[1..]) |*a| {
            const val = try evaluate(a);
            first -= try val.get_number();
        }

        return Value { .number = first };
        // * operator
    } else if (std.mem.eql(u8, "*", fun)) {
        var prod: f64 = 1;

        for (args) |*a| {
            const val = try evaluate(a);
            prod *= try val.get_number();
        }
        return Value { .number = prod };
        // == operator
    } else if (std.mem.eql(u8, "/", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try evaluate(&args[0]);
        var first: f64 = try r.get_number();

        for (args[1..]) |*a| {
            const val = try evaluate(a);
            first /= try val.get_number();
        }

        return Value { .number = first };
        // equals operator
    } else if (std.mem.eql(u8, "==", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try evaluate(&args[0]);
        var first: f64 = try r.get_number();
        var result: bool = true;

        for (args[1..]) |*a| {
            const val = try evaluate(a);
            result = result and first == try val.get_number();
        }

        return Value { .boolean = result };
        // if expr e.g (if cond expr else-expr)
    } else if (std.mem.eql(u8, "if", fun)) {
        if (args.len != 3) {
            return EvalError.InvalidArgumentLength;
        }

        const val = try evaluate(&args[0]);
        const b = try val.get_bool();

        return if (b)
            evaluate(&args[1])
        else
            evaluate(&args[2]);
    }

    return EvalError.UnknownFunction;
}