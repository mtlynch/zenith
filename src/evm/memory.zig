const std = @import("std");

pub const MemoryError = error{
    MemoryReferenceTooLarge,
};

pub const ExpandableMemory = struct {
    storage: std.ArrayList(u256) = undefined,

    pub fn init(self: *ExpandableMemory, allocator: std.mem.Allocator) void {
        self.storage = std.ArrayList(u256).init(allocator);
    }

    pub fn deinit(self: *ExpandableMemory) void {
        self.storage.deinit();
    }

    pub fn write(self: *ExpandableMemory, offset: u256, value: u256) !void {
        const offsetUsize = std.math.cast(usize, offset) orelse return MemoryError.MemoryReferenceTooLarge;
        std.log.debug("  Memory: Writing value=0x{x} to memory offset={d}", .{ value, offset });
        const wordsToDelete = @min(1, self.storage.items[offsetUsize..].len);
        try self.storage.replaceRange(offsetUsize, wordsToDelete, &[_]u256{value});
    }

    pub fn read(self: ExpandableMemory, allocator: std.mem.Allocator, offset: u256, size: u256) ![]u8 {
        const offsetUsize = std.math.cast(usize, offset) orelse return MemoryError.MemoryReferenceTooLarge;
        const sizeUsize = std.math.cast(usize, size) orelse return MemoryError.MemoryReferenceTooLarge;
        std.log.debug("  Memory: reading size={d} bytes from offset={d}", .{ size, offset });

        // Make a copy of memory in big-endian order.
        // TODO: We can optimize this to only copy the bytes that we want to read.
        var memoryCopy = try std.ArrayList(u256).initCapacity(allocator, self.storage.items.len);
        defer memoryCopy.deinit();
        for (0..self.storage.items.len) |i| {
            memoryCopy.insertAssumeCapacity(i, toBigEndian(self.storage.items[i]));
        }

        const mBytes = std.mem.sliceAsBytes(memoryCopy.items);

        var rBytes = try std.ArrayList(u8).initCapacity(allocator, sizeUsize);
        errdefer rBytes.deinit();
        for (0..sizeUsize) |i| {
            try rBytes.insert(i, mBytes[offsetUsize + i]);
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
    for (memory, 0..) |b, i| {
        try mem.write(i, b);
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

test "overwrite a byte of memory" {
    const allocator = std.testing.allocator;
    var mem = ExpandableMemory{};
    mem.init(allocator);
    defer mem.deinit();
    try mem.write(0, 0x01);
    try mem.write(0, 0x02);
    const rBytes = try mem.read(allocator, 31, 1);
    defer allocator.free(rBytes);

    const expectedRead = [_]u8{0x02};
    try std.testing.expectEqualSlices(u8, &expectedRead, rBytes);
}

test "overwrite 32 bytes of memory" {
    const allocator = std.testing.allocator;
    var mem = ExpandableMemory{};
    mem.init(allocator);
    defer mem.deinit();
    try mem.write(0, 0x000000000000000000000000000000000000000000000000000000000000ffff);
    try mem.write(0, 0xffff000000000000000000000000000000000000000000000000000000000000);
    const rBytes = try mem.read(allocator, 0, 32);
    defer allocator.free(rBytes);

    const expectedRead = [_]u8{ 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    try std.testing.expectEqualSlices(u8, &expectedRead, rBytes);
}
