const std = @import("std");

// Example bytecode we want to execute.
//
// // Set the stat
// PUSH32 0xFF01000000000000000000000000000000000000000000000000000000000000
// PUSH1 0
// MSTORE

// // Example
// PUSH1 2
// PUSH1 0
// RETURN

const OpCode = enum(u8) {
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    RETURN = 0xf3,
};

pub fn main() !void {
    // Dummy bytecode
    const bytecode = [_]u8{
        @intFromEnum(OpCode.PUSH1),
        @intFromEnum(OpCode.PUSH32),
    };

    for (bytecode) |b| {
        const op: OpCode = @enumFromInt(b);
        std.debug.print("op is {s}\n", .{@tagName(op)});
    }
}

test "simple test" {
    // TODO
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}
