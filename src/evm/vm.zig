const std = @import("std");
const memory = @import("memory.zig");
const opcodes = @import("opcodes.zig");
const stack = @import("stack.zig");

pub const VMError = error{
    NotImplemented,
    MemoryReferenceTooLarge,
};

pub const VM = struct {
    allocator: std.mem.Allocator = undefined,
    stack: stack.Stack = stack.Stack{},
    memory: memory.ExpandableMemory = memory.ExpandableMemory{},
    returnValue: []u8 = undefined,
    gasConsumed: u64 = 0,

    pub fn init(self: *VM, allocator: std.mem.Allocator) void {
        self.memory.init(allocator);
        self.allocator = allocator;
    }

    pub fn deinit(self: *VM) void {
        self.memory.deinit();
        self.allocator.free(self.returnValue);
    }

    pub fn run(self: *VM, bytecode: []const u8) !void {
        var stream = std.io.fixedBufferStream(bytecode);

        while (try self.nextInstruction(&stream)) {
            std.log.debug("---", .{});
        }
    }

    pub fn nextInstruction(self: *VM, stream: *std.io.FixedBufferStream([]const u8)) !bool {
        // This doesn't really matter, since the opcode is a single byte.
        const byteOrder = std.builtin.Endian.Big;

        const reader = stream.reader();

        const op: opcodes.OpCode = reader.readEnum(opcodes.OpCode, byteOrder) catch |err| switch (err) {
            error.EndOfStream => {
                return false;
            },
            else => {
                return err;
            },
        };
        switch (op) {
            opcodes.OpCode.STOP => {
                std.log.debug("{s}", .{
                    @tagName(op),
                });

                return false;
            },
            opcodes.OpCode.ADD => {
                std.log.debug("{s}", .{
                    @tagName(op),
                });
                const a = try self.stack.pop();
                const b = try self.stack.pop();
                const c = @addWithOverflow(a, b)[0];
                try self.stack.push(c);
                self.gasConsumed += 3;
                return true;
            },
            opcodes.OpCode.MOD => {
                std.log.debug("{s}", .{@tagName(op)});
                self.gasConsumed += 5;
                const a = try self.stack.pop();
                const b = try self.stack.pop();
                if (b == 0) {
                    try self.stack.push(0);
                    return true;
                }
                const c = @mod(a, b);
                try self.stack.push(c);
                return true;
            },
            opcodes.OpCode.PUSH1 => {
                const b = try reader.readByte();
                std.log.debug("{s} 0x{x:0>2}", .{ @tagName(op), b });
                try self.stack.push(b);
                self.gasConsumed += 3;
                return true;
            },
            opcodes.OpCode.PUSH32 => {
                const b = try reader.readIntBig(u256);
                std.log.debug("{s} 0x{x:0>32}", .{ @tagName(op), b });
                try self.stack.push(b);
                self.gasConsumed += 3;
                return true;
            },
            opcodes.OpCode.MSTORE => {
                std.log.debug("{s}", .{@tagName(op)});
                const offset = try self.stack.pop();
                const value = try self.stack.pop();
                std.log.debug("  Memory: Writing value=0x{x} to memory offset={d}", .{ value, offset });
                if (offset != 0) {
                    return VMError.NotImplemented;
                }
                std.log.debug("  Memory: 0x{x:0>32}", .{value});

                const oldState = ((self.memory.length() << 2) / 512) + (3 * self.memory.length());
                try self.memory.write(value);
                const newState = ((self.memory.length() << 2) / 512) + (3 * self.memory.length());
                self.gasConsumed += 3;
                self.gasConsumed += @as(u64, newState - oldState);
                return true;
            },
            opcodes.OpCode.PC => {
                std.log.debug("{s}", .{@tagName(op)});

                const pos = try stream.getPos();
                try self.stack.push(pos - 1);
                self.gasConsumed += 2;

                return true;
            },
            opcodes.OpCode.RETURN => {
                std.log.debug("{s}", .{@tagName(op)});
                const offset256 = try self.stack.pop();
                const size256 = try self.stack.pop();

                const offset = std.math.cast(u32, offset256) orelse return VMError.MemoryReferenceTooLarge;
                const size = std.math.cast(u32, size256) orelse return VMError.MemoryReferenceTooLarge;

                std.log.debug("  Memory: reading size={d} bytes from offset={d}", .{ size, offset });

                self.returnValue = try self.memory.read(self.allocator, offset, size);
                std.log.debug("  Return value: 0x{}", .{std.fmt.fmtSliceHexLower(self.returnValue)});
                return true;
            },
            else => {
                std.log.err("Not yet handling opcode {d}", .{op});
                return VMError.NotImplemented;
            },
        }
    }
};

