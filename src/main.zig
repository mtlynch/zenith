const std = @import("std");
const vm = @import("evm/vm.zig");

pub fn main() !void {
    var buffer: [800000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const bytecode = try readStdin(allocator);
    defer allocator.free(bytecode);

    var evm = vm.VM{};
    evm.init(allocator);
    defer evm.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.lap();
    try evm.run(bytecode);
    const end = timer.read();
    const elapsed_micros = @as(f64, @floatFromInt(end - start)) / std.time.ns_per_us;

    const output = std.io.getStdOut().writer();
    try output.print("EVM gas used:    {}\n", .{evm.gasConsumed});
    try output.print("execution time:  {d:.3}µs\n", .{elapsed_micros});
    if (evm.returnValue.len > 0) {
        try output.print("0x{}\n", .{std.fmt.fmtSliceHexLower(evm.returnValue)});
    } else {
        // Match evm behavior by outputting a blank line when there is no return value.
        try output.print("\n", .{});
    }
}

pub fn readStdin(allocator: std.mem.Allocator) ![]u8 {
    var stdin = std.io.getStdIn().reader();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try stdin.readAllArrayList(&buffer, std.math.maxInt(usize));

    return buffer.toOwnedSlice();
}

test {
    std.testing.refAllDecls(@This());
}
