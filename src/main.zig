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

pub fn readMemory(allocator: std.mem.Allocator, memory: []u32, offset: u8, size: u8) []u8 {
    const memoryCopy = std.ArrayList(u32).initCapacity(allocator, memory.len);
    for (0..memory.len) |i| {
        memoryCopy.items[i] = toBigEndian(memory[i]);
    }

    const mBytes = std.mem.sliceAsBytes(&memoryCopy.items);

    const rBytes = std.ArrayList(u8).initCapacity(allocator, size);
    for (0..size) |i| {
        rBytes.items[i] = mBytes[offset + i];
    }

    return rBytes.asOwnedSlice();
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

test "convert memory word to bytes" {
    const allocator = std.testing.allocator;

    const m = [_]u32{ 0x1234567, 0xabcdef01 };
    const mBig = [_]u32{ toBigEndian(m[0]), toBigEndian(m[1]) };

    const mBytes = std.mem.sliceAsBytes(&mBig);

    const returnSize = 2;
    const returnOffset = 1;

    var rBytes = [4]u8{ 0, 0, 0, 0 };
    for (0..returnSize) |i| {
        rBytes[i] = mBytes[returnOffset + i];
    }

    std.debug.print("next line?\n", .{});
    std.debug.print("m        = 0x{x}\n", .{m});
    for (0..mBytes.len) |i| {
        std.debug.print("mBytes[{d}]= 0x{x}\n", .{ i, mBytes[i] });
    }
    std.debug.print("mBytes   = {*}\n", .{mBytes});
    for (0..rBytes.len) |i| {
        std.debug.print("rBytes[{d}]= 0x{x}\n", .{ i, rBytes[i] });
    }
}
