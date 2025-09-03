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

/// Decompresses deflate compressed data (raw deflate without container headers)
///
/// Args:
///   allocator: Memory allocator to use for the decompressed data
///   compressed_data: Raw bytes of deflate compressed data
///   uncompressed_size: Expected size of uncompressed data (from ZIP header)
///
/// Returns:
///   Decompressed data as a slice of bytes. Caller owns this memory.
///
/// Errors:
///   - error.OutOfMemory: If allocation fails
///   - error.InvalidData: If the compressed data is malformed
///   - error.EndOfStream: If the compressed data is truncated
///   - error.SizeMismatch: If decompressed size doesn't match expected size
pub fn decompressDeflate(allocator: Allocator, compressed_data: []const u8, uncompressed_size: u32) ![]u8 {
    // Handle special case of empty data
    if (uncompressed_size == 0) {
        return try allocator.alloc(u8, 0);
    }

    // Create a fixed reader from the compressed data
    var reader: std.Io.Reader = .fixed(compressed_data);

    // Initialize deflate decompressor with raw container (no headers)
    var history_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress = std.compress.flate.Decompress.init(&reader, .raw, &history_buffer);

    // Allocate buffer for decompressed data
    var decompressed_data = try allocator.alloc(u8, uncompressed_size);
    errdefer allocator.free(decompressed_data);

    // Decompress data in chunks
    var total_read: usize = 0;
    var chunk: [4096]u8 = undefined;

    while (total_read < uncompressed_size) {
        const remaining = uncompressed_size - total_read;
        const chunk_size = @min(chunk.len, remaining);

        const bytes_read = decompress.reader.readSliceShort(chunk[0..chunk_size]) catch |err| switch (err) {
            error.ReadFailed => {
                if (total_read == uncompressed_size) break;
                return error.InvalidData;
            },
            else => return err,
        };

        if (bytes_read == 0) {
            if (total_read < uncompressed_size) {
                return error.EndOfStream;
            }
            break;
        }

        @memcpy(decompressed_data[total_read .. total_read + bytes_read], chunk[0..bytes_read]);
        total_read += bytes_read;
    }

    // Verify we got the expected amount of data
    if (total_read != uncompressed_size) {
        std.log.err("Deflate decompression size mismatch: expected {}, got {}", .{ uncompressed_size, total_read });
        return error.SizeMismatch;
    }

    return decompressed_data;
}

