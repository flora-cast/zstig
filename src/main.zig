const std = @import("std");
const zstig = @import("zstig");

pub fn main() !void {}

test "compress and decompress" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const original = "Hello, This is test string for compression";
    const compressed = try zstig.compress(original, allocator);
    defer allocator.free(compressed);

    std.debug.print("Size: {}, Compressed: {}\n", .{
        original.len,
        compressed.len,
    });

    std.debug.print("Compressed string: {s}\n", .{
        compressed,
    });

    const decompressed = try zstig.decompress(compressed, allocator);
    defer allocator.free(decompressed);
    std.debug.print("Decompressed: {s}\n", .{decompressed});
}
