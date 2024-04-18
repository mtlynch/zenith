const evmc = @cImport({
    @cInclude("evmc/instructions.h");
});

pub const OpCode = enum(u8) {
    STOP = evmc.OP_STOP,
    ADD = evmc.OP_ADD,
    MUL = evmc.OP_MUL,
    SUB = evmc.OP_SUB,
    DIV = evmc.OP_DIV,
    SDIV = evmc.OP_SDIV,
    MOD = evmc.OP_MOD,
    SMOD = evmc.OP_SMOD,
    ISZERO = evmc.OP_ISZERO,
    NOT = evmc.OP_NOT,
    KECCAK256 = evmc.OP_KECCAK256,
    CODESIZE = evmc.OP_CODESIZE,
    POP = evmc.OP_POP,
    PUSH0 = evmc.OP_PUSH0,
    PUSH1 = evmc.OP_PUSH1,
    PUSH32 = evmc.OP_PUSH32,
    MSTORE = evmc.OP_MSTORE,
    PC = evmc.OP_PC,
    RETURN = evmc.OP_RETURN,
    _,
};
