const std = @import("std");

pub fn trim(inp: []const u8, toTrim: u8) []const u8 {
    const tmp = trimStart(inp, toTrim);
    return trimEnd(tmp, toTrim);
}

pub fn trimStart(inp: []const u8, toTrim: u8) []const u8 {
    var begin: usize = 0;
    while(begin < inp.len and inp[begin] == toTrim) : (begin += 1) { }

    return inp[begin ..];

}

pub fn trimEnd(inp: []const u8, toTrim: u8) []const u8 {
    var end: usize = inp.len - 1;

    while(end >= 0 and inp[end] == toTrim) : (end -= 1) { }

    return inp[0 .. end + 1];
}

pub fn trimWhiteSpace(inp: []const u8) []const u8 {
    const tmp = trimWhiteSpaceStart(inp);
    return trimWhiteSpaceEnd(tmp);
}

pub fn trimWhiteSpaceStart(inp: []const u8) []const u8 {
    var begin: usize = 0;
    while(begin < inp.len and isWhiteSpace(inp[begin])) : (begin += 1) { }

    return inp[begin ..];

}

pub fn trimWhiteSpaceEnd(inp: []const u8) []const u8 {
    var end: usize = inp.len - 1;

    while(end >= 0 and isWhiteSpace(inp[end])) : (end -= 1) { }

    return inp[0 .. end + 1];
}

pub const SplitResult = struct {
    split: ?[]const u8,
    rest: []const u8,
};

pub fn split(inp: []const u8, toSplit: u8) SplitResult {
    var end = find(inp, toSplit);

    return .{
        .split = if (end > 0) inp[0..end] else null,
        .rest = if (end+1 < inp.len) inp[end+1..] else "",
    };
}

pub fn splitWhiteSpace(inp: []const u8) SplitResult {
    var end = findWhitespace(inp);

    return .{
        .split = if (end > 0) inp[0..end] else null,
        .rest = if (end+1 < inp.len) 
                   trimWhiteSpaceStart(inp[end+1..])
                else "",
    };
}

pub fn findWhitespace(str: []const u8) usize {
    var result: usize = 0;

    while (result < str.len and !isWhiteSpace(str[result]))
        : (result += 1) {}
    
    return result;
}

pub fn find(str: []const u8, toFind: u8) usize {
    var result: usize = 0;

    while (result < str.len and str[result] != toFind)
        : (result += 1) {}
    
    return result;
}

pub fn findEnd(str: []const u8, toFind: u8) usize {
    var result = str.len-1;

    while (result >= 0 and str[result] != toFind)
        : (result -= 1) {
        }
    
    return result;
}

pub fn isWhiteSpace(c: u8) bool {
    return c == ' '
        or c == '\n'
        or c == '\t';
}

test "simple find" {
    const data = "Hello world";
    const result = find(data, 'l');
    const expected: usize = 2;

    try std.testing.expectEqual(expected, result);
}

test "simple reverse find" {
    const data = "Hello world";
    const result = findEnd(data, 'l');
    const expected: usize = 9;

    try std.testing.expectEqual(expected, result);
}

test "split" {
    const data = "Hello world";
    const result = split(data, ' ');
    const expected: []const u8 = "Hello";
    const expectedRest: []const u8 = "world";

    try std.testing.expectEqualStrings(expected, result.split orelse return error{NoMatch}.NoMatch);
    try std.testing.expectEqualStrings(expectedRest, result.rest);
}

test "trim" {
    const data = "  Hello world     ";
    const result = trim(data, ' ');

    try std.testing.expectEqualStrings("Hello world", result);
}

test "trim whitespace" {
    const data = "  Hello world     ";
    const result = trimWhiteSpace(data);

    try std.testing.expectEqualStrings("Hello world", result);
}

test "find whitespace" {
    const data = "Hello world";
    const result = findWhitespace(data);
    const expected: usize = 5;

    try std.testing.expectEqual(expected, result);
}