const std = @import("std");
const evm = @import("evm");
const evmc = @cImport({
    @cInclude("evmc/evmc.h");
});

fn execute(
    _: ?*evmc.evmc_vm,
    _: ?*const evmc.evmc_host_interface,
    _: ?*evmc.evmc_host_context,
    _: evmc.evmc_revision,
    _: ?*const evmc.evmc_message,
    bytecode_c: [*c]const u8,
    bytecode_c_size: usize,
) callconv(.C) evmc.evmc_result {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var vm = evm.VM{};
    vm.init(allocator);
    defer vm.deinit();

    const fail_result = evmc.evmc_result{
        .status_code = evmc.EVMC_FAILURE,
        .gas_left = 0,
        .gas_refund = 0,
        .output_data = null,
        .output_size = 0,
        .release = null,
        .create_address = evmc.evmc_address{
            .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .padding = [4]u8{ 0, 0, 0, 0 },
    };

    const bytecode = bytecode_c[0..bytecode_c_size];

    vm.run(bytecode) catch return fail_result;

    return evmc.evmc_result{
        .status_code = evmc.EVMC_SUCCESS,
        .gas_left = 0,
        .gas_refund = 0,
        .output_data = vm.returnValue.ptr,
        .output_size = vm.returnValue.len,
        .release = null,
        .create_address = evmc.evmc_address{
            .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .padding = [4]u8{ 0, 0, 0, 0 },
    };
}

fn get_capabilities(_: ?*evmc.evmc_vm) callconv(.C) evmc.evmc_capabilities_flagset {
    return evmc.EVMC_CAPABILITY_EVM1;
}

fn destroy(_: ?*evmc.evmc_vm) callconv(.C) void {
    return;
}

export fn evmc_create() callconv(.C) *evmc.evmc_vm {
    var vm: evmc.evmc_vm = evmc.evmc_vm{
        .abi_version = evmc.EVMC_ABI_VERSION,
        .name = "eth-zvm",
        .version = "0.0.1",
        .execute = &execute,
        .get_capabilities = &get_capabilities,
        .set_option = null,
        .destroy = &destroy,
    };
    return &vm;
}