fn testBytecode(bytecode: []const u8, expectedReturnValue: []const u8, expectedGasConsumed: u64, expectedStack: []const u256, expectedMemory: []const u256) !void {
    const allocator = std.testing.allocator;

    var vm = VM{};
    vm.init(allocator);
    defer vm.deinit();

    try vm.run(bytecode);

    try std.testing.expectEqualSlices(u8, expectedReturnValue, vm.returnValue);
    try std.testing.expectEqual(expectedGasConsumed, vm.gasConsumed);
    try std.testing.expectEqualSlices(u256, expectedStack, vm.stack.slice());
    try std.testing.expectEqualSlices(u256, expectedMemory, vm.memory.slice());
}

test "exit immediately" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.STOP)
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = 0;
    const expectedStack = [_]u256{};
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "exit after pushing two values to stack" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH1), 0x02,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x01,
        @intFromEnum(opcodes.OpCode.STOP),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = 6;
    const expectedStack = [_]u256{ 0x02, 0x01 };
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "add two bytes" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH1), 0x03,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x02,
        @intFromEnum(opcodes.OpCode.ADD),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    try testBytecode(&bytecode, &expectedReturnValue, 9, &[_]u256{0x05}, &[_]u256{});
}

test "adding one to max u256 should wrap to zero" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH32),  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x01,
        @intFromEnum(opcodes.OpCode.ADD),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = 9;
    const expectedStack = [_]u256{0x0};
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "10 modulus 3 is 1" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH1), 0x03,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x0a,
        @intFromEnum(opcodes.OpCode.MOD),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = 11;
    const expectedStack = [_]u256{0x01};
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "anything mod 0 is 0" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH1), 0x00,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x05,
        @intFromEnum(opcodes.OpCode.MOD),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = 11;
    const expectedStack = [_]u256{0x00};
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "return single-byte value" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH1), 0x01,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x00,
        @intFromEnum(opcodes.OpCode.MSTORE),
        @intFromEnum(opcodes.OpCode.PUSH1), 0x01,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x1f,
        @intFromEnum(opcodes.OpCode.RETURN),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{0x01};
    const expectedGasConsumed = 18;
    const expectedStack = [_]u256{};
    const expectedMemory = [_]u256{0x01};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "return 32-byte value" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH1), 0x01,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x00,
        @intFromEnum(opcodes.OpCode.MSTORE),
        @intFromEnum(opcodes.OpCode.PUSH1), 0x20,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x00,
        @intFromEnum(opcodes.OpCode.RETURN),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
    };
    const expectedGasConsumed = 18;
    const expectedStack = [_]u256{};
    const expectedMemory = [_]u256{0x01};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "use push32 and return a single byte" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PUSH32), 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x00,
        @intFromEnum(opcodes.OpCode.MSTORE),
        @intFromEnum(opcodes.OpCode.PUSH1), 0x01,
        @intFromEnum(opcodes.OpCode.PUSH1), 0x00,
        @intFromEnum(opcodes.OpCode.RETURN),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{0x10};
    const expectedGasConsumed = 18;
    const expectedStack = [_]u256{};
    const expectedMemory = [_]u256{0x1000000000000000000000000000000000000000000000000000000000000000};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "use pc to measure program counter" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(opcodes.OpCode.PC),
        @intFromEnum(opcodes.OpCode.PC),
        @intFromEnum(opcodes.OpCode.PUSH1), 0xaa,
        @intFromEnum(opcodes.OpCode.PC),
        @intFromEnum(opcodes.OpCode.PUSH32), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xbb,
        @intFromEnum(opcodes.OpCode.PC),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = (4 * 2) + (3 * 2);
    const expectedStack = [_]u256{ 0x00, 0x01, 0xaa, 0x04, 0x00000000000000000000000000000000000000000000000000000000000000bb, 4 + 1 + 1 + 32 };
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}
