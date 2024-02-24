const std = @import("std");

pub const StackError = error{
    EmptyStack,
};

pub const Stack = struct {
    slots: [1024]u256 = undefined,
    size: u16 = 0,

    pub fn push(self: *Stack, val: u256) void {
        self.slots[self.size] = val;
        self.size += 1;
    }

    pub fn pop(self: *Stack) !u256 {
        if (self.size == 0) {
            return StackError.EmptyStack;
        }
        self.size -= 1;
        const val = self.slots[self.size];
        return val;
    }

    pub fn slice(self: Stack) []const u256 {
        return self.slots[0..self.size];
    }
};

test "push and pop an element to the stack" {
    var stack: Stack = Stack{};

    stack.push(150);

    const result = try stack.pop();

    try std.testing.expectEqual(@as(u256, 150), result);
    try std.testing.expectEqualSlices(u256, &[_]u256{}, stack.slice());
}

test "push and pop three elements to the stack" {
    var stack: Stack = Stack{};

    stack.push(1);
    stack.push(2);
    stack.push(3);

    try std.testing.expectEqualSlices(u256, &[_]u256{ 1, 2, 3 }, stack.slice());
    var result = try stack.pop();
    try std.testing.expectEqual(@as(u256, 3), result);

    try std.testing.expectEqualSlices(u256, &[_]u256{ 1, 2 }, stack.slice());
    result = try stack.pop();
    try std.testing.expectEqual(@as(u256, 2), result);

    try std.testing.expectEqualSlices(u256, &[_]u256{1}, stack.slice());
    result = try stack.pop();
    try std.testing.expectEqual(@as(u256, 1), result);

    try std.testing.expectEqualSlices(u256, &[_]u256{}, stack.slice());
}

test "popping an empty stack returns an error" {
    var stack: Stack = Stack{};

    try std.testing.expectError(StackError.EmptyStack, stack.pop());
}
