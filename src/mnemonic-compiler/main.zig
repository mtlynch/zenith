const std = @import("std");
const vm = @import("vm");
const tokenizer = @import("tokenizer.zig");

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

    const tokens = try tokenizer.tokenize(infile.reader(), allocator);
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

test {
    std.testing.refAllDecls(@This());
}
