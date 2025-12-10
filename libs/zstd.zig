const std = @import("std");

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC) ?*std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zstd",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = sanitize_c,
        }),
    });
    lib.linkLibC();
    lib.root_module.addCMacro("ZSTD_DISABLE_ASM", "1");
    lib.root_module.addCMacro("HUF_FORCE_DECOMPRESS_X1", "1");

    const zstd_dep = b.lazyDependency("zstd", .{
        .target = target,
        .optimize = optimize,
    }) orelse return null;

    const srcs = &.{ "lib/common/xxhash.c", "lib/common/debug.c", "lib/common/threading.c", "lib/common/zstd_common.c", "lib/common/pool.c", "lib/common/error_private.c", "lib/common/fse_decompress.c", "lib/common/entropy_common.c", "lib/dictBuilder/zdict.c", "lib/dictBuilder/cover.c", "lib/dictBuilder/divsufsort.c", "lib/dictBuilder/fastcover.c", "lib/legacy/zstd_v04.c", "lib/legacy/zstd_v01.c", "lib/legacy/zstd_v07.c", "lib/legacy/zstd_v06.c", "lib/legacy/zstd_v03.c", "lib/legacy/zstd_v05.c", "lib/legacy/zstd_v02.c", "lib/compress/huf_compress.c", "lib/compress/zstd_opt.c", "lib/compress/zstd_compress_literals.c", "lib/compress/zstd_ldm.c", "lib/compress/zstd_compress_sequences.c", "lib/compress/zstdmt_compress.c", "lib/compress/zstd_fast.c", "lib/compress/zstd_preSplit.c", "lib/compress/zstd_lazy.c", "lib/compress/fse_compress.c", "lib/compress/hist.c", "lib/compress/zstd_compress_superblock.c", "lib/compress/zstd_compress.c", "lib/compress/zstd_double_fast.c", "lib/deprecated/zbuff_decompress.c", "lib/deprecated/zbuff_compress.c", "lib/deprecated/zbuff_common.c", "lib/decompress/zstd_ddict.c", "lib/decompress/zstd_decompress_block.c", "lib/decompress/huf_decompress.c", "lib/decompress/zstd_decompress.c" };

    inline for (srcs) |s| {
        lib.addCSourceFile(.{
            .file = zstd_dep.path(s),
            .flags = &.{"-std=gnu89"},
        });
    }

    return lib;
}
