const std = @import("std");
const equal = std.mem.eql;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const cells = @import("./cells.zig");
const Value = cells.Value;
const Type = cells.Type;

const eval = @import("./exec.zig");
const EvalState = eval.EvalState;
const EvalError = eval.EvalError;

const astT = @import("./ast.zig");
const AstExpr = astT.AstExpr;

pub fn evalBuiltins(self: *EvalState, function: AstExpr, args: []AstExpr) EvalError!Value {
    const fun = function.get_ident() catch return EvalError.UnknownFunction;

    if (equal(u8, "==", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try self.evaluate(&args[0]);
        var first: f64 = try r.get_number();
        var result: bool = true;

        for (args[1..]) |*a| {
            const val = try self.evaluate(a);
            result = result and first == try val.get_number();
        }

        return Value { .boolean = result };
        // if expr e.g (if cond expr else-expr)
    } else if (equal(u8, "if", fun)) {
        if (args.len != 3) {
            return EvalError.InvalidArgumentLength;
        }

        const val = try self.evaluate(&args[0]);
        const b = try val.get_bool();

        return if (b)
            self.evaluate(&args[1])
        else
            self.evaluate(&args[2]);
    } else if (equal(u8, "fn", fun)) {
        return process_function(args, self.allo);
    }

    return arith_functions(self, fun, args);
}

pub fn arith_functions(self: *EvalState, fun: []const u8, args: []AstExpr) EvalError!Value {
    if (equal(u8, "+", fun)) {
        var sum: f64 = 0;

        for (args) |*a| {
            const val = try self.evaluate(a);
            sum += try val.get_number();
        }
        return Value { .number = sum };
        // - operator
    } else if (equal(u8, "-", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try self.evaluate(&args[0]);
        var first: f64 = try r.get_number();

        for (args[1..]) |*a| {
            const val = try self.evaluate(a);
            first -= try val.get_number();
        }

        return Value { .number = first };
        // * operator
    } else if (equal(u8, "*", fun)) {
        var prod: f64 = 1;

        for (args) |*a| {
            const val = try self.evaluate(a);
            prod *= try val.get_number();
        }
        return Value { .number = prod };
        // == operator
    } else if (equal(u8, "/", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try self.evaluate(&args[0]);
        var first: f64 = try r.get_number();

        for (args[1..]) |*a| {
            const val = try self.evaluate(a);
            first /= try val.get_number();
        }

        return Value { .number = first };
    }

    return EvalError.UnknownFunction;
}

fn process_function(atoms: []AstExpr, allo: Allocator) EvalError!Value {
    if (atoms.len != 2)
        return EvalError.InvalidArgumentLength;

    const args = try atoms[0].get_call();
    const expr = atoms[1];

    var vargs = ArrayList([]const u8).init(allo);

    for (args) |a| {
        const arg = try a.get_ident();
        try vargs.append(arg);
    }

    const function = cells.Function {
        .args = vargs.toOwnedSlice(),
        .body = expr
    };

    return Value {.function = function};
}