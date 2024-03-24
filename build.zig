const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const evm_module = b.createModule(.{
        .source_file = .{ .path = "src/vm.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "eth-zvm",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const mnemonic_exe = b.addExecutable(.{
        .name = "mnc",
        .root_source_file = .{ .path = "src/mnemonic-compiler/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    mnemonic_exe.addModule("evm", evm_module);
    b.installArtifact(mnemonic_exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const mnc_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/mnemonic-compiler/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    mnc_unit_tests.addModule("evm", evm_module);

    const run_mnc_unit_tests = b.addRunArtifact(mnc_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_mnc_unit_tests.step);
}