/// Checks if the given compression method is deflate
///
/// Args:
///   compression_method: ZIP compression method code
///
/// Returns:
///   true if the compression method is deflate (8), false otherwise
pub fn isDeflateCompression(compression_method: u16) bool {
    return compression_method == 8;
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

/// Checks if the given data appears to be ZIP compressed
///
/// Args:
///   data: Raw bytes to check
///
/// Returns:
///   true if the data appears to be ZIP compressed, false otherwise
pub fn isZipCompressed(data: []const u8) bool {
    // ZIP magic number: 0x50 0x4b (PK)
    if (data.len < 2) return false;
    return data[0] == 0x50 and data[1] == 0x4b;
}

/// Extracts all files from a ZIP archive to a target directory
///
/// Args:
///   allocator: Memory allocator for extraction operations
///   zipData: Raw bytes of ZIP compressed data
///   targetDir: Absolute path to directory where files should be extracted
///
/// Returns:
///   void on success
///
/// Errors:
///   - error.OutOfMemory: If allocation fails
///   - error.InvalidData: If the ZIP data is malformed
///   - error.FileNotFound: If target directory doesn't exist
///   - error.PermissionDenied: If insufficient permissions
pub fn extractZip(allocator: std.mem.Allocator, zipData: []const u8, targetDir: []const u8) !void {
    // Validate ZIP data format first
    if (!isZipCompressed(zipData)) {
        std.log.err("Data does not appear to be a valid ZIP file (missing PK signature)", .{});
        return error.InvalidData;
    }

    // Ensure we have minimum data for a ZIP file
    if (zipData.len < 22) {
        std.log.err("ZIP data too small: {} bytes (minimum 22 bytes required)", .{zipData.len});
        return error.InvalidData;
    }

    // Create a fixed buffer reader from the ZIP data
    var fbs = std.io.fixedBufferStream(zipData);
    _ = fbs.reader();

    // Parse ZIP file structure
    // ZIP files have entries at the end (Central Directory)
    // We need to find the End of Central Directory Record (EOCD)
    const eocdSignature: u32 = 0x06054b50;
    var eocdOffset: ?usize = null;

    // Search for EOCD signature from the end
    if (zipData.len >= 22) { // Minimum EOCD size
        var searchOffset: usize = zipData.len - 4; // Start from a position where we can read 4 bytes
        while (searchOffset > 0) {
            const signature = std.mem.readInt(u32, zipData[searchOffset .. searchOffset + 4][0..4], .little);
            if (signature == eocdSignature) {
                eocdOffset = searchOffset;
                break;
            }
            searchOffset -= 1;
        }

        // Check the first position (searchOffset == 0) as well
        if (eocdOffset == null and zipData.len >= 4) {
            const signature = std.mem.readInt(u32, zipData[0..4][0..4], .little);
            if (signature == eocdSignature) {
                eocdOffset = 0;
            }
        }
    }

    if (eocdOffset == null) {
        std.log.err("EOCD signature not found in ZIP data. File may be corrupted or not a valid ZIP archive.", .{});
        return error.InvalidData;
    }

    // Parse EOCD record
    const eocd = zipData[eocdOffset.?..];
    if (eocd.len < 22) {
        std.log.err("EOCD record too small: {} bytes (minimum 22 bytes required)", .{eocd.len});
        return error.InvalidData;
    }

    const centralDirSize = std.mem.readInt(u32, eocd[12..16][0..4], .little);
    const centralDirOffset = std.mem.readInt(u32, eocd[16..20][0..4], .little);

    // Validate central directory bounds
    if (centralDirOffset >= zipData.len) {
        std.log.err("Central directory offset {} exceeds ZIP data size {}", .{ centralDirOffset, zipData.len });
        return error.InvalidData;
    }

    if (centralDirOffset + centralDirSize > zipData.len) {
        std.log.err("Central directory (offset: {}, size: {}) exceeds ZIP data bounds (size: {})", .{ centralDirOffset, centralDirSize, zipData.len });
        return error.InvalidData;
    }

    // Read central directory entries
    var currentOffset: usize = centralDirOffset;
    const centralDirEnd = centralDirOffset + centralDirSize;

    while (currentOffset < centralDirEnd) {
        if (currentOffset + 46 > zipData.len) break;

        const centralFileHeader = zipData[currentOffset..];
        const signature = std.mem.readInt(u32, centralFileHeader[0..4][0..4], .little);

        // Central file header signature
        if (signature != 0x02014b50) break;

        const filenameLength = std.mem.readInt(u16, centralFileHeader[28..30][0..2], .little);
        const extraFieldLength = std.mem.readInt(u16, centralFileHeader[30..32][0..2], .little);
        const fileCommentLength = std.mem.readInt(u16, centralFileHeader[32..34][0..2], .little);
        const localHeaderOffset = std.mem.readInt(u32, centralFileHeader[42..46][0..4], .little);

        // Extract filename
        const filenameStart = currentOffset + 46;
        const filenameEnd = filenameStart + filenameLength;
        if (filenameEnd > zipData.len) break;

        const filename = zipData[filenameStart..filenameEnd];

        // Skip directories (filenames ending with '/')
        if (filename.len > 0 and filename[filename.len - 1] != '/') {
            try extractZipFile(allocator, zipData, localHeaderOffset, filename, targetDir);
        }

        // Move to next central directory entry
        currentOffset = filenameEnd + extraFieldLength + fileCommentLength;
    }
}

/// Extracts a single file from ZIP archive
fn extractZipFile(
    allocator: std.mem.Allocator,
    zipData: []const u8,
    localHeaderOffset: u32,
    filename: []const u8,
    targetDir: []const u8,
) !void {
    if (localHeaderOffset + 30 > zipData.len) return error.InvalidData;

    const localFileHeader = zipData[localHeaderOffset..];
    const signature = std.mem.readInt(u32, localFileHeader[0..4][0..4], .little);

    // Local file header signature
    if (signature != 0x04034b50) return error.InvalidData;

    const compressionMethod = std.mem.readInt(u16, localFileHeader[8..10][0..2], .little);
    const compressedSize = std.mem.readInt(u32, localFileHeader[18..22][0..4], .little);
    _ = std.mem.readInt(u32, localFileHeader[22..26][0..4], .little); // uncompressedSize - not needed for stored files
    const filenameLength = std.mem.readInt(u16, localFileHeader[26..28][0..2], .little);
    const extraFieldLength = std.mem.readInt(u16, localFileHeader[28..30][0..2], .little);

    const dataOffset = localHeaderOffset + 30 + filenameLength + extraFieldLength;
    if (dataOffset + compressedSize > zipData.len) return error.InvalidData;

    const compressedData = zipData[dataOffset .. dataOffset + compressedSize];

    // Create target file path
    const targetPath = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ targetDir, filename });
    defer allocator.free(targetPath);

    std.debug.print("Extracting file: {s} to {s}\n", .{ filename, targetPath });

    // Ensure parent directories exist
    if (std.fs.path.dirname(targetPath)) |parentDir| {
        std.fs.makeDirAbsolute(parentDir) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // Directory already exists, that's fine
            else => return err,
        };
    }

    // Create and write the file
    const file = try std.fs.createFileAbsolute(targetPath, .{});
    defer file.close();

    switch (compressionMethod) {
        0 => { // No compression (stored)
            try file.writeAll(compressedData);
        },
        8 => { // Deflate compression
            const uncompressed_size = std.mem.readInt(u32, localFileHeader[22..26][0..4], .little);
            const decompressed_data = decompressDeflate(allocator, compressedData, uncompressed_size) catch |err| {
                std.log.err("Failed to decompress deflate data for file {s}: {any}", .{ filename, err });
                return err;
            };
            defer allocator.free(decompressed_data);

            try file.writeAll(decompressed_data);
        },
        else => {
            std.log.warn("Unsupported compression method {} for file: {s}", .{ compressionMethod, filename });
            return error.UnsupportedCompressionMethod;
        },
    }
}

