const std = @import("std");

pub const ExpandableMemory = struct {
    storage: std.ArrayList(u256) = undefined,

    pub fn init(self: *ExpandableMemory, allocator: std.mem.Allocator) void {
        self.storage = std.ArrayList(u256).init(allocator);
    }

    pub fn deinit(self: *ExpandableMemory) void {
        self.storage.deinit();
    }

    pub fn write(self: *ExpandableMemory, value: u256) !void {
        return self.storage.append(value);
    }

    pub fn read(self: ExpandableMemory, allocator: std.mem.Allocator, offset: u32, size: u32) ![]u8 {
        // Make a copy of memory in big-endian order.
        // TODO: We can optimize this to only copy the bytes that we want to read.
        var memoryCopy = try std.ArrayList(u256).initCapacity(allocator, self.storage.items.len);
        defer memoryCopy.deinit();
        for (0..self.storage.items.len) |i| {
            memoryCopy.insertAssumeCapacity(i, toBigEndian(self.storage.items[i]));
        }

        const mBytes = std.mem.sliceAsBytes(memoryCopy.items);

        var rBytes = try std.ArrayList(u8).initCapacity(allocator, size);
        errdefer rBytes.deinit();
        for (0..size) |i| {
            try rBytes.insert(i, mBytes[offset + i]);
        }

        return try rBytes.toOwnedSlice();
    }

    pub fn slice(self: ExpandableMemory) []u256 {
        return self.storage.items;
    }

    pub fn length(self: ExpandableMemory) usize {
        return self.storage.items.len;
    }
};

fn toBigEndian(x: u256) u256 {
    return std.mem.nativeTo(u256, x, std.builtin.Endian.Big);
}

fn testRead(
    memory: []const u256,
    offset: u8,
    size: u8,
    expected: []const u8,
) !void {
    const allocator = std.testing.allocator;
    var mem = ExpandableMemory{};
    mem.init(allocator);
    defer mem.deinit();
    for (memory) |b| {
        try mem.write(b);
    }
    const rBytes = try mem.read(allocator, offset, size);
    defer allocator.free(rBytes);
    try std.testing.expectEqualSlices(u8, expected, rBytes);
}

test "read from memory as bytes" {
    try testRead(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 0, 1, &[_]u8{0x01});
    try testRead(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 1, 1, &[_]u8{0x23});
    try testRead(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 31, 1, &[_]u8{0xaa});
    try testRead(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 31, 2, &[_]u8{ 0xaa, 0x13 });
    try testRead(&[_]u256{
        0x0123456789abcdefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        0x13579bdf02468ace111111111111111111111111111111111111111111111111,
    }, 30, 4, &[_]u8{ 0xaa, 0xaa, 0x13, 0x57 });
}
