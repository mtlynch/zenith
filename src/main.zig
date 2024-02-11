const std = @import("std");

// Example bytecode we want to execute.
//
// // Set the stat
// PUSH1 1
// PUSH1 0
// MSTORE

// // Example
// PUSH1 1
// PUSH1 31
// RETURN
//
// Should end with
// Return value: 0x01
// Stack: empty
// Storage: empty
// Memory: 0x01

const OpCode = enum(u8) {
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    RETURN = 0xf3,
};

pub fn main() !void {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.MSTORE),
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.PUSH1), 0x1f,
        @intFromEnum(OpCode.RETURN),
    };
    // zig fmt: on

    var byteIndex: u32 = 0;
    while (byteIndex < bytecode.len) {
        const b = bytecode[byteIndex];
        byteIndex = byteIndex + 1;

        const op: OpCode = @enumFromInt(b);
        switch (op) {
            OpCode.PUSH1 => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                byteIndex = byteIndex + 1;
                // TODO: Read values onto stack.
            },
            OpCode.PUSH32 => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                // TODO: Read values onto stack.
            },
            OpCode.MSTORE => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                // TODO: Move values from stack to memory
            },
            OpCode.RETURN => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                // TODO: Return value in memory
            },
        }
    }
}

test "simple test" {
    // TODO
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}
