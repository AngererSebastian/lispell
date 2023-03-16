const std = @import("std");
const equal = std.mem.eql;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;


const astT = @import("./ast.zig");
const AstExpr = astT.AstExpr;
const TakeError = astT.TakeError;

const cells = @import("./cells.zig");
const Value = cells.Value;
const Type = cells.Type;

pub const EvalError = error {
    UnknownFunction,
    UnknownType,
    UnknownVariable,
    TypeMismatch,
    OutOfMemory,
    InvalidArgumentLength,
    InvalidFunction,
};

pub const EvalState = struct {
    const State = std.StringHashMap(Value);
    state: State,
    allo: Allocator,

    pub fn init(allocator: Allocator) @This() {
        return EvalState {
            .state = State.init(allocator),
            .allo = allocator
        };
    }
    pub fn deinit(self: @This()) void {
        for (self.state.keys()) |k| {
            self.allo.free(k);
        }

        self.state.deinit();
    }

    pub fn set(self: *@This(), name: []const u8, val: Value) !void {
        // TODO: make this case insensitive
        var key = try self.allo.alloc(u8, name.len);
        _ = std.ascii.lowerString(key, name);
        try self.state.put(key, val);
    }

    pub fn evaluate(self: *@This(), ast: *const AstExpr) EvalError!Value {
        switch (ast.*) {
            .number => |n| return Value {.number = n },
            .string => |s| return Value {.string = s },
            .call => |cs| {
                if (cs.len == 0){
                    return EvalError.UnknownFunction;
                }

                const fun = cs[0];

                return self.evalBuiltins(fun, cs[1..]) catch |err| {
                    if (err != EvalError.UnknownFunction)
                        return err;

                    return self.evalCustomFunction(fun, cs[1..]);
                };
            },
            .ident => |i| return self.state.get(i) orelse return EvalError.UnknownVariable,
            else => return EvalError.UnknownFunction,
        }
    }

    fn evalCustomFunction(self: *@This(), function: AstExpr, args: []AstExpr) EvalError!Value {
        const fun_value = try self.evaluate(&function);
        const fun = fun_value.get_function() catch |err| {
            if (err == EvalError.UnknownVariable)
                return EvalError.UnknownFunction
            else
                return err;
        };

        if (fun.args.len != args.len)
            return EvalError.InvalidArgumentLength;

        var state_backup = try self.allo.alloc(?Value, args.len);
        defer self.allo.free(state_backup);

        // prepare arguments
        for (args) |*arg, i| {
            const arg_name = fun.args[i];
            state_backup[i] = self.state.get(arg_name);

            const val = try self.evaluate(arg);

            try self.state.put(arg_name, val);
        }

        const result = self.evaluate(&fun.body);

        // reset the state
        for (state_backup) |bak, i| {
            if (bak) |val| {
                try self.state.put(fun.args[i], val);
            } else {
                _ = self.state.remove(fun.args[i]);
            }
        }
        return result;
    }

    // runs builtin commands/functions (+ - * == if)
    fn evalBuiltins(self: *@This(), function: AstExpr, args: []AstExpr) EvalError!Value {
        const fun = function.get_ident() catch return EvalError.UnknownFunction;

            // + operator
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
            // equals operator
        } else if (equal(u8, "==", fun)) {
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
            return self.process_function(args);
        }

        return EvalError.UnknownFunction;
    }

    fn process_function(self: *@This(), atoms: []AstExpr) EvalError!Value {
        if (atoms.len != 2)
            return EvalError.InvalidArgumentLength;

        const args = try atoms[0].get_call();
        const expr = atoms[1];

        var vargs = ArrayList([]const u8).init(self.allo);

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
};

fn name_to_type(name: []const u8) EvalError!Type {
    return if (equal(u8, "number", name))
        Type.number
    else if (equal(u8, "bool", name))
        Type.boolean
    else if (equal(u8, "string", name))
        Type.string
    else if (equal(u8, "function", name))
        Type.function
    else
        return EvalError.UnknownType;
}