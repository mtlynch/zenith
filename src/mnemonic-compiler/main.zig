const std = @import("std");

pub fn main() !void {
    const output = std.io.getStdOut().writer();

    try output.print("hello, world!\n", .{});
}
