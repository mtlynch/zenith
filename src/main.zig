const std = @import("std");
const time = std.time;
const Timer = std.time.Timer;

const OpCode = enum(u8) {
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    RETURN = 0xf3,
    _,
};

const VMError = error{
    NotImplemented,
    MemoryReferenceTooLarge,
};

const VM = struct {
    allocator: std.mem.Allocator = undefined,
    stack: std.ArrayList(u256) = undefined,
    memory: std.ArrayList(u256) = undefined,
    returnValue: []u8 = undefined,
    verbose: bool = false,
    gasConsumed: u64 = 0,

    pub fn init(self: *VM, allocator: std.mem.Allocator, verbose: bool) void {
        self.stack = std.ArrayList(u256).init(allocator);
        self.memory = std.ArrayList(u256).init(allocator);
        self.allocator = allocator;
        self.verbose = verbose;
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.memory.deinit();
        self.allocator.free(self.returnValue);
    }

    pub fn run(self: *VM, reader: anytype) !void {
        while (try self.nextInstruction(reader)) {
            self.printVerbose("---\n", .{});
        }
    }

    pub fn nextInstruction(self: *VM, reader: anytype) !bool {
        // This doesn't really matter, since the opcode is a single byte.
        const byteOrder = std.builtin.Endian.Big;

        const op: OpCode = reader.readEnum(OpCode, byteOrder) catch |err| switch (err) {
            error.EndOfStream => {
                return false;
            },
            else => {
                return err;
            },
        };
        switch (op) {
            OpCode.PUSH1 => {
                const b = try reader.readByte();
                self.printVerbose("{s} 0x{x:0>2}\n", .{ @tagName(op), b });
                try self.stack.append(b);
                self.printVerbose("  Stack: push 0x{x:0>2}\n", .{b});
                self.gasConsumed += 3;
                return true;
            },
            OpCode.PUSH32 => {
                const b = try reader.readIntBig(u256);
                self.printVerbose("{s} 0x{x:0>32}\n", .{ @tagName(op), b });
                try self.stack.append(b);
                self.printVerbose("  Stack: push 0x{x:0>2}\n", .{b});
                self.gasConsumed += 3;
                return true;
            },
            OpCode.MSTORE => {
                const offset = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{offset});
                const value = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{value});
                self.printVerbose("{s} offset={d}, value={d}\n", .{ @tagName(op), offset, value });
                if (offset != 0) {
                    return VMError.NotImplemented;
                }
                self.printVerbose("  Memory: 0x{x:0>32}\n", .{value});

                const oldState = ((self.memory.items.len << 2) / 512) + (3 * self.memory.items.len);
                try self.memory.append(value);
                const newState = ((self.memory.items.len << 2) / 512) + (3 * self.memory.items.len);
                self.gasConsumed += 3;
                self.gasConsumed += @as(u64, newState - oldState);
                return true;
            },
            OpCode.RETURN => {
                const offset256 = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{offset256});
                const size256 = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{size256});
                self.printVerbose("{s} offset={d}, size={d}\n", .{ @tagName(op), offset256, size256 });

                const offset = std.math.cast(u32, offset256) orelse return VMError.MemoryReferenceTooLarge;
                const size = std.math.cast(u32, size256) orelse return VMError.MemoryReferenceTooLarge;

                self.returnValue = try readMemory(self.allocator, self.memory.items, offset, size);
                self.printVerbose("  Return value: 0x{}\n", .{std.fmt.fmtSliceHexLower(self.returnValue)});
                return true;
            },
            else => {
                self.printVerbose("Not yet handling opcode {d}\n", .{op});
                return VMError.NotImplemented;
            },
        }
    }

    fn printVerbose(self: VM, comptime fmt: []const u8, args: anytype) void {
        if (self.verbose) {
            std.debug.print(fmt, args);
        }
    }
};

pub fn toBigEndian(x: u256) u256 {
    return std.mem.nativeTo(u256, x, std.builtin.Endian.Big);
}

