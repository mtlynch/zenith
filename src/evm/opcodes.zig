const evmc = @cImport({
    @cInclude("evmc/instructions.h");
});

pub const OpCode = enum(u8) {
    STOP = evmc.OP_STOP,
    ADD = evmc.OP_ADD,
    MOD = evmc.OP_MOD,
    ISZERO = evmc.OP_ISZERO,
    KECCAK256 = evmc.OP_KECCAK256,
    CODESIZE = evmc.OP_CODESIZE,
    POP = evmc.OP_POP,
    PUSH1 = evmc.OP_PUSH1,
    PUSH32 = evmc.OP_PUSH32,
    MSTORE = evmc.OP_MSTORE,
    PC = evmc.OP_PC,
    RETURN = evmc.OP_RETURN,
    _,
};
