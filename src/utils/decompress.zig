const std = @import("std");

const Allocator = std.mem.Allocator;

/// Decompresses gzip compressed data
///
/// Args:
///   allocator: Memory allocator to use for the decompressed data
///   compressed_data: Raw bytes of gzip compressed data
///
/// Returns:
///   Decompressed data as a slice of bytes. Caller owns this memory.
///
/// Errors:
///   - error.OutOfMemory: If allocation fails
///   - error.InvalidData: If the compressed data is malformed
///   - error.EndOfStream: If the compressed data is truncated
pub fn decompressGzip(allocator: Allocator, compressed_data: []const u8) ![]u8 {
    // Create a fixed reader from the compressed data
    var reader: std.Io.Reader = .fixed(compressed_data);

    // Create a buffer to collect the decompressed data
    var buffer = try std.ArrayList(u8).initCapacity(allocator, compressed_data.len);
    defer buffer.deinit(allocator);

    // Initialize gzip decompressor with a proper buffer
    var history_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress: std.compress.flate.Decompress = .init(&reader, .gzip, &history_buffer);

    // Read in chunks to handle large files efficiently
    var chunk: [4096]u8 = undefined;
    var total_read: usize = 0;
    while (true) {
        const bytes_read = decompress.reader.readSliceShort(&chunk) catch |err| switch (err) {
            error.ReadFailed => break,
            else => return err,
        };

        if (bytes_read == 0) break;
        total_read += bytes_read;
        try buffer.appendSlice(allocator, chunk[0..bytes_read]);
    }

    // Check if we actually read any data
    if (total_read == 0) {
        return error.InvalidData;
    }

    // Transfer ownership of the buffer to the caller
    return buffer.toOwnedSlice(allocator);
}

/// Decompresses gzip compressed data with a custom chunk size
///
/// Args:
///   allocator: Memory allocator to use for the decompressed data
///   compressed_data: Raw bytes of gzip compressed data
///   chunk_size: Size of chunks to read during decompression
///
/// Returns:
///   Decompressed data as a slice of bytes. Caller owns this memory.
///
/// Errors:
///   - error.OutOfMemory: If allocation fails
///   - error.InvalidData: If the compressed data is malformed
///   - error.EndOfStream: If the compressed data is truncated
pub fn decompressGzipWithChunkSize(allocator: Allocator, compressed_data: []const u8, chunk_size: usize) ![]u8 {
    // Create a fixed reader from the compressed data
    var reader: std.Io.Reader = .fixed(compressed_data);

    // Create a buffer to collect the decompressed data
    var buffer = try std.ArrayList(u8).initCapacity(allocator, compressed_data.len);
    defer buffer.deinit(allocator);

    // Initialize gzip decompressor with a proper buffer
    var history_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress: std.compress.flate.Decompress = .init(&reader, .gzip, &history_buffer);

    // Read in chunks of the specified size
    var chunk = try allocator.alloc(u8, chunk_size);
    defer allocator.free(chunk);

    var total_read: usize = 0;
    while (true) {
        const bytes_read = decompress.reader.readSliceShort(chunk) catch |err| switch (err) {
            error.ReadFailed => break,
            else => return err,
        };

        if (bytes_read == 0) break;
        total_read += bytes_read;
        try buffer.appendSlice(allocator, chunk[0..bytes_read]);
    }

    // Check if we actually read any data
    if (total_read == 0) {
        return error.InvalidData;
    }

    // Transfer ownership of the buffer to the caller
    return buffer.toOwnedSlice(allocator);
}

/// Checks if the given data appears to be gzip compressed
///
/// Args:
///   data: Raw bytes to check
///
/// Returns:
///   true if the data appears to be gzip compressed, false otherwise
pub fn isGzipCompressed(data: []const u8) bool {
    // Gzip magic number: 0x1f 0x8b
    if (data.len < 2) return false;
    return data[0] == 0x1f and data[1] == 0x8b;
}

/// Gets the estimated decompressed size for gzip data
///
/// Note: This is an estimate based on typical compression ratios.
/// The actual size may vary significantly.
///
/// Args:
///   compressed_size: Size of the compressed data in bytes
///
/// Returns:
///   Estimated decompressed size in bytes
pub fn estimateGzipDecompressedSize(compressed_size: usize) usize {
    // Gzip typically achieves 2:1 to 10:1 compression ratios
    // We'll use a conservative estimate of 3:1
    return compressed_size * 3;
}

test "gzip detection" {
    // Test with empty data
    try std.testing.expect(!isGzipCompressed(""));

    // Test with too short data
    try std.testing.expect(!isGzipCompressed(&[_]u8{0x1f}));

    // Test with valid gzip header
    try std.testing.expect(isGzipCompressed(&[_]u8{ 0x1f, 0x8b, 0x08, 0x00 }));

    // Test with invalid data
    try std.testing.expect(!isGzipCompressed(&[_]u8{ 0x1f, 0x8c, 0x08, 0x00 }));
    try std.testing.expect(!isGzipCompressed(&[_]u8{ 0x1e, 0x8b, 0x08, 0x00 }));
}

test "size estimation" {
    // Test size estimation
    const compressed_size: usize = 1000;
    const estimated_size = estimateGzipDecompressedSize(compressed_size);

    // Should be larger than compressed size
    try std.testing.expect(estimated_size > compressed_size);

    // Should be reasonable (not too large)
    try std.testing.expect(estimated_size < compressed_size * 20);
}

test "decompress invalid gzip data" {
    const allocator = std.testing.allocator;

    // Test with invalid gzip data
    const invalid_data = "This is not gzip compressed data";

    // This should fail
    const result = decompressGzip(allocator, invalid_data);
    try std.testing.expectError(error.InvalidData, result);
}

test "decompress empty data" {
    const allocator = std.testing.allocator;

    // Test with empty data
    const empty_data: []const u8 = "";

    // This should fail
    const result = decompressGzip(allocator, empty_data);
    try std.testing.expectError(error.InvalidData, result);
}
