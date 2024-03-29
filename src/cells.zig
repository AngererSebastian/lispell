const std = @import("std");
const exec = @import("./exec.zig");
const ast = @import("./ast.zig");
const parse = @import("./parse.zig");

const ArrayList = std.ArrayList;
const TakeError = ast.TakeError;
const AstExpr = ast.AstExpr;
const Allocator = std.mem.Allocator;
const BufPrintError = std.fmt.BufPrintError;

pub const Type = enum {
    number,
    string,
    boolean,
    function,
    list,
};

pub const Value = union(Type) {
    number: f64,
    string: []const u8,
    boolean: bool,
    function: Function,
    list: []Value,

    pub fn print(self: Value) void {
        var buf: [256]u8 = undefined;
        _ = self.format(buf[0..]) catch return;
        std.debug.print("{s}", .{buf});
    }

    pub fn format(self: Value, buf: []u8) std.fmt.BufPrintError!usize {
        switch (self) {
            .number => |n| return (try std.fmt.bufPrint(buf, "{d}", .{n})).len,
            .string => |s| {
                std.mem.copy(u8, buf[1..s.len+1], s);
                buf[0] = '"';
                buf[s.len + 1] = '"';
                return s.len + 2;
            },
            .boolean => |b| return (try std.fmt.bufPrint(buf, "{}", .{b})).len,
            .function => {
                const fun = "function";
                std.mem.copy(u8, buf,fun);
                return fun.len;
            },
            .list => |l| {
                return try Value.format_list(l, buf);
            }
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

    pub fn get_function(self: Value) TakeError!Function {
        switch (self) {
            .function => |f| return f,
            else => return TakeError.TypeMismatch,
        }
    }

    fn format_list(list: []Value, buf: []u8) BufPrintError!usize {
        if (buf.len == 0) {
            return BufPrintError.NoSpaceLeft;
        }

        buf[0] = '(';
        var offset: usize = 1;
        
        for (list) |x| {
            offset += try x.format(buf[offset..]);

            if (buf.len - offset < 0) {
                return BufPrintError.NoSpaceLeft;
            }

            buf[offset] = ',';
            offset += 1;
        }

        buf[offset-1] = ')';
        return offset;
    }
};

pub const Function = struct {
    args: [][]const u8,
    body: AstExpr,
};

pub const Table = struct {
    allocator: Allocator,
    content: [][]Value,

    pub fn from(str: []const u8, allo: Allocator) !Table {
        const TableVec = ArrayList([]Value);
        const RowVec = ArrayList(Value);
        var table: TableVec = TableVec.init(allo);
        var row: RowVec = RowVec.init(allo);
        var evaluator = exec.EvalState.init(allo);

        var in = str;
        var buf: [8]u8 = undefined;

        while (true) {
            const result = try parse.parse_expr(in, allo);
            //result.result.print(0);
            const val = try evaluator.evaluate(&result.result);

            const coords = try format_coords(buf[0..], row.items.len, table.items.len);
            //var dbg: [256]u8 = undefined;
            //const n = try val.format(dbg[0..]);
            //std.debug.print("inserting {s} - {s}\n", .{coords, dbg[0..n]});
            try evaluator.set(coords, val);

            try row.append(val);
            in = result.remaining;
            //std.debug.print("remaining to parse: \"{s}\"\n", .{in});

            if (in.len == 0 or in.len == 1)
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

fn format_coords(into: []u8, x: usize, y: usize) ![]u8 {
    // TODO: think about longer x coords like AA1
    const t = @intCast(u8, x);

    var out = std.fmt.bufPrint(into, "{c}{d}", .{t + 'a', y + 1});
    return out;
}