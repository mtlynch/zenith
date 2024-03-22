const std = @import("std");
const vm = @import("vm");

pub fn main() !void {
    const kvs = comptime build_kvs: {
        const KV = struct { []const u8, vm.OpCode };
        var kvs_array: [std.meta.fields(vm.OpCode).len]KV = undefined;
        for (std.meta.fields(vm.OpCode), 0..) |enumField, i| {
            kvs_array[i] = .{ enumField.name, @field(vm.OpCode, enumField.name) };
        }
        break :build_kvs kvs_array;
    };
    const keywords = std.ComptimeStringMap(vm.OpCode, kvs);

    const output = std.io.getStdOut().writer();

    for (keywords.kvs) |kv| {
        try output.print("{s} = 0x{x:0>2}\n", .{ kv.key, @intFromEnum(kv.value) });
    }
}
