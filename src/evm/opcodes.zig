pub const OpCode = enum(u8) {
    ADD = 0x01,
    MOD = 0x06,
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    PC = 0x58,
    RETURN = 0xf3,
    _,
};