pub fn readMemory(allocator: std.mem.Allocator, memory: []const u256, offset: u32, size: u32) ![]u8 {
    // Make a copy of memory in big-endian order.
    // TODO: We can optimize this to only copy the bytes that we want to read.
    var memoryCopy = try std.ArrayList(u256).initCapacity(allocator, memory.len);
    defer memoryCopy.deinit();
    for (0..memory.len) |i| {
        memoryCopy.insertAssumeCapacity(i, toBigEndian(memory[i]));
    }

    const mBytes = std.mem.sliceAsBytes(memoryCopy.items);

    var rBytes = try std.ArrayList(u8).initCapacity(allocator, size);
    errdefer rBytes.deinit();
    for (0..size) |i| {
        try rBytes.insert(i, mBytes[offset + i]);
    }

    return try rBytes.toOwnedSlice();
}

pub fn main() !void {
    const verboseMode = ((std.os.argv.len > 1) and std.mem.eql(u8, std.mem.span(std.os.argv[1]), "-v"));

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var reader = std.io.getStdIn().reader();

    var evm = VM{};
    evm.init(allocator, verboseMode);
    defer evm.deinit();

    var timer = try Timer.start();
    const start = timer.lap();
    try evm.run(&reader);
    const end = timer.read();
    const elapsed_micros = @as(f64, @floatFromInt(end - start)) / time.ns_per_us;

    const output = std.io.getStdOut().writer();
    try output.print("EVM gas used:    {}\n", .{evm.gasConsumed});
    try output.print("execution time:  {d:.3}µs\n", .{elapsed_micros});
    try output.print("0x{}\n", .{std.fmt.fmtSliceHexLower(evm.returnValue)});
}

test "return single-byte value" {
    const allocator = std.testing.allocator;

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
    var stream = std.io.fixedBufferStream(&bytecode);
    var reader = stream.reader();

    var evm = VM{};
    evm.init(allocator, false);
    defer evm.deinit();

    try evm.run(&reader);

    try std.testing.expectEqual(@as(u64, 18), evm.gasConsumed);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x01}, evm.returnValue);
    try std.testing.expectEqualSlices(u256, &[_]u256{}, evm.stack.items);
    try std.testing.expectEqualSlices(u256, &[_]u256{0x01}, evm.memory.items);
}

test "return 32-byte value" {
    const allocator = std.testing.allocator;

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
    var stream = std.io.fixedBufferStream(&bytecode);
    var reader = stream.reader();

    var evm = VM{};
    evm.init(allocator, false);
    defer evm.deinit();

    try evm.run(&reader);

    try std.testing.expectEqual(@as(u64, 18), evm.gasConsumed);
    try std.testing.expectEqualSlices(u8, &[_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
    }, evm.returnValue);
    try std.testing.expectEqualSlices(u256, &[_]u256{}, evm.stack.items);
    try std.testing.expectEqualSlices(u256, &[_]u256{0x01}, evm.memory.items);
}

test "use push32 and return a single byte" {
    const allocator = std.testing.allocator;

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
    var stream = std.io.fixedBufferStream(&bytecode);
    var reader = stream.reader();

    var evm = VM{};
    evm.init(allocator, false);
    defer evm.deinit();

    try evm.run(&reader);

    try std.testing.expectEqual(@as(u64, 18), evm.gasConsumed);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x10}, evm.returnValue);
    try std.testing.expectEqualSlices(u256, &[_]u256{}, evm.stack.items);
    try std.testing.expectEqualSlices(u256, &[_]u256{0x1000000000000000000000000000000000000000000000000000000000000000}, evm.memory.items);
}

fn testReadMemory(
    memory: []const u256,
    offset: u8,
    size: u8,
    expected: []const u8,
) !void {
    const allocator = std.testing.allocator;
    const rBytes = try readMemory(allocator, memory, offset, size);
    defer allocator.free(rBytes);
    try std.testing.expectEqualSlices(u8, expected, rBytes);
}

test "read from memory as bytes" {
    try testReadMemory(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 0, 1, &[_]u8{0x01});
    try testReadMemory(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 1, 1, &[_]u8{0x23});
    try testReadMemory(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 31, 1, &[_]u8{0xaa});
    try testReadMemory(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 31, 2, &[_]u8{ 0xaa, 0x13 });
    try testReadMemory(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 30, 4, &[_]u8{ 0xaa, 0xaa, 0x13, 0x57 });
}
