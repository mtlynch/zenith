const std = @import("std");
const memory = @import("memory.zig");
const stack = @import("stack.zig");

pub const OpCode = enum(u8) {
    ADD = 0x01,
    MOD = 0x06,
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    PC = 0x58,
    RETURN = 0xf3,
    _,
};

pub const VMError = error{
    NotImplemented,
    MemoryReferenceTooLarge,
};

pub fn VM(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator = undefined,
        stack: stack.Stack = stack.Stack{},
        memory: memory.ExpandableMemory = memory.ExpandableMemory{},
        returnValue: []u8 = undefined,
        gasConsumed: u64 = 0,
        reader: std.io.CountingReader(ReaderType) = undefined,

        pub fn init(allocator: std.mem.Allocator, reader: ReaderType) Self {
            var vm = Self{
                .allocator = allocator,
                .reader = std.io.countingReader(reader),
                .returnValue = &[_]u8{},
            };
            vm.memory.init(allocator);
            return vm;
        }

        pub fn deinit(self: *Self) void {
            self.memory.deinit();
            if (self.returnValue.len > 0) {
                self.allocator.free(self.returnValue);
            }
        }

        pub fn run(self: *Self) !void {
            while (try self.nextInstruction()) {
                std.log.debug("---", .{});
            }
        }

        pub fn nextInstruction(self: *Self) !bool {
            // This doesn't really matter, since the opcode is a single byte.
            const byteOrder = std.builtin.Endian.Big;

            const op: OpCode = self.reader.reader().readEnum(OpCode, byteOrder) catch |err| switch (err) {
                error.EndOfStream => {
                    return false;
                },
                else => {
                    return err;
                },
            };
            switch (op) {
                OpCode.ADD => {
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
                OpCode.MOD => {
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
                OpCode.PUSH1 => {
                    const b = try self.reader.reader().readByte();
                    std.log.debug("{s} 0x{x:0>2}", .{ @tagName(op), b });
                    try self.stack.push(b);
                    self.gasConsumed += 3;
                    return true;
                },
                OpCode.PUSH32 => {
                    const b = try self.reader.reader().readIntBig(u256);
                    std.log.debug("{s} 0x{x:0>32}", .{ @tagName(op), b });
                    try self.stack.push(b);
                    self.gasConsumed += 3;
                    return true;
                },
                OpCode.MSTORE => {
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
                OpCode.PC => {
                    std.log.debug("{s}", .{@tagName(op)});

                    try self.stack.push(self.reader.bytes_read - 1);
                    self.gasConsumed += 2;

                    return true;
                },
                OpCode.RETURN => {
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
}

fn testBytecode(bytecode: []const u8, expectedReturnValue: []const u8, expectedGasConsumed: u64, expectedStack: []const u256, expectedMemory: []const u256) !void {
    const allocator = std.testing.allocator;

    var stream = std.io.fixedBufferStream(bytecode);
    var reader = stream.reader();

    var evm = VM(@TypeOf(reader)).init(allocator, reader);
    defer evm.deinit();

    try evm.run();

    try std.testing.expectEqualSlices(u8, expectedReturnValue, evm.returnValue);
    try std.testing.expectEqual(expectedGasConsumed, evm.gasConsumed);
    try std.testing.expectEqualSlices(u256, expectedStack, evm.stack.slice());
    try std.testing.expectEqualSlices(u256, expectedMemory, evm.memory.slice());
}

test "add two bytes" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(OpCode.PUSH1), 0x03,
        @intFromEnum(OpCode.PUSH1), 0x02,
        @intFromEnum(OpCode.ADD),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = 9;
    const expectedStack = [_]u256{0x05};
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}

test "adding one to max u256 should wrap to zero" {
    // zig fmt: off
    const bytecode = [_]u8{
        @intFromEnum(OpCode.PUSH32),  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.ADD),
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
        @intFromEnum(OpCode.PUSH1), 0x03,
        @intFromEnum(OpCode.PUSH1), 0x0a,
        @intFromEnum(OpCode.MOD),
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
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.PUSH1), 0x05,
        @intFromEnum(OpCode.MOD),
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
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.MSTORE),
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.PUSH1), 0x1f,
        @intFromEnum(OpCode.RETURN),
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
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.MSTORE),
        @intFromEnum(OpCode.PUSH1), 0x20,
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.RETURN),
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
        @intFromEnum(OpCode.PUSH32), 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.MSTORE),
        @intFromEnum(OpCode.PUSH1), 0x01,
        @intFromEnum(OpCode.PUSH1), 0x00,
        @intFromEnum(OpCode.RETURN),
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
        @intFromEnum(OpCode.PC),
        @intFromEnum(OpCode.PC),
        @intFromEnum(OpCode.PUSH1), 0xaa,
        @intFromEnum(OpCode.PC),
        @intFromEnum(OpCode.PUSH32), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xbb,
        @intFromEnum(OpCode.PC),
    };
    // zig fmt: on

    const expectedReturnValue = [_]u8{};
    const expectedGasConsumed = (4 * 2) + (3 * 2);
    const expectedStack = [_]u256{ 0x00, 0x01, 0xaa, 0x04, 0x00000000000000000000000000000000000000000000000000000000000000bb, 4 + 1 + 1 + 32 };
    const expectedMemory = [_]u256{};
    try testBytecode(&bytecode, &expectedReturnValue, expectedGasConsumed, &expectedStack, &expectedMemory);
}
