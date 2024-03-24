const evmc = @cImport({
    @cInclude("evmc/instructions.h");
});

pub const OpCode = enum(u8) {
    ADD = evmc.OP_ADD,
    MOD = 0x06,
    PUSH1 = 0x60,
    PUSH32 = 0x7f,
    MSTORE = 0x52,
    PC = 0x58,
    RETURN = 0xf3,
    _,
};
