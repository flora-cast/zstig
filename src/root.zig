const std = @import("std");
const c = @cImport({
    @cInclude("zstd.h");
});

pub fn compress(src: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const max_compressed_size = c.ZSTD_compressBound(src.len);

    const dst = try allocator.alloc(u8, max_compressed_size);
    errdefer allocator.free(dst);

    const compressed_size = c.ZSTD_compress(dst.ptr, dst.len, src.ptr, src.len, 3);

    if (c.ZSTD_isError(compressed_size) != 0) {
        const err_name = c.ZSTD_getErrorName(compressed_size);
        std.debug.print("[zstd] Compress Error: {s}\n", .{err_name});
        return error.CompressionFailed;
    }

    return try allocator.realloc(dst, compressed_size);
}

pub fn decompress(src: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const decompressed_size = c.ZSTD_getFrameContentSize(src.ptr, src.len);

    const CONTENTSIZE_ERROR: c_ulonglong = @bitCast(@as(c_longlong, -2));
    const CONTENTSIZE_UNKNOWN: c_ulonglong = @bitCast(@as(c_longlong, -1));

    if (decompressed_size == CONTENTSIZE_ERROR) {
        return error.NotZstdFormat;
    }
    if (decompressed_size == CONTENTSIZE_UNKNOWN) {
        return error.UnknownContentSize;
    }

    const dst = try allocator.alloc(u8, @intCast(decompressed_size));
    errdefer allocator.free(dst);

    const result = c.ZSTD_decompress(dst.ptr, dst.len, src.ptr, src.len);

    if (c.ZSTD_isError(result) != 0) {
        const err_name = c.ZSTD_getErrorName(result);
        std.debug.print("[zstd] Extract Error: {s}\n", .{err_name});
        return error.DecompressionFailed;
    }

    return dst;
}

pub fn decompressStream(reader: anytype, writer: anytype, allocator: std.mem.Allocator) !void {
    const dctx = c.ZSTD_createDCtx() orelse return error.ContextCreationFailed;
    defer _ = c.ZSTD_freeDCtx(dctx);

    const in_buff_size = c.ZSTD_DStreamInSize();
    const out_buff_size = c.ZSTD_DStreamOutSize();

    const in_buff = try allocator.alloc(u8, in_buff_size);
    defer allocator.free(in_buff);

    const out_buff = try allocator.alloc(u8, out_buff_size);
    defer allocator.free(out_buff);

    while (true) {
        const bytes_read = try reader.read(in_buff);
        if (bytes_read == 0) break;

        var input = c.ZSTD_inBuffer{
            .src = in_buff.ptr,
            .size = bytes_read,
            .pos = 0,
        };

        while (input.pos < input.size) {
            var output = c.ZSTD_outBuffer{
                .dst = out_buff.ptr,
                .size = out_buff.len,
                .pos = 0,
            };

            const ret = c.ZSTD_decompressStream(dctx, &output, &input);

            if (c.ZSTD_isError(ret) != 0) {
                const err_name = c.ZSTD_getErrorName(ret);
                std.debug.print("[zstd] Stream Extract Error: {s}\n", .{err_name});
                return error.StreamDecompressionFailed;
            }

            try writer.writeAll(out_buff[0..output.pos]);
        }
    }
}

pub fn compressStream(reader: anytype, writer: anytype, allocator: std.mem.Allocator, compression_level: usize) !void {
    const compression_level_c_int: c_int = @intCast(compression_level);
    const cctx = c.ZSTD_createCCtx() orelse return error.ContextCreationFailed;
    defer _ = c.ZSTD_freeCCtx(cctx);

    _ = c.ZSTD_CCtx_setParameter(cctx, c.ZSTD_c_compressionLevel, compression_level_c_int);

    const in_buff_size = c.ZSTD_CStreamInSize();
    const out_buff_size = c.ZSTD_CStreamOutSize();

    const in_buff = try allocator.alloc(u8, in_buff_size);
    defer allocator.free(in_buff);

    const out_buff = try allocator.alloc(u8, out_buff_size);
    defer allocator.free(out_buff);

    while (true) {
        const bytes_read = try reader.read(in_buff);

        const mode: c_uint = if (bytes_read == 0)
            c.ZSTD_e_end
        else
            c.ZSTD_e_continue;

        var input = c.ZSTD_inBuffer{
            .src = in_buff.ptr,
            .size = bytes_read,
            .pos = 0,
        };

        var finished = false;
        while (!finished) {
            var output = c.ZSTD_outBuffer{
                .dst = out_buff.ptr,
                .size = out_buff.len,
                .pos = 0,
            };

            const remaining = c.ZSTD_compressStream2(cctx, &output, &input, mode);

            if (c.ZSTD_isError(remaining) != 0) {
                return error.StreamCompressionFailed;
            }

            try writer.writeAll(out_buff[0..output.pos]);

            finished = (mode == c.ZSTD_e_end) and (remaining == 0);
        }

        if (bytes_read == 0) break;
    }
}
