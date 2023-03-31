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
        const sum = try fold_ast(f64, self, 0, add_expr, args);
        return Value { .number = sum };
        // - operator
    } else if (equal(u8, "-", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try self.evaluate(&args[0]);
        var first: f64 = try r.get_number();

        const diff = try fold_ast(f64, self, first, sub_expr, args[1..]);
        return Value { .number = diff };
        // * operator
    } else if (equal(u8, "*", fun)) {
        const prod = try fold_ast(f64, self, 1, mult_expr, args);
        return Value { .number = prod };
        // / operator
    } else if (equal(u8, "/", fun)) {
        if (args.len == 0) {
            return EvalError.InvalidArgumentLength;
        }

        const r = try self.evaluate(&args[0]);
        var first: f64 = try r.get_number();

        const quotient = try fold_ast(f64, self, first, div_expr, args[1..]);
        return Value { .number = quotient };
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

fn Folder(comptime State: type) type {
    return *const fn(state: State, expr: Value) EvalError!State;
}

fn fold_ast(comptime State: type, evaluator: *EvalState, state: State, folder: Folder(State), exprs: []AstExpr) EvalError!State {
    var s = state;
    for (exprs) |*e| {
        if (e.get_quoted()) |l| {
            s = try fold_ast(State, evaluator, s, folder, l);
        } else |_| {
            const val = try evaluator.evaluate(e);
            s = try folder(s, val);
        }
    }

    return s;
}

fn add_expr(sum: f64, expr: Value) EvalError!f64 {
    return sum + try expr.get_number();
}

fn sub_expr(diff: f64, expr: Value) EvalError!f64 {
    return diff - try expr.get_number();
}

fn mult_expr(left: f64, expr: Value) EvalError!f64 {
    return left * try expr.get_number();
}

fn div_expr(left: f64, expr: Value) EvalError!f64 {
    return left / try expr.get_number();
}