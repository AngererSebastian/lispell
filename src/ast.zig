const std = @import("std");
const Vec = std.ArrayList;
const Allocator = std.mem.Allocator;

const space_buf = " " ** 256;

pub const TakeError = error {
    TypeMismatch
};

pub const AstExpr = union(enum) {
    number: f64,
    string: []const u8,
    ident: []const u8,
    call: []AstExpr,
    quoted: []AstExpr,

    pub fn deinit(self: AstExpr, allocator: Allocator) void {
        switch (self) {
            .number => {},
            .string => {},
            .ident => {},
            .call => |c| {
                for (c) |a| {
                    a.deinit(allocator);
                }
                allocator.free(c);
            },
            .quoted => |c| {
                for (c) |e| {
                    e.deinit(allocator);
                }
                allocator.free(c);
            },
        }
    }

    pub fn print(self: AstExpr, indent: u8) void {
        const p = std.debug.print;
        switch (self) {
            .number => |n| p("number: {d}", .{n}),
            .string => |s| p("string: {s}", .{s}),
            .ident => |i| p("ident: {s}", .{i}),
            .call => |asts| {
                if (asts.len == 0) {
                    return;
                }

                p("{s}function: \n", .{space_buf[0..indent]});
                print(asts[0], indent+1);

                var i: u32 = 1;

                while (i < asts.len) : (i += 1) {
                    p("{s} - ", .{space_buf[0..indent]});
                    print(asts[i], indent + 1);
                }
            },
            .quoted => |asts| {
                p("list: ", .{});

                var i: u32 = 0;

                while (i <= asts.len) : (i += 1) {
                    p("{s} - ", .{space_buf[0..indent]});
                    print(asts[i], indent + 1);
                }
            }
        }
        p("\n", .{});
    }

    pub fn get_number(self: AstExpr) TakeError!f64 {
        switch (self) {
            .number => |n| return n,
            else => return TakeError.TypeMismatch,
        }
    }

    pub fn get_string(self: AstExpr) TakeError![]const u8 {
        switch (self) {
            .string => |s| return s,
            else => return TakeError.TypeMismatch,
        }
    }

    pub fn get_ident(self: AstExpr) TakeError![]const u8 {
        switch (self) {
            .ident => |s| return s,
            else => return TakeError.TypeMismatch,
        }
    }
};