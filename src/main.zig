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

const VMReturnValue = struct {
    value: [32]u8,
    size: u8 = undefined,

    pub fn slice(self: VMReturnValue) []u8 {
        return [self.size]self.value;
    }
};

const VM = struct {
    stack: std.ArrayList(u8) = undefined,
    memory: std.ArrayList(u32) = undefined,
    returnValue: VMReturnValue = undefined,
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
        const op: OpCode = reader.readEnum(OpCode, std.builtin.Endian.Little) catch |err| switch (err) {
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

                // TODO: Handle case where return value spans multiple words.
                const mWord = self.memory.getLast();

                const mBytes = [_]u8{
                    mWord >> 15,
                    mWord >> 14,
                    mWord >> 13,
                    mWord >> 12,
                    mWord >> 11,
                    mWord >> 10,
                    mWord >> 9,
                    mWord >> 8,
                    mWord >> 7,
                    mWord >> 6,
                    mWord >> 5,
                    mWord >> 4,
                    mWord >> 3,
                    mWord >> 2,
                    mWord >> 1,
                    mWord >> 0,
                };

                //self.returnValue = shrunk;
                //self.printVerbose("RETURN {d}\n", .{shrunk});
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
    try std.testing.expectEqualSlices(u8, &[_]u8{0x01}, evm.returnValue.slice());
    try std.testing.expectEqualSlices(u8, &[_]u8{}, evm.stack.items);
    try std.testing.expectEqualSlices(u32, &[_]u32{1}, evm.memory.items);
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
    }, evm.returnValue.slice());
    try std.testing.expectEqualSlices(u8, &[_]u8{}, evm.stack.items);
    try std.testing.expectEqualSlices(u32, &[_]u32{1}, evm.memory.items);
}