test "zip detection" {
    // Test with empty data
    try std.testing.expect(!isZipCompressed(""));

    // Test with too short data
    try std.testing.expect(!isZipCompressed(&[_]u8{0x50}));

    // Test with valid ZIP header (PK)
    try std.testing.expect(isZipCompressed(&[_]u8{ 0x50, 0x4b, 0x03, 0x04 }));

    // Test with invalid data
    try std.testing.expect(!isZipCompressed(&[_]u8{ 0x50, 0x4c, 0x03, 0x04 }));
    try std.testing.expect(!isZipCompressed(&[_]u8{ 0x51, 0x4b, 0x03, 0x04 }));
}

test "decompress empty data" {
    const allocator = std.testing.allocator;

    // Test with empty data
    const empty_data: []const u8 = "";

    // This should fail
    const result = decompressGzip(allocator, empty_data);
    try std.testing.expectError(error.InvalidData, result);
}

test "deflate compression detection" {
    // Test deflate compression method detection
    try std.testing.expect(isDeflateCompression(8));
    try std.testing.expect(!isDeflateCompression(0)); // Stored
    try std.testing.expect(!isDeflateCompression(1)); // Shrunk
    try std.testing.expect(!isDeflateCompression(12)); // BZIP2
    try std.testing.expect(!isDeflateCompression(14)); // LZMA
}

test "deflate decompression with known data" {
    const allocator = std.testing.allocator;

    // For testing purposes, we'll create a minimal deflate stream manually
    // This is a deflate-compressed version of "Hello" (for testing)
    // Generated using standard deflate compression with no headers
    const deflate_data = [_]u8{
        0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, // "Hello" compressed with deflate
    };

    const expected_output = "Hello";
    const uncompressed_size: u32 = expected_output.len;

    const result = decompressDeflate(allocator, &deflate_data, uncompressed_size) catch |err| {
        std.debug.print("Deflate decompression failed: {any}\n", .{err});
        return err;
    };
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected_output, result);
}

test "deflate decompression size mismatch" {
    const allocator = std.testing.allocator;

    // Use the same deflate data but wrong expected size
    const deflate_data = [_]u8{
        0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, // "Hello" compressed
    };

    const wrong_size: u32 = 100; // Much larger than actual

    const result = decompressDeflate(allocator, &deflate_data, wrong_size);
    try std.testing.expectError(error.EndOfStream, result);
}

test "deflate decompression with empty input" {
    const allocator = std.testing.allocator;

    const empty_data: []const u8 = "";
    const uncompressed_size: u32 = 0;

    // Empty input with size 0 should succeed and return empty data
    const result = try decompressDeflate(allocator, empty_data, uncompressed_size);
    defer allocator.free(result);

    // Result should be empty
    try std.testing.expectEqual(@as(usize, 0), result.len);
}
