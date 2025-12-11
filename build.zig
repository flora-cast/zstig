const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sanitize_c = null;

    const lib = b.addLibrary(.{
        .name = "zstig",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (buildLibZstd(b, target, optimize, sanitize_c)) |v| {
        lib.linkLibrary(v);
    }
    lib.linkLibC();

    const mod = b.addModule("zstig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.linkLibrary(lib);
    mod.addIncludePath(b.path("src/"));
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zstig-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstig", .module = mod },
            },
        }),
    });

    exe.linkLibC();

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn buildLibZstd(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC) ?*Step.Compile {
    const zstd = @import("libs/zstd.zig").create(b, target, optimize, sanitize_c);
    const libzstd = zstd.?;
    return libzstd;
}
