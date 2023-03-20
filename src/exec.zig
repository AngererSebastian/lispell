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

const builtins = @import("./builtins.zig");

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

                return builtins.evalBuiltins(self, fun, cs[1..]) catch |err| {
                    if (err != EvalError.UnknownFunction)
                        return err;

                    return self.evalCustomFunction(fun, cs[1..]);
                };
            },
            .quoted => |list| {
                const ret = try self.allo.alloc(Value, list.len);

                for (list) |x, i| {
                    ret[i] = try self.evaluate(&x);
                }

                return Value {.list = ret};
            },
            .ident => |i| return self.state.get(i) orelse return EvalError.UnknownVariable,
            //else => return EvalError.UnknownFunction,
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