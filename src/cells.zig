const std = @import("std");
const exec = @import("./exec.zig");
const ast = @import("./ast.zig");
const parse = @import("./parse.zig");

const ArrayList = std.ArrayList;
const TakeError = ast.TakeError;
const AstExpr = ast.AstExpr;
const Allocator = std.mem.Allocator;

pub const Type = enum {
    number,
    string,
    boolean,
    function,
};

pub const Value = union(Type) {
    number: f64,
    string: []const u8,
    boolean: bool,
    function: Function,

    pub fn print(self: Value) void {
        var buf: [256]u8 = undefined;
        _ = self.format(buf[0..]) catch return;
        std.debug.print("{s}", .{buf});
    }

    pub fn format(self: Value, buf: []u8) std.fmt.BufPrintError!usize {
        switch (self) {
            .number => |n| return (try std.fmt.bufPrint(buf, "{d}", .{n})).len,
            .string => |s| {
                std.mem.copy(u8, buf[1..s.len-1], s);
                buf[0] = '"';
                buf[s.len - 1] = '"';
                return s.len;
            },
            .boolean => |b| return (try std.fmt.bufPrint(buf, "{b}", .{b})).len,
            .function => {
                const fun = "function";
                std.mem.copy(u8, buf,fun);
                return fun.len;
            },
        }
    }

    pub fn get_number(self: Value) TakeError!f64 {
        switch (self) {
            .number => |n| return n,
            else => return TakeError.TypeMismatch,
        }
    }

    pub fn get_bool(self: Value) TakeError!bool {
        switch (self) {
            .boolean => |b| return b,
            else => return TakeError.TypeMismatch,
        }
    }
};

pub const Function = struct {
    args: []struct {name: []const u8, type: Type},
    body: []const AstExpr,
};

pub const Table = struct {
    allocator: Allocator,
    content: [][]Value,

    pub fn from(str: []const u8, allo: Allocator) !Table {
        const TableVec = ArrayList([]Value);
        const RowVec = ArrayList(Value);
        var table: TableVec = TableVec.init(allo);

        var row: RowVec = RowVec.init(allo);

        var in = str;

        while (true) {
            const result = try parse.parse_expr(in, allo);
            const val = try exec.exec(&result.result);

            try row.append(val);
            in = result.remaining;

            if (in.len == 0)
                break;
            
            if (in[0] == '\n') {
                try table.append(row.toOwnedSlice());
            }
            in = in[1..];
        }

        try table.append(row.toOwnedSlice());

        return Table {
            .content = table.toOwnedSlice(),
            .allocator = allo,
        };
    }

    pub fn deinit(self: Table) void {
        for (self.content) |r| {
            self.allocator.free(r);
        }

        self.allocator.free(self.content);
    }

    pub fn format(self: Table, allo: Allocator) ![]const u8 {
        const String = ArrayList(u8);
        var vec: String = String.init(allo);
        var buf: [256]u8 = undefined;

        for (self.content) |row| {
            for (row) |val| {
                const n = try val.format(buf[0..]);
                try vec.appendSlice(buf[0..n]);
                try vec.appendSlice(", ");
            }

            try vec.append('\n');
        }

        return vec.toOwnedSlice();
    }
};
