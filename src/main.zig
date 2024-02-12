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

const Operation = struct {
    Code: OpCode,
    Args: std.ArrayList(u8), // TODO: Handle different typed args.
};

const BytecodeReader = struct {
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

    bytes: []const u8 = &bytecode,
    index: u32 = 0,

    pub fn nextByte(self: *BytecodeReader) u8 {
        // TODO: Handle out of bounds error.
        const b = self.bytes[self.index];
        self.index += 1;
        return b;
    }

    pub fn done(self: BytecodeReader) bool {
        return self.index >= self.bytes.len;
    }
};

const VM = struct {
    pub fn run(self: VM, reader: *BytecodeReader) !void {
        while (!reader.done()) {
            try self.nextInstruction(reader);
        }
    }

    pub fn nextInstruction(_: VM, reader: *BytecodeReader) !void {
        const op: OpCode = @enumFromInt(reader.nextByte());
        switch (op) {
            OpCode.PUSH1 => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                _ = reader.nextByte();
                // TODO: Assign value onto stack.
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
};

pub fn main() !void {
    var bcReader = BytecodeReader{};

    const evm = VM{};
    try evm.run(&bcReader);
}

test "simple test" {
    // TODO
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}
