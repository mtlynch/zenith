const std = @import("std");
const vm = @import("vm");

fn tokenize(reader: anytype, allocator: std.mem.Allocator) ![][:0]const u8 {
    var tokens = std.ArrayList([:0]const u8).init(allocator);
    defer tokens.deinit();

    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
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

fn parseOpcode(val: [:0]const u8) ?vm.OpCode {
    const kvs = comptime build_kvs: {
        const KV = struct { []const u8, vm.OpCode };
        var kvs_array: [std.meta.fields(vm.OpCode).len]KV = undefined;
        for (std.meta.fields(vm.OpCode), 0..) |enumField, i| {
            kvs_array[i] = .{ enumField.name, @enumFromInt(enumField.value) };
        }
        break :build_kvs kvs_array;
    };
    const keywords = std.ComptimeStringMap(vm.OpCode, kvs);

    return keywords.get(val);
}

fn parseValue(val: [:0]const u8) !u32 {
    return std.fmt.parseInt(u32, val, 0);
}

fn printByte(writer: anytype, val: u8) !void {
    try writer.print("{x:0>2}", .{val});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <mnemonic-file> <output-file>\n", .{args[0]});
        return;
    }

    const infilePath = args[1];
    const infile = try std.fs.cwd().openFile(infilePath, .{});
    defer infile.close();

    var buf = std.io.bufferedReader(infile.reader());
    var reader = buf.reader();

    const tokens = try tokenize(reader, allocator);
    defer {
        for (tokens) |token| {
            allocator.free(token);
        }
        allocator.free(tokens);
    }

    const output = std.io.getStdOut().writer();

    var currentOpCode: vm.OpCode = undefined;
    for (tokens) |token| {
        if (parseOpcode(token)) |opcode| {
            currentOpCode = opcode;
            try output.print("{x:0>2}", .{@intFromEnum(opcode)});
        } else {
            // TODO: Parse value based on opcode.
            const value = try parseValue(token);
            try output.print("{x:0>2}", .{value});
        }
    }
    try output.print("\n", .{});
}
