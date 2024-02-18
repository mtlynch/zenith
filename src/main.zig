const std = @import("std");
const time = std.time;
const Timer = std.time.Timer;

const OpCode = enum(u8) {
    PUSH1 = 0x60,
    MSTORE = 0x52,
    RETURN = 0xf3,
    _,
};

const VMError = error{
    NotImplemented,
};

const VM = struct {
    stack: std.ArrayList(u8) = undefined,
    memory: std.ArrayList(u32) = undefined,
    returnValue: u8 = undefined,
    verbose: bool = false,
    gasConsumed: u64 = 0,

    pub fn init(self: *VM, allocator: std.mem.Allocator, verbose: bool) void {
        self.stack = std.ArrayList(u8).init(allocator);
        self.memory = std.ArrayList(u32).init(allocator);
        self.verbose = verbose;
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.memory.deinit();
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
            OpCode.MSTORE => {
                const offset = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{offset});
                const value = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{value});
                self.printVerbose("{s} offset=0x{x:0>2}, value=0x{x:0>2}\n", .{ @tagName(op), offset, value });
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
                const offset = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{offset});
                const size = self.stack.pop();
                self.printVerbose("  Stack: pop 0x{x:0>2}\n", .{size});
                self.printVerbose("{s} offset=0x{x:0>2}, size=0x{x:0>2}\n", .{ @tagName(op), offset, size });
                if (size != 1) {
                    return VMError.NotImplemented;
                }
                if (offset != 31) {
                    return VMError.NotImplemented;
                }
                const val = self.memory.getLast();
                const shrunk: u8 = @as(u8, @truncate(val));
                self.returnValue = shrunk;
                self.printVerbose("RETURN {d}\n", .{shrunk});
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

pub fn toBigEndian(x: u32) u32 {
    return std.mem.nativeTo(u32, x, std.builtin.Endian.Big);
}

pub fn readMemory(allocator: std.mem.Allocator, memory: []const u32, offset: u8, size: u8) ![]u8 {
    // Make a copy of memory in big-endian order.
    var memoryCopy = try std.ArrayList(u32).initCapacity(allocator, memory.len);
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
    try output.print("0x{x:0>2}\n", .{evm.returnValue});
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
    try std.testing.expectEqual(@as(u32, 0x01), evm.returnValue);
    try std.testing.expectEqualSlices(u8, &[_]u8{}, evm.stack.items);
    try std.testing.expectEqualSlices(u32, &[_]u32{1}, evm.memory.items);
}

fn testReadMemory(
    memory: []const u32,
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
    try testReadMemory(&[_]u32{ 0x01234567, 0xabcdef44 }, 0, 1, &[_]u8{0x01});
    try testReadMemory(&[_]u32{ 0x01234567, 0xabcdef44 }, 1, 1, &[_]u8{0x23});
    try testReadMemory(&[_]u32{ 0x01234567, 0xabcdef44 }, 7, 1, &[_]u8{0x44});
    try testReadMemory(&[_]u32{ 0x01234567, 0xabcdef44 }, 3, 2, &[_]u8{ 0x67, 0xab });
    try testReadMemory(&[_]u32{ 0x01234567, 0xabcdef44 }, 4, 3, &[_]u8{ 0xab, 0xcd, 0xef });
}
