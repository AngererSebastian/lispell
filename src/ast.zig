const std = @import("std");
const Vec = std.ArrayList;
const Allocator = std.mem.Allocator;

const space_buf = " " ** 256;

pub const AstExpr = union(enum) {
    number: f64,
    string: []const u8,
    ident: []const u8,
    call: Vec(AstExpr),
    quoted: []AstExpr,

    pub fn deinit(self: AstExpr, allocator: Allocator) void {
        switch (self) {
            .number => {},
            .string => {},
            .ident => {},
            .call => |c| {
                var i: u32 = 0;
                while (i < c.items.len) : (i += 1) {
                    c.items[i].deinit(allocator);
                }
                c.deinit();
            },
            .quoted => |c| {
                for (c) |e| {
                    e.deinit(allocator);
                }
                allocator.free(c);
            },
        }
    }

    pub fn print(self: AstExpr, ident: u8) void {
        const p = std.debug.print;
        switch (self) {
            .number => |n| p("number: {d}", .{n}),
            .string => |s| p("string: {s}", .{s}),
            .ident => |i| p("ident: {s}", .{i}),
            .call => |asts| {
                if (asts.items.len == 0) {
                    return;
                }

                p("{s}function: \n", .{space_buf[0..ident]});
                print(asts.items[0], ident+1);

                var i: u32 = 1;

                while (i < asts.items.len) : (i += 1) {
                    p("{s} - ", .{space_buf[0..ident]});
                    print(asts.items[i], ident + 1);
                }
            },
            .quoted => |asts| {
                p("list: ", .{});

                var i: u32 = 0;

                while (i <= asts.len) : (i += 1) {
                    p("{s} - ", .{space_buf[0..ident]});
                    print(asts[i], ident + 1);
                }
            }
        }
        p("\n", .{});
    }
};