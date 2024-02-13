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

// mstore offsets
// 0:  00000000000000000000000000000000000000000000000000000000000000ff
// 1:  0000000000000000000000000000000000000000000000000000000000000000ff00000000000000000000000000000000000000000000000000000000000000
// 2:  000000000000000000000000000000000000000000000000000000000000000000ff000000000000000000000000000000000000000000000000000000000000
// 32: 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff

const OpCode = enum(u8) {
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    RETURN = 0xf3,
    _,
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

const VMError = error{
    NotImplemented,
};

const VM = struct {
    stack: std.ArrayList(u8) = undefined,
    memory: std.ArrayList(u32) = undefined,

    pub fn init(self: *VM, allocator: std.mem.Allocator) void {
        self.stack = std.ArrayList(u8).init(allocator);
        self.memory = std.ArrayList(u32).init(allocator);
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.memory.deinit();
    }

    pub fn run(self: *VM, reader: *BytecodeReader) !void {
        while (!reader.done()) {
            try self.nextInstruction(reader);
        }
    }

    pub fn nextInstruction(self: *VM, reader: *BytecodeReader) !void {
        const op: OpCode = @enumFromInt(reader.nextByte());
        switch (op) {
            OpCode.PUSH1 => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                const b = reader.nextByte();
                std.debug.print("Pushed {d} onto stack\n", .{b});
                try self.stack.append(b);
            },
            OpCode.PUSH32 => {
                std.debug.print("Handle {s}\n", .{@tagName(op)});
                return VMError.NotImplemented;
            },
            OpCode.MSTORE => {
                const offset = self.stack.pop();
                const value = self.stack.pop();
                std.debug.print("Handle {s} offset={d}, value={d}\n", .{ @tagName(op), offset, value });
                if (offset != 0) {
                    return VMError.NotImplemented;
                }
                std.debug.print("Set memory to {d}\n", .{value});
                try self.memory.append(value);
            },
            OpCode.RETURN => {
                const offset = self.stack.pop();
                const size = self.stack.pop();
                std.debug.print("Handle {s} offset={d}, size={d}\n", .{ @tagName(op), offset, size });
                if (size != 1) {
                    return VMError.NotImplemented;
                }
                if (offset != 31) {
                    return VMError.NotImplemented;
                }
                const val = self.memory.getLast();
                const shrunk: u8 = @as(u8, @truncate(val));
                std.debug.print("RETURN {d}\n", .{shrunk});
            },
            else => {
                std.debug.print("Not yet handling opcode {d}\n", .{op});
                return VMError.NotImplemented;
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var bcReader = BytecodeReader{};

    var evm = VM{};
    evm.init(allocator);
    defer evm.deinit();
    try evm.run(&bcReader);
}

test "simple test" {
    // TODO
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}
