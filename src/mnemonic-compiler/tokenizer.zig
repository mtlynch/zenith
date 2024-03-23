const std = @import("std");

pub fn tokenize(reader: anytype, allocator: std.mem.Allocator) ![][:0]const u8 {
    var tokens = std.ArrayList([:0]const u8).init(allocator);
    defer tokens.deinit();

    var buf = std.io.bufferedReader(reader);
    var bufReader = buf.reader();

    var lineBuf: [1024]u8 = undefined;
    while (try bufReader.readUntilDelimiterOrEof(&lineBuf, '\n')) |line| {
        // Skip lines that start with "//"
        if (std.mem.startsWith(u8, line, "//")) {
            continue;
        }

        var iter = std.mem.split(u8, line, " ");
        while (iter.next()) |token| {
            if (token.len == 0) {
                continue;
            }
            try tokens.append(try allocator.dupeZ(u8, token));
        }
    }

    return tokens.toOwnedSlice();
}

fn testTokenize(input: [:0]const u8, expectedTokens: []const [:0]const u8) !void {
    var stream = std.io.fixedBufferStream(input);
    var reader = stream.reader();

    const allocator = std.testing.allocator;

    const tokens = try tokenize(reader, allocator);
    defer {
        for (tokens) |token| {
            allocator.free(token);
        }
        allocator.free(tokens);
    }

    try std.testing.expectEqual(expectedTokens.len, tokens.len);
    for (expectedTokens, 0..) |expected, i| {
        try std.testing.expectEqualStrings(expected, tokens[i]);
    }
}

test "tokenize a single word" {
    const input = "RETURN";

    const expectedTokens = [_][:0]const u8{
        "RETURN",
    };

    try testTokenize(input, &expectedTokens);
}

test "tokenize a multi-word line" {
    const input = "PUSH1 0x01";

    const expectedTokens = [_][:0]const u8{ "PUSH1", "0x01" };

    try testTokenize(input, &expectedTokens);
}

test "tokenize a multi-line input" {
    const input =
        \\PUSH1 0x01
        \\RETURN
    ;

    const expectedTokens = [_][:0]const u8{ "PUSH1", "0x01", "RETURN" };

    try testTokenize(input, &expectedTokens);
}

test "ignores lines starting with //" {
    const input =
        \\// Don't mind me; I'm just a comment
        \\PUSH1 0x01
        \\// This is where we return
        \\RETURN
    ;

    const expectedTokens = [_][:0]const u8{ "PUSH1", "0x01", "RETURN" };

    try testTokenize(input, &expectedTokens);
}

test "treats multiple spaces the same as a single space" {
    const input =
        \\PUSH1             0x01
        \\
        \\
        \\RETURN
        \\
    ;

    const expectedTokens = [_][:0]const u8{ "PUSH1", "0x01", "RETURN" };

    try testTokenize(input, &expectedTokens);
}
