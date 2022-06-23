const std = @import("std");
const Vec = std.ArrayList;
const Call = Vec(AstExpr);
const AstExpr = @import("./parse.zig").AstExpr;

const Type = enum {
    number,
    string,
    function,
};
const Value = union(Type) {
    number: f64,
    string: []const u8,
    function: Function,
};

const Function = struct {
    args: []struct {name: []const u8, type: Type},
    body: []const AstExpr,
};

pub fn exec(ast: *const AstExpr) AstExpr {

}

pub fn runBuiltins(call: Call) bool {
}